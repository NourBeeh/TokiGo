import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/cards/card.dart';

/// Hotel search card for search results and comparison.
///
/// Horizontal layout with image (~50% width) on the left, content on the right.
/// Uses BaseCard for pressed/disabled/loading states and accessibility.
/// Composes shared Card Design System primitives: CardImage, CardRating, CardLocation,
/// CardFeatureList, CardCancellation, CardPriceBlock, CardFavorite.
/// NO CTA button - entire card is tappable → Hotel Details (booking review flow).
class HotelSearchCard extends StatelessWidget {
  const HotelSearchCard({
    super.key,
    this.offer,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    this.enabled = true,
    this.loading = false,
  });

  /// Skeleton constructor — renders the card's loading state with no data.
  const HotelSearchCard.loading({super.key})
      : offer = null,
        onTap = null,
        onFavorite = null,
        isFavorite = false,
        enabled = false,
        loading = true;

  /// The hotel data. Null only in the skeleton/loading state.
  final HotelOffer? offer;

  /// Non-null offer accessor — valid everywhere except the skeleton state,
  /// which never reads offer data.
  HotelOffer get data => offer!;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final bool enabled;
  final bool loading;

  int get _nights => data.checkOut.difference(data.checkIn).inDays;

  double? get _pricePerNight {
    final metadata = data.metadata;
    final ppn = metadata['pricePerNight'];
    if (ppn is num) return ppn.toDouble();
    return null;
  }

  double? get _totalPrice {
    final metadata = data.metadata;
    final total = metadata['totalPrice'];
    if (total is num) return total.toDouble();
    final pricePerNight = metadata['pricePerNight'];
    if (pricePerNight is num && _nights > 0) {
      return pricePerNight.toDouble() * _nights;
    }
    return null;
  }

  bool get _hasFreeCancellation {
    final metadata = data.metadata;
    final fc = metadata['freeCancellation'];
    return fc == true;
  }

  String? get _cancellationLabel {
    final metadata = data.metadata;
    return metadata['cancellationPolicy']?.toString();
  }

  List<String> get _displayFeatures {
    final features = <String>[];
    if (data.roomType.isNotEmpty) features.add(data.roomType);
    if (data.amenities.isNotEmpty) {
      features.addAll(data.amenities.take(2));
    }
    return features.take(3).toList();
  }

  double? get _taxesFees {
    final metadata = data.metadata;
    final tf = metadata['taxesAndFees'];
    if (tf is num) return tf.toDouble();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return BaseCard(
        onTap: null,
        enabled: false,
        loading: true,
        semanticsLabel: 'Loading hotel',
        margin: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: cardLoadingSemantics(const _LoadingSkeleton()),
      );
    }

    final pricePerNight = _pricePerNight;
    final totalPrice = _totalPrice;
    final hasPricePerNight = pricePerNight != null && pricePerNight > 0;
    final hasTotalPrice = totalPrice != null && totalPrice > 0;

    // Determine primary price display: per-night if available, else total if available, else base price
    final double primaryPrice;
    final String? unit;
    if (hasPricePerNight) {
      primaryPrice = pricePerNight;
      unit = 'night';
    } else if (hasTotalPrice && _nights > 0) {
      primaryPrice = totalPrice / _nights;
      unit = 'night';
    } else {
      primaryPrice = data.price;
      unit = 'night';
    }

    final semanticParts = <String>[
      data.title,
      '${data.city}, ${data.country}',
      if (data.rating != null) '${data.rating!.toStringAsFixed(1)} stars, ${data.reviewCount} reviews',
      'Per $unit ${NumberFormat.currency(symbol: '', locale: 'en_US').format(primaryPrice)} ${data.currency}',
      if (hasTotalPrice) 'Total ${NumberFormat.currency(symbol: '', locale: 'en_US').format(totalPrice)} ${data.currency}',
      if (_hasFreeCancellation) 'Free cancellation',
    ];
    final semanticLabel = semanticParts.join(', ');

    return BaseCard(
      onTap: onTap,
      enabled: enabled,
      semanticsLabel: semanticLabel,
      margin: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image section - approximately 50% width
          Expanded(
            flex: 5,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CardImage(
                url: data.imageUrl,
                fallbackIcon: Icons.hotel,
                semanticLabel: data.title,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Content section - approximately 50% width
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title + Wishlist
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          data.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      CardFavorite(
                        value: isFavorite,
                        onChanged: onFavorite,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Rating + review count
                  if (data.rating != null)
                    CardRating(
                      rating: data.rating,
                      reviewCount: data.reviewCount,
                      onImage: false,
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  // Location
                  CardLocation(text: '${data.city}, ${data.country}'),
                  const Spacer(),
                  // Features (room type + up to 2 amenities)
                  if (_displayFeatures.isNotEmpty) ...[
                    CardFeatureList(
                      features: _displayFeatures,
                      direction: Axis.horizontal,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  // Cancellation (only when free cancellation is available)
                  if (_hasFreeCancellation) ...[
                    CardCancellation(
                      label: _cancellationLabel ?? 'Free cancellation',
                      freeCancellation: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  // Price anchored consistently at the bottom-end
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: CardPriceBlock(
                      currentPrice: primaryPrice,
                      currency: data.currency,
                      showCurrency: true,
                      unit: unit,
                      // Show total as secondary line only when different from
                      // calculated per-night * nights
                      total: (hasTotalPrice && hasPricePerNight && totalPrice != pricePerNight * _nights)
                          ? totalPrice
                          : null,
                      // Taxes/fees only when explicitly provided
                      taxesExcluded: _taxesFees != null && _taxesFees! > 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
/// Skeleton for [HotelSearchCard] — mirrors the real card's geometry
/// (image column + content column with anchored bottom price) with no fake data.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image section — same ~50% flex as the real card
        Expanded(
          flex: 5,
          child: AspectRatio(aspectRatio: 4 / 3, child: CardSkeleton.image()),
        ),
        // Content section — same ~50% flex
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title + favorite row
                Row(
                  children: [
                    Expanded(child: CardSkeleton.title(height: 16)),
                    CardSkeleton.hGap(width: AppSpacing.sm),
                    CardSkeleton.text(width: 24, height: 24),
                  ],
                ),
                CardSkeleton.gap(height: AppSpacing.xs),
                // Rating
                CardSkeleton.text(width: 72),
                CardSkeleton.gap(height: AppSpacing.xs),
                // Location
                CardSkeleton.text(width: 120),
                const SizedBox(height: AppSpacing.md),
                // Features
                Row(
                  children: [
                    CardSkeleton.chip(width: 64),
                    CardSkeleton.hGap(width: AppSpacing.xs),
                    CardSkeleton.chip(width: 72),
                  ],
                ),
                CardSkeleton.gap(height: AppSpacing.sm),
                // Price anchored bottom-end (matches real card)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: CardSkeleton.price(width: 100),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
