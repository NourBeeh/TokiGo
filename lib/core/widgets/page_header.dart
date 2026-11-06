import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/app_back_button.dart';
import 'package:tokigo/core/widgets/app_icon_action.dart';

/// The unified pushed-page header — one identity for every discovery and
/// search surface (Groups, Flights/Hotels/Cars/Packages).
///
/// **Owner decision (2026-11): the page NAME is gone.** The header carries one
/// line only — the page's small description — sitting in the control row's
/// title slot, beside the back control. A second, larger line of type was
/// redundant with that description and pushed every page's content down.
///
/// One UI app-bar rhythm: a control row (back control + the description +
/// optional trailing action), then an optional progress affordance. Type and
/// controls share the page gutter, so the header lines up with the page's own
/// content column.
///
/// The description uses [AppTypography.body] (15/400) in `textTertiary` —
/// deliberately NOT `headline` (28/800): it stays the quiet supporting line it
/// always was, now promoted to the only identifying text in the header.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    this.subtitle,
    this.trailing,
    this.steps,
    this.showBackButton = true,
    this.backFallbackLocation,
    this.backEnabled = true,
    this.visible = true,
  });

  /// The page's supporting line — the ONLY identifying text in the header.
  ///
  /// Every surface supplies one (owner decision, 2026-11): with the title gone,
  /// a missing description leaves the header as a bare back control and the
  /// page unnamed.
  final String? subtitle;

  /// Optional action pinned to the end of the control row (e.g. a view toggle).
  final Widget? trailing;

  /// Optional progress affordance under the title — the booking funnel's
  /// [StepProgress] — so a multi-step flow shares the same header rhythm.
  final Widget? steps;

  /// Whether the header draws the back control itself.
  ///
  /// Hosts that own a travelling control ([DetachedBackButton]) pass `false`:
  /// the row keeps its height (and [trailing]) so the title rhythm never
  /// shifts, while the detached control renders over the reserved space.
  final bool showBackButton;

  /// Where the back control lands when the route cannot pop — see
  /// [AppBackButton.fallbackLocation]. Null resolves to Home.
  final String? backFallbackLocation;

  /// Whether leaving the page is currently allowed — see
  /// [AppIconAction.enabled]. The payment step blocks it while a charge is in
  /// flight.
  final bool backEnabled;

  /// Whether the whole header is rendered.
  ///
  /// The six top-level sections pass `false` while the persistent shell chrome
  /// is on screen: their navigation bar already identifies the section, so a
  /// second back control or description would be redundant.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final typography = AppTypography.forLight();
    final TextDirection appTextDirection = Directionality.of(context);
    final TextStyle description = typography.body.copyWith(
      color: context.tokigoColors.textTertiary,
    );
    final bool rtl = appTextDirection == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Directionality(
        textDirection: appTextDirection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (rtl) ...<Widget>[
                  if (trailing != null) trailing!,
                  Expanded(child: _descriptionBlock(description)),
                  const SizedBox(width: AppSpacing.sm),
                  _backControl(),
                ] else ...<Widget>[
                  _backControl(),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _descriptionBlock(description)),
                  if (trailing != null) trailing!,
                ],
              ],
            ),
            if (steps case final Widget progress) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Directionality(textDirection: appTextDirection, child: progress),
            ],
          ],
        ),
      ),
    );
  }

  /// The description, in the control row's title slot. `Semantics.header` keeps
  /// the surface announced as a named page even though the visible type is
  /// small.
  Widget _descriptionBlock(TextStyle style) {
    final String? line = subtitle;
    if (line == null) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        header: true,
        child: Text(
          line,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
  }

  Widget _backControl() {
    if (showBackButton) {
      return AppBackButton(
        fallbackLocation: backFallbackLocation,
        enabled: backEnabled,
      );
    }
    return const SizedBox(
      width: AppIconAction.tapTarget,
      height: AppIconAction.tapTarget,
    );
  }
}
