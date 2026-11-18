import 'package:flutter/material.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/section_header.dart';
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
    final cardHeight = HomeCardDimensions.cardHeightForType(
      HomeCardType.flight,
    );
    final displayItems = items.take(maxRows).toList();
    final isLoading =
        loading || displayItems.isEmpty || _isSkeletonItem(displayItems.first);
    final tileCount = isLoading ? maxRows.clamp(1, 3) : displayItems.length;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final AppTypography typography = dark
        ? AppTypography.forDark()
        : AppTypography.forLight();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header: the SAME shared `SectionHeader` step and rhythm as every
        // other Home section, so the flight rail's heading lands on the same
        // lines. Its action is the theme's brand ink — never the red primary,
        // which is reserved for primary CTAs and selected states.
        SectionHeader(
          title: title,
          titleStyle: typography.titleMedium.copyWith(
            color: context.tokigoColors.textPrimary,
          ),
          actionLabel: onViewAll != null && !isLoading
              ? (AppLocalizations.of(context)?.viewAll ?? 'View all')
              : null,
          onAction: onViewAll,
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
                item: HomeItem(id: '', type: HomeCardType.flight, title: ''),
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
