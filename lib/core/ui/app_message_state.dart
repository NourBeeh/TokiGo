import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';

/// The ONE honest-state recipe (empty / idle / no-data / error).
///
/// OWNER DECISION (2026-10-18/19): when data is missing the app says so —
/// a tinted icon disc, a `title`, a centred `body` and an optional action —
/// and it NEVER invents content to fill the gap (no fake photograph, no fake
/// price). This widget was extracted from the search verticals' state view so
/// Home and every other surface render the exact same thing instead of each
/// hand-rolling a bare `Text` + `FilledButton`.
///
/// The hue carries the meaning: [AppColors.brand] for "nothing here yet",
/// [AppColors.danger] for a failure.
class AppMessageState extends StatelessWidget {
  const AppMessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.hue = AppColors.brand,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;

  /// Tint for the icon disc — brand by default, danger for an error.
  final Color hue;

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxxl,
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: hue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: hue),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: typography.title.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: typography.body.copyWith(color: AppColors.textSecondary),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: actionLabel!,
              type: AppButtonType.secondary,
              expanded: false,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
