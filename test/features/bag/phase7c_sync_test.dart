import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/features/bag/application/bag_controller.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/core/domain/models/booking/booking.dart';
import 'package:tokigo/core/domain/models/booking/booking.dart' as models;
import 'package:tokigo/core/domain/models/booking/booking.dart';


void main() {
  test('confirmed booking creates trip in currentTrips', () {
    final bag = BagController();
    final booking = BookingRecord(
      bookingId: 'b1',
      userId: 'u1',
      offerId: 'o1',
      providerId: 'p1',
      providerName: 'ProviderX',
      type: 'flight',
      status: BookingStatus.confirmed,
      currency: 'USD',
      authoritativePrice: 500,
      priceBreakdown: models.PriceBreakdown.empty,
      travelers: const [],
      bookingReference: 'REF123',
      createdAt: DateTime(2025,1,1),
      updatedAt: DateTime.now(),
      metadata: {'destination': 'Paris'},
    );
    bag.syncFromBooking(booking);
    expect(bag.state.currentTrips.length, 1);
    expect(bag.state.currentTrips.first.bookingId, 'b1');
  });

  test('duplicate bookingId is ignored', () {
    final bag = BagController();
    final booking = BookingRecord(
      bookingId: 'b1',
      userId: 'u1',
      offerId: 'o1',
      providerId: 'p1',
      providerName: 'ProviderX',
      type: 'flight',
      status: BookingStatus.confirmed,
      currency: 'USD',
      authoritativePrice: 500,
      priceBreakdown: models.PriceBreakdown.empty,
      travelers: const [],
      bookingReference: 'REF123',
      createdAt: DateTime(2025,1,1),
      updatedAt: DateTime.now(),
    );
    bag.syncFromBooking(booking);
    bag.syncFromBooking(booking);
    expect(bag.state.currentTrips.length, 1);
  });

  test('non-confirmed booking does not create trip', () {
    final bag = BagController();
    final booking = BookingRecord(
      bookingId: 'b2',
      userId: 'u1',
      offerId: 'o2',
      providerId: 'p2',
      providerName: 'ProviderY',
      type: 'hotel',
      status: BookingStatus.pending,
      currency: 'USD',
      authoritativePrice: 300,
      priceBreakdown: models.PriceBreakdown.empty,
      travelers: const [],
      bookingReference: 'REF456',
      createdAt: DateTime(2025,1,1),
      updatedAt: DateTime.now(),
    );
    bag.syncFromBooking(booking);
    expect(bag.state.currentTrips, isEmpty);
  });

  test('TripSummary mapping correct fields', () {
    final bag = BagController();
    final booking = BookingRecord(
      bookingId: 'b3',
      userId: 'u1',
      offerId: 'o3',
      providerId: 'p3',
      providerName: 'ProviderZ',
      type: 'car',
      status: BookingStatus.confirmed,
      currency: 'EUR',
      authoritativePrice: 200,
      priceBreakdown: models.PriceBreakdown.empty,
      travelers: const [],
      bookingReference: 'REF789',
      createdAt: DateTime(2025,5,10),
      updatedAt: DateTime.now(),
      metadata: {
        'destination': 'Berlin',
        'startDate': DateTime(2025,6,1),
        'endDate': DateTime(2025,6,5),
      },
    );
    bag.syncFromBooking(booking);
    final trip = bag.state.currentTrips.first;
    expect(trip.bookingId, 'b3');
    expect(trip.type, 'car');
    expect(trip.destination, 'Berlin');
    expect(trip.providerName, 'ProviderZ');
    expect(trip.bookingReference, 'REF789');
    expect(trip.currency, 'EUR');
    expect(trip.total, 200);
    expect(trip.status, 'confirmed');
  });
}
