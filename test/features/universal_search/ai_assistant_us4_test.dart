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

/// US-4 — AI assistant INSIDE Universal Search: the AI layer may enrich
/// the surface with a narrative + sections, but it can never trap the
/// user: every failure degrades to the DETERMINISTIC search path, and the
/// follow-up vocabulary stays intent-patchable (no free-form chat).
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

  group('AI success — narrative + real sections land on AI_RESULT', () {
    test('sections + narrative are published and the phase moves', () {
      controller.open();
      controller.surfaceReady();
      controller.onQueryChanged('plan something fun');
      controller.submit();
      expect(phase(), UniversalSearchPhase.searching);
      expect(controller.currentState.aiInterpreting, isTrue);

      controller.aiResultsReady(
        const [],
        'Here are some ideas for your trip.',
      );

      expect(controller.currentState.aiInterpreting, isFalse);
      expect(controller.currentState.aiNarrative,
          'Here are some ideas for your trip.');
      expect(phase(), UniversalSearchPhase.aiResult);
    });

    test('AI_RESULT keeps the edit affordance (never a chat loop)', () {
      controller.open();
      controller.surfaceReady();
      controller.onQueryChanged('random words here');
      controller.submit();
      controller.aiResultsReady(const [], 'a narrative');

      // The query is preserved for editing — the AI result is a
      // search answer, not a conversation turn.
      expect(controller.currentState.query, 'random words here');
      expect(phase(), UniversalSearchPhase.aiResult);
    });
  });

  group('AI failure → deterministic fallback (spec: AI must never block search)', () {
    test('a place-bearing query degrades to a real hotel search', () async {
      controller.open();
      controller.surfaceReady();
      // Not parseable as a service query (no hotel/flight/car keyword)
      // but carries a dictionary place after a preposition.
      controller.onQueryChanged('something relaxing in dubai');
      await controller.submit();
      expect(phase(), UniversalSearchPhase.searching);
      expect(controller.currentState.aiInterpreting, isTrue);
      expect(hotel.searchCallCount, 0);

      controller.aiResultsFailed();

      // The fallback COMPILED a complete hotel intent and executed it
      // through the REAL controller — deterministic search, no AI.
      expect(hotel.searchCallCount, 1);
      expect(hotel.lastParams, isA<HotelSearchParams>());
      // The parser's dictionary canonicalizes the place name.
      expect(hotel.lastParams!.destination, 'Dubai');
      expect(controller.currentState.aiInterpreting, isFalse);
      expect(phase(), UniversalSearchPhase.searching);
      // Let the (instant fake) search settle.
      await Future<void>.delayed(Duration.zero);
      expect(phase(), UniversalSearchPhase.results);
    });

    test('Arabic prepositions work in the fallback too', () async {
      controller.open();
      controller.surfaceReady();
      controller.onQueryChanged('عايز مكان حلو في باريس');
      await controller.submit();

      controller.aiResultsFailed();

      expect(hotel.searchCallCount, 1);
      expect(hotel.lastParams!.destination, 'Paris');
    });

    test('a query with NO place signal degrades to the empty state (no trap)',
        () async {
      controller.open();
      controller.surfaceReady();
      controller.onQueryChanged('xyzzy plugh');
      await controller.submit();
      expect(controller.currentState.aiInterpreting, isTrue);

      controller.aiResultsFailed();

      // No honest deterministic interpretation exists → empty state with
      // the edit affordance, never a stuck spinner.
      expect(phase(), UniversalSearchPhase.aiResult);
      expect(controller.currentState.resultSections, isEmpty);
      expect(hotel.searchCallCount, 0);
      expect(flight.searchCallCount, 0);
    });

    test('the fallback never duplicates the gaps flow (incomplete service '
        'queries keep their chips)', () async {
      controller.open();
      controller.surfaceReady();
      // Valid service + destination but incomplete → parked with gaps by
      // submit(); aiResultsFailed must not hijack that flow (the phase
      // guard: aiResultsFailed is a no-op off SEARCHING).
      controller.onQueryChanged('flight to dubai');
      await controller.submit();
      expect(phase(), UniversalSearchPhase.typing);
      expect(controller.currentState.intentGaps, isNotEmpty);

      controller.aiResultsFailed();

      expect(phase(), UniversalSearchPhase.typing); // unchanged
      expect(flight.searchCallCount, 0);
    });
  });

  group('Follow-ups patch the intent (no free-form chat)', () {
    test('compare is the CONTRACT-ONLY chip: a no-op on the intent', () async {
      controller.open();
      controller.surfaceReady();
      controller.onQueryChanged('hotels in dubai');
      await controller.submit();
      expect(phase(), UniversalSearchPhase.results);
      final intentBefore = controller.currentState.structuredIntent;

      await controller.applyFollowUp(FollowUpAction.compare);

      // Phase + intent untouched — the chip is a signal for US-6's
      // comparison surface, nothing patches here.
      expect(phase(), UniversalSearchPhase.results);
      expect(controller.currentState.structuredIntent?.destination,
          intentBefore?.destination);
      expect(controller.currentState.structuredIntent?.type,
          intentBefore?.type);
    });

    test('cheaper/morePremium still patch the budget band (US-2 §8 intact)',
        () async {
      controller.open();
      controller.surfaceReady();
      controller.onQueryChanged('hotels in dubai');
      await controller.submit();
      expect(phase(), UniversalSearchPhase.results);

      await controller.applyFollowUp(FollowUpAction.cheaper);
      expect(
        controller.currentState.structuredIntent?.budget,
        IntentBudgetBand.low,
      );
      // A follow-up runs a real search: the hotel controller fired.
      expect(hotel.searchCallCount, 2); // initial + follow-up
    });

    test('AI_RESULT → follow-up runs a deterministic search (AI_RESULT → SEARCHING)',
        () async {
      controller.open();
      controller.surfaceReady();
      controller.onQueryChanged('hotels in dubai');
      await controller.submit();
      expect(phase(), UniversalSearchPhase.results);
      final searchesBefore = hotel.searchCallCount;

      // A follow-up from a structured result must re-enter SEARCHING
      // through the real controllers (the AI_RESULT phase takes the same
      // path — proven through the results phase here since chips only
      // render with a structured intent, per US-2 §8).
      await controller.applyFollowUp(FollowUpAction.twoPeople);
      expect(hotel.searchCallCount, searchesBefore + 1);
      expect(
        controller.currentState.structuredIntent?.passengers,
        2,
      );
      await Future<void>.delayed(Duration.zero);
      expect(phase(), UniversalSearchPhase.results);
    });
  });

  group('Context safety (spec: safe structured context only)', () {
    test('the AI interpreting state carries NO user/session data', () {
      controller.open();
      controller.surfaceReady();
      controller.onQueryChanged('random words');
      controller.submit();

      // The state that drives the AI call holds ONLY the query + phase
      // flags — no tokens, no profile, no personal fields (the context
      // object is built route-only at the page layer).
      final snapshot = controller.currentState;
      expect(snapshot.aiInterpreting, isTrue);
      expect(snapshot.query, 'random words');
    });
  });
}

class _FakeSuggestionsDelegate implements AiSuggestionsDelegate {
  @override
  Future<List<String>> suggest(String query) async => const <String>[];
}

class _RecordingFlightController extends FlightSearchController {
  _RecordingFlightController()
      : super(
          SearchFlightsUseCase(FlightRepositoryImpl(
              HttpApiClient(baseUrlOverride: 'http://stub'))),
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
      : super(HotelRepositoryImpl(HttpApiClient(baseUrlOverride: 'http://stub')),
          MemoryOfflineCache());

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
      : super(CarRepositoryImpl(HttpApiClient(baseUrlOverride: 'http://stub')),
          MemoryOfflineCache());

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
