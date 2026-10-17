import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/ai/presentation/widgets/ai_ambient_visual.dart';
import 'package:tokigo/features/ai/presentation/widgets/ai_mode_indicator.dart';
import 'package:tokigo/features/ai/presentation/widgets/ai_prompt_input.dart';
import 'package:tokigo/features/ai/presentation/widgets/ai_response_content.dart';

/// The living AI surface shown when the app is in AI mode (AppMode.ai).
///
/// Composes the ambient background, a mocked AI response rendered through the
/// existing HomeCard engine, and the bottom prompt input. Pure presentation —
/// no controllers or business logic. Designed so a single circular mode toggle
/// can mount into the header right side in a later phase without layout rework.
class AiVisualShellPage extends StatelessWidget {
  const AiVisualShellPage({super.key});

  /// Comfortable column width for larger (tablet/desktop) canvases.
  static const double _contentMaxWidth = 720;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const AiAmbientVisual(),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: Column(
                  children: const <Widget>[
                    _AiHeader(),
                    Expanded(child: AiResponseContent()),
                    AiPromptInput(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top bar: brand identity on the left, reserved circular toggle slot right.
class _AiHeader extends StatelessWidget {
  const _AiHeader();

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: AppRadius.mdBorder,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(Icons.travel_explore, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'TokiGo',
                  style: typography.bodyLargeMedium.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  'AI Assistant',
                  style: typography.label.copyWith(
                    color: typography.textMutedColor,
                  ),
                ),
              ],
            ),
          ),
          const AiModeIndicator(),
        ],
      ),
    );
  }
}