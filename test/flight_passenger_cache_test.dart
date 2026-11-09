import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/core/storage/offline_cache_serializers.dart';

void main() {
  test('flight cache key changes with passenger counts', () {
    final a = flightSearchCacheKey(
      origin: 'CAI',
      destination: 'DXB',
      departure: DateTime(2026, 1, 1),
      adults: 1,
      children: 0,
      infants: 0,
    );
    final b = flightSearchCacheKey(
      origin: 'CAI',
      destination: 'DXB',
      departure: DateTime(2026, 1, 1),
      adults: 2,
      children: 1,
      infants: 1,
      childAges: const <int>[5],
      infantAges: const <int>[1],
    );
    expect(a, isNot(equals(b)));
  });

  test('flight cache key changes with child age', () {
    final a = flightSearchCacheKey(
      origin: 'CAI',
      destination: 'DXB',
      departure: DateTime(2026, 1, 1),
      adults: 1,
      children: 1,
      infants: 0,
      childAges: const <int>[5],
    );
    final b = flightSearchCacheKey(
      origin: 'CAI',
      destination: 'DXB',
      departure: DateTime(2026, 1, 1),
      adults: 1,
      children: 1,
      infants: 0,
      childAges: const <int>[6],
    );
    expect(a, isNot(equals(b)));
  });

  test('flight params copyWith preserves ages', () {
    final p = FlightSearchParams(
      origin: 'CAI',
      destination: 'DXB',
      departureDate: DateTime(2026, 1, 1),
      adults: 1,
      children: 1,
      infants: 1,
      childAges: const <int>[5],
      infantAges: const <int>[1],
    );
    final c = p.copyWith(children: 2, childAges: const <int>[5, 6]);
    expect(c.childAges, const <int>[5, 6]);
    expect(c.infantAges, const <int>[1]);
  });
}
