import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';
import 'reading_theme.dart';

/// Builds the [ThemeData] for one [ReadingTheme]. The app selects this
/// explicitly per value (no `themeMode`) because there are three temperatures.
ThemeData appThemeFor(ReadingTheme theme) {
  final c = KoinoniaColors.of(theme);
  final base = ThemeData(brightness: theme.brightness, useMaterial3: true);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: c.accent,
    brightness: theme.brightness,
  ).copyWith(
    primary: c.accent,
    onPrimary: c.onAccent,
    surface: c.surface,
    onSurface: c.ink,
    error: c.red,
  );

  final textTheme = base.textTheme
      .apply(fontFamily: AppType.sans, bodyColor: c.ink, displayColor: c.ink);

  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[c],
    colorScheme: colorScheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    dividerColor: c.hairline,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      titleTextStyle: AppType.title.copyWith(color: c.ink, fontSize: 20),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.wash,
      elevation: 0,
      height: 70,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppType.caption.copyWith(
          color: states.contains(WidgetState.selected) ? c.accent : c.muted,
          fontSize: 11.5,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? c.accent : c.muted,
          size: 24,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.hairline,
    ),
    iconTheme: IconThemeData(color: c.ink2),
    splashColor: c.wash,
    highlightColor: c.wash.withValues(alpha: 0.5),
  );
}
