import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/features/home/presentation/widgets/cover_flow_carousel.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stay_card.dart';

/// Home's "Hotels recommended for you" rail (owner decision, 2026-10-25).
///
/// Owner decision (2026-11): the rail shares the Discover rail's 3D
/// **cover-flow** mechanics — ONE stay centred in the viewport with its
/// neighbours peeking on both sides, tilted in 3D — instead of the flat,
/// leading-aligned pager it used to be. Both rails now run the same
/// [CoverFlowCarousel], so the swipe feel is identical across the feed.
///
/// Every stay is the same structured [HomeStayCard] used by the results page
/// and AI answer, with room below its photo for the hotel's decision facts.
///
/// The rail is a fixed-height box by nature, so the height is derived from the
/// image and information panel and grows with the traveller's text scale.
class HomeStaysCarousel extends StatelessWidget {
  const HomeStaysCarousel({
    super.key,
    required this.items,
    this.viewportFraction = HomeCardDimensions.stayViewportFraction,
    this.onItemTap,
    this.itemBuilder,
    this.sheetTextHeight = staysSheetTextHeight,
    this.splitLayout = false,
    this.photoAspectRatio = HomeStaysCarousel.mediaAspectRatio,
    this.showHeartPlatter = true,
    this.loading = false,
    this.cardHeightBuilder,
  });

  /// The stays to page through. The caller guarantees this is not empty
  /// unless [loading] is set.
  final List<HomeItem> items;

  /// Width of one page as a fraction of the rail's width. A little under the
  /// full width so the neighbouring stay peeks — the only affordance that says
  /// "swipe me" without a tutorial.
  final double viewportFraction;

  /// Optional surface-specific action; null opens the stay's normal details.
  final ValueChanged<HomeItem>? onItemTap;

  /// Alternate card presentation for Discover destinations.
  final Widget Function(BuildContext context, HomeItem item)? itemBuilder;

  /// Sheet budget for this rail. Stays carry a rating, place, distance and
  /// price; a city carries a name, place, one description line and the action
  /// hint. Passing the city's own budget keeps the rail from reserving empty
  /// space the city card can never fill.
  final double sheetTextHeight;

  /// Whether the rail renders Home's horizontal 60/40 split card. Only the
  /// Home "Stays Near You" rail opts in; the AI answer rails keep the
  /// photo-above-sheet card.
  final bool splitLayout;

  /// Photo width ÷ height for this rail. The default is the wide Home stay
  /// ratio; a surface that wants a taller photo (image on top, description
  /// below) passes a smaller ratio.
  final double photoAspectRatio;

  /// Whether the favourite heart draws its white disc platter.
  final bool showHeartPlatter;

  /// Skeleton state — the SAME rail with placeholder cards.
  ///
  /// The rail's height, page width and page fraction are read from the same
  /// fields the loaded rail uses, so a loading feed occupies exactly the space
  /// the real stays will. One page only: pretending there are stays to swipe
  /// before any exists would be a lie.
  final bool loading;

  /// Overrides the rail's card height.
  ///
  /// The Home "Stays Near You" split rail supplies
  /// [splitCardHeightFor] so its card is the exact same measured width and
  /// height as a Trending Destinations city card. Null (the default) keeps the
  /// photo-above-sheet budget derived from [mediaAspectRatio] and
  /// [sheetTextHeight].
  final double Function(double pageWidth, double textScale)? cardHeightBuilder;

  /// A city sheet's content budget at the default text scale: name, place,
  /// one description line and the pinned action row.
  static const double destinationSheetTextHeight =
      HomeCardDimensions.destinationSheetTextHeight;

  /// Hotel image ratio in the Home rail: wide enough for a clear property
  /// photograph, with a separate information panel beneath it.
  static const double mediaAspectRatio =
      HomeCardDimensions.stayMediaAspectRatio;

  /// The sheet's own vertical padding (top + bottom).
  static const double _sheetPadding = AppSpacing.md * 2;

  /// A stay sheet's content budget at the default text scale: name, class or
  /// score, location, distance, price and their gaps — including a two-line
  /// stay name — grown with the traveller's text scale. The city rail passes
  /// [destinationSheetTextHeight] instead, because its sheet is shorter.
  static const double staysSheetTextHeight =
      HomeCardDimensions.staySheetTextHeight;

  /// Breathing room so rounding never turns into a clipped price.
  ///
  /// The card fills its page edge-to-edge now that the rail is a cover flow
  /// (the old leading-aligned pager left a 12dp trailing gap), so the photo is
  /// wider and the sheet needs the extra slack to stay inside the rail.
  static const double _sheetSlack = 24;

  /// The rail's card height for a page of [pageWidth] at [textScale].
  static double cardHeightFor(
    double pageWidth,
    double textScale, {
    double sheetTextHeight = staysSheetTextHeight,
    double mediaAspectRatio = HomeStaysCarousel.mediaAspectRatio,
  }) {
    final double media = pageWidth / mediaAspectRatio;
    return media - _sheetPadding + sheetTextHeight * textScale + _sheetSlack;
  }

  /// The split card's height, matching the Trending Destinations city card.
  ///
  /// The city card's geometry is the source of truth: a page of [pageWidth] is
  /// `pageWidth / destinationMediaAspectRatio` tall. The split card adopts
  /// that exact height at the default text scale, and grows with the
  /// traveller's text scale — its information column carries the stay's
  /// decision facts, which the city card's scrim copy does not, so a larger
  /// scale must not clip them.
  static double splitCardHeightFor(double pageWidth, double textScale) {
    final double cityHeight =
        pageWidth / HomeCardDimensions.destinationMediaAspectRatio;
    final double contentHeight =
        HomeCardDimensions.staySheetTextHeight * textScale;
    return math.max(cityHeight, contentHeight);
  }

  /// The taller photo-above-sheet variant: the hotel photo on top, its
  /// description below, at the Discover card's (taller) photo ratio.
  static double tallCardHeightFor(double pageWidth, double textScale) {
    return cardHeightFor(
      pageWidth,
      textScale,
      mediaAspectRatio: HomeCardDimensions.destinationMediaAspectRatio,
    );
  }

  /// The rail height for the current viewport — shared with the loading
  /// skeleton so the feed does not jump when the real stays land.
  static double railHeight(
    BuildContext context, {
    double viewportFraction = HomeCardDimensions.stayViewportFraction,
    double sheetTextHeight = staysSheetTextHeight,
  }) {
    final double width = MediaQuery.sizeOf(context).width;
    return cardHeightFor(
      width * viewportFraction,
      _textScaleOf(context),
      sheetTextHeight: sheetTextHeight,
    );
  }

  /// The traveller's text scale, clamped: the sheet's padding is fixed, so an
  /// unbounded scale would only grow the box faster than the text.
  static double _textScaleOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double pageWidth = constraints.maxWidth * viewportFraction;
        final double textScale = HomeStaysCarousel._textScaleOf(context);
        final double height =
            cardHeightBuilder?.call(pageWidth, textScale) ??
            HomeStaysCarousel.cardHeightFor(
              pageWidth,
              textScale,
              sheetTextHeight: sheetTextHeight,
              mediaAspectRatio: photoAspectRatio,
            );

        return CoverFlowCarousel(
          itemCount: loading ? 1 : items.length,
          height: height,
          viewportFraction: viewportFraction,
          itemBuilder: (BuildContext context, int index) {
            // The page box is already the card's exact width, and the card
            // fills it; the height is the rail height, so every card in the
            // rail ends on the same line.
            final Widget card = loading
                ? HomeStayCard.loading(
                    margin: EdgeInsets.zero,
                    aspectRatio: photoAspectRatio,
                    splitLayout: splitLayout,
                    showHeartPlatter: showHeartPlatter,
                  )
                : itemBuilder?.call(context, items[index]) ??
                      HomeStayCard(
                        item: items[index],
                        margin: EdgeInsets.zero,
                        aspectRatio: photoAspectRatio,
                        splitLayout: splitLayout,
                        showHeartPlatter: showHeartPlatter,
                        onTap: onItemTap == null
                            ? null
                            : () => onItemTap!(items[index]),
                      );
            return KeyedSubtree(
              key: ValueKey<String>(
                loading ? 'home-stays-skeleton' : items[index].id,
              ),
              child: card,
            );
          },
        );
      },
    );
  }
}
