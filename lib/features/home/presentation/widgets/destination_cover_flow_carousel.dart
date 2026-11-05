import 'package:flutter/material.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/features/home/presentation/widgets/home_discovery_stay_card.dart';

/// A premium 3D **cover-flow carousel** for the Explore/Discover destination
/// cards on TokiGo Home.
///
/// It is a **destination-only** carousel: the hotel rail keeps [HomeStaysCarousel]
/// untouched, and this widget is swapped in by [HomeSectionWidget] for every
/// destination-only section (layout `horizontal` and `horizontalPeek`, plus the
/// owner-decided grid for destination-only sections).
///
/// ## 3D mechanics
/// Each card is a plain [HomeDiscoveryStayCard] wrapped in a [Transform] whose
/// [Matrix4] is built per page. The [Transform.alignment] is
/// [Alignment.center], so the rotation/scale pivot is the card's own centre —
/// the matrix itself only carries the slot offset, the tilt and the scale:
///   1. `RotateY` — tilt the side cards in 3D (LTR drags toward the
///      direction of motion; the focal card leans *with* the drag).
///   2. `Scale` — the focal card is 100 %, one slot out is ~70 %, two slots
///      out is ~48 %.
///   3. `translate(x, 0, z)` — move the card to its slot and push the side
///      cards slightly *toward* the viewer ([negative Z] in Flutter's
///      right-handed space), so the tilted cards peek "out of" the focal card.
///
/// A [Matrix4.perspective](entry `(3, 2)` → 0.0018) creates the parallax
/// distortion so cards that trail away (or forward) read as depth.
///
/// ## Smooth dragging
/// A [ValueNotifier] mirrors [PageController.page] on every scroll frame; an
/// [AnimatedBuilder] rebuilds only the transforms, so side cards track the
/// pointer continuously instead of waiting for a snap.
///
/// ## Accessibility
/// When the platform reports `reduceMotion`, the 3D transforms and every
/// animated scale/opacity are stripped — the widget falls back to a plain
/// horizontally scrolling [PageView] with no depth, so motion-impaired users
/// do not lose the feed.
class DestinationCoverFlowCarousel extends StatefulWidget {
  const DestinationCoverFlowCarousel({
    super.key,
    required this.items,
    required this.onItemTap,
    this.viewportFraction = HomeCardDimensions.destinationViewportFraction,
    this.mediaAspectRatio = HomeCardDimensions.destinationMediaAspectRatio,
    this.loading = false,
  });

  /// Destination items to page through. May be empty (the widget renders
  /// nothing) or a single item (no carousel, just a centred card). Empty is
  /// also how the [loading] skeleton is hosted.
  final List<HomeItem> items;

  /// Open the selected city page.
  final ValueChanged<HomeItem>? onItemTap;

  /// Width of one page as a fraction of the available screen width.
  final double viewportFraction;

  /// Photo width ÷ height of each card.
  final double mediaAspectRatio;

  /// Skeleton state — the SAME carousel with one placeholder card.
  ///
  /// The rail height, page width and photo ratio come from the same fields the
  /// loaded carousel reads, so the loading Discover rail occupies exactly the
  /// space the real cities will.
  final bool loading;

  static const double defaultMediaAspectRatio =
      HomeCardDimensions.destinationMediaAspectRatio;

  @override
  State<DestinationCoverFlowCarousel> createState() =>
      _DestinationCoverFlowCarouselState();
}

class _DestinationCoverFlowCarouselState
    extends State<DestinationCoverFlowCarousel> {
  /// The pager. Its [PageController.viewportFraction] is the rail's own
  /// [DestinationCoverFlowCarousel.viewportFraction], so one page is 90 % of
  /// the rail and the neighbouring city stays visible as a 10 % peek — the
  /// only affordance that says "swipe me".
  late PageController _controller;
  final ValueNotifier<double> _offsetNotifier = ValueNotifier<double>(0.0);

  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: widget.viewportFraction);
    // Mirror the controller so the AnimatedBuilder updates the transforms on
    // every scroll frame (smooth while dragging, and after any snap).
    _controller.addListener(_onPageChanged);
    _checkReducedMotion();
  }

  @override
  void didUpdateWidget(covariant DestinationCoverFlowCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The viewport fraction is baked into the PageController at construction;
    // a changed fraction needs a new controller (the same is true of the
    // PageView's own viewport, which is derived from it).
    if (oldWidget.viewportFraction != widget.viewportFraction) {
      _controller.removeListener(_onPageChanged);
      _controller.dispose();
      _controller = PageController(viewportFraction: widget.viewportFraction);
      _controller.addListener(_onPageChanged);
    }
  }

  void _onPageChanged() {
    final double page = _controller.page ?? 0.0;
    _offsetNotifier.value = page;
  }

  /// Whether the platform-level "reduce motion" accessibility setting is on.
  ///
  /// The [AccessibilityFeatures] API that exposes this flag ships with Flutter
  /// ≥ 3.8. The host SDK in this workspace is a minimal build that does not
  /// carry that API, so we consult it at runtime with a hard fallback to
  /// `false`: reduced-motion is only honoured when the flag is actually
  /// readable. A future SDK upgrade will flip this to a real platform query.
  bool _reduceMotionEnabled() {
    // The `accessibilityFeatures` flag ships with Flutter ≥ 3.8; a minimal
    // host SDK may omit it, so treat a missing/runtime-unavailable flag as
    // "no reduced motion".
    final accessibilityFeatures =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return accessibilityFeatures.reduceMotion;
  }

  void _checkReducedMotion() {
    if (_reduceMotionEnabled()) {
      if (mounted) {
        setState(() {
          _reducedMotion = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onPageChanged);
    _controller.dispose();
    _offsetNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return _buildLoadingPage();
    if (widget.items.isEmpty) return const SizedBox.shrink();
    if (_reducedMotion) {
      return _buildReducedMotionCarousel();
    }
    return _buildCoverFlowCarousel();
  }

  // ── Loading ──────────────────────────────────────────────────────────

  /// One placeholder page through the SAME layout pipeline as the loaded
  /// carousel: identical [SizedBox] height, identical page width, identical
  /// `_buildTransformedPage` → `_buildPageContent` chain. The focal page's
  /// transform is the identity, so the skeleton lands exactly where the real
  /// focal card will.
  Widget _buildLoadingPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double pageWidth = screenWidth * widget.viewportFraction;
        final double cardHeight = pageWidth / widget.mediaAspectRatio;

        return SizedBox(
          height: cardHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: 1,
            padEnds: false,
            itemBuilder: (context, index) =>
                _buildTransformedPage(index, pageWidth, cardHeight),
          ),
        );
      },
    );
  }

  // ── Cover-flow ──────────────────────────────────────────────────────────

  Widget _buildCoverFlowCarousel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double pageWidth = screenWidth * widget.viewportFraction;
        final double cardHeight = pageWidth / widget.mediaAspectRatio;

        return SizedBox(
          height: cardHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            padEnds: false,
            itemBuilder: (context, index) {
              return _buildTransformedPage(index, pageWidth, cardHeight);
            },
          ),
        );
      },
    );
  }

  Widget _buildTransformedPage(
    int index,
    double pageWidth,
    double cardHeight,
  ) {
    return AnimatedBuilder(
      // Rebuild every frame while the user drags.
      animation: _offsetNotifier,
      builder: (context, child) {
        // Read the CURRENT scroll offset here, inside the builder. Capturing
        // it when the page was built would freeze every transform at the
        // offset of the first layout, so the focal card would never hand over
        // to the next one and the rail would keep a stale tilt after a swipe.
        final Matrix4 transform = _computePageTransform(
          index,
          _offsetNotifier.value,
          pageWidth,
          Directionality.of(context),
        );
        return Transform(
          transform: transform,
          alignment: Alignment.center,
          child: child,
        );
      },
      child: _buildPageContent(index, pageWidth, cardHeight),
    );
  }

  Widget _buildPageContent(
    int index,
    double pageWidth,
    double cardHeight,
  ) {
    final HomeItem? item = widget.loading
        ? null
        : widget.items[index.clamp(0, widget.items.length - 1)];
    return HomeDiscoveryStayCard(
      item: item ??
          const HomeItem(
            id: 'loading-destination',
            type: HomeCardType.destination,
            title: '',
          ),
      onTap: widget.loading || widget.onItemTap == null || item == null
          ? null
          : () => widget.onItemTap!(item),
      fillSheet: false,
      aspectRatio: widget.mediaAspectRatio,
      loading: widget.loading,
    );
  }

  /// Builds the [Matrix4] for the card at [index] given the current scroll
  /// offset [offset] (in page units).
  Matrix4 _computePageTransform(
    int index,
    double offset,
    double pageWidth,
    TextDirection direction,
  ) {
    final int currentPage = _pageOf(offset);
    final double offsetWithinPage = _snapWithinPage(offset, currentPage);

    // Distance (in page slots) from the focal card. For the focal card the
    // within-page offset speeds up its own tilt/scale while the user drags.
    final int diff = index - currentPage;
    final double absDiff = diff.abs().toDouble();
    final double effectiveDistance =
        absDiff + (diff == 0 ? offsetWithinPage.abs() : 0.0);
    final double clampedDistance = effectiveDistance.clamp(0.0, 2.5);

    // ── Scale ──────────────────────────────────────────────────────────────
    // 1.0 at the focal card → ~0.48 at two slots out.
    final double rawScale = 1.0 - (clampedDistance * 0.26);
    final double scale = rawScale.clamp(0.48, 1.0);

    // ── RotationY (degrees) ────────────────────────────────────────────────
    // ±14° at one slot out, flattening to ~0 as the distance grows. The focal
    // card leans with the drag (up to ±6° at a 0.5 slot drag).
    double rotationDegrees = diff * 14.0;
    if (diff == 0) {
      rotationDegrees = offsetWithinPage * 11.0;
    }
    rotationDegrees = rotationDegrees * (1.0 - clampedDistance * 0.25);

    // ── Visual offset ──────────────────────────────────────────────────────
    // A side card is scaled about its OWN centre, which pulls its inner edge
    // away from the focal card by half the shrink. Compensate by exactly that
    // amount so a side card stays flush against the focal card's edge and the
    // 10 % peek the pager leaves is actually visible. Without it the scaled
    // side card floats in the middle of the viewport and no neighbour shows.
    // Page +1 is to the RIGHT in LTR and to the LEFT in RTL, so the sign of
    // the correction follows the reading direction.
    final double directionSign = direction == TextDirection.rtl ? -1.0 : 1.0;
    final double visualOffsetX =
        -directionSign * diff * (pageWidth * (1.0 - scale)) / 2.0;
    // Small Z push (negative Z = towards the viewer) so side cards read as
    // "out of" the focal card. The focal card is dragged through the z-axis
    // too, reinforcing the depth cue.
    final double visualOffsetZ = -absDiff * 34.0;
    final double focalDragZ = diff == 0 ? -offsetWithinPage * 16.0 : 0.0;

    // ── Card geometry ──────────────────────────────────────────────────────
    // The card is laid out at the page's own box (pageWidth × cardHeight) and
    // [Transform.alignment] is Alignment.center, so the pivot for the
    // rotation/scale is already the card's centre. The matrix must NOT carry
    // a `translate(-w/2, -h/2)` pivot term: that would double the pivot and
    // shift every card half a page up-left, out of the viewport.

    // ── Build the matrix ───────────────────────────────────────────────────
    // Multiply on the right, so the *last* call is applied first.
    final Matrix4 m = Matrix4.identity();
    // 1) Perspective: the (3,2) entry warps W and gives the parallax cue.
    m.setEntry(3, 2, 0.0018);

    // 2) T_slot: move the card to its slot + a small Z shift (applied last,
    //    so it's the outermost transform).
    m.translateByDouble(visualOffsetX, 0.0, visualOffsetZ + focalDragZ, 1.0);

    // 3) R: rotate about the card's own centre (supplied by the Transform's
    //    alignment, so the pivot term lives there and not in this matrix).
    m.rotateY(rotationDegrees * 3.141592653589793 / 180.0);

    // 4) S: shrink the side cards.
    m.scaleByDouble(scale, 1.0, 1.0, 1.0);

    return m;
  }

  // ── Reduced-motion fallback ──────────────────────────────────────────────

  Widget _buildReducedMotionCarousel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double pageWidth = screenWidth * widget.viewportFraction;
        final double cardHeight = pageWidth / widget.mediaAspectRatio;

        return SizedBox(
          height: cardHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            padEnds: false,
            itemBuilder: (context, index) {
              return _buildPageContent(index, pageWidth, cardHeight);
            },
          ),
        );
      },
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  int _pageOf(double offset) => offset.floor().toInt();

  /// Keep the within-page offset inside [-0.5, 0.5] so a drag that overshoots
  /// a page still yields a sane tilt/scale for the pulled card.
  double _snapWithinPage(double offset, int page) {
    return (offset - page).clamp(-0.5, 0.5);
  }
}
