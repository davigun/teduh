import 'package:flutter/material.dart';

import '../theme/reading_theme.dart';

/// The warm-devotional palette, carried into [ThemeData] as a [ThemeExtension]
/// so any widget reads it via `context.colors`. Values are precomputed from the
/// OKLCH tokens in DESIGN.md to exact sRGB (see tool/oklch — kept in the build
/// notes). All ink/bg and onAccent/accent pairs clear WCAG AA.
@immutable
class TeduhColors extends ThemeExtension<TeduhColors> {
  const TeduhColors({
    required this.bg,
    required this.surface,
    required this.sunken,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.hairline,
    required this.accent,
    required this.wash,
    required this.onAccent,
    required this.gold,
    required this.red,
    required this.success,
  });

  final Color bg;
  final Color surface;
  final Color sunken;
  final Color ink;
  final Color ink2;
  final Color muted;
  final Color hairline;
  final Color accent;
  final Color wash;
  final Color onAccent;
  final Color gold;
  final Color red;
  final Color success;

  static const pagi = TeduhColors(
    bg: Color(0xFFF9F4EB),
    surface: Color(0xFFFFFCF6),
    sunken: Color(0xFFF3ECE1),
    ink: Color(0xFF2D231D),
    ink2: Color(0xFF61554E),
    muted: Color(0xFF8A7F77),
    hairline: Color(0xFFE3DDD3),
    accent: Color(0xFFB25630),
    wash: Color(0xFFFEE8DB),
    onAccent: Color(0xFFFDFAF3),
    gold: Color(0xFFD1A255),
    red: Color(0xFFA83632),
    success: Color(0xFF4B8B5A),
  );

  static const senja = TeduhColors(
    bg: Color(0xFFEDDFCC),
    surface: Color(0xFFF4E7D7),
    sunken: Color(0xFFE6D4C0),
    ink: Color(0xFF402E26),
    ink2: Color(0xFF6C594E),
    muted: Color(0xFF8E7C70),
    hairline: Color(0xFFD8C8B6),
    accent: Color(0xFFA54A28),
    wash: Color(0xFFEED1C1),
    onAccent: Color(0xFFFAF6EF),
    gold: Color(0xFFC59449),
    red: Color(0xFF9E2C2A),
    success: Color(0xFF3F7F4F),
  );

  static const malam = TeduhColors(
    bg: Color(0xFF1B1612),
    surface: Color(0xFF251F1A),
    sunken: Color(0xFF14100C),
    ink: Color(0xFFE2DDD4),
    ink2: Color(0xFFA49D95),
    muted: Color(0xFF7B736C),
    hairline: Color(0xFF38322D),
    accent: Color(0xFFD78862),
    wash: Color(0xFF38271E),
    onAccent: Color(0xFF17130F),
    gold: Color(0xFFD9B06B),
    red: Color(0xFFDD7767),
    success: Color(0xFF6DA97D),
  );

  static TeduhColors of(ReadingTheme theme) => switch (theme) {
        ReadingTheme.pagi => pagi,
        ReadingTheme.senja => senja,
        ReadingTheme.malam => malam,
      };

  @override
  TeduhColors copyWith({
    Color? bg,
    Color? surface,
    Color? sunken,
    Color? ink,
    Color? ink2,
    Color? muted,
    Color? hairline,
    Color? accent,
    Color? wash,
    Color? onAccent,
    Color? gold,
    Color? red,
    Color? success,
  }) {
    return TeduhColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      sunken: sunken ?? this.sunken,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      muted: muted ?? this.muted,
      hairline: hairline ?? this.hairline,
      accent: accent ?? this.accent,
      wash: wash ?? this.wash,
      onAccent: onAccent ?? this.onAccent,
      gold: gold ?? this.gold,
      red: red ?? this.red,
      success: success ?? this.success,
    );
  }

  @override
  TeduhColors lerp(ThemeExtension<TeduhColors>? other, double t) {
    if (other is! TeduhColors) return this;
    return TeduhColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      wash: Color.lerp(wash, other.wash, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      red: Color.lerp(red, other.red, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

/// Read the palette anywhere: `context.colors.accent`.
extension TeduhColorsX on BuildContext {
  TeduhColors get colors =>
      Theme.of(this).extension<TeduhColors>() ?? TeduhColors.pagi;
}
