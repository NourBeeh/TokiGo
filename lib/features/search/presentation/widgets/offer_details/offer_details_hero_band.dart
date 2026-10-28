import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';

/// The photo band at the top of the details page.
///
/// A stay or a car renders the provider's photo (with a soft scrim so the
/// pinned controls stay legible). A flight never does: the only URL a flight
/// carries is an airline logo, and blowing a logo up to a cover image mis-uses
/// the provider's asset — so a flight gets our brand composition with the logo
/// as a small plate. No photo at all is not a giant empty block either: the
/// band becomes `surfaceSecondary` with the vertical's own glyph.
class OfferDetailsHeroBand extends StatelessWidget {
  const OfferDetailsHeroBand({
    super.key,
    required this.imageUrl,
    required this.hue,
    required this.flight,
    required this.glyph,
  });

  final String? imageUrl;
  final Color hue;
  final FlightOffer? flight;
  final IconData glyph;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final url = imageUrl;
    final flightOffer = flight;
    final double dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    final int logoDecodeWidth = (40 * dpr).round().clamp(1, 4096);
    final int heroDecodeWidth = (MediaQuery.sizeOf(context).width * dpr)
        .round()
        .clamp(1, 4096);

    if (url == null || flightOffer != null) {
      return Container(
        color: flightOffer == null ? AppColors.surfaceSecondary : hue,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: Alignment.center,
        child: flightOffer == null
            ? Icon(glyph, size: 48, color: AppColors.textTertiary)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (url != null) ...<Widget>[
                    ClipOval(
                      child: Image.network(
                        url,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        cacheWidth: logoDecodeWidth,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Text(
                    flightOffer.airline,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.title.copyWith(color: AppColors.onBrand),
                  ),
                  if (flightOffer.flightNumber.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      flightOffer.flightNumber,
                      style: typography.caption.copyWith(
                        color: AppColors.onBrand.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ],
              ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.network(
          url,
          fit: BoxFit.cover,
          cacheWidth: heroDecodeWidth,
          errorBuilder: (_, _, _) => _HueFallback(hue: hue),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                AppColors.scrimSoft,
                Colors.transparent,
                AppColors.scrimStrong,
              ],
              stops: <double>[0, 0.4, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _HueFallback extends StatelessWidget {
  const _HueFallback({required this.hue});

  final Color hue;

  @override
  Widget build(BuildContext context) {
    return Container(color: hue.withValues(alpha: 0.85));
  }
}
