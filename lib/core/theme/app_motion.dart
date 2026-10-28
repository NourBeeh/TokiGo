import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Motion tokens driving the premium, unified animations (page transitions,
/// sheets, staggered lists, the AI pulse).
@immutable
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);

  /// The page flight for a push/pop — iOS is ~350ms.
  ///
  /// A page transition is the one animation in the app that must NOT be short:
  /// with a front-loaded curve over 260ms the page is already 60% across the
  /// screen 65ms in, so the eye never sees it leave the edge and the push reads
  /// as "appearing from the middle". This is the longer, trackable flight.
  static const Duration page = Duration(milliseconds: 350);

  /// Curves for entering/leaving elements.
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
  static const Curve exit = Curves.fastOutSlowIn;

  /// The push/pop curve: symmetric and gentle at the start, so the page is
  /// watched travelling in from the edge (see [page]). `fastOutSlowIn` is
  /// symmetric, which is what makes the pop look like the push backwards.
  static const Curve pageCurve = Curves.fastOutSlowIn;

  /// Convenience builders.
  static Duration durationFor(double distance) =>
      Duration(milliseconds: (120 + distance * 18).clamp(150, 420).round());

  static Color scrimColor() => AppColors.overlay;
}
