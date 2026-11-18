import 'package:flutter/material.dart';
import 'package:tokigo/l10n/app_localizations.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/tokigo_gradients.dart';
import 'package:tokigo/core/theme/app_elevation.dart';
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
    final tc = context.tokigoColors;
    final typography = AppTypography.forLight();

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
              _mark(tc, const EdgeInsets.only(bottom: AppSpacing.xl)),
              Text(
                AppLocalizations.of(context)?.aiTravelCopilot ??
                    'Your travel co-pilot',
                textAlign: TextAlign.center,
                style: typography.headline.copyWith(color: tc.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Ask anything about your trip — flights, stays, cars, '
                'or day-to-day travel know-how.',
                textAlign: TextAlign.center,
                style: typography.body.copyWith(color: tc.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: tc.surfaceTertiary,
                  borderRadius: AppRadius.pillBorder,
                ),
                child: Text(
                  'Ready · AI mode',
                  style: typography.label.copyWith(color: tc.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mark(TokiGoColors tc, EdgeInsets padding) {
    return Padding(
      padding: padding,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: TokiGoGradients.brandGradient(),
          boxShadow: AppElevation.shadow(
            background: tc.surface,
            level: AppElevation.sm,
          ),
        ),
        child: Icon(Icons.auto_awesome, size: 40, color: tc.onMedia),
      ),
    );
  }
}
