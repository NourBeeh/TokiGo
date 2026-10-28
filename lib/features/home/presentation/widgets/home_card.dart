import 'package:flutter/material.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/features/home/presentation/widgets/deal_card.dart';
import 'package:tokigo/features/home/presentation/widgets/destination_discovery_card.dart';
import 'package:tokigo/features/home/presentation/widgets/discovery_product_card.dart';

/// Type dispatcher for Home feed items.
///
/// Approved discovery cards (Wave 2): [DestinationDiscoveryCard],
/// [DealCard], [FlightRecommendationCard] (via section layout) and the
/// unified [DiscoveryProductCard] for hotel / car / package items — real
/// data cards with rating, highlights and price. Skeleton-only previews
/// remain for loading states and empty dev-preview items.
class HomeCard extends StatelessWidget {
  const HomeCard({super.key, required this.item, this.onTap});

  final HomeItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    switch (item.type) {
      case HomeCardType.hotel:
      case HomeCardType.car:
      case HomeCardType.package:
        // Real data renders the unified product card; dev-preview items
        // (empty title/price) keep the skeleton preview.
        if (_isSkeleton(item)) {
          return const HomeSkeletonCard();
        }
        return DiscoveryProductCard(item: item, onTap: onTap);
      case HomeCardType.destination:
        return DestinationDiscoveryCard(item: item);
      case HomeCardType.deal:
        return DealCard(item: item);
      case HomeCardType.flight:
        return const HomeSkeletonCard();
    }
  }

  /// Dev-preview items are empty (no fake data by design) — they keep the
  /// skeleton surface until real content arrives.
  static bool _isSkeleton(HomeItem item) =>
      item.title.isEmpty && item.price == null && item.imageUrl == null;
}

/// Unified skeleton-only preview card for Home item types that have no
/// approved product card design yet.
///
/// Uses the standard [BaseCard] surface + [CardSkeleton] blocks — no fake
/// travel data of any kind. Fixed vertical rhythm so carousels/grids keep a
/// stable layout while loading.
class HomeSkeletonCard extends StatelessWidget {
  const HomeSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: null,
      enabled: false,
      loading: true,
      semanticsLabel: 'Loading',
      padding: EdgeInsets.zero,
      child: cardLoadingSemantics(
        LayoutBuilder(
          builder: (context, constraints) {
            // When the parent constrains the card height (carousels/grids),
            // the image area absorbs whatever remains so the card never
            // overflows. Unconstrained (e.g. test wrap) falls back to 16:9.
            final hasHeightBound =
                constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
            final imageWidget = hasHeightBound
                ? Expanded(child: CardSkeleton.image())
                : AspectRatio(aspectRatio: 16 / 9, child: CardSkeleton.image());

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: hasHeightBound
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                imageWidget,
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CardSkeleton.title(width: 140),
                      CardSkeleton.gap(height: AppSpacing.xs),
                      CardSkeleton.text(width: 100),
                      CardSkeleton.gap(height: AppSpacing.sm),
                      Row(
                        children: [
                          CardSkeleton.chip(width: 64),
                          CardSkeleton.hGap(width: AppSpacing.xs),
                          CardSkeleton.chip(width: 56),
                        ],
                      ),
                      CardSkeleton.gap(height: AppSpacing.sm),
                      CardSkeleton.price(width: 88),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
