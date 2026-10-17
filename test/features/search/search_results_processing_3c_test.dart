import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/domain/models/offers/customer_price.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/features/search/application/search_results_processing.dart';
import 'package:tokigo/features/search/domain/search_filters.dart';
import 'package:tokigo/features/search/domain/sort_option.dart';

/// Phase 3C — unified results processing contracts: provider-safe filtering,
/// deterministic sorting, customer-total-aware comparisons (spec point 14),
/// and the recommended = provider-order rule.

CustomerPrice _egp(double amount) => CustomerPrice(
      providerAmount: amount,
      providerCurrency: 'USD',
      customerAmount: amount,
      customerCurrency: 'EGP',
      pricingVersion: 'test',
      expiresAt: '2026-12-01',
    );

FlightOffer _flight(
  String id, {
  double price = 100,
  String currency = 'USD',
  CustomerPrice? quote,
  int? stops,
  DateTime? departure,
  Duration duration = const Duration(hours: 4),
  String airline = 'MS',
}) {
  final dep = departure ?? DateTime(2026, 10, 1, 8);
  return FlightOffer(
    id: id,
    providerId: 'p',
    providerName: 'n',
    title: 't',
    price: price,
    currency: currency,
    customerPrice: quote,
    origin: 'CAI',
    destination: 'DXB',
    departureTime: dep,
    arrivalTime: dep.add(duration),
    airline: airline,
    flightNumber: '100',
    stops: stops,
  );
}

HotelOffer _hotel(
  String id, {
  double price = 100,
  CustomerPrice? quote,
  double? rating,
  List<String> amenities = const [],
}) =>
    HotelOffer(
      id: id,
      providerId: 'p',
      providerName: 'n',
      title: 't',
      price: price,
      currency: 'USD',
      customerPrice: quote,
      city: 'Dubai',
      country: 'AE',
      checkIn: DateTime(2026, 10, 1),
      checkOut: DateTime(2026, 10, 4),
      roomType: 'std',
      rating: rating,
      amenities: amenities,
    );

CarOffer _car(
  String id, {
  double price = 100,
  CustomerPrice? quote,
  int? seats,
  String? transmission,
}) =>
    CarOffer(
      id: id,
      providerId: 'p',
      providerName: 'n',
      title: 't',
      price: price,
      currency: 'USD',
      customerPrice: quote,
      pickupLocation: 'Dubai',
      dropoffLocation: 'Dubai',
      pickupTime: DateTime(2026, 10, 1),
      dropoffTime: DateTime(2026, 10, 4),
      carType: 'sedan',
      seats: seats,
      transmission: transmission,
    );

void main() {
  group('3C — customer-total-aware sorting (spec point 14)', () {
    test('cheapest sorts by the CUSTOMER total when quotes are attached, not the provider amount', () {
      // Provider amounts are misleading: A looks cheaper in provider USD,
      // but its customer EGP total is higher.
      final a = _flight('a', price: 80, quote: _egp(5000));
      final b = _flight('b', price: 90, quote: _egp(4000));

      final sorted = sortFlightResults([a, b], SortOption.priceLowHigh);
      expect(sorted.first.id, 'b'); // cheapest CUSTOMER total wins.
    });

    test('cheapest falls back to the provider amount when no quote exists', () {
      final a = _flight('a', price: 80);
      final b = _flight('b', price: 90);
      final sorted = sortFlightResults([a, b], SortOption.priceLowHigh);
      expect(sorted.first.id, 'a');
    });

    test('sort is deterministic — equal amounts keep a stable order (id tie-breaker)', () {
      final a = _flight('zz', price: 100, quote: _egp(1000));
      final b = _flight('aa', price: 200, quote: _egp(1000));
      final first = sortFlightResults([a, b], SortOption.priceLowHigh);
      final second = sortFlightResults([b, a], SortOption.priceLowHigh);
      expect(first.map((o) => o.id), second.map((o) => o.id));
      expect(first.first.id, 'aa'); // stable tie-break by id.
    });

    test('priceHighLow mirrors priceLowHigh exactly (hotels)', () {
      final offers = [
        _hotel('x', price: 100, quote: _egp(1000)),
        _hotel('y', price: 50, quote: _egp(500)),
        _hotel('z', price: 300, quote: _egp(3000)),
      ];
      final asc = sortHotelResults(offers, SortOption.priceLowHigh);
      final desc = sortHotelResults(offers, SortOption.priceHighLow);
      expect(desc.map((o) => o.id), asc.reversed.map((o) => o.id).toList());
    });

    test('cars: cheapest by customer total', () {
      final offers = [
        _car('a', price: 10, quote: _egp(900)),
        _car('b', price: 20, quote: _egp(800)),
      ];
      final sorted = sortCarResults(offers, SortOption.priceLowHigh);
      expect(sorted.first.id, 'b');
    });
  });

  group('3C — "recommended" is provider order (never client-invented)', () {
    test('recommended is an exact passthrough for all verticals', () {
      final flights = [_flight('f2'), _flight('f1')];
      final hotels = [_hotel('h2'), _hotel('h1')];
      final cars = [_car('c2'), _car('c1')];
      expect(
        sortFlightResults(flights, SortOption.recommended).map((o) => o.id),
        ['f2', 'f1'],
      );
      expect(
        sortHotelResults(hotels, SortOption.recommended).map((o) => o.id),
        ['h2', 'h1'],
      );
      expect(
        sortCarResults(cars, SortOption.recommended).map((o) => o.id),
        ['c2', 'c1'],
      );
    });
  });

  group('3C — duration/stops/rating sorting (flights)', () {
    test('duration sorts by actual travel time', () {
      final fast = _flight('fast', duration: const Duration(hours: 2));
      final slow = _flight('slow', duration: const Duration(hours: 8));
      final sorted = sortFlightResults([slow, fast], SortOption.duration);
      expect(sorted.first.id, 'fast');
    });

    test('stops sorts non-stop first', () {
      final direct = _flight('direct', stops: 0);
      final twoStops = _flight('two', stops: 2);
      final sorted = sortFlightResults([twoStops, direct], SortOption.stops);
      expect(sorted.first.id, 'direct');
    });

    test('rating sorts highest first with nulls last (hotels)', () {
      final offers = [
        _hotel('null-rating'),
        _hotel('top', rating: 4.9),
        _hotel('mid', rating: 4.2),
      ];
      final sorted = sortHotelResults(offers, SortOption.rating);
      expect(sorted.map((o) => o.id), ['top', 'mid', 'null-rating']);
    });
  });

  group('3C — provider-safe filters (client-side post-filtering only)', () {
    test('flight filters: price window (customer total), stops, airlines', () {
      final offers = [
        _flight('in', price: 80, quote: _egp(400), stops: 0, airline: 'MS'),
        _flight('too-expensive', price: 500, quote: _egp(3000), stops: 1, airline: 'MS'),
        _flight('too-many-stops', price: 90, quote: _egp(450), stops: 2, airline: 'MS'),
        _flight('wrong-airline', price: 85, quote: _egp(420), stops: 0, airline: 'EK'),
      ];
      final filtered = applyFlightFilters(
        offers,
        const SearchFilters(priceMin: 300, priceMax: 500, maxStops: 1, airlines: ['MS']),
      );
      expect(filtered.map((o) => o.id), ['in']);
    });

    test('hotel filters: min rating + amenity ANY-match', () {
      final offers = [
        _hotel('pool', rating: 4.5, amenities: ['Pool', 'Wifi']),
        _hotel('no-pool', rating: 4.8, amenities: ['Wifi']),
        _hotel('low-rating', rating: 2.0, amenities: ['Pool']),
      ];
      final filtered = applyHotelFilters(
        offers,
        const SearchFilters(minRating: 4.0, amenities: ['Pool']),
      );
      expect(filtered.map((o) => o.id), ['pool']);
    });

    test('car filters: min seats + transmission', () {
      final offers = [
        _car('ok', seats: 5, transmission: 'Automatic'),
        _car('small', seats: 2, transmission: 'Automatic'),
        _car('manual', seats: 5, transmission: 'Manual'),
      ];
      final filtered = applyCarFilters(
        offers,
        const SearchFilters(minSeats: 4, transmission: 'Automatic'),
      );
      expect(filtered.map((o) => o.id), ['ok']);
    });

    test('empty filter set returns the list unchanged', () {
      final offers = [_flight('a'), _flight('b')];
      expect(applyFlightFilters(offers, const SearchFilters()), offers);
    });

    test('price filter uses the customer total when quoted', () {
      final cheapForCustomer = _flight('cheap', price: 80, quote: _egp(300));
      final expensiveForCustomer = _flight('expensive', price: 100, quote: _egp(3000));
      final filtered = applyFlightFilters(
        [cheapForCustomer, expensiveForCustomer],
        const SearchFilters(priceMax: 1000),
      );
      expect(filtered.map((o) => o.id), ['cheap']);
    });
  });

  group('3C — SearchFilters contract', () {
    test('transmission is part of the filter contract and emptiness', () {
      const withTransmission = SearchFilters(transmission: 'Automatic');
      expect(withTransmission.isEmpty, isFalse);
      const empty = SearchFilters();
      expect(empty.isEmpty, isTrue);
    });

    test('copyWith merges without losing untouched fields', () {
      const base = SearchFilters(minRating: 4.0, amenities: ['Pool']);
      final patched = base.copyWith(transmission: 'Automatic');
      expect(patched.minRating, 4.0);
      expect(patched.amenities, ['Pool']);
      expect(patched.transmission, 'Automatic');
    });
  });
}
