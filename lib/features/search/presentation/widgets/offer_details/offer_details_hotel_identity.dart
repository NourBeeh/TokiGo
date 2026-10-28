import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/search/presentation/widgets/hotel_amenities_strip.dart';
import 'package:tokigo/features/search/presentation/widgets/hotel_class_line.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The hotel's own facts under its name (reference screen 6): the provider's
/// star classification beside the place, the guest score with its review count,
/// and the facilities it listed.
///
/// Every part is optional — a hotel that reported no class, no score or no
/// facilities simply shows fewer lines, and one that reported nothing shows
/// none. Nothing here is filled in on the provider's behalf.
class OfferDetailsHotelIdentity extends StatelessWidget {
  const OfferDetailsHotelIdentity({super.key, required this.hotel});

  final HotelOffer hotel;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final rating = hotel.rating;
    final reviews = hotel.reviewCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        HotelClassLocationLine(
          stars: hotel.starClass,
          city: hotel.city,
          country: hotel.country,
          // Doc 18 §2.5 — the class stars are bronze, 16px.
          iconSize: 16,
          starColor: AppColors.starFill,
          style: typography.body.copyWith(color: AppColors.textSecondary),
        ),
        if (rating != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              const Icon(
                Icons.star_rounded,
                size: 16,
                color: AppColors.starFill,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                rating.toStringAsFixed(1),
                style: typography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              if (reviews != null && reviews > 0) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '·',
                  style: typography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.offerReviewsCount(reviews),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Doc 18 §2.5 — 13/400 `textSecondary` (AA on the sheet).
                    style: typography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (hotel.amenities.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          HotelAmenitiesStrip(amenities: hotel.amenities),
        ],
      ],
    );
  }
}
