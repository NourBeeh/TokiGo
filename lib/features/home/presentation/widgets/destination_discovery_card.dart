import 'package:flutter/material.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/cards/card.dart';

/// Destination discovery card for Home discovery surfaces.
///
/// The photo is the whole visual; the city's name sits underneath it on the
/// leading edge. There is no price, rating, duration, CTA or favourite — the
/// tile itself opens the city's information page.
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

  /// Kept for callers that still offer saving a destination; the card remains
  /// image-first and does not draw a heart over the photo.
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;

  /// Skeleton state — renders the same image-first geometry with no data.
  final bool loading;

  /// How many real stays the provider has in this city (when it said).
  int? get staysCount {
    final Object? count = item.metadata['staysCount'];
    return count is num ? count.toInt() : null;
  }

  @override
  Widget build(BuildContext context) {
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

    return BaseCard(
      onTap: onTap,
      enabled: onTap != null,
      semanticsLabel: item.title,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      showShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl),
                  ),
                  child: CardImage(
                    url: item.imageUrl,
                    fallbackIcon: Icons.photo_camera_outlined,
                    semanticLabel: item.title,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.xl),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        stops: const <double>[0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: AppSpacing.md,
                  end: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.forLight().titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          shadows: <Shadow>[
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      if (staysCount != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '$staysCount stays',
                            style: AppTypography.forLight().caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AspectRatio(aspectRatio: 4 / 3, child: CardSkeleton.image()),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: CardSkeleton.title(width: 140, height: 20),
          ),
        ),
      ],
    );
  }
}
