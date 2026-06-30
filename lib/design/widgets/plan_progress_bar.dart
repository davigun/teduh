import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A calm "where am I in the plan" indicator: a thin clay bar over a sunken
/// track, with a plain-language day count. Shared by Beranda and the plan
/// detail so progress reads identically wherever it appears.
class PlanProgressBar extends StatelessWidget {
  const PlanProgressBar({
    super.key,
    required this.dayIndex,
    required this.totalDays,
  });

  final int dayIndex; // 0-based
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dayNumber = (dayIndex + 1).clamp(1, totalDays);
    final remaining = (totalDays - dayNumber).clamp(0, totalDays);
    final value = (dayNumber / totalDays).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: c.sunken,
            valueColor: AlwaysStoppedAnimation(c.accent),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          remaining == 0
              ? 'Hari terakhir · ke-$dayNumber dari $totalDays'
              : 'Hari ke-$dayNumber dari $totalDays · $remaining hari lagi',
          style: AppType.caption.copyWith(color: c.muted),
        ),
      ],
    );
  }
}
