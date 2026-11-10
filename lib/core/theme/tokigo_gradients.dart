import 'package:flutter/material.dart';

/// Centralized Instagram-inspired gradient accents.
///
/// The palette direction is Instagram's recognizable visual language: a
/// signature purple → magenta → orange ramp used for SMALL accents only
/// (the AI composer's send action, the "Ask your assistant" entry, the brand
/// mark). Everything else stays on the neutral [TokiGoColors] surfaces so the
/// gradients never take over a screen.
///
/// The stops are shared by both themes — a gradient is a hue, not a surface,
/// and the same ramp reads correctly on the light and the dark canvas.
@immutable
abstract final class TokiGoGradients {
  /// The signature Instagram ramp: purple → red/magenta → orange.
  static const List<Color> brand = <Color>[
    Color(0xFF833AB4),
    Color(0xFFFD1D1D),
    Color(0xFFFCB045),
  ];

  /// A tighter five-stop ramp for small rounded surfaces (pills, buttons).
  static const List<Color> brandSmooth = <Color>[
    Color(0xFF5851DB),
    Color(0xFF833AB4),
    Color(0xFFC13584),
    Color(0xFFE1306C),
    Color(0xFFFD1D1D),
    Color(0xFFF56040),
    Color(0xFFF77737),
    Color(0xFFFCAF45),
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
