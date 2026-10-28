import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/domain/models/offers/travel_package_offer.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/localized_date.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Key-fact card for the non-flight verticals (a flight renders its route block
/// instead).
///
/// One row per fact the provider actually sent. A null field is omitted, not
/// printed as "–": an absent rating is absent, not zero.
class OfferDetailsSummaryCard extends StatelessWidget {
  const OfferDetailsSummaryCard({super.key, required this.offer});

  final Object offer;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final rows = _rowsFor(context, offer);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Icon(rows[i].$3, size: 18, color: AppColors.brand),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    rows[i].$1,
                    style: typography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                Text(
                  rows[i].$2,
                  style: typography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<(String, String, IconData)> _rowsFor(
    BuildContext context,
    Object offer,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return switch (offer) {
      HotelOffer o => <(String, String, IconData)>[
        (
          l10n.offerCheckIn,
          // Check-in/out are calendar days in the provider payload (no clock
          // time), so no fabricated "00:00" is appended.
          localizedMediumDate(context, o.checkIn),
          Icons.login_rounded,
        ),
        (
          l10n.offerCheckOut,
          localizedMediumDate(context, o.checkOut),
          Icons.logout_rounded,
        ),
        if (o.roomType.isNotEmpty)
          (l10n.offerRoom, o.roomType, Icons.bed_rounded),
        // The guest score and the star class live in the identity block under
        // the hotel's name (with the review count), so they are not repeated
        // here as bare rows.
        if (o.metadata['boardName'] != null)
          (
            l10n.offerBoard,
            '${o.metadata['boardName']}',
            Icons.restaurant_rounded,
          ),
      ],
      CarOffer o => <(String, String, IconData)>[
        if (o.pickupLocation.isNotEmpty)
          (l10n.offerPickup, o.pickupLocation, Icons.pin_drop_rounded),
        if (o.dropoffLocation.isNotEmpty)
          (l10n.offerDropOff, o.dropoffLocation, Icons.pin_drop_rounded),
        if (o.carType.isNotEmpty)
          (l10n.offerCarType, o.carType, Icons.directions_car_rounded),
        if (o.transmission != null)
          (l10n.offerTransmission, o.transmission!, Icons.settings_rounded),
        if (o.seats != null)
          (l10n.offerSeats, '${o.seats}', Icons.event_seat_rounded),
        if (o.metadata['mileagePolicy'] != null)
          (
            l10n.offerMileage,
            '${o.metadata['mileagePolicy']}',
            Icons.speed_rounded,
          ),
      ],
      TravelPackageOffer o => <(String, String, IconData)>[
        if (o.destination.isNotEmpty)
          (l10n.offerDestination, o.destination, Icons.place_rounded),
        (
          l10n.offerDuration,
          l10n.offerDays(o.durationDays),
          Icons.timelapse_rounded,
        ),
        if (o.rating != null)
          (l10n.offerRating, '${o.rating}', Icons.star_rounded),
      ],
      // A flight renders its own journey block instead.
      _ => const <(String, String, IconData)>[],
    };
  }
}
