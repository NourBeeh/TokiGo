import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';

/// Unified primary action for cards: a red primary pill with
/// enabled / disabled / loading states.
class CardPrimaryAction extends StatelessWidget {
  const CardPrimaryAction({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.height = 52,
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
    final tc = context.tokigoColors;
    final bool disabled = _disabled && !loading;
    final Color fill = disabled ? tc.surfaceSecondary : tc.primary;
    final Color foreground = disabled ? tc.textTertiary : tc.onPrimary;
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
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) =>
            GestureDetector(
              onTapDown: disabled
                  ? null
                  : (_) => setState(() => pressed = true),
              onTapUp: disabled
                  ? null
                  : (_) => setState(() => pressed = false),
              onTapCancel: disabled
                  ? null
                  : () => setState(() => pressed = false),
              onTap: disabled
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onPressed!();
                    },
              child: AnimatedScale(
                scale: pressed ? 0.98 : 1,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: Container(
                  height: height,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: child,
                ),
              ),
            ),
      ),
    );
  }
}
