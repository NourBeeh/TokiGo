import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/flight_repository.dart';
import 'package:tokigo/core/repositories/impl/flight_repository_impl.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_serializers.dart';
import 'package:tokigo/core/usecases/search_flights_usecase.dart';
import 'package:tokigo/features/search/application/controllers/flight_search_controller.dart';

/// Records the party a search was actually run for, so a test can prove the
/// children/infants/ages really crossed the repository boundary.
class _RecordingFlightRepository implements FlightRepository {
  int calls = 0;
  int? adults;
  int? children;
  int? infants;
  List<int>? childAges;
  List<int>? infantAges;

  @override
  Future<ApiResult<List<FlightOffer>>> search({
    required String origin,
    required String destination,
    required DateTime departure,
    DateTime? returnDate,
    int? passengers,
    int? children,
    int? infants,
    List<int>? childAges,
    List<int>? infantAges,
    List<FlightSearchLeg>? legs,
    String? cabinClass,
    bool? directOnly,
  }) async {
    calls++;
    adults = passengers;
    this.children = children;
    this.infants = infants;
    this.childAges = childAges;
    this.infantAges = infantAges;
    return ApiResult.success(const <FlightOffer>[]);
  }

  @override
  Future<ApiResult<FlightOffer>> getById(String id) async =>
      ApiResult.failure(const ApiUnknownError(message: 'not implemented'));
}

void main() {
  group('A. Search request mapping', () {
    test('A1 a family search carries children and their ages', () {
      final Map<String, dynamic> body = FlightRepositoryImpl.buildSearchBody(
        origin: 'CAI',
        destination: 'DXB',
        departure: DateTime(2026, 1, 1),
        passengers: 2,
        children: 1,
        infants: 1,
        childAges: const <int>[7],
        infantAges: const <int>[1],
      );
      expect(body['passengers'], 2);
      expect(body['children'], 1);
      expect(body['infants'], 1);
      expect(body['childAges'], const <int>[7]);
      expect(body['infantAges'], const <int>[1]);
    });

    test('A2 an adults-only search omits the child/infant fields', () {
      final Map<String, dynamic> body = FlightRepositoryImpl.buildSearchBody(
        origin: 'CAI',
        destination: 'DXB',
        departure: DateTime(2026, 1, 1),
        passengers: 2,
      );
      expect(body['passengers'], 2);
      expect(body.containsKey('children'), isFalse);
      expect(body.containsKey('infants'), isFalse);
      expect(body.containsKey('childAges'), isFalse);
      expect(body.containsKey('infantAges'), isFalse);
    });

    test('A3 the usecase forwards the party to the repository', () async {
      final _RecordingFlightRepository repo = _RecordingFlightRepository();
      await SearchFlightsUseCase(repo).call(
        origin: 'CAI',
        destination: 'DXB',
        departure: DateTime(2026, 1, 1),
        passengers: 2,
        children: 1,
        infants: 1,
        childAges: const <int>[7],
        infantAges: const <int>[1],
      );
      expect(repo.adults, 2);
      expect(repo.children, 1);
      expect(repo.infants, 1);
      expect(repo.childAges, const <int>[7]);
      expect(repo.infantAges, const <int>[1]);
    });

    test('A4 the controller forwards the party end to end', () async {
      final _RecordingFlightRepository repo = _RecordingFlightRepository();
      final FlightSearchController controller = FlightSearchController(
        SearchFlightsUseCase(repo),
        MemoryOfflineCache(),
      );
      addTearDown(controller.dispose);
      await controller.search(
        FlightSearchParams(
          origin: 'CAI',
          destination: 'DXB',
          departureDate: DateTime(2026, 1, 1),
          adults: 2,
          children: 1,
          infants: 1,
          childAges: const <int>[7],
          infantAges: const <int>[1],
        ),
      );
      expect(repo.calls, 1);
      expect(repo.adults, 2);
      expect(repo.children, 1);
      expect(repo.infants, 1);
      expect(repo.childAges, const <int>[7]);
      expect(repo.infantAges, const <int>[1]);
    });
  });

  group('B. Passenger count consistency', () {
    test('B1 the request counts match the party the UI collected', () {
      const int adults = 2;
      const int children = 2;
      const int infants = 1;
      final Map<String, dynamic> body = FlightRepositoryImpl.buildSearchBody(
        origin: 'CAI',
        destination: 'DXB',
        departure: DateTime(2026, 1, 1),
        passengers: adults,
        children: children,
        infants: infants,
        childAges: const <int>[5, 8],
        infantAges: const <int>[0],
      );
      final int total = (body['passengers'] as int) +
          (body['children'] as int) +
          (body['infants'] as int);
      expect(total, adults + children + infants);
      expect((body['childAges'] as List<int>).length, children);
      expect((body['infantAges'] as List<int>).length, infants);
    });

    test('B2 the cache key distinguishes different infant ages', () {
      final String a = flightSearchCacheKey(
        origin: 'CAI',
        destination: 'DXB',
        departure: DateTime(2026, 1, 1),
        adults: 1,
        children: 0,
        infants: 1,
        infantAges: const <int>[0],
      );
      final String b = flightSearchCacheKey(
        origin: 'CAI',
        destination: 'DXB',
        departure: DateTime(2026, 1, 1),
        adults: 1,
        children: 0,
        infants: 1,
        infantAges: const <int>[1],
      );
      expect(a, isNot(equals(b)));
    });

    test('B3 the cache key distinguishes multiple adults', () {
      final String a = flightSearchCacheKey(
        origin: 'CAI',
        destination: 'DXB',
        departure: DateTime(2026, 1, 1),
        adults: 1,
        children: 0,
        infants: 0,
      );
      final String b = flightSearchCacheKey(
        origin: 'CAI',
        destination: 'DXB',
        departure: DateTime(2026, 1, 1),
        adults: 3,
        children: 0,
        infants: 0,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
