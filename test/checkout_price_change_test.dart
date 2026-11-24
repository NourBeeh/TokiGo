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
import 'package:tokigo/core/storage/secure_token_storage.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/features/bag/application/bag_controller.dart';
import 'package:tokigo/features/booking/application/booking_controller.dart';
import 'package:tokigo/features/booking/application/booking_providers.dart';
import 'package:tokigo/features/booking/application/booking_state.dart';
import 'package:tokigo/features/booking/application/confirm_booking_usecase.dart';
import 'package:tokigo/features/booking/application/prepare_booking_usecase.dart';
import 'package:tokigo/features/booking/application/revalidate_booking_usecase.dart';
import 'package:tokigo/features/booking/application/services/checkout_payment_service.dart';
import 'package:tokigo/features/booking/domain/booking_preparation.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/booking/domain/price_change.dart';
import 'package:tokigo/features/booking/presentation/pages/checkout_page.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Phase 2E — checkout revalidates the exact prepared booking immediately
/// before charging. A moved price/terms stops the charge and returns to the
/// review page, where the customer must explicitly accept the update.

PriceChangeConfirmation _change({double previousPrice = 800}) {
  const double currentPrice = 950;
  return PriceChangeConfirmation(
    providerId: 'duffel-flight',
    offerId: 'off-1',
    offerType: 'flight',
    previousPrice: previousPrice,
    currentPrice: currentPrice,
    currency: 'USD',
    priceDifference: currentPrice - previousPrice,
    priceChangePercent:
        ((currentPrice - previousPrice) / previousPrice) * 100,
    priceChanged: true,
    termsChanged: false,
    changedTerms: const <String>[],
    termsVersion: 'terms-v1-checkout',
    requiresAcceptance: true,
    accepted: false,
    checkedAt: DateTime.utc(2026, 1, 2),
  );
}

BookingRecord _record({
  double price = 800,
  PriceChangeConfirmation? priceChange,
  BookingStatus status = BookingStatus.pending,
}) {
  return BookingRecord(
    bookingId: 'bk-1',
    userId: 'user-1',
    searchId: 'search-1',
    offerId: 'off-1',
    providerId: 'duffel-flight',
    providerName: 'Duffel',
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
  int revalidateCalls = 0;
  int createCalls = 0;
  ApiResult<BookingRecord>? revalidateResult;

  @override
  Future<ApiResult<BookingRecord>> prepareBooking(
    String offerId,
    String providerId,
    String searchId,
  ) async => ApiResult.success(_record());

  @override
  Future<ApiResult<BookingRecord>> revalidateBooking(String bookingId) async {
    revalidateCalls++;
    return revalidateResult ?? ApiResult.success(_record());
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

class _PaymentService implements CheckoutPaymentService {
  int calls = 0;
  PaymentOutcome outcome = PaymentOutcome.succeeded;

  @override
  SecureTokenStorage? get tokenStorage => null;

  @override
  Future<CheckoutPaymentResult> pay({
    required String bookingId,
    required double amount,
    required String currency,
    required String market,
    required String idempotencyKey,
    required String method,
  }) async {
    calls++;
    return CheckoutPaymentResult(outcome: outcome);
  }
}

const SelectedOffer _offer = SelectedOffer(
  offerId: 'off-1',
  providerId: 'duffel-flight',
  providerName: 'Duffel',
  price: 800,
  currency: 'USD',
  searchId: 'search-1',
  offerType: 'flight',
  title: 'CAI → DXB',
  subtitle: 'Cairo to Dubai',
);

class _Harness {
  _Harness({
    required this.repo,
    required this.payment,
    required this.controller,
  });

  final _FakeRepository repo;
  final _PaymentService payment;
  final BookingController controller;

  static Future<_Harness> pump(
    WidgetTester tester, {
    ApiResult<BookingRecord>? revalidateResult,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeRepository()..revalidateResult = revalidateResult;
    final payment = _PaymentService();
    final controller = BookingController(
      prepareUseCase: PrepareBookingUseCase(repo),
      revalidateUseCase: RevalidateBookingUseCase(repo),
      confirmUseCase: ConfirmBookingUseCase(repo),
      bagController: BagController(),
    );
    controller.state = BookingState(
      phase: BookingPhase.readyToConfirm,
      record: _record(),
      preparation: const BookingPreparation(
        request: BookingRequest(
          offerId: 'off-1',
          providerId: 'duffel-flight',
          searchId: 'search-1',
        ),
        revalidation: PriceRevalidationResult(
          authoritativePrice: 800,
          currency: 'USD',
          priceChanged: false,
          available: true,
        ),
      ),
    );

    final GoRouter router = GoRouter(
      initialLocation: '/booking/review/checkout',
      routes: <RouteBase>[
        GoRoute(
          path: '/booking/review/checkout',
          builder: (BuildContext context, GoRouterState state) =>
              const CheckoutPage(),
        ),
        GoRoute(
          path: '/booking/review',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('REVIEW')),
        ),
        GoRoute(
          path: '/booking/review/confirmation',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('CONFIRMED')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          bookingControllerProvider.overrideWith((ref) => controller),
          checkoutPaymentServiceProvider.overrideWithValue(payment),
          selectedOfferProvider.overrideWith((ref) => _offer),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: const <Locale>[Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _Harness(repo: repo, payment: payment, controller: controller);
  }

  Future<void> pay(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), '4242424242424242');
    await tester.enterText(find.byType(TextField).at(1), 'Nour Adel');
    await tester.enterText(find.byType(TextField).at(2), '12/30');
    await tester.enterText(find.byType(TextField).at(3), '123');
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('a price change at pre-charge time never charges or books', (
    tester,
  ) async {
    final harness = await _Harness.pump(
      tester,
      revalidateResult: ApiResult.success(
        _record(price: 950, priceChange: _change()),
      ),
    );

    await harness.pay(tester);

    expect(harness.repo.revalidateCalls, 1);
    expect(harness.payment.calls, 0);
    expect(harness.repo.createCalls, 0);
    expect(harness.controller.state.phase, BookingPhase.priceChanged);
    expect(find.text('REVIEW'), findsOneWidget);
    expect(find.text('CONFIRMED'), findsNothing);
  });

  testWidgets('a terms-only change at pre-charge time never charges or books', (
    tester,
  ) async {
    final harness = await _Harness.pump(
      tester,
      revalidateResult: ApiResult.success(
        _record(
          price: 800,
          priceChange: PriceChangeConfirmation(
            providerId: 'duffel-flight',
            offerId: 'off-1',
            offerType: 'flight',
            previousPrice: 800,
            currentPrice: 800,
            currency: 'USD',
            priceDifference: 0,
            priceChanged: false,
            termsChanged: true,
            changedTerms: const <String>['conditions'],
            termsVersion: 'terms-v1-checkout-2',
            requiresAcceptance: true,
            accepted: false,
            checkedAt: DateTime.utc(2026, 1, 2),
          ),
        ),
      ),
    );

    await harness.pay(tester);

    expect(harness.payment.calls, 0);
    expect(harness.repo.createCalls, 0);
    expect(harness.controller.state.phase, BookingPhase.priceChanged);
    expect(find.text('REVIEW'), findsOneWidget);
  });

  testWidgets('an unavailable offer at pre-charge time never charges', (
    tester,
  ) async {
    final harness = await _Harness.pump(
      tester,
      revalidateResult: ApiResult.failure(
        ApiClientError(
          message: jsonEncode(<String, dynamic>{
            'code': 'no_availability',
            'message': 'This offer is no longer available. Please pick another.',
          }),
          statusCode: 409,
        ),
      ),
    );

    await harness.pay(tester);

    expect(harness.payment.calls, 0);
    expect(harness.repo.createCalls, 0);
    expect(harness.controller.state.phase, BookingPhase.unavailable);
    expect(find.text('CONFIRMED'), findsNothing);
  });

  testWidgets('an unchanged offer charges exactly once and confirms', (
    tester,
  ) async {
    final harness = await _Harness.pump(tester);

    await harness.pay(tester);

    expect(harness.repo.revalidateCalls, 1);
    expect(harness.payment.calls, 1);
    expect(harness.repo.createCalls, 1);
    expect(harness.controller.state.phase, BookingPhase.confirmed);
    expect(find.text('CONFIRMED'), findsOneWidget);
  });
}
