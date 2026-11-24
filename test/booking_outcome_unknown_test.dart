import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/booking/booking.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/booking_repository_impl.dart';
import 'package:tokigo/core/repositories/contracts/booking_repository.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/bag/application/bag_controller.dart';
import 'package:tokigo/features/booking/application/booking_controller.dart';
import 'package:tokigo/features/booking/application/booking_providers.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/application/confirm_booking_usecase.dart';
import 'package:tokigo/features/booking/application/prepare_booking_usecase.dart';
import 'package:tokigo/features/booking/application/revalidate_booking_usecase.dart';
import 'package:tokigo/features/booking/domain/booking_error.dart';
import 'package:tokigo/features/booking/domain/booking_preparation.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/features/search/presentation/pages/booking_review_page.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Phase 3C — ambiguous provider outcomes must be their own customer-visible
/// state, never a duplicate request and never an ordinary failure.
///
/// The backend answers HTTP 409 with `code: booking_outcome_unknown` and
/// `details: {status: reconciliation_pending, requiresReconciliation: true,
/// retryable: false, operationStatus: unknown}`. Nothing in this file makes a
/// provider call.

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Map<String, dynamic> _unknownBody({bool includeCode = true}) {
  return <String, dynamic>{
    if (includeCode) 'code': 'booking_outcome_unknown',
    'message':
        'The provider booking outcome is not confirmed yet. This booking is pending reconciliation; do not retry or make another payment.',
    'details': <String, dynamic>{
      'bookingId': 'bk-1',
      'status': 'reconciliation_pending',
      'providerId': 'nuitee',
      'offerId': 'offer-1',
      'operationStatus': 'unknown',
      'requiresReconciliation': true,
      'retryable': false,
      'reconciliation': <String, dynamic>{
        'method': 'POST',
        'path': '/bookings/bk-1/reconcile',
        'adminOnly': true,
      },
    },
  };
}

ApiClientError _error(Map<String, dynamic> body) {
  return ApiClientError(statusCode: 409, message: jsonEncode(body));
}

BookingRecord _record({
  String bookingId = 'bk-1',
  double price = 100,
  BookingStatus status = BookingStatus.pending,
}) {
  return BookingRecord(
    bookingId: bookingId,
    userId: 'user-1',
    searchId: 'search-1',
    offerId: 'offer-1',
    providerId: 'nuitee',
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

BookingPreparation _preparation() {
  return BookingPreparation(
    request: const BookingRequest(
      offerId: 'offer-1',
      providerId: 'nuitee',
      searchId: 'search-1',
    ),
    revalidation: const PriceRevalidationResult(
      authoritativePrice: 100,
      currency: 'USD',
      priceChanged: false,
      available: true,
    ),
  );
}

BookingState _readyState() {
  return BookingState(
    phase: BookingPhase.readyToConfirm,
    record: _record(),
    preparation: _preparation(),
  );
}

const List<dynamic> _validTravelers = <dynamic>[
  <String, dynamic>{'firstName': 'Test', 'lastName': 'Guest', 'adult': true},
];

class _FakeRepository implements BookingRepository {
  ApiResult<BookingRecord>? createResult;
  int createCalls = 0;
  int revalidateCalls = 0;

  @override
  Future<ApiResult<BookingRecord>> createBooking(
    String bookingId,
    String idempotencyKey,
    List<dynamic> travelers,
  ) async {
    createCalls++;
    return createResult ??
        ApiResult.success(_record(status: BookingStatus.confirmed));
  }

  @override
  Future<ApiResult<BookingRecord>> prepareBooking(
    String offerId,
    String providerId,
    String searchId,
  ) async => ApiResult.success(_record());

  @override
  Future<ApiResult<BookingRecord>> revalidateBooking(String bookingId) async {
    revalidateCalls++;
    return ApiResult.success(_record());
  }

  @override
  Future<ApiResult<BookingRecord>> getBooking(String bookingId) async =>
      ApiResult.success(_record());

  @override
  Future<ApiResult<BookingRecord>> getBookingStatus(String bookingId) async =>
      ApiResult.success(_record());

  @override
  Future<ApiResult<void>> cancelBooking(String bookingId) async =>
      const ApiResult<void>.success(null);
}

/// A minimal client so the REAL [BookingRepositoryImpl] is exercised: the test
/// proves the repository forwards the 409 body instead of swallowing it.
class _FakeClient implements ApiClient {
  _FakeClient(this._response);

  final ApiResult<Map<String, dynamic>> _response;

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
  }) async => _response as ApiResult<T>;

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => _response as ApiResult<T>;

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

BookingController _controller(BookingRepository repository) {
  return BookingController(
    prepareUseCase: PrepareBookingUseCase(repository),
    revalidateUseCase: RevalidateBookingUseCase(repository),
    confirmUseCase: ConfirmBookingUseCase(repository),
    bagController: BagController(),
  );
}

SelectedOffer _offer() => SelectedOffer(
  offerId: 'offer-1',
  providerId: 'nuitee',
  providerName: 'Nuitee Connect',
  price: 100,
  currency: 'USD',
  searchId: 'search-1',
  offerType: 'hotel',
  title: 'Cairo stay',
  subtitle: 'Cairo',
);

Future<void> _pumpReview(
  WidgetTester tester, {
  required BookingController controller,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/booking/review',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/booking/review',
        builder: (BuildContext context, GoRouterState state) =>
            const BookingReviewPage(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        bookingControllerProvider.overrideWith((ref) => controller),
        selectedOfferProvider.overrideWith((ref) => _offer()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: const <Locale>[Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  // The review page hosts a BackdropFilter bar; a fixed pump is used instead
  // of pumpAndSettle for the same reason as the other review-page tests.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('booking outcome mapping', () {
    test('canonical 409 unknown-outcome body maps to bookingOutcomeUnknown',
        () {
      expect(
        bookingErrorCodeFrom(_error(_unknownBody())),
        BookingErrorCode.bookingOutcomeUnknown,
      );
    });

    test('structured reconciliation flags map even without a code', () {
      expect(
        bookingErrorCodeFrom(_error(_unknownBody(includeCode: false))),
        BookingErrorCode.bookingOutcomeUnknown,
      );
    });

    test('an ordinary duplicate_request 409 stays duplicateRequest', () {
      final error = _error(<String, dynamic>{
        'code': 'duplicate_request',
        'message': 'This booking request was already submitted.',
      });
      expect(bookingErrorCodeFrom(error), BookingErrorCode.duplicateRequest);
    });

    test('a price_changed 409 keeps the price-change flow', () {
      final error = _error(<String, dynamic>{
        'code': 'price_changed',
        'message': 'The price changed.',
        'details': <String, dynamic>{'priceChange': <String, dynamic>{}},
      });
      expect(bookingErrorCodeFrom(error), BookingErrorCode.priceChanged);
    });

    test('bookingErrorFrom preserves the backend message and details', () {
      final parsed = bookingErrorFrom(_error(_unknownBody()));
      expect(parsed.code, BookingErrorCode.bookingOutcomeUnknown);
      expect(parsed.details['status'], 'reconciliation_pending');
      expect(parsed.details['requiresReconciliation'], isTrue);
      expect(parsed.details['retryable'], isFalse);
      expect(parsed.message, contains('do not retry'));
    });
  });

  group('repository transport', () {
    test('BookingRepositoryImpl forwards the 409 body', () async {
      final repository = BookingRepositoryImpl(
        _FakeClient(
          ApiResult<Map<String, dynamic>>.failure(_error(_unknownBody())),
        ),
      );

      final result = await repository.createBooking('bk-1', 'key-1', _validTravelers);
      final error = result.when(
        success: (_) => null,
        failure: (e) => e,
      );

      expect(error, isNotNull);
      final failure = error!;
      expect(bookingErrorFrom(failure).code, BookingErrorCode.bookingOutcomeUnknown);
      expect(failure.statusCode, 409);
      expect(failure.message, contains('booking_outcome_unknown'));
    });
  });

  group('booking controller', () {
    test('unknown outcome becomes reconciliationPending and never failed',
        () async {
      final repository = _FakeRepository()
        ..createResult = ApiResult<BookingRecord>.failure(
          _error(_unknownBody()),
        );
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      controller.state = _readyState();

      await controller.confirm(travelers: _validTravelers);

      expect(repository.createCalls, 1);
      expect(controller.state.phase, BookingPhase.reconciliationPending);
      expect(controller.state.phase, isNot(BookingPhase.failed));
      expect(controller.state.phase, isNot(BookingPhase.confirmed));
      expect(
        controller.state.errorCode,
        BookingErrorCode.bookingOutcomeUnknown,
      );
      expect(controller.state.record?.bookingId, 'bk-1');
      expect(controller.state.idempotencyKey, isNotNull);
    });

    test('a second confirm while pending is a no-op (no double booking)',
        () async {
      final repository = _FakeRepository()
        ..createResult = ApiResult<BookingRecord>.failure(
          _error(_unknownBody()),
        );
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      controller.state = _readyState();

      await controller.confirm(travelers: _validTravelers);
      final pending = controller.state;
      await controller.confirm(travelers: _validTravelers);

      expect(repository.createCalls, 1);
      expect(controller.state.phase, BookingPhase.reconciliationPending);
      expect(controller.state.idempotencyKey, pending.idempotencyKey);
      expect(identical(controller.state, pending), isTrue);
    });

    test('revalidate while pending does not call the provider again', () async {
      final repository = _FakeRepository()
        ..createResult = ApiResult<BookingRecord>.failure(
          _error(_unknownBody()),
        );
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      controller.state = _readyState();

      await controller.confirm(travelers: _validTravelers);
      await controller.revalidate(bookingId: 'bk-1');

      expect(repository.revalidateCalls, 0);
      expect(controller.state.phase, BookingPhase.reconciliationPending);
    });

    test('a definitive duplicate failure still uses the failed phase', () async {
      final repository = _FakeRepository()
        ..createResult = ApiResult<BookingRecord>.failure(
          _error(<String, dynamic>{
            'code': 'duplicate_request',
            'message': 'This booking request was already submitted.',
          }),
        );
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      controller.state = _readyState();

      await controller.confirm(travelers: _validTravelers);

      expect(controller.state.phase, BookingPhase.failed);
      expect(controller.state.errorCode, BookingErrorCode.duplicateRequest);
    });
  });

  group('review page', () {
    testWidgets('shows pending verification with no retry and no confirmation',
        (tester) async {
      final controller = _controller(_FakeRepository());
      addTearDown(controller.dispose);
      controller.state = BookingState(
        phase: BookingPhase.reconciliationPending,
        record: _record(),
        preparation: _preparation(),
        errorCode: BookingErrorCode.bookingOutcomeUnknown,
        errorMessage: 'pending',
      );

      await _pumpReview(tester, controller: controller);

      expect(find.text('Booking is being verified'), findsOneWidget);
      expect(find.textContaining('Do not retry the booking'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Confirmed'), findsNothing);
      expect(find.text('Back to home'), findsOneWidget);

      await tester.tap(find.text('Back to home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('HOME'), findsOneWidget);
    });
  });
}
