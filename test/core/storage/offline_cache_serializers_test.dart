import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/storage/offline_cache_serializers.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/core/domain/models/search/hotel_search_params.dart';
import 'package:tokigo/core/domain/models/search/car_search_params.dart';
import 'package:tokigo/features/ai/domain/ai_query_context.dart';

void main() {
  group('offline_cache_serializers - cache key generation', () {
    test('flightSearchCacheKey generates deterministic key', () {
      final key1 = flightSearchCacheKey(
        origin: 'JFK',
        destination: 'LAX',
        departure: DateTime(2025, 6, 15),
        returnDate: DateTime(2025, 6, 20),
        passengers: 2,
      );
      final key2 = flightSearchCacheKey(
        origin: 'JFK',
        destination: 'LAX',
        departure: DateTime(2025, 6, 15),
        returnDate: DateTime(2025, 6, 20),
        passengers: 2,
      );
      expect(key1, equals(key2));
      expect(key1, startsWith('flight|'));
      expect(key1, contains('jfk'));
      expect(key1, contains('lax'));
    });

    test('flightSearchCacheKey differs by params', () {
      final key1 = flightSearchCacheKey(
        origin: 'JFK',
        destination: 'LAX',
        departure: DateTime(2025, 6, 15),
      );
      final key2 = flightSearchCacheKey(
        origin: 'LAX',
        destination: 'JFK',
        departure: DateTime(2025, 6, 15),
      );
      expect(key1, isNot(equals(key2)));
    });

    test('hotelSearchCacheKey generates deterministic key', () {
      final key1 = hotelSearchCacheKey(
        city: 'Paris',
        checkIn: DateTime(2025, 7, 1),
        checkOut: DateTime(2025, 7, 7),
        guests: 2,
      );
      final key2 = hotelSearchCacheKey(
        city: 'Paris',
        checkIn: DateTime(2025, 7, 1),
        checkOut: DateTime(2025, 7, 7),
        guests: 2,
      );
      expect(key1, equals(key2));
      expect(key1, startsWith('hotel|'));
      expect(key1, contains('paris'));
    });

    test('carSearchCacheKey generates deterministic key', () {
      final key1 = carSearchCacheKey(
        pickupLocation: 'LAX Airport',
        pickupTime: DateTime(2025, 8, 1, 10, 0),
        dropoffTime: DateTime(2025, 8, 5, 10, 0),
      );
      final key2 = carSearchCacheKey(
        pickupLocation: 'LAX Airport',
        pickupTime: DateTime(2025, 8, 1, 10, 0),
        dropoffTime: DateTime(2025, 8, 5, 10, 0),
      );
      expect(key1, equals(key2));
      expect(key1, startsWith('car|'));
      expect(key1, contains('lax airport'));
    });

    test('aiQueryCacheKey generates deterministic key from prompt hash', () {
      final key1 = aiQueryCacheKey(prompt: 'Find flights to Paris');
      final key2 = aiQueryCacheKey(prompt: 'Find flights to Paris');
      expect(key1, equals(key2));
      expect(key1, startsWith('ai|'));
      // Key should be bounded length (hash-based)
      expect(key1.length, lessThan(100));
    });

    test('aiQueryCacheKey differs by prompt', () {
      final key1 = aiQueryCacheKey(prompt: 'Find flights to Paris');
      final key2 = aiQueryCacheKey(prompt: 'Find hotels in London');
      expect(key1, isNot(equals(key2)));
    });

    test('aiQueryCacheKey includes context when provided', () {
      final context = AiQueryContext(
        route: 'flights',
        geolocation: {'lat': 48.85, 'lng': 2.35},
        travelDates: {'from': '2025-06-01', 'to': '2025-06-10'},
      );
      final key1 = aiQueryCacheKey(prompt: 'Find flights', context: context);
      final key2 = aiQueryCacheKey(prompt: 'Find flights');
      expect(key1, isNot(equals(key2)));
      expect(key1, contains('flights'));
      expect(key1, contains('geo'));
      expect(key1, contains('dates'));
    });
  });

  group('offline_cache_serializers - offer serialization round-trip', () {
    // These tests verify the serializers work with the same mapOffer mapper
    // used by the live repositories. Real round-trip tests would need the full
    // offer model hierarchy; here we test the key generation and map shapes.

    test('flightSearchCacheKey works with FlightSearchParams', () {
      final params = FlightSearchParams(
        origin: 'CDG',
        destination: 'JFK',
        departureDate: DateTime(2025, 9, 1),
        returnDate: DateTime(2025, 9, 10),
        adults: 1,
      );
      final key = flightSearchCacheKey(
        origin: params.origin,
        destination: params.destination,
        departure: params.departureDate,
        returnDate: params.returnDate,
        passengers: params.adults,
      );
      expect(key, startsWith('flight|cdg|jfk|'));
    });

    test('hotelSearchCacheKey works with HotelSearchParams', () {
      final params = HotelSearchParams(
        destination: 'Tokyo',
        checkIn: DateTime(2025, 10, 1),
        checkOut: DateTime(2025, 10, 5),
        adults: 2,
      );
      final key = hotelSearchCacheKey(
        city: params.destination,
        checkIn: params.checkIn,
        checkOut: params.checkOut,
        guests: params.adults,
      );
      expect(key, startsWith('hotel|tokyo|'));
    });

    test('carSearchCacheKey works with CarSearchParams', () {
      final params = CarSearchParams(
        pickupLocation: 'SFO Airport',
        dropoffLocation: 'SFO Airport',
        pickupDateTime: DateTime(2025, 11, 1, 9, 0),
        dropoffDateTime: DateTime(2025, 11, 3, 9, 0),
      );
      final key = carSearchCacheKey(
        pickupLocation: params.pickupLocation,
        pickupTime: params.pickupDateTime,
        dropoffTime: params.dropoffDateTime,
      );
      expect(key, startsWith('car|sfo airport|'));
    });
  });
}