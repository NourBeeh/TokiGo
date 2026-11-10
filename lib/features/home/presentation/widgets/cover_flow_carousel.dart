import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The shared 3D **cover-flow** pager behind Home's rails.
///
/// Each page is wrapped in a [Transform] whose [Matrix4] is rebuilt on every
/// scroll frame from the LIVE scroll offset, so the hand-over between the focal
/// page and its neighbours is continuous: an arriving card grows from ~70 % to
/// 100 % as it crosses the viewport instead of jumping the instant the pager
/// snaps.
///
/// The mechanics are page-agnostic — the caller supplies the page content, the
/// rail height and the page-width fraction. Both Home rails (destinations and
/// stays) therefore share ONE cover-flow implementation instead of the stay
/// rail shipping a second, flatter pager.
///
/// ## 3D mechanics
/// The [Transform.alignment] is [Alignment.center], so the rotation/scale pivot
/// is the card's own centre — the matrix itself only carries the slot offset,
/// the tilt and the scale:
///   1. `RotateY` — a fan: cards past the focal position tilt one way, the ones
///      before it the other, flattening out with distance.
///   2. `Scale` — the focal card is 100 %, one slot out is ~70 %, two slots out
///      is ~48 %. Uniform on both axes so a side card keeps the card's own
///      aspect ratio instead of stretching into a full-height sliver.
///   3. `translate(x, 0, z)` — move the card to its slot and push the side
///      cards slightly *toward* the viewer ([negative Z] in Flutter's
///      right-handed space), so the tilted cards peek "out of" the focal card.
///
/// A [Matrix4.perspective](entry `(3, 2)` → 0.0018) creates the parallax
/// distortion so cards that trail away (or forward) read as depth.
///
/// ## Accessibility
/// When the platform reports `reduceMotion`, the 3D transforms are stripped and
/// the widget falls back to a plain centred [PageView] with no depth, so
/// motion-impaired users do not lose the feed.
class CoverFlowCarousel extends StatefulWidget {
  const CoverFlowCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.viewportFraction = 0.9,
  });

  /// Number of pages. Hosts pass `1` for their loading skeleton.
  final int itemCount;

  /// Builds the content of page [index]. The returned widget fills the page
  /// box (`rail width × viewportFraction` × [height]).
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// The rail's height — the same value the host uses for its skeleton.
  final double height;

  /// Width of one page as a fraction of the rail's width.
  final double viewportFraction;

  @override
  State<CoverFlowCarousel> createState() => _CoverFlowCarouselState();
}

class _CoverFlowCarouselState extends State<CoverFlowCarousel> {
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
  void didUpdateWidget(covariant CoverFlowCarousel oldWidget) {
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
    _offsetNotifier.value = _controller.page ?? 0.0;
  }

  /// Whether the platform-level "reduce motion" accessibility setting is on.
  bool _reduceMotionEnabled() =>
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;

  void _checkReducedMotion() {
    if (_reduceMotionEnabled() && mounted) {
      setState(() => _reducedMotion = true);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final double pageWidth = constraints.maxWidth * widget.viewportFraction;
        return SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.itemCount,
            // The focal card is centred, with the neighbours peeking on both
            // sides — the only affordance that says "swipe me".
            padEnds: true,
            itemBuilder: (context, index) {
              final Widget content = widget.itemBuilder(context, index);
              if (_reducedMotion) return content;
              return AnimatedBuilder(
                // Rebuild every frame while the user drags.
                animation: _offsetNotifier,
                builder: (context, child) {
                  // Read the CURRENT scroll offset here, inside the builder.
                  // Capturing it when the page was built would freeze every
                  // transform at the offset of the first layout, so the focal
                  // card would never hand over to the next one.
                  final Matrix4 transform = computePageTransform(
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
                child: content,
              );
            },
          ),
        );
      },
    );
  }

  /// Builds the [Matrix4] for the card at [index] given the current scroll
  /// offset [offset] (in page units).
  ///
  /// Public and static so a host can verify the transform contract in tests.
  @visibleForTesting
  static Matrix4 computePageTransform(
    int index,
    double offset,
    double pageWidth,
    TextDirection direction,
  ) {
    // Continuous distance from the focal position, in page units. Reading the
    // live offset — not the settled page index — is what makes the hand-over
    // seamless: an arriving card grows from ~70 % to 100 % as it crosses the
    // viewport instead of jumping the instant the pager snaps.
    final double distance = index - offset;
    final double absDistance = distance.abs();
    final double clampedDistance = absDistance.clamp(0.0, 2.5);

    // ── Scale ──────────────────────────────────────────────────────────────
    // 1.0 at the focal card → ~0.48 at two slots out. Uniform on both axes so
    // a side card keeps the card's own aspect ratio: an X-only scale stretches
    // it into a full-height sliver whose rotated corners leave the rail and get
    // clipped by the viewport.
    final double scale = (1.0 - clampedDistance * 0.26).clamp(0.48, 1.0);

    // ── RotationY (degrees) ────────────────────────────────────────────────
    // A fan: cards past the focal position tilt one way, the ones before it the
    // other, flattening out with distance.
    final double rotationDegrees =
        distance * 14.0 * (1.0 - clampedDistance * 0.25);

    // Small Z push (negative Z = towards the viewer) so side cards read as
    // "out of" the focal card.
    final double visualOffsetZ = -absDistance * 34.0;

    // ── Visual offset ──────────────────────────────────────────────────────
    // A side card is scaled about its OWN centre AND rotated in 3D, and BOTH
    // move its inner edge away from the focal card. Half the shrink is only
    // the unrotated part: rotateY plus the perspective divide move the edge
    // further, so the old `-shrink/2` compensation left a white gutter
    // between the focal card and its neighbour and the peek the pager leaves
    // was mostly empty canvas.
    //
    // Project the inner edge through the exact same scale → rotateY →
    // perspective pipeline the matrix below applies, then solve for the slot
    // translation that lands it exactly on the focal card's edge. Page +1 is
    // to the RIGHT in LTR and to the LEFT in RTL, so the edge's sign follows
    // the reading direction.
    final double directionSign = direction == TextDirection.rtl ? -1.0 : 1.0;
    final double innerEdge =
        -directionSign * distance.sign * pageWidth / 2.0;
    final double theta = rotationDegrees * math.pi / 180.0;
    final double scaledEdge = innerEdge * scale;
    final double rotatedEdge = scaledEdge * math.cos(theta);
    final double edgeZ = -scaledEdge * math.sin(theta) + visualOffsetZ;
    final double edgeW = 1.0 + 0.0018 * edgeZ;
    final double visualOffsetX = innerEdge * edgeW - rotatedEdge;

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
    m.translateByDouble(visualOffsetX, 0.0, visualOffsetZ, 1.0);

    // 3) R: rotate about the card's own centre (supplied by the Transform's
    //    alignment, so the pivot term lives there and not in this matrix).
    m.rotateY(rotationDegrees * 3.141592653589793 / 180.0);

    // 4) S: shrink the side cards, uniformly so they keep their proportions.
    m.scaleByDouble(scale, scale, 1.0, 1.0);

    return m;
  }
}
