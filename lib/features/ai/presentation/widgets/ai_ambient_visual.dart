import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    final primary = Theme.of(context).colorScheme.primary;

    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Static radial tint — kept outside the animated layer so the
            // per-frame work stays small and the effect stays cheap.
            _baseTint(primary),
            AnimatedBuilder(
              animation: _t,
              builder: (context, _) {
                final t = _t.value;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final size = math.min(constraints.maxWidth, constraints.maxHeight);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        _haloRing(primary, size, t),
                        _coreGlow(primary, size, t),
                        _satellite(
                          primary,
                          size,
                          t,
                          const Alignment(0.85, -0.42),
                          phase: 0.0,
                        ),
                        _satellite(
                          primary,
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

  Widget _baseTint(Color primary) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 1.2,
          colors: <Color>[
            primary.withValues(alpha: 0.10),
            primary.withValues(alpha: 0.03),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  /// A thin expanding ring that breathes around the core — the "pulse".
  Widget _haloRing(Color primary, double size, double t) {
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
              color: primary.withValues(alpha: 0.07 + 0.05 * t),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  /// Central breathing orb with a soft multiplicative glow.
  Widget _coreGlow(Color primary, double size, double t) {
    final core = size * 0.34 * (1.0 + 0.05 * t);
    return Align(
      alignment: const Alignment(0, -0.45),
      child: Container(
        width: core,
        height: core,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment.center,
            colors: <Color>[
              primary.withValues(alpha: 0.15 + 0.07 * t),
              primary.withValues(alpha: 0.04),
              Colors.transparent,
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: primary.withValues(alpha: 0.09 + 0.07 * t),
              blurRadius: 110,
              spreadRadius: 6,
            ),
          ],
        ),
      ),
    );
  }

  /// Small, slow orbs drifting in [phase]-offset counterpoint to the breath.
  Widget _satellite(
    Color primary,
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
            color: primary.withValues(alpha: 0.06 + 0.10 * fade),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: primary.withValues(alpha: 0.12 * fade),
                blurRadius: d,
              ),
            ],
          ),
        ),
      ),
    );
  }
}