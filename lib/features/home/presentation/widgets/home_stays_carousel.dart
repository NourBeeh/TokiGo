import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_overlap.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stay_card.dart';

/// Home's "Hotels recommended for you" rail (owner decision, 2026-10-25).
///
/// It used to be a vertical stack of full-width cards: the traveller had to
/// scroll past every stay to reach the rest of the feed. It is now a SWIPE
/// pager — one stay per page, snapped card by card, with the next stay peeking
/// at the edge (the only affordance that says "swipe me" without a tutorial)
/// and page dots underneath so the position is readable at a glance.
///
/// Every card is the same [HomeStayCard] used by the results page and AI
/// answer, with a wider photo in this rail so the sheet has room for the
/// stay's facts (name, class, score, location, distance, nightly price).
///
/// The pager is a fixed-height box by nature, so the height is derived from the
/// card's own geometry (4:3 photo + the sheet that rides 48px up over it) and
/// grows with the traveller's text scale — a large font must never clip a
/// price.
class HomeStaysCarousel extends StatefulWidget {
  const HomeStaysCarousel({
    super.key,
    required this.items,
    this.viewportFraction = 0.8,
    this.onItemTap,
    this.itemBuilder,
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

  /// Card A's media ratio in this rail. A wider (shorter) photo leaves more of
  /// the card's height for the facts the stay card now carries — name, class,
  /// score, location, distance and nightly price — while making the card a
  /// little smaller overall than the old portrait photo.
  static const double mediaAspectRatio = 1.3;

  /// The sheet's own vertical padding (top + bottom).
  static const double _sheetPadding = AppSpacing.md * 2;

  /// The sheet content (name + class/score + location + distance + price and
  /// their gaps) at the default text scale. Kept in step with
  /// [OverlapStayCard] and grown with the traveller's text scale.
  static const double _sheetText = 112;

  /// Breathing room so rounding never turns into a clipped price.
  static const double _sheetSlack = 8;

  /// The rail's card height for a page of [pageWidth] at [textScale].
  static double cardHeightFor(double pageWidth, double textScale) {
    final double media = pageWidth / mediaAspectRatio;
    return media -
        AppOverlap.card +
        _sheetPadding +
        _sheetText * textScale +
        _sheetSlack;
  }

  /// The rail height for the current viewport — shared with the loading
  /// skeleton so the feed does not jump when the real stays land.
  static double railHeight(
    BuildContext context, {
    double viewportFraction = 0.8,
  }) {
    final double width = MediaQuery.sizeOf(context).width;
    return cardHeightFor(width * viewportFraction, _textScaleOf(context));
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
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeStaysCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refresh can shorten the list under the traveller's feet; the dots must
    // never point past the last stay.
    if (_page >= widget.items.length) {
      _page = widget.items.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double pageWidth = constraints.maxWidth * widget.viewportFraction;
        final double height = HomeStaysCarousel.cardHeightFor(
          pageWidth,
          HomeStaysCarousel._textScaleOf(context),
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
                onPageChanged: (int index) {
                  if (!mounted) return;
                  setState(() => _page = index);
                },
                itemBuilder: (BuildContext context, int index) {
                  // The page box is already the card's exact width, and the
                  // card fills it; the height is the rail height, so every
                  // card in the rail ends on the same line.
                  final HomeItem item = widget.items[index];
                  return KeyedSubtree(
                    key: ValueKey<String>(item.id),
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
                  );
                },
              ),
            ),
            if (widget.items.length > 1) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              // The dots are a position cue, not content: the cards themselves
              // carry the screen-reader labels.
              ExcludeSemantics(
                child: _SwipeDots(count: widget.items.length, index: _page),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Page dots for a swipe rail: the inactive ones are 6px circles, the current
/// one stretches into a 16px pill so the position never relies on colour alone.
class _SwipeDots extends StatelessWidget {
  const _SwipeDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final int safeIndex = index.clamp(0, count - 1);
    // Wrap, not Row: a long recommendation list must never overflow the rail —
    // the dots flow onto a second line instead of pushing the feed sideways.
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: i == safeIndex ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == safeIndex ? AppColors.brand : AppColors.outline,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}
