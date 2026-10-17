import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/domain/models/search/car_search_params.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/car_repository.dart';
import 'package:tokigo/features/search/application/controllers/car_search_controller.dart';
import 'package:tokigo/core/storage/offline_cache.dart';

/// Phase 11C — `CarSearchController` error boundary.
///
/// `CarSearchState.errorMessage` is rendered verbatim on screen by
/// `car_search_page.dart`, while the network layer stores the whole HTTP
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

final CarSearchParams _params = CarSearchParams(
  pickupLocation: 'Nice',
  dropoffLocation: 'Cannes',
  pickupDateTime: DateTime(2026, 8, 20),
  dropoffDateTime: DateTime(2026, 8, 22),
);

final List<CarOffer> _offers = <CarOffer>[
  CarOffer(
    id: 'car-1',
    providerId: 'p1',
    providerName: 'Hertz',
    title: 'Toyota Yaris',
    price: 42,
    currency: 'EUR',
    pickupLocation: 'Nice',
    dropoffLocation: 'Cannes',
    pickupTime: DateTime(2026, 8, 20),
    dropoffTime: DateTime(2026, 8, 22),
    carType: 'compact',
  ),
];

/// Serves the configured [result]; returns an empty success when unset.
class _FakeCarRepository implements CarRepository {
  _FakeCarRepository([this.result]);

  ApiResult<List<CarOffer>>? result;
  int calls = 0;

  @override
  Future<ApiResult<List<CarOffer>>> search({
    required String pickupLocation,
    required DateTime pickupTime,
    required DateTime dropoffTime,
  }) async {
    calls++;
    return result ?? const ApiResult.success(<CarOffer>[]);
  }

  @override
  Future<ApiResult<CarOffer>> getById(String id) async =>
      throw UnimplementedError();
}

CarSearchController _controllerFor(CarRepository repository) {
  final controller = CarSearchController(repository, MemoryOfflineCache());
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('CarSearchController — no raw error text reaches errorMessage', () {
    test('ApiServerError does not leak the API/provider body', () async {
      final repository = _FakeCarRepository(
        const ApiResult.failure(
          ApiServerError(message: _rawServerBody, statusCode: 503),
        ),
      );
      final controller = _controllerFor(repository);

      await controller.search(_params);

      final message = controller.state.errorMessage;
      expect(controller.state.status, CarSearchStatus.error);
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
      final repository = _FakeCarRepository(
        const ApiResult.failure(ApiNetworkError(message: _rawSocketText)),
      );
      final controller = _controllerFor(repository);

      await controller.search(_params);

      final message = controller.state.errorMessage;
      expect(controller.state.status, CarSearchStatus.error);
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
          _FakeCarRepository(ApiResult.failure(error)),
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

  group('CarSearchController — existing behavior is unchanged', () {
    test('success publishes results and clears the error', () async {
      final repository = _FakeCarRepository(ApiResult.success(_offers));
      final controller = _controllerFor(repository);

      await controller.search(_params);

      expect(controller.state.status, CarSearchStatus.success);
      expect(controller.state.results, _offers);
      expect(controller.state.errorMessage, isNull);
      expect(repository.calls, 1);
    });

    test('an empty result list becomes the empty state', () async {
      final repository = _FakeCarRepository();
      final controller = _controllerFor(repository);

      await controller.search(_params);

      expect(controller.state.status, CarSearchStatus.empty);
      expect(controller.state.results, isEmpty);
      expect(controller.state.errorMessage, isNull);
    });

    test('retry after an error recovers to success', () async {
      final repository = _FakeCarRepository();
      final controller = _controllerFor(repository);

      repository.result = const ApiResult.failure(
        ApiServerError(message: _rawServerBody, statusCode: 503),
      );
      await controller.search(_params);
      expect(controller.state.status, CarSearchStatus.error);
      expect(controller.state.errorMessage, isNot(contains(_rawServerBody)));

      repository.result = ApiResult.success(_offers);
      await controller.search(_params);

      expect(repository.calls, 2);
      expect(controller.state.status, CarSearchStatus.success);
      expect(controller.state.results, _offers);
      // Pre-existing copyWith semantics keep the last errorMessage while
      // status is success; it must still never contain raw API/provider text.
      expect(controller.state.errorMessage ?? '', isNot(contains(_rawServerBody)));
    });
  });
}
