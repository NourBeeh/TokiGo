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
/// canvas rather than painting light-mode beige over it.
@immutable
abstract final class HomeDesignTokens {
  /// Home canvas.
  static const Color background = Color(0xFFFAF8F5);

  /// Fill for a raised Home surface (search field, quick-action card).
  static const Color surface = Color(0xFFFFFFFF);

  /// Home accent — the leading search glyph, the card icons and their labels.
  ///
  /// Action Ink `#111111` (the DESIGN.md action-ink token), NOT a red: the
  /// service shortcuts are monochrome, and the same near-black keeps a 12pt
  /// label above 4.5:1 on the white tile in both themes.
  static const Color accent = Color(0xFF111111);

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

  /// Pressed fill for a quick-action card — a neutral grey, so the pressed
  /// state never reintroduces a coloured tint.
  static Color pressedSurfaceOf(BuildContext context) =>
      isDark(context) ? context.tokigoColors.surfaceSecondary : const Color(0xFFF5F5F5);

  /// Soft halo under the floating AI composer.
  ///
  /// A single low-opacity stop (blur 20, offset y 4) that works on both
  /// canvases: ink at 10% on the light page, black at 35% on the dark one.
  static List<BoxShadow> composerShadowOf(BuildContext context) => <BoxShadow>[
    BoxShadow(
      color: isDark(context)
          ? const Color(0x59000000)
          : const Color(0x1A111111),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
