import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';

/// Unified primary action for cards: brand-gradient pill with
/// enabled / disabled / loading states.
class CardPrimaryAction extends StatelessWidget {
  const CardPrimaryAction({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.height = 44,
    this.icon,
  });

  final String label;

  /// Null disables the button (reduced opacity, taps swallowed).
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final double height;
  final IconData? icon;

  bool get _disabled => onPressed == null || loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = scheme.onPrimary;
    bool pressed = false;

    final child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );

    return Opacity(
      opacity: _disabled && !loading ? 0.55 : 1,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) =>
            GestureDetector(
              onTapDown: _disabled
                  ? null
                  : (_) => setState(() => pressed = true),
              onTapUp: _disabled
                  ? null
                  : (_) => setState(() => pressed = false),
              onTapCancel: _disabled
                  ? null
                  : () => setState(() => pressed = false),
              onTap: _disabled
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onPressed!();
                    },
              child: AnimatedScale(
                scale: pressed ? 0.96 : 1,
                duration: const Duration(milliseconds: 110),
                curve: Curves.easeOut,
                child: Container(
                  height: height,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [
                        context.tokigoColors.brand,
                        context.tokigoColors.brand,
                      ],
                    ),
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: child,
                ),
              ),
            ),
      ),
    );
  }
}
