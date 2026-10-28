import 'package:flutter/material.dart';

/// Corner radius scale for an Apple-quality, softly curved UI.
@immutable
abstract final class AppRadius {
  static const double none = 0;
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;

  static BorderRadius xsBorder = BorderRadius.circular(xs);
  static BorderRadius smBorder = BorderRadius.circular(sm);
  static BorderRadius mdBorder = BorderRadius.circular(md);
  static BorderRadius lgBorder = BorderRadius.circular(lg);
  static BorderRadius xlBorder = BorderRadius.circular(xl);
  static BorderRadius pillBorder = BorderRadius.circular(pill);
}
