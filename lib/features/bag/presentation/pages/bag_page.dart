import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/widgets/step_progress.dart' show StatusChip;
import 'package:tokigo/features/bag/application/bag_controller.dart';
import 'package:tokigo/features/bag/domain/trip.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// My Trips (Bag) — the unified trip surface.
///
/// Upcoming/past tabs of trip cards with status chips. The full
/// Today/Itinerary/Map/Wallet surfaces arrive with the travel-mode phase;
/// this page replaces the old placeholder with the real Bag state.
class BagPage extends ConsumerWidget {
  const BagPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bag = ref.watch(bagControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final typography = AppTypography.forLight();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                    Text(
                      l10n.myTrips,
                      style: typography.display.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TabBar(
                  tabs: <Widget>[
                    Tab(text: l10n.upcoming),
                    Tab(text: l10n.past),
                  ],
                  labelColor: AppColors.brand,
                  unselectedLabelColor: AppColors.textTertiary,
                  indicatorColor: AppColors.brand,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelStyle: typography.bodyLargeMedium,
                  unselectedLabelStyle: typography.bodyMedium,
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _TripList(trips: bag.currentTrips, emptyLabel: l10n.upcoming),
                    _TripList(trips: bag.pastTrips, emptyLabel: l10n.past),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  const _TripList({required this.trips, required this.emptyLabel});

  final List<TripSummary> trips;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.luggage_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No $emptyLabel trips yet',
              style: typography.bodyLargeMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your confirmed bookings appear here automatically.',
              style: typography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      itemCount: trips.length,
      itemBuilder: (context, index) => _TripCard(trip: trips[index]),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final TripSummary trip;

  static Color _statusColor(String status) => switch (status) {
        'confirmed' => AppColors.success,
        'planned' => AppColors.info,
        'needsReview' || 'needs_review' => AppColors.warning,
        'cancelled' => AppColors.danger,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final dateFormat = (DateTime d) =>
        '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/bag/${trip.tripId}'),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        trip.destination,
                        style: typography.bodyLargeMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    StatusChip(
                      label: trip.status,
                      color: _statusColor(trip.status),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${dateFormat(trip.startDate)} → ${dateFormat(trip.endDate)}',
                      style: typography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${trip.currency} ${trip.total.toStringAsFixed(0)}',
                      style: typography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.confirmation_number_rounded,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${trip.providerName} • ${trip.bookingReference}',
                      style: typography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
