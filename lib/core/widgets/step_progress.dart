import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';

/// Horizontal step progress indicator for multi-step flows
/// (booking: details → add-ons → payment).
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < total; i++) ...<Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 4,
            width: i == current ? 28 : 12,
            decoration: BoxDecoration(
              color: i <= current ? AppColors.brand : AppColors.surfaceTertiary,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          if (i < total - 1) const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Status chip with container tint — used across booking states, trip item
/// lifecycles and group roles.
class StatusChip extends StatelessWidget {
  StatusChip({
    super.key,
    required this.label,
    required this.color,
    Color? container,
  }) : container = container ?? color.withValues(alpha: 0.1);

  final String label;
  final Color color;
  final Color container;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: typography.captionSemibold.copyWith(color: color, height: 1.4),
      ),
    );
  }
}
