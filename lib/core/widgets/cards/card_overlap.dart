import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_elevation.dart';
import 'package:tokigo/core/theme/app_overlap.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';

/// Photo + info-sheet card shell (archetype A): the sheet rides up over the
/// bottom of the photo by [overlap] pixels.
///
/// This is the card engineering of the whole system, so the geometry is
/// explicit rather than emergent:
///
///     total height = media height + sheet height − overlap
///
/// Flutter has no negative margin, and [Transform.translate] would leave a
/// transparent gap at the bottom of the card instead of shrinking it. So the
/// card is a [Stack] whose sizing child is a [Column] of
/// `(media height − overlap)` + the sheet, while the media is painted
/// separately at its full height underneath. The sheet therefore covers the
/// photo's last [overlap] pixels and the card ends exactly where the sheet
/// ends.
///
/// The media must have a bounded width (every card placement does — a list, a
/// rail with a fixed card width, or a stretched column).
class CardOverlap extends StatelessWidget {
  const CardOverlap({
    super.key,
    required this.media,
    required this.sheet,
    this.mediaAspectRatio = 4 / 3,
    this.mediaHeight,
    this.overlap = AppOverlap.card,
    this.radius = AppRadius.lg,
    this.sheetTopRadius,
    this.sheetPadding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    this.elevated = true,
    this.clipOuter = true,
    this.fillSheet = false,
  });

  /// The photo (or any media). Painted full-height behind the sheet.
  final Widget media;

  /// The info sheet content. Its own height drives the bottom of the card.
  final Widget sheet;

  /// Width ÷ height of the media area. 4:3 matches the reference's results
  /// card; pass a different ratio for other placements. Ignored when
  /// [mediaHeight] is set.
  final double mediaAspectRatio;

  /// Explicit media height — used by the detail hero, whose height is a
  /// fraction of the viewport rather than a ratio of the card width.
  final double? mediaHeight;

  /// How far the sheet rides up over the media. [AppOverlap.card] (48) by
  /// default — the detail hero passes [AppOverlap.detailSheet] (24) instead.
  final double overlap;

  /// Outer corner radius of the whole card.
  final double radius;

  /// Top radius of the sheet alone. Defaults to [radius]; the detail hero
  /// uses `xl` 24 while the outer surface is square.
  final double? sheetTopRadius;

  /// Padding inside the sheet.
  final EdgeInsetsGeometry sheetPadding;

  /// Draw the sheet's resting shadow onto the photo.
  final bool elevated;

  /// Clip the whole surface to [radius]. Off for the full-bleed hero, where
  /// only the sheet's top corners are rounded.
  final bool clipOuter;

  /// Stretch the sheet to the card's own height when the parent supplies a
  /// bounded one (a fixed-height rail, a grid cell). The sheet can then pin a
  /// footer to the bottom with [MainAxisAlignment.spaceBetween].
  ///
  /// Off by default: a content-sized card must end where its sheet ends.
  final bool fillSheet;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          mediaHeight != null || constraints.hasBoundedWidth,
          'CardOverlap needs either an explicit mediaHeight or a bounded '
          'width to size its media.',
        );
        if (mediaHeight == null && !constraints.hasBoundedWidth) {
          return const SizedBox.shrink();
        }

        final double mediaExtent =
            mediaHeight ?? constraints.maxWidth / mediaAspectRatio;
        final double aboveSheet = math.max(0.0, mediaExtent - overlap);
        final double topRadius = sheetTopRadius ?? radius;
        final EdgeInsets resolvedPadding = sheetPadding.resolve(
          Directionality.of(context),
        );
        // Only a parent that already fixed the card's height can hand the
        // sheet a definite remainder to fill.
        final double? sheetHeight = fillSheet && constraints.hasBoundedHeight
            ? math.max(0.0, constraints.maxHeight - aboveSheet)
            : null;

        final Widget content = ColoredBox(
          color: context.tokigoColors.surface,
          child: Stack(
            children: <Widget>[
              PositionedDirectional(
                top: 0,
                start: 0,
                end: 0,
                height: mediaExtent,
                child: media,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(height: aboveSheet),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.tokigoColors.surface,
                      borderRadius: BorderRadiusDirectional.vertical(
                        top: Radius.circular(topRadius),
                      ),
                      boxShadow: elevated
                          ? AppElevation.shadow(
                              background: context.tokigoColors.surface,
                              level: AppElevation.md,
                            )
                          : null,
                    ),
                    child: Padding(
                      padding: resolvedPadding,
                      child: sheetHeight == null
                          ? sheet
                          : SizedBox(
                              height: math.max(
                                0.0,
                                sheetHeight - resolvedPadding.vertical,
                              ),
                              child: sheet,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        if (!clipOuter) return content;
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: content,
        );
      },
    );
  }
}
