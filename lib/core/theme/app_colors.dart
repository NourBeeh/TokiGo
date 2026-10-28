import 'package:flutter/material.dart';

/// Central colour palette for TokiGo — "Pure White" luxury.
///
/// A light-only identity on a **pure white canvas**: the app surface is white,
/// and every card, sheet and bar is white too. Separation comes from LIGHT —
/// a 1px hairline ([hairline]) plus the two-stop halo in `AppElevation` —
/// never from a tinted background.
///
/// **There is no accent hue.** The palette is white, ink and grey; the only
/// colours left are semantic (success / warning / danger / info), and they are
/// state — never decoration. A rated star is ink ([starFill]); bronze/gold is
/// gone at the root (owner decision, 2026-10-20).
///
/// This is a design primitive. Consumers should reference these tokens and
/// let [AppTheme] map them onto the active [ThemeData] and [ColorScheme].
@immutable
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Action — the monochrome "brand" family.
  //
  // The indigo is retired: a primary action is ink/charcoal and nothing in the
  // chrome carries a hue. The names are kept because 30+ consumers read them as
  // *intent* ("the app's own action colour"); the values are now monochrome.
  // The wordmark keeps its own tokens ([brandRed], [wordmarkInk]) — the logo is
  // not chrome.
  // ---------------------------------------------------------------------------
  static const Color brand = Color(0xFF111111);
  static const Color onBrand = Colors.white;

  /// Deeper step for pressed states and subtle depth.
  static const Color brandDark = Color(0xFF000000);

  /// Lighter step (used where a brand tone sits on a dark fill / gradient).
  static const Color brandLight = Color(0xFF1A1A1A);

  static const Color brandContainer = Color(0xFFF5F5F5);
  static const Color onBrandContainer = Color(0xFF111111);

  // ---------------------------------------------------------------------------
  // Ink primitives
  // ---------------------------------------------------------------------------
  /// The loudest ink — primary buttons, display type.
  static const Color ink = Color(0xFF111111);

  /// The primary-button fill and the dark CTA bar.
  static const Color charcoal = Color(0xFF141414);
  static const Color charcoalPressed = Color(0xFF000000);

  /// A **rated** star. Ink, not a hue (17.40:1 on white).
  static const Color starFill = Color(0xFF1A1A1A);

  /// The unrated star outline (2.81:1 — graphic, always paired with
  /// [starFill] or with a numeric score that carries the meaning).
  static const Color starIdle = Color(0xFF9A9A9A);

  // ---------------------------------------------------------------------------
  // AI — no longer a colour
  // ---------------------------------------------------------------------------
  /// The AI signature is ink on paper. The token survives so AI surfaces have
  /// one name to reference; it deliberately resolves to the interface's own ink
  /// (the violet is retired).
  static const Color ai = Color(0xFF111111);
  static const Color aiLight = Color(0xFF6E6E6E);
  static const Color aiContainer = Color(0xFFFAFAFA);
  static const Color onAiContainer = Color(0xFF111111);

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
  static const Color classStar = Color(0xFF4A4A4A);
  // Wordmark ink — the neutral near-black of the "Toki" half.
  static const Color wordmarkInk = Color(0xFF2E2E2E);
  // Brand red — the "Go" in the TokiGo wordmark (single source of truth).
  static const Color brandRed = Color(0xFFFF2D2D);
  static const Color info = Color(0xFF0284C7);
  static const Color infoContainer = Color(0xFFE3F2FB);

  // -----------------------------------------------------------------------------
  // Light surfaces — pure white
  // -----------------------------------------------------------------------------
  /// The app canvas: pure white. Cards and sheets are white too, so the
  /// separator is [hairline] + the halo shadow — never a tinted background.
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Colors.white;

  /// A neutral inset well (search fields, quiet blocks, selected states).
  static const Color surfaceSecondary = Color(0xFFFAFAFA);

  /// Skeletons, image placeholders, disabled fills.
  static const Color surfaceTertiary = Color(0xFFF5F5F5);

  /// The default 1px border on white — ink at 6%.
  static const Color hairline = Color(0x0F1A1A1A);

  /// Focus rings and dense dividers — ink at 12%.
  static const Color hairlineStrong = Color(0x1F1A1A1A);

  /// The 4px focus halo around a focused field.
  static const Color focusRing = Color(0x0A111111);

  /// Card and field borders (the same value as [hairline]; kept under its
  /// long-standing name so layout code reads naturally).
  static const Color outline = Color(0x0F1A1A1A);
  static const Color divider = Color(0x0F1A1A1A);
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
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6E6E6E);
  static const Color textTertiary = Color(0xFF9B9B9B);
  static const Color textOnSurface = Color(0xFFFFFFFF);

  // -----------------------------------------------------------------------------
  // Dark bottom action bar (the detail / checkout bar)
  // -----------------------------------------------------------------------------
  /// The charcoal bar pinned under a detail surface. A COMPONENT colour, not
  /// a theme: the app stays light-only, there is no dark variant.
  static const Color ctaBar = Color(0xFF141414);

  /// Primary ink inside [ctaBar] (the price, the dates).
  static const Color onCtaBar = Color(0xFFFFFFFF);

  /// Secondary ink inside [ctaBar] (the muted line above the price).
  static const Color onCtaBarVariant = Color(0xFFBFB5AC);

  /// The inverted button inside [ctaBar].
  static const Color ctaBarButton = Color(0xFFFFFFFF);

  /// Its label.
  static const Color onCtaBarButton = Color(0xFF1A1A1A);

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
  static const Color flightHue = Color(0xFF111111);
  static const Color hotelHue = Color(0xFF111111);
  static const Color carHue = Color(0xFF111111);
  static const Color packageHue = Color(0xFF111111);
  static const Color exploreHue = Color(0xFF111111);
  static const Color groupsHue = Color(0xFF111111);

  /// Paired containers for the search service tiles — white, like every tile.
  static const Color flightContainer = Color(0xFFFFFFFF);
  static const Color hotelContainer = Color(0xFFFFFFFF);
  static const Color carContainer = Color(0xFFFFFFFF);
  static const Color packageContainer = Color(0xFFFFFFFF);
}
