import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_motion.dart';

/// The unified page-transition language of the app ("fade-through").
///
/// - Push: outgoing page fades + scales down to 96%; incoming page fades in
///   and scales up from 92% with the standard ease-out curve.
/// - Pop: the mirrored sequence.
///
/// Every route in the app uses this single transition so navigation feels
/// like one continuous premium surface.
class FadeThroughTransition extends CustomTransitionPage<void> {
  FadeThroughTransition({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    Duration duration = AppMotion.normal,
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: AppMotion.standard,
              reverseCurve: AppMotion.exit,
            );
            return FadeThroughBuilder(
              animation: curved,
              child: child,
            );
          },
        );
}

/// Core fade-through builder shared by [FadeThroughTransition] and any
/// custom usages (dialogs, sheets, hero surfaces).
class FadeThroughBuilder extends StatelessWidget {
  const FadeThroughBuilder({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  static const double _incomingScaleFrom = 0.92;
  static const double _outgoingScaleTo = 0.96;
  static const double _incomingFadePeak = 0.4;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // Phase 1 (0 -> 0.4): outgoing content fades to invisible while
        // scaling down. Phase 2 (0.4 -> 1): incoming content fades in while
        // scaling up from 92%. This mirrors the Material fade-through spec.
        final t = animation.value;
        if (t <= _incomingFadePeak) {
          final phase = t / _incomingFadePeak;
          return Opacity(
            opacity: 1 - phase,
            child: Transform.scale(
              scale: 1 - (1 - _outgoingScaleTo) * phase,
              child: child,
            ),
          );
        }
        final phase = (t - _incomingFadePeak) / (1 - _incomingFadePeak);
        return Opacity(
          opacity: phase,
          child: Transform.scale(
            scale: _incomingScaleFrom + (1 - _incomingScaleFrom) * phase,
            child: child,
          ),
        );
      },
    );
  }
}

/// Convenience wrapper: wraps [child] with the unified fade-through
/// transition for go-router page builders.
CustomTransitionPage<void> fadeThroughPage({
  required Widget child,
  Object? arguments,
  String? name,
}) {
  return FadeThroughTransition(
    child: child,
    arguments: arguments,
    name: name,
  );
}

/// The container-transform page transition (Material 3 / iOS style).
///
/// Used by the smart-search surface: a [Hero] flight morphs the Home pill
/// into the page header, while this transition layer supplies the two
/// remaining ingredients of the spec —
///
/// - **Scrim:** a stark-white veil fading in over the outgoing page for
///   the first 30% of the flight, so the old content reads as "receding"
///   behind the rising container.
/// - **Content reveal:** the page body (suggestions / results) fades in
///   with a quiet upward slide, starting at 25% of the flight so it
///   follows the container once it has settled at the top.
///
/// The header itself is NOT wrapped: it hosts the hero's destination and
/// must be visible from t = 0.
class ContainerTransformTransition extends CustomTransitionPage<void> {
  ContainerTransformTransition({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    Duration duration = const Duration(milliseconds: 320),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: AppMotion.standard,
              reverseCurve: AppMotion.exit,
            );
            return _ContainerTransformBuilder(
              animation: curved,
              body: child,
            );
          },
        );
}

/// Builds the scrim + content-reveal choreography for
/// [ContainerTransformTransition].
class _ContainerTransformBuilder extends StatelessWidget {
  const _ContainerTransformBuilder({
    required this.animation,
    required this.body,
  });

  final Animation<double> animation;
  final Widget body;

  /// Scrim keeps dissolving until this fraction of the flight — aligned
  /// with most of the hero's travel so there is never a "dead" stretch
  /// where nothing on screen moves.
  static const double _scrimCompleteAt = 0.65;

  /// Content reveal starts once the capsule has visually settled, so the
  /// body genuinely follows the container instead of racing it.
  static const double _revealFrom = 0.40;

  /// Upward offset (logical px) the content slides in from.
  static const double _revealSlide = 16;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;

        // Scrim opacity inverts with the flight direction: on push the
        // veil starts opaque (the old page hidden) and dissolves as the
        // new page rises; on pop it is mirrored — the white returns to
        // cover the receding content. Either way one continuous dissolve,
        // never a dead stretch.
        final isReversing = animation.status == AnimationStatus.reverse;
        final rawScrim =
            isReversing ? t / _scrimCompleteAt : 1 - (t / _scrimCompleteAt);
        final scrimT = rawScrim.clamp(0.0, 1.0).toDouble();

        // Content reveal: fade + gentle slide-up, gated behind _revealFrom.
        final revealT = ((t - _revealFrom) / (1 - _revealFrom))
            .clamp(0.0, 1.0)
            .toDouble();

        return Stack(
          children: <Widget>[
            // The incoming page itself, always laid out beneath the scrim.
            Transform.translate(
              offset: Offset(0, _revealSlide * (1 - revealT)),
              child: Opacity(
                opacity: revealT,
                child: body,
              ),
            ),
            // Scrim veil over everything while the old page recedes. The
            // pure-white identity keeps the transformation airy instead of
            // heavy — the same reason the app is light-only. Alive for the
            // whole dissolve window in BOTH directions; pointer-transparent.
            if (scrimT < 1.0)
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: scrimT),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Convenience wrapper: wraps [child] with the container-transform
/// transition for go-router page builders.
CustomTransitionPage<void> containerTransformPage({
  required Widget child,
  Object? arguments,
  String? name,
}) {
  return ContainerTransformTransition(
    child: child,
    arguments: arguments,
    name: name,
  );
}
