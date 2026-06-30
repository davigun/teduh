import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/queries.dart';
import '../../../app/router/app_router.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/tokens/app_typography.dart';
import '../../../design/widgets/adaptive_scaffold.dart';
import '../../../design/widgets/plan_progress_bar.dart';
import '../../../design/widgets/primary_button.dart';
import '../../../design/widgets/section_card.dart';

/// Rencana — invites a plan when none exists, or summarizes the active one.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final plan = ref.watch(activePlanProvider).value;
    final names = ref.watch(bookNamesProvider).value ?? const {};
    final today = ref.watch(todaysReadingProvider).value;

    return AdaptiveScaffold(
      title: 'Rencana',
      slivers: plan == null
          ? [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Empty(onSetup: () => context.push(Routes.planSetup)),
              ),
            ]
          : [
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RENCANA AKTIF',
                          style: AppType.overline.copyWith(color: c.muted)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${names[plan.start.bookCode] ?? plan.start.bookCode} – ${names[plan.end.bookCode] ?? plan.end.bookCode}',
                        style: AppType.title.copyWith(color: c.ink, fontSize: 24),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text('${plan.chaptersPerDay} pasal per hari',
                          style: AppType.body.copyWith(color: c.ink2)),
                      if (today != null && today.totalDays > 0) ...[
                        const SizedBox(height: AppSpacing.lg),
                        PlanProgressBar(
                            dayIndex: today.dayIndex,
                            totalDays: today.totalDays),
                      ],
                      if (today != null && today.chapters.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text('Hari ini: ${passageLabel(today.chapters, names)}',
                            style: AppType.label.copyWith(
                                color: c.accent, fontSize: 15)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Ubah rencana',
                  icon: Icons.tune,
                  onPressed: () => context.push(Routes.planSetup),
                ),
                  ]),
                ),
              ),
            ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onSetup});
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.wash, borderRadius: AppRadii.cardLg),
            child: Icon(Icons.route_outlined, color: c.accent, size: 32),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Baca dengan langkah yang pas untukmu.',
              style: AppType.title.copyWith(color: c.ink, fontSize: 23, height: 1.3)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tentukan berapa pasal sehari. Teduh menyusun jadwalnya, kamu tinggal membaca.',
            style: AppType.body.copyWith(color: c.ink2, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(label: 'Atur rencana', icon: Icons.tune, onPressed: onSetup),
        ],
      ),
    );
  }
}
