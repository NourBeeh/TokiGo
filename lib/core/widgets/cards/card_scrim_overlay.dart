import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_spacing.dart';

/// Visual strength of a card scrim overlay.
enum CardScrimStrength { light, regular, strong }

/// Foreground (text/icon) colours guaranteed to sit legibly on top of a
/// [CardScrimFooter] scrim. Cards must use these instead of raw `Colors.white`.
///
/// The scrim itself is a fixed neutral dark (not a theme colour) by design: it
/// sits on top of arbitrary photography, so a dark scrim plus these foreground
/// tokens is the only combination that guarantees legibility in light AND dark
/// mode regardless of the photo underneath.
abstract final class CardScrimColors {
  /// Primary text on the scrim (titles, prices).
  static const Color onScrim = Color(0xFFFFFFFF);

  /// Secondary text on the scrim (subtitles, captions).
  static const Color onScrimVariant = Color(0xB3FFFFFF);

  /// Hairline borders on the scrim (e.g. pill outlines).
  static const Color onScrimBorder = Color(0x40FFFFFF);
}

/// Builds the shared scrim gradient. Exposed as a function so callers that
/// cannot use the widget form still share the exact same stops and alphas.
Decoration buildCardScrimDecoration(CardScrimStrength strength) {
  final alpha = switch (strength) {
    CardScrimStrength.light => 0.45,
    CardScrimStrength.regular => 0.70,
    CardScrimStrength.strong => 0.85,
  };
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0x00000000),
        Color.fromRGBO(0, 0, 0, alpha * 0.5),
        Color.fromRGBO(0, 0, 0, alpha),
      ],
      stops: const [0.0, 0.45, 1.0],
    ),
  );
}

/// The single shared bottom scrim for every image-first card.
///
/// All discovery cards that place text over a photo must use this footer —
/// never re-implement `LinearGradient` inline. The scrim is bottom-heavy so
/// overlaid content stays readable over any photo in both themes.
///
/// Drop directly into a `Stack` (it is a `PositionedDirectional` widget
/// covering the bottom edge, inset horizontally).
class CardScrimFooter extends StatelessWidget {
  const CardScrimFooter({
    super.key,
    this.strength = CardScrimStrength.regular,
    this.heightFactor,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.child,
  });

  final CardScrimStrength strength;

  /// Optional explicit scrim height as a fraction of the card height.
  /// Defaults to a strength-appropriate value (light/regular ≈ lower half,
  /// strong ≈ lower two thirds for dense overlaid content). The footer sizes
  /// itself to its content; the factor only guides documentation and callers
  /// that need to budget overlay space.
  final double? heightFactor;
  final EdgeInsetsGeometry padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      bottom: 0,
      start: 0,
      end: 0,
      child: DecoratedBox(
        decoration: buildCardScrimDecoration(strength),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
