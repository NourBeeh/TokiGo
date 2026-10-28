import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/app_back_button.dart';
import 'package:tokigo/core/widgets/app_icon_action.dart';

/// The unified pushed-page header — one identity for every discovery and
/// search surface (Groups, Flights/Hotels/Cars/Packages).
///
/// One UI app-bar rhythm: a control row (back control + optional trailing
/// action) over the headline title, then a muted subtitle — title and subtitle
/// on the page gutter, so the header's type lines up with the page's own
/// content column. Extracting this keeps every surface from drifting apart.
///
/// The title uses [AppTypography.headline] (28/800) — deliberately NOT
/// `display` (36/800): every reference page title measures 27–29px, and a 36px
/// title would collide with Home's greeting, which owns the display size.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    this.steps,
    this.showBackButton = true,
    this.backFallbackLocation = '/',
    this.backEnabled = true,
  });

  /// Big page title ("Groups", "Flights"…).
  ///
  /// Optional: a surface that already carries its own hero heading (the booking
  /// confirmation's success mark, the AI chat) renders the control row alone
  /// rather than repeating the title.
  final String? title;

  /// Optional supporting line under the title.
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
  /// [AppBackButton.fallbackLocation].
  final String backFallbackLocation;

  /// Whether leaving the page is currently allowed — see
  /// [AppIconAction.enabled]. The payment step blocks it while a charge is in
  /// flight.
  final bool backEnabled;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title case final String line)
            Row(
              children: <Widget>[
                if (showBackButton)
                  AppBackButton(
                    fallbackLocation: backFallbackLocation,
                    enabled: backEnabled,
                  )
                else
                  const SizedBox(
                    width: AppIconAction.tapTarget,
                    height: AppIconAction.tapTarget,
                  ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.headline.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                ?trailing,
              ],
            )
          else
            Row(
              children: <Widget>[
                if (showBackButton)
                  AppBackButton(
                    fallbackLocation: backFallbackLocation,
                    enabled: backEnabled,
                  )
                else
                  const SizedBox(
                    width: AppIconAction.tapTarget,
                    height: AppIconAction.tapTarget,
                  ),
                const Spacer(),
                ?trailing,
              ],
            ),
          if (subtitle case final String line) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              line,
              style: typography.body.copyWith(color: AppColors.textTertiary),
            ),
          ],
          if (steps case final Widget progress) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            progress,
          ],
        ],
      ),
    );
  }
}
