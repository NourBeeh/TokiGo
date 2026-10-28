import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/cards/base_card.dart';
import 'package:tokigo/core/widgets/cards/card_image.dart';
import 'package:tokigo/core/widgets/cards/photo_counter_chip.dart';
import 'package:tokigo/core/widgets/cards/photo_pager_dots.dart';
import 'package:tokigo/core/widgets/cards/rating_badge.dart';

/// Card B — the grid badge card (reference A-4).
///
/// Not a variant of card A: it adds a **photo pager**, a **green rating
/// badge**, optional grey class stars and a **discounted price** with the old
/// amount struck through.
///
/// The pager is real — the dots follow the photo the user is looking at, and
/// the counter is the same one that photo shows. A single photo renders no
/// dots and no counter.
class DiscoverBadgeCard extends StatefulWidget {
  const DiscoverBadgeCard({
    super.key,
    required this.title,
    this.imageUrls = const <String>[],
    this.aspectRatio = 16 / 9,
    this.classStars,
    this.rating,
    this.reviewCount,
    this.ratingLabel,
    this.priceLabel,
    this.price,
    this.oldPrice,
    this.currency = 'EUR',
    this.priceColor,
    this.onTap,
    this.semanticLabel,
  });

  final String title;

  /// Gallery photos, in provider order. Empty renders one placeholder frame.
  final List<String> imageUrls;

  /// Photo aspect. 16:9 is the reference estimate (not yet verified against a
  /// frame — see decision D10).
  final double aspectRatio;

  /// 1–5 hotel class, drawn as grey stars. Null hides the row.
  final int? classStars;

  /// Guest score on its own scale (e.g. 8.8/10 or 4.8/5).
  final double? rating;
  final int? reviewCount;

  /// The word beside the badge — "Exceptional", "Very good", …
  final String? ratingLabel;

  /// "Nightly from". Null hides it.
  final String? priceLabel;

  final double? price;
  final double? oldPrice;
  final String currency;

  /// Price colour. Left null until decision D1 lands; the reference's violet
  /// collides with the AI colour, so nothing here guesses a hue.
  final Color? priceColor;

  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<DiscoverBadgeCard> createState() => _DiscoverBadgeCardState();
}

class _DiscoverBadgeCardState extends State<DiscoverBadgeCard> {
  static const double _mediaInset = AppSpacing.md;

  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _photos =>
      widget.imageUrls.isEmpty ? <String>[''] : widget.imageUrls;

  String? get _money {
    final double? price = widget.price;
    if (price == null) return null;
    return intl.NumberFormat.currency(
      symbol: '',
      locale: 'en_US',
    ).format(price).trim();
  }

  String? get _oldMoney {
    final double? price = widget.oldPrice;
    if (price == null) return null;
    return intl.NumberFormat.currency(
      symbol: '',
      locale: 'en_US',
    ).format(price).trim();
  }

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final bool hasGallery = widget.imageUrls.length > 1;

    return BaseCard(
      onTap: widget.onTap,
      showBorder: false,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      semanticsLabel: widget.semanticLabel ?? widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                PageView.builder(
                  controller: _controller,
                  itemCount: _photos.length,
                  onPageChanged: (int i) => setState(() => _index = i),
                  itemBuilder: (context, i) =>
                      CardImage(url: _photos[i], semanticLabel: widget.title),
                ),
                if (hasGallery)
                  PositionedDirectional(
                    start: _mediaInset,
                    bottom: _mediaInset,
                    child: PhotoPagerDots(count: _photos.length, index: _index),
                  ),
                if (hasGallery)
                  PositionedDirectional(
                    end: _mediaInset,
                    bottom: _mediaInset,
                    child: PhotoCounterChip(
                      index: _index + 1,
                      count: _photos.length,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (widget.classStars != null) ...<Widget>[
                  _ClassStars(stars: widget.classStars!),
                  const SizedBox(height: AppSpacing.xs),
                ],
                if (widget.rating != null)
                  Row(
                    children: <Widget>[
                      RatingBadge(score: widget.rating!.toStringAsFixed(1)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              widget.ratingLabel ?? widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typography.bodyLargeMedium.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (widget.reviewCount != null)
                              Text(
                                '(${widget.reviewCount})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.bodyLargeMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                if (_money != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      if (widget.priceLabel != null)
                        Flexible(
                          child: Text(
                            widget.priceLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (widget.priceLabel != null)
                        const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        flex: 3,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerEnd,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: <Widget>[
                              Text(
                                '$_money ${widget.currency}',
                                textDirection: TextDirection.ltr,
                                style: typography.titleMedium.copyWith(
                                  color:
                                      widget.priceColor ??
                                      AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (_oldMoney != null) ...<Widget>[
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  '$_oldMoney ${widget.currency}',
                                  textDirection: TextDirection.ltr,
                                  style: typography.body.copyWith(
                                    color: AppColors.textTertiary,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grey class stars — the property's rating, not the guest score.
class _ClassStars extends StatelessWidget {
  const _ClassStars({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    final int safe = stars.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < safe; i++)
          const Icon(Icons.star_rounded, size: 12, color: AppColors.classStar),
      ],
    );
  }
}
