import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/domain/models/offers/travel_package_offer.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_section_title.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The page's long-form sections: description, taxes & fees, cancellation,
/// car policies, package inclusions and the provider footnote.
///
/// Every block is provider-verbatim. When the provider sent nothing for a
/// section, the section is absent rather than filled with a generic sentence.
class OfferDetailsContentSections extends StatelessWidget {
  const OfferDetailsContentSections({super.key, required this.offer});

  final Object offer;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final widgets = <Widget>[];

    final description = switch (offer) {
      FlightOffer o => o.description,
      HotelOffer o => o.description,
      CarOffer o => o.description,
      TravelPackageOffer o => o.description,
      _ => null,
    };
    if (description != null && description.isNotEmpty) {
      widgets.addAll(<Widget>[
        OfferDetailsSectionTitle(
          typography: typography,
          title: l10n.offerAbout,
        ),
        Text(
          description,
          style: typography.body.copyWith(color: AppColors.textSecondary),
        ),
      ]);
    }

    // 3D — Hotel taxes & cancellation policy (provider-verbatim).
    final hotel = offer is HotelOffer ? offer as HotelOffer : null;
    if (hotel != null) {
      final taxes = hotel.metadata['taxesAndFees'];
      if (taxes is Map && taxes['amount'] != null) {
        widgets.addAll(<Widget>[
          OfferDetailsSectionTitle(
            typography: typography,
            title: l10n.offerTaxesFees,
          ),
          Text(
            '${taxes['description'] ?? l10n.offerTaxesFees}: '
            '${taxes['currency']} ${taxes['amount']}'
            '${taxes['included'] == true ? ' ${l10n.offerTaxesIncluded}' : ''}',
            style: typography.body.copyWith(color: AppColors.textSecondary),
          ),
        ]);
      }
      final cancellation = hotel.metadata['cancellationPolicy'];
      if (cancellation is Map) {
        final until = cancellation['refundableUntil'];
        final fee = cancellation['feeAmount'];
        final feeCurrency = cancellation['feeCurrency'];
        widgets.addAll(<Widget>[
          OfferDetailsSectionTitle(
            typography: typography,
            title: l10n.offerCancellation,
          ),
          if (hotel.metadata['refundable'] == true)
            Text(
              until != null
                  ? l10n.offerFreeCancellationUntil('$until')
                  : l10n.offerRefundableRate,
              style: typography.body.copyWith(color: AppColors.textSecondary),
            )
          else
            Text(
              l10n.offerNonRefundableRate,
              style: typography.body.copyWith(color: AppColors.textSecondary),
            ),
          if (hotel.metadata['refundable'] == true && fee != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.offerCancellationFeeNote('$feeCurrency $fee'),
              style: typography.caption.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ]);
      } else if (hotel.metadata['refundable'] == false) {
        widgets.addAll(<Widget>[
          OfferDetailsSectionTitle(
            typography: typography,
            title: l10n.offerCancellation,
          ),
          Text(
            l10n.offerNonRefundableRate,
            style: typography.body.copyWith(color: AppColors.textSecondary),
          ),
        ]);
      }
    }

    // 3D — Car policies (provider-verbatim; only what the vendor sent).
    final car = offer is CarOffer ? offer as CarOffer : null;
    if (car != null) {
      final cancellation = car.metadata['cancellationPolicy'];
      if (cancellation != null) {
        widgets.addAll(<Widget>[
          OfferDetailsSectionTitle(
            typography: typography,
            title: l10n.offerCancellation,
          ),
          Text(
            '$cancellation',
            style: typography.body.copyWith(color: AppColors.textSecondary),
          ),
        ]);
      }
      final features = car.metadata['features'];
      if (features is List && features.isNotEmpty) {
        widgets.addAll(<Widget>[
          OfferDetailsSectionTitle(
            typography: typography,
            title: l10n.offerFeatures,
          ),
          Text(
            features.join(' · '),
            style: typography.body.copyWith(color: AppColors.textSecondary),
          ),
        ]);
      }
    }

    // 3D — Package inclusions (verbatim from the offer model).
    final pkg = offer is TravelPackageOffer
        ? offer as TravelPackageOffer
        : null;
    if (pkg != null && pkg.inclusions.isNotEmpty) {
      widgets.addAll(<Widget>[
        OfferDetailsSectionTitle(
          typography: typography,
          title: l10n.offerInclusions,
        ),
        for (final line in pkg.inclusions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppColors.brand,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    line,
                    style: typography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ]);
    }

    // Hotel amenities live up under the hotel's name (reference screen 6's
    // facility strip) — one place for them, never two.

    // Provider footnote for every offer.
    widgets.addAll(<Widget>[
      OfferDetailsSectionTitle(
        typography: typography,
        title: l10n.offerProvider,
      ),
      Text(switch (offer) {
        FlightOffer o => o.providerName,
        HotelOffer o => o.providerName,
        CarOffer o => o.providerName,
        TravelPackageOffer o => o.providerName,
        _ => '',
      }, style: typography.bodyMedium.copyWith(color: AppColors.textPrimary)),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
