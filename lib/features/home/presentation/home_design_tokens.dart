import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_elevation.dart';
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
  /// Owner decision (2026-11): Home's accent is the THEME's own brand ink —
  /// #111111 on the light canvas, #F5F5F5 on the dark one — so Home carries no
  /// second near-black. Resolve it with [accentOf]; this constant is only the
  /// light fallback for hosts without a [TokiGoColors] extension.
  static const Color accent = Color(0xFF111111);

  /// Search placeholder ink — the theme's own [TokiGoColors.textTertiary]
  /// (#6E6E6E light / #8E8E8E dark). Resolve it with [hintOf].
  static const Color hint = Color(0xFF6E6E6E);

  /// 1dp border on the search field and the quick-action cards.
  static const Color border = Color(0xFFDBDBDB);

  /// The canvas Home paints behind its chrome.
  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? context.tokigoColors.background : background;

  /// Fill for a raised Home surface.
  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? context.tokigoColors.surfaceElevated : surface;

  /// Home accent, resolved for the active brightness.
  static Color accentOf(BuildContext context) => context.tokigoColors.brand;

  /// Border on a Home surface.
  static Color borderOf(BuildContext context) =>
      isDark(context) ? context.tokigoColors.hairline : border;

  /// The theme's placeholder ink for the active brightness.
  static Color hintOf(BuildContext context) =>
      context.tokigoColors.textTertiary;

  /// Pressed fill for a quick-action card — a neutral grey, so the pressed
  /// state never reintroduces a coloured tint.
  static Color pressedSurfaceOf(BuildContext context) => isDark(context)
      ? context.tokigoColors.surfaceSecondary
      : const Color(0xFFF5F5F5);

  /// Soft halo under the AI composer pill.
  ///
  /// Light theme is FLAT: the pill's edge comes from the surface step against
  /// the canvas, not from a shadow. The halo is drawn only on the dark canvas,
  /// where a white pill would otherwise have no separation at all.
  static List<BoxShadow> composerShadowOf(BuildContext context) =>
      AppElevation.darkOnly(
        context,
        background: surface,
        level: AppElevation.lg,
      );

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
