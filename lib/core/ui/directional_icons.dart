import 'package:flutter/material.dart';

/// Directional glyphs that follow the active reading direction.
///
/// Material's arrow set is mixed: `arrow_back_ios_new_rounded` carries
/// `matchTextDirection` and mirrors itself, but `chevron_right_rounded` and
/// `arrow_forward_rounded` are plain geometry and keep pointing right in
/// Arabic — where "forward", "next" and "disclosure" run the OTHER way.
///
/// Every chevron/arrow that means progress, disclosure or "view all" must come
/// from here so the whole app mirrors with the locale instead of each call
/// site re-deriving it (and some forgetting).
@immutable
abstract final class DirectionalIcons {
  /// A disclosure / "continue" chevron pointing the way the text flows.
  static IconData chevron(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
      ? Icons.chevron_left_rounded
      : Icons.chevron_right_rounded;

  /// The thin filled chevron used on dense rows.
  static IconData chevronThin(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
      ? Icons.chevron_left
      : Icons.chevron_right;

  /// "Onward" — the small arrow beside a text link such as "View all".
  static IconData forward(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
      ? Icons.arrow_back_rounded
      : Icons.arrow_forward_rounded;
}
