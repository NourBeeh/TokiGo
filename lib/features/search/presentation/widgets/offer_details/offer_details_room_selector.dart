import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/ui/localized_date.dart';
import 'package:tokigo/features/search/domain/stay_price.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_section_title.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The details page's room selector.
///
/// The backend groups EVERY valid room-type offer for a hotel into one row, so
/// this widget lists them verbatim: room name, board, cancellation terms and
/// the provider's stay total. Selecting one changes the price and the booking
/// hand-off — it never filters or hides an offer the provider returned.
class OfferDetailsRoomSelector extends StatelessWidget {
  const OfferDetailsRoomSelector({
    super.key,
    required this.offers,
    required this.selected,
    required this.onSelected,
  });

  final List<HotelOffer> offers;
  final HotelOffer selected;
  final ValueChanged<HotelOffer> onSelected;

  @override
  Widget build(BuildContext context) {
    // One offer needs no chooser: the row already shows its facts and price.
    if (offers.length < 2) return const SizedBox.shrink();
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OfferDetailsSectionTitle(
          typography: typography,
          title: l10n.offerChooseRoom,
        ),
        for (int i = 0; i < offers.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _RoomOption(
            offer: offers[i],
            isSelected:
                identical(offers[i], selected) || offers[i].id == selected.id,
            onTap: () => onSelected(offers[i]),
          ),
        ],
      ],
    );
  }
}

class _RoomOption extends StatelessWidget {
  const _RoomOption({
    required this.offer,
    required this.isSelected,
    required this.onTap,
  });

  final HotelOffer offer;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final tc = context.tokigoColors;
    final board = offer.boardName;
    final stay = StayPrice.of(offer);

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
                        offer.roomType.isNotEmpty
                            ? offer.roomType
                            : l10n.offerRoom,
                        style: typography.bodyMedium.copyWith(
                          color: tc.textPrimary,
                        ),
                      ),
                      if (board != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          board,
                          style: typography.caption.copyWith(
                            color: tc.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _cancellationLine(context, l10n, offer),
                        style: typography.caption.copyWith(
                          color: offer.refundable == false
                              ? tc.textSecondary
                              : tc.success,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      offer.currency.isNotEmpty
                          ? '${offer.currency} '
                                '${offer.price.toStringAsFixed(2)}'
                          : offer.price.toStringAsFixed(2),
                      style: typography.title.copyWith(color: tc.textPrimary),
                    ),
                    if (stay.nights > 0)
                      Text(
                        l10n.offerPerStay,
                        style: typography.caption.copyWith(
                          color: tc.textTertiary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The provider's own cancellation truth, tri-state: a tagged refundable
  /// rate, a tagged non-refundable rate, or no tag at all (never assumed).
  String _cancellationLine(
    BuildContext context,
    AppLocalizations l10n,
    HotelOffer offer,
  ) {
    if (offer.refundable == false) return l10n.offerNonRefundable;
    if (offer.refundable != true) return l10n.offerCancellationUnknown;
    final DateTime? until = offer.freeCancellationUntil;
    if (until != null) {
      return l10n.offerFreeCancellationUntil(
        localizedMediumDate(context, until),
      );
    }
    return l10n.offerFreeCancellation;
  }
}
