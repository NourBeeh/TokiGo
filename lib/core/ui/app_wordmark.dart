import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_spacing.dart';

/// Decorates one half of the wordmark (index 0 = "Toki", 1 = "Go").
///
/// Home uses it to animate its two halves independently; a static surface can
/// simply ignore it.
typedef WordmarkPartBuilder =
    Widget Function(BuildContext context, int index, Widget child);

/// The TokiGo logotype.
///
/// A brand mark is a fixed shape, not a phrase: it must read "TokiGo" in every
/// locale. Wrapping the two halves in an explicit [TextDirection.ltr] is what
/// guarantees that — in an Arabic (RTL) layout a plain `Row` mirrors them into
/// "GoToki", which is a different word, not a translation.
///
/// This is the ONE place the logotype is built (Home's animated header and the
/// first-launch hero both use it) so the rule cannot be forgotten twice.
class AppWordmark extends StatelessWidget {
  const AppWordmark({
    super.key,
    required this.style,
    this.goStyle,
    this.buildPart,
  });

  /// Style of "Toki" (and of "Go" when [goStyle] is null).
  final TextStyle? style;

  /// Style of "Go" — the brand-red half.
  final TextStyle? goStyle;

  /// Optional decorator for each half, used by the animated Home header.
  final WordmarkPartBuilder? buildPart;

  @override
  Widget build(BuildContext context) {
    Widget part(int index, String text, TextStyle? partStyle) {
      final child = Text(text, style: partStyle);
      return buildPart == null ? child : buildPart!(context, index, child);
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          part(0, 'Toki', style),
          const SizedBox(width: AppSpacing.xs),
          part(1, 'Go', goStyle ?? style),
        ],
      ),
    );
  }
}
