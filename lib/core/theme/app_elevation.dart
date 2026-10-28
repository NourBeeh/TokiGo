import 'package:flutter/material.dart';

/// Elevation tokens — the **halo** system.
///
/// On a pure white canvas a single-stop Material shadow reads as dirt: a white
/// card floating over a white page needs an edge as well as a shadow. Every
/// level therefore returns TWO stops — a tight contact stop that defines the
/// edge and a wide diffuse stop that lifts the surface — while the 1px hairline
/// (`AppColors.hairline`) completes the halo at the widget level.
///
/// The alpha ladder is monotonic, so a higher level is always visibly stronger.
/// The shadow colour is ink (`#111111`), never pure black: black shadows on
/// white read as grime, ink shadows read as light.
@immutable
abstract final class AppElevation {
  static const double none = 0;
  static const double sm = 1;
  static const double md = 3;
  static const double lg = 8;
  static const double xl = 16;

  /// Builds the two-stop halo for [level]. `level` maps 0..3 to the
  /// (sm/md/lg/xl) presets; the ladder is monotonic by design.
  ///
  /// The [background] parameter is kept for API compatibility with call sites
  /// that pass the surface they are lifting; the halo itself is always ink,
  /// because the canvas is always white.
  static List<BoxShadow> shadow({
    required Color background,
    double level = AppElevation.md,
  }) {
    switch (level) {
      case AppElevation.none:
        return const <BoxShadow>[];
      case AppElevation.sm:
        return const <BoxShadow>[
          BoxShadow(
            color: Color(0x08111111),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x08111111),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ];
      case AppElevation.lg:
        return const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D111111),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x12111111),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ];
      case AppElevation.xl:
        return const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F111111),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x2E111111),
            blurRadius: 80,
            offset: Offset(0, 24),
          ),
        ];
      case AppElevation.md:
      default:
        return const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A111111),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x0D111111),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ];
    }
  }

  /// Upward halo for a surface anchored to the bottom edge (sheets, nav bars,
  /// the dark CTA bar).
  static List<BoxShadow> up({double level = AppElevation.lg}) {
    switch (level) {
      case AppElevation.none:
        return const <BoxShadow>[];
      case AppElevation.sm:
        return const <BoxShadow>[
          BoxShadow(
            color: Color(0x08111111),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ];
      case AppElevation.md:
        return const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F111111),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
          BoxShadow(
            color: Color(0x14111111),
            blurRadius: 32,
            offset: Offset(0, -12),
          ),
        ];
      case AppElevation.xl:
        return const <BoxShadow>[
          BoxShadow(
            color: Color(0x14111111),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
          BoxShadow(
            color: Color(0x1F111111),
            blurRadius: 80,
            offset: Offset(0, -32),
          ),
        ];
      case AppElevation.lg:
      default:
        return const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F111111),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
          BoxShadow(
            color: Color(0x1A111111),
            blurRadius: 60,
            offset: Offset(0, -24),
          ),
        ];
    }
  }
}
