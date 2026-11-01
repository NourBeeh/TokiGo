import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_typography.dart';

/// Decorates one half of the wordmark (index 0 = "Toki", 1 = "Go").
///
/// Home uses it to animate its two halves independently; a static surface can
/// simply ignore it.
typedef WordmarkPartBuilder =
    Widget Function(BuildContext context, int index, Widget child);

/// The TokiGo logotype — the ONE place the brand mark is built.
///
/// A brand mark is a fixed shape, not a phrase: it must read "TokiGo" with the
/// same letterforms on every surface, in every locale, at every size. So this
/// widget owns the whole spec and a caller only chooses the *size* it is drawn
/// at:
///
///  * **Direction** is pinned to LTR. In an Arabic (RTL) layout a plain [Row]
///    mirrors the halves into "GoToki" — a different word, not a translation.
///  * **Family and weight** are always Manrope ExtraBold. An Arabic session
///    renders copy in Cairo, but the logotype is not copy: the mark keeps its
///    Latin letterforms.
///  * **Tracking and the gap between the halves** are em-based, so the mark is
///    the same shape at the 25px header and the 36px hero instead of drifting.
///  * **Colours** are the brand pair — [AppColors.wordmarkInk] and
///    [AppColors.brandRed].
///
/// The raster splash masters (`assets/branding/logo_wordmark*.png`) are rendered
/// from this exact spec by `tool/branding/generate_wordmark.py`, whose constants
/// mirror this class. Change a value here and regenerate there, or the splash
/// and the app drift apart again.
class AppWordmark extends StatelessWidget {
  const AppWordmark({
    super.key,
    required this.base,
    this.inkColor = AppColors.wordmarkInk,
    this.goColor = AppColors.brandRed,
    this.buildPart,
  });

  /// The typography step the mark is sized from. Only its `fontSize` (and the
  /// line height that comes with it) is honoured — weight, family, tracking and
  /// colour come from the brand spec, so no caller can quietly restyle the logo.
  final TextStyle base;

  /// The "Toki" half. Override only for a surface that needs it, e.g.
  /// [AppColors.wordmarkOnMedia] over photography.
  final Color inkColor;

  /// The "Go" half — the brand red.
  final Color goColor;

  /// Optional decorator for each half, used by the animated Home header.
  final WordmarkPartBuilder? buildPart;

  /// The logotype's family, whatever the active locale is.
  static const String fontFamily = AppTypography.fontFamily;

  /// The heaviest weight the bundled font ships — the mark's weight.
  static const FontWeight markWeight = AppTypography.weightExtraBold;

  /// Tracking as a fraction of the font size (−1.2%). Flutter's
  /// [TextStyle.letterSpacing] is absolute px, so an em value is what keeps the
  /// same mark shape across sizes; −1.2% is the −0.3px the header always used
  /// at 25px. Baked into the raster masters as well.
  static const double trackingEm = -0.012;

  /// Gap between the halves, in em (0.16em == the 4dp the header used at 25px).
  static const double gapEm = 0.16;

  @override
  Widget build(BuildContext context) {
    final double size = base.fontSize ?? AppTypography.fontSizeTitle;
    final TextStyle ink = _half(base, inkColor, size);
    final TextStyle go = _half(base, goColor, size);

    Widget part(int index, String text, TextStyle style) {
      final child = Text(text, style: style);
      return buildPart == null ? child : buildPart!(context, index, child);
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          part(0, 'Toki', ink),
          SizedBox(width: size * gapEm),
          part(1, 'Go', go),
        ],
      ),
    );
  }

  static TextStyle _half(TextStyle base, Color color, double size) =>
      base.copyWith(
        color: color,
        fontFamily: fontFamily,
        // A single-entry fallback: Manrope must supply every glyph of the mark,
        // never Cairo or a platform font.
        fontFamilyFallback: const <String>[fontFamily],
        fontWeight: markWeight,
        letterSpacing: size * trackingEm,
      );
}
