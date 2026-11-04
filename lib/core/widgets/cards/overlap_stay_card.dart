import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/cards/base_card.dart';
import 'package:tokigo/core/widgets/cards/card_favorite.dart';
import 'package:tokigo/core/widgets/cards/card_glass.dart';
import 'package:tokigo/core/widgets/cards/card_scrim_overlay.dart';
import 'package:tokigo/core/widgets/cards/card_skeleton.dart';
import 'package:tokigo/core/widgets/cards/travel_card_style.dart';

/// A structured hotel card: a cropped hotel photo above a distinct information
/// surface with the name, rating, location and price.
///
/// Two callers share this one shape — the hotel results page
/// (`HotelOverlapCard`, from an offer) and the Home recommendation rail (from a
/// `HomeItem`). Keeping the drawing here means the user meets the same card in
/// both places. The legacy class name remains to avoid changing its callers.
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
    this.heartSize = 40,
  });

  /// The photo alone — the heart and the class pill are drawn by this card on
  /// top of it.
  final Widget media;

  final String title;

  /// Already-formatted amount ("120", "1 250"). Formatting stays with the
  /// caller because each surface has its own rounding rules.
  final String amountText;
  final String currency;

  /// "/ night" when the amount really is a nightly rate. Null hides it.
  final String? unit;

  /// The hotel's own class (1–5), drawn as a glass pill on the photo. Distinct
  /// from [rating], which is the guest review score.
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
        showBorder: true,
        borderColor: TravelCardStyle.borderColor(context),
        showShadow: false,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
      showBorder: true,
      borderColor: TravelCardStyle.borderColor(context),
      showShadow: false,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      margin: margin,
      semanticsLabel: semanticsLabel ?? _autoSemantics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                media,
                const Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0x33000000), Color(0x00000000)],
                          stops: <double>[0, 0.36],
                        ),
                      ),
                    ),
                  ),
                ),
                if (starClass case final int stars)
                  PositionedDirectional(
                    top: AppSpacing.md,
                    start: AppSpacing.md,
                    child: _ClassPill(stars: stars),
                  ),
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
          ),
          Padding(
            padding: TravelCardStyle.sheetPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.forLight().bodyLargeMedium.copyWith(
                    color: context.tokigoColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (rating != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  _RatingLine(rating: rating!),
                ],
                if (location case final String place) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  _LocationLine(text: place, onTap: onLocationTap),
                ],
                if (distanceText case final String distance) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  _DistanceLine(text: distance),
                ],
                if (amountText.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: context.tokigoColors.hairline,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Start-aligned: the nightly price sits on the LEFT in English
                  // (LTR) and on the right in Arabic (RTL), the side the eye
                  // reaches first in each language.
                  Align(
                    alignment: AlignmentDirectional.centerStart,
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
        ],
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

/// The hotel's own class, as a quiet glass pill over the photo. It is a fact
/// (the provider's classification), not a promotional badge.
class _ClassPill extends StatelessWidget {
  const _ClassPill({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    final int safe = stars.clamp(0, 5);
    return CardGlass(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      tint: context.tokigoColors.glassTint,
      borderColor: context.tokigoColors.onMediaBorder,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.star_rounded,
            size: 13,
            color: Colors.amber,
          ),
          if (safe > 0) ...<Widget>[
            const SizedBox(width: AppSpacing.xxs),
            Text(
              '$safe',
              style: AppTypography.forLight().captionSemibold.copyWith(
                color: CardScrimColors.onScrim,
                height: 1.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingLine extends StatelessWidget {
  const _RatingLine({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final Color ink = context.tokigoColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.thumb_up_rounded,
          size: 15,
          color: context.tokigoColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          rating.toStringAsFixed(1),
          style: typography.captionSemibold.copyWith(
            color: ink,
            fontWeight: FontWeight.w800,
          ),
        ),
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
    final Widget row = Row(
      children: <Widget>[
        Icon(
          Icons.place_outlined,
          size: 14,
          color: context.tokigoColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.caption.copyWith(
              color: context.tokigoColors.textSecondary,
              decoration: onTap == null ? null : TextDecoration.underline,
              decorationColor: context.tokigoColors.textSecondary,
            ),
          ),
        ),
      ],
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
        Icon(
          Icons.near_me_outlined,
          size: 13,
          color: context.tokigoColors.textTertiary,
        ),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.forLight().caption.copyWith(
              color: context.tokigoColors.textTertiary,
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
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          amountText,
          maxLines: 1,
          style: typography.titleMedium.copyWith(
            color: context.tokigoColors.textPrimary,
            fontWeight: FontWeight.w800,
            height: 1.05,
            letterSpacing: -0.3,
          ),
        ),
        if (currency.isNotEmpty) ...<Widget>[
          const SizedBox(width: AppSpacing.xs),
          Text(
            currency,
            style: typography.caption.copyWith(
              color: context.tokigoColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (unit != null) ...<Widget>[
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              isRtl ? unit : '/ $unit',
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.caption.copyWith(
                color: context.tokigoColors.textTertiary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Skeleton body mirrors the photo-above-information geometry of the card.
class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody({required this.aspectRatio});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AspectRatio(
          aspectRatio: aspectRatio,
          child: KeyedSubtree(
            key: const Key('overlap-skeleton-media'),
            child: CardSkeleton.image(),
          ),
        ),
        Padding(
          padding: TravelCardStyle.sheetPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CardSkeleton.title(width: 170, height: 20),
              CardSkeleton.gap(height: AppSpacing.xs),
              CardSkeleton.text(width: 96, height: 19),
              CardSkeleton.gap(height: AppSpacing.md),
              CardSkeleton.text(width: 120, height: 16),
              CardSkeleton.gap(height: AppSpacing.md),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: CardSkeleton.price(width: 88),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
