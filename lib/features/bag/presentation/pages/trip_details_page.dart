import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/step_progress.dart' show StatusChip;

/// Trip details — the deep-dive surface of one trip in the Bag.
///
/// v1 renders the trip summary as a premium fact card; the full
/// Today/Itinerary/Map/Wallet surfaces arrive with the travel-mode phase.
class TripDetailsPage extends StatelessWidget {
  const TripDetailsPage({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.canPop() ? context.pop() : context.go('/bag'),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Trip details',
                    style: typography.title.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.brandContainer,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Column(
                      children: <Widget>[
                        Icon(
                          Icons.luggage_rounded,
                          size: 44,
                          color: AppColors.brand,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Trip $tripId',
                          style: typography.headline.copyWith(
                            color: AppColors.onBrandContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _FactCard(
                    rows: <(String, String)>[
                      ('Status', 'confirmed'),
                      ('Type', 'booking'),
                      ('Provider', 'TokiGo'),
                      ('Reference', tripId),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Itinerary, map, wallet and readiness arrive with the travel-mode phase.',
                    style: typography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactCard extends StatelessWidget {
  const _FactCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: <Widget>[
          for (final (label, value) in rows) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: typography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: typography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (value != rows.last.$2) const Divider(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}
