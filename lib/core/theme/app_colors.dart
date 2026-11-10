import 'package:flutter/material.dart';

/// Central colour palette for TokiGo — "Clean Light", Instagram-inspired.
///
/// A light identity on a **near-white canvas**: the app surface is #FAFAFA and
/// cards/sheets are white. Separation comes from LIGHT — a 1px hairline
/// ([hairline]) plus the two-stop halo in `AppElevation` — never from a tinted
/// background. The accent is the brand blue [brand] (#0064E0), with a small
/// purple→red→orange gradient reserved for the AI accents.
///
/// The remaining hues are semantic (success / warning / danger / info) and are
/// state — never decoration. A rated star is ink ([starFill]); bronze/gold is
/// gone at the root (owner decision, 2026-10-20).
///
/// This is a design primitive. Consumers should reference these tokens and
/// let [AppTheme] map them onto the active [ThemeData] and [ColorScheme].
@immutable
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Action — the brand family.
  //
  // The brand is the Instagram-inspired blue #0064E0. The wordmark keeps its
  // own tokens ([brandRed], [wordmarkInk]) — the logo is not chrome.
  // ---------------------------------------------------------------------------
  static const Color brand = Color(0xFF0064E0);
  static const Color onBrand = Colors.white;

  /// Deeper step for pressed states and subtle depth.
  static const Color brandDark = Color(0xFF0051B3);

  /// Lighter step (used where a brand tone sits on a dark fill / gradient).
  static const Color brandLight = Color(0xFF3D8BEC);

  static const Color brandContainer = Color(0xFFE7F3FE);
  static const Color onBrandContainer = Color(0xFF005A9E);

  // ---------------------------------------------------------------------------
  // Ink primitives
  // ---------------------------------------------------------------------------
  /// The loudest ink — primary buttons, display type.
  static const Color ink = Color(0xFF262626);

  /// The primary-button fill and the dark CTA bar.
  static const Color charcoal = Color(0xFF121212);
  static const Color charcoalPressed = Color(0xFF000000);

  /// A **rated** star. Ink, not a hue (17.40:1 on white).
  static const Color starFill = Color(0xFF262626);

  /// The unrated star outline.
  static const Color starIdle = Color(0xFF8E8E8E);

  // ---------------------------------------------------------------------------
  // AI — brand blue.
  // ---------------------------------------------------------------------------
  /// The AI signature is the brand blue on a soft container. The token survives
  /// so AI surfaces have one name to reference.
  static const Color ai = Color(0xFF0064E0);
  static const Color aiLight = Color(0xFF737373);
  static const Color aiContainer = Color(0xFFF5F5F5);
  static const Color onAiContainer = Color(0xFF262626);

  // ---------------------------------------------------------------------------
  // Semantic / feedback (the only hues in the system)
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF16A34A);
  static const Color successContainer = Color(0xFFE5F6EC);

  /// The green that carries WHITE text — the rating badge above all.
  ///
  /// [success] #16A34A with white measures 3.4:1 and fails AA, so anything that
  /// paints a white numeral on green uses this darker step instead (5.0:1).
  /// Keep [success] for green text on a light container.
  static const Color successStrong = Color(0xFF15803D);

  /// AA-passing green for text ON [successContainer] (6.4:1).
  /// [success] itself is only 2.9:1 there.
  static const Color onSuccessContainer = Color(0xFF166534);
  static const Color warning = Color(0xFFD97706);
  static const Color warningContainer = Color(0xFFFCF1E3);

  /// AA-passing amber for text ON [warningContainer] (6.4:1).
  /// [warning] itself is only 2.9:1 there.
  static const Color onWarningContainer = Color(0xFF92400E);

  /// Warning text on WHITE (5.02:1).
  static const Color warningInk = Color(0xFFB45309);
  static const Color danger = Color(0xFFE11D48);
  static const Color dangerContainer = Color(0xFFFCEAEF);

  /// The favourite heart fill. Same tone as [danger] — named for what it is,
  /// so a card never has to reach for a semantic token to paint a heart.
  static const Color heart = Color(0xFFE11D48);

  /// Class stars on the discover card — deliberately grey, not bronze: they
  /// describe the property's class, not the guest score.
  static const Color classStar = Color(0xFF8E8E8E);
  // Wordmark ink — the "Toki" half. Kept at its own near-black (#111111) so
  // the logo raster and the in-app mark never drift from the shipped branding
  // assets; the app's text ink is [ink].
  static const Color wordmarkInk = Color(0xFF111111);
  // Brand red — the "Go" in the TokiGo wordmark (single source of truth).
  static const Color brandRed = Color(0xFFFF2D2D);
  static const Color info = Color(0xFF0064E0);
  static const Color infoContainer = Color(0xFFE7F3FE);

  // -----------------------------------------------------------------------------
  // Light surfaces — pure white
  // -----------------------------------------------------------------------------
  /// The app canvas: pure white. Cards and sheets are white too, so the
  /// separator is [hairline] + the halo shadow — never a tinted background.
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;

  /// A neutral inset well (search fields, quiet blocks, selected states).
  static const Color surfaceSecondary = Color(0xFFF5F5F5);

  /// Skeletons, image placeholders, disabled fills.
  static const Color surfaceTertiary = Color(0xFFEFEFEF);

  /// The default 1px border on white.
  static const Color hairline = Color(0xFFEFEFEF);

  /// Focus rings and dense dividers.
  static const Color hairlineStrong = Color(0xFFDBDBDB);

  /// The 4px focus halo around a focused field.
  static const Color focusRing = Color(0x1F0064E0);

  /// Card and field borders (the same value as [hairline]; kept under its
  /// long-standing name so layout code reads naturally).
  static const Color outline = Color(0xFFDBDBDB);
  static const Color divider = Color(0xFFEFEFEF);
  static const Color overlay = Color(0x14000000); // scrim / focused overlay

  // -----------------------------------------------------------------------------
  // On-media — overlays that sit on arbitrary photography (image-first cards)
  // -----------------------------------------------------------------------------
  /// Primary text/icon on a photo scrim (titles, prices).
  static const Color onMedia = Color(0xFFFFFFFF);

  /// Secondary text on a photo scrim (subtitles, captions, review counts).
  static const Color onMediaVariant = Color(0xB3FFFFFF);

  /// Hairline borders on a photo scrim (pill outlines).
  static const Color onMediaBorder = Color(0x40FFFFFF);

  /// Solid frosted-white fill for the controls pinned over a photo (the nav
  /// discs on a hero header). One UI's floating back control is a translucent
  /// white disc whose edge comes from a soft diffuse shadow — not from a
  /// border — so this fill is deliberately *not* opaque.
  static const Color onMediaFill = Color(0xEBFFFFFF);

  /// Frosted-white fill for glass badges placed over a photo.
  static const Color glassFill = Color(0x24FFFFFF);

  /// Dark glass tint for on-image pills (rating pill over a photo).
  static const Color glassTint = Color(0x73000000);

  /// The wordmark's "Go" over photography: a light brand tint that keeps the
  /// logo legible on the hero scrim (the pure red is too low-contrast there).
  static const Color wordmarkOnMedia = Color(0xFFFFC9C9);

  /// Soft shadow behind white labels placed directly on photography.
  static const Color onMediaTextShadow = Color(0x99000000);

  /// Soft top scrim on a hero photo (under the pinned action bar).
  static const Color scrimSoft = Color(0x33000000);

  /// Stronger bottom scrim on a hero photo (keeps the action bar legible).
  static const Color scrimStrong = Color(0x40000000);

  // Text
  static const Color textPrimary = Color(0xFF262626);
  static const Color textSecondary = Color(0xFF737373);
  static const Color textTertiary = Color(0xFF8E8E8E);
  static const Color textOnSurface = Color(0xFFFFFFFF);

  // -----------------------------------------------------------------------------
  // Dark bottom action bar (the detail / checkout bar)
  // -----------------------------------------------------------------------------
  /// The charcoal bar pinned under a detail surface. A COMPONENT colour, not
  /// a theme: the app stays light-only, there is no dark variant.
  static const Color ctaBar = Color(0xFF121212);

  /// Primary ink inside [ctaBar] (the price, the dates).
  static const Color onCtaBar = Color(0xFFFFFFFF);

  /// Secondary ink inside [ctaBar] (the muted line above the price).
  static const Color onCtaBarVariant = Color(0xFFA8A8A8);

  /// The inverted button inside [ctaBar].
  static const Color ctaBarButton = Color(0xFFFFFFFF);

  /// Its label.
  static const Color onCtaBarButton = Color(0xFF262626);

  /// The bottom gradient under a hero photo (photo scrim).
  static const Color photoScrim = Color(0x73000000);

  // -----------------------------------------------------------------------------
  // Feature hues — RETIRED from the chrome.
  //
  // The Home nav tiles are white with ink glyphs (owner decision, 2026-10-20),
  // so the per-vertical hues and their containers no longer paint anything.
  // The names survive because routing and the admin read them as *identities*
  // (a vertical still has an id); the values are monochrome.
  // -----------------------------------------------------------------------------
  static const Color flightHue = Color(0xFF0064E0);
  static const Color hotelHue = Color(0xFF0064E0);
  static const Color carHue = Color(0xFF0064E0);
  static const Color packageHue = Color(0xFF0064E0);
  static const Color exploreHue = Color(0xFF0064E0);
  static const Color groupsHue = Color(0xFF0064E0);

  /// Paired containers for the search service tiles.
  static const Color flightContainer = Color(0xFFE7F3FE);
  static const Color hotelContainer = Color(0xFFE7F3FE);
  static const Color carContainer = Color(0xFFE7F3FE);
  static const Color packageContainer = Color(0xFFE7F3FE);
}
