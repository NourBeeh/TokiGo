import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';

import 'package:tokigo/core/theme/app_motion.dart';

/// Calm, living ambient background for the AI surface.
///
/// A single breathing [AnimationController] drives a soft radial tint, a
/// gently pulsing core glow, a slow halo ring and two faint satellite orbs.
/// Pure decoration — non-interactive and built exclusively from the existing
/// design tokens ([AppMotion]); no added packages or AI logic.
class AiAmbientVisual extends StatefulWidget {
  const AiAmbientVisual({super.key});

  @override
  State<AiAmbientVisual> createState() => _AiAmbientVisualState();
}

class _AiAmbientVisualState extends State<AiAmbientVisual>
    with SingleTickerProviderStateMixin {
  /// Calm ~2.5s breath cycle derived from the slowest motion token
  /// (slow = 420ms), keeping the ambient feel premium and unobtrusive.
  late final AnimationController _breath;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: AppMotion.slow.inMilliseconds * 6),
    )..repeat(reverse: true);
    _t = CurvedAnimation(parent: _breath, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tokigoColors;
    final Color ink = tc.brand;

    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Static tint — kept outside the animated layer so the per-frame
            // work stays small and the effect stays cheap.
            _baseTint(ink),
            AnimatedBuilder(
              animation: _t,
              builder: (context, _) {
                final t = _t.value;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final size = math.min(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        _haloRing(ink, size, t),
                        _coreGlow(ink, size, t),
                        _satellite(
                          ink,
                          size,
                          t,
                          const Alignment(0.85, -0.42),
                          phase: 0.0,
                        ),
                        _satellite(
                          ink,
                          size,
                          t,
                          const Alignment(-0.92, 0.28),
                          phase: 0.5,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _baseTint(Color ink) {
    return DecoratedBox(
      decoration: BoxDecoration(color: ink.withValues(alpha: 0.03)),
    );
  }

  /// A thin expanding ring that breathes around the core — the "pulse".
  Widget _haloRing(Color ink, double size, double t) {
    final halo = math.max(size * 0.62, 240.0);
    return Align(
      alignment: const Alignment(0, -0.45),
      child: Transform.scale(
        scale: 1.0 + 0.08 * t,
        child: Container(
          width: halo,
          height: halo,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ink.withValues(alpha: 0.05 + 0.03 * t),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  /// Central breathing orb — a flat ink wash, no blur glow.
  Widget _coreGlow(Color ink, double size, double t) {
    final core = size * 0.34 * (1.0 + 0.05 * t);
    return Align(
      alignment: const Alignment(0, -0.45),
      child: Container(
        width: core,
        height: core,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ink.withValues(alpha: 0.05 + 0.03 * t),
        ),
      ),
    );
  }

  /// Small, slow orbs drifting in [phase]-offset counterpoint to the breath.
  Widget _satellite(
    Color ink,
    double size,
    double t,
    Alignment alignment, {
    required double phase,
  }) {
    final p = (t + phase) % 1.0;
    final d = math.max(math.min(size * 0.045, 34.0), 12.0);
    final fade = 1.0 - p;
    return Align(
      alignment: alignment,
      child: Opacity(
        opacity: 0.18 + 0.28 * fade,
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ink.withValues(alpha: 0.05 + 0.08 * fade),
          ),
        ),
      ),
    );
  }
}
