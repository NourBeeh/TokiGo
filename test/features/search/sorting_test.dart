import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/features/search/application/sort_utils.dart';
import 'package:tokigo/features/search/domain/sort_option.dart';

void main() {
  test('sort flights by price low high', () {
    final a = FlightOffer(id: '1', providerId: 'p', providerName: 'n', title: 't', price: 200, currency: 'USD', origin: 'A', destination: 'B', departureTime: DateTime.now(), arrivalTime: DateTime.now().add(const Duration(hours: 2)), airline: 'AA', flightNumber: '100');
    final b = FlightOffer(id: '2', providerId: 'p', providerName: 'n', title: 't', price: 100, currency: 'USD', origin: 'A', destination: 'B', departureTime: DateTime.now(), arrivalTime: DateTime.now().add(const Duration(hours: 2)), airline: 'BB', flightNumber: '200');
    final sorted = sortFlights([a, b], SortOption.priceLowHigh);
    expect(sorted.first.price, 100);
  });

  test('sort flights by stops', () {
    final a = FlightOffer(id: '1', providerId: 'p', providerName: 'n', title: 't', price: 200, currency: 'USD', origin: 'A', destination: 'B', departureTime: DateTime.now(), arrivalTime: DateTime.now().add(const Duration(hours: 2)), airline: 'AA', flightNumber: '100', stops: 2);
    final b = FlightOffer(id: '2', providerId: 'p', providerName: 'n', title: 't', price: 100, currency: 'USD', origin: 'A', destination: 'B', departureTime: DateTime.now(), arrivalTime: DateTime.now().add(const Duration(hours: 2)), airline: 'BB', flightNumber: '200', stops: 0);
    final sorted = sortFlights([a, b], SortOption.stops);
    expect(sorted.first.stops, 0);
  });
}
