import 'package:flutter/material.dart';

import 'app_breakpoints.dart';
import 'app_colors.dart';
import 'app_elevation.dart';
import 'app_motion.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Aggregates every design token set in a single bundle.
///
/// The design language is light-only ("Pure White Premium"); a single
/// [AppTokens] instance is produced by [AppTokens.standard] and consumed by
/// [AppTheme] when building [ThemeData].
@immutable
class AppTokens {
  const AppTokens._({required this.colors, required this.typography});

  factory AppTokens.standard() => const AppTokens._(
    colors: AppColorPalette(),
    typography: AppTypography.forLight(),
  );

  final AppColorPalette colors;
  final AppTypography typography;

  // Non-color token sets.
  static const AppSpacingToken spacing = AppSpacingToken();
  static const AppRadiusToken radius = AppRadiusToken();
  static const AppElevationToken elevation = AppElevationToken();
  static const AppMotionToken motion = AppMotionToken();
  static const AppBreakpointsToken breakpoints = AppBreakpointsToken();
}

/// Value-object wrapper so colour tokens can be accessed uniformly.
@immutable
class AppColorPalette {
  const AppColorPalette({
    this.background = AppColors.background,
    this.surface = AppColors.surface,
    this.surfaceSecondary = AppColors.surfaceSecondary,
    this.outline = AppColors.outline,
    this.divider = AppColors.divider,
    this.overlay = AppColors.overlay,
    this.textPrimary = AppColors.textPrimary,
    this.textSecondary = AppColors.textSecondary,
    this.textTertiary = AppColors.textTertiary,
    this.textOnSurface = AppColors.textOnSurface,
    this.hairline = AppColors.hairline,
    this.hairlineStrong = AppColors.hairlineStrong,
    this.focusRing = AppColors.focusRing,
    this.starFill = AppColors.starFill,
    this.starIdle = AppColors.starIdle,
  });

  final Color background;
  final Color surface;
  final Color surfaceSecondary;
  final Color outline;
  final Color divider;
  final Color overlay;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnSurface;
  final Color hairline;
  final Color hairlineStrong;
  final Color focusRing;
  final Color starFill;
  final Color starIdle;
}

/// Non-color token sets (concrete, const).
@immutable
class AppSpacingToken {
  const AppSpacingToken();
  double get xxs => AppSpacing.xxs;
  double get xs => AppSpacing.xs;
  double get sm => AppSpacing.sm;
  double get md => AppSpacing.md;
  double get lg => AppSpacing.lg;
  double get xl => AppSpacing.xl;
  double get xxl => AppSpacing.xxl;
  double get xxxl => AppSpacing.xxxl;
}

@immutable
class AppRadiusToken {
  const AppRadiusToken();
  double get xs => AppRadius.xs;
  double get sm => AppRadius.sm;
  double get md => AppRadius.md;
  double get lg => AppRadius.lg;
  double get xl => AppRadius.xl;
  double get pill => AppRadius.pill;
}

@immutable
class AppElevationToken {
  const AppElevationToken();
  double get none => AppElevation.none;
  double get sm => AppElevation.sm;
  double get md => AppElevation.md;
  double get lg => AppElevation.lg;
  double get xl => AppElevation.xl;
}

@immutable
class AppMotionToken {
  const AppMotionToken();
  Duration get fast => AppMotion.fast;
  Duration get normal => AppMotion.normal;
  Duration get slow => AppMotion.slow;
  Curve get standard => AppMotion.standard;
  Curve get emphasized => AppMotion.emphasized;
  Curve get exit => AppMotion.exit;
}

@immutable
class AppBreakpointsToken {
  const AppBreakpointsToken();
  double get compact => AppBreakpoints.compact;
  double get medium => AppBreakpoints.medium;
  double get expanded => AppBreakpoints.expanded;
}
