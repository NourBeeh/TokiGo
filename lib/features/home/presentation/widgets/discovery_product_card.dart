import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/core/theme/app_colors.dart';

/// Real discovery product card for hotels / cars / packages in the Home
/// feed (Wave 2): image-first vertical card with rating, highlights chips
/// and price — one design replacing the previous skeleton-only preview.
///
/// Loading mirrors the exact geometry via [DiscoveryProductCard.loading].
class DiscoveryProductCard extends StatelessWidget {
  const DiscoveryProductCard({super.key, required this.item, this.onTap})
    : _loading = false;

  const DiscoveryProductCard.loading({super.key})
    : item = const HomeItem(id: '', type: HomeCardType.hotel, title: ''),
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
        showBorder: false,
        semanticsLabel: 'Loading',
        padding: EdgeInsets.zero,
        child: cardLoadingSemantics(
          LayoutBuilder(
            builder: (context, constraints) {
              final bounded =
                  constraints.hasBoundedHeight &&
                  constraints.maxHeight.isFinite;
              // Same overlay geometry as the real card: photo fills the card,
              // skeleton copy sits bottom-start.
              final Widget skeleton = Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CardSkeleton.image(),
                  PositionedDirectional(
                    start: AppSpacing.md,
                    end: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
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
              return bounded
                  ? skeleton
                  : SizedBox(
                      height: HomeCardDimensions.cardHeightForType(item.type),
                      child: skeleton,
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
      showBorder: false,
      semanticsLabel:
          '${item.type.name} ${item.title}${item.price != null ? ', price ${item.currency ?? ''} ${item.price}' : ''}',
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite;

          final Widget media = Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CardImage(url: item.imageUrl),
              // Card E: the copy sits ON the photo, held by a bottom-up scrim.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Colors.transparent, AppColors.photoScrim],
                    stops: <double>[0.35, 1],
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
                    if (item.badge?.isNotEmpty ?? false) ...<Widget>[
                      CardBadge(label: item.badge!),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.bodyLargeMedium.copyWith(
                        color: CardScrimColors.onScrim,
                      ),
                    ),
                    if (item.subtitle?.isNotEmpty ?? false) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.caption.copyWith(
                          color: CardScrimColors.onScrimVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        if (rating != null) ...<Widget>[
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.starFill,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            rating.toStringAsFixed(1),
                            style: typography.caption.copyWith(
                              color: CardScrimColors.onScrimVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        if (item.highlights.isNotEmpty)
                          Expanded(
                            child: Text(
                              item.highlights.take(2).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typography.caption.copyWith(
                                color: CardScrimColors.onScrimVariant,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        if (item.price != null) ...<Widget>[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '${item.currency ?? '\$'}${item.price!.toStringAsFixed(0)}',
                            maxLines: 1,
                            textDirection: TextDirection.ltr,
                            style: typography.bodyLargeMedium.copyWith(
                              color: CardScrimColors.onScrim,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          // An overlay card needs an explicit height when the parent gives it
          // none (the AI thread, vertical lists). Use the Home rail height so
          // the card never grows the section it sits in.
          return bounded
              ? media
              : SizedBox(
                  height: HomeCardDimensions.cardHeightForType(item.type),
                  child: media,
                );
        },
      ),
    );
  }
}
