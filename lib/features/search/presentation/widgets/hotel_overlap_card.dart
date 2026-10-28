import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/cards/card_image.dart';
import 'package:tokigo/core/widgets/cards/overlap_stay_card.dart';
import 'package:tokigo/features/search/domain/stay_price.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Card A on the hotel results page — [OverlapStayCard] fed from a real
/// [HotelOffer].
///
/// The drawing (4:3 photo, −48 sheet, heart ⌀32, name/rating/price) lives in
/// the model-free card so Home and results render the identical shape.
class HotelOverlapCard extends StatelessWidget {
  const HotelOverlapCard({
    super.key,
    this.offer,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    this.enabled = true,
    this.loading = false,
  });

  /// Skeleton constructor — same geometry, no data.
  const HotelOverlapCard.loading({super.key})
    : offer = null,
      onTap = null,
      onFavorite = null,
      isFavorite = false,
      enabled = false,
      loading = true;

  /// The hotel data. Null only in the skeleton state.
  final HotelOffer? offer;

  final VoidCallback? onTap;
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final bool enabled;
  final bool loading;

  /// Heart diameter on card A (the detail hero uses 32 too, the destination
  /// tile 28 — the three are deliberately different).
  static const double heartSize = 32;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return OverlapStayCard.skeleton(
        margin: _margin,
        semanticsLabel:
            AppLocalizations.of(context)?.hotelLoading ?? 'Loading hotel',
      );
    }

    final HotelOffer data = offer!;
    final StayPrice stay = StayPrice.of(data);
    final String? unit = stay.perNight != null
        ? (AppLocalizations.of(context)?.unitNight ?? 'night')
        : null;
    final double amount = stay.fallbackAmount(data.price);
    final String money = NumberFormat.currency(
      symbol: '',
      locale: 'en_US',
      // Whole amounts read as "120", not "120.00" — the reference card has no
      // cents and a provider's fractional total keeps them.
      decimalDigits: amount % 1 == 0 ? 0 : 2,
    ).format(amount).trim();

    return OverlapStayCard(
      media: CardImage(
        url: data.imageUrl,
        fallbackIcon: Icons.hotel,
        semanticLabel: data.title,
        fit: BoxFit.cover,
      ),
      title: data.title,
      rating: data.rating,
      reviewCount: data.reviewCount,
      amountText: money,
      currency: data.currency,
      unit: unit,
      onTap: onTap,
      onFavorite: onFavorite,
      isFavorite: isFavorite,
      enabled: enabled,
      heartSize: heartSize,
      margin: _margin,
      semanticsLabel: AppLocalizations.of(context) == null
          ? data.title
          : _semantics(context, data, money, unit),
    );
  }

  static const EdgeInsetsGeometry _margin = EdgeInsetsDirectional.fromSTEB(
    AppSpacing.lg,
    0,
    AppSpacing.lg,
    AppSpacing.md,
  );

  String _semantics(
    BuildContext context,
    HotelOffer data,
    String money,
    String? unit,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return <String>[
      data.title,
      if (data.city.isNotEmpty) data.city,
      if (data.rating != null)
        l10n.hotelRatingSemantics(
          data.rating!.toStringAsFixed(1),
          data.reviewCount ?? 0,
        ),
      if (unit != null)
        l10n.cardPerUnitSemantics(unit, money, data.currency)
      else
        '$money ${data.currency}',
    ].join(', ');
  }
}
