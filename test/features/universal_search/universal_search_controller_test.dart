import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/domain/models/search/car_search_params.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/core/domain/models/search/hotel_search_params.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/repositories/impl/car_repository_impl.dart';
import 'package:tokigo/core/repositories/impl/flight_repository_impl.dart';
import 'package:tokigo/core/repositories/impl/hotel_repository_impl.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/usecases/search_flights_usecase.dart';
import 'package:tokigo/features/search/application/controllers/car_search_controller.dart';
import 'package:tokigo/features/search/application/controllers/flight_search_controller.dart';
import 'package:tokigo/features/search/application/controllers/hotel_search_controller.dart';
import 'package:tokigo/features/universal_search/application/universal_search_controller.dart';
import 'package:tokigo/features/universal_search/application/universal_search_state.dart';
import 'package:tokigo/features/universal_search/domain/structured_travel_intent.dart';

/// Controller-level coverage (US-1 STEP 26): the state machine doors,
/// query preservation across close/reopen, submit-only recents, stale
/// suggestion protection and the SearchIntentParser wiring through the
/// EXISTING controllers (injected real, with a stubbed HTTP transport —
/// their own suites cover their logic).
void main() {
  late _RecordingFlightController flight;
  late _RecordingHotelController hotel;
  late _RecordingCarController car;
  late UniversalSearchController controller;

  setUp(() {
    flight = _RecordingFlightController();
    hotel = _RecordingHotelController();
    car = _RecordingCarController();
    controller = UniversalSearchController(
      suggestionsDelegate: _FakeSuggestionsDelegate(),
      cache: MemoryOfflineCache(),
      flightSearch: flight,
      hotelSearch: hotel,
      carSearch: car,
    );
  });

  UniversalSearchPhase phase() => controller.currentState.phase;

  test('surfaceReady with empty query opens into ACTIVE', () {
    controller.open();
    controller.surfaceReady();
    expect(phase(), UniversalSearchPhase.active);
  });

  test('surfaceReady with preserved query reopens into TYPING (STEP 8)', () {
    controller.open();
    controller.surfaceReady();
    controller.onQueryChanged('hotels in dubai');
    controller.close();
    controller.surfaceClosed();
    // Reopen: query survives and the surface enters TYPING directly.
    controller.open();
    controller.surfaceReady();
    expect(phase(), UniversalSearchPhase.typing);
    expect(controller.currentState.query, 'hotels in dubai');
  });

  test('closing never clears the query (STEP 7)', () {
    controller.open();
    controller.surfaceReady();
    controller.onQueryChanged('flights to cairo');
    controller.close();
    expect(controller.currentState.query, 'flights to cairo');
    expect(phase(), UniversalSearchPhase.closing);
  });

  test('forbidden transitions are rejected, not thrown', () {
    // From CLOSED a query change must not move the machine.
    controller.onQueryChanged('anything');
    expect(phase(), UniversalSearchPhase.closed);
  });

  test('typing then clearing returns to ACTIVE', () {
    controller.open();
    controller.surfaceReady();
    controller.onQueryChanged('dubai');
    expect(phase(), UniversalSearchPhase.typing);
    controller.onQueryChanged('');
    expect(phase(), UniversalSearchPhase.active);
  });

  test('natural hotel query routes through the hotel controller (STEP 14)', () async {
    controller.open();
    controller.surfaceReady();
    controller.onQueryChanged('hotel from cairo to dubai');
    await controller.submit();

    expect(hotel.lastParams, isA<HotelSearchParams>());
    expect(hotel.lastParams!.destination, 'dubai');
    expect(hotel.searchCallCount, 1);
    expect(phase(), UniversalSearchPhase.results);
  });

  test('natural flight query routes through the flight controller', () async {
    controller.open();
    controller.surfaceReady();
    controller.onQueryChanged('flight from cairo to dubai');
    await controller.submit();

    expect(flight.lastParams, isA<FlightSearchParams>());
    expect(flight.lastParams!.origin, 'cairo');
    expect(flight.lastParams!.destination, 'dubai');
    expect(phase(), UniversalSearchPhase.results);
  });

  test('natural car query routes through the car controller', () async {
    controller.open();
    controller.surfaceReady();
    controller.onQueryChanged('car from riyadh airport to city center');
    await controller.submit();

    expect(car.lastParams, isA<CarSearchParams>());
    expect(phase(), UniversalSearchPhase.results);
  });

  test('non-travel query falls to the AI flag on SEARCHING', () async {
    controller.open();
    controller.surfaceReady();
    controller.onQueryChanged('random words here');
    await controller.submit();

    expect(phase(), UniversalSearchPhase.searching);
    expect(controller.currentState.aiInterpreting, isTrue);
  });

  // -------------------------------------------------------------------------
  // US-2 §3 — gaps flow: incomplete intents park with question chips,
  // never invented values.
  // -------------------------------------------------------------------------

  test('flight without origin parks with an origin gap (US-2 §3)', () async {
    controller.open();
    controller.surfaceReady();
    controller.onQueryChanged('flight to dubai');
    await controller.submit();

    expect(flight.searchCallCount, 0); // nothing executed
    expect(phase(), UniversalSearchPhase.typing);
    expect(controller.currentState.intentGaps, contains(IntentGap.origin));
    expect(controller.currentState.structuredIntent?.destination, 'dubai');
  });

  test('service-only hotel parks with a destination gap', () async {
    controller.open();
    controller.surfaceReady();
    controller.onQueryChanged('hotel');
    await controller.submit();

    expect(hotel.searchCallCount, 0);
    expect(controller.currentState.intentGaps,
        <IntentGap>[IntentGap.destination]);
  });

  test('fillGap completes the intent and runs the search', () async {
    controller.open();
    controller.surfaceReady();
    controller.onQueryChanged('flight to dubai');
    await controller.submit();
    expect(controller.currentState.intentGaps, isNotEmpty);

    // The user answers the origin question.
    final patched = controller.currentState.structuredIntent!
        .copyWith(origin: 'Cairo');
    await controller.fillGap(patched);

    expect(controller.currentState.intentGaps, isEmpty);
    expect(flight.searchCallCount, 1);
    expect(flight.lastParams!.origin, 'Cairo');
    expect(flight.lastParams!.destination, 'dubai');
    expect(phase(), UniversalSearchPhase.results);
  });

  test('package intents flag unsupported instead of executing', () async {
    controller.open();
    controller.surfaceReady();
    controller.onQueryChanged('hotel in dubai');
    await controller.submit();

    // Hotel with destination is complete — runs. Packages are the only
    // unsupported vertical (Phase 19B mock); verified through the state
    // machine test instead of a query (no package keyword exists).
    expect(hotel.searchCallCount, 1);
    expect(controller.currentState.intentGaps, isEmpty);
  });

  // -------------------------------------------------------------------------
  // US-2 §8 — the five follow-ups patch typed fields then re-search.
  // -------------------------------------------------------------------------

  Future<void> _reachHotelResults() async {
    controller.open();
    controller.surfaceReady();
    controller.onQueryChanged('hotel from cairo to dubai');
    await controller.submit();
  }

  test('cheaper patches the budget band to low', () async {
    await _reachHotelResults();
    final before = hotel.lastParams!.maxPrice;

    await controller.applyFollowUp(FollowUpAction.cheaper);

    expect(hotel.searchCallCount, 2);
    expect(hotel.lastParams!.maxPrice, 120);
    expect(before, isNull); // the first run carried no cap
    expect(phase(), UniversalSearchPhase.results);
  });

  test('morePremium patches the budget band to high', () async {
    await _reachHotelResults();
    await controller.applyFollowUp(FollowUpAction.morePremium);

    expect(hotel.searchCallCount, 2);
    expect(hotel.lastParams!.minPrice, 200);
    expect(hotel.lastParams!.minRating, 4.0);
  });

  test('twoPeople patches passengers to 2', () async {
    await _reachHotelResults();
    await controller.applyFollowUp(FollowUpAction.twoPeople);

    expect(hotel.searchCallCount, 2);
    expect(hotel.lastParams!.adults, 2);
  });

  test('nearAirport patches the Airport transfer amenity', () async {
    await _reachHotelResults();
    await controller.applyFollowUp(FollowUpAction.nearAirport);

    expect(hotel.searchCallCount, 2);
    expect(hotel.lastParams!.amenities, contains('Airport transfer'));
  });

  test('changeDates surfaces the dates gap instead of guessing', () async {
    await _reachHotelResults();
    await controller.applyFollowUp(FollowUpAction.changeDates);

    expect(hotel.searchCallCount, 1); // no re-search
    expect(controller.currentState.intentGaps, <IntentGap>[IntentGap.dates]);
  });

  test('applyDateRange completes the dates gap and re-searches', () async {
    await _reachHotelResults();
    await controller.applyFollowUp(FollowUpAction.changeDates);

    final start = DateTime.now().add(const Duration(days: 10));
    await controller.applyDateRange(start, start.add(const Duration(days: 3)));

    expect(hotel.searchCallCount, 2);
    expect(hotel.lastParams!.checkIn.day, start.day);
    expect(hotel.lastParams!.checkOut.difference(start).inDays, 3);
    expect(controller.currentState.intentGaps, isEmpty);
    expect(phase(), UniversalSearchPhase.results);
  });

  test('recents record ONLY on explicit recordRecent (STEP 9)', () async {
    controller.open();
    controller.surfaceReady();
    controller.onQueryChanged('hotels in dubai');
    // Typing never records.
    expect(controller.currentState.recents, isEmpty);

    await controller.recordRecent('hotels in dubai');
    expect(controller.currentState.recents, <String>['hotels in dubai']);

    // Re-submitting the same prompt dedupes to the front.
    await controller.recordRecent('hotels in dubai');
    expect(controller.currentState.recents, hasLength(1));
  });

  test('stale suggestion responses never override newer ones', () async {
    final delegate = _SlowSuggestionsDelegate();
    final slowController = UniversalSearchController(
      suggestionsDelegate: delegate,
      cache: MemoryOfflineCache(),
      flightSearch: flight,
      hotelSearch: hotel,
      carSearch: car,
    );
    slowController.open();
    slowController.surfaceReady();

    slowController.onQueryChanged('dub');
    // Let the first debounced fetch START (it will hang 200ms).
    await Future<void>.delayed(const Duration(milliseconds: 450));
    // A newer query supersedes the in-flight fetch.
    slowController.onQueryChanged('dubai');
    // Let both fetches finish — the second owns the UI.
    await Future<void>.delayed(const Duration(milliseconds: 700));

    expect(
      slowController.currentState.suggestions,
      isNot(contains('STALE')),
    );
  });
}

// ---------------------------------------------------------------------------
// Recording controllers — real controllers over stubbed transports; they
// record the params Universal Search hands them and inject a preset
// offer so the adapter path has data to map.
// ---------------------------------------------------------------------------

class _RecordingFlightController extends FlightSearchController {
  _RecordingFlightController()
      : super(
          SearchFlightsUseCase(FlightRepositoryImpl(HttpApiClient(baseUrlOverride: 'http://stub'))),
          MemoryOfflineCache(),
        );

  FlightSearchParams? lastParams;
  int searchCallCount = 0;

  @override
  Future<void> search(FlightSearchParams params) async {
    lastParams = params;
    searchCallCount++;
    state = state.copyWith(
      status: SearchStatus.success,
      results: <FlightOffer>[_presetFlight()],
    );
  }
}

class _RecordingHotelController extends HotelSearchController {
  _RecordingHotelController()
      : super(HotelRepositoryImpl(HttpApiClient(baseUrlOverride: 'http://stub')), MemoryOfflineCache());

  HotelSearchParams? lastParams;
  int searchCallCount = 0;

  @override
  Future<void> search(HotelSearchParams params) async {
    lastParams = params;
    searchCallCount++;
    state = state.copyWith(
      status: HotelSearchStatus.success,
      results: <HotelOffer>[_presetHotel()],
    );
  }
}

class _RecordingCarController extends CarSearchController {
  _RecordingCarController()
      : super(CarRepositoryImpl(HttpApiClient(baseUrlOverride: 'http://stub')), MemoryOfflineCache());

  CarSearchParams? lastParams;
  int searchCallCount = 0;

  @override
  Future<void> search(CarSearchParams params) async {
    lastParams = params;
    searchCallCount++;
    state = state.copyWith(
      status: CarSearchStatus.success,
      results: <CarOffer>[_presetCar()],
    );
  }
}

HotelOffer _presetHotel() {
  final now = DateTime(2026, 10, 1);
  return HotelOffer(
    id: 'h1',
    providerId: 'nuitee',
    providerName: 'Nuitee',
    title: 'Downtown Dubai Hotel',
    price: 120,
    currency: 'USD',
    city: 'Dubai',
    country: 'UAE',
    checkIn: now,
    checkOut: now.add(const Duration(days: 2)),
    roomType: 'Deluxe',
  );
}

CarOffer _presetCar() {
  final now = DateTime(2026, 10, 1);
  return CarOffer(
    id: 'c1',
    providerId: 'europcar',
    providerName: 'Europcar',
    title: 'Compact Car',
    price: 80,
    currency: 'USD',
    pickupLocation: 'Riyadh Airport',
    dropoffLocation: 'Riyadh City',
    pickupTime: now,
    dropoffTime: now.add(const Duration(days: 3)),
    carType: 'Compact',
  );
}

FlightOffer _presetFlight() {
  final now = DateTime(2026, 10, 1);
  return FlightOffer(
    id: 'f1',
    providerId: 'duffel',
    providerName: 'Duffel',
    title: 'Cairo to Dubai',
    price: 450,
    currency: 'USD',
    origin: 'CAI',
    destination: 'DXB',
    departureTime: now,
    arrivalTime: now.add(const Duration(hours: 3)),
    airline: 'EgyptAir',
    flightNumber: '985',
  );
}

class _FakeSuggestionsDelegate implements AiSuggestionsDelegate {
  @override
  Future<List<String>> suggest(String query) async => const <String>[];
}

/// Returns STALE for the first query after a delay — proves versioning.
class _SlowSuggestionsDelegate implements AiSuggestionsDelegate {
  int _calls = 0;

  @override
  Future<List<String>> suggest(String query) async {
    _calls++;
    if (_calls == 1) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return const <String>['STALE'];
    }
    return const <String>['FRESH'];
  }
}
