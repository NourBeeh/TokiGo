import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/booking/booking.dart';
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
import 'package:tokigo/features/booking/application/idempotency_store.dart';
import 'package:tokigo/features/booking/application/prepare_booking_usecase.dart';
import 'package:tokigo/features/booking/application/providers/checkout_flow_providers.dart';
import 'package:tokigo/features/booking/application/revalidate_booking_usecase.dart';
import 'package:tokigo/features/booking/application/services/checkout_payment_service.dart';
import 'package:tokigo/features/booking/domain/booking_preparation.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/booking/presentation/pages/checkout_page.dart';
import 'package:tokigo/features/booking/presentation/pages/passenger_details_page.dart';
import 'package:tokigo/features/search/application/controllers/flight_search_controller.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// P3 — flight passenger flow: the search party hands off to the funnel, and
/// the checkout carries the FULL traveller record (not just the names).
///
/// Same seams as `hotel_guest_flow_test.dart`: a fake repository at the
/// booking boundary and a succeeding payment service.

SelectedOffer _flightOffer() => const SelectedOffer(
  offerId: 'offer-flight',
  providerId: 'duffel-flight',
  providerName: 'Duffel',
  price: 800,
  currency: 'USD',
  searchId: 'search-flight',
  offerType: 'flight',
  title: 'CAI → DXB',
  subtitle: 'Cairo to Dubai',
);

BookingRecord _record({
  String bookingId = 'bk-flight',
  String offerId = 'offer-flight',
  String providerId = 'duffel-flight',
  String searchId = 'search-flight',
  String type = 'flight',
  BookingStatus status = BookingStatus.pending,
}) {
  return BookingRecord(
    bookingId: bookingId,
    userId: 'user-1',
    searchId: searchId,
    offerId: offerId,
    providerId: providerId,
    providerName: 'Duffel',
    type: type,
    status: status,
    currency: 'USD',
    authoritativePrice: 800,
    priceBreakdown: PriceBreakdown.empty,
    travelers: const <Passenger>[],
    bookingReference: '',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

class _FakeBookingRepository implements BookingRepository {
  final List<List<dynamic>> travelersCalls = <List<dynamic>>[];

  @override
  Future<ApiResult<BookingRecord>> createBooking(
    String bookingId,
    String idempotencyKey,
    List<dynamic> travelers,
  ) async {
    travelersCalls.add(travelers);
    return ApiResult.success(
      _record(bookingId: bookingId, status: BookingStatus.confirmed),
    );
  }

  @override
  Future<ApiResult<BookingRecord>> prepareBooking(
    String offerId,
    String providerId,
    String searchId,
  ) async => ApiResult.success(
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

class _SucceededPaymentService implements CheckoutPaymentService {
  int calls = 0;

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
    return const CheckoutPaymentResult(outcome: PaymentOutcome.succeeded);
  }
}

Future<void> _pumpPassengerDetails(
  WidgetTester tester, {
  required ProviderContainer container,
}) async {
  // Three traveller cards do not fit the default 800x600 test surface; the
  // later cards would not be built and the count could not be asserted.
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: const <Locale>[Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const PassengerDetailsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('A. Search party hand-off', () {
    testWidgets('A1 a flight search party seeds the passenger details page', (
      tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          flightPassengerCompositionProvider.overrideWith(
            (ref) => const FlightPassengerComposition(
              adults: 1,
              children: 1,
              infants: 1,
              childAges: <int>[7],
              infantAges: <int>[1],
            ),
          ),
          selectedOfferProvider.overrideWith((ref) => _flightOffer()),
          checkoutTravelersProvider.overrideWith(
            (ref) => const <TravelerForm>[],
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pumpPassengerDetails(tester, container: container);

      expect(find.text('Passenger details 1 · Adult'), findsOneWidget);
      expect(find.text('Passenger details 2 · Child'), findsOneWidget);
      expect(find.text('Passenger details 3 · Infant'), findsOneWidget);
      expect(find.text('Passenger details 4'), findsNothing);
    });

    testWidgets('A2 a non-flight offer keeps the single-traveller default', (
      tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          flightPassengerCompositionProvider.overrideWith(
            (ref) => const FlightPassengerComposition(
              adults: 3,
              children: 0,
              infants: 0,
            ),
          ),
          selectedOfferProvider.overrideWith(
            (ref) => const SelectedOffer(
              offerId: 'offer-car',
              providerId: 'nuitee',
              providerName: 'Nuitee',
              price: 100,
              currency: 'USD',
              searchId: 'search-car',
              offerType: 'car',
            ),
          ),
          checkoutTravelersProvider.overrideWith(
            (ref) => const <TravelerForm>[],
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pumpPassengerDetails(tester, container: container);

      expect(find.text('Passenger details 1 · Adult'), findsOneWidget);
      expect(find.text('Passenger details 2'), findsNothing);
    });

    testWidgets('A3 an empty flight party falls back to one traveller', (
      tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          selectedOfferProvider.overrideWith((ref) => _flightOffer()),
          checkoutTravelersProvider.overrideWith(
            (ref) => const <TravelerForm>[],
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pumpPassengerDetails(tester, container: container);

      expect(find.text('Passenger details 1 · Adult'), findsOneWidget);
      expect(find.text('Passenger details 2'), findsNothing);
    });
  });

  group('B. Checkout traveller payload', () {
    testWidgets(
      'B1 the flight checkout sends the full collected traveller record',
      (tester) async {
        IdempotencyStore.clear();
        final _FakeBookingRepository repo = _FakeBookingRepository();
        final BagController bag = BagController();
        final _SucceededPaymentService paymentService =
            _SucceededPaymentService();
        final BookingController controller = BookingController(
          prepareUseCase: PrepareBookingUseCase(repo),
          revalidateUseCase: RevalidateBookingUseCase(repo),
          confirmUseCase: ConfirmBookingUseCase(repo),
          bagController: bag,
        );
        controller.state = BookingState(
          phase: BookingPhase.readyToConfirm,
          record: _record(),
          preparation: BookingPreparation(
            request: BookingRequest(
              offerId: 'offer-flight',
              providerId: 'duffel-flight',
              searchId: 'search-flight',
            ),
            revalidation: const PriceRevalidationResult(
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
              checkoutPaymentServiceProvider.overrideWithValue(paymentService),
              selectedOfferProvider.overrideWith((ref) => _flightOffer()),
              checkoutTravelersProvider.overrideWith(
                (ref) => <TravelerForm>[
                  const TravelerForm(
                    firstName: 'Nour',
                    lastName: 'Adel',
                    dob: '1990-01-01',
                    gender: 'M',
                    nationality: 'EG',
                    documentType: 'PASSPORT',
                    documentNumber: 'P123456',
                    documentIssueCountry: 'EG',
                    documentExpiry: '2030-01-01',
                  ),
                  const TravelerForm(
                    firstName: 'Mona',
                    lastName: 'Adel',
                    dob: '1992-05-05',
                    gender: 'F',
                    nationality: 'EG',
                    documentType: 'PASSPORT',
                    documentNumber: 'P654321',
                    documentIssueCountry: 'EG',
                    documentExpiry: '2031-01-01',
                  ),
                ],
              ),
              checkoutContactProvider.overrideWith(
                (ref) => const ContactForm(
                  email: 'nour@example.com',
                  phone: '+201000000000',
                ),
              ),
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

        await tester.enterText(
          find.byType(TextField).at(0),
          '4242424242424242',
        );
        await tester.enterText(find.byType(TextField).at(1), 'Nour Adel');
        await tester.enterText(find.byType(TextField).at(2), '12/30');
        await tester.enterText(find.byType(TextField).at(3), '123');
        await tester.tap(find.byType(AppButton));
        await tester.pumpAndSettle();

        expect(repo.travelersCalls, hasLength(1));
        expect(repo.travelersCalls.single, <Map<String, dynamic>>[
          <String, dynamic>{
            'firstName': 'Nour',
            'lastName': 'Adel',
            'dateOfBirth': '1990-01-01',
            'gender': 'M',
            'nationality': 'EG',
            'documentType': 'PASSPORT',
            'documentNumber': 'P123456',
            'documentIssueCountry': 'EG',
            'documentExpiry': '2030-01-01',
            'email': 'nour@example.com',
            'phone': '+201000000000',
            'passengerType': 'adult',
          },
          <String, dynamic>{
            'firstName': 'Mona',
            'lastName': 'Adel',
            'dateOfBirth': '1992-05-05',
            'gender': 'F',
            'nationality': 'EG',
            'documentType': 'PASSPORT',
            'documentNumber': 'P654321',
            'documentIssueCountry': 'EG',
            'documentExpiry': '2031-01-01',
            'passengerType': 'adult',
          },
        ]);
      },
    );

    testWidgets(
      'B2 hotel guest data never leaks into a flight checkout payload',
      (tester) async {
        IdempotencyStore.clear();
        final _FakeBookingRepository repo = _FakeBookingRepository();
        final BookingController controller = BookingController(
          prepareUseCase: PrepareBookingUseCase(repo),
          revalidateUseCase: RevalidateBookingUseCase(repo),
          confirmUseCase: ConfirmBookingUseCase(repo),
          bagController: BagController(),
        );
        controller.state = BookingState(
          phase: BookingPhase.readyToConfirm,
          record: _record(),
          preparation: BookingPreparation(
            request: BookingRequest(
              offerId: 'offer-flight',
              providerId: 'duffel-flight',
              searchId: 'search-flight',
            ),
            revalidation: const PriceRevalidationResult(
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
              checkoutPaymentServiceProvider.overrideWithValue(
                _SucceededPaymentService(),
              ),
              selectedOfferProvider.overrideWith((ref) => _flightOffer()),
              checkoutTravelersProvider.overrideWith(
                (ref) => const <TravelerForm>[
                  TravelerForm(firstName: 'Mona', lastName: 'Adel'),
                ],
              ),
              checkoutContactProvider.overrideWith(
                (ref) => const ContactForm(email: 'nour@example.com'),
              ),
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

        await tester.enterText(
          find.byType(TextField).at(0),
          '4242424242424242',
        );
        await tester.enterText(find.byType(TextField).at(1), 'Nour Adel');
        await tester.enterText(find.byType(TextField).at(2), '12/30');
        await tester.enterText(find.byType(TextField).at(3), '123');
        await tester.tap(find.byType(AppButton));
        await tester.pumpAndSettle();

        expect(repo.travelersCalls.single, hasLength(1));
        expect(
          (repo.travelersCalls.single.first as Map<String, dynamic>)['firstName'],
          'Mona',
        );
      },
    );
  });
}
