import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/ai/application/ai_providers.dart';
import 'package:tokigo/features/ai/application/ai_state.dart';
import 'package:tokigo/features/home/presentation/widgets/home_section.dart';

import 'ai_empty_state.dart';

/// Renders the AI controller state on the AI surface.
///
/// Pure presentation: watches [aiControllerProvider] and shows the empty state
/// (idle), a brief loading indicator, an error with retry, or the mapped
/// response rendered through the existing [HomeSectionWidget] cards.
class AiResponseContent extends ConsumerWidget {
  const AiResponseContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiControllerProvider);
    return switch (state.status) {
      AiStatus.idle => const AiEmptyState(),
      AiStatus.empty => const AiEmptyState(),
      AiStatus.loading => const _AiLoadingState(),
      AiStatus.error => _AiErrorState(
          message: state.errorMessage ?? 'Something went wrong.',
          onRetry: state.currentPrompt.isEmpty
              ? null
              : () => ref.read(aiControllerProvider.notifier).retry(),
        ),
      AiStatus.success => _AiSuccessContent(state: state),
    };
  }
}

/// Calm loading indicator shown while the response is being generated.
class _AiLoadingState extends StatelessWidget {
  const _AiLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

/// Error message with an optional retry that re-runs the last prompt.
class _AiErrorState extends StatelessWidget {
  const _AiErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: typography.body.copyWith(color: typography.textMutedColor),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

/// The successful response: intro bubble + mapped home sections.
class _AiSuccessContent extends StatelessWidget {
  const _AiSuccessContent({required this.state});

  final AiState state;

  @override
  Widget build(BuildContext context) {
    final text = state.responseText;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      children: <Widget>[
        if (text != null && text.isNotEmpty) _AiResponseBubble(text: text),
        for (final section in state.sections)
          HomeSectionWidget(section: section),
      ],
    );
  }
}

/// Assistant message bubble — AI-first identity, built from design tokens.
class _AiResponseBubble extends StatelessWidget {
  const _AiResponseBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final typography = AppTypography.forLight();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[AppColors.ai, AppColors.aiLight],
              ),
            ),
            child: Icon(Icons.auto_awesome, size: 14, color: scheme.onPrimary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.sm),
                  topRight: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.lg),
                  bottomRight: Radius.circular(AppRadius.lg),
                ),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Text(
                text,
                style: typography.bodyMedium.copyWith(color: scheme.onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}