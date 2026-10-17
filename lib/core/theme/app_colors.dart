import 'package:flutter/material.dart';

/// Central colour palette for TokiGo — "Pure White Premium".
///
/// A crisp, light-only identity: stark white canvas, royal electric indigo
/// primary, near-black ink text, and two reserved accents — warm gold for
/// offers/luxury cues and electric violet for AI surfaces only.
///
/// This is a design primitive. Consumers should reference these tokens and
/// let [AppTheme] map them onto the active [ThemeData] and [ColorScheme].
@immutable
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Brand — royal electric indigo
  // ---------------------------------------------------------------------------
  static const Color brand = Color(0xFF2B4EFF);
  static const Color onBrand = Colors.white;

  /// Darker brand step for pressed states and subtle depth.
  static const Color brandDark = Color(0xFF1E38C7);
  static const Color brandLight = Color(0xFF5A78FF);

  static const Color brandContainer = Color(0xFFE9EEFF);
  static const Color onBrandContainer = Color(0xFF14267A);

  // ---------------------------------------------------------------------------
  // Accent — warm gold (offers / luxury cues only)
  // ---------------------------------------------------------------------------
  static const Color accent = Color(0xFFC99A3C);
  static const Color accentContainer = Color(0xFFFBF3E2);
  static const Color onAccentContainer = Color(0xFF5C4413);

  // ---------------------------------------------------------------------------
  // AI signature — electric violet (AI surfaces only)
  // ---------------------------------------------------------------------------
  static const Color ai = Color(0xFF7C5CFF);
  static const Color aiLight = Color(0xFFA38DFF);
  static const Color aiContainer = Color(0xFFEFEAFF);
  static const Color onAiContainer = Color(0xFF2A1B6B);

  // ---------------------------------------------------------------------------
  // Semantic / feedback
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF16A34A);
  static const Color successContainer = Color(0xFFE5F6EC);
  static const Color warning = Color(0xFFD97706);
  static const Color warningContainer = Color(0xFFFCF1E3);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerContainer = Color(0xFFFDEAEA);
  static const Color info = Color(0xFF0284C7);
  static const Color infoContainer = Color(0xFFE3F2FB);

  // -----------------------------------------------------------------------------
  // Light surfaces — pure white premium
  // -----------------------------------------------------------------------------
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color surfaceSecondary = Color(0xFFF7F8FA);
  static const Color surfaceTertiary = Color(0xFFEFF1F5);
  static const Color outline = Color(0xFFE6E8EE);
  static const Color divider = Color(0xFFEDEEF2);
  static const Color overlay = Color(0x14000000); // scrim / focused overlay

  // Text
  static const Color textPrimary = Color(0xFF0F1B2D);
  static const Color textSecondary = Color(0xFF5A6474);
  static const Color textTertiary = Color(0xFF98A0B0);
  static const Color textOnSurface = Color(0xFFFFFFFF);

  // -----------------------------------------------------------------------------
  // Feature hues (search headers / category accents)
  // -----------------------------------------------------------------------------
  static const Color flightHue = Color(0xFF2B4EFF);
  static const Color hotelHue = Color(0xFFB85C3F);
  static const Color carHue = Color(0xFF0E8A7B);
  static const Color packageHue = Color(0xFF7C5CFF);
  static const Color exploreHue = Color(0xFF0284C7);
  static const Color groupsHue = Color(0xFF16A34A);
}
