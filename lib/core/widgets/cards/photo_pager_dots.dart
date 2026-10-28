import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';

/// The page-indicator dots under a photo gallery.
///
/// Inactive dots are 6×6 circles; the active dot stretches into a 6×16 pill so
/// position is readable without relying on colour alone. Renders nothing for a
/// single photo — one dot is noise.
class PhotoPagerDots extends StatelessWidget {
  const PhotoPagerDots({
    super.key,
    required this.count,
    required this.index,
    this.activeColor = AppColors.onMedia,
    this.inactiveColor = AppColors.scrimStrong,
  });

  /// Number of photos. Values below 2 render nothing.
  final int count;

  /// Zero-based index of the visible photo.
  final int index;

  final Color activeColor;
  final Color inactiveColor;

  static const double dotSize = 6;
  static const double activeWidth = 16;
  static const double gap = AppSpacing.sm - 2; // 6

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    final int safeIndex = index.clamp(0, count - 1);

    return Semantics(
      label: 'Photo ${safeIndex + 1} of $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < count; i++) ...<Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: i == safeIndex ? activeWidth : dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: i == safeIndex ? activeColor : inactiveColor,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              if (i < count - 1) const SizedBox(width: gap),
            ],
          ],
        ),
      ),
    );
  }
}
