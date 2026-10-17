import 'package:flutter/material.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/core/widgets/cards/card_scrim_overlay.dart';

/// Deal discovery card — image-first, full-bleed.
///
/// The photo is the entire card; a shared bottom scrim overlay (never an
/// inline gradient) carries the deal content:
/// - discount badge (top-start corner, over the photo)
/// - title
/// - optional destination/subtitle
/// - savings/discount + validity (via [DealPresentation] semantics, kept visual)
/// - price
///
/// The card sizes itself from its parent constraints (Home layout decides the
/// target ~280×220); no hardcoded dimensions inside.
///
/// No strikethrough original price, no countdown, no CTA — the whole card is
/// tappable via [onTap].
class DealCard extends StatelessWidget {
  const DealCard({
    super.key,
    required this.item,
    this.onTap,
    this.loading = false,
  });

  final HomeItem item;
  final VoidCallback? onTap;

  /// Skeleton state — renders the same full-bleed geometry with no data.
  final bool loading;

  double? _parsePrice(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _getSavingsPercent() {
    final raw = item.metadata['savingsPercent'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return BaseCard(
        onTap: null,
        enabled: false,
        loading: true,
        semanticsLabel: 'Loading deal',
        padding: EdgeInsets.zero,
        child: const _LoadingSkeleton(),
      );
    }

    final savingsPercent = _getSavingsPercent();
    final price = item.price;

    final semanticParts = <String>[
      'Deal',
      item.title,
      if (item.subtitle != null && item.subtitle!.isNotEmpty) item.subtitle!,
      if (savingsPercent != null && savingsPercent > 0) 'Save $savingsPercent%',
      if (price != null) 'Price ${price.toStringAsFixed(0)} ${item.currency ?? ''}',
    ];
    final semanticLabel = semanticParts.join(', ');

    return BaseCard(
      onTap: onTap,
      semanticsLabel: semanticLabel,
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 280 / 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full-bleed image
            CardImage(
              url: item.imageUrl,
              fallbackIcon: Icons.local_offer,
              semanticLabel: item.title,
              fit: BoxFit.cover,
            ),
            // Discount badge — top-start corner
            if (savingsPercent != null && savingsPercent > 0)
              PositionedDirectional(
                top: AppSpacing.sm,
                start: AppSpacing.sm,
                child: CardBadge(
                  label: '$savingsPercent% OFF',
                  icon: Icons.local_offer,
                  variant: CardBadgeVariant.tinted,
                  type: BadgeType.discount,
                ),
              ),
            // Bottom scrim with deal content (shared overlay primitive)
            CardScrimFooter(
              strength: CardScrimStrength.strong,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: CardScrimColors.onScrim,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  // Destination/subtitle
                  if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      item.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: CardScrimColors.onScrimVariant,
                          ),
                    ),
                  ],
                  // Price row + savings
                  if (price != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        CardPrice(
                          price: price,
                          currency: item.currency,
                          color: CardScrimColors.onScrim,
                        ),
                        if (savingsPercent != null && savingsPercent > 0) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Save $savingsPercent%',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: CardScrimColors.onScrimVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for [DealCard] — same full-bleed geometry, no fake prices,
/// titles or discounts.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 280 / 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CardSkeleton.image(),
          // Badge skeleton — top-start corner
          PositionedDirectional(
            top: AppSpacing.sm,
            start: AppSpacing.sm,
            child: CardSkeleton.chip(width: 72),
          ),
          // Bottom scrim skeleton
          CardScrimFooter(
            strength: CardScrimStrength.strong,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CardSkeleton.title(width: 150, height: 18),
                const SizedBox(height: AppSpacing.xxs),
                CardSkeleton.text(width: 100),
                const SizedBox(height: AppSpacing.xxs),
                CardSkeleton.price(width: 90, height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
