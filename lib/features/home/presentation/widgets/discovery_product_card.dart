import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_elevation.dart';

/// Real discovery product card for hotels / cars / packages in the Home
/// feed (Wave 2): image-first vertical card with rating, highlights chips
/// and price — one design replacing the previous skeleton-only preview.
///
/// Loading mirrors the exact geometry via [DiscoveryProductCard.loading].
class DiscoveryProductCard extends StatelessWidget {
  const DiscoveryProductCard({
    super.key,
    required this.item,
    this.onTap,
  }) : _loading = false;

  const DiscoveryProductCard.loading({super.key})
      : item = const HomeItem(
          id: '',
          type: HomeCardType.hotel,
          title: '',
        ),
        onTap = null,
        _loading = true;

  final HomeItem item;
  final VoidCallback? onTap;
  final bool _loading;

  static const double kWidth = 220;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return BaseCard(
        onTap: null,
        enabled: false,
        loading: true,
        semanticsLabel: 'Loading',
        padding: EdgeInsets.zero,
        child: cardLoadingSemantics(
          LayoutBuilder(
            builder: (context, constraints) {
              final bounded = constraints.hasBoundedHeight &&
                  constraints.maxHeight.isFinite;
              final image = bounded
                  ? Expanded(child: CardSkeleton.image())
                  : AspectRatio(
                      aspectRatio: 16 / 10, child: CardSkeleton.image());
              return Column(
                mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  image,
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        CardSkeleton.title(width: 130),
                        CardSkeleton.gap(height: AppSpacing.xs),
                        CardSkeleton.text(width: 90),
                        CardSkeleton.gap(height: AppSpacing.sm),
                        CardSkeleton.price(width: 72),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    final typography = AppTypography.forLight();
    final rating = item.rating;

    return BaseCard(
      onTap: onTap,
      semanticsLabel:
          '${item.type.name} ${item.title}${item.price != null ? ', price ${item.currency ?? ''} ${item.price}' : ''}',
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.hasBoundedHeight &&
              constraints.maxHeight.isFinite;
          final image = bounded
              ? Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      CardImage(url: item.imageUrl),
                      if (item.badge?.isNotEmpty ?? false)
                        PositionedDirectional(
                          top: AppSpacing.sm,
                          start: AppSpacing.sm,
                          child: CardBadge(label: item.badge!),
                        ),
                    ],
                  ),
                )
              : AspectRatio(
                  aspectRatio: 16 / 10,
                  child: CardImage(url: item.imageUrl),
                );

          return Column(
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              image,
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.bodyLargeMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (rating != null) ...<Widget>[
                          const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            rating.toStringAsFixed(1),
                            style: typography.captionSemibold.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.subtitle?.isNotEmpty ?? false) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        if (item.highlights.isNotEmpty) ...<Widget>[
                          Expanded(
                            child: Text(
                              item.highlights.take(2).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),
                        if (item.price != null) ...<Widget>[
                          CardPrice(
                            price: item.price!,
                            currency: item.currency,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
