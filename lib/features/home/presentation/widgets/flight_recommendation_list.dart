import 'package:flutter/material.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/features/home/presentation/widgets/cover_flow_carousel.dart';
import 'package:tokigo/features/home/presentation/widgets/flight_recommendation_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_card_loading.dart';

/// Flight recommendation section for Home.
///
/// A pure SECTION CONTAINER: header (title + View All) followed by a
/// horizontal carousel of [FlightRecommendationCard] tiles. All row/tile UI
/// lives inside the card — this widget never renders flight data itself.
///
/// Tap card → Flight Details (/booking/review); "View All" → Flight Search
/// (/flights) — both wired by the parent through callbacks.
class FlightRecommendationList extends StatelessWidget {
  const FlightRecommendationList({
    super.key,
    required this.items,
    this.onTapFlight,
    this.onViewAll,
    this.onFavorite,
    this.title = 'Recommended Flights',
    this.maxRows = 3,
    this.loading = false,
  });

  final List<HomeItem> items;
  final void Function(HomeItem flight)? onTapFlight;
  final VoidCallback? onViewAll;
  final void Function(String flightId, bool value)? onFavorite;
  final String title;

  /// Maximum number of cards visible in the carousel.
  final int maxRows;

  /// When true (or when items are skeleton entries), cards render their
  /// skeleton state with no fake data.
  final bool loading;

  /// True when an item carries no data at all — a skeleton entry.
  static bool _isSkeletonItem(HomeItem item) => isHomeSkeletonItem(item);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardHeight = HomeCardDimensions.cardHeightForType(
      HomeCardType.flight,
    );
    final displayItems = items.take(maxRows).toList();
    final isLoading =
        loading || displayItems.isEmpty || _isSkeletonItem(displayItems.first);
    final tileCount = isLoading ? maxRows.clamp(1, 3) : displayItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with title and View All
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (onViewAll != null && !isLoading)
                Pressable.wrap(
                  child: TextButton(
                    onPressed: onViewAll,
                    child: Text(
                      // Null-safe: a bare test host has no localizations, and the English
                      // form is the documented fallback.
                      AppLocalizations.of(context)?.viewAll ?? 'View all',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Horizontal carousel of FlightRecommendationCards.
        //
        // The SAME 3D cover flow as every other Home card rail (owner decision,
        // 2026-11): one centred page with its neighbours peeking, tilted in 3D.
        // No second pager implementation lives in this file.
        CoverFlowCarousel(
          itemCount: tileCount,
          viewportFraction: HomeCardDimensions.cardRailViewportFraction,
          height: cardHeight,
          itemBuilder: (BuildContext context, int index) {
            final HomeItem? item = isLoading ? null : displayItems[index];
            if (item == null) {
              return const FlightRecommendationCard(
                item: HomeItem(
                  id: '',
                  type: HomeCardType.flight,
                  title: '',
                ),
                loading: true,
              );
            }
            return FlightRecommendationCard(
              item: item,
              onTap: onTapFlight != null ? () => onTapFlight!(item) : null,
              onFavorite: onFavorite != null
                  ? (value) => onFavorite!(item.id, value)
                  : null,
            );
          },
        ),
      ],
    );
  }
}
