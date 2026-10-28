import 'package:flutter/material.dart';

/// Compatibility wrapper retained for existing route declarations.
///
/// Owner decision (2026-10-22): TokiGo does **not** implement its own
/// edge-swipe navigation. iOS keeps its native interactive back gesture and
/// Android keeps system back, so the gesture matches the platform the user
/// already knows. Pushed pages keep their visible, localized back control and
/// must never intercept system back.
///
/// The wrapper therefore adds nothing: it renders [child] unchanged. Do not
/// reintroduce a drag recognizer here (or anywhere else) — see `AGENTS.md`
/// § Navigation and page exits and `PROJECT_MEMORY/06_DECISIONS.md`.
class SwipeFromRightToPop extends StatelessWidget {
  const SwipeFromRightToPop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
