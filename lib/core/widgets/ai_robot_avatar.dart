import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';

/// The ONE robot identity for every AI surface.
///
/// A small, locally stored illustration ([_robotAsset]) drawn beside each
/// assistant turn, inside the thinking indicator and in the welcome hero — so
/// the assistant has the same face everywhere it speaks. The artwork is
/// `assets/images/TOKI AI.png` (transparent background), which the AI chat
/// welcome state already used; this widget makes that single asset the shared
/// identity instead of a one-off.
///
/// While the assistant is thinking or loading, [animate] adds a gentle
/// breathing pulse (a slow scale + a soft ink halo) — quiet motion, no
/// packages. With [animate] false the mark is static, which is what a
/// completed reply uses.
///
/// The mark is intentionally SMALL: it sits beside a message, never above it,
/// and it never grows into a hero. Callers place it at the leading edge of the
/// turn, so RTL is handled by the surrounding row.
class AiRobotAvatar extends StatefulWidget {
  const AiRobotAvatar({super.key, this.size = 32, this.animate = false});

  /// The robot's box. 32 keeps it a quiet sibling of a text line; the welcome
  /// hero passes a larger value.
  final double size;

  /// Whether the breathing pulse is running (thinking / loading).
  final bool animate;

  /// The asset the identity is drawn from.
  static const String assetName = 'assets/images/TOKI AI.png';

  @override
  State<AiRobotAvatar> createState() => _AiRobotAvatarState();
}

class _AiRobotAvatarState extends State<AiRobotAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _breath.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AiRobotAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate) {
      _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      _breath.value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.tokigoColors.brand;
    final Widget mark = _mark(ink);
    if (!widget.animate) {
      return Semantics(
        label: 'TokiGo assistant',
        image: true,
        child: SizedBox(width: widget.size, height: widget.size, child: mark),
      );
    }
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, child) {
        final double t = Curves.easeInOut.transform(_breath.value);
        return Semantics(
          label: 'TokiGo assistant is thinking',
          image: true,
          liveRegion: true,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // A soft ink halo that breathes with the mark — the only motion
                // cue while the assistant is working.
                Container(
                  width: widget.size * (0.92 + 0.14 * t),
                  height: widget.size * (0.92 + 0.14 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ink.withValues(alpha: 0.06 + 0.08 * t),
                  ),
                ),
                Transform.scale(scale: 1.0 + 0.045 * t, child: child),
              ],
            ),
          ),
        );
      },
      child: mark,
    );
  }

  /// The artwork itself, contained so its own proportions are preserved.
  Widget _mark(Color ink) {
    return Image.asset(
      AiRobotAvatar.assetName,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (context, _, _) => Icon(
        Icons.smart_toy_rounded,
        size: widget.size * 0.7,
        color: ink,
      ),
    );
  }
}

/// The standard gap between the robot and the message it belongs to.
const double kAiRobotGap = AppSpacing.sm;
