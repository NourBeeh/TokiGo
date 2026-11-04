import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/cards/card.dart';

/// Discovery product card for cars and packages in the Home feed.
///
/// A product image leads, followed by a quiet information panel for the name,
/// supporting detail, rating and price.
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
  static const double kHeight = 276;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return BaseCard(
        onTap: null,
        enabled: false,
        loading: true,
        showBorder: true,
        borderColor: TravelCardStyle.borderColor(context),
        showShadow: false,
        semanticsLabel: 'Loading',
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: cardLoadingSemantics(
          LayoutBuilder(
            builder: (context, constraints) {
              final bounded =
                  constraints.hasBoundedHeight &&
                  constraints.maxHeight.isFinite;
              final Widget skeleton = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(flex: 5, child: CardSkeleton.image()),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          CardSkeleton.title(width: 144, height: 18),
                          CardSkeleton.gap(height: AppSpacing.xs),
                          CardSkeleton.text(width: 98, height: 14),
                          const Spacer(),
                          Row(
                            children: <Widget>[
                              CardSkeleton.chip(width: 54),
                              const Spacer(),
                              CardSkeleton.price(width: 78, height: 22),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
              return bounded
                  ? skeleton
                  : SizedBox(
                      height: kHeight,
                      child: skeleton,
                    );
            },
          ),
        ),
      );
    }

    final typography = AppTypography.forLight();
    final rating = item.rating;
    final price = item.price;
    final currency = item.currency;

    return BaseCard(
      onTap: onTap,
      showBorder: true,
      borderColor: TravelCardStyle.borderColor(context),
      showShadow: false,
      semanticsLabel:
          '${item.type.name} ${item.title}${price != null ? ', price ${currency ?? ''} $price' : ''}',
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
          final String supportingText =
              item.subtitle?.trim().isNotEmpty == true
              ? item.subtitle!.trim()
              : item.highlights.take(2).join(' · ');
          final Widget product = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CardImage(
                      url: item.imageUrl,
                      fallbackIcon: Icons.travel_explore_rounded,
                      semanticLabel: item.title,
                      fit: BoxFit.cover,
                    ),
                    if (item.badge?.isNotEmpty ?? false)
                      PositionedDirectional(
                        top: AppSpacing.sm,
                        start: AppSpacing.sm,
                        child: CardBadge(
                          label: item.badge!,
                          variant: CardBadgeVariant.glass,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: typography.bodyLargeMedium.copyWith(
                              color: context.tokigoColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          if (supportingText.isNotEmpty) ...<Widget>[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              supportingText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typography.caption.copyWith(
                                color: context.tokigoColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: <Widget>[
                          if (rating != null) ...<Widget>[
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: context.tokigoColors.starFill,
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              rating.toStringAsFixed(1),
                              style: typography.captionSemibold.copyWith(
                                color: context.tokigoColors.textSecondary,
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (price != null)
                            _ProductPrice(
                              price: price,
                              currency: currency,
                              typography: typography,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
          return bounded
              ? product
              : SizedBox(height: kHeight, child: product);
        },
      ),
    );
  }
}

class _ProductPrice extends StatelessWidget {
  const _ProductPrice({
    required this.price,
    required this.currency,
    required this.typography,
  });

  final double price;
  final String? currency;
  final AppTypography typography;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          price.toStringAsFixed(0),
          maxLines: 1,
          style: typography.titleMedium.copyWith(
            color: context.tokigoColors.textPrimary,
            fontWeight: FontWeight.w800,
            height: 1.05,
            letterSpacing: -0.3,
          ),
        ),
        if ((currency ?? '').isNotEmpty) ...<Widget>[
          const SizedBox(width: AppSpacing.xs),
          Text(
            currency!,
            maxLines: 1,
            style: typography.caption.copyWith(
              color: context.tokigoColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
