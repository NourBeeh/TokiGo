import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
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
      child: GestureDetector(
        onTap: _disabled ? null : onPressed,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [AppColors.brand, AppColors.brand],
            ),
            borderRadius: AppRadius.pillBorder,
          ),
          child: child,
        ),
      ),
    );
  }
}
