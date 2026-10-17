import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/features/bag/domain/trip.dart';

void main() {
  test('trip summary mapping', () {
    final trip = TripSummary(
      tripId: 't1',
      bookingId: 'b1',
      type: 'flight',
      destination: 'Paris',
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 1, 5),
      status: 'confirmed',
      total: 500,
      currency: 'USD',
      bookingReference: 'REF123',
      providerName: 'ProviderX',
    );
    expect(trip.bookingId, 'b1');
    expect(trip.destination, 'Paris');
  });
}
