import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Horizontal step progress indicator for multi-step flows
/// (booking: details → add-ons → payment).
///
/// Four equal segments, 4px tall, 4px apart, fully rounded. Completed and
/// current segments are brand; upcoming ones stay neutral. The widget takes
/// [total] as data — a vertical without add-ons runs a 3-step funnel and must
/// not be forced to 4.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.current, required this.total});

  /// Zero-based index of the active step.
  final int current;

  /// Number of steps in the funnel (3 or 4 today).
  final int total;

  static const double segmentHeight = 4;
  static const Duration fillDuration = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final int safeTotal = total < 1 ? 1 : total;
    final int safeCurrent = current.clamp(0, safeTotal - 1);

    // Localized when the app supplies its localizations; the English form is
    // the documented fallback for bare test hosts.
    final l10n = AppLocalizations.of(context);
    final label =
        l10n?.bookingStepOf('${safeCurrent + 1}', '$safeTotal') ??
        'Step ${safeCurrent + 1} of $safeTotal';

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          children: <Widget>[
            for (int i = 0; i < safeTotal; i++) ...<Widget>[
              Expanded(
                child: AnimatedContainer(
                  duration: fillDuration,
                  curve: Curves.easeOutCubic,
                  height: segmentHeight,
                  decoration: BoxDecoration(
                    color: i <= safeCurrent
                        ? AppColors.brand
                        : AppColors.surfaceTertiary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              if (i < safeTotal - 1) const SizedBox(width: AppSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}

/// The four booking/trip lifecycle states a [StatusChip] can express.
enum BookingStatusTone { confirmed, pending, cancelled, completed }

/// Status chip with container tint — used across booking states, trip item
/// lifecycles and group roles.
///
/// Prefer [StatusChip.forTone] for the four documented booking palettes: it
/// also draws the 6px dot that precedes the status text.
class StatusChip extends StatelessWidget {
  StatusChip({
    super.key,
    required this.label,
    required this.color,
    Color? container,
    this.showDot = false,
  }) : container = container ?? color.withValues(alpha: 0.1);

  /// The documented booking palette for [tone], with AA-passing label colours.
  ///
  /// The reference pairs `success` on `successContainer` (2.9:1) and `warning`
  /// on `warningContainer` (2.9:1) — unreadable at 11px. The label uses the
  /// darker "on container" steps instead (6.4:1). Cancelled and completed are
  /// both terminal states and share the neutral pair, which clears AA at
  /// 4.7:1; the words carry the distinction, not the tint.
  factory StatusChip.forTone({
    Key? key,
    required String label,
    required BookingStatusTone tone,
    bool showDot = true,
  }) {
    final (Color fill, Color ink) = switch (tone) {
      BookingStatusTone.confirmed => (
        AppColors.successContainer,
        AppColors.onSuccessContainer,
      ),
      BookingStatusTone.pending => (
        AppColors.warningContainer,
        AppColors.onWarningContainer,
      ),
      BookingStatusTone.cancelled || BookingStatusTone.completed => (
        AppColors.surfaceSecondary,
        AppColors.textSecondary,
      ),
    };
    return StatusChip(
      key: key,
      label: label,
      color: ink,
      container: fill,
      showDot: showDot,
    );
  }

  final String label;
  final Color color;
  final Color container;

  /// Draw the 6px dot before the label, in [color].
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showDot) ...<Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.label.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
