import 'package:flutter/material.dart';

/// The three reading temperatures. Pagi and Senja are light; Malam is a warm
/// dark (not pure black). Material's `themeMode` only toggles two, so the app
/// selects a [ThemeData] explicitly per value (see `appThemeFor`).
enum ReadingTheme {
  pagi(Brightness.light),
  senja(Brightness.light),
  malam(Brightness.dark);

  const ReadingTheme(this.brightness);
  final Brightness brightness;

  static ReadingTheme fromName(String? name) =>
      ReadingTheme.values.firstWhere(
        (t) => t.name == name,
        orElse: () => ReadingTheme.pagi,
      );
}
