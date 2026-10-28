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
/// Every card is the SAME [HomeStayCard] the results page and the AI answer
/// use: the rail changes how the stays are navigated, never what a stay is.
///
/// The pager is a fixed-height box by nature, so the height is derived from the
/// card's own geometry (4:3 photo + the sheet that rides 48px up over it) and
/// grows with the traveller's text scale — a large font must never clip a
/// price.
class HomeStaysCarousel extends StatefulWidget {
  const HomeStaysCarousel({
    super.key,
    required this.items,
    this.viewportFraction = 0.9,
  });

  /// The stays to page through. The caller guarantees this is not empty.
  final List<HomeItem> items;

  /// Width of one page as a fraction of the rail's width. Below 1 the next
  /// card peeks; 0.9 leaves a ~16pt gutter on both ends (the page gutter the
  /// rest of the Home uses).
  final double viewportFraction;

  /// Card A's media ratio — the same shape every stay card has.
  static const double _mediaAspectRatio = 4 / 3;

  /// The sheet's own vertical padding (top + bottom).
  static const double _sheetPadding = AppSpacing.md * 2;

  /// Title line + rating line + price line with their gaps, at the default
  /// text scale (see [OverlapStayCard]).
  static const double _sheetText = 76;

  /// Breathing room so rounding never turns into a clipped price.
  static const double _sheetSlack = 8;

  /// The rail's card height for a page of [pageWidth] at [textScale].
  static double cardHeightFor(double pageWidth, double textScale) {
    final double media = pageWidth / _mediaAspectRatio;
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
    double viewportFraction = 0.9,
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
                onPageChanged: (int index) {
                  if (!mounted) return;
                  setState(() => _page = index);
                },
                itemBuilder: (BuildContext context, int index) {
                  // The page box is already the card's exact width, and the
                  // card fills it; the height is the rail height, so every
                  // card in the rail ends on the same line.
                  return HomeStayCard(
                    // Index-keyed: a stay that moves page keeps its photo.
                    key: ValueKey<String>(widget.items[index].id),
                    item: widget.items[index],
                    margin: EdgeInsets.zero,
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
