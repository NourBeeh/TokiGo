import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_typography.dart';

/// The circular score disc that sits on a photo's top corner.
///
/// The reference paints a white numeral on green. Plain [AppColors.success]
/// #16A34A with white is only 3.4:1 — below AA — so the disc uses
/// [AppColors.successStrong] #15803D (5.0:1) instead.
///
/// The score is passed pre-formatted because the system is used on a 10-point
/// scale and a 5-point scale in different verticals; the widget never guesses.
class RatingBadge extends StatelessWidget {
  const RatingBadge({
    super.key,
    required this.score,
    this.size = 36,
    this.semanticLabel,
  });

  /// Already-formatted score, e.g. `8.8`. Never localise the numeral.
  final String score;

  /// Outer diameter. 36 is the reference's card size.
  final double size;

  /// Screen-reader text. Defaults to "Rated 8.8".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Semantics(
      label: semanticLabel ?? 'Rated $score',
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.successStrong,
            shape: BoxShape.circle,
          ),
          child: Text(
            score,
            textDirection: TextDirection.ltr,
            style: typography.label.copyWith(
              color: AppColors.onMedia,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
