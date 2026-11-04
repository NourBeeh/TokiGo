import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/features/home/presentation/widgets/deal_card.dart';
import 'package:tokigo/features/home/presentation/widgets/destination_discovery_card.dart';
import 'package:tokigo/features/home/presentation/widgets/discovery_product_card.dart';
import 'package:tokigo/features/home/presentation/widgets/flight_recommendation_card.dart';
import 'package:tokigo/features/home/presentation/widgets/flight_recommendation_list.dart';
import 'package:tokigo/features/home/presentation/widgets/home_section_titles.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stay_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stays_carousel.dart';
import 'package:tokigo/features/home/presentation/widgets/destination_cover_flow_carousel.dart';
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
    this.onItemTap,
  });

  final HomeSection section;
  final FlightTapCallback? onFlightTap;
  final ViewAllCallback? onViewAllFlights;
  final WishlistChangedCallback? onFavorite;

  /// US-6 — a general tap callback for every card type (hotel/car/package
  /// included), so the Universal Search results can hand off a `SelectedOffer`
  /// without altering the card widgets themselves.
  final FlightTapCallback? onItemTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    HomeSectionTitles.title(l10n, section.metadata, section.title),
                    style: AppTypography.forLight().titleMedium.copyWith(
                      color: context.tokigoColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isDestinationOnlySection)
                  Pressable(
                    onTap: () => context.push('/explore'),
                    child: TextButton(
                      onPressed: () => context.push('/explore'),
                      child: Text(l10n?.exploreFilterAll ?? 'All'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildItems(context),
        ],
      ),
    );
  }

  bool get _isFlightOnlySection =>
      section.items.isNotEmpty &&
      section.items.every((item) => item.type == HomeCardType.flight);

  bool get _isDealOnlySection =>
      section.items.isNotEmpty &&
      section.items.every((item) => item.type == HomeCardType.deal);

  bool get _isDestinationOnlySection =>
      section.items.isNotEmpty &&
      section.items.every((item) => item.type == HomeCardType.destination);

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
  /// Renders the card for [item].
  ///
  /// [inRail] is true when the card sits inside a horizontal carousel: a
  /// flight is then a single **flight card**, never the whole flight list
  /// (a list carries its own header and would overflow the rail).
  Widget _cardForItem(
    BuildContext context,
    HomeItem item, {
    bool inRail = false,
  }) {
    final isSkeleton = _isSkeletonItem(item);
    switch (item.type) {
      case HomeCardType.hotel:
        // Keep Home and results on the same structured hotel card.
        return HomeStayCard(
          item: item,
          margin: EdgeInsets.zero,
          onTap: onItemTap != null ? () => onItemTap!(item) : null,
        );
      case HomeCardType.car:
      case HomeCardType.package:
        return DiscoveryProductCard(
          item: item,
          onTap: onItemTap != null ? () => onItemTap!(item) : null,
        );
      case HomeCardType.deal:
        // Offer cards have their own price-and-discount hierarchy.
        return DealCard(
          item: item,
          loading: isSkeleton,
          onTap: onItemTap != null ? () => onItemTap!(item) : null,
        );
      case HomeCardType.flight:
        if (inRail) {
          return FlightRecommendationCard(
            item: item,
            loading: isSkeleton,
            onTap: onFlightTap != null ? () => onFlightTap!(item) : null,
            onFavorite: onFavorite != null
                ? (bool value) => onFavorite!(item.id, value)
                : null,
          );
        }
        return FlightRecommendationList(
          items: <HomeItem>[item],
          title: '',
          maxRows: 1,
          loading: isSkeleton,
          onTapFlight: onFlightTap,
          onViewAll: onViewAllFlights,
          onFavorite: onFavorite,
        );
      case HomeCardType.destination:
        // Card D — the image-first city tile. Its tap opens the city's own
        // information page, not a pre-filtered search.
        return DestinationDiscoveryCard(
          item: item,
          onTap: () => _openCity(context, item),
        );
    }
  }

  void _openCity(BuildContext context, HomeItem item) {
    final String city = (item.metadata['city'] ?? item.title).toString().trim();
    if (city.isEmpty) return;
    context.push('/city', extra: item);
  }

  Widget _buildItems(BuildContext context) {
    // A section whose items carry no data at all renders NOTHING: an empty
    // heading with an empty row reads as broken, not as loading.
    final List<HomeItem> items = section.items
        .where((HomeItem item) => !_isSkeletonItem(item))
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    switch (section.layout) {
      case HomeSectionLayout.vertical:
        return ListView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildItemCard(context, items[i]),
          ),
        );
      case HomeSectionLayout.horizontal:
        return _buildHorizontalCarousel(context, items);
      case HomeSectionLayout.horizontalPeek:
        return _buildHorizontalCarousel(context, items);
      case HomeSectionLayout.grid:
        // OWNER DECISION (2026-10-21): Discover SWIPES. A destination-only
        // section is a city rail — one full card D per swipe — never a
        // two-column grid that stalls the feed and shrinks every tile.
        if (_isDestinationOnlySection) {
          return _buildHorizontalCarousel(context, items);
        }
        return _buildResponsiveGrid(context, items);
      case HomeSectionLayout.flightRecommendationList:
        return _buildFlightRecommendationList(context);
      case HomeSectionLayout.verticalDealList:
        return _buildDealVerticalList(context);
    }
  }

  Widget _buildItemCard(BuildContext context, HomeItem item) {
    return _cardForItem(context, item);
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

  Widget _buildHorizontalCarousel(BuildContext context, List<HomeItem> items) {
    final primaryType = items.isNotEmpty
        ? items.first.type
        : HomeCardType.hotel;
    if (primaryType == HomeCardType.hotel) {
      // The hotel rail keeps [HomeStaysCarousel] unchanged.
      return HomeStaysCarousel(
        items: items,
        viewportFraction: 0.8,
        sheetTextHeight: HomeStaysCarousel.staysSheetTextHeight,
        onItemTap: onItemTap,
      );
    }

    // Destination-only section: the premium 3D cover flow.
    if (primaryType == HomeCardType.destination) {
      return DestinationCoverFlowCarousel(
        items: items,
        onItemTap: onItemTap,
        viewportFraction: 0.9,
      );
    }

    // Fall through for non-hotel, non-destination items.
    final cardHeight = HomeCardDimensions.cardHeightForType(primaryType);
    final cardWidth = HomeCardDimensions.cardWidthForType(primaryType);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double itemWidth = (constraints.maxWidth - AppSpacing.lg * 2)
            .clamp(1.0, cardWidth)
            .toDouble();

        return SizedBox(
          height: cardHeight + 8,
          child: PageView.builder(
            itemCount: items.length,
            itemBuilder: (BuildContext context, int index) => Center(
              child: SizedBox(
                width: itemWidth,
                child: _buildHorizontalItemCard(context, items[index]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHorizontalItemCard(BuildContext context, HomeItem item) {
    return _cardForItem(context, item, inRail: true);
  }

  Widget _buildResponsiveGrid(BuildContext context, List<HomeItem> items) {
    final primaryType = items.isNotEmpty
        ? items.first.type
        : HomeCardType.hotel;
    final crossAxisCount = HomeCardDimensions.gridCrossAxisCount(context);
    final childAspectRatio = HomeCardDimensions.gridChildAspectRatio(
      primaryType,
    );

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
    return _cardForItem(context, item);
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
