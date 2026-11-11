import 'package:flutter/material.dart';

/// Centralized neutral accent ramps.
///
/// **Owner decision (2026-11): the blue brand accent is retired.** The former
/// Instagram purple → red → orange ramp carried a hue, so it is replaced by a
/// neutral ink ramp: the same shape of gradient (a quiet dark-to-light step) with
/// no colour, used for SMALL accents only — the AI assistant's identity mark and
/// the "Ask your assistant" entry.
///
/// The stops are shared by both themes — a ramp is a VALUE step, not a surface,
/// and the same neutral ramp reads correctly on the light and the dark canvas.
@immutable
abstract final class TokiGoGradients {
  /// The signature ramp: near-black → mid ink. Neutral, never a hue.
  static const List<Color> brand = <Color>[
    Color(0xFF262626),
    Color(0xFF5A5A5A),
    Color(0xFF8E8E8E),
  ];

  /// A tighter multi-stop ramp for small rounded surfaces (pills, buttons).
  static const List<Color> brandSmooth = <Color>[
    Color(0xFF111111),
    Color(0xFF262626),
    Color(0xFF3A3A3A),
    Color(0xFF4F4F4F),
    Color(0xFF666666),
    Color(0xFF7D7D7D),
    Color(0xFF949494),
    Color(0xFFA8A8A8),
  ];

  /// The brand ramp as a left-to-right gradient (RTL-aware callers flip it).
  static LinearGradient brandGradient({
    AlignmentGeometry begin = AlignmentDirectional.centerStart,
    AlignmentGeometry end = AlignmentDirectional.centerEnd,
  }) {
    return LinearGradient(colors: brand, begin: begin, end: end);
  }

  /// The smooth ramp as a left-to-right gradient.
  static LinearGradient brandSmoothGradient({
    AlignmentGeometry begin = AlignmentDirectional.centerStart,
    AlignmentGeometry end = AlignmentDirectional.centerEnd,
  }) {
    return LinearGradient(colors: brandSmooth, begin: begin, end: end);
  }

  /// A 1px gradient border painter for the "Ask your assistant" entry.
  static BoxDecoration outlineGradientBox({
    required double width,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(16)),
  }) {
    return BoxDecoration(
      gradient: brandGradient(),
      borderRadius: borderRadius,
      border: Border.all(width: width, color: Colors.transparent),
    );
  }
}
