import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tokigo/core/domain/models/offers/travel_package_offer.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/cards/card.dart';

/// Package search card for search results.
///
/// Horizontal layout with image (~55-60% width) on the left, content on the right.
/// Uses BaseCard for pressed/disabled/loading states and accessibility.
/// Composes shared Card Design System primitives: CardImage, CardLocation, CardFeatureList,
/// CardPriceBlock.
/// NO: guest rating, reviews, travel dates, tax/fee info, total price, CTA button.
/// Entire card is tappable → Package Details (booking review flow).
class PackageSearchCard extends StatelessWidget {
  const PackageSearchCard({
    super.key,
    this.offer,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    this.enabled = true,
    this.loading = false,
  });

  /// Skeleton constructor — renders the card's loading state with no data.
  const PackageSearchCard.loading({super.key})
      : offer = null,
        onTap = null,
        onFavorite = null,
        isFavorite = false,
        enabled = false,
        loading = true;

  /// The package data. Null only in the skeleton/loading state.
  final TravelPackageOffer? offer;

  /// Non-null offer accessor — valid everywhere except the skeleton state,
  /// which never reads offer data.
  TravelPackageOffer get data => offer!;
  final VoidCallback? onTap;

  /// Favorite toggle callback; null hides the favorite affordance.
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final bool enabled;
  final bool loading;

  List<String> get _cities {
    return data.destination
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String _formatDuration(int days) {
    if (days <= 0) return '';
    if (days == 1) return '1 day';
    if (days < 7) return '$days days';
    if (days == 7) return '1 week';
    if (days < 14) return '1 week ${days - 7} days';
    final weeks = days ~/ 7;
    final remaining = days % 7;
    if (remaining == 0) return '$weeks weeks';
    return '$weeks weeks $remaining days';
  }

  List<String> get _displayInclusions {
    return data.inclusions.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (loading) {
      return BaseCard(
        onTap: null,
        enabled: false,
        loading: true,
        semanticsLabel: 'Loading package',
        margin: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: cardLoadingSemantics(const _LoadingSkeleton()),
      );
    }

    final duration = _formatDuration(data.durationDays);
    final citiesLine = _cities.join(' · ');

    final semanticParts = <String>[
      data.title,
      'Package to $citiesLine',
      if (duration.isNotEmpty) 'Duration $duration',
      if (_displayInclusions.isNotEmpty) 'Includes ${_displayInclusions.join(', ')}',
      if (isFavorite) 'Saved',
      'Price ${NumberFormat.currency(symbol: '', locale: 'en_US').format(data.price)} ${data.currency} / person',
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
          // Image section - approximately 55-60% width
          Expanded(
            flex: 6,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CardImage(
                url: data.imageUrl,
                fallbackIcon: Icons.card_travel,
                semanticLabel: data.title,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Content section - approximately 40-45% width
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Package name + favorite
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
                      if (onFavorite != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        CardFavorite(
                          value: isFavorite,
                          onChanged: onFavorite,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Cities/Destinations via shared location primitive
                  if (citiesLine.isNotEmpty)
                    CardLocation(text: citiesLine, maxLines: 2),
                  const SizedBox(height: AppSpacing.xs),
                  // Duration — package-specific emphasis chip
                  if (duration.isNotEmpty)
                    CardBadge(
                      label: duration,
                      icon: Icons.calendar_today_outlined,
                      variant: CardBadgeVariant.tinted,
                    ),
                  const Spacer(),
                  // Inclusions (up to 3)
                  if (_displayInclusions.isNotEmpty) ...[
                    CardFeatureList(
                      features: _displayInclusions,
                      direction: Axis.horizontal,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  // Price per person anchored consistently at the bottom-end
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: CardPriceBlock(
                      currentPrice: data.price,
                      currency: data.currency,
                      showCurrency: true,
                      unit: 'person',
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
/// Skeleton for [PackageSearchCard] — mirrors the real card's geometry
/// (image column + content column) with no fake data.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image section — same ~60% flex as the real card
        Expanded(
          flex: 6,
            child: AspectRatio(aspectRatio: 4 / 3, child: CardSkeleton.image()),
        ),
        // Content section — same ~40% flex
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Package name
                CardSkeleton.title(height: 16),
                CardSkeleton.gap(height: AppSpacing.xs),
                // Cities/destinations
                CardSkeleton.text(width: 110),
                CardSkeleton.gap(height: AppSpacing.xs),
                // Duration
                CardSkeleton.chip(width: 72),
                const SizedBox(height: AppSpacing.md),
                // Inclusions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CardSkeleton.chip(width: 72),
                    CardSkeleton.gap(height: AppSpacing.xs),
                    CardSkeleton.chip(width: 64),
                  ],
                ),
                CardSkeleton.gap(height: AppSpacing.sm),
                // Price per person anchored bottom-end (matches real card)
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
