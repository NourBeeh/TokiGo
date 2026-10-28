import 'package:flutter/material.dart';

/// Responsive breakpoints (logical widths) used for adaptive layout.
@immutable
abstract final class AppBreakpoints {
  static const double compact = 480;
  static const double medium = 840;
  static const double expanded = 1200;

  static bool isCompact(BoxConstraints constraints) =>
      constraints.maxWidth < compact;
  static bool isMedium(BoxConstraints constraints) =>
      constraints.maxWidth >= compact && constraints.maxWidth < medium;
  static bool isExpanded(BoxConstraints constraints) =>
      constraints.maxWidth >= expanded;

  /// Optional: a cross-axis convenience for [MediaQueryData].
  static double widthOf(MediaQueryData mq) => mq.size.width;
}
