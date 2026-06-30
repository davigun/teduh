import 'package:flutter/widgets.dart';

/// 4px-based spacing scale. Vary it for rhythm; never pad everything equally.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double x3 = 32;
  static const double x4 = 40;
}

abstract final class AppRadii {
  static const Radius md = Radius.circular(12);
  static const Radius lg = Radius.circular(16);
  static const double pill = 999;

  static const BorderRadius cardLg = BorderRadius.all(lg);
  static const BorderRadius cardMd = BorderRadius.all(md);
}
