import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/cards/base_card.dart';
import 'package:tokigo/core/widgets/cards/card_favorite.dart';
import 'package:tokigo/core/widgets/cards/card_skeleton.dart';
import 'package:tokigo/core/widgets/cards/overlap_stay_card.dart';
import 'package:tokigo/core/widgets/cards/travel_card_style.dart';

/// Home's horizontal-split stay card (owner decision, 2026-11).
///
/// A 60 / 40 horizontal split: the hotel photo occupies the larger share, the
/// decision facts the smaller one. The image sits on the STARTING side, so it
/// mirrors in Arabic (right) exactly as the reading direction does.
///
/// Used ONLY by the Home "Stays Near You" rail — the hotel results page and
/// every other hotel card keep [OverlapStayCard]. The brand palette, corner
/// radius, border and typography are the same tokens that card uses.
class HomeSplitStayCard extends StatelessWidget {
  const HomeSplitStayCard({
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
    this.imageFlex = 60,
    this.infoFlex = 40,
    this.heartSize = 40,
    this.showHeartPlatter = false,
    this.loading = false,
  });

  /// Skeleton at the identical geometry — the rail must not jump when the real
  /// data lands. Same split flexes, same card shell.
  const HomeSplitStayCard.loading({
    super.key,
    this.margin,
    this.semanticsLabel = 'Loading',
    this.imageFlex = 60,
    this.infoFlex = 40,
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
       showHeartPlatter = false,
       loading = true;

  /// The photo alone — the heart and the class pill are drawn on top of it.
  final Widget media;

  final String title;

  /// Already-formatted amount ("120", "1 250"). Formatting stays with the
  /// caller because each surface has its own rounding rules.
  final String amountText;
  final String currency;

  /// "/ night" when the amount really is a nightly rate. Null hides it.
  final String? unit;

  /// The hotel's own class (1–5), drawn as a glass pill on the photo.
  final int? starClass;

  final double? rating;
  final int? reviewCount;

  /// The stay's location line ("Cairo, EG").
  final String? location;
  final VoidCallback? onLocationTap;

  /// An honest distance line ("1.2 km from the center") — null hides it.
  final String? distanceText;

  final VoidCallback? onTap;
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final bool enabled;

  final String? semanticsLabel;

  /// Outer margin. The rail passes [EdgeInsets.zero] and supplies its own
  /// spacing.
  final EdgeInsetsGeometry? margin;

  /// The photo's share of the split (the larger share).
  final int imageFlex;

  /// The information panel's share of the split (the smaller share).
  final int infoFlex;

  final double heartSize;

  /// Whether the favourite heart draws its white disc platter. The Home rail
  /// draws the heart directly on the photo.
  final bool showHeartPlatter;

  /// Skeleton state — same geometry, no data.
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
              _SplitBody(loading: true, imageFlex: imageFlex, infoFlex: infoFlex),
              label: semanticsLabel,
            )
          : _SplitBody(
              loading: false,
              imageFlex: imageFlex,
              infoFlex: infoFlex,
              media: media,
              starClass: starClass,
              onFavorite: onFavorite,
              isFavorite: isFavorite,
              heartSize: heartSize,
              showHeartPlatter: showHeartPlatter,
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

/// The split body shared by the loaded and loading card.
///
/// The photo is the FIRST child, so it lands on the starting side in both
/// writing directions (left in LTR, right in RTL).
class _SplitBody extends StatelessWidget {
  const _SplitBody({
    required this.loading,
    required this.imageFlex,
    required this.infoFlex,
    this.media = const SizedBox.shrink(),
    this.starClass,
    this.onFavorite,
    this.isFavorite = false,
    this.heartSize = 40,
    this.showHeartPlatter = false,
    this.title = '',
    this.rating,
    this.location,
    this.onLocationTap,
    this.distanceText,
    this.amountText = '',
    this.currency = '',
    this.unit,
  });

  final bool loading;
  final int imageFlex;
  final int infoFlex;
  final Widget media;
  final int? starClass;
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;
  final double heartSize;
  final bool showHeartPlatter;
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
    return Row(
      textDirection: Directionality.of(context),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(flex: imageFlex, child: _media(context)),
        Expanded(flex: infoFlex, child: _info(context)),
      ],
    );
  }

  Widget _media(BuildContext context) {
    final int? starClass = loading ? null : this.starClass;
    final ValueChanged<bool>? onFavorite = loading ? null : this.onFavorite;
    return Stack(
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
        if (starClass != null)
          PositionedDirectional(
            top: AppSpacing.md,
            start: AppSpacing.md,
            child: StayClassPill(stars: starClass),
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
              showPlatter: showHeartPlatter,
            ),
          ),
      ],
    );
  }

  Widget _info(BuildContext context) {
    final bool showRating = loading || rating != null;
    final bool showLocation = loading || location != null;
    final bool showDistance = loading || distanceText != null;
    final bool showPrice = loading || amountText.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (loading)
            CardSkeleton.title(width: 120, height: 40)
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
              CardSkeleton.text(width: 80, height: 17)
            else
              // The 40% column is narrow: at a large text scale the rating
              // row (icon + score) is wider than the column. Scale it down
              // instead of overflowing the card.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: StayRatingLine(rating: rating!),
                ),
              ),
          ],
          if (showLocation) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            if (loading)
              CardSkeleton.text(width: 100, height: 17)
            else
              StayLocationLine(text: location!, onTap: onLocationTap),
          ],
          if (showDistance) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            if (loading)
              CardSkeleton.text(width: 90, height: 17)
            else
              StayDistanceLine(text: distanceText!),
          ],
          const Spacer(),
          if (showPrice) ...<Widget>[
            Divider(
              height: 1,
              thickness: 1,
              color: context.tokigoColors.hairline,
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              // The 40% column is narrow: the price scales down to fit rather
              // than overflowing the card.
              child: loading
                  ? CardSkeleton.price(width: 80, height: 24)
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: StayPriceLine(
                        amountText: amountText,
                        currency: currency,
                        unit: unit,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
