import 'package:flutter/material.dart';

/// Unified press feedback for any tappable widget.
///
/// Wraps [child] with a subtle scale + opacity on press, matching the style
/// used by [HomeNavButtons]. Use this instead of ad-hoc AnimatedScale or
/// InkWell ripples so every button feels identical.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.scale = 0.96,
    this.duration = const Duration(milliseconds: 120),
  }) : wrap = false,
       enabled = true;

  /// Adds press feedback to a child that handles its own taps (a Material
  /// button, [InkWell], [GestureDetector]…).
  ///
  /// Unlike the default constructor this uses a [Listener], so it never enters
  /// the gesture arena and never steals the tap from the child. It only observes
  /// the pointer to drive the scale — the child keeps its own `onTap`.
  const Pressable.wrap({
    super.key,
    required this.child,
    this.scale = 0.96,
    this.duration = const Duration(milliseconds: 120),
    this.enabled = true,
  }) : onTap = null,
       wrap = true;

  final VoidCallback? onTap;
  final Widget child;
  final double scale;
  final Duration duration;

  /// When true the widget only observes pointers; the child owns the gesture.
  final bool wrap;

  /// Whether press feedback is shown. Set false for a disabled child so it
  /// does not react to taps it will not handle.
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  bool get _canPress =>
      widget.enabled && (widget.wrap || widget.onTap != null);

  void _setPressed(bool value) {
    if (!_canPress || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final Widget animated = AnimatedScale(
      scale: _pressed ? widget.scale : 1.0,
      duration: widget.duration,
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.85 : 1.0,
        duration: widget.duration,
        child: widget.child,
      ),
    );

    if (widget.wrap) {
      return Listener(
        onPointerDown: _canPress ? (_) => _setPressed(true) : null,
        onPointerUp: _canPress ? (_) => _setPressed(false) : null,
        onPointerCancel: _canPress ? (_) => _setPressed(false) : null,
        behavior: HitTestBehavior.translucent,
        child: animated,
      );
    }

    return GestureDetector(
      onTapDown: _canPress ? (_) => _setPressed(true) : null,
      onTapUp: _canPress ? (_) => _setPressed(false) : null,
      onTapCancel: _canPress ? () => _setPressed(false) : null,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: animated,
    );
  }
}
