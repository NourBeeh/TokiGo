import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_overlap.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/cards/base_card.dart';
import 'package:tokigo/core/widgets/cards/card_favorite.dart';
import 'package:tokigo/core/widgets/cards/card_overlap.dart';
import 'package:tokigo/core/widgets/cards/card_skeleton.dart';

/// Card A's visual, model-free: a 4:3 photo with a white sheet riding 48px up
/// over it, carrying name, rating line and an end-aligned price.
///
/// Two callers share this one shape — the hotel results page
/// (`HotelOverlapCard`, from an offer) and the Home recommendation list (from a
/// `HomeItem`). Keeping the drawing here means the user meets the same card in
/// both places, which is the point of the archetype.
///
/// The photo is supplied by the caller so each surface keeps its own image
/// pipeline (Home reads the Hive-backed hotel cache; results use `CardImage`).
class OverlapStayCard extends StatelessWidget {
  const OverlapStayCard({
    super.key,
    required this.media,
    required this.title,
    required this.amountText,
    this.currency = '',
    this.unit,
    this.starClass,
    this.rating,
    this.reviewCount,
    this.location,
    this.onLocationTap,
    this.distanceText,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    this.enabled = true,
    this.semanticsLabel,
    this.margin,
    this.aspectRatio = 4 / 3,
    this.heartSize = 32,
  });

  /// The photo alone — the heart is drawn by this card on top of it.
  final Widget media;

  final String title;

  /// Already-formatted amount ("120", "1 250"). Formatting stays with the
  /// caller because each surface has its own rounding rules.
  final String amountText;
  final String currency;

  /// "/ night" when the amount really is a nightly rate. Null hides it.
  final String? unit;

  /// The hotel's own class (1–5), drawn as an outlined star. Distinct from
  /// [rating], which is the guest review score (filled star).
  final int? starClass;

  final double? rating;
  final int? reviewCount;

  /// The stay's location line ("Cairo, EG"). When [onLocationTap] is set the
  /// line is a real control that opens the place in the platform's maps.
  final String? location;
  final VoidCallback? onLocationTap;

  /// An honest distance line ("1.2 km from the center") — null hides it.
  final String? distanceText;

  final VoidCallback? onTap;
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final bool enabled;

  final String? semanticsLabel;

  /// Outer margin. Defaults to the page gutter (16) with the 12 card gap.
  final EdgeInsetsGeometry? margin;

  final double aspectRatio;
  final double heartSize;

  /// Skeleton at the identical geometry — the list must not jump when the
  /// real data lands.
  const OverlapStayCard.skeleton({
    super.key,
    this.margin,
    this.semanticsLabel = 'Loading',
    this.aspectRatio = 4 / 3,
  }) : media = const SizedBox.shrink(),
       title = '',
       amountText = '',
       currency = '',
       unit = null,
       starClass = null,
       rating = null,
       reviewCount = null,
       location = null,
       onLocationTap = null,
       distanceText = null,
       onTap = null,
       onFavorite = null,
       isFavorite = false,
       enabled = false,
       heartSize = 32;

  bool get _isSkeleton => title.isEmpty && amountText.isEmpty;

  @override
  Widget build(BuildContext context) {
    final EdgeInsetsGeometry margin =
        this.margin ??
        const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        );

    if (_isSkeleton) {
      return BaseCard(
        onTap: null,
        enabled: false,
        loading: true,
        showBorder: false,
        showShadow: false,
        padding: EdgeInsets.zero,
        margin: margin,
        semanticsLabel: semanticsLabel,
        child: cardLoadingSemantics(
          _SkeletonBody(aspectRatio: aspectRatio),
          label: semanticsLabel,
        ),
      );
    }

    return BaseCard(
      onTap: onTap,
      enabled: enabled,
      showBorder: false,
      showShadow: false,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      margin: margin,
      semanticsLabel: semanticsLabel ?? _autoSemantics,
      child: CardOverlap(
        mediaAspectRatio: aspectRatio,
        overlap: AppOverlap.card,
        radius: AppRadius.lg,
        sheetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        media: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            media,
            if (onFavorite != null)
              PositionedDirectional(
                top: AppSpacing.md,
                end: AppSpacing.md,
                child: CardFavorite(
                  value: isFavorite,
                  onChanged: onFavorite,
                  size: heartSize,
                  onImage: true,
                ),
              ),
          ],
        ),
        sheet: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.forLight().bodyLargeMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            if (starClass != null || rating != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              _RatingLine(
                starClass: starClass,
                rating: rating,
                reviewCount: reviewCount,
              ),
            ],
            if (location case final String place) ...<Widget>[
              const SizedBox(height: AppSpacing.xxs),
              _LocationLine(text: place, onTap: onLocationTap),
            ],
            if (distanceText case final String distance) ...<Widget>[
              const SizedBox(height: AppSpacing.xxs),
              _DistanceLine(text: distance),
            ],
            if (amountText.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _PriceLine(
                  amountText: amountText,
                  currency: currency,
                  unit: unit,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _autoSemantics {
    final List<String> parts = <String>[title];
    if (starClass != null) parts.add('$starClass-star hotel');
    if (rating != null) parts.add(rating!.toStringAsFixed(1));
    if (reviewCount != null) parts.add('($reviewCount)');
    if (location case final String place) parts.add(place);
    if (distanceText case final String distance) parts.add(distance);
    parts.add('$amountText $currency${unit == null ? '' : ' / $unit'}');
    return parts.join(', ');
  }
}

class _RatingLine extends StatelessWidget {
  const _RatingLine({
    required this.starClass,
    required this.rating,
    this.reviewCount,
  });

  final int? starClass;
  final double? rating;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final int? stars = starClass;
    final double? score = rating;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (stars != null) ...<Widget>[
          const Icon(
            Icons.star_outline_rounded,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            '$stars',
            style: typography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (stars != null && score != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          Text(
            '·',
            style: typography.caption.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (score != null) ...<Widget>[
          const Icon(Icons.star_rounded, size: 14, color: AppColors.starFill),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            score.toStringAsFixed(1),
            style: typography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (reviewCount != null) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            Text(
              '($reviewCount)',
              style: typography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _LocationLine extends StatelessWidget {
  const _LocationLine({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.place_outlined,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.caption.copyWith(
                color: AppColors.textSecondary,
                decoration: onTap == null ? null : TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      ),
    );
  }
}

class _DistanceLine extends StatelessWidget {
  const _DistanceLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(
          Icons.near_me_outlined,
          size: 14,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.forLight().caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.amountText,
    required this.currency,
    this.unit,
  });

  final String amountText;
  final String currency;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final String? unit = this.unit;
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: amountText,
            style: typography.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (currency.isNotEmpty)
            TextSpan(
              text: ' $currency',
              style: typography.label.copyWith(color: AppColors.textSecondary),
            ),
          if (unit != null)
            TextSpan(
              text: ' / $unit',
              style: typography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
    );
  }
}

/// Skeleton body — the same [CardOverlap] geometry as the real card.
class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody({required this.aspectRatio});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return CardOverlap(
      mediaAspectRatio: aspectRatio,
      overlap: AppOverlap.card,
      radius: AppRadius.lg,
      sheetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      media: KeyedSubtree(
        key: const Key('overlap-skeleton-media'),
        child: CardSkeleton.image(),
      ),
      sheet: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CardSkeleton.title(width: 170, height: 20),
          CardSkeleton.gap(height: AppSpacing.xs),
          CardSkeleton.text(width: 96, height: 19),
          CardSkeleton.gap(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: CardSkeleton.price(width: 88),
          ),
        ],
      ),
    );
  }
}
