import 'package:flutter/material.dart';

/// Spacing scale (8pt grid) used across layout and widgets.
@immutable
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Convenience edge insets using the [lg] (16) step.
  static const EdgeInsets page = EdgeInsets.all(lg);
  static const EdgeInsets screen = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: xl,
  );

  /// The smallest tappable target recommended for accessibility.
  static const double minimumTapTarget = 48;
}
