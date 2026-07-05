import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/queries.dart';
import '../../../app/router/app_router.dart';
import '../../../domain/entities/bible.dart';
import '../../../domain/services/sequential_plan_engine.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/tokens/app_typography.dart';
import '../../../design/widgets/primary_button.dart';
import '../../../design/widgets/section_card.dart';
import 'start_picker.dart';

/// Sequential plan setup. P1 reads through the New Testament (Matius → Wahyu);
/// a start-point picker is a small follow-up. Pace is adjustable and the
/// schedule preview is computed live by the engine.
class PlanSetupScreen extends ConsumerStatefulWidget {
  const PlanSetupScreen({super.key});

  @override
  ConsumerState<PlanSetupScreen> createState() => _PlanSetupScreenState();
}

class _PlanSetupScreenState extends ConsumerState<PlanSetupScreen> {
  static const _engine = SequentialPlanEngine();
  static const _end = BibleRef('REV', 22);
  BibleRef _start = const BibleRef('MAT', 1);
  int _pace = 3;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final books = ref.watch(booksProvider).value ?? const [];
    final names = ref.watch(bookNamesProvider).value ?? const {};
    final universe = _engine.chapterUniverse(books, _start, _end);
    final totalDays = _engine.totalDays(universe.length, _pace);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Rencana Baca')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          Text('Baca dengan langkah yang pas untukmu.',
              style: AppType.title.copyWith(color: c.ink, fontSize: 22, height: 1.3)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tentukan berapa pasal sehari. Teduh menyusun jadwalnya, kamu tinggal membaca.',
            style: AppType.body.copyWith(color: c.ink2, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                _Row(
                  label: 'Mulai dari',
                  trailing: GestureDetector(
                    onTap: () => _pickStart(context),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          '${names[_start.bookCode] ?? _start.bookCode} ${_start.chapter}',
                          style: AppType.title.copyWith(
                              color: c.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      Icon(Icons.chevron_right, color: c.muted, size: 20),
                    ]),
                  ),
                  divider: true,
                ),
                _Row(
                  label: 'Kecepatan',
                  trailing: _Stepper(
                    value: _pace,
                    onChanged: (v) => setState(() => _pace = v.clamp(1, 10)),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.xs, top: AppSpacing.xs),
            child: Text('pasal per hari',
                style: TextStyle(fontFamily: AppType.sans, fontSize: 12)),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (totalDays > 0)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(color: c.wash, borderRadius: AppRadii.cardLg),
              child: Text.rich(
                TextSpan(
                  style: AppType.title.copyWith(
                      color: c.ink,
                      fontSize: 19,
                      height: 1.3,
                      fontWeight: FontWeight.w600),
                  children: [
                    const TextSpan(text: 'Kamu menamatkan '),
                    TextSpan(text: 'Perjanjian Baru', style: TextStyle(color: c.accent)),
                    const TextSpan(text: ' dalam '),
                    TextSpan(text: '± $totalDays hari', style: TextStyle(color: c.accent)),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text('Pratinjau jadwal', style: AppType.overline.copyWith(color: c.muted)),
          const SizedBox(height: AppSpacing.sm),
          for (var d = 0; d < 4 && d < totalDays; d++)
            _ScheduleRow(
              day: 'HARI ${d + 1}',
              passage: passageLabel(
                  _engine.readingForDay(universe, _pace, d).chapters, names),
            ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: _saving ? 'Menyimpan…' : 'Mulai rencana',
            onPressed: (_saving || universe.isEmpty) ? null : _startPlan,
          ),
        ],
      ),
    );
  }

  Future<void> _startPlan() async {
    setState(() => _saving = true);
    final plan =
        buildPlan(ref, start: _start, end: _end, chaptersPerDay: _pace);
    await savePlanAction(ref, plan);
    if (mounted) context.go(Routes.home);
  }

  Future<void> _pickStart(BuildContext context) async {
    final picked =
        await showStartPicker(context, ref.read(booksProvider).value ?? const []);
    if (picked != null) setState(() => _start = picked);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.trailing, this.divider = false});
  final String label;
  final Widget trailing;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: divider
          ? BoxDecoration(border: Border(bottom: BorderSide(color: c.hairline)))
          : null,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppType.caption.copyWith(color: c.muted, fontSize: 13)),
          trailing,
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
          color: c.sunken, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        children: [
          IconButton(
              onPressed: () => onChanged(value - 1),
              icon: Icon(Icons.remove, color: c.accent)),
          Text('$value',
              style: AppType.title.copyWith(
                  color: c.ink, fontSize: 17, fontWeight: FontWeight.w600)),
          IconButton(
              onPressed: () => onChanged(value + 1),
              icon: Icon(Icons.add, color: c.accent)),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.day, required this.passage});
  final String day;
  final String passage;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: c.hairline))),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(day,
                style: AppType.caption.copyWith(
                    color: c.muted, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(passage,
              style: AppType.body.copyWith(
                  fontFamily: AppType.serif,
                  color: c.ink,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
