import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/mappers/offer_mapper_fixed.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';

void main() {
  test('mapOffer flight parses dates and fields', () {
    final json = {
      'type': 'flight',
      'id': 'f1',
      'providerId': 'p1',
      'providerName': 'P',
      'title': 'NYC-LON',
      'price': 299.99,
      'currency': 'USD',
      'origin': 'NYC',
      'destination': 'LON',
      'departureTime': '2025-01-01T10:00:00Z',
      'arrivalTime': '2025-01-01T22:00:00Z',
      'airline': 'AA',
      'flightNumber': 'AA100',
      'stops': 0,
      'cabinClass': 'economy',
    };
    final offer = mapOffer(json) as FlightOffer;
    expect(offer.id, 'f1');
    expect(offer.origin, 'NYC');
    expect(offer.destination, 'LON');
    expect(offer.airline, 'AA');
    expect(offer.departureTime.toUtc().toIso8601String(), '2025-01-01T10:00:00.000Z');
  });
}
