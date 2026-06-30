import 'package:flutter/animation.dart';

/// Gentle, state-conveying motion. Ease-out only, no bounce/elastic.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Curve easeOutQuint = Cubic(0.22, 1, 0.36, 1);
}
