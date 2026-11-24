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
import 'package:tokigo/l10n/app_localizations.dart';

/// A structured hotel card: a cropped hotel photo above a distinct information
/// surface with the name, rating, location and price.
///
/// Two callers share this one shape — the hotel results page
/// (`HotelOverlapCard`, from an offer) and the Home recommendation rail (from a
/// `HomeItem`). Keeping the drawing here means the user meets the same card in
/// both places. The legacy class name remains to avoid changing its callers.
///
/// ## Loading is a state of THIS widget
///
/// [loading] replaces the sheet's facts with shimmer placeholders and the
/// photo with a shimmer box. Both states build the SAME `_StayBody` — same
/// `AspectRatio`, same sheet padding, same row order, same divider, same
/// corner radius — so the placeholder cannot drift from the real card when the
/// design changes. The skeleton is never inferred from empty data: pass
/// [loading] (or use [OverlapStayCard.skeleton]).
class OverlapStayCard extends StatelessWidget {
  const OverlapStayCard({
    super.key,
    required this.media,
    required this.title,
    required this.amountText,
    this.currency = '',
    this.unit,
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
    this.showHeartPlatter = true,
    this.loading = false,
  });

  /// Skeleton at the identical geometry — the list must not jump when the real
  /// data lands. Delegates to the same widget with [loading] on.
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
       rating = null,
       reviewCount = null,
       location = null,
       onLocationTap = null,
       distanceText = null,
       onTap = null,
       onFavorite = null,
       isFavorite = false,
       enabled = false,
       heartSize = 40,
       showHeartPlatter = true,
       loading = true;

  /// The photo alone — the heart is drawn by this card on top of it. In the
  /// loading state this is ignored and a shimmer box is painted in its place.
  final Widget media;

  final String title;

  /// Already-formatted amount ("120", "1 250"). Formatting stays with the
  /// caller because each surface has its own rounding rules.
  final String amountText;
  final String currency;

  /// "/ night" when the amount really is a nightly rate. Null hides it.
  final String? unit;

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

  /// Whether the favourite heart draws its white disc platter. The Home stay
  /// card turns it off (the heart sits directly on the photo).
  final bool showHeartPlatter;

  /// Skeleton state — same geometry, no data. See the class comment.
  final bool loading;


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

    final String semanticsLabel =
        this.semanticsLabel ?? (loading ? 'Loading' : _autoSemantics(context));

    return BaseCard(
      onTap: loading ? null : onTap,
      enabled: !loading && enabled,
      loading: loading,
      showBorder: true,
      borderColor: TravelCardStyle.borderColor(context),
      showShadow: false,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      margin: margin,
      semanticsLabel: semanticsLabel,
      child: loading
          ? cardLoadingSemantics(
              _StayBody(
                loading: loading,
                aspectRatio: aspectRatio,
                media: media,
                onFavorite: onFavorite,
                isFavorite: isFavorite,
                heartSize: heartSize,
                showHeartPlatter: showHeartPlatter,
                title: title,
                rating: rating,
                reviewCount: reviewCount,
                location: location,
                onLocationTap: onLocationTap,
                distanceText: distanceText,
                amountText: amountText,
                currency: currency,
                unit: unit,
              ),
              label: semanticsLabel,
            )
          : _StayBody(
              loading: loading,
              aspectRatio: aspectRatio,
              media: media,
              onFavorite: onFavorite,
              isFavorite: isFavorite,
              heartSize: heartSize,
              showHeartPlatter: showHeartPlatter,
              title: title,
              rating: rating,
              reviewCount: reviewCount,
              location: location,
              onLocationTap: onLocationTap,
              distanceText: distanceText,
              amountText: amountText,
              currency: currency,
              unit: unit,
            ),
    );
  }

  String _autoSemantics(BuildContext context) {
    final List<String> parts = <String>[title];
    if (rating != null) parts.add(rating!.toStringAsFixed(1));
    if (reviewCount != null) parts.add('($reviewCount)');
    if (location case final String place) parts.add(place);
    if (distanceText case final String distance) parts.add(distance);
    parts.add('$amountText $currency${unit == null ? '' : ' / $unit'}');
    return parts.join(', ');
  }
}

/// The photo-above-information body shared by the loaded and loading card.
///
/// The photo is inset inside the card with its own rounded corners; the sheet
/// below carries the name, price, location and review row. Both states build
/// this same body, so the skeleton cannot drift from the real card.
class _StayBody extends StatelessWidget {
  const _StayBody({
    required this.loading,
    required this.aspectRatio,
    required this.media,
    required this.onFavorite,
    required this.isFavorite,
    required this.heartSize,
    required this.showHeartPlatter,
    required this.title,
    required this.rating,
    required this.reviewCount,
    required this.location,
    required this.onLocationTap,
    required this.distanceText,
    required this.amountText,
    required this.currency,
    required this.unit,
  });

  final bool loading;
  final double aspectRatio;
  final Widget media;
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final double heartSize;
  final bool showHeartPlatter;
  final String title;
  final double? rating;
  final int? reviewCount;
  final String? location;
  final VoidCallback? onLocationTap;
  final String? distanceText;
  final String amountText;
  final String currency;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final ValueChanged<bool>? onFavorite = loading ? null : this.onFavorite;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The reference card keeps a white margin around the photo and rounds
        // the image itself, so the photo sits inside the card's own surface.
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (loading) CardSkeleton.image() else media,
                  // Overlays are data-driven: they never appear in the skeleton.
                  if (onFavorite != null)
                    PositionedDirectional(
                      top: AppSpacing.sm,
                      end: AppSpacing.sm,
                      child: CardFavorite(
                        value: isFavorite,
                        onChanged: onFavorite,
                        size: heartSize,
                        onImage: true,
                        showPlatter: showHeartPlatter,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        _StaySheet(
          loading: loading,
          title: title,
          rating: rating,
          reviewCount: reviewCount,
          location: location,
          onLocationTap: onLocationTap,
          distanceText: distanceText,
          amountText: amountText,
          currency: currency,
          unit: unit,
        ),
      ],
    );
  }
}

/// The information sheet shared by the loaded and loading card.
///
/// Layout (owner reference, 2026-11): the name and the price share the first
/// row — the price right-aligned with its per-night unit beneath it — then the
/// location + distance line, then the star review line.
///
/// Every slot is guarded by `loading || <data present>`, so the placeholder
/// reserves exactly the room a fully-populated card uses while a sparse real
/// card keeps its own (smaller) footprint. Placeholder heights mirror the text
/// style of the slot they stand in for.
class _StaySheet extends StatelessWidget {
  const _StaySheet({
    required this.loading,
    required this.title,
    required this.rating,
    required this.reviewCount,
    required this.location,
    required this.onLocationTap,
    required this.distanceText,
    required this.amountText,
    required this.currency,
    required this.unit,
  });

  final bool loading;
  final String title;
  final double? rating;
  final int? reviewCount;
  final String? location;
  final VoidCallback? onLocationTap;
  final String? distanceText;
  final String amountText;
  final String currency;
  final String? unit;

  // Placeholder geometry mirrors the loaded slot it stands in for:
  // two-line title (2 × 22), rating/location captions (17 each), price (24).
  // See AppTypography for the styles these derive from.
  static const double _titleWidth = 170;
  static const double _titleHeight = 44;
  static const double _ratingWidth = 116;
  static const double _ratingHeight = 17;
  static const double _locationWidth = 220;
  static const double _locationHeight = 17;
  static const double _priceWidth = 88;
  static const double _priceHeight = 24;

  @override
  Widget build(BuildContext context) {
    final bool showRating = loading || rating != null;
    final bool showLocation = loading || location != null;
    final bool showDistance = loading || distanceText != null;
    final bool showPrice = loading || amountText.isNotEmpty;

    return Padding(
      padding: TravelCardStyle.sheetPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: loading
                    ? CardSkeleton.title(
                        width: _titleWidth,
                        height: _titleHeight,
                      )
                    : Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.forLight().bodyLargeMedium
                            .copyWith(
                              color: context.tokigoColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                      ),
              ),
              if (showPrice) ...<Widget>[
                const SizedBox(width: AppSpacing.md),
                loading
                    ? CardSkeleton.price(
                        width: _priceWidth,
                        height: _priceHeight,
                      )
                    : _StayPriceBlock(
                        amountText: amountText,
                        currency: currency,
                        unit: unit,
                      ),
              ],
            ],
          ),
          if (showLocation || showDistance) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            if (loading)
              CardSkeleton.text(width: _locationWidth, height: _locationHeight)
            else
              _StayMetaRow(
                location: location,
                onLocationTap: onLocationTap,
                distanceText: distanceText,
              ),
          ],
          if (showRating) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            if (loading)
              CardSkeleton.text(width: _ratingWidth, height: _ratingHeight)
            else
              StayRatingLine(rating: rating!, reviewCount: reviewCount),
          ],
        ],
      ),
    );
  }
}

/// The location + distance line: a pin, the place, then the distance — one row,
/// as in the reference card.
class _StayMetaRow extends StatelessWidget {
  const _StayMetaRow({
    required this.location,
    required this.onLocationTap,
    required this.distanceText,
  });

  final String? location;
  final VoidCallback? onLocationTap;
  final String? distanceText;

  @override
  Widget build(BuildContext context) {
    final String? place = location;
    final String? distance = distanceText;
    if (place == null) {
      return Row(
        children: <Widget>[
          Icon(
            Icons.near_me_outlined,
            size: 13,
            color: context.tokigoColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            distance ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.forLight().caption.copyWith(
              color: context.tokigoColors.textTertiary,
            ),
          ),
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(
          flex: 2,
          child: StayLocationLine(text: place, onTap: onLocationTap),
        ),
        if (distance != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.near_me_outlined,
            size: 13,
            color: context.tokigoColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              distance,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.forLight().caption.copyWith(
                color: context.tokigoColors.textTertiary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The right-aligned price block: the amount (with its currency) on top and the
/// per-night unit beneath it.
class _StayPriceBlock extends StatelessWidget {
  const _StayPriceBlock({
    required this.amountText,
    required this.currency,
    required this.unit,
  });

  final String amountText;
  final String currency;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    final String? unit = this.unit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
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
          ],
        ),
        if (unit != null)
          Text(
            isRtl ? unit : '/ $unit',
            maxLines: 1,
            style: typography.caption.copyWith(
              color: context.tokigoColors.textTertiary,
            ),
          ),
      ],
    );
  }
}

/// The hotel's own class, as a quiet glass pill over the photo. It is a fact
/// (the provider's classification), not a promotional badge.
class StayClassPill extends StatelessWidget {
  const StayClassPill({super.key, required this.stars});

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
          Icon(Icons.star_rounded, size: 13, color: CardScrimColors.onScrim),
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

class StayRatingLine extends StatelessWidget {
  const StayRatingLine({super.key, required this.rating, this.reviewCount});

  final double rating;

  /// When set, the line renders the five-star score plus the review count
  /// (owner reference card, 2026-11). Null keeps the compact score-only line
  /// used by the split card.
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final Color ink = context.tokigoColors.textPrimary;
    final int? reviews = reviewCount;
    if (reviews == null) {
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
    final int filled = rating.round().clamp(0, 5);
    final String reviewsText =
        AppLocalizations.of(context)?.offerReviewsCount(reviews) ??
        '$reviews reviews';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 5; i++)
          Icon(
            i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 14,
            color: i < filled ? ink : context.tokigoColors.textTertiary,
          ),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          reviewsText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: typography.caption.copyWith(
            color: context.tokigoColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class StayLocationLine extends StatelessWidget {
  const StayLocationLine({super.key, required this.text, this.onTap});

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

class StayDistanceLine extends StatelessWidget {
  const StayDistanceLine({super.key, required this.text});

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

class StayPriceLine extends StatelessWidget {
  const StayPriceLine({
    super.key,
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
