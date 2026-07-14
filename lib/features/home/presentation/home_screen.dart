import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/auth_controller.dart';
import '../../../app/group_providers.dart';
import '../../../app/providers.dart';
import '../../../app/queries.dart';
import '../../../app/router/app_router.dart';
import '../../../core/time/calendar_date.dart';
import '../../../domain/entities/plan.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/tokens/app_typography.dart';
import '../../../design/widgets/adaptive_scaffold.dart';
import '../../../design/widgets/plan_progress_bar.dart';
import '../../../design/widgets/primary_button.dart';
import '../../../design/widgets/section_card.dart';

/// Beranda — one calm focal point: today's reading. A compact greeting leads,
/// the reading card is the hero, and streak + together recede beneath it.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = ref.watch(clockProvider).nowLocal().hour;
    final reading = ref.watch(todaysReadingProvider);
    final names = ref.watch(bookNamesProvider).value ?? const {};
    final streak = ref.watch(streakProvider).value;
    final doneToday = ref.watch(isTodayDoneProvider).value ?? false;
    final firstName = _firstName(ref.watch(authProvider).displayName);

    return AdaptiveScaffold.list(
      title: 'Koinonia',
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl, AppSpacing.xs, AppSpacing.xxl, AppSpacing.x4),
      children: [
        _Greeting(hour: hour, name: firstName),
        const SizedBox(height: AppSpacing.xl),
        reading.when(
          loading: () => const _CardSkeleton(),
          error: (_, __) => const _CardSkeleton(),
          data: (daily) => daily == null
              ? _NoPlanCard(onSetup: () => context.push(Routes.planSetup))
              : _TodayCard(
                  reading: daily,
                  label: passageLabel(daily.chapters, names),
                  done: doneToday,
                  onStart: daily.chapters.isEmpty
                      ? null
                      : () => context.push(Routes.reader(
                          daily.chapters.first.bookCode,
                          daily.chapters.first.chapter)),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _StreakStrip(
          days: streak?.current ?? 0,
          completed: ref.watch(completedDatesProvider).value ?? const {},
          today: CalendarDate.fromLocal(ref.watch(clockProvider).nowLocal()),
        ),
        const SizedBox(height: AppSpacing.md),
        const _TogetherRow(),
      ],
    );
  }

  String? _firstName(String? displayName) {
    final trimmed = displayName?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.split(' ').first;
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.hour, required this.name});
  final int hour;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final greeting = name == null ? '${_greeting(hour)}.' : '${_greeting(hour)}, $name.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_dateLabel().toUpperCase(),
            style: AppType.overline.copyWith(color: c.muted)),
        const SizedBox(height: AppSpacing.sm),
        Text(greeting,
            style: AppType.title.copyWith(color: c.ink2, fontSize: 22)),
      ],
    );
  }

  String _greeting(int hour) {
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  String _dateLabel() {
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]} · ${now.day} ${months[now.month - 1]}';
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();
  @override
  Widget build(BuildContext context) => SectionCard(
        child: SizedBox(
          height: 150,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(context.colors.muted)),
            ),
          ),
        ),
      );
}

class _NoPlanCard extends StatelessWidget {
  const _NoPlanCard({required this.onSetup});
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Belum ada rencana baca',
              style: AppType.title.copyWith(color: c.ink, fontSize: 22)),
          const SizedBox(height: AppSpacing.xs),
          Text('Atur langkahmu, lalu pasal hari ini muncul di sini tiap pagi.',
              style: AppType.body.copyWith(color: c.ink2)),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(label: 'Atur rencana', icon: Icons.tune, onPressed: onSetup),
        ],
      ),
    );
  }
}

/// The hero: today's passage and the single primary action, with a quiet
/// progress line so "where am I in the plan" lives right where reading begins.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.reading,
    required this.label,
    required this.done,
    required this.onStart,
  });
  final DailyReading reading;
  final String label;
  final bool done;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final finished = reading.chapters.isEmpty;
    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BACAAN HARI INI',
              style: AppType.overline.copyWith(color: c.accent)),
          const SizedBox(height: AppSpacing.md),
          Text(finished ? 'Rencana selesai 🎉' : label,
              style: AppType.display.copyWith(color: c.ink, fontSize: 33)),
          if (!finished && reading.totalDays > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            PlanProgressBar(
                dayIndex: reading.dayIndex, totalDays: reading.totalDays),
          ],
          const SizedBox(height: AppSpacing.xl),
          if (finished)
            Text('Kamu sudah menyelesaikan seluruh rencana ini.',
                style: AppType.body.copyWith(color: c.ink2))
          else if (done)
            Row(children: [
              Icon(Icons.check_circle, color: c.success, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text('Sudah selesai hari ini',
                  style: AppType.label.copyWith(color: c.success, fontSize: 15)),
              const Spacer(),
              TextButton(onPressed: onStart, child: const Text('Baca lagi')),
            ])
          else
            PrimaryButton(
                label: 'Mulai baca',
                icon: Icons.menu_book_outlined,
                onPressed: onStart),
        ],
      ),
    );
  }
}

/// Secondary: the streak. Flat (hairline, no shadow) so the hero card leads.
class _StreakStrip extends StatelessWidget {
  const _StreakStrip(
      {required this.days, required this.completed, required this.today});
  final int days;
  final Set<CalendarDate> completed;
  final CalendarDate today;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadii.cardLg,
        border: Border.all(color: c.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: c.wash, shape: BoxShape.circle),
            child: Icon(Icons.local_fire_department, color: c.gold, size: 24),
          ),
          const SizedBox(width: AppSpacing.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$days hari',
                  style: AppType.title.copyWith(
                      color: c.ink, fontSize: 20, fontWeight: FontWeight.w600)),
              Text('berturut-turut',
                  style: AppType.caption.copyWith(color: c.muted)),
            ],
          ),
          const Spacer(),
          _WeekDots(completed: completed, today: today),
        ],
      ),
    );
  }
}

class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.completed, required this.today});
  final Set<CalendarDate> completed;
  final CalendarDate today;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const initials = ['Sn', 'Sl', 'Rb', 'Km', 'Jm', 'Sb', 'Mg'];
    return Row(
      children: List.generate(4, (i) {
        final date = today.addDays(-(3 - i));
        final done = completed.contains(date);
        final isToday = i == 3;
        final dow = DateTime.utc(date.year, date.month, date.day).weekday;
        return Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: Column(
            children: [
              Text(initials[dow - 1],
                  style: AppType.caption.copyWith(color: c.muted, fontSize: 10.5)),
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: done ? c.success : c.sunken,
                  shape: BoxShape.circle,
                  border: isToday && !done
                      ? Border.all(color: c.accent, width: 2)
                      : null,
                ),
                child: done ? Icon(Icons.check, size: 14, color: c.onAccent) : null,
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Tertiary: a quiet doorway to the Bersama tab. Lightest element on the page.
class _TogetherRow extends ConsumerWidget {
  const _TogetherRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final available = ref.watch(authProvider).isAvailable;
    final group = available ? ref.watch(activeGroupProvider).value : null;
    final stages = group == null ? null : ref.watch(groupStagesProvider).value;

    final (subtitle, badge) = !available
        ? ('Ajak keluarga & sahabat membaca seiring tiap hari.', 'Segera')
        : group == null
            ? ('Buat grup atau gabung dengan kode.', 'Mulai')
            : stages != null && stages.isNotEmpty
                ? ('${stages.where((s) => s.readToday).length} dari ${stages.length} sudah baca hari ini · ${group.name}',
                    'Buka')
                : ('Grup ${group.name} sedang berjalan.', 'Buka');

    final row = Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadii.cardLg,
        border: Border.all(color: c.hairline),
      ),
      child: Row(
        children: [
          Icon(Icons.people_outline, color: c.accent, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Baca bersama',
                    style: AppType.label.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(badge,
              style: AppType.caption.copyWith(
                  color: c.accent, fontSize: 12, fontWeight: FontWeight.w600)),
          Icon(Icons.chevron_right, color: c.muted, size: 18),
        ],
      ),
    );

    if (!available) return row;
    return InkWell(
      borderRadius: AppRadii.cardLg,
      onTap: () => context.go(Routes.together),
      child: row,
    );
  }
}
