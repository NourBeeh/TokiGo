import 'package:flutter/material.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/cards/card_badge.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// A visual route line for flights showing departure, stops, and arrival.
///
/// Renders a horizontal line with:
/// - Departure time on the start side
/// - Visual line with stop indicator (●) when stops > 0
/// - Stop city/country label under the stop indicator
/// - Layover duration when available
/// - Arrival time on the end side
///
/// Fully RTL-safe: uses directional alignment only.
class FlightRouteLine extends StatelessWidget {
  const FlightRouteLine({
    super.key,
    required this.departureTime,
    required this.arrivalTime,
    required this.origin,
    required this.destination,
    this.stops = 0,
    this.stopAirport,
    this.layoverDuration,
    this.duration,
    this.compact = false,
  });

  final DateTime departureTime;
  final DateTime arrivalTime;
  final String origin;
  final String destination;
  final int stops;
  final String? stopAirport;
  final String? layoverDuration;
  final String? duration;

  /// Compact variant for recommendation cards: slightly smaller typography.
  final bool compact;

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.tokigoColors;
    final scheme = Theme.of(context).colorScheme;
    final lineColor = scheme.outlineVariant;
    final timeStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: compact ? null : AppTypography.fontSizeTitle,
    );

    // "Arrives the next day": the arrival time is shown in the destination's
    // local clock, so a red-eye can read 23:50 → 05:10 with no hint that it
    // landed tomorrow. Compare calendar days, not hours.
    final int arrivalDayOffset = DateUtils.dateOnly(
      arrivalTime,
    ).difference(DateUtils.dateOnly(departureTime)).inDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main route row: departure time | line | arrival time
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Departure column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatTime(departureTime), style: timeStyle),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    origin,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            // Route line with stops
            Expanded(
              flex: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AppSpacing.xs),
                  // Line with stop indicators. The row is given a real height so
                  // the 10px stop dot and the 14px plane are not clipped to the
                  // 2px line (Stack clips to its own bounds by default), and no
                  // clipping at all as a safety net.
                  SizedBox(
                    height: 16,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Main line
                        Container(height: 2, color: lineColor),
                        // Plane icon travelling the route — turned to fly toward
                        // the arrival end (RTL routes read right → left).
                        PositionedDirectional(
                          end: 0,
                          child: RotatedBox(
                            quarterTurns:
                                Directionality.of(context) == TextDirection.rtl
                                ? 3
                                : 1,
                            child: const Icon(Icons.flight, size: 14),
                          ),
                        ),
                        // Stop indicators
                        if (stops > 0)
                          ..._buildStopIndicators(context, lineColor),
                      ],
                    ),
                  ),
                  // Duration pill
                  if (duration != null && duration!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: AppRadius.pillBorder,
                        ),
                        child: Text(
                          duration!,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Arrival column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The arrival column is a fixed flex share of a narrow row
                  // (compact cards are the tightest). The optional "+1"
                  // badge must never push the time past that share, so the
                  // pair scales down together instead of overflowing.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatTime(arrivalTime), style: timeStyle),
                        if (arrivalDayOffset > 0)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 2),
                            child: Text(
                              '+$arrivalDayOffset',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    destination,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Stop details (layover, airport name)
        if (stops > 0 && (stopAirport != null || layoverDuration != null)) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildStopDetails(context),
        ],
      ],
    );
  }

  List<Widget> _buildStopIndicators(BuildContext context, Color lineColor) {
    final scheme = Theme.of(context).colorScheme;

    if (stops == 1) {
      return [
        // Single stop in the middle
        PositionedDirectional(
          start: 0,
          end: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: scheme.onSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: lineColor, width: 2),
                ),
              ),
            ],
          ),
        ),
      ];
    } else {
      // Multiple stops - distribute along the line
      final widgets = <Widget>[];
      for (int i = 0; i < stops; i++) {
        widgets.add(
          Align(
            alignment: Alignment(-1.0 + (2.0 / (stops + 1)) * (i + 1), 0),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: scheme.onSurface,
                shape: BoxShape.circle,
                border: Border.all(color: lineColor, width: 2),
              ),
            ),
          ),
        );
      }
      return widgets;
    }
  }

  Widget _buildStopDetails(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    if (stops == 1 && stopAirport != null) {
      // Single stop with airport name and optional layover
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (stopAirport!.isNotEmpty) ...[
            Text(
              stopAirport!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (layoverDuration != null && layoverDuration!.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n?.offerLayover(layoverDuration!) ??
                    '${layoverDuration!} layover',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      );
    } else if (stops > 1) {
      // Multiple stops - show as badges
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          CardBadge(
            label: l10n?.offerStopsCount(stops) ?? '$stops stops',
            icon: Icons.flight,
            variant: CardBadgeVariant.tinted,
          ),
          if (stopAirport != null && stopAirport!.isNotEmpty)
            CardBadge(
              label: stopAirport!,
              icon: Icons.flight_land,
              variant: CardBadgeVariant.tinted,
            ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
