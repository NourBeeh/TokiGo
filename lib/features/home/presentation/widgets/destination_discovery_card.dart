import 'package:flutter/material.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/widgets/cards/card.dart';

/// Destination discovery card for Home discovery carousels.
///
/// Vertical, image-first card. Image is the dominant visual element; a shared
/// bottom scrim overlay (never an inline gradient) carries the destination
/// name and country.
///
/// The card sizes itself from its parent constraints (carousel/grid decides
/// the target size); no hardcoded dimensions inside.
///
/// NO price, rating, duration, CTA or favorite — tap is handled by the parent.
class DestinationDiscoveryCard extends StatelessWidget {
  const DestinationDiscoveryCard({
    super.key,
    required this.item,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    this.loading = false,
  });

  final HomeItem item;
  final VoidCallback? onTap;

  /// Saving a destination is optional: the heart renders only when a caller
  /// can actually persist the choice — never as decoration.
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;

  /// Card D's heart diameter (card A uses 32, the hero 32).
  static const double heartSize = 28;

  /// Skeleton state — renders the same image-first geometry with no data.
  final bool loading;

  /// How many real stays the provider has in this city (when it said).
  int? get staysCount {
    final Object? count = item.metadata['staysCount'];
    return count is num ? count.toInt() : null;
  }

  String? _getCountry() {
    final country = item.metadata['country']?.toString();
    if (country != null && country.isNotEmpty) return country;
    final region = item.metadata['region']?.toString();
    if (region != null && region.isNotEmpty) return region;
    if (item.subtitle != null && item.subtitle!.isNotEmpty) {
      return item.subtitle;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // A local, so the null check promotes it inside the footer.
    final int? count = staysCount;
    if (loading) {
      return BaseCard(
        onTap: null,
        enabled: false,
        loading: true,
        semanticsLabel: 'Loading destination',
        padding: EdgeInsets.zero,
        child: const _LoadingSkeleton(),
      );
    }

    final country = _getCountry();

    final semanticParts = <String>['Destination', item.title, ?country];
    final semanticLabel = semanticParts.join(', ');

    return BaseCard(
      onTap: onTap,
      semanticsLabel: semanticLabel,
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 280 / 240,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full-bleed image - dominant element
            CardImage(
              url: item.imageUrl,
              fallbackIcon: Icons.photo_camera_outlined,
              semanticLabel: item.title,
              fit: BoxFit.cover,
            ),
            // Save affordance — only when the caller can persist it.
            if (onFavorite != null)
              PositionedDirectional(
                top: 8,
                end: 8,
                child: CardFavorite(
                  value: isFavorite,
                  onChanged: onFavorite,
                  size: heartSize,
                  onImage: true,
                ),
              ),
            // Bottom scrim overlay with content (shared overlay primitive)
            CardScrimFooter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Destination name — two lines, because a city like
                  // "Sharm El Sheikh" does not fit on one in a narrow tile.
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: CardScrimColors.onScrim,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // Country + how many real stays the provider has there.
                  if (country != null || count != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: CardScrimColors.onScrimVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              ?country,
                              if (count != null)
                                AppLocalizations.of(
                                      context,
                                    )?.cityStaysCount(count) ??
                                    '$count stays',
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: CardScrimColors.onScrimVariant,
                                ),
                          ),
                        ),
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

/// Skeleton for [DestinationDiscoveryCard] — same image-first geometry,
/// no fake destination names or countries.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 280 / 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CardSkeleton.image(),
          CardScrimFooter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CardSkeleton.title(width: 140, height: 20),
                const SizedBox(height: 4),
                CardSkeleton.text(width: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
