import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography scale for TokiGo.
///
/// A premium, travel-magazine type system built on Manrope (Latin) with
/// Cairo as the Arabic counterpart. Variable fonts are bundled, so every
/// weight from 400-800 renders without extra assets.
@immutable
class AppTypography {
  const AppTypography._({
    required this.textColor,
    required this.textMutedColor,
  });

  const AppTypography.forLight()
      : textColor = AppColors.textPrimary,
        textMutedColor = AppColors.textSecondary;

  final Color textColor;
  final Color textMutedColor;

  // ---------------------------------------------------------------------------
  // Font families
  // ---------------------------------------------------------------------------
  static const String fontFamily = 'Manrope';
  static const String fontFamilyFallback = 'Cairo';

  // ---------------------------------------------------------------------------
  // Font sizes
  // ---------------------------------------------------------------------------
  static const double fontSizeDisplay = 34;
  static const double fontSizeHeadline = 28;
  static const double fontSizeTitle = 22;
  static const double fontSizeBodyLarge = 17;
  static const double fontSizeBody = 15;
  static const double fontSizeCaption = 13;
  static const double fontSizeLabel = 11;

  // ---------------------------------------------------------------------------
  // Weights
  // ---------------------------------------------------------------------------
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemibold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;
  static const FontWeight weightExtraBold = FontWeight.w800;

  /// Tracks whether the active session renders Arabic copy (RTL) so the type
  /// system can swap to Cairo. Set by the app's locale observer.
  static bool _isArabicLocale = false;

  // ignore: avoid_setters_without_getters
  static set isArabicLocale(bool value) => _isArabicLocale = value;

  TextStyle _style({
    required double size,
    required FontWeight weight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    final isArabic = _isArabicLocale;
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? textColor,
      height: height,
      letterSpacing: isArabic ? 0 : letterSpacing,
      fontFamily: isArabic ? fontFamilyFallback : fontFamily,
      fontFamilyFallback: const <String>['Manrope', 'Cairo', '.SF Pro Text', 'Roboto'],
    );
  }

  TextStyle get display => _style(size: fontSizeDisplay, weight: weightExtraBold, height: 1.12, letterSpacing: -0.5);
  TextStyle get headline => _style(size: fontSizeHeadline, weight: weightBold, height: 1.18, letterSpacing: -0.4);
  TextStyle get title => _style(size: fontSizeTitle, weight: weightSemibold, height: 1.25, letterSpacing: -0.2);
  TextStyle get bodyLarge => _style(size: fontSizeBodyLarge, weight: weightRegular, height: 1.4);
  TextStyle get bodyLargeMedium =>
      _style(size: fontSizeBodyLarge, weight: weightSemibold, height: 1.35);
  TextStyle get body => _style(size: fontSizeBody, weight: weightRegular, height: 1.4);
  TextStyle get bodyMedium => _style(size: fontSizeBody, weight: weightMedium, height: 1.35);
  TextStyle get caption => _style(size: fontSizeCaption, weight: weightRegular, height: 1.3);
  TextStyle get captionSemibold =>
      _style(size: fontSizeCaption, weight: weightSemibold, height: 1.3);
  TextStyle get label => _style(
        size: fontSizeLabel,
        weight: weightSemibold,
        color: textMutedColor,
        height: 1.2,
        letterSpacing: 0.3,
      );

  /// Builds a full [TextTheme] wired to the active palette.
  TextTheme buildTextTheme() {
    return TextTheme(
      displayLarge: display.copyWith(color: textColor),
      displayMedium: headline.copyWith(color: textColor),
      displaySmall: title.copyWith(color: textColor),
      headlineLarge: headline.copyWith(color: textColor),
      headlineMedium: title.copyWith(color: textColor),
      headlineSmall: bodyLarge.copyWith(color: textColor),
      titleLarge: title.copyWith(color: textColor),
      titleMedium: bodyLargeMedium.copyWith(color: textColor),
      titleSmall: bodyMedium.copyWith(color: textColor),
      bodyLarge: bodyLarge.copyWith(color: textColor),
      bodyMedium: body.copyWith(color: textColor),
      bodySmall: caption.copyWith(color: textColor),
      labelLarge: bodyMedium.copyWith(color: textColor),
      labelMedium: captionSemibold.copyWith(color: textMutedColor),
      labelSmall: label.copyWith(color: textMutedColor),
    );
  }
}
