import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_motion.dart';

/// Physical starting offset for a full-screen horizontal page push.
///
/// The page enters from the **trailing** edge — the right in LTR, the left in
/// RTL — and leaves back through that same edge, so forward and reverse
/// navigation are exact mirror images. The vertical component is always zero:
/// page transitions never move up/down or diagonally.
Offset horizontalPageEnterOffset(BuildContext context) {
  return Directionality.of(context) == TextDirection.rtl
      ? const Offset(-1, 0)
      : const Offset(1, 0);
}

/// The shared, strictly-horizontal page transition used by every layout.
///
/// - [animation] drives this page: it starts one full screen off the trailing
///   edge and settles at `Offset.zero`.
/// - [secondaryAnimation] drives the page *underneath* while a new page covers
///   it: it moves a third of the way in the opposite direction, matching the
///   native Cupertino parallax.
///
/// Both animations only ever change `dx`; `dy` stays `0`.
class HorizontalPageTransition extends StatelessWidget {
  const HorizontalPageTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  /// Cupertino's parallax distance for the covered page (one third of the
  /// screen). Kept identical so push/pop feel native on every platform.
  static const double _coveredPageParallax = 1 / 3;

  @override
  Widget build(BuildContext context) {
    final Offset enter = horizontalPageEnterOffset(context);
    final Offset covered = Offset(-enter.dx * _coveredPageParallax, 0);

    final Animation<Offset> primaryPosition = Tween<Offset>(
      begin: enter,
      end: Offset.zero,
    ).chain(CurveTween(curve: AppMotion.pageCurve)).animate(animation);

    final Animation<Offset> secondaryPosition = Tween<Offset>(
      begin: Offset.zero,
      end: covered,
    ).chain(CurveTween(curve: AppMotion.pageCurve)).animate(secondaryAnimation);

    return SlideTransition(
      position: secondaryPosition,
      transformHitTests: false,
      child: SlideTransition(
        position: primaryPosition,
        transformHitTests: false,
        child: child,
      ),
    );
  }
}

/// The FADE-THROUGH transition — a cross-dissolve with a subtle scale.
///
/// Kept for backwards compatibility (and non-page surfaces that want a quiet
/// dissolve). Full-screen routes use [slideFromRightPage], which is strictly
/// horizontal and therefore never zooms or grows from a corner.
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
           return FadeThroughBuilder(animation: curved, child: child);
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
  LocalKey? key,
  Object? arguments,
  String? name,
  String? restorationId,
}) {
  return FadeThroughTransition(
    key: key,
    child: child,
    arguments: arguments,
    name: name,
    restorationId: restorationId,
  );
}

/// App's push/pop route for iOS: a Cupertino route that includes the native
/// interactive back-gesture detector.
///
/// [CupertinoPageTransitionsBuilder] is used for the visual transition. It
/// wraps the child in `_CupertinoBackGestureDetector`, which handles the
/// edge-swipe back gesture and animates the route in the direction of the
/// user's finger, including cancellation and completion.
class CupertinoSlideFromRightRoute extends CupertinoPageRoute<void> {
  CupertinoSlideFromRightRoute({
    required super.builder,
    super.title,
    super.settings,
    super.requestFocus,
    super.maintainState,
    super.fullscreenDialog,
    super.allowSnapshotting,
    super.barrierDismissible,
  });
}

/// App's push/pop page for iOS: a native [CupertinoPage] that keeps the
/// interactive edge-swipe and the directional horizontal transition.
class CupertinoSlideFromRightPage extends CupertinoPage<void> {
  const CupertinoSlideFromRightPage({
    required super.child,
    super.maintainState,
    super.title,
    super.fullscreenDialog,
    super.allowSnapshotting,
    super.canPop,
    super.onPopInvoked,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  @override
  Route<void> createRoute(BuildContext context) {
    // `settings: this` is REQUIRED, not decorative:
    //
    // * GoRouter's `_handlePopPage` reads `route.settings as Page` to find the
    //   matching route, and `Navigator._updatePages` / `_RouteEntry` assert
    //   that a page-based route's settings are the originating Page.
    // * Without it, the native iOS back-swipe throws when the drag completes
    //   (`navigator.pop()` runs inside the gesture callback), leaving the
    //   route stuck mid-flight — the "frozen" back gesture.
    //
    // Passing the page also preserves its name, arguments, restorationId,
    // fullscreenDialog and canPop/onPopInvoked semantics.
    return CupertinoSlideFromRightRoute(
      settings: this,
      builder: (context) => child,
      maintainState: maintainState,
      title: title,
      fullscreenDialog: fullscreenDialog,
      allowSnapshotting: allowSnapshotting,
    );
  }
}

/// App's push/pop transition for non-iOS platforms.
///
/// This is a valid, strictly-horizontal fallback (never throws) for callers
/// that explicitly want a [CustomTransitionPage]. Prefer [slideFromRightPage]:
/// on Android it returns a [MaterialPage] so `PredictiveBackPageTransitionsBuilder`
/// can drive the route animation from the system back gesture.
class SlideFromRightTransition extends CustomTransitionPage<void> {
  SlideFromRightTransition({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    Duration duration = AppMotion.page,
  }) : super(
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           // Reduced motion: no travel at all, just a quiet dissolve.
           if (MediaQuery.disableAnimationsOf(context)) {
             return FadeTransition(opacity: animation, child: child);
           }
           return HorizontalPageTransition(
             animation: animation,
             secondaryAnimation: secondaryAnimation,
             child: child,
           );
         },
       );
}

/// Convenience wrapper: wraps [child] with the app's full-screen horizontal
/// page transition for go-router page builders.
///
/// - iOS: [CupertinoSlideFromRightPage] → native interactive back-swipe.
/// - Android: [MaterialPage] → `PageTransitionsTheme` with
///   `PredictiveBackPageTransitionsBuilder`, so system back/predictive back
///   owns the gesture.
/// - Other platforms: [MaterialPage] → the horizontal builder from the theme.
///
/// [key] must be unique per page instance (pass `state.pageKey` from
/// GoRouter). Reusing a constant key makes the Navigator treat different
/// destinations as the same page and corrupts the route stack.
Page<void> slideFromRightPage({
  required Widget child,
  LocalKey? key,
  Object? arguments,
  String? name,
  String? restorationId,
}) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return CupertinoSlideFromRightPage(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      child: child,
    );
  }
  // MaterialPage deliberately keeps the framework's route type so that
  // Android's PredictiveBackPageTransitionsBuilder can attach its gesture
  // detector and drive the transition from the system back gesture.
  return MaterialPage<void>(
    key: key,
    name: name,
    arguments: arguments,
    restorationId: restorationId,
    child: child,
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
           return _ContainerTransformBuilder(animation: curved, body: child);
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
        final rawScrim = isReversing
            ? t / _scrimCompleteAt
            : 1 - (t / _scrimCompleteAt);
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
              child: Opacity(opacity: revealT, child: body),
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
  LocalKey? key,
  Object? arguments,
  String? name,
  String? restorationId,
}) {
  return ContainerTransformTransition(
    key: key,
    child: child,
    arguments: arguments,
    name: name,
    restorationId: restorationId,
  );
}

/// [PageTransitionsBuilder] for platforms that use `MaterialPage` but do not
/// have a system-owned back gesture (macOS / Windows / Linux / Fuchsia).
///
/// Applies the same strictly-horizontal, RTL-aware slide as
/// [HorizontalPageTransition]. Android must NOT use this builder: it needs
/// [PredictiveBackPageTransitionsBuilder] so the route follows the system
/// back gesture.
class SlideFromRightPageTransitionsBuilder extends PageTransitionsBuilder {
  const SlideFromRightPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Duration get reverseTransitionDuration => AppMotion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Reduced motion: quiet dissolve, never a corner/zoom entrance.
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: child);
    }

    return HorizontalPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}
