import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';

/// The AI surface's content area (above the prompt input).
///
/// Currently a quiet, premium empty state. Real AI responses will stream into
/// this slot in a later phase. Kept intentionally minimal — no logic inside.
class AiEmptyState extends StatelessWidget {
  const AiEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _mark(
                scheme,
                const EdgeInsets.only(bottom: AppSpacing.xl),
              ),
              Text(
                'Your travel co-pilot',
                textAlign: TextAlign.center,
                style: typography.headline.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Ask anything about your trip — flights, stays, cars, '
                'or day-to-day travel know-how.',
                textAlign: TextAlign.center,
                style: typography.body.copyWith(
                  color: typography.textMutedColor,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: AppRadius.pillBorder,
                ),
                child: Text(
                  'Ready · AI mode',
                  style: typography.label.copyWith(
                    color: typography.textMutedColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mark(ColorScheme scheme, EdgeInsets padding) {
    return Padding(
      padding: padding,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.ai, AppColors.aiLight],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.ai.withValues(alpha: 0.28),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Icon(Icons.auto_awesome, size: 40, color: scheme.onPrimary),
      ),
    );
  }
}