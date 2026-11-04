import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';

/// The Home surface's own palette — the owner's Home design spec.
///
/// These are **Home-scoped** values, deliberately not app theme tokens: the
/// app's global palette stays white/ink ([TokiGoColors]) and Home is the one
/// surface carrying this warm, red-accented identity. Nothing here is wired
/// into [ThemeData], so no other screen can pick these up by accident.
///
/// The spec is a light-mode design. In dark mode each *role* resolves to the
/// active [TokiGoColors] value instead, so Home stays legible on the dark
/// canvas rather than painting light-mode beige over it — a 12pt label in the
/// spec red (#B22234) only reaches 2.6:1 on the dark surface, while the app's
/// dark accent clears 5:1.
@immutable
abstract final class HomeDesignTokens {
  /// Home canvas.
  static const Color background = Color(0xFFFAF8F5);

  /// Fill for a raised Home surface (search field, quick-action card).
  static const Color surface = Color(0xFFFFFFFF);

  /// Home accent — the leading search glyph, the card icons and their labels.
  static const Color accent = Color(0xFFB22234);

  /// Search placeholder ink.
  static const Color hint = Color(0xFF757575);

  /// 1dp border on the search field and the quick-action cards.
  static const Color border = Color(0xFFE0DCD6);

  /// The canvas Home paints behind its chrome.
  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? context.tokigoColors.background : background;

  /// Fill for a raised Home surface.
  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? context.tokigoColors.surfaceElevated : surface;

  /// Home accent, resolved for the active brightness.
  static Color accentOf(BuildContext context) =>
      isDark(context) ? context.tokigoColors.brand : accent;

  /// Border on a Home surface.
  static Color borderOf(BuildContext context) =>
      isDark(context) ? context.tokigoColors.hairline : border;

  /// The spec's placeholder ink in both modes.
  static Color hintOf(BuildContext context) => hint;

  /// Pressed fill for a quick-action card.
  static Color pressedSurfaceOf(BuildContext context) =>
      isDark(context) ? context.tokigoColors.surfaceSecondary : const Color(0xFFF5F2EE);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
