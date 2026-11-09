import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/domain/models/booking/booking.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/repositories/booking_repository_impl.dart';
import 'package:tokigo/core/repositories/contracts/booking_repository.dart';
import 'package:tokigo/features/bag/application/bag_controller.dart';
import 'package:tokigo/features/booking/application/booking_controller.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/application/confirm_booking_usecase.dart';
import 'package:tokigo/features/booking/application/idempotency_store.dart';
import 'package:tokigo/features/booking/application/prepare_booking_usecase.dart';
import 'package:tokigo/features/booking/application/revalidate_booking_usecase.dart';
import 'package:tokigo/features/booking/domain/booking_error.dart';
import 'package:tokigo/features/booking/domain/booking_preparation.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';

/// Phase 2P — deterministic safety tests for the hotel booking confirm path.
///
/// These drive the REAL controller / use-case / repository boundaries. The only
/// seam is the external dependency (the provider behind `BookingRepository`,
/// or the `ApiClient` behind it), and every seam is synchronised with
/// `Completer`s — never with an arbitrary sleep.
///
/// No live Nuitee request is made anywhere in this file.

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// One recorded repository call. [error] is non-null only on a failure path.
class _Call {
  _Call(this.bookingId, this.idempotencyKey, this.travelers, this.error);

  final String bookingId;
  final String idempotencyKey;
  final List<dynamic> travelers;
  final ApiError? error;
}

/// Deterministic fake of the provider-backed booking repository.
///
/// The test decides exactly when each in-flight call is released via
/// [releaseCreate]; that is what makes the concurrency assertions exact rather
/// than timing-dependent.
class _FakeRepository implements BookingRepository {
  _FakeRepository({this.createResult, this.prepareResult});

  /// Outcome of the next `createBooking` call. Null → a confirmed record.
  ApiResult<BookingRecord>? createResult;

  /// Outcome of the next `prepareBooking` call. Null → a prepared record.
  ApiResult<BookingRecord>? prepareResult;

  final List<_Call> createCalls = <_Call>[];

  /// Completed when the first `createBooking` has actually been entered, so a
  /// test can assert "still pending" without racing the call itself.
  final Completer<void> createEntered = Completer<void>();

  /// Completed by the test to release every in-flight `createBooking` call.
  final Completer<void> releaseCreate = Completer<void>();

  bool get createPending => !releaseCreate.isCompleted;

  List<String> get idempotencyKeys =>
      createCalls.map((c) => c.idempotencyKey).toList(growable: false);

  @override
  Future<ApiResult<BookingRecord>> createBooking(
    String bookingId,
    String idempotencyKey,
    List<dynamic> travelers,
  ) async {
    final outcome = createResult;
    final ApiError? error = outcome?.when(
      success: (_) => null,
      failure: (e) => e,
    );
    createCalls.add(_Call(bookingId, idempotencyKey, travelers, error));
    if (!createEntered.isCompleted) createEntered.complete();
    await releaseCreate.future;
    return outcome ??
        ApiResult.success(
          _record(
            bookingId: bookingId,
            offerId: 'offer-1',
            providerId: 'nuitee',
            searchId: 'search-1',
            status: 'confirmed',
          ),
        );
  }

  @override
  Future<ApiResult<BookingRecord>> prepareBooking(
    String offerId,
    String providerId,
    String searchId,
  ) async =>
      prepareResult ??
      ApiResult.success(
        _record(
          offerId: offerId,
          providerId: providerId,
          searchId: searchId,
          status: 'prepared',
        ),
      );

  @override
  Future<ApiResult<BookingRecord>> revalidateBooking(String bookingId) async =>
      ApiResult.success(_record(bookingId: bookingId, status: 'revalidated'));

  @override
  Future<ApiResult<BookingRecord>> getBooking(String bookingId) async =>
      ApiResult.success(_record(bookingId: bookingId));

  @override
  Future<ApiResult<void>> cancelBooking(String bookingId) async =>
      const ApiResult<void>.success(null);

  @override
  Future<ApiResult<BookingRecord>> getBookingStatus(String bookingId) async =>
      ApiResult.success(_record(bookingId: bookingId));
}

/// A fake [ApiClient] so the REAL `BookingRepositoryImpl` mapping — including
/// its malformed-response handling — is exercised rather than bypassed.
class _FakeClient implements ApiClient {
  _FakeClient(this._responder);

  final ApiResult<Map<String, dynamic>> Function(String path) _responder;
  final List<String> calls = <String>[];

  @override
  String get baseUrl => 'http://test.local';

  @override
  Duration get defaultTimeout => const Duration(seconds: 5);

  @override
  Map<String, String> get defaultHeaders => const <String, String>{};

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async {
    calls.add(path);
    return _responder(path) as ApiResult<T>;
  }

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async {
    calls.add(path);
    return _responder(path) as ApiResult<T>;
  }

  @override
  Future<ApiResult<T>> put<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => throw UnimplementedError('put');

  @override
  Future<ApiResult<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => throw UnimplementedError('patch');

  @override
  Future<ApiResult<T>> delete<T>(
    String path, {
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => throw UnimplementedError('delete');

  @override
  ApiResult<T> mapError<T>(Object error, {StackTrace? stackTrace}) =>
      ApiResult<T>.failure(ApiUnknownError(message: '$error'));
}

/// A client whose timeout is short enough for a test to wait on. The behaviour
/// under test (abandoning a request that never answers) is identical; only the
/// bound differs.
class _ShortTimeoutClient extends HttpApiClient {
  _ShortTimeoutClient({required String baseUrl}) : super(baseUrlOverride: baseUrl);

  @override
  Duration get defaultTimeout => const Duration(seconds: 2);
}

/// Adapts a real [BookingRepositoryImpl] to the harness's call recording, so
/// the transport-boundary test drives the genuine HTTP client.
class _RepositoryAdapter implements BookingRepository {
  _RepositoryAdapter(this._inner);

  final BookingRepositoryImpl _inner;
  final List<_Call> createCalls = <_Call>[];

  @override
  Future<ApiResult<BookingRecord>> createBooking(
    String bookingId,
    String idempotencyKey,
    List<dynamic> travelers,
  ) async {
    final res = await _inner.createBooking(
      bookingId,
      idempotencyKey,
      travelers,
    );
    return res.when(
      success: (record) {
        createCalls.add(_Call(bookingId, idempotencyKey, travelers, null));
        return ApiResult.success(record);
      },
      failure: (error) {
        createCalls.add(_Call(bookingId, idempotencyKey, travelers, error));
        return ApiResult.failure(error);
      },
    );
  }

  @override
  Future<ApiResult<BookingRecord>> prepareBooking(
    String offerId,
    String providerId,
    String searchId,
  ) async => _inner.prepareBooking(offerId, providerId, searchId);

  @override
  Future<ApiResult<BookingRecord>> revalidateBooking(String bookingId) async =>
      _inner.revalidateBooking(bookingId);

  @override
  Future<ApiResult<BookingRecord>> getBooking(String bookingId) async =>
      _inner.getBooking(bookingId);

  @override
  Future<ApiResult<void>> cancelBooking(String bookingId) async =>
      _inner.cancelBooking(bookingId);

  @override
  Future<ApiResult<BookingRecord>> getBookingStatus(String bookingId) async =>
      _inner.getBookingStatus(bookingId);
}

/// Valid hotel guests for the confirmation state-machine tests. The controller
/// blocks a hotel confirmation with an empty or malformed traveler list, so
/// every `confirm` call passes a real guest.
const List<dynamic> _validTravelers = <dynamic>[
  <String, dynamic>{'firstName': 'Test', 'lastName': 'Guest', 'adult': true},
];

BookingRecord _record({
  String bookingId = 'bk-1',
  String offerId = 'offer-1',
  String providerId = 'nuitee',
  String searchId = 'search-1',
  String status = 'prepared',
  double price = 100,
}) {
  return BookingRecord(
    bookingId: bookingId,
    userId: 'user-1',
    searchId: searchId,
    offerId: offerId,
    providerId: providerId,
    providerName: 'Nuitee Connect',
    type: 'hotel',
    status: _status(status),
    currency: 'USD',
    authoritativePrice: price,
    priceBreakdown: PriceBreakdown.empty,
    travelers: const <Passenger>[],
    bookingReference: '',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

/// Mirrors the status mapping in `BookingRepositoryImpl._parseStatus`.
BookingStatus _status(String raw) {
  switch (raw) {
    case 'confirmed':
      return BookingStatus.confirmed;
    case 'cancelled':
      return BookingStatus.cancelled;
    case 'failed':
    case 'expired':
      return BookingStatus.failed;
    case 'prepared':
    case 'revalidated':
    case 'confirming':
      return BookingStatus.pending;
    default:
      return BookingStatus.draft;
  }
}

BookingPreparation _preparation({
  String offerId = 'offer-1',
  String providerId = 'nuitee',
  String searchId = 'search-1',
  double price = 100,
  bool priceChanged = false,
  bool available = true,
}) {
  return BookingPreparation(
    request: BookingRequest(
      offerId: offerId,
      providerId: providerId,
      searchId: searchId,
    ),
    revalidation: PriceRevalidationResult(
      authoritativePrice: price,
      currency: 'USD',
      priceChanged: priceChanged,
      available: available,
    ),
  );
}

BookingState _readyState({
  required BookingRecord record,
  required BookingPreparation preparation,
  bool priceAccepted = false,
}) {
  return BookingState(
    phase: BookingPhase.readyToConfirm,
    record: record,
    preparation: preparation,
    priceAccepted: priceAccepted,
  );
}

class _Harness {
  _Harness(BookingRepository repository) {
    controller = BookingController(
      prepareUseCase: PrepareBookingUseCase(repository),
      revalidateUseCase: RevalidateBookingUseCase(repository),
      confirmUseCase: ConfirmBookingUseCase(repository),
      bagController: BagController(),
    );
  }

  late final BookingController controller;

  void dispose() => controller.dispose();
}

ApiResult<Map<String, dynamic>> _providerPayload({
  String status = 'confirmed',
  double price = 100,
}) {
  return ApiResult<Map<String, dynamic>>.success(<String, dynamic>{
    'id': 'bk-1',
    'userId': 'user-1',
    'offerId': 'offer-1',
    'providerId': 'nuitee',
    'providerName': 'Nuitee Connect',
    'type': 'hotel',
    'status': status,
    'currency': 'USD',
    'authoritativePrice': price,
    'bookingReference': 'REF-1',
    'travelers': const <dynamic>[],
  });
}

void main() {
  setUp(() {
    // The idempotency cache is process-wide; every scenario starts clean so a
    // previous test's confirmed record can never satisfy a later attempt.
    IdempotencyStore.clear();
  });

  group('A. Duplicate confirmation', () {
    test(
      'A1 confirm succeeds from readyToConfirm and submits exactly one booking',
      () async {
        final repo = _FakeRepository();
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-a1'),
          preparation: _preparation(offerId: 'offer-a1', searchId: 'search-a1'),
        );

        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(1));
        expect(repo.createCalls.single.bookingId, 'bk-a1');
        expect(repo.createCalls.single.error, isNull);
        expect(h.controller.state.phase, BookingPhase.confirmed);
        expect(h.controller.state.record?.status, BookingStatus.confirmed);
      },
    );

    test(
      'A2 confirm is rejected outside readyToConfirm and never reaches the provider',
      () async {
        final repo = _FakeRepository();
        final h = _Harness(repo);
        addTearDown(h.dispose);

        const rejected = <BookingPhase>[
          BookingPhase.idle,
          BookingPhase.preparing,
          BookingPhase.prepared,
          BookingPhase.revalidating,
          BookingPhase.priceChanged,
          BookingPhase.unavailable,
          BookingPhase.confirming,
          BookingPhase.confirmed,
          BookingPhase.failed,
          BookingPhase.error,
        ];
        for (final phase in rejected) {
          h.controller.state = BookingState(phase: phase);
          await h.controller.confirm(travelers: _validTravelers);
          expect(
            repo.createCalls,
            isEmpty,
            reason: 'phase $phase must not submit',
          );
        }

        // Every rejection is classified, and the last one is still not
        // confirmable — the machine never silently opens a window.
        expect(h.controller.state.phase, BookingPhase.error);
        expect(h.controller.state.errorCode, BookingErrorCode.validationFailed);
      },
    );

    test(
      'A3 two concurrent confirm calls while the first is pending submit exactly one booking',
      () async {
        final repo = _FakeRepository();
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-a3'),
          preparation: _preparation(offerId: 'offer-a3', searchId: 'search-a3'),
        );

        final first = h.controller.confirm(travelers: _validTravelers);
        await repo.createEntered.future;
        final second = h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(1));
        expect(repo.createPending, isTrue);
        expect(h.controller.state.phase, BookingPhase.confirming);

        repo.releaseCreate.complete();
        await Future.wait(<Future<void>>[first, second]);

        expect(repo.createCalls, hasLength(1));
        expect(repo.idempotencyKeys, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.confirmed);
        expect(h.controller.state.record?.status, BookingStatus.confirmed);
      },
    );

    test(
      'A4 a third (and further) call during the same pending attempt cannot submit another booking',
      () async {
        final repo = _FakeRepository();
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-a4'),
          preparation: _preparation(offerId: 'offer-a4', searchId: 'search-a4'),
        );

        final first = h.controller.confirm(travelers: _validTravelers);
        await repo.createEntered.future;
        // Five extra taps while the provider call is still open.
        final extras = <Future<void>>[
          for (int i = 0; i < 5; i++) h.controller.confirm(travelers: _validTravelers),
        ];

        expect(repo.createCalls, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.confirming);

        repo.releaseCreate.complete();
        await Future.wait(<Future<void>>[first, ...extras]);

        expect(repo.createCalls, hasLength(1));
        expect(repo.idempotencyKeys, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.confirmed);
        expect(h.controller.state.record?.status, BookingStatus.confirmed);
      },
    );

    test(
      'A5 the controller stays protected after a successful confirmation',
      () async {
        final repo = _FakeRepository();
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-a5'),
          preparation: _preparation(offerId: 'offer-a5', searchId: 'search-a5'),
        );

        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);
        expect(repo.createCalls, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.confirmed);

        // Late duplicate taps after the success is already published must not
        // submit and must not overwrite the confirmed state with an error.
        await h.controller.confirm(travelers: _validTravelers);
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(1));
        expect(repo.idempotencyKeys, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.confirmed);
        expect(h.controller.state.record?.status, BookingStatus.confirmed);
      },
    );

    test(
      'A6 a legitimate new attempt proceeds after a completed attempt is reset',
      () async {
        final repo = _FakeRepository();
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(
            bookingId: 'bk-a6-first',
            offerId: 'offer-a6-first',
            searchId: 'search-a6-first',
          ),
          preparation: _preparation(
            offerId: 'offer-a6-first',
            searchId: 'search-a6-first',
          ),
        );

        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);
        expect(repo.createCalls, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.confirmed);

        // The funnel resets the machine before a new booking can be prepared.
        h.controller.reset();
        expect(h.controller.state.phase, BookingPhase.idle);

        h.controller.state = _readyState(
          record: _record(
            bookingId: 'bk-a6-second',
            offerId: 'offer-a6-second',
            searchId: 'search-a6-second',
          ),
          preparation: _preparation(
            offerId: 'offer-a6-second',
            searchId: 'search-a6-second',
          ),
        );
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(2));
        expect(repo.createCalls[1].bookingId, 'bk-a6-second');
        expect(repo.idempotencyKeys[1], isNot(repo.idempotencyKeys[0]));
        expect(h.controller.state.phase, BookingPhase.confirmed);
        expect(h.controller.state.record?.bookingId, 'bk-a6-second');
      },
    );

    test(
      'A7 a failed attempt does not leave the controller stuck in confirming',
      () async {
        final repo = _FakeRepository(
          createResult: ApiResult<BookingRecord>.failure(
            const ApiClientError(
              message: '{"code":"provider_error","message":"rejected"}',
              statusCode: 502,
            ),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-a7'),
          preparation: _preparation(offerId: 'offer-a7', searchId: 'search-a7'),
        );

        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.failed);
        expect(h.controller.state.phase, isNot(BookingPhase.confirming));
        expect(h.controller.state.errorCode, BookingErrorCode.providerError);
        expect(h.controller.state.record?.status, isNot(BookingStatus.confirmed));

        // The failed attempt is not cached as a success, so a fresh attempt
        // reaches the provider again instead of replaying a phantom result.
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-a7'),
          preparation: _preparation(offerId: 'offer-a7', searchId: 'search-a7'),
        );
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(2));
      },
    );
  });

  group('B. Timeout and ambiguous provider results', () {
    test(
      'B1 a clear provider rejection is a failure, never a confirmation',
      () async {
        final repo = _FakeRepository(
          createResult: ApiResult<BookingRecord>.failure(
            const ApiClientError(
              message: '{"code":"provider_error","message":"declined"}',
              statusCode: 502,
            ),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-b1'),
          preparation: _preparation(offerId: 'offer-b1', searchId: 'search-b1'),
        );

        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(1));
        expect(repo.createCalls.single.error, isA<ApiClientError>());
        expect(h.controller.state.phase, BookingPhase.failed);
        expect(h.controller.state.record?.status, isNot(BookingStatus.confirmed));
        expect(h.controller.state.errorCode, BookingErrorCode.providerError);
      },
    );

    test(
      'B2 a connection failure before submission is not reported as confirmed',
      () async {
        final repo = _FakeRepository(
          createResult: ApiResult<BookingRecord>.failure(
            const ApiNetworkError(message: 'Connection refused'),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-b2'),
          preparation: _preparation(offerId: 'offer-b2', searchId: 'search-b2'),
        );

        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(1));
        expect(repo.createCalls.single.error, isA<ApiNetworkError>());
        expect(h.controller.state.phase, BookingPhase.failed);
        expect(h.controller.state.record?.status, isNot(BookingStatus.confirmed));
        // A transport failure means the provider never answered. It is
        // classified as providerUnavailable (never as a confirmation), which is
        // what lets the funnel decide a retry is meaningful.
        expect(
          h.controller.state.errorCode,
          BookingErrorCode.providerUnavailable,
        );
      },
    );

    test(
      'B3 a pending timeout never becomes a confirmed booking',
      () async {
        final repo = _FakeRepository(
          createResult: ApiResult<BookingRecord>.failure(
            const ApiTimeoutError(message: 'Request timed out'),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-b3'),
          preparation: _preparation(offerId: 'offer-b3', searchId: 'search-b3'),
        );

        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(1));
        expect(repo.createCalls.single.error, isA<ApiTimeoutError>());
        expect(h.controller.state.phase, BookingPhase.failed);
        expect(h.controller.state.record?.status, isNot(BookingStatus.confirmed));
      },
    );

    test(
      'B4 a timeout is never automatically retried into a second submission',
      () async {
        final repo = _FakeRepository(
          createResult: ApiResult<BookingRecord>.failure(
            const ApiTimeoutError(message: 'Request timed out'),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-b4'),
          preparation: _preparation(offerId: 'offer-b4', searchId: 'search-b4'),
        );

        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);

        // Give any hypothetical retry timer a chance to fire. Zero-duration
        // turns only — no arbitrary delay.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(repo.createCalls, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.failed);
      },
    );

    test(
      'B5 an ambiguous outcome exposes no unsafe retry action',
      () async {
        final repo = _FakeRepository(
          createResult: ApiResult<BookingRecord>.failure(
            const ApiTimeoutError(message: 'Request timed out'),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-b5'),
          preparation: _preparation(offerId: 'offer-b5', searchId: 'search-b5'),
        );

        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);

        // After an ambiguous outcome the controller surface is: a failed phase
        // plus a classified error. A repeat confirm() is a NEW attempt that
        // goes back to the provider — never a silent replay of the uncertain
        // one, and never an auto-fired second submission.
        expect(h.controller.state.phase, BookingPhase.failed);
        expect(h.controller.state.errorCode, isNotNull);

        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-b5'),
          preparation: _preparation(offerId: 'offer-b5', searchId: 'search-b5'),
        );
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(2));
        expect(h.controller.state.phase, BookingPhase.failed);
      },
    );

    test(
      "B6 a new attempt cannot reuse an uncertain attempt's identifiers",
      () async {
        final repo = _FakeRepository(
          createResult: ApiResult<BookingRecord>.failure(
            const ApiTimeoutError(message: 'Request timed out'),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-b6'),
          preparation: _preparation(offerId: 'offer-b6', searchId: 'search-b6'),
        );

        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);
        final uncertainKey = repo.idempotencyKeys.single;

        // A different offer must not inherit the timed-out attempt's key.
        h.controller.reset();
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-b6-other', offerId: 'offer-b6-other'),
          preparation: _preparation(
            offerId: 'offer-b6-other',
            searchId: 'search-b6-other',
          ),
        );
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(2));
        expect(repo.idempotencyKeys[1], isNot(uncertainKey));
      },
    );

    test(
      'B7 clear failure and uncertain outcome stay distinguishable',
      () async {
        // A structured backend refusal maps to providerError; a transport
        // failure maps to providerUnavailable. They are different codes, so the
        // funnel can tell "the provider said no" from "the provider never
        // answered" — the distinction the architecture supports.
        expect(
          bookingErrorCodeFrom(
            const ApiClientError(
              message: '{"code":"provider_error","message":"declined"}',
              statusCode: 502,
            ),
          ),
          BookingErrorCode.providerError,
        );
        expect(
          bookingErrorCodeFrom(const ApiTimeoutError()),
          BookingErrorCode.providerUnavailable,
        );
        expect(
          bookingErrorCodeFrom(const ApiTimeoutError()),
          isNot(BookingErrorCode.providerError),
        );
        expect(
          bookingErrorCodeFrom(const ApiNetworkError()),
          BookingErrorCode.providerUnavailable,
        );
      },
    );

    test(
      'B8 a real socket timeout is reported as a timeout, never a confirmation',
      () async {
        // A server that accepts the connection and never answers: the client
        // abandons the request on timeout. This is the "response lost after the
        // provider may have processed it" case, exercised through the REAL
        // HttpApiClient + BookingRepositoryImpl mapping.
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close());
        final port = server.port;

        final client = _ShortTimeoutClient(
          baseUrl: 'http://127.0.0.1:$port',
        );
        final adapter = _RepositoryAdapter(BookingRepositoryImpl(client));
        final h = _Harness(adapter);
        addTearDown(h.dispose);

        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-b8'),
          preparation: _preparation(offerId: 'offer-b8', searchId: 'search-b8'),
        );

        await h.controller.confirm(travelers: _validTravelers);

        expect(adapter.createCalls, hasLength(1));
        expect(adapter.createCalls.single.error, isA<ApiTimeoutError>());
        expect(h.controller.state.phase, BookingPhase.failed);
        expect(h.controller.state.record?.status, isNot(BookingStatus.confirmed));
      }, timeout: const Timeout(Duration(seconds: 90)));
  });

  group('C. Prebook and price validation', () {
    test(
      'C1 a failed prepare (prebook) prevents any booking submission',
      () async {
        final repo = _FakeRepository(
          prepareResult: ApiResult<BookingRecord>.failure(
            const ApiClientError(
              message:
                  '{"code":"provider_unavailable","message":"prebook failed"}',
              statusCode: 503,
            ),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);

        await h.controller.prepare(
          offerId: 'offer-c1',
          providerId: 'nuitee',
          searchId: 'search-c1',
        );

        expect(h.controller.state.phase, BookingPhase.error);
        expect(
          h.controller.state.errorCode,
          BookingErrorCode.providerUnavailable,
        );

        // The machine is outside readyToConfirm, so confirm() can never reach
        // createBooking.
        await h.controller.confirm(travelers: _validTravelers);
        expect(repo.createCalls, isEmpty);
        expect(h.controller.state.phase, isNot(BookingPhase.confirmed));
      },
    );

    test(
      'C2 a prepare timeout prevents any booking submission',
      () async {
        final repo = _FakeRepository(
          prepareResult: ApiResult<BookingRecord>.failure(
            const ApiTimeoutError(message: 'prebook timed out'),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);

        await h.controller.prepare(
          offerId: 'offer-c2',
          providerId: 'nuitee',
          searchId: 'search-c2',
        );

        expect(h.controller.state.phase, BookingPhase.error);
        await h.controller.confirm(travelers: _validTravelers);
        expect(repo.createCalls, isEmpty);
        expect(h.controller.state.phase, isNot(BookingPhase.confirmed));
      },
    );

    test(
      'C3 expired prebook data cannot reach the booking submission',
      () async {
        // The provider reports the quote as expired during prebook. The funnel
        // lands in `error`, so the confirm gate can never open.
        final repo = _FakeRepository(
          prepareResult: ApiResult<BookingRecord>.failure(
            const ApiClientError(
              message:
                  '{"code":"booking_expired","message":"This quote has expired"}',
              statusCode: 409,
            ),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);

        await h.controller.prepare(
          offerId: 'offer-c3',
          providerId: 'nuitee',
          searchId: 'search-c3',
        );

        expect(h.controller.state.phase, BookingPhase.error);
        expect(h.controller.state.errorCode, BookingErrorCode.bookingExpired);

        await h.controller.confirm(travelers: _validTravelers);
        expect(repo.createCalls, isEmpty);
        expect(h.controller.state.phase, isNot(BookingPhase.confirmed));
      },
    );

    test(
      'C4 a prepared booking is not confirmable before price revalidation',
      () async {
        final repo = _FakeRepository();
        final h = _Harness(repo);
        addTearDown(h.dispose);

        await h.controller.prepare(
          offerId: 'offer-c4',
          providerId: 'nuitee',
          searchId: 'search-c4',
        );
        expect(h.controller.state.phase, BookingPhase.prepared);

        // prepared != readyToConfirm: the confirm gate must hold.
        await h.controller.confirm(travelers: _validTravelers);
        expect(repo.createCalls, isEmpty);
        expect(h.controller.state.phase, isNot(BookingPhase.confirmed));
      },
    );

    test(
      'C4b missing required offer identifiers cannot reach the booking submission',
      () async {
        // `offerId` is mandatory on the backend DTO (MinLength 1). An empty id
        // is rejected at the boundary as validation_failed, so no booking is
        // ever prepared and confirm() has nothing to submit.
        final repo = _FakeRepository(
          prepareResult: ApiResult<BookingRecord>.failure(
            const ApiClientError(
              message:
                  '{"code":"validation_failed","message":"offerId must be a non-empty string"}',
              statusCode: 422,
            ),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);

        await h.controller.prepare(
          offerId: '',
          providerId: 'nuitee',
          searchId: 'search-c4b',
        );

        expect(h.controller.state.phase, BookingPhase.error);
        expect(
          h.controller.state.errorCode,
          BookingErrorCode.validationFailed,
        );

        await h.controller.confirm(travelers: _validTravelers);
        expect(repo.createCalls, isEmpty);
        expect(h.controller.state.phase, isNot(BookingPhase.confirmed));
      },
    );

    test(
      'C5 a rate becoming unavailable prevents confirmation',
      () async {
        // The provider reports no availability during prebook → the funnel lands
        // in `error` and the confirm gate never opens.
        final repo = _FakeRepository(
          prepareResult: ApiResult<BookingRecord>.failure(
            const ApiClientError(
              message:
                  '{"code":"no_availability","message":"This offer is no longer available"}',
              statusCode: 409,
            ),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);

        await h.controller.prepare(
          offerId: 'offer-c5',
          providerId: 'nuitee',
          searchId: 'search-c5',
        );

        expect(h.controller.state.phase, BookingPhase.error);
        expect(h.controller.state.errorCode, BookingErrorCode.noAvailability);

        await h.controller.confirm(travelers: _validTravelers);
        expect(repo.createCalls, isEmpty);
        expect(h.controller.state.phase, isNot(BookingPhase.confirmed));
      },
    );

    test(
      'C6 a changed price is never silently accepted as the original price',
      () async {
        final repo = _FakeRepository();
        final h = _Harness(repo);
        addTearDown(h.dispose);

        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-c6', price: 100),
          preparation: _preparation(
            offerId: 'offer-c6',
            searchId: 'search-c6',
            price: 175,
            priceChanged: true,
          ),
          priceAccepted: false,
        );

        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, isEmpty);
        expect(h.controller.state.phase, BookingPhase.error);
        expect(h.controller.state.errorCode, BookingErrorCode.priceChanged);

        // Explicit acceptance is the only way past the gate, and then the
        // booking carries the NEW price, never the original.
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-c6', price: 175),
          preparation: _preparation(
            offerId: 'offer-c6',
            searchId: 'search-c6',
            price: 175,
            priceChanged: true,
          ),
          priceAccepted: true,
        );
        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(1));
        expect(repo.createCalls.single.bookingId, 'bk-c6');
        expect(h.controller.state.phase, BookingPhase.confirmed);
      },
    );

    test(
      'C7 revalidate with an unchanged price reaches readyToConfirm',
      () async {
        final repo = _FakeRepository();
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = BookingState(
          phase: BookingPhase.prepared,
          record: _record(bookingId: 'bk-c7', price: 100),
        );

        // The fake's revalidate returns the same price → readyToConfirm.
        await h.controller.revalidate(bookingId: 'bk-c7', oldPrice: 100);

        expect(h.controller.state.phase, BookingPhase.readyToConfirm);
        expect(repo.createCalls, isEmpty);
      },
    );
  });

  group('D. Repository mapping (malformed provider responses)', () {
    test(
      'D1 a malformed provider response is not a confirmed booking',
      () async {
        final client = _FakeClient(
          (_) => ApiResult<Map<String, dynamic>>.success(<String, dynamic>{
            'id': 'bk-d1',
            // offerId / providerId / status are all missing → the mapping must
            // not invent them into a confirmed booking.
          }),
        );
        final repo = BookingRepositoryImpl(client);

        final result = await repo.createBooking('bk-d1', 'key-d1', <dynamic>[]);

        expect(result.isSuccess, isTrue);
        final record = result.valueOrNull;
        expect(record, isNotNull);
        expect(record!.offerId, isEmpty);
        expect(record.providerId, isEmpty);
        expect(record.status, BookingStatus.draft);
        expect(record.status, isNot(BookingStatus.confirmed));
      },
    );

    test(
      'D2 a well-formed provider response carries status and price verbatim',
      () async {
        final client = _FakeClient(
          (_) => _providerPayload(status: 'confirmed', price: 305.94),
        );
        final repo = BookingRepositoryImpl(client);

        final record = (await repo.createBooking(
          'bk-d2',
          'key-d2',
          <dynamic>[],
        )).valueOrNull;

        expect(record!.status, BookingStatus.confirmed);
        expect(record.authoritativePrice, 305.94);
        expect(record.bookingReference, 'REF-1');
      },
    );

    test(
      'D3 a transport failure maps to a network error and no booking record',
      () async {
        final client = _FakeClient(
          (_) => ApiResult<Map<String, dynamic>>.failure(
            const ApiTimeoutError(message: 'timed out'),
          ),
        );
        final repo = BookingRepositoryImpl(client);

        final result = await repo.createBooking('bk-d3', 'key-d3', <dynamic>[]);

        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<ApiTimeoutError>());
        expect(result.valueOrNull, isNull);
      },
    );
  });

  group('E. Ambiguous-result limitation (documented, not solved)', () {
    test(
      'E1 an uncertain outcome is never cached as a confirmed booking',
      () async {
        final repo = _FakeRepository(
          createResult: ApiResult<BookingRecord>.failure(
            const ApiTimeoutError(message: 'Request timed out'),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-e1'),
          preparation: _preparation(offerId: 'offer-e1', searchId: 'search-e1'),
        );

        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);

        // A timeout is not proof of failure, so it must not enter the
        // idempotency cache as a success a later attempt could replay.
        expect(h.controller.state.phase, BookingPhase.failed);
        final uncertainKey = repo.idempotencyKeys.single;
        expect(IdempotencyStore.contains(uncertainKey), isFalse);

        // A subsequent fresh attempt therefore reaches the provider again. It
        // reuses the same logical idempotency key — correct, because the key
        // identifies the booking attempt, and the backend's unique index is what
        // makes that replay safe. What must NOT happen is a replay of a
        // phantom success, which the uncached entry above already proved.
        h.controller.reset();
        h.controller.state = _readyState(
          record: _record(bookingId: 'bk-e1'),
          preparation: _preparation(offerId: 'offer-e1', searchId: 'search-e1'),
        );
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(2));
        expect(h.controller.state.phase, BookingPhase.failed);
        expect(IdempotencyStore.contains(uncertainKey), isFalse);
      },
    );
  });
}
