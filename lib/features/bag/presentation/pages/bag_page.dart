import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_message_state.dart';
import 'package:tokigo/core/ui/localized_date.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/cards/card_image.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/core/widgets/step_progress.dart' show StatusChip;
import 'package:tokigo/features/bag/application/bag_controller.dart';
import 'package:tokigo/features/bag/domain/trip.dart';
import 'package:tokigo/features/bag/presentation/trip_labels.dart';
import 'package:tokigo/features/profile/presentation/pages/wishlist_page.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart'
    show SearchSegmentedControl;
import 'package:tokigo/l10n/app_localizations.dart';

/// My Trips — the unified trip surface.
///
/// **Reference screen 8**: a segmented Upcoming/Past control over cards that
/// carry the vertical, the booked item, its dates, the provider's reference and
/// the status.
///
/// **Honesty rules (owner, 2026-10-19):** a trip states only what the confirmed
/// booking really carries. Upcoming/past is derived from the trip's own dates
/// (a booking without dates is never called "past"), the card never invents a
/// photo or a price, and an empty filter says so instead of showing a sample
/// trip. A third "Cancelled" filter from the reference is **not** built: no
/// cancellation flow can produce that state, and a filter that can never fill
/// is decoration.
class BagPage extends ConsumerStatefulWidget {
  const BagPage({super.key, this.initialLikes = false});

  final bool initialLikes;

  @override
  ConsumerState<BagPage> createState() => _BagPageState();
}

enum _BagSection { trips, likes }

enum _TripPeriod { upcoming, past, cancelled }

class _BagPageState extends ConsumerState<BagPage> {
  late _BagSection _section;
  _TripPeriod _period = _TripPeriod.upcoming;

  @override
  void initState() {
    super.initState();
    _section = widget.initialLikes ? _BagSection.likes : _BagSection.trips;
  }

  @override
  Widget build(BuildContext context) {
    final bag = ref.watch(bagControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // The Bag keeps two lists (a trip can be moved explicitly); the filter is
    // derived from the trip's own dates so both lists are classified the same
    // way. A trip without dates is never claimed as past.
    final all = <TripSummary>[...bag.currentTrips, ...bag.pastTrips];

    // Three real periods (doc 22 §1.2). A cancelled booking is its own
    // period: the backend owns that state, so the tab is real — and a
    // cancelled trip must not sit in "Upcoming" pretending to still travel.
    _TripPeriod periodOf(TripSummary trip) {
      if (trip.status.toLowerCase() == 'cancelled') {
        return _TripPeriod.cancelled;
      }
      final end = trip.endDate ?? trip.startDate;
      if (end != null && end.isBefore(today)) return _TripPeriod.past;
      return _TripPeriod.upcoming;
    }

    final trips = all.where((trip) => periodOf(trip) == _period).toList()
      ..sort((a, b) {
        final aDate = a.startDate;
        final bDate = b.startDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return _period == _TripPeriod.upcoming
            ? aDate.compareTo(bDate)
            : bDate.compareTo(aDate);
      });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: AiEntranceAnimation(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppPageHeader(
                title: _section == _BagSection.trips
                    ? l10n.myTrips
                    : l10n.wishlist,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: SearchSegmentedControl<_BagSection>(
                  options: const <_BagSection>[
                    _BagSection.trips,
                    _BagSection.likes,
                  ],
                  selected: _section,
                  labelOf: (section) => switch (section) {
                    _BagSection.trips => l10n.myTrips,
                    _BagSection.likes => l10n.wishlist,
                  },
                  onSelected: (section) => setState(() => _section = section),
                ),
              ),
              if (_section == _BagSection.trips)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: SearchSegmentedControl<_TripPeriod>(
                    options: const <_TripPeriod>[
                      _TripPeriod.upcoming,
                      _TripPeriod.past,
                      _TripPeriod.cancelled,
                    ],
                    selected: _period,
                    labelOf: (period) => switch (period) {
                      _TripPeriod.upcoming => l10n.upcoming,
                      _TripPeriod.past => l10n.past,
                      _TripPeriod.cancelled => l10n.cancelled,
                    },
                    onSelected: (period) => setState(() => _period = period),
                  ),
                ),
              Expanded(
                child: _section == _BagSection.likes
                    ? const WishlistPage(embedded: true)
                    : trips.isEmpty
                    ? _EmptyTrips(period: _period)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.xs,
                          AppSpacing.lg,
                          AppSpacing.xxxl,
                        ),
                        itemCount: trips.length,
                        itemBuilder: (context, index) =>
                            _TripCard(trip: trips[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips({required this.period});

  final _TripPeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppMessageState(
                icon: Icons.luggage_outlined,
                title: switch (period) {
                  _TripPeriod.upcoming => l10n.tripsEmptyUpcomingTitle,
                  _TripPeriod.past => l10n.tripsEmptyPastTitle,
                  // A real, empty period — the tab exists because the backend
                  // owns the state, not because something was invented.
                  _TripPeriod.cancelled => l10n.tripsEmptyCancelledTitle,
                },
                body: l10n.tripsEmptyBody,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final TripSummary trip;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;
    final typeLabel = tripTypeLabel(l10n, trip.type);
    final place = trip.destination.trim();
    final title = trip.title?.trim();
    final hasTitle = title != null && title.isNotEmpty;
    // Name the trip with what the booking really carries: the item's own name,
    // else the place/route. With neither, the vertical label above already
    // names it — repeating it as a headline would just say "Hotel" twice.
    final headline = hasTitle ? title : (place.isNotEmpty ? place : null);
    final showPlace = hasTitle && place.isNotEmpty;
    final dates = _dateLine(context, l10n, trip);

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: CardImage(
                      url: trip.imageUrl,
                      fallbackIcon: tripTypeIcon(trip.type),
                      semanticLabel: headline ?? typeLabel,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            tripTypeIcon(trip.type),
                            size: 13,
                            color: AppColors.brand,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Flexible(
                            child: Text(
                              typeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typography.captionSemibold.copyWith(
                                color: AppColors.brand,
                              ),
                            ),
                          ),
                          const Spacer(),
                          StatusChip(
                            label: tripStatusLabel(l10n, trip.status),
                            color: tripStatusColor(trip.status),
                          ),
                        ],
                      ),
                      if (headline != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: typography.bodyLargeMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                      if (showPlace) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                      if (dates != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 13,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                dates,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      // The reference gets the full line: a truncated booking
                      // reference is useless, so the money sits on its own
                      // end-aligned line instead of squeezing it.
                      Text(
                        trip.bookingReference.isEmpty
                            ? trip.providerName
                            : '${l10n.bookingReferenceLabel} · '
                                  '${trip.bookingReference}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          '${trip.currency} '
                          '${trip.total.toStringAsFixed(2)}',
                          style: typography.bodyLargeMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The trip's own dates (never a computed window) plus the traveller count
  /// the booking actually carried. Null when neither is known.
  String? _dateLine(
    BuildContext context,
    AppLocalizations l10n,
    TripSummary trip,
  ) {
    final start = trip.startDate;
    final end = trip.endDate;
    // A same-day trip (a flight, a day rental) is one date, not a range from
    // a day to itself.
    final sameDay =
        start != null &&
        end != null &&
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    String? dates;
    if (start != null && end != null && !sameDay) {
      dates =
          '${localizedMediumDate(context, start)} – '
          '${localizedMediumDate(context, end)}';
    } else if (start != null) {
      dates = localizedMediumDate(context, start);
    }
    final count = trip.travelersCount;
    final who = count == null ? null : l10n.tripTravellersCount(count);
    if (dates == null) return who;
    if (who == null) return dates;
    return '$dates · $who';
  }
}
