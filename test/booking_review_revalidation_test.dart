import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/booking/booking.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/booking_repository.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/bag/application/bag_controller.dart';
import 'package:tokigo/features/booking/application/booking_controller.dart';
import 'package:tokigo/features/booking/application/booking_providers.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/application/confirm_booking_usecase.dart';
import 'package:tokigo/features/booking/application/decide_price_change_usecase.dart';
import 'package:tokigo/features/booking/application/prepare_booking_usecase.dart';
import 'package:tokigo/features/booking/application/revalidate_booking_usecase.dart';
import 'package:tokigo/features/booking/domain/booking_error.dart';
import 'package:tokigo/features/booking/domain/booking_preparation.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/booking/domain/price_change.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/features/search/presentation/pages/booking_review_page.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Phase 2E — the booking review page's single pre-checkout revalidation path.
///
/// The review page no longer calls the generic `/offers/revalidate` endpoint.
/// It revalidates the exact prepared booking through `/bookings/revalidate`,
/// which returns the backend-owned price/terms confirmation. A moved price or
/// changed condition blocks the funnel until the customer explicitly taps
/// "Update price"; a decline returns to offer selection; an unavailable or
/// expired offer cannot be retried into a booking.

SelectedOffer _offer(String providerId) => SelectedOffer(
  offerId: 'offer-1',
  providerId: providerId,
  providerName: providerId == 'nuitee-flight' ? 'Nuitee Flights' : 'Duffel',
  price: 800,
  currency: 'USD',
  searchId: 'search-1',
  offerType: 'flight',
  title: 'CAI → DXB',
  subtitle: 'Cairo to Dubai',
);

PriceChangeConfirmation _change({
  String providerId = 'nuitee-flight',
  double previousPrice = 800,
  double currentPrice = 950,
  bool priceChanged = true,
  bool termsChanged = false,
  List<String> changedTerms = const <String>[],
  bool requiresAcceptance = true,
  bool accepted = false,
  String? decision,
}) {
  final double difference = currentPrice - previousPrice;
  return PriceChangeConfirmation(
    providerId: providerId,
    offerId: 'offer-1',
    offerType: 'flight',
    previousPrice: previousPrice,
    currentPrice: currentPrice,
    currency: 'USD',
    priceDifference: difference,
    priceChangePercent: previousPrice == 0
        ? null
        : (difference / previousPrice) * 100,
    priceChanged: priceChanged,
    termsChanged: termsChanged,
    changedTerms: changedTerms,
    termsVersion: 'terms-v1-review',
    requiresAcceptance: requiresAcceptance,
    accepted: accepted,
    decision: decision,
    checkedAt: DateTime.utc(2026, 1, 2),
  );
}

BookingRecord _record({
  String providerId = 'nuitee-flight',
  String bookingId = 'bk-1',
  double price = 800,
  BookingStatus status = BookingStatus.pending,
  PriceChangeConfirmation? priceChange,
}) {
  return BookingRecord(
    bookingId: bookingId,
    userId: 'user-1',
    searchId: 'search-1',
    offerId: 'offer-1',
    providerId: providerId,
    providerName: 'Nuitee Flights',
    type: 'flight',
    status: status,
    currency: 'USD',
    authoritativePrice: price,
    priceBreakdown: PriceBreakdown.empty,
    travelers: const <Passenger>[],
    bookingReference: '',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    priceChange: priceChange,
  );
}

class _FakeRepository implements BookingRepository {
  int prepareCalls = 0;
  int revalidateCalls = 0;
  int createCalls = 0;

  /// Result of the next `revalidateBooking` call. Null → an unchanged record.
  ApiResult<BookingRecord>? revalidateResult;

  /// Dynamic result, evaluated with the 1-based call number.
  ApiResult<BookingRecord> Function(int call)? revalidateResponder;

  @override
  Future<ApiResult<BookingRecord>> prepareBooking(
    String offerId,
    String providerId,
    String searchId,
  ) async {
    prepareCalls++;
    return ApiResult.success(_record(providerId: providerId, price: 800));
  }

  @override
  Future<ApiResult<BookingRecord>> revalidateBooking(String bookingId) async {
    revalidateCalls++;
    return revalidateResponder?.call(revalidateCalls) ??
        revalidateResult ??
        ApiResult.success(_record(price: 800));
  }

  @override
  Future<ApiResult<BookingRecord>> createBooking(
    String bookingId,
    String idempotencyKey,
    List<dynamic> travelers,
  ) async {
    createCalls++;
    return ApiResult.success(
      _record(status: BookingStatus.confirmed, price: 800),
    );
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

class _FakeDecisionRepository implements PriceChangeDecisionRepository {
  int calls = 0;
  String? decision;
  double? expectedPrice;
  String? expectedCurrency;
  String? expectedTermsVersion;
  ApiResult<BookingRecord> Function()? responder;

  @override
  Future<ApiResult<BookingRecord>> decidePriceChange(
    String bookingId, {
    required String decision,
    double? expectedPrice,
    String? expectedCurrency,
    String? expectedTermsVersion,
  }) async {
    calls++;
    this.decision = decision;
    this.expectedPrice = expectedPrice;
    this.expectedCurrency = expectedCurrency;
    this.expectedTermsVersion = expectedTermsVersion;
    return responder?.call() ??
        ApiResult.success(
          _record(
            price: 950,
            priceChange: _change(
              requiresAcceptance: false,
              accepted: true,
              decision: 'accepted',
            ),
          ),
        );
  }
}

Future<void> _pumpReview(
  WidgetTester tester, {
  required BookingController controller,
  required SelectedOffer offer,
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
        routes: <RouteBase>[
          GoRoute(
            path: 'passengers',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('PASSENGERS')),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        bookingControllerProvider.overrideWith((ref) => controller),
        selectedOfferProvider.overrideWith((ref) => offer),
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
  await _settle(tester);
}

/// The review page hosts a `BackdropFilter` bar; `pumpAndSettle` never settles
/// on it in a test host, so a fixed pump is used instead.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

BookingController _controller(
  BookingRepository repo, {
  PriceChangeDecisionRepository? decisions,
}) => BookingController(
  prepareUseCase: PrepareBookingUseCase(repo),
  revalidateUseCase: RevalidateBookingUseCase(repo),
  confirmUseCase: ConfirmBookingUseCase(repo),
  decidePriceChangeUseCase: decisions == null
      ? null
      : DecidePriceChangeUseCase(decisions),
  bagController: BagController(),
);

BookingState _readyState({
  String providerId = 'nuitee-flight',
  BookingRecord? record,
}) {
  return BookingState(
    phase: BookingPhase.readyToConfirm,
    record: record ?? _record(providerId: providerId),
    preparation: BookingPreparation(
      request: const BookingRequest(
        offerId: 'offer-1',
        providerId: 'nuitee-flight',
        searchId: 'search-1',
      ),
      revalidation: const PriceRevalidationResult(
        authoritativePrice: 800,
        currency: 'USD',
        priceChanged: false,
        available: true,
      ),
    ),
  );
}

ApiResult<BookingRecord> _failure(String code, String message) {
  return ApiResult<BookingRecord>.failure(
    ApiClientError(
      message: jsonEncode(<String, dynamic>{'code': code, 'message': message}),
      statusCode: code == 'booking_expired' ? 409 : 503,
    ),
  );
}

void main() {
  testWidgets('P3-D7 a valid Nuitee revalidation enables Continue', (
    tester,
  ) async {
    final _FakeRepository repo = _FakeRepository();
    final BookingController controller = _controller(repo);

    await _pumpReview(
      tester,
      controller: controller,
      offer: _offer('nuitee-flight'),
    );
    controller.state = _readyState();
    await tester.pump();

    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await _settle(tester);

    // The funnel advanced through the single booking revalidation path.
    expect(find.text('PASSENGERS'), findsOneWidget);
    expect(repo.revalidateCalls, 1);
    expect(repo.prepareCalls, 0);
    expect(repo.createCalls, 0);
  });

  testWidgets('P3-D7 a price change requires explicit acceptance', (
    tester,
  ) async {
    final _FakeRepository repo = _FakeRepository()
      ..revalidateResult = ApiResult.success(
        _record(price: 950, priceChange: _change()),
      );
    final _FakeDecisionRepository decisions = _FakeDecisionRepository();
    final BookingController controller = _controller(
      repo,
      decisions: decisions,
    );

    await _pumpReview(
      tester,
      controller: controller,
      offer: _offer('nuitee-flight'),
    );
    controller.state = _readyState();
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await _settle(tester);

    // Blocked: the shared price/terms banner is shown and nothing navigated.
    expect(find.text('PASSENGERS'), findsNothing);
    expect(controller.state.phase, BookingPhase.priceChanged);
    expect(find.text('Price changed'), findsOneWidget);
    expect(find.text('Previous price: 800.00 USD'), findsOneWidget);
    expect(find.text('Updated price: 950.00 USD'), findsOneWidget);
    expect(find.text('Difference: +150.00 USD (+18.75%)'), findsOneWidget);
    expect(
      find.text('No booking has been made at the updated price.'),
      findsOneWidget,
    );
    expect(find.text('Update price'), findsWidgets);
    expect(find.text('Decline'), findsWidgets);
    expect(decisions.calls, 0);
    expect(repo.createCalls, 0);

    // Explicit acceptance is bound to the exact amount/currency/terms shown.
    await tester.tap(find.text('Update price').last);
    await _settle(tester);

    expect(decisions.calls, 1);
    expect(decisions.decision, 'accept');
    expect(decisions.expectedPrice, 950);
    expect(decisions.expectedCurrency, 'USD');
    expect(decisions.expectedTermsVersion, 'terms-v1-review');
    expect(controller.state.phase, BookingPhase.readyToConfirm);
    expect(controller.state.priceAccepted, isTrue);

    // The next Continue revalidates again and, with the accepted state live,
    // advances without another price decision.
    repo.revalidateResult = ApiResult.success(
      _record(
        price: 950,
        priceChange: _change(
          requiresAcceptance: false,
          accepted: true,
          decision: 'accepted',
        ),
      ),
    );
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    expect(find.text('PASSENGERS'), findsOneWidget);
    expect(decisions.calls, 1);
    expect(repo.createCalls, 0);
  });

  testWidgets('P3-D7 a terms-only change blocks Continue until accepted', (
    tester,
  ) async {
    final _FakeRepository repo = _FakeRepository()
      ..revalidateResult = ApiResult.success(
        _record(
          price: 800,
          priceChange: _change(
            currentPrice: 800,
            priceChanged: false,
            termsChanged: true,
            changedTerms: const <String>[
              'conditions',
              'baggageAllowances',
            ],
          ),
        ),
      );
    final _FakeDecisionRepository decisions = _FakeDecisionRepository();
    final BookingController controller = _controller(
      repo,
      decisions: decisions,
    );

    await _pumpReview(
      tester,
      controller: controller,
      offer: _offer('nuitee-flight'),
    );
    controller.state = _readyState();
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await _settle(tester);

    expect(find.text('PASSENGERS'), findsNothing);
    expect(controller.state.phase, BookingPhase.priceChanged);
    expect(find.text('Conditions changed'), findsOneWidget);
    expect(find.text('• Fare conditions'), findsOneWidget);
    expect(find.text('• Baggage allowance'), findsOneWidget);
    expect(find.textContaining('Difference:'), findsNothing);
    expect(repo.createCalls, 0);

    await tester.tap(find.text('Update price').last);
    await _settle(tester);

    expect(decisions.calls, 1);
    expect(controller.state.phase, BookingPhase.readyToConfirm);
  });

  testWidgets('P3-D7 a revalidation failure blocks Continue', (tester) async {
    final _FakeRepository repo = _FakeRepository()
      ..revalidateResult = _failure(
        'no_availability',
        'This offer is no longer available. Please pick another.',
      );
    final BookingController controller = _controller(repo);

    await _pumpReview(
      tester,
      controller: controller,
      offer: _offer('nuitee-flight'),
    );
    controller.state = _readyState();
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await _settle(tester);

    expect(find.text('PASSENGERS'), findsNothing);
    expect(controller.state.phase, BookingPhase.unavailable);
    expect(
      find.text('This offer is no longer available. Please pick another.'),
      findsOneWidget,
    );
    expect(find.text('Choose another offer'), findsWidgets);
    expect(repo.prepareCalls, 0);
    expect(repo.createCalls, 0);
  });

  testWidgets('P3-D7 an expired offer is distinguishable and blocks Continue', (
    tester,
  ) async {
    final _FakeRepository repo = _FakeRepository()
      ..revalidateResult = _failure(
        'booking_expired',
        'This offer has expired. Please search again.',
      );
    final BookingController controller = _controller(repo);

    await _pumpReview(
      tester,
      controller: controller,
      offer: _offer('nuitee-flight'),
    );
    controller.state = _readyState();
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await _settle(tester);

    expect(find.text('PASSENGERS'), findsNothing);
    expect(controller.state.phase, BookingPhase.expired);
    expect(
      find.text('This offer has expired. Please search again.'),
      findsOneWidget,
    );
    expect(find.text('Choose another offer'), findsWidgets);
    expect(repo.createCalls, 0);
  });

  testWidgets('P3-D7 retry after a failure does not reset booking state', (
    tester,
  ) async {
    final _FakeRepository repo = _FakeRepository()
      ..revalidateResponder = (int call) => call == 1
          ? _failure('provider_error', 'The provider is temporarily down.')
          : ApiResult.success(_record(price: 800));
    final BookingController controller = _controller(repo);

    await _pumpReview(
      tester,
      controller: controller,
      offer: _offer('nuitee-flight'),
    );
    controller.state = _readyState();
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await _settle(tester);
    expect(controller.state.phase, BookingPhase.error);

    await tester.tap(find.text('Retry').last);
    await _settle(tester);
    expect(controller.state.phase, BookingPhase.readyToConfirm);

    await tester.tap(find.text('Continue'));
    await _settle(tester);
    expect(find.text('PASSENGERS'), findsOneWidget);

    // The SAME booking record was reused — no duplicate prepare/create.
    expect(repo.revalidateCalls, 3);
    expect(repo.prepareCalls, 0);
    expect(repo.createCalls, 0);
    expect(controller.state.record?.bookingId, 'bk-1');
  });

  testWidgets('P3-D7 declining the update returns to offer selection', (
    tester,
  ) async {
    final _FakeRepository repo = _FakeRepository()
      ..revalidateResult = ApiResult.success(
        _record(price: 950, priceChange: _change()),
      );
    final _FakeDecisionRepository decisions = _FakeDecisionRepository()
      ..responder = () => ApiResult.success(
        _record(
          price: 950,
          priceChange: _change(
            requiresAcceptance: false,
            decision: 'declined',
          ),
        ),
      );
    final BookingController controller = _controller(
      repo,
      decisions: decisions,
    );

    await _pumpReview(
      tester,
      controller: controller,
      offer: _offer('nuitee-flight'),
    );
    controller.state = _readyState();
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await _settle(tester);
    expect(controller.state.phase, BookingPhase.priceChanged);

    await tester.tap(find.text('Decline').last);
    await _settle(tester);

    expect(decisions.calls, 1);
    expect(decisions.decision, 'decline');
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('PASSENGERS'), findsNothing);
    expect(repo.createCalls, 0);
  });

  testWidgets('P3-D7 a stale acceptance shows the fresh change again', (
    tester,
  ) async {
    final _FakeRepository repo = _FakeRepository()
      ..revalidateResult = ApiResult.success(
        _record(price: 950, priceChange: _change()),
      );
    final _FakeDecisionRepository decisions = _FakeDecisionRepository()
      ..responder = () => ApiResult.failure(
        ApiClientError(
          message: jsonEncode(<String, dynamic>{
            'code': 'price_changed',
            'message': 'The offer changed again; please review the latest '
                'price and conditions',
            'details': <String, dynamic>{
              'priceChange': <String, dynamic>{
                'providerId': 'nuitee-flight',
                'offerId': 'offer-1',
                'offerType': 'flight',
                'previousPrice': 800,
                'currentPrice': 975,
                'currency': 'USD',
                'priceDifference': 175,
                'priceChangePercent': 21.875,
                'priceChanged': true,
                'termsChanged': false,
                'changedTerms': <String>[],
                'termsVersion': 'terms-v1-review-2',
                'requiresAcceptance': true,
                'accepted': false,
                'decision': null,
                'checkedAt': '2026-01-02T00:00:00.000Z',
              },
            },
          }),
          statusCode: 409,
        ),
      );
    final BookingController controller = _controller(
      repo,
      decisions: decisions,
    );

    await _pumpReview(
      tester,
      controller: controller,
      offer: _offer('nuitee-flight'),
    );
    controller.state = _readyState();
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await _settle(tester);
    await tester.tap(find.text('Update price').last);
    await _settle(tester);

    // The acceptance was rejected because the offer moved again. The fresh
    // amount is displayed and a NEW acceptance is required.
    expect(find.text('PASSENGERS'), findsNothing);
    expect(controller.state.phase, BookingPhase.priceChanged);
    expect(find.text('Updated price: 975.00 USD'), findsOneWidget);
    expect(find.text('Difference: +175.00 USD (+21.88%)'), findsOneWidget);
    expect(controller.state.record?.priceChange?.termsVersion,
        'terms-v1-review-2');
    expect(repo.createCalls, 0);
  });

  testWidgets('P3-D7 Duffel review behaviour is unchanged', (tester) async {
    final _FakeRepository repo = _FakeRepository();
    final BookingController controller = _controller(repo);

    await _pumpReview(
      tester,
      controller: controller,
      offer: _offer('duffel-flight'),
    );
    controller.state = _readyState(providerId: 'duffel-flight');
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await _settle(tester);

    expect(find.text('PASSENGERS'), findsOneWidget);
    expect(repo.revalidateCalls, 1);
    expect(repo.createCalls, 0);
    expect(controller.state.phase, BookingPhase.readyToConfirm);
  });

  test('P3-D7 a confirm-time change is surfaced instead of a generic failure', () async {
    final ApiResult<BookingRecord> createFailure = ApiResult.failure(
      ApiClientError(
        message: jsonEncode(<String, dynamic>{
          'code': 'price_changed',
          'message': 'The offer price changed before confirmation',
          'details': <String, dynamic>{
            'priceChange': <String, dynamic>{
              'providerId': 'nuitee-flight',
              'offerId': 'offer-1',
              'offerType': 'flight',
              'previousPrice': 800,
              'currentPrice': 925,
              'currency': 'USD',
              'priceDifference': 125,
              'priceChangePercent': 15.625,
              'priceChanged': true,
              'termsChanged': false,
              'changedTerms': <String>[],
              'termsVersion': 'terms-v1-review-3',
              'requiresAcceptance': true,
              'accepted': false,
              'decision': null,
              'checkedAt': '2026-01-02T00:00:00.000Z',
            },
          },
        }),
        statusCode: 409,
      ),
    );

    // The repository's create result is replaced through a responder-like fake.
    final _CreateFailingRepository failingRepo = _CreateFailingRepository(
      createFailure,
    );
    final BookingController failingController = _controller(failingRepo);
    addTearDown(failingController.dispose);
    failingController.state = BookingState(
      phase: BookingPhase.readyToConfirm,
      record: _record(price: 800),
      preparation: _readyState().preparation,
      priceAccepted: true,
    );

    await failingController.confirm();

    expect(failingController.state.phase, BookingPhase.priceChanged);
    expect(failingController.state.errorCode, BookingErrorCode.priceChanged);
    expect(
      failingController.state.record?.priceChange?.currentPrice,
      925,
    );
    expect(failingController.state.record?.priceChange?.termsVersion,
        'terms-v1-review-3');
  });
}

/// Repository whose create call reports a price change discovered at confirm
/// time. Kept separate so the common fake stays simple.
class _CreateFailingRepository extends _FakeRepository {
  _CreateFailingRepository(this.result);

  final ApiResult<BookingRecord> result;

  @override
  Future<ApiResult<BookingRecord>> createBooking(
    String bookingId,
    String idempotencyKey,
    List<dynamic> travelers,
  ) async {
    createCalls++;
    return result;
  }
}
