import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';

/// The A− / A+ reading-size control. One implementation, shared by the reader
/// sheet and Settings so the affordance is identical in both places.
class ReadingSizeStepper extends StatelessWidget {
  const ReadingSizeStepper({
    super.key,
    required this.onSmaller,
    required this.onLarger,
  });

  final VoidCallback onSmaller;
  final VoidCallback onLarger;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.sunken,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Glyph(fontSize: 15, onTap: onSmaller),
          Container(width: 1, height: 22, color: c.hairline),
          _Glyph(fontSize: 23, onTap: onLarger),
        ],
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.fontSize, required this.onTap});
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 48,
        height: 44,
        child: Center(
          child: Text(
            'A',
            style: AppType.title.copyWith(
              color: c.accent,
              fontFamily: AppType.serif,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
