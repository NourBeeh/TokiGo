import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_elevation.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_tokens.dart';
import 'app_typography.dart';
import 'tokigo_colors.dart';
import 'package:tokigo/core/navigation/app_transitions.dart';

/// Builds the central light [ThemeData] for TokiGo.
///
/// "Clean Light": a near-white canvas, hairline borders, the neutral ink accent
/// for primary actions, and the two-stop halo shadow. The only other colours in
/// the [ColorScheme] are semantic (error and the feedback roles). The dark
/// variant lives in [dark].
@immutable
abstract final class AppTheme {
  /// System chrome for the light-only canvas.
  ///
  /// Android 15+ (targetSdk 35) enforces edge-to-edge, so the app draws under
  /// the system bars: without an explicit overlay style the platform default
  /// keeps LIGHT status-bar icons, which are invisible on the near-white
  /// canvas. Dark icons on a transparent bar is the only correct choice for a
  /// light-only design — applied once at the app root, since the pages draw
  /// their own headers instead of using an `AppBar`.
  static const SystemUiOverlayStyle systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  /// System chrome for the dark canvas: light icons on a transparent bar.
  static const SystemUiOverlayStyle systemOverlayDark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  static ThemeData light() {
    final tokens = AppTokens.standard();
    final palette = tokens.colors;
    final typography = AppTypography.forLight();
    // The light canvas's own ink. Every hue-bearing token in the app resolves
    // through [TokiGoColors], so the [ColorScheme] only needs the neutral step.
    final TokiGoColors ink = TokiGoColors.light();

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: ink.brand,
      onPrimary: ink.onBrand,
      primaryContainer: ink.brandContainer,
      onPrimaryContainer: ink.onBrandContainer,
      secondary: AppColors.ink,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.surfaceTertiary,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.ink,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.surfaceSecondary,
      onTertiaryContainer: AppColors.ink,
      error: AppColors.danger,
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      surfaceContainerHighest: palette.surfaceSecondary,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.outline,
      outlineVariant: palette.divider,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: palette.textPrimary,
      onInverseSurface: palette.surface,
      inversePrimary: const Color(0xFF3A3A3A),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: tokens.typography.buildTextTheme(),
      scaffoldBackgroundColor: palette.background,
      fontFamily: AppTypography.fontFamily,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[TokiGoColors.light()],
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: NoSplash.splashFactory,
      highlightColor: ink.brand.withValues(alpha: 0.08),
      splashColor: Colors.transparent,
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: AppElevation.none,
        margin: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgBorder,
          side: BorderSide(color: palette.outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlBorder),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: AppElevation.none,
        scrolledUnderElevation: AppElevation.none,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: AppTheme.systemOverlay,
      ),
      dividerTheme: DividerThemeData(color: palette.divider, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: ink.brand,
              foregroundColor: ink.onBrand,
              disabledBackgroundColor: AppColors.surfaceTertiary,
              disabledForegroundColor: AppColors.textTertiary,
              minimumSize: const Size(64, 52),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
              textStyle: typography.bodyLargeMedium,
            ).copyWith(
              overlayColor: WidgetStatePropertyAll<Color>(
                ink.brand.withValues(alpha: 0.08),
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: ink.brand,
              side: const BorderSide(color: AppColors.hairlineStrong),
              minimumSize: const Size(64, 52),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
              textStyle: typography.bodyLargeMedium,
            ).copyWith(
              overlayColor: WidgetStatePropertyAll<Color>(
                ink.brand.withValues(alpha: 0.08),
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              foregroundColor: ink.brand,
              textStyle: typography.bodyLargeMedium,
            ).copyWith(
              overlayColor: WidgetStatePropertyAll<Color>(
                ink.brand.withValues(alpha: 0.08),
              ),
            ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: palette.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: palette.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
        ),
        hintStyle: typography.bodyMedium.copyWith(color: palette.textTertiary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: ink.brandContainer,
        elevation: AppElevation.none,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlBorder),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          // Android: the system owns back / predictive back. Do not replace
          // this with a custom slide builder or the gesture detector is lost.
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          // iOS: native Cupertino transition *and* the native interactive
          // edge-swipe back gesture (including RTL direction handling).
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          // Desktop has no system back gesture; use the app's RTL-aware,
          // strictly-horizontal slide.
          TargetPlatform.macOS: SlideFromRightPageTransitionsBuilder(),
          TargetPlatform.linux: SlideFromRightPageTransitionsBuilder(),
          TargetPlatform.windows: SlideFromRightPageTransitionsBuilder(),
          TargetPlatform.fuchsia: SlideFromRightPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData dark() {
    final palette = TokiGoColors.dark();
    final typography = AppTypography.forDark();

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: palette.brand,
      onPrimary: palette.onBrand,
      primaryContainer: palette.brandContainer,
      onPrimaryContainer: palette.onBrandContainer,
      secondary: palette.ink,
      onSecondary: palette.background,
      secondaryContainer: palette.surfaceTertiary,
      onSecondaryContainer: palette.ink,
      tertiary: palette.ink,
      onTertiary: palette.background,
      tertiaryContainer: palette.surfaceSecondary,
      onTertiaryContainer: palette.ink,
      error: palette.danger,
      onError: palette.background,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      surfaceContainerHighest: palette.surfaceSecondary,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.outline,
      outlineVariant: palette.divider,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: palette.textPrimary,
      onInverseSurface: palette.surface,
      inversePrimary: palette.brand,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: typography.buildTextTheme(),
      scaffoldBackgroundColor: palette.background,
      fontFamily: AppTypography.fontFamily,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[palette],
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: NoSplash.splashFactory,
      highlightColor: palette.brand.withValues(alpha: 0.08),
      splashColor: Colors.transparent,
      cardTheme: CardThemeData(
        color: palette.surfaceElevated,
        elevation: AppElevation.none,
        margin: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgBorder,
          side: BorderSide(color: palette.outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlBorder),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: AppElevation.none,
        scrolledUnderElevation: AppElevation.none,
        foregroundColor: TokiGoColors.dark().textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: AppTheme.systemOverlayDark,
      ),
      dividerTheme: DividerThemeData(color: palette.divider, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: palette.brand,
              foregroundColor: palette.onBrand,
              disabledBackgroundColor: palette.surfaceTertiary,
              disabledForegroundColor: palette.textTertiary,
              minimumSize: const Size(64, 52),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
              textStyle: typography.bodyLargeMedium,
            ).copyWith(
              overlayColor: WidgetStatePropertyAll<Color>(
                palette.brand.withValues(alpha: 0.08),
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: palette.brand,
              side: BorderSide(color: palette.hairlineStrong),
              minimumSize: const Size(64, 52),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
              textStyle: typography.bodyLargeMedium,
            ).copyWith(
              overlayColor: WidgetStatePropertyAll<Color>(
                palette.brand.withValues(alpha: 0.08),
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              foregroundColor: palette.brand,
              textStyle: typography.bodyLargeMedium,
            ).copyWith(
              overlayColor: WidgetStatePropertyAll<Color>(
                palette.brand.withValues(alpha: 0.08),
              ),
            ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: palette.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: palette.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: palette.brand, width: 1.5),
        ),
        hintStyle: typography.bodyMedium.copyWith(color: palette.textTertiary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.brandContainer,
        elevation: AppElevation.none,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlBorder),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          // Android: the system owns back / predictive back. Do not replace
          // this with a custom slide builder or the gesture detector is lost.
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          // iOS: native Cupertino transition *and* the native interactive
          // edge-swipe back gesture (including RTL direction handling).
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          // Desktop has no system back gesture; use the app's RTL-aware,
          // strictly-horizontal slide.
          TargetPlatform.macOS: SlideFromRightPageTransitionsBuilder(),
          TargetPlatform.linux: SlideFromRightPageTransitionsBuilder(),
          TargetPlatform.windows: SlideFromRightPageTransitionsBuilder(),
          TargetPlatform.fuchsia: SlideFromRightPageTransitionsBuilder(),
        },
      ),
    );
  }
}
