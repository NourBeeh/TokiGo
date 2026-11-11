import 'package:flutter/material.dart';

/// Centralized, theme-aware colour tokens for TokiGo.
///
/// Replaces the static [AppColors] palette with a [ThemeExtension] so every
/// surface can resolve the correct value for the active brightness. The
/// existing [AppColors] constants are retained for backward compatibility
/// (light values) and will be migrated incrementally.
///
/// **The accent is NEUTRAL** in both palettes: the primary action fill is the
/// canvas's own ink (near-black on the light canvas, near-white on the dark
/// one), never a hue. Only semantic status colours carry a hue.
@immutable
class TokiGoColors extends ThemeExtension<TokiGoColors> {
  const TokiGoColors({
    required this.background,
    required this.surface,
    required this.surfaceSecondary,
    required this.surfaceTertiary,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnSurface,
    required this.outline,
    required this.divider,
    required this.hairline,
    required this.hairlineStrong,
    required this.focusRing,
    required this.overlay,
    required this.brand,
    required this.onBrand,
    required this.brandContainer,
    required this.onBrandContainer,
    required this.ink,
    required this.charcoal,
    required this.charcoalPressed,
    required this.starFill,
    required this.starIdle,
    required this.ai,
    required this.aiLight,
    required this.aiContainer,
    required this.onAiContainer,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.successStrong,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.warningInk,
    required this.danger,
    required this.dangerContainer,
    required this.heart,
    required this.classStar,
    required this.wordmarkInk,
    required this.brandRed,
    required this.info,
    required this.infoContainer,
    required this.onMedia,
    required this.onMediaVariant,
    required this.onMediaBorder,
    required this.onMediaFill,
    required this.glassFill,
    required this.glassTint,
    required this.wordmarkOnMedia,
    required this.onMediaTextShadow,
    required this.scrimSoft,
    required this.scrimStrong,
    required this.photoScrim,
    required this.ctaBar,
    required this.onCtaBar,
    required this.onCtaBarVariant,
    required this.ctaBarButton,
    required this.onCtaBarButton,
  });

  // ---- Light palette (neutral) ----
  factory TokiGoColors.light() => const TokiGoColors(
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFF5F5F5),
    surfaceTertiary: Color(0xFFEFEFEF),
    surfaceElevated: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF262626),
    textSecondary: Color(0xFF737373),
    textTertiary: Color(0xFF8E8E8E),
    textOnSurface: Color(0xFFFFFFFF),
    outline: Color(0xFFDBDBDB),
    divider: Color(0xFFEFEFEF),
    hairline: Color(0xFFEFEFEF),
    hairlineStrong: Color(0xFFDBDBDB),
    focusRing: Color(0x1F111111),
    overlay: Color(0x14000000),
    brand: Color(0xFF111111),
    onBrand: Color(0xFFFFFFFF),
    brandContainer: Color(0xFFF0F0F0),
    onBrandContainer: Color(0xFF111111),
    ink: Color(0xFF262626),
    charcoal: Color(0xFF121212),
    charcoalPressed: Color(0xFF000000),
    starFill: Color(0xFF262626),
    starIdle: Color(0xFF8E8E8E),
    ai: Color(0xFF111111),
    aiLight: Color(0xFF737373),
    aiContainer: Color(0xFFF5F5F5),
    onAiContainer: Color(0xFF262626),
    success: Color(0xFF16A34A),
    successContainer: Color(0xFFE5F6EC),
    onSuccessContainer: Color(0xFF166534),
    successStrong: Color(0xFF15803D),
    warning: Color(0xFFD97706),
    warningContainer: Color(0xFFFCF1E3),
    onWarningContainer: Color(0xFF92400E),
    warningInk: Color(0xFFB45309),
    danger: Color(0xFFE11D48),
    dangerContainer: Color(0xFFFCEAEF),
    heart: Color(0xFFE11D48),
    classStar: Color(0xFF8E8E8E),
    wordmarkInk: Color(0xFF111111),
    brandRed: Color(0xFFFF2D2D),
    info: Color(0xFF262626),
    infoContainer: Color(0xFFF0F0F0),
    onMedia: Color(0xFFFFFFFF),
    onMediaVariant: Color(0xB3FFFFFF),
    onMediaBorder: Color(0x40FFFFFF),
    onMediaFill: Color(0xEBFFFFFF),
    glassFill: Color(0x24FFFFFF),
    glassTint: Color(0x73000000),
    wordmarkOnMedia: Color(0xFFFFC9C9),
    onMediaTextShadow: Color(0x99000000),
    scrimSoft: Color(0x33000000),
    scrimStrong: Color(0x40000000),
    photoScrim: Color(0x73000000),
    ctaBar: Color(0xFF121212),
    onCtaBar: Color(0xFFFFFFFF),
    onCtaBarVariant: Color(0xFFA8A8A8),
    ctaBarButton: Color(0xFFFFFFFF),
    onCtaBarButton: Color(0xFF262626),
  );

  // ---- Dark palette (neutral) ----
  factory TokiGoColors.dark() => const TokiGoColors(
    background: Color(0xFF000000),
    surface: Color(0xFF121212),
    surfaceSecondary: Color(0xFF1E1E1E),
    surfaceTertiary: Color(0xFF262626),
    surfaceElevated: Color(0xFF1E1E1E),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFA8A8A8),
    textTertiary: Color(0xFF8E8E8E),
    textOnSurface: Color(0xFF000000),
    outline: Color(0xFF262626),
    divider: Color(0xFF262626),
    hairline: Color(0xFF262626),
    hairlineStrong: Color(0xFF363636),
    focusRing: Color(0x33F5F5F5),
    overlay: Color(0x40000000),
    // The dark canvas's own ink is the light one: the primary action fill is
    // near-white so it reads as a filled action on the black page.
    brand: Color(0xFFF5F5F5),
    onBrand: Color(0xFF000000),
    brandContainer: Color(0xFF262626),
    onBrandContainer: Color(0xFFF5F5F5),
    ink: Color(0xFFF5F5F5),
    charcoal: Color(0xFF000000),
    charcoalPressed: Color(0xFF000000),
    starFill: Color(0xFFF5F5F5),
    starIdle: Color(0xFF8E8E8E),
    ai: Color(0xFFF5F5F5),
    aiLight: Color(0xFFA8A8A8),
    aiContainer: Color(0xFF1E1E1E),
    onAiContainer: Color(0xFFF5F5F5),
    success: Color(0xFF22C55E),
    successContainer: Color(0xFF0F2A1A),
    onSuccessContainer: Color(0xFF86EFAC),
    successStrong: Color(0xFF16A34A),
    warning: Color(0xFFFBBF24),
    warningContainer: Color(0xFF2A1F0A),
    onWarningContainer: Color(0xFFFCD34D),
    warningInk: Color(0xFFFBBF24),
    danger: Color(0xFFF43F5E),
    dangerContainer: Color(0xFF2A0F1A),
    heart: Color(0xFFF43F5E),
    classStar: Color(0xFFA8A8A8),
    wordmarkInk: Color(0xFFF5F5F5),
    brandRed: Color(0xFFFF5C5C),
    info: Color(0xFFF5F5F5),
    infoContainer: Color(0xFF262626),
    onMedia: Color(0xFFFFFFFF),
    onMediaVariant: Color(0xB3FFFFFF),
    onMediaBorder: Color(0x40FFFFFF),
    onMediaFill: Color(0xEBFFFFFF),
    glassFill: Color(0x24FFFFFF),
    glassTint: Color(0x73000000),
    wordmarkOnMedia: Color(0xFFFFC9C9),
    onMediaTextShadow: Color(0x99000000),
    scrimSoft: Color(0x33000000),
    scrimStrong: Color(0x40000000),
    photoScrim: Color(0x73000000),
    ctaBar: Color(0xFF121212),
    onCtaBar: Color(0xFFFFFFFF),
    onCtaBarVariant: Color(0xFFA8A8A8),
    // The inverted button inside the charcoal bar — the canvas ink, so the
    // bar's own action is neutral rather than a hue.
    ctaBarButton: Color(0xFFF5F5F5),
    onCtaBarButton: Color(0xFF262626),
  );

  final Color background;
  final Color surface;
  final Color surfaceSecondary;
  final Color surfaceTertiary;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnSurface;
  final Color outline;
  final Color divider;
  final Color hairline;
  final Color hairlineStrong;
  final Color focusRing;
  final Color overlay;
  final Color brand;
  final Color onBrand;
  final Color brandContainer;
  final Color onBrandContainer;
  final Color ink;
  final Color charcoal;
  final Color charcoalPressed;
  final Color starFill;
  final Color starIdle;
  final Color ai;
  final Color aiLight;
  final Color aiContainer;
  final Color onAiContainer;
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color successStrong;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color warningInk;
  final Color danger;
  final Color dangerContainer;
  final Color heart;
  final Color classStar;
  final Color wordmarkInk;
  final Color brandRed;
  final Color info;
  final Color infoContainer;
  final Color onMedia;
  final Color onMediaVariant;
  final Color onMediaBorder;
  final Color onMediaFill;
  final Color glassFill;
  final Color glassTint;
  final Color wordmarkOnMedia;
  final Color onMediaTextShadow;
  final Color scrimSoft;
  final Color scrimStrong;
  final Color photoScrim;
  final Color ctaBar;
  final Color onCtaBar;
  final Color onCtaBarVariant;
  final Color ctaBarButton;
  final Color onCtaBarButton;

  @override
  TokiGoColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSecondary,
    Color? surfaceTertiary,
    Color? surfaceElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textOnSurface,
    Color? outline,
    Color? divider,
    Color? hairline,
    Color? hairlineStrong,
    Color? focusRing,
    Color? overlay,
    Color? brand,
    Color? onBrand,
    Color? brandContainer,
    Color? onBrandContainer,
    Color? ink,
    Color? charcoal,
    Color? charcoalPressed,
    Color? starFill,
    Color? starIdle,
    Color? ai,
    Color? aiLight,
    Color? aiContainer,
    Color? onAiContainer,
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? successStrong,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? warningInk,
    Color? danger,
    Color? dangerContainer,
    Color? heart,
    Color? classStar,
    Color? wordmarkInk,
    Color? brandRed,
    Color? info,
    Color? infoContainer,
    Color? onMedia,
    Color? onMediaVariant,
    Color? onMediaBorder,
    Color? onMediaFill,
    Color? glassFill,
    Color? glassTint,
    Color? wordmarkOnMedia,
    Color? onMediaTextShadow,
    Color? scrimSoft,
    Color? scrimStrong,
    Color? photoScrim,
    Color? ctaBar,
    Color? onCtaBar,
    Color? onCtaBarVariant,
    Color? ctaBarButton,
    Color? onCtaBarButton,
  }) {
    return TokiGoColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      surfaceTertiary: surfaceTertiary ?? this.surfaceTertiary,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textOnSurface: textOnSurface ?? this.textOnSurface,
      outline: outline ?? this.outline,
      divider: divider ?? this.divider,
      hairline: hairline ?? this.hairline,
      hairlineStrong: hairlineStrong ?? this.hairlineStrong,
      focusRing: focusRing ?? this.focusRing,
      overlay: overlay ?? this.overlay,
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      brandContainer: brandContainer ?? this.brandContainer,
      onBrandContainer: onBrandContainer ?? this.onBrandContainer,
      ink: ink ?? this.ink,
      charcoal: charcoal ?? this.charcoal,
      charcoalPressed: charcoalPressed ?? this.charcoalPressed,
      starFill: starFill ?? this.starFill,
      starIdle: starIdle ?? this.starIdle,
      ai: ai ?? this.ai,
      aiLight: aiLight ?? this.aiLight,
      aiContainer: aiContainer ?? this.aiContainer,
      onAiContainer: onAiContainer ?? this.onAiContainer,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      successStrong: successStrong ?? this.successStrong,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      warningInk: warningInk ?? this.warningInk,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      heart: heart ?? this.heart,
      classStar: classStar ?? this.classStar,
      wordmarkInk: wordmarkInk ?? this.wordmarkInk,
      brandRed: brandRed ?? this.brandRed,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      onMedia: onMedia ?? this.onMedia,
      onMediaVariant: onMediaVariant ?? this.onMediaVariant,
      onMediaBorder: onMediaBorder ?? this.onMediaBorder,
      onMediaFill: onMediaFill ?? this.onMediaFill,
      glassFill: glassFill ?? this.glassFill,
      glassTint: glassTint ?? this.glassTint,
      wordmarkOnMedia: wordmarkOnMedia ?? this.wordmarkOnMedia,
      onMediaTextShadow: onMediaTextShadow ?? this.onMediaTextShadow,
      scrimSoft: scrimSoft ?? this.scrimSoft,
      scrimStrong: scrimStrong ?? this.scrimStrong,
      photoScrim: photoScrim ?? this.photoScrim,
      ctaBar: ctaBar ?? this.ctaBar,
      onCtaBar: onCtaBar ?? this.onCtaBar,
      onCtaBarVariant: onCtaBarVariant ?? this.onCtaBarVariant,
      ctaBarButton: ctaBarButton ?? this.ctaBarButton,
      onCtaBarButton: onCtaBarButton ?? this.onCtaBarButton,
    );
  }

  @override
  TokiGoColors lerp(ThemeExtension<TokiGoColors>? other, double t) {
    if (other is! TokiGoColors) return this;
    return TokiGoColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSecondary: Color.lerp(
        surfaceSecondary,
        other.surfaceSecondary,
        t,
      )!,
      surfaceTertiary: Color.lerp(surfaceTertiary, other.surfaceTertiary, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textOnSurface: Color.lerp(textOnSurface, other.textOnSurface, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      hairlineStrong: Color.lerp(hairlineStrong, other.hairlineStrong, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandContainer: Color.lerp(brandContainer, other.brandContainer, t)!,
      onBrandContainer: Color.lerp(
        onBrandContainer,
        other.onBrandContainer,
        t,
      )!,
      ink: Color.lerp(ink, other.ink, t)!,
      charcoal: Color.lerp(charcoal, other.charcoal, t)!,
      charcoalPressed: Color.lerp(charcoalPressed, other.charcoalPressed, t)!,
      starFill: Color.lerp(starFill, other.starFill, t)!,
      starIdle: Color.lerp(starIdle, other.starIdle, t)!,
      ai: Color.lerp(ai, other.ai, t)!,
      aiLight: Color.lerp(aiLight, other.aiLight, t)!,
      aiContainer: Color.lerp(aiContainer, other.aiContainer, t)!,
      onAiContainer: Color.lerp(onAiContainer, other.onAiContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      successStrong: Color.lerp(successStrong, other.successStrong, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      warningInk: Color.lerp(warningInk, other.warningInk, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      heart: Color.lerp(heart, other.heart, t)!,
      classStar: Color.lerp(classStar, other.classStar, t)!,
      wordmarkInk: Color.lerp(wordmarkInk, other.wordmarkInk, t)!,
      brandRed: Color.lerp(brandRed, other.brandRed, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onMedia: Color.lerp(onMedia, other.onMedia, t)!,
      onMediaVariant: Color.lerp(onMediaVariant, other.onMediaVariant, t)!,
      onMediaBorder: Color.lerp(onMediaBorder, other.onMediaBorder, t)!,
      onMediaFill: Color.lerp(onMediaFill, other.onMediaFill, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      wordmarkOnMedia: Color.lerp(wordmarkOnMedia, other.wordmarkOnMedia, t)!,
      onMediaTextShadow: Color.lerp(
        onMediaTextShadow,
        other.onMediaTextShadow,
        t,
      )!,
      scrimSoft: Color.lerp(scrimSoft, other.scrimSoft, t)!,
      scrimStrong: Color.lerp(scrimStrong, other.scrimStrong, t)!,
      photoScrim: Color.lerp(photoScrim, other.photoScrim, t)!,
      ctaBar: Color.lerp(ctaBar, other.ctaBar, t)!,
      onCtaBar: Color.lerp(onCtaBar, other.onCtaBar, t)!,
      onCtaBarVariant: Color.lerp(onCtaBarVariant, other.onCtaBarVariant, t)!,
      ctaBarButton: Color.lerp(ctaBarButton, other.ctaBarButton, t)!,
      onCtaBarButton: Color.lerp(onCtaBarButton, other.onCtaBarButton, t)!,
    );
  }
}

/// Convenience accessor for the active TokiGo colour palette.
extension TokiGoColorsX on BuildContext {
  TokiGoColors get tokigoColors =>
      Theme.of(this).extension<TokiGoColors>() ?? TokiGoColors.light();
}

extension TokiGoThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
