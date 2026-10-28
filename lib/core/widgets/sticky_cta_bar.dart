import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_elevation.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';

/// The two CTA-bar skins (doc 18 §2.6).
///
/// * [light] — the booking flow's translucent bar over the warm canvas.
/// * [dark] — the detail page's `ctaBar` slab: a solid #2B2320 surface with
///   `xl` top corners and an upward shadow. The dark bar is a **component**
///   colour, not a second theme.
enum StickyCtaBarVariant { light, dark }

/// Bottom sticky action bar that hosts a page's primary CTA.
class StickyCtaBar extends StatelessWidget {
  const StickyCtaBar({
    super.key,
    required this.child,
    this.variant = StickyCtaBarVariant.light,
  });

  final Widget child;
  final StickyCtaBarVariant variant;

  @override
  Widget build(BuildContext context) {
    // The VIEW padding, not the MediaQuery one: a Scaffold consumes the
    // bottom inset for its body, so a bar that reads `padding.bottom` ends up
    // under the system navigation bar (it did, on the device).
    final double bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final EdgeInsetsGeometry padding = EdgeInsetsDirectional.only(
      start: AppSpacing.lg,
      top: AppSpacing.md,
      end: AppSpacing.lg,
      bottom: bottomPadding + AppSpacing.md,
    );

    if (variant == StickyCtaBarVariant.dark) {
      return Container(
        // Doc 18 §2.6 — solid `ctaBar`, top radius 24, AppElevation.lg cast
        // UPWARDS so the slab separates from the sheet without a hairline.
        decoration: BoxDecoration(
          color: AppColors.ctaBar,
          borderRadius: const BorderRadiusDirectional.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          boxShadow: AppElevation.up(level: AppElevation.lg),
        ),
        padding: padding,
        child: child,
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.9),
            border: Border(top: BorderSide(color: AppColors.hairlineStrong)),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
