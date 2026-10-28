import 'package:flutter/material.dart';

/// The AI page entrance animation — a subtle scale+fade that plays once on
/// mount. Extracted from the AI chat page so every pushed page can share the
/// same content entrance flourish.
///
/// The route transition itself stays native so iOS edge-swipe-back keeps
/// working; this only animates the CONTENT inside the page.
class AiEntranceAnimation extends StatelessWidget {
  const AiEntranceAnimation({super.key, required this.child});

  final Widget child;

  /// One shared tween instance for every build.
  ///
  /// [TweenAnimationBuilder] compares the tween by IDENTITY
  /// (`widget.tween != oldWidget.tween`), and [Tween] does not override `==` —
  /// so a tween built inside `build` is a new object on every rebuild. Keeping
  /// one instance here means the builder never sees a "changed" tween, so the
  /// flourish plays once on mount and is never re-armed by a rebuild.
  static final Tween<double> _tween = Tween<double>(begin: 0, end: 1);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: _tween,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.scale(
          scale: 0.92 + 0.08 * v,
          alignment: Alignment.bottomRight,
          child: child,
        ),
      ),
      child: child,
    );
  }
}
