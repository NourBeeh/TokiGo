import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/booking_repository.dart';
import 'package:tokigo/core/domain/models/booking/booking.dart';
import 'package:tokigo/features/bag/application/bag_controller.dart';
import 'package:tokigo/features/booking/application/booking_controller.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/application/confirm_booking_usecase.dart';
import 'package:tokigo/features/booking/application/prepare_booking_usecase.dart';
import 'package:tokigo/features/booking/application/revalidate_booking_usecase.dart';
import 'package:tokigo/features/booking/domain/booking_error.dart';
import 'package:tokigo/features/booking/domain/booking_preparation.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';

/// Phase 2P-Fix — deterministic safety tests for the booking confirm path.
///
/// These drive the REAL controller / use-case boundaries. The only seam is a
/// fake [BookingRepository]; concurrency is synchronised with [Completer]s,
/// never with arbitrary sleeps.

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
  double price = 100,
  BookingStatus status = BookingStatus.pending,
}) {
  return BookingRecord(
    bookingId: bookingId,
    userId: 'user-1',
    searchId: searchId,
    offerId: offerId,
    providerId: providerId,
    providerName: 'Nuitee Connect',
    type: 'hotel',
    status: status,
    currency: 'USD',
    authoritativePrice: price,
    priceBreakdown: PriceBreakdown.empty,
    travelers: const <Passenger>[],
    bookingReference: '',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

BookingPreparation _preparation({
  String offerId = 'offer-1',
  String providerId = 'nuitee',
  String searchId = 'search-1',
  double price = 100,
  bool priceChanged = false,
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
      available: true,
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

/// Fake repository. Every create call is held open until the test releases it,
/// so the "first request pending" window is exact rather than timing-based.
class _FakeRepository implements BookingRepository {
  _FakeRepository({this.prepareResult, this.createResult});

  /// Overrides the prepare/prebook outcome (null → a prepared record).
  ApiResult<BookingRecord>? prepareResult;

  /// Overrides the create outcome (null → a confirmed record).
  ApiResult<BookingRecord>? createResult;

  final List<String> createCalls = <String>[];
  final List<String> idempotencyKeys = <String>[];
  final List<List<dynamic>> travelersCalls = <List<dynamic>>[];
  final Completer<void> createEntered = Completer<void>();
  final Completer<void> releaseCreate = Completer<void>();

  bool get createPending => !releaseCreate.isCompleted;

  @override
  Future<ApiResult<BookingRecord>> createBooking(
    String bookingId,
    String idempotencyKey,
    List<dynamic> travelers,
  ) async {
    createCalls.add(bookingId);
    idempotencyKeys.add(idempotencyKey);
    travelersCalls.add(travelers);
    if (!createEntered.isCompleted) createEntered.complete();
    await releaseCreate.future;
    return createResult ??
        ApiResult.success(
          _record(
            bookingId: bookingId,
            offerId: 'offer-x',
            searchId: 'search-x',
            status: BookingStatus.confirmed,
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
        _record(offerId: offerId, providerId: providerId, searchId: searchId),
      );

  @override
  Future<ApiResult<BookingRecord>> revalidateBooking(String bookingId) async =>
      ApiResult.success(_record(bookingId: bookingId));

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

class _Harness {
  _Harness(this.repository) {
    controller = BookingController(
      prepareUseCase: PrepareBookingUseCase(repository),
      revalidateUseCase: RevalidateBookingUseCase(repository),
      confirmUseCase: ConfirmBookingUseCase(repository),
      bagController: BagController(),
    );
  }

  final _FakeRepository repository;
  late final BookingController controller;

  void dispose() => controller.dispose();
}

void main() {
  group('A. Duplicate submission', () {
    test(
      'A1 two concurrent confirm calls while the first is pending submit exactly one provider booking',
      () async {
        final repo = _FakeRepository();
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(),
          preparation: _preparation(),
        );

        final first = h.controller.confirm(travelers: _validTravelers);
        await repo.createEntered.future;
        expect(h.controller.state.phase, BookingPhase.confirming);

        final second = h.controller.confirm(travelers: _validTravelers);
        final third = h.controller.confirm(travelers: _validTravelers);

        // The duplicate taps must be no-ops: one submission, and the machine
        // must stay in confirming rather than being flipped to error.
        expect(repo.createCalls, hasLength(1));
        expect(repo.createPending, isTrue);
        expect(h.controller.state.phase, BookingPhase.confirming);

        repo.releaseCreate.complete();
        await Future.wait(<Future<void>>[first, second, third]);

        expect(repo.createCalls, hasLength(1));
        expect(repo.idempotencyKeys, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.confirmed);
        expect(h.controller.state.record?.status, BookingStatus.confirmed);
      },
    );

    test(
      'A2 additional calls during the same pending attempt never submit another booking',
      () async {
        final repo = _FakeRepository();
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(
            bookingId: 'bk-a2',
            offerId: 'offer-a2',
            searchId: 'search-a2',
          ),
          preparation: _preparation(offerId: 'offer-a2', searchId: 'search-a2'),
        );

        final first = h.controller.confirm(travelers: _validTravelers);
        await repo.createEntered.future;
        final extras = <Future<void>>[
          for (int i = 0; i < 4; i++) h.controller.confirm(travelers: _validTravelers),
        ];

        expect(repo.createCalls, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.confirming);

        repo.releaseCreate.complete();
        await Future.wait(<Future<void>>[first, ...extras]);

        expect(repo.createCalls, hasLength(1));
        expect(repo.idempotencyKeys, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.confirmed);
      },
    );

    test(
      'A3 a completed successful attempt does not accidentally submit again',
      () async {
        final repo = _FakeRepository();
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(
            bookingId: 'bk-a3',
            offerId: 'offer-a3',
            searchId: 'search-a3',
          ),
          preparation: _preparation(offerId: 'offer-a3', searchId: 'search-a3'),
        );

        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);
        expect(repo.createCalls, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.confirmed);

        // Late duplicate taps must not submit and must not overwrite the
        // confirmed state with an error.
        await h.controller.confirm(travelers: _validTravelers);
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.confirmed);
        expect(h.controller.state.record?.status, BookingStatus.confirmed);
      },
    );

    test(
      'A4 a legitimate new booking attempt works after the previous attempt is reset',
      () async {
        final repo = _FakeRepository();
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(
            bookingId: 'bk-a4-first',
            offerId: 'offer-a4-first',
            searchId: 'search-a4-first',
          ),
          preparation: _preparation(
            offerId: 'offer-a4-first',
            searchId: 'search-a4-first',
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
            bookingId: 'bk-a4-second',
            offerId: 'offer-a4-second',
            searchId: 'search-a4-second',
          ),
          preparation: _preparation(
            offerId: 'offer-a4-second',
            searchId: 'search-a4-second',
          ),
        );
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(2));
        expect(repo.createCalls[1], 'bk-a4-second');
        expect(repo.idempotencyKeys[1], isNot(repo.idempotencyKeys[0]));
        expect(h.controller.state.phase, BookingPhase.confirmed);
        expect(h.controller.state.record?.bookingId, 'bk-a4-second');
      },
    );
  });

  group('B. Failure and timeout', () {
    test(
      'B5 a clear provider rejection does not produce a successful booking state',
      () async {
        final repo = _FakeRepository(
          createResult: ApiResult.failure(
            const ApiClientError(
              message:
                  '{"code":"provider_error","message":"Provider rejected the booking"}',
              statusCode: 502,
            ),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(
            bookingId: 'bk-b5',
            offerId: 'offer-b5',
            searchId: 'search-b5',
          ),
          preparation: _preparation(offerId: 'offer-b5', searchId: 'search-b5'),
        );

        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.failed);
        expect(
          h.controller.state.record?.status,
          isNot(BookingStatus.confirmed),
        );
        expect(h.controller.state.errorCode, BookingErrorCode.providerError);
      },
    );

    test(
      'B6 a timeout does not produce false success and is classified as providerUnavailable',
      () async {
        final repo = _FakeRepository(
          createResult: ApiResult.failure(
            const ApiTimeoutError(message: 'Request timed out'),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(
            bookingId: 'bk-b6',
            offerId: 'offer-b6',
            searchId: 'search-b6',
          ),
          preparation: _preparation(offerId: 'offer-b6', searchId: 'search-b6'),
        );

        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.failed);
        expect(
          h.controller.state.record?.status,
          isNot(BookingStatus.confirmed),
        );
        expect(
          h.controller.state.errorCode,
          BookingErrorCode.providerUnavailable,
        );
      },
    );

    test('B6b a connection loss does not produce false success', () async {
      final repo = _FakeRepository(
        createResult: ApiResult.failure(
          const ApiNetworkError(
            message: 'SocketException: connection refused',
          ),
        ),
      );
      final h = _Harness(repo);
      addTearDown(h.dispose);
      h.controller.state = _readyState(
        record: _record(
          bookingId: 'bk-b6b',
          offerId: 'offer-b6b',
          searchId: 'search-b6b',
        ),
        preparation: _preparation(offerId: 'offer-b6b', searchId: 'search-b6b'),
      );

      repo.releaseCreate.complete();
      await h.controller.confirm(travelers: _validTravelers);

      expect(repo.createCalls, hasLength(1));
      expect(h.controller.state.phase, BookingPhase.failed);
      expect(
        h.controller.state.record?.status,
        isNot(BookingStatus.confirmed),
      );
      expect(
        h.controller.state.errorCode,
        BookingErrorCode.providerUnavailable,
      );
    });

    test(
      'B7 an ambiguous timeout does not trigger an automatic second booking submission',
      () async {
        final repo = _FakeRepository(
          createResult: ApiResult.failure(
            const ApiTimeoutError(message: 'Request timed out'),
          ),
        );
        final h = _Harness(repo);
        addTearDown(h.dispose);
        h.controller.state = _readyState(
          record: _record(
            bookingId: 'bk-b7',
            offerId: 'offer-b7',
            searchId: 'search-b7',
          ),
          preparation: _preparation(offerId: 'offer-b7', searchId: 'search-b7'),
        );

        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);
        expect(repo.createCalls, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.failed);

        // No automatic retry path exists: after the ambiguous outcome the
        // submission count must stay at one.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(repo.createCalls, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.failed);
      },
    );
  });

  group('C. Prebook and price validation', () {
    test('C8 a failed prebook prevents any booking submission', () async {
      final repo = _FakeRepository(
        prepareResult: ApiResult.failure(
          const ApiClientError(
            message:
                '{"code":"provider_unavailable","message":"prebook request failed"}',
            statusCode: 503,
          ),
        ),
      );
      final h = _Harness(repo);
      addTearDown(h.dispose);

      await h.controller.prepare(
        offerId: 'offer-c8',
        providerId: 'nuitee',
        searchId: 'search-c8',
      );

      expect(h.controller.state.phase, BookingPhase.error);
      await h.controller.confirm(travelers: _validTravelers);
      expect(repo.createCalls, isEmpty);
      expect(h.controller.state.phase, isNot(BookingPhase.confirmed));
    });

    test('C9 an expired or unavailable rate prevents confirmation', () async {
      final repo = _FakeRepository(
        prepareResult: ApiResult.failure(
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
        offerId: 'offer-c9',
        providerId: 'nuitee',
        searchId: 'search-c9',
      );

      expect(h.controller.state.phase, BookingPhase.error);
      expect(h.controller.state.errorCode, BookingErrorCode.noAvailability);
      await h.controller.confirm(travelers: _validTravelers);
      expect(repo.createCalls, isEmpty);
      expect(h.controller.state.phase, isNot(BookingPhase.confirmed));
    });

    test(
      'C9b a prepared booking cannot be confirmed before price revalidation',
      () async {
        final repo = _FakeRepository();
        final h = _Harness(repo);
        addTearDown(h.dispose);

        await h.controller.prepare(
          offerId: 'offer-c9b',
          providerId: 'nuitee',
          searchId: 'search-c9b',
        );
        expect(h.controller.state.phase, BookingPhase.prepared);

        // prepared != readyToConfirm: the confirm gate must hold.
        await h.controller.confirm(travelers: _validTravelers);
        expect(repo.createCalls, isEmpty);
        expect(h.controller.state.phase, isNot(BookingPhase.confirmed));
      },
    );

    test(
      'C10 a changed price is not silently accepted as the original price',
      () async {
        final repo = _FakeRepository();
        final h = _Harness(repo);
        addTearDown(h.dispose);

        h.controller.state = _readyState(
          record: _record(
            bookingId: 'bk-c10',
            offerId: 'offer-c10',
            searchId: 'search-c10',
            price: 100,
          ),
          preparation: _preparation(
            offerId: 'offer-c10',
            searchId: 'search-c10',
            price: 175,
            priceChanged: true,
          ),
          priceAccepted: false,
        );

        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, isEmpty);
        expect(h.controller.state.phase, BookingPhase.error);
        expect(h.controller.state.errorCode, BookingErrorCode.priceChanged);

        // Explicit acceptance is the only way past the gate.
        h.controller.state = _readyState(
          record: _record(
            bookingId: 'bk-c10',
            offerId: 'offer-c10',
            searchId: 'search-c10',
            price: 175,
          ),
          preparation: _preparation(
            offerId: 'offer-c10',
            searchId: 'search-c10',
            price: 175,
            priceChanged: true,
          ),
          priceAccepted: true,
        );
        repo.releaseCreate.complete();
        await h.controller.confirm(travelers: _validTravelers);

        expect(repo.createCalls, hasLength(1));
        expect(h.controller.state.phase, BookingPhase.confirmed);
      },
    );
  });
}
