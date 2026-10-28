import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';

/// The `1 / 5` photo counter that sits on a gallery's bottom corner.
///
/// Numerals stay LTR in both directions: "3 / 12" must never become "12 / 3"
/// when the app runs in Arabic.
class PhotoCounterChip extends StatelessWidget {
  const PhotoCounterChip({super.key, required this.index, required this.count});

  /// One-based position of the visible photo.
  final int index;

  /// Total number of photos.
  final int count;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final int safeIndex = index.clamp(1, count);
    final String text = '$safeIndex / $count';

    return Semantics(
      label: 'Photo $safeIndex of $count',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            // The reference's 45% black — the same value as the glass tint.
            color: AppColors.glassTint,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            text,
            textDirection: TextDirection.ltr,
            style: typography.label.copyWith(
              color: AppColors.onMedia,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
