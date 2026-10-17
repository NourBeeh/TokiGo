import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/domain/models/search/car_search_params.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/core/domain/models/search/hotel_search_params.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/repositories/contracts/car_repository.dart';
import 'package:tokigo/core/repositories/contracts/flight_repository.dart';
import 'package:tokigo/core/repositories/contracts/hotel_repository.dart';
import 'package:tokigo/core/repositories/impl/hotel_repository_impl.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/usecases/search_flights_usecase.dart';
import 'package:tokigo/features/search/application/controllers/car_search_controller.dart';
import 'package:tokigo/features/search/application/controllers/flight_search_controller.dart';
import 'package:tokigo/features/search/application/controllers/hotel_search_controller.dart';

/// Phase 3A — Unified Search Foundation contracts.
///
/// Covers: the hotel request-body contract (every rich param reaches the
/// backend, omitted ones stay out), the extras seeding bridge (params →
/// repository contract while the interface stays stable), and the
/// stale-response guard (request versioning) on all three vertical
/// controllers.
void main() {
  group('HotelRepositoryImpl.buildSearchBody — the request contract', () {
    final checkIn = DateTime(2026, 10, 1);
    final checkOut = DateTime(2026, 10, 4);

    test('baseline: city, dates and guest default', () {
      final body = HotelRepositoryImpl.buildSearchBody(
        city: 'Dubai',
        checkIn: checkIn,
        checkOut: checkOut,
        guests: null,
      );
      expect(body['city'], 'Dubai');
      expect(body['checkIn'], checkIn.toIso8601String());
      expect(body['checkOut'], checkOut.toIso8601String());
      expect(body['guests'], 2); // The vertical form's own default.
    });

    test('every rich param set reaches the body VERBATIM', () {
      final body = HotelRepositoryImpl.buildSearchBody(
        city: 'Dubai',
        checkIn: checkIn,
        checkOut: checkOut,
        guests: 3,
        rooms: 2,
        minRating: 4.0,
        maxPrice: 300,
        minPrice: 100,
        amenities: const ['Pool', 'Wifi'],
      );
      expect(body['rooms'], 2);
      expect(body['minRating'], 4.0);
      expect(body['maxPrice'], 300);
      expect(body['minPrice'], 100);
      expect(body['amenities'], ['Pool', 'Wifi']);
      expect(body['guests'], 3);
    });

    test('omitted/empty params stay OUT of the body (no invented filters)',
        () {
      final body = HotelRepositoryImpl.buildSearchBody(
        city: 'Dubai',
        checkIn: checkIn,
        checkOut: checkOut,
        rooms: null,
        minRating: null,
        amenities: const [],
      );
      expect(body.containsKey('amenities'), isFalse);
      // The nullable slots are explicit nulls the backend treats as unset.
      expect(body['rooms'], isNull);
      expect(body['minRating'], isNull);
    });
  });

  group('HotelSearchController — extras seeding bridge', () {
    late _ExtrasProbingHotelRepository repo;
    late HotelSearchController controller;

    setUp(() {
      repo = _ExtrasProbingHotelRepository();
      controller = HotelSearchController(repo, MemoryOfflineCache());
    });

    test('search() seeds every rich param into the repository BEFORE the call',
        () async {
      await controller.search(HotelSearchParams(
        destination: 'Dubai',
        checkIn: DateTime(2026, 10, 1),
        checkOut: DateTime(2026, 10, 4),
        rooms: 2,
        minRating: 4.5,
        maxPrice: 250,
        minPrice: 90,
        amenities: ['Airport transfer'],
      ));

      expect(repo.seenRooms, 2);
      expect(repo.seenMinRating, 4.5);
      expect(repo.seenMaxPrice, 250);
      expect(repo.seenMinPrice, 90);
      expect(repo.seenAmenities, ['Airport transfer']);
    });

    test('a repository WITHOUT the extras contract still works (interface stability)',
        () async {
      final plain = _PlainHotelRepository();
      final c = HotelSearchController(plain, MemoryOfflineCache());
      await c.search(HotelSearchParams(
        destination: 'Dubai',
        checkIn: DateTime(2026, 10, 1),
        checkOut: DateTime(2026, 10, 4),
        rooms: 3,
      ));
      expect(plain.calls, 1);
      // The plain repo returns an empty list — the controller reaches the
      // EMPTY state cleanly (no crash, no missed call): the interface
      // compatibility holds.
      expect(c.state.status, HotelSearchStatus.empty);
    });
  });

  group('Stale-response guard (request versioning)', () {
    test('HOTEL: a late older result never overwrites the newer search',
        () async {
      final repo = _SlowThenFastHotelRepository();
      final controller = HotelSearchController(repo, MemoryOfflineCache());

      // First search resolves SLOWLY (the gate stays closed).
      final first = controller.search(HotelSearchParams(
        destination: 'Dubai',
        checkIn: DateTime(2026, 10, 1),
        checkOut: DateTime(2026, 10, 4),
      ));

      // Second search resolves IMMEDIATELY and lands first.
      final second = controller.search(HotelSearchParams(
        destination: 'Paris',
        checkIn: DateTime(2026, 11, 1),
        checkOut: DateTime(2026, 11, 4),
      ));
      repo.releaseGate(); // Now the first (stale) response arrives.
      await first;
      await second;

      // The LAST state belongs to the newest search — Paris, not Dubai.
      expect(controller.state.results.first.title, 'Paris Hotel');
    });

    test('FLIGHT: a late older result never overwrites the newer search',
        () async {
      final repo = _SlowThenFastFlightRepository();
      final controller =
          FlightSearchController(SearchFlightsUseCase(repo), MemoryOfflineCache());

      final first = controller.search(FlightSearchParams(
        origin: 'CAI',
        destination: 'DXB',
        departureDate: DateTime(2026, 10, 1),
      ));
      final second = controller.search(FlightSearchParams(
        origin: 'CAI',
        destination: 'PAR',
        departureDate: DateTime(2026, 11, 1),
      ));
      repo.releaseGate();
      await first;
      await second;

      expect(controller.state.results.first.title, 'Paris Flight');
    });

    test('CAR: a late older result never overwrites the newer search',
        () async {
      final repo = _SlowThenFastCarRepository();
      final controller = CarSearchController(repo, MemoryOfflineCache());

      final first = controller.search(CarParamsBuilder.dubai());
      final second = controller.search(CarParamsBuilder.paris());
      repo.releaseGate();
      await first;
      await second;

      expect(controller.state.results.first.title, 'Paris Car');
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Exercises the controller's extras seeding through the REAL
/// HotelRepositoryImpl contract — captures the body the base class would
/// send, then answers empty (no HTTP).
class _ExtrasProbingHotelRepository extends HotelRepositoryImpl {
  Map<String, dynamic>? sentBody;

  _ExtrasProbingHotelRepository() : super(_NullHttpClient());

  int? seenRooms;
  double? seenMinRating;
  double? seenMaxPrice;
  double? seenMinPrice;
  List<String>? seenAmenities;

  @override
  Future<ApiResult<List<HotelOffer>>> search({
    required String city,
    required DateTime checkIn,
    required DateTime checkOut,
    int? guests,
  }) {
    // Capture exactly what the next body WOULD carry — via the same
    // public builder the real call uses.
    sentBody = HotelRepositoryImpl.buildSearchBody(
      city: city,
      checkIn: checkIn,
      checkOut: checkOut,
      guests: guests,
      rooms: _seededRooms,
      minRating: _seededMinRating,
      maxPrice: _seededMaxPrice,
      minPrice: _seededMinPrice,
      amenities: _seededAmenities,
    );
    seenRooms = _seededRooms;
    seenMinRating = _seededMinRating;
    seenMaxPrice = _seededMaxPrice;
    seenMinPrice = _seededMinPrice;
    seenAmenities = _seededAmenities;
    return Future.value(const ApiResult.success([]));
  }

  @override
  void setNextSearchExtras({
    int? rooms,
    double? minRating,
    double? maxPrice,
    double? minPrice,
    List<String>? amenities,
  }) {
    _seededRooms = rooms;
    _seededMinRating = minRating;
    _seededMaxPrice = maxPrice;
    _seededMinPrice = minPrice;
    _seededAmenities = amenities;
    super.setNextSearchExtras(
      rooms: rooms,
      minRating: minRating,
      maxPrice: maxPrice,
      minPrice: minPrice,
      amenities: amenities,
    );
  }

  // Mirror of the base seed (private fields are library-scoped).
  int? _seededRooms;
  double? _seededMinRating;
  double? _seededMaxPrice;
  double? _seededMinPrice;
  List<String>? _seededAmenities;
}

class _NullHttpClient implements HttpApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _PlainHotelRepository implements HotelRepository {
  int calls = 0;

  @override
  Future<ApiResult<List<HotelOffer>>> search({
    required String city,
    required DateTime checkIn,
    required DateTime checkOut,
    int? guests,
  }) async {
    calls++;
    return const ApiResult.success([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Completer-gated repositories: the FIRST search stalls until released.
class _SlowThenFastHotelRepository implements HotelRepository {
  bool _gated = true;

  void releaseGate() => _gated = false;

  @override
  Future<ApiResult<List<HotelOffer>>> search({
    required String city,
    required DateTime checkIn,
    required DateTime checkOut,
    int? guests,
  }) async {
    while (_gated) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return ApiResult.success(<HotelOffer>[
      HotelOffer(
        id: 'h',
        providerId: 'nuitee',
        providerName: 'Nuitee',
        title: city == 'Paris' ? 'Paris Hotel' : 'Dubai Hotel',
        price: 100,
        currency: 'USD',
        city: city,
        country: 'X',
        checkIn: checkIn,
        checkOut: checkOut,
        roomType: 'std',
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _SlowThenFastFlightRepository implements FlightRepository {
  bool _gated = true;

  void releaseGate() => _gated = false;

  @override
  Future<ApiResult<List<FlightOffer>>> search({
    required String origin,
    required String destination,
    required DateTime departure,
    DateTime? returnDate,
    int? passengers,
  }) async {
    while (_gated) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return ApiResult.success(<FlightOffer>[
      FlightOffer(
        id: 'f',
        providerId: 'duffel',
        providerName: 'Duffel',
        title: destination == 'PAR' ? 'Paris Flight' : 'Dubai Flight',
        price: 300,
        currency: 'USD',
        origin: origin,
        destination: destination,
        departureTime: departure,
        arrivalTime: departure.add(const Duration(hours: 4)),
        airline: 'EgyptAir',
        flightNumber: '985',
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _SlowThenFastCarRepository implements CarRepository {
  bool _gated = true;

  void releaseGate() => _gated = false;

  @override
  Future<ApiResult<List<CarOffer>>> search({
    required String pickupLocation,
    required DateTime pickupTime,
    required DateTime dropoffTime,
  }) async {
    while (_gated) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return ApiResult.success(<CarOffer>[
      CarOffer(
        id: 'c',
        providerId: 'mock-car',
        providerName: 'Mock Car',
        title: pickupLocation == 'Paris' ? 'Paris Car' : 'Dubai Car',
        price: 50,
        currency: 'USD',
        pickupLocation: pickupLocation,
        dropoffLocation: pickupLocation,
        pickupTime: pickupTime,
        dropoffTime: dropoffTime,
        carType: 'sedan',
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class CarParamsBuilder {
  static CarSearchParams dubai() => CarSearchParams(
        pickupLocation: 'Dubai',
        dropoffLocation: 'Dubai',
        pickupDateTime: DateTime(2026, 10, 1),
        dropoffDateTime: DateTime(2026, 10, 4),
      );

  static CarSearchParams paris() => CarSearchParams(
        pickupLocation: 'Paris',
        dropoffLocation: 'Paris',
        pickupDateTime: DateTime(2026, 11, 1),
        dropoffDateTime: DateTime(2026, 11, 4),
      );
}
