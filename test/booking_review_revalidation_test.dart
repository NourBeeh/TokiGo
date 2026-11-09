import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/booking/booking.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/booking_repository.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/bag/application/bag_controller.dart';
import 'package:tokigo/features/booking/application/booking_controller.dart';
import 'package:tokigo/features/booking/application/booking_providers.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/application/confirm_booking_usecase.dart';
import 'package:tokigo/features/booking/application/prepare_booking_usecase.dart';
import 'package:tokigo/features/booking/application/revalidate_booking_usecase.dart';
import 'package:tokigo/features/booking/application/services/offer_revalidation_service.dart';
import 'package:tokigo/features/booking/domain/booking_preparation.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/features/search/presentation/pages/booking_review_page.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// P3-D7 — the booking review page's pre-checkout offer revalidation.
///
/// The review page used to hit `/offers/revalidate`, which had no Nuitee flight
/// path and answered `UNAVAILABLE` for EVERY Nuitee flight offer — so Continue
/// could never advance. These tests pin the Flutter side of the fixed flow:
/// a supported provider advances, a price change needs explicit acceptance, a
/// failure blocks the funnel, and a retry never duplicates booking state.

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

BookingRecord _record({
  String providerId = 'nuitee-flight',
  String bookingId = 'bk-1',
  double price = 800,
  BookingStatus status = BookingStatus.pending,
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
  );
}

class _FakeRepository implements BookingRepository {
  int prepareCalls = 0;
  int revalidateCalls = 0;
  int createCalls = 0;
  double reviewPrice = 800;

  @override
  Future<ApiResult<BookingRecord>> prepareBooking(
    String offerId,
    String providerId,
    String searchId,
  ) async {
    prepareCalls++;
    return ApiResult.success(
      _record(providerId: providerId, price: 800),
    );
  }

  @override
  Future<ApiResult<BookingRecord>> revalidateBooking(String bookingId) async {
    revalidateCalls++;
    return ApiResult.success(_record(price: reviewPrice));
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

/// Fake `/offers/revalidate` transport. Only the offer check is exercised.
class _FakeOfferClient implements ApiClient {
  _FakeOfferClient(this._responder);

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
  }) async =>
      throw UnimplementedError('get');

  @override
  Future<ApiResult<T>> put<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async =>
      throw UnimplementedError('put');

  @override
  Future<ApiResult<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async =>
      throw UnimplementedError('patch');

  @override
  Future<ApiResult<T>> delete<T>(
    String path, {
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async =>
      throw UnimplementedError('delete');

  @override
  ApiResult<T> mapError<T>(Object error, {StackTrace? stackTrace}) =>
      ApiResult.failure(ApiUnknownError(message: error.toString()));
}

ApiResult<Map<String, dynamic>> _ok() => ApiResult.success(
  <String, dynamic>{
    'status': 'OK',
    'offerId': 'offer-1',
    'price': 800,
    'currency': 'USD',
  },
);

ApiResult<Map<String, dynamic>> _priceChanged() => ApiResult.success(
  <String, dynamic>{
    'status': 'PRICE_CHANGED',
    'offerId': 'offer-1',
    'oldPrice': 800,
    'newPrice': 950,
    'currency': 'USD',
  },
);

ApiResult<Map<String, dynamic>> _unavailable({String? reason}) =>
    ApiResult.success(
      <String, dynamic>{
        'status': 'UNAVAILABLE',
        'offerId': 'offer-1',
        'reason': reason ?? 'This offer is no longer available.',
      },
    );

ApiResult<Map<String, dynamic>> _expired() => ApiResult.success(
  <String, dynamic>{
    'status': 'UNAVAILABLE',
    'offerId': 'offer-1',
    'reason': 'offer expired',
  },
);

Future<void> _pumpReview(
  WidgetTester tester, {
  required BookingController controller,
  required ApiClient offerClient,
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
        offerRevalidationServiceProvider.overrideWithValue(
          OfferRevalidationService(offerClient),
        ),
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

BookingController _controller(BookingRepository repo) => BookingController(
  prepareUseCase: PrepareBookingUseCase(repo),
  revalidateUseCase: RevalidateBookingUseCase(repo),
  confirmUseCase: ConfirmBookingUseCase(repo),
  bagController: BagController(),
);

void main() {
  testWidgets('P3-D7 a valid Nuitee revalidation enables Continue', (
    tester,
  ) async {
    final _FakeRepository repo = _FakeRepository();
    final BookingController controller = _controller(repo);
    controller.state = BookingState(
      phase: BookingPhase.readyToConfirm,
      record: _record(),
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

    await _pumpReview(
      tester,
      controller: controller,
      offerClient: _FakeOfferClient((_) => _ok()),
      offer: _offer('nuitee-flight'),
    );

    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await _settle(tester);

    // The funnel advanced — the offer is no longer treated as UNAVAILABLE.
    expect(find.text('PASSENGERS'), findsOneWidget);
    expect(repo.prepareCalls, 0);
  });

  testWidgets('P3-D7 a price change requires explicit acceptance', (
    tester,
  ) async {
    final _FakeRepository repo = _FakeRepository()..reviewPrice = 950;
    final BookingController controller = _controller(repo);
    controller.state = BookingState(
      phase: BookingPhase.readyToConfirm,
      record: _record(),
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

    final _FakeOfferClient client = _FakeOfferClient((_) => _priceChanged());
    await _pumpReview(
      tester,
      controller: controller,
      offerClient: client,
      offer: _offer('nuitee-flight'),
    );

    await tester.tap(find.text('Continue'));
    await _settle(tester);

    // Blocked: the price-change banner is shown and the funnel did not move.
    expect(find.text('PASSENGERS'), findsNothing);
    expect(find.text('Price changed'), findsOneWidget);
    expect(client.calls, <String>['/offers/revalidate']);

    // Explicit acceptance unblocks the funnel.
    await tester.tap(find.text('Accept new price').last);
    await _settle(tester);
    expect(controller.state.phase, BookingPhase.readyToConfirm);
    expect(controller.state.priceAccepted, isTrue);
  });

  testWidgets('P3-D7 a revalidation failure blocks Continue', (
    tester,
  ) async {
    final _FakeRepository repo = _FakeRepository();
    final BookingController controller = _controller(repo);
    controller.state = BookingState(
      phase: BookingPhase.readyToConfirm,
      record: _record(),
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

    await _pumpReview(
      tester,
      controller: controller,
      offerClient: _FakeOfferClient((_) => _unavailable()),
      offer: _offer('nuitee-flight'),
    );

    await tester.tap(find.text('Continue'));
    await _settle(tester);

    expect(find.text('PASSENGERS'), findsNothing);
    expect(controller.state.phase, BookingPhase.unavailable);
    // The booking record is untouched — a failed check never re-prepares.
    expect(repo.prepareCalls, 0);
    expect(repo.createCalls, 0);
  });

  testWidgets('P3-D7 an expired offer is distinguishable and blocks Continue', (
    tester,
  ) async {
    final _FakeRepository repo = _FakeRepository();
    final BookingController controller = _controller(repo);
    controller.state = BookingState(
      phase: BookingPhase.readyToConfirm,
      record: _record(),
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

    await _pumpReview(
      tester,
      controller: controller,
      offerClient: _FakeOfferClient((_) => _expired()),
      offer: _offer('nuitee-flight'),
    );

    await tester.tap(find.text('Continue'));
    await _settle(tester);

    expect(find.text('PASSENGERS'), findsNothing);
    expect(controller.state.phase, BookingPhase.expired);
    expect(find.text('This offer has expired. Please search again.'),
        findsOneWidget);
  });

  testWidgets('P3-D7 retry after a failure does not reset booking state', (
    tester,
  ) async {
    final _FakeRepository repo = _FakeRepository();
    final BookingController controller = _controller(repo);
    controller.state = BookingState(
      phase: BookingPhase.readyToConfirm,
      record: _record(),
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

    // First check fails, the retry succeeds.
    int calls = 0;
    final _FakeOfferClient client = _FakeOfferClient((_) {
      calls++;
      return calls == 1 ? _unavailable() : _ok();
    });

    await _pumpReview(
      tester,
      controller: controller,
      offerClient: client,
      offer: _offer('nuitee-flight'),
    );

    await tester.tap(find.text('Continue'));
    await _settle(tester);
    expect(controller.state.phase, BookingPhase.unavailable);

    await tester.tap(find.text('Retry').last);
    await _settle(tester);
    expect(controller.state.phase, BookingPhase.readyToConfirm);

    await tester.tap(find.text('Continue'));
    await _settle(tester);
    expect(find.text('PASSENGERS'), findsOneWidget);

    // The SAME booking record was reused — no duplicate prepare/create.
    expect(repo.prepareCalls, 0);
    expect(repo.createCalls, 0);
    expect(controller.state.record?.bookingId, 'bk-1');
  });

  testWidgets('P3-D7 Duffel review behaviour is unchanged', (tester) async {
    final _FakeRepository repo = _FakeRepository();
    final BookingController controller = _controller(repo);
    controller.state = BookingState(
      phase: BookingPhase.readyToConfirm,
      record: _record(providerId: 'duffel-flight'),
      preparation: BookingPreparation(
        request: const BookingRequest(
          offerId: 'offer-1',
          providerId: 'duffel-flight',
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

    final _FakeOfferClient client = _FakeOfferClient((_) => _ok());
    await _pumpReview(
      tester,
      controller: controller,
      offerClient: client,
      offer: _offer('duffel-flight'),
    );

    await tester.tap(find.text('Continue'));
    await _settle(tester);

    expect(client.calls, <String>['/offers/revalidate']);
    expect(find.text('PASSENGERS'), findsOneWidget);
  });
}
