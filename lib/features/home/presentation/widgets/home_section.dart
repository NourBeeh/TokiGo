import 'package:flutter/material.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/features/home/presentation/widgets/deal_card.dart';
import 'package:tokigo/features/home/presentation/widgets/destination_discovery_card.dart';
import 'package:tokigo/features/home/presentation/widgets/flight_recommendation_list.dart';
import 'package:tokigo/features/home/presentation/widgets/home_card.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';

typedef FlightTapCallback = void Function(HomeItem flight);
typedef ViewAllCallback = void Function();
typedef WishlistChangedCallback = void Function(String flightId, bool value);

class HomeSectionWidget extends StatelessWidget {
  const HomeSectionWidget({
    super.key,
    required this.section,
    this.onFlightTap,
    this.onViewAllFlights,
    this.onFavorite,
  });

  final HomeSection section;
  final FlightTapCallback? onFlightTap;
  final ViewAllCallback? onViewAllFlights;
  final WishlistChangedCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    // Flight recommendation list renders its own header, so skip the section title
    if (section.layout == HomeSectionLayout.flightRecommendationList) {
      return _buildFlightRecommendationList(context);
    }

    // Deal vertical list renders its own header
    if (section.layout == HomeSectionLayout.verticalDealList) {
      return _buildDealVerticalList(context);
    }

    // For sections with only flights, render as FlightRecommendationList regardless of layout
    if (_isFlightOnlySection) {
      return _buildFlightRecommendationList(context);
    }

    // For sections with only deals, render as vertical deal list
    if (_isDealOnlySection) {
      return _buildDealVerticalList(context);
    }

    // For sections with only destinations, render as horizontal destination cards
    if (_isDestinationOnlySection) {
      return _buildDestinationCarousel(context);
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(section.title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildItems(context),
        ],
      ),
    );
  }

  bool get _isFlightOnlySection =>
      section.items.isNotEmpty && section.items.every((item) => item.type == HomeCardType.flight);

  bool get _isDealOnlySection =>
      section.items.isNotEmpty && section.items.every((item) => item.type == HomeCardType.deal);

  bool get _isDestinationOnlySection =>
      section.items.isNotEmpty && section.items.every((item) => item.type == HomeCardType.destination);

  /// True when the item carries no data at all (empty title, no image, no
  /// price) — i.e. a development-preview/skeleton entry. Such items render
  /// the approved cards in their skeleton/loading state.
  static bool _isSkeletonItem(HomeItem item) =>
      item.title.trim().isEmpty &&
      item.price == null &&
      (item.imageUrl == null || item.imageUrl!.isEmpty);

  /// Renders the correct card for [item] across every layout.
  ///
  /// Data-bearing items use the approved cards; skeleton (no-data) items use
  /// the same approved cards with `loading: true`, so the Home feed renders a
  /// pure skeleton preview while the API returns nothing.
  Widget _cardForItem(HomeItem item) {
    final isSkeleton = _isSkeletonItem(item);
    switch (item.type) {
      case HomeCardType.hotel:
      case HomeCardType.car:
      case HomeCardType.package:
        return HomeCard(item: item);
      case HomeCardType.flight:
        return FlightRecommendationList(
          items: <HomeItem>[item],
          title: '',
          maxRows: 1,
          loading: isSkeleton,
          onTapFlight: onFlightTap,
          onViewAll: onViewAllFlights,
          onFavorite: onFavorite,
        );
      case HomeCardType.deal:
        return DealCard(
          item: item,
          loading: isSkeleton,
          onTap: () => onFlightTap?.call(item),
        );
      case HomeCardType.destination:
        return DestinationDiscoveryCard(
          item: item,
          loading: isSkeleton,
          onTap: onFlightTap != null ? () => onFlightTap!(item) : null,
        );
    }
  }

  Widget _buildItems(BuildContext context) {
    switch (section.layout) {
      case HomeSectionLayout.vertical:
        return ListView.builder(
          itemCount: section.items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildItemCard(context, section.items[i]),
          ),
        );
      case HomeSectionLayout.horizontal:
        return _buildHorizontalCarousel(context, peek: false);
      case HomeSectionLayout.horizontalPeek:
        return _buildHorizontalCarousel(context, peek: true);
      case HomeSectionLayout.grid:
        return _buildResponsiveGrid(context);
      case HomeSectionLayout.flightRecommendationList:
        return _buildFlightRecommendationList(context);
      case HomeSectionLayout.verticalDealList:
        return _buildDealVerticalList(context);
    }
  }

  Widget _buildItemCard(BuildContext context, HomeItem item) {
    return _cardForItem(item);
  }

  Widget _buildFlightRecommendationList(BuildContext context) {
    // Filter only flight items for this layout
    final flightItems = section.items
        .where((item) => item.type == HomeCardType.flight)
        .toList();

    if (flightItems.isEmpty) return const SizedBox.shrink();

    return FlightRecommendationList(
      items: flightItems,
      title: section.title,
      loading: _isSkeletonItem(flightItems.first),
      onTapFlight: onFlightTap,
      onViewAll: onViewAllFlights,
      onFavorite: onFavorite,
    );
  }

  Widget _buildHorizontalCarousel(BuildContext context, {required bool peek}) {
    final primaryType = section.items.isNotEmpty ? section.items.first.type : HomeCardType.hotel;
    final cardHeight = HomeCardDimensions.cardHeightForType(primaryType);
    final cardWidth = HomeCardDimensions.cardWidthForType(primaryType);

    final carouselHeight = cardHeight + 8;
    final itemWidth = cardWidth;
    final peekExtent = peek ? 48.0 : 0.0;

    return SizedBox(
      height: carouselHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: section.items.length,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemBuilder: (_, i) => SizedBox(
          width: itemWidth + peekExtent,
          child: Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: _buildHorizontalItemCard(context, section.items[i]),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalItemCard(BuildContext context, HomeItem item) {
    return _cardForItem(item);
  }

  Widget _buildResponsiveGrid(BuildContext context) {
    final primaryType = section.items.isNotEmpty ? section.items.first.type : HomeCardType.hotel;
    final crossAxisCount = HomeCardDimensions.gridCrossAxisCount(context);
    final childAspectRatio = HomeCardDimensions.gridChildAspectRatio(primaryType);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: section.items.length,
      itemBuilder: (_, i) => _buildGridItemCard(context, section.items[i]),
    );
  }

  Widget _buildGridItemCard(BuildContext context, HomeItem item) {
    return _cardForItem(item);
  }

  Widget _buildDestinationCarousel(BuildContext context) {
    final destinationItems = section.items
        .where((item) => item.type == HomeCardType.destination)
        .toList();

    if (destinationItems.isEmpty) return const SizedBox.shrink();

    final cardHeight = HomeCardDimensions.cardHeightForType(HomeCardType.destination);
    final cardWidth = HomeCardDimensions.cardWidthForType(HomeCardType.destination);
    final carouselHeight = cardHeight + 8;
    final itemWidth = cardWidth;

    final skeletons = _isSkeletonItem(destinationItems.first);

    return SizedBox(
      height: carouselHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: destinationItems.length,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemBuilder: (_, i) => SizedBox(
          width: itemWidth,
          child: Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: DestinationDiscoveryCard(
              item: destinationItems[i],
              loading: skeletons,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDealVerticalList(BuildContext context) {
    // Filter only deal items for this layout
    final dealItems = section.items
        .where((item) => item.type == HomeCardType.deal)
        .toList();

    if (dealItems.isEmpty) return const SizedBox.shrink();

    final skeletons = _isSkeletonItem(dealItems.first);

    return ListView.builder(
      itemCount: dealItems.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemBuilder: (_, i) => Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: DealCard(
          item: dealItems[i],
          loading: skeletons,
          onTap: () => onFlightTap?.call(dealItems[i]),
        ),
      ),
    );
  }
}