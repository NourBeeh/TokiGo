import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stay_card.dart';

/// Home's "Hotels recommended for you" rail (owner decision, 2026-10-25).
///
/// It used to be a vertical stack of full-width cards: the traveller had to
/// scroll past every stay to reach the rest of the feed. It is now a SWIPE
/// pager — one stay per page, snapped card by card, with the next stay peeking
/// at the edge (the only affordance that says "swipe me" without a tutorial).
///
/// Every stay is the same structured [HomeStayCard] used by the results page
/// and AI answer, with room below its photo for the hotel's decision facts.
///
/// The pager is a fixed-height box by nature, so the height is derived from
/// the image and information panel and grows with the traveller's text scale.
class HomeStaysCarousel extends StatefulWidget {
  const HomeStaysCarousel({
    super.key,
    required this.items,
    this.viewportFraction = 0.8,
    this.onItemTap,
    this.itemBuilder,
    this.sheetTextHeight = staysSheetTextHeight,
  });

  /// The stays to page through. The caller guarantees this is not empty.
  final List<HomeItem> items;

  /// Width of one page as a fraction of the rail's width. A little under the
  /// full width so the next stay peeks — the only affordance that says
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

  /// A city sheet's content budget at the default text scale: name, place,
  /// one description line and the pinned action row.
  static const double destinationSheetTextHeight = 60;

  /// Hotel image ratio in the Home rail: wide enough for a clear property
  /// photograph, with a separate information panel beneath it.
  static const double mediaAspectRatio = 1.6;

  /// The sheet's own vertical padding (top + bottom).
  static const double _sheetPadding = AppSpacing.md * 2;

  /// A stay sheet's content budget at the default text scale: name, class or
  /// score, location, distance, price and their gaps — including a two-line
  /// stay name — grown with the traveller's text scale. The city rail passes
  /// [destinationSheetTextHeight] instead, because its sheet is shorter.
  static const double staysSheetTextHeight = 188;

  /// Breathing room so rounding never turns into a clipped price.
  static const double _sheetSlack = 8;

  /// The rail's card height for a page of [pageWidth] at [textScale].
  static double cardHeightFor(
    double pageWidth,
    double textScale, {
    double sheetTextHeight = staysSheetTextHeight,
  }) {
    final double media = pageWidth / mediaAspectRatio;
    return media - _sheetPadding + sheetTextHeight * textScale + _sheetSlack;
  }

  /// The rail height for the current viewport — shared with the loading
  /// skeleton so the feed does not jump when the real stays land.
  static double railHeight(
    BuildContext context, {
    double viewportFraction = 0.8,
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
  State<HomeStaysCarousel> createState() => _HomeStaysCarouselState();
}

class _HomeStaysCarouselState extends State<HomeStaysCarousel> {
  late final PageController _controller = PageController(
    viewportFraction: widget.viewportFraction,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double pageWidth = constraints.maxWidth * widget.viewportFraction;
        final double height = HomeStaysCarousel.cardHeightFor(
          pageWidth,
          HomeStaysCarousel._textScaleOf(context),
          sheetTextHeight: widget.sheetTextHeight,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: height,
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.items.length,
                padEnds: false,
                itemBuilder: (BuildContext context, int index) {
                  // The page box is already the card's exact width, and the
                  // card fills it; the height is the rail height, so every
                  // card in the rail ends on the same line.
                  final HomeItem item = widget.items[index];
                  return KeyedSubtree(
                    key: ValueKey<String>(item.id),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.md,
                      ),
                      child:
                          widget.itemBuilder?.call(context, item) ??
                          HomeStayCard(
                            item: item,
                            margin: EdgeInsets.zero,
                            aspectRatio: HomeStaysCarousel.mediaAspectRatio,
                            onTap: widget.onItemTap == null
                                ? null
                                : () => widget.onItemTap!(item),
                          ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
