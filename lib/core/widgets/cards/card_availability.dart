import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';

/// Semantic availability of an offer.
enum CardAvailabilityStatus { available, limited, unavailable }

/// Availability chip with theme-driven semantic colors:
/// available → primary, limited → tertiary, unavailable → error.
class CardAvailability extends StatelessWidget {
  const CardAvailability({super.key, required this.status, this.label});

  final CardAvailabilityStatus status;

  /// Optional custom label; defaults to a fixed English string per status.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tc = context.tokigoColors;
    final (Color container, Color ink) = switch (status) {
      CardAvailabilityStatus.available => (
        tc.successContainer,
        tc.onSuccessContainer,
      ),
      CardAvailabilityStatus.limited => (
        tc.warningContainer,
        tc.onWarningContainer,
      ),
      CardAvailabilityStatus.unavailable => (
        tc.dangerContainer,
        tc.onDangerContainer,
      ),
    };
    final Color color = ink;
    final String text =
        label ??
        switch (status) {
          CardAvailabilityStatus.available => 'Available',
          CardAvailabilityStatus.limited => 'Few left',
          CardAvailabilityStatus.unavailable => 'Unavailable',
        };

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
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
