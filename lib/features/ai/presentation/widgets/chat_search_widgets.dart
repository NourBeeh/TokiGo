import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/universal_search/application/voice_search_state.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The chat surface's microphone affordance — a bare red mic at rest,
/// recording red with a gentle pulse while listening, a quiet wait while
/// starting. Fully semantic (microphone / listening state / stop-cancel
/// labels).
class VoiceMicButton extends StatelessWidget {
  const VoiceMicButton({super.key, required this.state, required this.onTap});

  final VoiceSearchState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isListening = state.status == VoiceSearchStatus.listening;
    final isStarting = state.status == VoiceSearchStatus.starting;

    final icon = isListening
        ? Icons.stop_circle_rounded
        : isStarting
        ? Icons.mic_none_rounded
        : Icons.mic_rounded;
    // The brand mic is red in every restful state; listening keeps the same
    // warm red so only the icon + pulse communicate the state change.
    final color = isListening ? scheme.error : AppColors.brandRed;

    return Semantics(
      button: true,
      enabled: true,
      label: isListening
          ? l10n.voiceStop
          : isStarting
          ? l10n.voiceStarting
          : l10n.voiceSearch,
      child: SizedBox(
        width: AppSpacing.minimumTapTarget,
        height: AppSpacing.minimumTapTarget,
        child: InkResponse(
          customBorder: const CircleBorder(),
          radius: 24,
          onTap: onTap,
          child: Center(
            child: _MicPulse(
              listening: isListening,
              child: Icon(icon, size: 24, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// A gentle breathing halo while listening — quiet motion, no packages.
class _MicPulse extends StatefulWidget {
  const _MicPulse({required this.listening, required this.child});

  final bool listening;
  final Widget child;

  @override
  State<_MicPulse> createState() => _MicPulseState();
}

class _MicPulseState extends State<_MicPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.listening) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _MicPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening && !oldWidget.listening) {
      _controller.repeat(reverse: true);
    } else if (!widget.listening && oldWidget.listening) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.listening) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + 0.18 * _controller.value;
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}

/// The inline voice-failure surface — explained in place, never a modal
/// interrupt, with a dismiss affordance. Announced as a live region.
class VoiceFailureBanner extends StatelessWidget {
  const VoiceFailureBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline_rounded, size: 18, color: scheme.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: typography.caption.copyWith(color: scheme.error),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
