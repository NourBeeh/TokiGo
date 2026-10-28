import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_elevation.dart';
import 'package:tokigo/core/theme/app_spacing.dart';

/// The two chrome roles an icon action can play — Samsung's One UI app-bar
/// language, which the app follows for navigation chrome.
enum AppIconActionVariant {
  /// Resting canvas chrome (a page header): a bare glyph whose box starts on
  /// the page gutter. No fill, no outline — the surrounding type does the
  /// visual work, exactly like the One UI app bar at the top of a page.
  bare,

  /// Floating chrome (over photography, or detached while scrolling): a
  /// near-white translucent disc whose edge comes from a soft diffuse shadow
  /// rather than a hairline, so it stays legible over both light and dark
  /// images. This is One UI's detached back button.
  disc,
}

/// The single source of truth for icon actions in app chrome.
///
/// Why it exists: the header used to render a stock [IconButton] — a 48×48 box
/// with the glyph centred, so the glyph drifted 12px inside the gutter and the
/// page title ended up 48px off the page's own content column — while the
/// offer-details hero hand-rolled a flat white circle with an untokenised fill.
/// Two shapes, two glyphs, one app. Both roles now come from here.
class AppIconAction extends StatelessWidget {
  const AppIconAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.variant = AppIconActionVariant.bare,
    this.semanticLabel,
    this.color,
    this.enabled = true,
    this.showTooltip = true,
    this.splashEnabled = true,
  });

  /// Tap target: always at least the 48 accessibility minimum, whatever the
  /// variant draws inside it.
  static const double tapTarget = AppSpacing.minimumTapTarget;

  /// Glyph box for [AppIconActionVariant.bare]. The gutter alignment depends on
  /// it, so it is fixed here rather than passed in.
  static const double bareGlyph = 24;

  /// Visible diameter of [AppIconActionVariant.disc].
  static const double discDiameter = 44;

  /// Role swap. Short and eased: it must read as the control *changing role*
  /// while the page scrolls, never as a second button fading in.
  static const Duration swapDuration = Duration(milliseconds: 180);

  final IconData icon;
  final VoidCallback onTap;
  final AppIconActionVariant variant;

  /// Accessible label; also becomes the long-press tooltip on desktop/web
  /// unless [showTooltip] is off.
  final String? semanticLabel;

  /// Whether the visible hover/long-press tooltip is drawn.
  ///
  /// The back control turns it off: a floating "Back" chip over a page
  /// competes with the title it now sits beside. The label itself is kept —
  /// it is what a screen reader announces.
  final bool showTooltip;

  /// Whether the press ripple (the expanding circle) is drawn.
  ///
  /// Off for the back control: a circle bursting out of a chevron reads as a
  /// second, unlabelled button rather than as feedback.
  final bool splashEnabled;

  /// Overrides the ink colour (defaults to [AppColors.textPrimary]).
  final Color? color;

  /// Whether the action can be pressed.
  ///
  /// A blocked action keeps its geometry — the header rhythm must never shift
  /// mid-flight — and only mutes its ink, so it still reads as chrome while the
  /// page is deliberately un-leavable (a payment being processed).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool disc = variant == AppIconActionVariant.disc;
    final Color ink = enabled
        ? (color ?? AppColors.textPrimary)
        : AppColors.textTertiary;

    final Widget sized = SizedBox(
      width: tapTarget,
      height: tapTarget,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          // The press ripple is opt-out: a circle bursting out of a bare
          // chevron reads as a second, unlabelled button, not as feedback.
          splashFactory: splashEnabled
              ? InkRipple.splashFactory
              : NoSplash.splashFactory,
          highlightColor: splashEnabled ? null : Colors.transparent,
          // ONE subtree for both roles: the fill and the glyph travel between
          // the gutter and the centred disc, instead of a second control being
          // built. The back contract must never see two buttons.
          child: AnimatedAlign(
            duration: swapDuration,
            curve: Curves.easeOutCubic,
            alignment: disc
                ? AlignmentDirectional.center
                : AlignmentDirectional.centerStart,
            child: AnimatedContainer(
              duration: swapDuration,
              curve: Curves.easeOutCubic,
              width: disc ? discDiameter : bareGlyph,
              height: disc ? discDiameter : bareGlyph,
              // No border, ever: a hairline reads as a sticker and vanishes on
              // a light photo — the shadow is the edge.
              decoration: disc
                  ? BoxDecoration(
                      color: AppColors.onMediaFill,
                      shape: BoxShape.circle,
                      boxShadow: AppElevation.shadow(
                        background: AppColors.surface,
                        level: AppElevation.lg,
                      ),
                    )
                  : null,
              child: Center(
                child: Icon(
                  icon,
                  size: disc ? 20 : 22,
                  color: ink,
                  semanticLabel: semanticLabel,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final String? label = semanticLabel;
    if (label == null || !showTooltip) return sized;
    return Tooltip(message: label, child: sized);
  }
}
