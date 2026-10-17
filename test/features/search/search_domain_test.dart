import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/core/domain/models/search/hotel_search_params.dart';
import 'package:tokigo/core/domain/models/search/car_search_params.dart';
import 'package:tokigo/core/domain/models/booking/booking.dart';

void main() {
  test('FlightSearchParams validation defaults', () {
    final p = FlightSearchParams(origin: 'JFK', destination: 'LAX', departureDate: DateTime(2025, 1, 1));
    expect(p.adults, 1);
    expect(p.cabinClass, 'economy');
  });

  test('HotelSearchParams creation', () {
    final p = HotelSearchParams(destination: 'Paris', checkIn: DateTime(2025, 5, 1), checkOut: DateTime(2025, 5, 3));
    expect(p.rooms, 1);
  });

  test('CarSearchParams creation', () {
    final p = CarSearchParams(
      pickupLocation: 'A',
      dropoffLocation: 'B',
      pickupDateTime: DateTime(2025, 1, 1),
      dropoffDateTime: DateTime(2025, 1, 2),
    );
    expect(p.driverAge, 25);
  });

  test('Booking price breakdown total', () {
    final pb = PriceBreakdown(basePrice: 100, taxes: 20, fees: 10, currency: 'USD');
    expect(pb.total, 130);
  });

  test('Booking status enum', () {
    expect(BookingStatus.confirmed, isNotNull);
  });
}
