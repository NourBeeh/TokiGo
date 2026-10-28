import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';

/// Shared section header with optional trailing "View all" action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.titleStyle,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Overrides the section title's size/weight. A section whose title is a
  /// long sentence (Home's stay rail) asks for the smaller step so the heading
  /// stays one line and does not compete with the cards under it.
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              // At a 200% text scale a long heading would grow to four lines
              // and push the whole feed down; two lines with an ellipsis keep
              // the block a header.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (titleStyle ?? typography.title).copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  actionLabel!,
                  style: typography.captionSemibold.copyWith(
                    color: AppColors.brand,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
