import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/flight_repository.dart';
import 'package:tokigo/core/usecases/search_flights_usecase.dart';
import 'package:tokigo/features/search/application/controllers/flight_search_controller.dart';
import 'package:tokigo/core/storage/offline_cache.dart';

/// Phase 11C — `FlightSearchController` error boundary.
///
/// `FlightSearchState.errorMessage` is rendered verbatim on screen by
/// `flight_search_page.dart`, while the network layer stores the whole HTTP
/// response body in `ApiError.message` and socket failures carry host/port.
/// These tests pin that no raw transport, API/provider or secret text can
/// reach that field, while the success / empty / retry transitions stay
/// exactly as they were.

/// Raw payloads that must never surface to the user.
const String _rawServerBody =
    '{"statusCode":503,"message":"provider internal error: database '
    'unreachable at 10.0.0.5:5432 token=sk-secret","error":"Service Unavailable"}';
const String _rawSocketText =
    'SocketException: Connection refused (OS Error: Connection refused, '
    'errno = 111), address = localhost, port = 45678';

final FlightSearchParams _params = FlightSearchParams(
  origin: 'AMS',
  destination: 'NCE',
  departureDate: DateTime(2026, 8, 20),
);

final List<FlightOffer> _offers = <FlightOffer>[
  FlightOffer(
    id: 'flight-1',
    providerId: 'p1',
    providerName: 'KLM',
    title: 'AMS - NCE',
    price: 120,
    currency: 'EUR',
    origin: 'AMS',
    destination: 'NCE',
    departureTime: DateTime(2026, 8, 20),
    arrivalTime: DateTime(2026, 8, 20),
    airline: 'KLM',
    flightNumber: 'KL123',
  ),
];

/// Serves the configured [result]; returns an empty success when unset.
class _FakeFlightRepository implements FlightRepository {
  _FakeFlightRepository([this.result]);

  ApiResult<List<FlightOffer>>? result;
  int calls = 0;

  @override
  Future<ApiResult<List<FlightOffer>>> search({
    required String origin,
    required String destination,
    required DateTime departure,
    DateTime? returnDate,
    int? passengers,
  }) async {
    calls++;
    return result ?? const ApiResult.success(<FlightOffer>[]);
  }

  @override
  Future<ApiResult<FlightOffer>> getById(String id) async =>
      throw UnimplementedError();
}

FlightSearchController _controllerFor(FlightRepository repository) {
  final controller = FlightSearchController(SearchFlightsUseCase(repository), MemoryOfflineCache());
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('FlightSearchController — no raw error text reaches errorMessage', () {
    test('ApiServerError does not leak the API/provider body', () async {
      final repository = _FakeFlightRepository(
        const ApiResult.failure(
          ApiServerError(message: _rawServerBody, statusCode: 503),
        ),
      );
      final controller = _controllerFor(repository);

      await controller.search(_params);

      final message = controller.state.errorMessage;
      expect(controller.state.status, SearchStatus.error);
      expect(message, isNotNull);
      expect(message, isNot(contains('statusCode')));
      expect(message, isNot(contains('Service Unavailable')));
      expect(message, isNot(contains('ApiServerError')));
      expect(message, isNot(contains('503')));
      expect(message, isNot(contains('10.0.0.5')));
      expect(message, isNot(contains('sk-secret')));
      expect(message, isNot(contains(_rawServerBody)));
    });

    test('ApiNetworkError does not leak host, port or exception type',
        () async {
      final repository = _FakeFlightRepository(
        const ApiResult.failure(ApiNetworkError(message: _rawSocketText)),
      );
      final controller = _controllerFor(repository);

      await controller.search(_params);

      final message = controller.state.errorMessage;
      expect(controller.state.status, SearchStatus.error);
      expect(message, isNotNull);
      expect(message, isNot(contains('SocketException')));
      expect(message, isNot(contains('localhost')));
      expect(message, isNot(contains('45678')));
      expect(message, isNot(contains('errno')));
      expect(message, isNot(contains(_rawSocketText)));
    });

    test('every ApiError subtype maps to a short, safe message', () async {
      final errors = <ApiError>[
        const ApiClientError(message: _rawServerBody, statusCode: 400),
        const ApiServerError(message: _rawServerBody, statusCode: 503),
        const ApiNetworkError(message: _rawSocketText),
        const ApiTimeoutError(message: 'TimeoutException after 30s'),
        const ApiUnauthorizedError(message: 'nope', statusCode: 401),
        const ApiParseError(message: 'Invalid JSON: {broken'),
        const ApiUnknownError(message: 'boom'),
      ];

      for (final error in errors) {
        final controller = _controllerFor(
          _FakeFlightRepository(ApiResult.failure(error)),
        );
        await controller.search(_params);

        final message = controller.state.errorMessage!;
        expect(message.length, lessThan(120), reason: 'for $error');
        expect(message, isNot(contains('{')), reason: 'for $error');
        expect(message, isNot(contains('Api')), reason: 'for $error');
        expect(message, isNot(contains('\n')), reason: 'for $error');
        expect(message, isNotEmpty, reason: 'for $error');
      }
    });
  });

  group('FlightSearchController — existing behavior is unchanged', () {
    test('success publishes results and clears the error', () async {
      final repository = _FakeFlightRepository(ApiResult.success(_offers));
      final controller = _controllerFor(repository);

      await controller.search(_params);

      expect(controller.state.status, SearchStatus.success);
      expect(controller.state.results, _offers);
      expect(controller.state.errorMessage, isNull);
      expect(repository.calls, 1);
    });

    test('an empty result list becomes the empty state', () async {
      final repository = _FakeFlightRepository();
      final controller = _controllerFor(repository);

      await controller.search(_params);

      expect(controller.state.status, SearchStatus.empty);
      expect(controller.state.results, isEmpty);
      expect(controller.state.errorMessage, isNull);
    });

    test('retry after an error recovers to success', () async {
      final repository = _FakeFlightRepository();
      final controller = _controllerFor(repository);

      repository.result = const ApiResult.failure(
        ApiServerError(message: _rawServerBody, statusCode: 503),
      );
      await controller.search(_params);
      expect(controller.state.status, SearchStatus.error);
      expect(controller.state.errorMessage, isNot(contains(_rawServerBody)));

      repository.result = ApiResult.success(_offers);
      await controller.search(_params);

      expect(repository.calls, 2);
      expect(controller.state.status, SearchStatus.success);
      expect(controller.state.results, _offers);
      // Pre-existing copyWith semantics keep the last errorMessage while
      // status is success; it must still never contain raw API/provider text.
      expect(controller.state.errorMessage ?? '', isNot(contains(_rawServerBody)));
    });
  });
}
