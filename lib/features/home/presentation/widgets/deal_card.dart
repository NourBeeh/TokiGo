import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Deal discovery card.
///
/// A compact offer-first tile: discount, destination and price are easy to scan
/// beside a square travel photograph.
class DealCard extends StatelessWidget {
  const DealCard({
    super.key,
    required this.item,
    this.onTap,
    this.loading = false,
  });

  final HomeItem item;
  final VoidCallback? onTap;

  /// Skeleton state — retains the offer-and-photo geometry without fake data.
  final bool loading;

  static const double _aspectRatio = 280 / 220;

  int? _getSavingsPercent() {
    final raw = item.metadata['savingsPercent'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  /// The one shell both the loaded card and its skeleton share: corner radius,
  /// hairline, padding and press behaviour live here and nowhere else, so a
  /// skeleton cannot drift from the real card's chrome.
  Widget _shell(
    BuildContext context, {
    required Widget child,
    required String semanticsLabel,
    VoidCallback? onTap,
    bool enabled = true,
    bool loading = false,
  }) {
    return BaseCard(
      onTap: onTap,
      enabled: enabled,
      loading: loading,
      showBorder: true,
      borderColor: TravelCardStyle.borderColor(context),
      showShadow: false,
      semanticsLabel: semanticsLabel,
      padding: EdgeInsets.zero,
      borderRadius: HomeCardDimensions.borderRadius,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _shell(
        context,
        loading: true,
        semanticsLabel: 'Loading deal',
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
      if (price != null)
        'Price ${price.toStringAsFixed(0)} ${item.currency ?? ''}',
    ];

    return _shell(
      context,
      onTap: onTap,
      semanticsLabel: semanticParts.join(', '),
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (savingsPercent != null &&
                          savingsPercent > 0) ...<Widget>[
                        Text(
                          AppLocalizations.of(
                                context,
                              )?.dealDiscountLabel(savingsPercent) ??
                              '$savingsPercent% OFF',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.forLight().titleMedium.copyWith(
                            color: context.tokigoColors.brand,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.forLight().bodyLargeMedium
                            .copyWith(
                              color: context.tokigoColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                      ),
                      if (item.subtitle?.isNotEmpty ?? false) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          item.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.forLight().caption.copyWith(
                            color: context.tokigoColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      _DealPrice(price: item.price, currency: item.currency),
                      const SizedBox(height: AppSpacing.xs),
                      TravelActionHint(
                        label:
                            AppLocalizations.of(context)?.navExplore ??
                            'Explore',
                        color: context.tokigoColors.textPrimary,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 112,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CardImage(
                      url: item.imageUrl,
                      fallbackIcon: Icons.local_offer_outlined,
                      semanticLabel: item.title,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DealPrice extends StatelessWidget {
  const _DealPrice({required this.price, required this.currency});

  final double? price;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    if (price == null) return const SizedBox.shrink();
    final typography = AppTypography.forLight();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          price!.toStringAsFixed(0),
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

/// Skeleton for [DealCard], with no fake prices, titles or discounts.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: DealCard._aspectRatio,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CardSkeleton.title(width: 74, height: 20),
                    CardSkeleton.gap(height: AppSpacing.xs),
                    CardSkeleton.title(width: 118, height: 18),
                    CardSkeleton.gap(height: AppSpacing.xs),
                    CardSkeleton.text(width: 90),
                    CardSkeleton.gap(height: AppSpacing.sm),
                    CardSkeleton.price(width: 84, height: 22),
                    CardSkeleton.gap(height: AppSpacing.xs),
                    CardSkeleton.text(width: 56, height: 14),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 112,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: AspectRatio(aspectRatio: 1, child: CardSkeleton.image()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
