import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_radius.dart';

/// A reusable frosted-glass surface used for on-image overlays (favorite
/// toggle, translucent badge/rating/feature pills placed over a photo).
///
/// Centralises the BackdropFilter + translucent-tint + hairline-border recipe
/// so feature cards never re-implement glassmorphism themselves. Defaults are
/// tuned for the light-only "Pure White Premium" design language.
class CardGlass extends StatelessWidget {
    const CardGlass({
      super.key,
      required this.child,
      this.padding = EdgeInsets.zero,
      this.borderRadius,
      this.blur = 12,
      this.tint,
      this.borderColor,
      this.borderWidth = 1,
      this.alignment,
    });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  /// Backdrop blur radius in logical pixels.
  final double blur;

  /// Base layer tint; defaults to a translucent white.
  final Color? tint;

  /// Hairline border colour; defaults to a translucent white.
  final Color? borderColor;
  final double borderWidth;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.md);
    final effectiveTint = tint ?? Colors.white.withValues(alpha: 0.55);
    final effectiveBorder = borderColor ?? Colors.white.withValues(alpha: 0.45);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          alignment: alignment,
          decoration: BoxDecoration(
            color: effectiveTint,
            borderRadius: radius,
            border: Border.all(color: effectiveBorder, width: borderWidth),
          ),
          child: child,
        ),
      ),
    );
  }
}
