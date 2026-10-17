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
    state = BagState(currentTrips: [...state.currentTrips, trip], pastTrips: state.pastTrips);
  }

  void moveToPast(String tripId) {
    final current = state.currentTrips.where((t) => t.tripId != tripId).toList();
    final moved = state.currentTrips.firstWhere((t) => t.tripId == tripId, orElse: () => throw StateError('Not found'));
    final existsInPast = state.pastTrips.any((t) => t.tripId == tripId);
    if (existsInPast) {
      state = BagState(currentTrips: current, pastTrips: state.pastTrips);
      return;
    }
    state = BagState(currentTrips: current, pastTrips: [...state.pastTrips, moved]);
  }

  void syncFromBooking(BookingRecord booking) {
    if (booking.status != BookingStatus.confirmed) return;
    final trip = _mapBookingToTrip(booking);
    if (_exists(trip.bookingId)) return;
    // Determine if current or past based on status
    if (booking.status == BookingStatus.confirmed) {
      addCurrent(trip);
    } else {
      // fallback to past for non-confirmed (should not happen)
      state = BagState(currentTrips: state.currentTrips, pastTrips: [...state.pastTrips, trip]);
    }
  }

  bool _exists(String bookingId) {
    return state.currentTrips.any((t) => t.bookingId == bookingId) ||
        state.pastTrips.any((t) => t.bookingId == bookingId);
  }

  TripSummary _mapBookingToTrip(BookingRecord booking) {
    final destination = booking.metadata['destination'] as String? ?? booking.providerName;
    final start = booking.metadata['startDate'] as DateTime? ?? booking.createdAt;
    final end = booking.metadata['endDate'] as DateTime? ?? (booking.expiration ?? booking.createdAt.add(const Duration(days: 1)));
    final tripId = 'trip-${booking.bookingId}';
    return TripSummary(
      tripId: tripId,
      bookingId: booking.bookingId,
      type: booking.type,
      destination: destination,
      startDate: start,
      endDate: end,
      status: booking.status.name,
      total: booking.authoritativePrice,
      currency: booking.currency,
      bookingReference: booking.bookingReference,
      providerName: booking.providerName,
    );
  }
}

final bagControllerProvider = StateNotifierProvider<BagController, BagState>((ref) => BagController());
