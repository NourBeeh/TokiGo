import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/features/home/presentation/widgets/cover_flow_carousel.dart';
import 'package:tokigo/features/home/presentation/widgets/home_discovery_stay_card.dart';

/// A premium 3D **cover-flow carousel** for the Explore/Discover destination
/// cards on TokiGo Home.
///
/// It is a **destination-only** carousel: the hotel rail keeps
/// [HomeStaysCarousel], which shares the same [CoverFlowCarousel] 3D mechanics
/// (owner decision, 2026-11 — one cover-flow system for both rails). This
/// widget is swapped in by `HomeSectionWidget` for every destination-only
/// section (layout `horizontal` and `horizontalPeek`, plus the owner-decided
/// grid for destination-only sections).
///
/// The 3D mechanics — the rotateY fan, the uniform scale, the slot offset that
/// keeps a side card flush with the focal card, the perspective cue and the
/// reduced-motion fallback — live in [CoverFlowCarousel]. This widget only
/// supplies the destination card and the rail's geometry.
class DestinationCoverFlowCarousel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (items.isEmpty && !loading) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final double pageWidth = constraints.maxWidth * viewportFraction;
        final double cardHeight = pageWidth / mediaAspectRatio;
        return CoverFlowCarousel(
          itemCount: loading ? 1 : items.length,
          height: cardHeight,
          viewportFraction: viewportFraction,
          itemBuilder: (context, index) => _buildPageContent(index),
        );
      },
    );
  }

  Widget _buildPageContent(int index) {
    final HomeItem? item = loading
        ? null
        : items[index.clamp(0, items.length - 1)];
    return HomeDiscoveryStayCard(
      item: item ??
          const HomeItem(
            id: 'loading-destination',
            type: HomeCardType.destination,
            title: '',
          ),
      onTap: loading || onItemTap == null || item == null
          ? null
          : () => onItemTap!(item),
      fillSheet: false,
      aspectRatio: mediaAspectRatio,
      loading: loading,
    );
  }
}
