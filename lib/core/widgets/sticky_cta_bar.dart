import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';

/// Bottom sticky action bar with a soft blur, used to host the primary CTA
/// of booking-flow pages (price total + continue button).
class StickyCtaBar extends StatelessWidget {
  const StickyCtaBar({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(
                color: AppColors.outline.withValues(alpha: 0.7),
              ),
            ),
          ),
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            top: AppSpacing.md,
            right: AppSpacing.lg,
            bottom: bottomPadding + AppSpacing.md,
          ),
          child: child,
        ),
      ),
    );
  }
}
