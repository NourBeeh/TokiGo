import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_elevation.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// Builds the central light-only [ThemeData] for TokiGo.
///
/// "Pure White Premium": stark white canvas, crisp hairline borders, soft
/// diffused shadows, and a royal indigo primary mapped through the full
/// Material 3 [ColorScheme]. There is intentionally no dark variant.
@immutable
abstract final class AppTheme {
  static ThemeData light() {
    final tokens = AppTokens.standard();
    final palette = tokens.colors;
    final typography = AppTypography.forLight();

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.brand,
      onPrimary: AppColors.onBrand,
      primaryContainer: AppColors.brandContainer,
      onPrimaryContainer: AppColors.onBrandContainer,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.accentContainer,
      onSecondaryContainer: AppColors.onAccentContainer,
      tertiary: AppColors.ai,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.aiContainer,
      onTertiaryContainer: AppColors.onAiContainer,
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
      inversePrimary: AppColors.brandLight,
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
      visualDensity: VisualDensity.adaptivePlatformDensity,
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
      ),
      dividerTheme: DividerThemeData(color: palette.divider, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.onBrand,
          disabledBackgroundColor: AppColors.surfaceTertiary,
          disabledForegroundColor: AppColors.textTertiary,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
          textStyle: typography.bodyLargeMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          side: const BorderSide(color: AppColors.brand),
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
          textStyle: typography.bodyLargeMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          textStyle: typography.bodyLargeMedium,
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
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
        hintStyle: typography.bodyMedium.copyWith(color: palette.textTertiary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: AppColors.brandContainer,
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
    );
  }
}
