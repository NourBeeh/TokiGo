import 'package:flutter/material.dart';

/// Shared shimmer skeleton box used by loading-state cards.
///
/// A self-animating placeholder that pulses its opacity between faint and
/// solid, mimicking the classic shimmer effect without an external package.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.alignment,
    this.padding,
    this.child,
  });

  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;

  /// Aligns [child] within the box when a size is constrained.
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.4,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          alignment: widget.alignment,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(
              alpha: _animation.value,
            ),
            borderRadius: widget.borderRadius,
          ),
          child: widget.child,
        );
      },
    );
  }
}
