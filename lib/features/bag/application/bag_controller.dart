import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/features/bag/domain/trip.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/core/domain/models/booking/booking.dart';

class BagState {
  final List<TripSummary> currentTrips;
  final List<TripSummary> pastTrips;

  const BagState({this.currentTrips = const [], this.pastTrips = const []});
}

class BagController extends StateNotifier<BagState> {
  BagController() : super(const BagState());

  void addCurrent(TripSummary trip) {
    if (_exists(trip.bookingId)) return;
    state = BagState(
      currentTrips: <TripSummary>[...state.currentTrips, trip],
      pastTrips: state.pastTrips,
    );
  }

  /// Marks the trip as cancelled — the backend confirmed the cancellation, so
  /// the trip moves to the Bag's "Cancelled" period instead of pretending it
  /// is still travelling.
  void markCancelled(String tripId) {
    TripSummary? updated;
    final List<TripSummary> current = <TripSummary>[];
    for (final TripSummary trip in state.currentTrips) {
      if (trip.tripId == tripId) {
        updated = trip.copyWith(status: 'cancelled');
        current.add(updated);
      } else {
        current.add(trip);
      }
    }
    final List<TripSummary> past = <TripSummary>[];
    for (final TripSummary trip in state.pastTrips) {
      past.add(
        trip.tripId == tripId ? trip.copyWith(status: 'cancelled') : trip,
      );
    }
    state = BagState(currentTrips: current, pastTrips: past);
  }

  void moveToPast(String tripId) {
    final current = state.currentTrips
        .where((t) => t.tripId != tripId)
        .toList();
    final moved = state.currentTrips.firstWhere(
      (t) => t.tripId == tripId,
      orElse: () => throw StateError('Not found'),
    );
    final existsInPast = state.pastTrips.any((t) => t.tripId == tripId);
    if (existsInPast) {
      state = BagState(currentTrips: current, pastTrips: state.pastTrips);
      return;
    }
    state = BagState(
      currentTrips: current,
      pastTrips: <TripSummary>[...state.pastTrips, moved],
    );
  }

  /// Records a booking the backend really confirmed.
  ///
  /// [item] is the offer the funnel booked (its name, photo and own dates).
  /// Without it the trip keeps only the facts the booking itself carries — it
  /// never fills the gap with the provider's name as a "destination" or with
  /// the booking's creation time as a travel date.
  void syncFromBooking(BookingRecord booking, {TripItem? item}) {
    if (booking.status != BookingStatus.confirmed) return;
    final trip = _mapBookingToTrip(booking, item: item);
    if (_exists(trip.bookingId)) return;
    addCurrent(trip);
  }

  bool _exists(String bookingId) {
    return state.currentTrips.any((t) => t.bookingId == bookingId) ||
        state.pastTrips.any((t) => t.bookingId == bookingId);
  }

  TripSummary _mapBookingToTrip(BookingRecord booking, {TripItem? item}) {
    final itemSubtitle = item?.subtitle?.trim() ?? '';
    final metadataDestination =
        (booking.metadata['destination'] as String?)?.trim() ?? '';
    final destination = itemSubtitle.isNotEmpty
        ? itemSubtitle
        : metadataDestination;

    final itemTitle = item?.title?.trim();

    // Real travel dates only: the booked offer's own pair, else whatever the
    // booking carried. `createdAt`/`expiration` are booking-lifecycle stamps,
    // not travel dates — they are never substituted here.
    final start = item?.startsAt ?? _asDate(booking.metadata['startDate']);
    final end = item?.endsAt ?? _asDate(booking.metadata['endDate']);

    return TripSummary(
      tripId: 'trip-${booking.bookingId}',
      bookingId: booking.bookingId,
      type: booking.type,
      destination: destination,
      title: (itemTitle != null && itemTitle.isNotEmpty) ? itemTitle : null,
      imageUrl: item?.imageUrl,
      startDate: start,
      endDate: end,
      status: booking.status.name,
      total: booking.authoritativePrice,
      currency: booking.currency,
      bookingReference: booking.bookingReference,
      providerName: booking.providerName,
      travelersCount: booking.travelers.isNotEmpty
          ? booking.travelers.length
          : null,
    );
  }

  DateTime? _asDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

final bagControllerProvider = StateNotifierProvider<BagController, BagState>(
  (ref) => BagController(),
);
