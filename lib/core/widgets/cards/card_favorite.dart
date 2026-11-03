import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';

/// The platter every wishlist heart sits on.
///
/// One shape everywhere (owner, 2026-11-03): a soft **white disc** whose edge
/// comes from a diffuse shadow — never a border, never a glass square. This is
/// the on-media control pattern already documented by [AppColors.onMediaFill],
/// so the heart reads as the same control over a photo and on a plain card.
class HeartPlatter extends StatelessWidget {
  const HeartPlatter({
    super.key,
    required this.diameter,
    this.child,
    this.strongShadow = false,
  });

  final double diameter;
  final Widget? child;

  /// A slightly deeper shadow for discs floating on photography, where the
  /// surrounding is arbitrary rather than a light card.
  final bool strongShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.tokigoColors.onMediaFill,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: strongShadow ? 0.20 : 0.12),
            blurRadius: strongShadow ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}

/// Heart toggle for cards. Purely presentational — persistence is wired by a
/// later phase through [onChanged].
///
/// The heart always sits on a [HeartPlatter] (a white disc), so the control
/// looks identical over a photo and on a plain surface.
class CardFavorite extends StatelessWidget {
  const CardFavorite({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 34,
    this.enabled = true,
    this.onImage = false,
    this.heartColor,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;
  final bool enabled;

  /// Renders the disc with a deeper shadow for hearts placed on top of a photo.
  final bool onImage;

  /// Active heart colour; defaults to the brand-red semantic token.
  final Color? heartColor;

  @override
  Widget build(BuildContext context) {
    final heart = heartColor ?? context.tokigoColors.danger;
    // The disc is always white, so the idle heart is always a dark neutral —
    // never a theme-tinted grey that would vanish on it.
    const Color idleColor = AppColors.textPrimary;

    Widget heartIcon(double iconSize) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: Icon(
        value ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        key: ValueKey(value),
        size: iconSize,
        color: value ? heart : idleColor,
      ),
    );

    final Widget box = HeartPlatter(
      diameter: size,
      strongShadow: onImage,
      child: heartIcon(size * 0.5),
    );

    // The visual disc may be smaller, but the tappable area is always expanded
    // to at least a 48×48dp accessible hit target (Material guidance).
    final hitTarget = AppSpacing.minimumTapTarget;

    bool pressed = false;
    return Semantics(
      button: enabled && onChanged != null,
      enabled: enabled,
      toggled: value,
      label: value ? 'Remove from favorites' : 'Add to favorites',
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: SizedBox(
          width: size < hitTarget ? hitTarget : size,
          height: size < hitTarget ? hitTarget : size,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) =>
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: enabled && onChanged != null
                      ? (_) => setState(() => pressed = true)
                      : null,
                  onTapUp: enabled && onChanged != null
                      ? (_) => setState(() => pressed = false)
                      : null,
                  onTapCancel: enabled && onChanged != null
                      ? () => setState(() => pressed = false)
                      : null,
                  onTap: enabled && onChanged != null
                      ? () {
                          HapticFeedback.lightImpact();
                          onChanged!(!value);
                        }
                      : null,
                  child: AnimatedScale(
                    scale: pressed ? 0.88 : 1,
                    duration: const Duration(milliseconds: 110),
                    curve: Curves.easeOut,
                    child: Center(child: box),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
