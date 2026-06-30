import 'package:flutter/widgets.dart';

/// Type tokens. Newsreader carries Scripture + display; Inter carries UI chrome.
/// Color is intentionally omitted: it comes from the theme / nearest
/// DefaultTextStyle, or is applied by the widget (e.g. `context.colors.ink`).
abstract final class AppType {
  static const String serif = 'Newsreader';
  static const String sans = 'Inter';

  static const TextStyle display = TextStyle(
      fontFamily: serif, fontSize: 34, height: 1.15, fontWeight: FontWeight.w500);

  static const TextStyle title = TextStyle(
      fontFamily: serif, fontSize: 24, height: 1.25, fontWeight: FontWeight.w500);

  /// The most important style in the app.
  static const TextStyle scripture = TextStyle(
      fontFamily: serif, fontSize: 19, height: 1.72, fontWeight: FontWeight.w400);

  static const TextStyle sectionHead = TextStyle(
      fontFamily: serif,
      fontSize: 17,
      height: 1.3,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400);

  static const TextStyle overline = TextStyle(
      fontFamily: sans,
      fontSize: 12,
      height: 1.0,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.4);

  static const TextStyle verseNumber = TextStyle(
      fontFamily: sans, fontSize: 12, height: 1.0, fontWeight: FontWeight.w600);

  static const TextStyle body = TextStyle(
      fontFamily: sans, fontSize: 15, height: 1.5, fontWeight: FontWeight.w400);

  static const TextStyle label = TextStyle(
      fontFamily: sans, fontSize: 14, height: 1.3, fontWeight: FontWeight.w500);

  static const TextStyle button = TextStyle(
      fontFamily: sans, fontSize: 16, height: 1.2, fontWeight: FontWeight.w600);

  static const TextStyle caption = TextStyle(
      fontFamily: sans,
      fontSize: 12.5,
      height: 1.4,
      fontWeight: FontWeight.w500);
}
