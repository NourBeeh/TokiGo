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

/// P3-D5 — the passenger form collects what the flight providers actually
/// require (title, per-passenger email/phone, infant→adult relationship) and
/// the checkout payload carries it without ever copying the lead contact.
///
/// Same seams as `flight_passenger_checkout_test.dart`.

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

const Composition _oneAdult = Composition(adults: 1);
const Composition _family = Composition(
  adults: 1,
  children: 1,
  infants: 1,
  childAges: <int>[7],
  infantAges: <int>[1],
);

/// The party the search ran for. Local alias so the overrides read clearly.
typedef Composition = FlightPassengerComposition;

BookingRecord _record({BookingStatus status = BookingStatus.pending}) =>
    BookingRecord(
      bookingId: 'bk-flight',
      userId: 'user-1',
      searchId: 'search-flight',
      offerId: 'offer-flight',
      providerId: 'duffel-flight',
      providerName: 'Duffel',
      type: 'flight',
      status: status,
      currency: 'USD',
      authoritativePrice: 800,
      priceBreakdown: PriceBreakdown.empty,
      travelers: const <Passenger>[],
      bookingReference: '',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

class _FakeBookingRepository implements BookingRepository {
  final List<List<dynamic>> travelersCalls = <List<dynamic>>[];

  @override
  Future<ApiResult<BookingRecord>> createBooking(
    String bookingId,
    String idempotencyKey,
    List<dynamic> travelers,
  ) async {
    travelersCalls.add(travelers);
    return ApiResult.success(_record(status: BookingStatus.confirmed));
  }

  @override
  Future<ApiResult<BookingRecord>> prepareBooking(
    String offerId,
    String providerId,
    String searchId,
  ) async => ApiResult.success(_record());

  @override
  Future<ApiResult<BookingRecord>> revalidateBooking(String bookingId) async =>
      ApiResult.success(_record());

  @override
  Future<ApiResult<BookingRecord>> getBooking(String bookingId) async =>
      ApiResult.success(_record());

  @override
  Future<ApiResult<void>> cancelBooking(String bookingId) async =>
      const ApiResult<void>.success(null);

  @override
  Future<ApiResult<BookingRecord>> getBookingStatus(String bookingId) async =>
      ApiResult.success(_record());
}

class _SucceededPaymentService implements CheckoutPaymentService {
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
  }) async => const CheckoutPaymentResult(outcome: PaymentOutcome.succeeded);
}

Future<GoRouter> _pumpPassengerDetails(
  WidgetTester tester, {
  required ProviderContainer container,
}) async {
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final GoRouter router = GoRouter(
    initialLocation: '/booking/review/passengers',
    routes: <RouteBase>[
      GoRoute(
        path: '/booking/review/passengers',
        builder: (BuildContext context, GoRouterState state) =>
            const PassengerDetailsPage(),
      ),
      GoRoute(
        path: '/booking/review/add-ons',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('ADDONS')),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
  return router;
}

/// Fills the fields of the card at [cardIndex] (0-based) and selects a title.
/// Fields are addressed by their stable keys, so adding a field to the card
/// cannot silently shift a test onto the wrong input.
Future<void> _fillCard(
  WidgetTester tester, {
  required int cardIndex,
  required String firstName,
  String title = 'Mr',
}) async {
  Future<void> enter(String field, String value) => tester.enterText(
        find.byKey(Key('traveler-$cardIndex-$field')),
        value,
      );

  await enter('firstName', firstName);
  await enter('lastName', 'Adel');
  await enter('dob', '1990-01-01');
  // Gender / nationality / document fields start EMPTY by design — the form
  // never invents them, so the test supplies them like a traveller would.
  await enter('gender', 'M');
  await enter('nationality', 'EG');
  await enter('email', '$firstName@example.com');
  await enter('phone', '201000000000');

  // Document type is a dropdown of the provider tokens the funnel collects.
  await tester.tap(find.byKey(Key('traveler-$cardIndex-documentType')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Passport').last);
  await tester.pumpAndSettle();
  await enter('documentNumber', 'P123456');
  await enter('documentIssueCountry', 'EG');
  await enter('documentExpiry', '2030-01-01');

  // Title dropdown for this card.
  await tester.tap(find.byKey(Key('traveler-$cardIndex-title')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title).last);
  await tester.pumpAndSettle();
}

/// Fills the shared contact block (email, calling code, phone).
Future<void> _fillContact(
  WidgetTester tester, {
  String email = 'lead@example.com',
  String countryCode = '20',
  String phone = '201000000001',
}) async {
  await tester.enterText(find.byKey(const Key('contact-email')), email);
  await tester.enterText(
    find.byKey(const Key('contact-phoneCountryCode')),
    countryCode,
  );
  await tester.enterText(find.byKey(const Key('contact-phone')), phone);
}

void main() {
  group('A. Party classification is preserved', () {
    testWidgets('A1 a 1+1+1 search seeds Adult, Child and Infant cards', (
      tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          flightPassengerCompositionProvider.overrideWith(
            (ref) => _family,
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
  });

  group('B. Required passenger fields', () {
    testWidgets('B1 the continue CTA stays blocked until every field is filled', (
      tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          flightPassengerCompositionProvider.overrideWith((ref) => _oneAdult),
          selectedOfferProvider.overrideWith((ref) => _flightOffer()),
          checkoutTravelersProvider.overrideWith(
            (ref) => const <TravelerForm>[],
          ),
        ],
      );
      addTearDown(container.dispose);
      final GoRouter router = await _pumpPassengerDetails(
        tester,
        container: container,
      );

      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('ADDONS'), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/booking/review/passengers',
      );
    });

    testWidgets('B2 a complete card unlocks the CTA and persists the values', (
      tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          flightPassengerCompositionProvider.overrideWith((ref) => _oneAdult),
          selectedOfferProvider.overrideWith((ref) => _flightOffer()),
          checkoutTravelersProvider.overrideWith(
            (ref) => const <TravelerForm>[],
          ),
          checkoutContactProvider.overrideWith(
            (ref) => const ContactForm(
              email: 'lead@example.com',
              phone: '201000000001',
              phoneCountryCode: '20',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await _pumpPassengerDetails(tester, container: container);

      await _fillCard(tester, cardIndex: 0, firstName: 'Nour');
      await _fillContact(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('ADDONS'), findsOneWidget);
      final List<TravelerForm> saved = container.read(
        checkoutTravelersProvider,
      );
      expect(saved, hasLength(1));
      expect(saved.single.title, 'mr');
      expect(saved.single.email, 'Nour@example.com');
      expect(saved.single.passengerType, 'adult');
      expect(saved.single.documentType, 'passport');
      expect(saved.single.documentNumber, 'P123456');
      expect(saved.single.documentIssueCountry, 'EG');
      expect(saved.single.documentExpiry, '2030-01-01');
      // The calling code is persisted with the contact, never assumed.
      expect(
        container.read(checkoutContactProvider).phoneCountryCode,
        '20',
      );
    });
  });

  group('C. Infant relationship', () {
    testWidgets('C1 an infant must name its accompanying adult', (
      tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          flightPassengerCompositionProvider.overrideWith((ref) => _family),
          selectedOfferProvider.overrideWith((ref) => _flightOffer()),
          checkoutTravelersProvider.overrideWith(
            (ref) => const <TravelerForm>[],
          ),
        ],
      );
      addTearDown(container.dispose);
      final GoRouter router = await _pumpPassengerDetails(
        tester,
        container: container,
      );

      // Fill the adult and the child, leave the infant's adult unselected.
      await _fillCard(tester, cardIndex: 0, firstName: 'Nour');
      await _fillCard(tester, cardIndex: 1, firstName: 'Youssef');
      await _fillCard(tester, cardIndex: 2, firstName: 'Salma');

      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('ADDONS'), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/booking/review/passengers',
      );
      expect(find.textContaining('adult this infant'), findsOneWidget);
    });
  });

  group('E. Identity documents (no placeholders)', () {
    testWidgets('E1 every document field starts EMPTY', (tester) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          flightPassengerCompositionProvider.overrideWith((ref) => _oneAdult),
          selectedOfferProvider.overrideWith((ref) => _flightOffer()),
          checkoutTravelersProvider.overrideWith(
            (ref) => const <TravelerForm>[],
          ),
        ],
      );
      addTearDown(container.dispose);
      await _pumpPassengerDetails(tester, container: container);

      // A silently-assigned 'PASSPORT'/'EG'/'2030-01-01' would be fabricated
      // data sent to the airline as if it were real.
      expect(find.widgetWithText(TextField, 'PASSPORT'), findsNothing);
      expect(find.widgetWithText(TextField, 'P123456'), findsNothing);
      final TextField number = tester.widget<TextField>(
        find.byKey(const Key('traveler-0-documentNumber')),
      );
      expect(number.controller?.text, '');
      final TextField country = tester.widget<TextField>(
        find.byKey(const Key('traveler-0-documentIssueCountry')),
      );
      expect(country.controller?.text, '');
      final TextField expiry = tester.widget<TextField>(
        find.byKey(const Key('traveler-0-documentExpiry')),
      );
      expect(expiry.controller?.text, '');
    });

    testWidgets('E2 a missing document field keeps the CTA blocked', (
      tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          flightPassengerCompositionProvider.overrideWith((ref) => _oneAdult),
          selectedOfferProvider.overrideWith((ref) => _flightOffer()),
          checkoutTravelersProvider.overrideWith(
            (ref) => const <TravelerForm>[],
          ),
          checkoutContactProvider.overrideWith(
            (ref) => const ContactForm(
              email: 'lead@example.com',
              phone: '201000000001',
              phoneCountryCode: '20',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final GoRouter router = await _pumpPassengerDetails(
        tester,
        container: container,
      );

      await _fillCard(tester, cardIndex: 0, firstName: 'Nour');
      await _fillContact(tester);
      // Clear one document field: the form must not invent it.
      await tester.enterText(
        find.byKey(const Key('traveler-0-documentExpiry')),
        '',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('ADDONS'), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/booking/review/passengers',
      );
    });
  });

  group('F. Phone calling code', () {
    testWidgets('F1 a missing calling code keeps the CTA blocked', (
      tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          flightPassengerCompositionProvider.overrideWith((ref) => _oneAdult),
          selectedOfferProvider.overrideWith((ref) => _flightOffer()),
          checkoutTravelersProvider.overrideWith(
            (ref) => const <TravelerForm>[],
          ),
        ],
      );
      addTearDown(container.dispose);
      final GoRouter router = await _pumpPassengerDetails(
        tester,
        container: container,
      );

      await _fillCard(tester, cardIndex: 0, firstName: 'Nour');
      await _fillContact(tester, countryCode: '');

      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('ADDONS'), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/booking/review/passengers',
      );
    });

    testWidgets('F2 a malformed calling code keeps the CTA blocked', (
      tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          flightPassengerCompositionProvider.overrideWith((ref) => _oneAdult),
          selectedOfferProvider.overrideWith((ref) => _flightOffer()),
          checkoutTravelersProvider.overrideWith(
            (ref) => const <TravelerForm>[],
          ),
        ],
      );
      addTearDown(container.dispose);
      final GoRouter router = await _pumpPassengerDetails(
        tester,
        container: container,
      );

      await _fillCard(tester, cardIndex: 0, firstName: 'Nour');
      await _fillContact(tester, countryCode: '+20');

      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('ADDONS'), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/booking/review/passengers',
      );
    });

    testWidgets('F3 the calling code reaches the lead traveller only', (
      tester,
    ) async {
      IdempotencyStore.clear();
      final _FakeBookingRepository repo = _FakeBookingRepository();
      final BagController bag = BagController();
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
            checkoutPaymentServiceProvider.overrideWithValue(
              _SucceededPaymentService(),
            ),
            selectedOfferProvider.overrideWith((ref) => _flightOffer()),
            checkoutTravelersProvider.overrideWith(
              (ref) => const <TravelerForm>[
                TravelerForm(
                  firstName: 'Nour',
                  lastName: 'Adel',
                  title: 'mr',
                  email: 'nour@example.com',
                  phone: '201000000000',
                  passengerType: 'adult',
                ),
                TravelerForm(
                  firstName: 'Mona',
                  lastName: 'Adel',
                  title: 'ms',
                  email: 'mona@example.com',
                  phone: '201000000001',
                  passengerType: 'adult',
                ),
              ],
            ),
            checkoutContactProvider.overrideWith(
              (ref) => const ContactForm(
                email: 'lead@example.com',
                phone: '201000000009',
                phoneCountryCode: '20',
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
      final List<dynamic> sent = repo.travelersCalls.single;
      expect((sent[0] as Map<String, dynamic>)['phoneCountryCode'], '20');
      expect((sent[1] as Map<String, dynamic>).containsKey('phoneCountryCode'), isFalse);
    });
  });

  group('D. Checkout payload', () {
    testWidgets(
      'D1 per-passenger contacts are never replaced by the lead contact',
      (tester) async {
        IdempotencyStore.clear();
        final _FakeBookingRepository repo = _FakeBookingRepository();
        final BagController bag = BagController();
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
              checkoutPaymentServiceProvider.overrideWithValue(
                _SucceededPaymentService(),
              ),
              selectedOfferProvider.overrideWith((ref) => _flightOffer()),
              checkoutTravelersProvider.overrideWith(
                (ref) => const <TravelerForm>[
                  TravelerForm(
                    firstName: 'Nour',
                    lastName: 'Adel',
                    title: 'mr',
                    email: 'nour@example.com',
                    phone: '201000000000',
                    passengerType: 'adult',
                  ),
                  TravelerForm(
                    firstName: 'Mona',
                    lastName: 'Adel',
                    title: 'ms',
                    email: 'mona@example.com',
                    phone: '201000000001',
                    passengerType: 'adult',
                  ),
                ],
              ),
              // A lead contact that must NOT be copied onto Mona.
              checkoutContactProvider.overrideWith(
                (ref) => const ContactForm(
                  email: 'lead@example.com',
                  phone: '201000000009',
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
        final List<dynamic> sent = repo.travelersCalls.single;
        expect(sent, hasLength(2));
        expect((sent[0] as Map<String, dynamic>)['email'], 'nour@example.com');
        expect((sent[1] as Map<String, dynamic>)['email'], 'mona@example.com');
        expect((sent[1] as Map<String, dynamic>)['phone'], '201000000001');
        expect(
          (sent[1] as Map<String, dynamic>)['passengerType'],
          'adult',
        );
      },
    );
  });
}
