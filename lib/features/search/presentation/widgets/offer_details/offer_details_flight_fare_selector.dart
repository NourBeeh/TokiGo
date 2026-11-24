import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/cards/card_price.dart';
import 'package:tokigo/features/search/presentation/widgets/flight_fare_facts.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_section_title.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The details page's fare selector.
///
/// The backend groups every valid fare for one identical itinerary into a
/// single row, so this widget lists them all verbatim: fare brand, cabin,
/// baggage, refund/change rules and the provider's own price. Selecting one
/// changes the price and the booking hand-off — it never hides a fare the
/// provider returned.
class OfferDetailsFlightFareSelector extends StatelessWidget {
  const OfferDetailsFlightFareSelector({
    super.key,
    required this.offers,
    required this.selected,
    required this.onSelected,
  });

  final List<FlightOffer> offers;
  final FlightOffer selected;
  final ValueChanged<FlightOffer> onSelected;

  @override
  Widget build(BuildContext context) {
    // One fare needs no chooser: the journey block already shows its facts.
    if (offers.length < 2) return const SizedBox.shrink();
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OfferDetailsSectionTitle(
          typography: typography,
          title: l10n.offerChooseFare,
        ),
        for (int i = 0; i < offers.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _FareOption(
            offer: offers[i],
            index: i,
            isSelected:
                identical(offers[i], selected) || offers[i].id == selected.id,
            onTap: () => onSelected(offers[i]),
          ),
        ],
      ],
    );
  }
}

class _FareOption extends StatelessWidget {
  const _FareOption({
    required this.offer,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  final FlightOffer offer;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final tc = context.tokigoColors;
    final cabin = offer.cabinClass;
    final baggage = flightBaggageSummary(l10n, offer);
    final restrictions = flightRestrictionsLine(offer);
    final codeshares = <String>{};
    for (final segment in offer.segments) {
      if (!segment.isCodeshare) continue;
      final name =
          segment.operatingCarrierName ?? segment.operatingCarrierCode ?? '';
      final designator = segment.operatingDesignator;
      if (name.isEmpty) continue;
      codeshares.add(designator.isEmpty ? name : '$name ($designator)');
    }

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isSelected ? tc.brand.withValues(alpha: 0.06) : tc.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isSelected ? tc.brand : tc.outline,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: isSelected ? tc.brand : tc.textTertiary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        flightFareTitle(l10n, offer, index),
                        style: typography.bodyMedium.copyWith(
                          color: tc.textPrimary,
                        ),
                      ),
                      if (cabin != null && cabin.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          cabin,
                          style: typography.caption.copyWith(
                            color: tc.textSecondary,
                          ),
                        ),
                      ],
                      if (baggage != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          baggage,
                          style: typography.caption.copyWith(
                            color: tc.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        flightRefundLine(l10n, offer),
                        style: typography.caption.copyWith(
                          color: offer.refundable == false
                              ? tc.textSecondary
                              : offer.refundable == true
                              ? tc.success
                              : tc.textTertiary,
                        ),
                      ),
                      Text(
                        flightChangeLine(l10n, offer),
                        style: typography.caption.copyWith(
                          color: offer.changeable == false
                              ? tc.textSecondary
                              : offer.changeable == true
                              ? tc.success
                              : tc.textTertiary,
                        ),
                      ),
                      if (codeshares.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          l10n.offerOperatedBy(codeshares.join(', ')),
                          style: typography.caption.copyWith(
                            color: tc.textTertiary,
                          ),
                        ),
                      ],
                      if (restrictions != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${l10n.offerRestrictions}: $restrictions',
                          style: typography.caption.copyWith(
                            color: tc.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  formatCardPrice(
                    price: offer.price,
                    currency: offer.currency,
                  ),
                  style: typography.title.copyWith(color: tc.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
