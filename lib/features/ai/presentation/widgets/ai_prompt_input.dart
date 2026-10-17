import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/theme/app_elevation.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_motion.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/ai/application/ai_providers.dart';

/// Bottom prompt input for the AI surface.
///
/// A multiline [TextField] with keyboard-friendly behaviour (send action on
/// submit, capped growth) and a single circular send button. Submission is
/// wired straight into the AI controller — no network happens here.
class AiPromptInput extends ConsumerStatefulWidget {
  const AiPromptInput({super.key});

  @override
  ConsumerState<AiPromptInput> createState() => _AiPromptInputState();
}

class _AiPromptInputState extends ConsumerState<AiPromptInput> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() => _hasText = _controller.text.trim().isNotEmpty);
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    // Prompt submission goes through the AI controller (Phase 6 flow).
    ref.read(aiControllerProvider.notifier).submit(text);
    // Clear the field and keep focus so the user can continue asking.
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final typography = AppTypography.forLight();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.86),
          borderRadius: AppRadius.lgBorder,
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: AppElevation.shadow(
            background: scheme.surface,
            level: AppElevation.lg,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                style: typography.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Ask anything about your trip...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            _SendButton(enabled: _hasText, onTap: _submit),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Send prompt',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? null : scheme.surfaceContainerHighest,
              gradient: enabled
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[AppColors.ai, AppColors.aiLight],
                    )
                  : null,
            ),
            child: Icon(
              Icons.arrow_upward,
              size: 22,
              color: enabled
                  ? scheme.onPrimary
                  : scheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}