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
       heartSize = 40,
       loading = true;

  /// The photo alone — the heart and the class pill are drawn by this card on
  /// top of it. In the loading state this is ignored and a shimmer box is
  /// painted in its place.
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
        this.semanticsLabel ?? (loading ? 'Loading' : _autoSemantics);

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
                starClass: starClass,
                onFavorite: onFavorite,
                isFavorite: isFavorite,
                heartSize: heartSize,
                title: title,
                rating: rating,
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
              starClass: starClass,
              onFavorite: onFavorite,
              isFavorite: isFavorite,
              heartSize: heartSize,
              title: title,
              rating: rating,
              location: location,
              onLocationTap: onLocationTap,
              distanceText: distanceText,
              amountText: amountText,
              currency: currency,
              unit: unit,
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

/// The photo-above-information body shared by the loaded and loading card.
///
/// Row order, the [AspectRatio] photo box, the sheet padding and the divider
/// are identical in both states; only the sheet's slot content switches.
class _StayBody extends StatelessWidget {
  const _StayBody({
    required this.loading,
    required this.aspectRatio,
    required this.media,
    required this.starClass,
    required this.onFavorite,
    required this.isFavorite,
    required this.heartSize,
    required this.title,
    required this.rating,
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
  final int? starClass;
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final double heartSize;
  final String title;
  final double? rating;
  final String? location;
  final VoidCallback? onLocationTap;
  final String? distanceText;
  final String amountText;
  final String currency;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    // Local copies so the skeleton guards below read as plain booleans and
    // Dart can promote the class fields.
    final int? starClass = loading ? null : this.starClass;
    final ValueChanged<bool>? onFavorite = loading ? null : this.onFavorite;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (loading) CardSkeleton.image() else media,
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
              // Overlays are data-driven: they never appear in the skeleton.
              if (starClass != null)
                PositionedDirectional(
                  top: AppSpacing.md,
                  start: AppSpacing.md,
                  child: _ClassPill(stars: starClass),
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
        _StaySheet(
          loading: loading,
          title: title,
          rating: rating,
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
/// Every slot is guarded by `loading || <data present>`, so the placeholder
/// reserves exactly the room a fully-populated card uses while a sparse real
/// card keeps its own (smaller) footprint. Placeholder heights mirror the text
/// style of the slot they stand in for.
class _StaySheet extends StatelessWidget {
  const _StaySheet({
    required this.loading,
    required this.title,
    required this.rating,
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
  final String? location;
  final VoidCallback? onLocationTap;
  final String? distanceText;
  final String amountText;
  final String currency;
  final String? unit;

  // Placeholder geometry mirrors the loaded slot it stands in for:
  // two-line title (2 × 22), rating/location/distance captions (17 each),
  // price (24). See AppTypography for the styles these derive from.
  static const double _titleWidth = 170;
  static const double _titleHeight = 44;
  static const double _ratingWidth = 96;
  static const double _ratingHeight = 17;
  static const double _locationWidth = 120;
  static const double _locationHeight = 17;
  static const double _distanceWidth = 100;
  static const double _distanceHeight = 17;
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
          if (loading)
            CardSkeleton.title(width: _titleWidth, height: _titleHeight)
          else
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
          if (showRating) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            if (loading)
              CardSkeleton.text(width: _ratingWidth, height: _ratingHeight)
            else
              _RatingLine(rating: rating!),
          ],
          if (showLocation) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            if (loading)
              CardSkeleton.text(width: _locationWidth, height: _locationHeight)
            else
              _LocationLine(text: location!, onTap: onLocationTap),
          ],
          if (showDistance) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            if (loading)
              CardSkeleton.text(width: _distanceWidth, height: _distanceHeight)
            else
              _DistanceLine(text: distanceText!),
          ],
          if (showPrice) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, thickness: 1, color: context.tokigoColors.hairline),
            const SizedBox(height: AppSpacing.md),
            // Start-aligned: the nightly price sits on the LEFT in English
            // (LTR) and on the right in Arabic (RTL), the side the eye reaches
            // first in each language.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: loading
                  ? CardSkeleton.price(width: _priceWidth, height: _priceHeight)
                  : _PriceLine(
                      amountText: amountText,
                      currency: currency,
                      unit: unit,
                    ),
            ),
          ],
        ],
      ),
    );
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
          const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
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
