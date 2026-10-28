import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/cards/card.dart';

/// Car search card for search results.
///
/// Horizontal layout with image (~50-55% width) on the left, content on the right.
/// Uses BaseCard for pressed/disabled/loading states and accessibility.
/// Composes shared Card Design System primitives: CardImage, CardBadge, CardFeatureList,
/// CardCancellation, CardPriceBlock.
/// NO CTA button - entire card is tappable → Car Details (booking review flow).
class CarSearchCard extends StatelessWidget {
  const CarSearchCard({
    super.key,
    this.offer,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    this.enabled = true,
    this.loading = false,
  });

  /// Skeleton constructor — renders the card's loading state with no data.
  const CarSearchCard.loading({super.key})
    : offer = null,
      onTap = null,
      onFavorite = null,
      isFavorite = false,
      enabled = false,
      loading = true;

  /// The car data. Null only in the skeleton/loading state.
  final CarOffer? offer;

  /// Non-null offer accessor — valid everywhere except the skeleton state,
  /// which never reads offer data.
  CarOffer get data => offer!;
  final VoidCallback? onTap;

  /// Favorite toggle callback; null hides the favorite affordance.
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final bool enabled;
  final bool loading;

  int get _rentalDays {
    final diff = data.dropoffTime.difference(data.pickupTime);
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    // Round up if there are remaining hours
    return days > 0 ? (hours > 0 ? days + 1 : days) : 1;
  }

  bool get _hasDiscount {
    final metadata = data.metadata;
    final originalPrice = metadata['originalPrice'];
    if (originalPrice == null) return false;
    final numVal = originalPrice is num
        ? originalPrice.toDouble()
        : double.tryParse(originalPrice.toString());
    return numVal != null && numVal > data.price;
  }

  int? _getDiscountPercent() {
    final metadata = data.metadata;
    final originalPrice = metadata['originalPrice'];
    if (originalPrice == null) return null;
    final numVal = originalPrice is num
        ? originalPrice.toDouble()
        : double.tryParse(originalPrice.toString());
    if (numVal == null || numVal <= data.price) return null;
    final discount = ((numVal - data.price) / numVal * 100).round();
    return discount > 0 ? discount : null;
  }

  bool get _hasOrSimilar {
    final metadata = data.metadata;
    return metadata['orSimilar'] == true;
  }

  String? get _mileagePolicy {
    final metadata = data.metadata;
    final mileage =
        metadata['mileagePolicy']?.toString() ??
        metadata['unlimitedMileage']?.toString();
    if (mileage == null) return null;
    if (mileage.toLowerCase() == 'true' ||
        mileage.toLowerCase() == 'unlimited') {
      return 'Unlimited mileage';
    }
    return mileage;
  }

  bool get _hasFreeCancellation {
    final metadata = data.metadata;
    return metadata['freeCancellation'] == true;
  }

  String? get _cancellationLabel {
    final metadata = data.metadata;
    return metadata['cancellationPolicy']?.toString();
  }

  List<String> _buildFeatures() {
    final features = <String>[];
    if (data.transmission != null && data.transmission!.isNotEmpty) {
      features.add(data.transmission!);
    }
    if (data.seats != null) {
      features.add('${data.seats} seats');
    }
    final luggage = data.metadata['luggage']?.toString();
    if (luggage != null && luggage.isNotEmpty) {
      features.add(luggage);
    }
    return features;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (loading) {
      return BaseCard(
        onTap: null,
        enabled: false,
        loading: true,
        semanticsLabel: 'Loading car',
        margin: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: cardLoadingSemantics(const _LoadingSkeleton()),
      );
    }

    final features = _buildFeatures();
    final discountPercent = _getDiscountPercent();
    final hasDiscount = _hasDiscount;
    final hasOrSimilar = _hasOrSimilar;
    final mileagePolicy = _mileagePolicy;
    final hasFreeCancellation = _hasFreeCancellation;
    final rentalDays = _rentalDays;

    final semanticParts = <String>[
      data.title,
      data.carType,
      if (data.transmission != null) data.transmission!,
      if (data.seats != null) '${data.seats} seats',
      if (features.isNotEmpty) features.join(', '),
      ?mileagePolicy,
      'Pickup: ${data.pickupLocation} at ${_formatTime(data.pickupTime)}',
      'Dropoff: ${data.dropoffLocation} at ${_formatTime(data.dropoffTime)}',
      'Rental: $rentalDays day${rentalDays > 1 ? 's' : ''}',
      if (hasFreeCancellation) 'Free cancellation',
      if (isFavorite) 'Saved',
      'Price ${NumberFormat.currency(symbol: '', locale: 'en_US').format(data.price)} ${data.currency} / day',
    ];
    final semanticLabel = semanticParts.join(', ');

    return BaseCard(
      onTap: onTap,
      enabled: enabled,
      semanticsLabel: semanticLabel,
      margin: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image section - approximately 50-55% width
          Expanded(
            flex: 55,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CardImage(
                url: data.imageUrl,
                fallbackIcon: Icons.directions_car,
                semanticLabel: data.title,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Content section - approximately 45-50% width
          Expanded(
            flex: 45,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Discount badge + favorite row
                  Row(
                    children: [
                      if (hasDiscount && discountPercent != null) ...[
                        CardBadge(
                          label: '$discountPercent% OFF',
                          icon: Icons.local_offer,
                          variant: CardBadgeVariant.tinted,
                          type: BadgeType.discount,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      const Spacer(),
                      if (onFavorite != null)
                        CardFavorite(value: isFavorite, onChanged: onFavorite),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Vehicle model
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Or similar
                  if (hasOrSimilar)
                    Text(
                      'or similar',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  // Vehicle class
                  CardBadge(
                    label: data.carType,
                    variant: CardBadgeVariant.tinted,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Features (transmission, seats, luggage)
                  if (features.isNotEmpty)
                    CardFeatureList(
                      features: features,
                      direction: Axis.horizontal,
                    ),
                  const Spacer(),
                  // Rental duration + mileage
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Flexible(
                        child: Text(
                          '$rentalDays day${rentalDays > 1 ? 's' : ''}'
                          '${mileagePolicy != null ? ' · $mileagePolicy' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  // Free cancellation
                  if (hasFreeCancellation) ...[
                    const SizedBox(height: AppSpacing.xs),
                    CardCancellation(
                      label: _cancellationLabel ?? 'Free cancellation',
                      freeCancellation: true,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  // Price anchored consistently at the bottom-end
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: CardPriceBlock(
                      currentPrice: data.price,
                      currency: data.currency,
                      showCurrency: true,
                      unit: 'day',
                      perDay: data.price,
                      total: rentalDays > 1 ? data.price * rentalDays : null,
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

  String _formatTime(DateTime dateTime) {
    return DateFormat.Hm().format(dateTime);
  }
}

/// Skeleton for [CarSearchCard] — mirrors the real card's geometry
/// (image column + content column with anchored bottom price) with no fake data.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image section — same ~55% flex as the real card
        Expanded(
          flex: 55,
          child: AspectRatio(aspectRatio: 4 / 3, child: CardSkeleton.image()),
        ),
        // Content section — same ~45% flex
        Expanded(
          flex: 45,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge row
                CardSkeleton.chip(width: 72),
                CardSkeleton.gap(height: AppSpacing.xs),
                // Vehicle model
                CardSkeleton.title(height: 16),
                CardSkeleton.gap(height: AppSpacing.xs),
                // Category badge
                CardSkeleton.chip(width: 64),
                CardSkeleton.gap(height: AppSpacing.sm),
                // Features
                Row(
                  children: [
                    CardSkeleton.chip(width: 64),
                    CardSkeleton.hGap(width: AppSpacing.xs),
                    CardSkeleton.chip(width: 56),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Rental duration
                CardSkeleton.text(width: 88),
                CardSkeleton.gap(height: AppSpacing.sm),
                // Price anchored bottom-end (matches real card)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: CardSkeleton.price(width: 96),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
