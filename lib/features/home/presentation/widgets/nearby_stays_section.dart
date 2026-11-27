import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/section_header.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/features/home/domain/promotional_stay.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/features/home/presentation/nearby_stays_controller.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stays_carousel.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Nearby Stays section (R6).
///
/// Renders promotional hotel cards around the traveller's real location. The
/// cached cards are published by the controller before the network settles;
/// this widget only draws them. Promotional prices are labelled as discovery
/// prices and never carry a stale/unverified warning.
class NearbyStaysSection extends StatelessWidget {
  const NearbyStaysSection({super.key, required this.state, this.onStayTap});

  final NearbyStaysState state;
  final ValueChanged<PromotionalStay>? onStayTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (state.stays.isEmpty) {
      switch (state.status) {
        case NearbyStaysStatus.loading:
          return const _NearbyStaysSkeleton();
        case NearbyStaysStatus.locationRequired:
          return _NearbyStaysMessage(
            icon: Icons.location_on_outlined,
            title: l10n.homeNearbyLocationTitle,
            body: l10n.homeNearbyLocationBody,
          );
        case NearbyStaysStatus.empty:
          return _NearbyStaysMessage(
            icon: Icons.explore_off_outlined,
            title: l10n.homeNearbyEmptyTitle,
            body: l10n.homeNearbyEmptyBody,
          );
        case NearbyStaysStatus.error:
          return _NearbyStaysMessage(
            icon: Icons.wifi_off_rounded,
            title: l10n.homeNearbyErrorTitle,
            body: l10n.homeNearbyErrorBody,
          );
        case NearbyStaysStatus.success:
          return const SizedBox.shrink();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SectionHeader(
                title: l10n.homeStaysTitle,
                titleStyle: Theme.of(context).textTheme.titleMedium,
              ),
              if (state.radiusKm != null)
                Text(
                  l10n.homeNearbyRadius(state.radiusKm!.round().toString()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        HomeStaysCarousel(
          items: <HomeItem>[
            for (final PromotionalStay stay in state.stays)
              promotionalStayToHomeItem(stay),
          ],
          splitLayout: false,
          photoAspectRatio: HomeCardDimensions.destinationMediaAspectRatio,
          showHeartPlatter: false,
          viewportFraction: HomeCardDimensions.destinationViewportFraction,
          cardHeightBuilder: HomeStaysCarousel.tallCardHeightFor,
          onItemTap: onStayTap == null
              ? null
              : (HomeItem item) {
                  final String id = item.id;
                  final PromotionalStay stay = state.stays.firstWhere(
                    (PromotionalStay candidate) => candidate.hotelId == id,
                    orElse: () => state.stays.first,
                  );
                  onStayTap!(stay);
                },
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: Text(
            l10n.homeNearbyPromotionalNote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Promotional card → the shared [HomeItem] the existing stay card renders.
///
/// `promotional: true` tells the card to show a per-night amount and to skip
/// the live-price verification hint. The metadata carries the REAL distance
/// from the traveller's location, the coordinates and the searched window.
HomeItem promotionalStayToHomeItem(PromotionalStay stay) {
  return HomeItem(
    id: stay.hotelId,
    type: HomeCardType.hotel,
    title: stay.hotelName,
    subtitle: <String>[
      stay.city,
      stay.country,
    ].where((String part) => part.isNotEmpty).join(', '),
    imageUrl: stay.image,
    price: stay.promotionalMinimumPrice,
    currency: stay.currency,
    rating: stay.rating,
    reviewCount: stay.reviewCount,
    metadata: <String, dynamic>{
      'city': stay.city,
      'country': stay.country,
      'latitude': stay.latitude,
      'longitude': stay.longitude,
      'distanceToCenter': stay.distanceKm,
      'promotional': true,
      'providerId': stay.provider,
      'locationConfidence': stay.locationConfidence,
      'searchedFromDate': stay.searchedFromDate,
      'searchedToDate': stay.searchedToDate,
    },
  );
}

class _NearbyStaysMessage extends StatelessWidget {
  const _NearbyStaysMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: AppMessageState(icon: icon, title: title, body: body),
    );
  }
}

class _NearbyStaysSkeleton extends StatelessWidget {
  const _NearbyStaysSkeleton();

  @override
  Widget build(BuildContext context) {
    // A STATIC placeholder (no repeating shimmer or progress indicator): the
    // promotional rail is cached and usually renders before this is ever seen,
    // and an indefinitely animating placeholder would keep a frame scheduled
    // forever (which also makes widget tests impossible to settle).
    return Container(
      height: HomeStaysCarousel.railHeight(context),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
