import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';

/// A calm raised surface (e1). Used for distinct grouped objects only — never
/// nested, and never for the reading surface itself.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: AppRadii.cardLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardLg,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardLg,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF40342C).withValues(alpha: 0.06),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A small muted pill, e.g. the "Segera" tag on not-yet-released books.
class SoonTag extends StatelessWidget {
  const SoonTag({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.sunken,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: c.muted,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
