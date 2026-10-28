import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_overlap.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/widgets/cards/card_overlap.dart';

/// Hero geometry for the detail surface (card G).
///
/// The reference hero is **52% of the viewport**. On a compact phone that is
/// still taller than the sheet below it, which pushes the title under the
/// fold — so below [compactBreakpoint] the hero drops to
/// [compactFraction]. Both numbers live here and nowhere else.
abstract final class AppHeroMetrics {
  static const double fraction = 0.52;
  static const double compactFraction = 0.44;

  /// Below this width the hero uses [compactFraction]. 480pt covers every
  /// phone in portrait; tablets keep the reference proportion.
  static const double compactBreakpoint = 480;

  static double heightFor(Size viewport) =>
      viewport.height *
      (viewport.width < compactBreakpoint ? compactFraction : fraction);
}

/// Card G — the detail page surface: full-bleed hero photo, a sheet biting
/// **24px** up into it (not card A's 48), rounded `xl` on the top corners only.
///
/// The two overlaps are intentionally different constants; passing
/// [AppOverlap.card] here would make the detail page read like a list card.
class AppHeroSheet extends StatelessWidget {
  const AppHeroSheet({
    super.key,
    required this.media,
    required this.child,
    this.sheetPadding = const EdgeInsets.all(16),
    this.overlay,
  });

  /// The hero photo.
  final Widget media;

  /// The sheet content below the hero.
  final Widget child;

  final EdgeInsetsGeometry sheetPadding;

  /// Chrome pinned over the photo (back, heart, share). Rendered inside the
  /// safe area so it never collides with the status bar.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final Size viewport = MediaQuery.sizeOf(context);
    return CardOverlap(
      mediaHeight: AppHeroMetrics.heightFor(viewport),
      overlap: AppOverlap.detailSheet,
      radius: AppRadius.none,
      sheetTopRadius: AppRadius.xl,
      clipOuter: false,
      sheetPadding: sheetPadding,
      media: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          media,
          if (overlay != null)
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: SafeArea(bottom: false, child: overlay!),
            ),
        ],
      ),
      sheet: child,
    );
  }
}
