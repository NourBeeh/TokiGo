import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/cards/card_glass.dart';

/// Heart toggle for cards. Purely presentational — persistence is wired by a
/// later phase through [onChanged].
///
/// Theme-aware (adapts background/foreground to light & dark) and supports a
/// frosted-glass [onImage] variant for hearts placed directly over a photo.
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

  /// Glass overlay styling for hearts rendered on top of a photo.
  final bool onImage;

  /// Active heart colour; defaults to the brand-red semantic token.
  final Color? heartColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final heart = heartColor ?? AppColors.danger;
    final idleColor = scheme.onSurfaceVariant;

    final icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: child,
      ),
      child: Icon(
        value ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        key: ValueKey(value),
        size: size * 0.53,
        color: value ? heart : idleColor,
      ),
    );

    Widget box;
    if (onImage) {
      box = SizedBox(
        width: size,
        height: size,
        child: CardGlass(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          padding: EdgeInsets.zero,
          child: Center(child: icon),
        ),
      );
    } else {
      box = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Center(child: icon),
      );
    }

    // The visual box may be smaller, but the tappable area is always expanded
    // to at least a 48×48dp accessible hit target (Material guidance).
    final hitTarget = AppSpacing.minimumTapTarget;

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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled && onChanged != null
                ? () {
                    HapticFeedback.lightImpact();
                    onChanged!(!value);
                  }
                : null,
            child: Center(child: box),
          ),
        ),
      ),
    );
  }
}
