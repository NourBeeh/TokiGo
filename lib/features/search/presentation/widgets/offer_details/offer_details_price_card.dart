import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/search/domain/stay_price.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_section_title.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The price block: the provider's own total, then the honest per-night reading
/// for a stay.
///
/// The provider sends ONE total. The reference design splits it into
/// "Base fare + Taxes & fees"; we do not — inventing a breakdown would state
/// numbers the provider never gave. What we add instead is the per-night figure
/// (the provider's own, or its stay total divided by the stay's real nights),
/// and a note that the price is revalidated when the booking is created.
class OfferDetailsPriceCard extends StatelessWidget {
  const OfferDetailsPriceCard({
    super.key,
    required this.price,
    required this.currency,
    this.stay,
  });

  final double price;
  final String currency;

  /// The hotel's honest stay reading. Null for non-hotel offers.
  final StayPrice? stay;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final stayInfo = stay;
    final perNight = stayInfo?.perNight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OfferDetailsSectionTitle(
          typography: typography,
          title: l10n.offerPrice,
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.offerTotalFromProvider,
                      style: typography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    // Exact provider amount, two decimals — the same rendering
                    // the booking funnel uses, so this screen, checkout and the
                    // confirmation never disagree about the price.
                    '$currency ${price.toStringAsFixed(2)}',
                    style: typography.title.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              // The per-night reading the reference headlines. It is either the
              // provider's own figure or the provider's stay total divided by
              // the stay's real nights — never an assumed rate. The total above
              // stays the number we charge.
              if (stayInfo != null && perNight != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '$currency ${perNight.toStringAsFixed(2)}'
                  ' ${l10n.cardPerUnitLabel(l10n.unitNight)}'
                  ' · ${stayInfo.derived ? l10n.offerPerNightDerived(l10n.hotelNightsCount(stayInfo.nights)) : l10n.offerPerNightStated}',
                  style: typography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.offerPriceNote,
                style: typography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              // Honestly: this is a presentation snapshot, revalidated when the
              // booking is created (3D, spec point 44).
              Text(
                l10n.offerRevalidated,
                style: typography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: AppTypography.fontSizeLabel,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
