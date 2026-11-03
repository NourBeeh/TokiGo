import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_elevation.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/cards/card_glass.dart';
import 'package:tokigo/core/widgets/cards/card_scrim_overlay.dart';

/// Shared visual tokens for cards across the Home discovery feed.
///
/// The Home feed mixes destinations, stays, flights, deals and products. They
/// have different compositions, but share a restrained visual language:
///
/// * theme-aware surfaces and hairline borders,
/// * quiet typography and metadata,
/// * limited elevation instead of decorative shadows.
///
/// Colours always come from [TokiGoColors], so both themes retain the same
/// hierarchy without duplicating presentation state.
abstract final class TravelCardStyle {
  /// Radius for shared card decoration helpers.
  static const double radius = AppRadius.xl;

  static BorderRadius get borderRadius => BorderRadius.circular(radius);

  /// Padding inside an information sheet. Generous enough for the price/CTA
  /// line, tight enough that the photo stays the loudest element.
  static const EdgeInsetsDirectional sheetPadding =
      EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      );

  /// Hairline that separates a card from the page. In dark mode the surface is
  /// only a few steps above the canvas, so the line is a touch stronger.
  static Color borderColor(BuildContext context) {
    final tc = context.tokigoColors;
    return Theme.of(context).brightness == Brightness.dark
        ? tc.hairlineStrong
        : tc.hairline;
  }

  /// Shadow used by a resting feed card.
  static List<BoxShadow> shadows(BuildContext context) => AppElevation.shadow(
    background: context.tokigoColors.surface,
    level: AppElevation.lg,
  );

  /// Surface + hairline + halo in one decoration for cards that build their
  /// own shell instead of using [BaseCard]'s default.
  static BoxDecoration decoration(BuildContext context) {
    final tc = context.tokigoColors;
    return BoxDecoration(
      color: tc.surface,
      borderRadius: borderRadius,
      border: Border.all(color: borderColor(context)),
      boxShadow: shadows(context),
    );
  }

  /// The neutral inner panel used for route strips / info groups.
  static BoxDecoration innerPanel(BuildContext context) {
    final tc = context.tokigoColors;
    return BoxDecoration(
      color: tc.surfaceSecondary,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: tc.hairline),
    );
  }

  /// The soft top-to-bottom photo scrim. Image-first cards use the shared
  /// [CardScrimFooter] for bottom copy; this variant is for cards that need a
  /// faint top wash behind overlaid chips.
  static BoxDecoration topScrim(BuildContext context) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Colors.black.withValues(alpha: 0.38), Colors.transparent],
      stops: const <double>[0.0, 0.5],
    ),
  );
}

/// A small metadata pill used across Home cards.
///
/// [onImage] renders the frosted-glass variant for pills that sit on a photo;
/// the tonal variant is for pills on the card's information sheet. Both inherit
/// their foreground from the active theme, so dark mode never gets a white
/// pill with white text.
class TravelMetaChip extends StatelessWidget {
  const TravelMetaChip({
    super.key,
    required this.label,
    this.icon,
    this.onImage = false,
    this.emphasized = false,
  });

  final String label;
  final IconData? icon;
  final bool onImage;

  /// Uses the brand ink for the metric that drives the decision (score, price).
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final tc = context.tokigoColors;
    final TextStyle style = AppTypography.forLight().captionSemibold.copyWith(
      color: onImage
          ? CardScrimColors.onScrim
          : (emphasized ? tc.textPrimary : tc.textSecondary),
      height: 1.1,
    );

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(
            icon,
            size: 13,
            color: onImage
                ? CardScrimColors.onScrimVariant
                : (emphasized ? tc.textPrimary : tc.textSecondary),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );

    if (onImage) {
      return CardGlass(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        tint: tc.glassTint,
        borderColor: CardScrimColors.onScrimBorder,
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tc.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: tc.hairline),
      ),
      child: content,
    );
  }
}

/// A quiet "open" affordance for cards with a clear next action.
class TravelActionHint extends StatelessWidget {
  const TravelActionHint({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color ink = color ?? context.tokigoColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.forLight().captionSemibold.copyWith(
              color: ink,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Icon(
          // The arrow mirrors in Arabic: the traveller's eye reads the action
          // as "onward" in the direction the language flows.
          Directionality.of(context) == TextDirection.rtl
              ? Icons.arrow_back_rounded
              : Icons.arrow_forward_rounded,
          size: 15,
          color: ink,
        ),
      ],
    );
  }
}
