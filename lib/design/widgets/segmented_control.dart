import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// One choice in a [SegmentedControl].
class SegmentItem {
  const SegmentItem(this.label, {this.icon});
  final String label;
  final IconData? icon;
}

/// The app's single segmented-toggle vocabulary: a sunken track with a calm
/// raised "thumb" on the selected segment. Used for the reading theme picker
/// (icon + label) and the testament switch (label only) so those controls are
/// identical everywhere instead of re-implemented per screen.
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<SegmentItem> segments;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final stacked = segments.any((s) => s.icon != null);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(color: c.sunken, borderRadius: AppRadii.cardMd),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++)
            Expanded(
              child: _Segment(
                item: segments[i],
                selected: i == selected,
                stacked: stacked,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.item,
    required this.selected,
    required this.stacked,
    required this.onTap,
  });

  final SegmentItem item;
  final bool selected;
  final bool stacked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.accent : c.ink2;
    final label = Text(
      item.label,
      style: (stacked ? AppType.caption : AppType.label)
          .copyWith(color: fg, fontWeight: FontWeight.w600),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.easeOutQuint,
        height: stacked ? 56 : 40,
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF40342C).withValues(alpha: 0.07),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: stacked
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 20, color: fg),
                  const SizedBox(height: 4),
                  label,
                ],
              )
            : label,
      ),
    );
  }
}
