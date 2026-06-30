import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';

/// The clay pill — the app's single primary action style.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        disabledBackgroundColor: c.accent.withValues(alpha: 0.4),
        minimumSize: const Size(0, 54),
        shape: const StadiumBorder(),
        textStyle: AppType.button,
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 9)],
          Text(label),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
