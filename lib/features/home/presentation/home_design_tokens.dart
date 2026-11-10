import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';

/// The Home surface's own palette — the owner's Home design spec.
///
/// These are **Home-scoped** values, deliberately not app theme tokens: they
/// resolve against the shared [TokiGoColors] roles in dark mode so Home stays
/// legible on the dark canvas rather than painting the light palette over it.
/// The light values follow the same Instagram-inspired identity as the rest of
/// the app (neutral surfaces, hairline borders), with one owner-decided
/// departure: Home's ink is black, not the brand blue.
///
/// The spec is a light-mode design. In dark mode each *role* resolves to the
/// active [TokiGoColors] value instead.
@immutable
abstract final class HomeDesignTokens {
  /// Home canvas (Instagram-inspired light neutral).
  static const Color background = Color(0xFFFAFAFA);

  /// Fill for a raised Home surface (search field, quick-action card).
  static const Color surface = Color(0xFFFFFFFF);

  /// Home ink — the leading search glyph, the quick-action glyphs and their
  /// labels, and the AI composer's actions.
  ///
  /// Owner decision (2026-11): Home's accent is NEUTRAL, not the brand blue —
  /// black on the light canvas, white on the dark one. The blue identity stays
  /// with the brand mark and the results surfaces; Home reads as a calm,
  /// content-first dashboard.
  static const Color accent = Color(0xFF000000);

  /// Search placeholder ink.
  static const Color hint = Color(0xFF8E8E8E);

  /// 1dp border on the search field and the quick-action cards.
  static const Color border = Color(0xFFDBDBDB);

  /// The canvas Home paints behind its chrome.
  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? context.tokigoColors.background : background;

  /// Fill for a raised Home surface.
  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? context.tokigoColors.surfaceElevated : surface;

  /// Home accent, resolved for the active brightness.
  static Color accentOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFFFFFFF) : accent;

  /// Border on a Home surface.
  static Color borderOf(BuildContext context) =>
      isDark(context) ? context.tokigoColors.hairline : border;

  /// The spec's placeholder ink in both modes.
  static Color hintOf(BuildContext context) => hint;

  /// Pressed fill for a quick-action card — a neutral grey, so the pressed
  /// state never reintroduces a coloured tint.
  static Color pressedSurfaceOf(BuildContext context) =>
      isDark(context) ? context.tokigoColors.surfaceSecondary : const Color(0xFFF5F5F5);

  /// Soft halo under the AI composer pill.
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
