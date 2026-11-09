import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/booking/booking.dart';
import 'package:tokigo/core/domain/models/search/hotel_room_occupancy.dart';
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
import 'package:tokigo/features/booking/domain/booking_error.dart';
import 'package:tokigo/features/booking/domain/booking_preparation.dart';
import 'package:tokigo/features/booking/domain/booking_record.dart';
import 'package:tokigo/features/booking/presentation/pages/checkout_page.dart';
import 'package:tokigo/features/booking/presentation/pages/hotel_guest_details_page.dart';
import 'package:tokigo/features/search/application/controllers/hotel_search_controller.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// P2 — regression tests for the hotel guest booking flow.
///
/// The flow under test is the real one:
/// `hotelOccupanciesProvider` → `HotelGuestDetailsPage` (fields + validation)
/// → `hotelGuestTravelersProvider` → `CheckoutPage` → `BookingController.confirm`.
///
/// The only seams are deterministic fakes at the repository / payment-service
/// boundaries, mirroring the conventions in `booking_safety_test.dart`.

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

HotelRoomOccupancy _room({
  int adults = 1,
  List<int> childAges = const <int>[],
}) => HotelRoomOccupancy(adults: adults, childAges: childAges);

const List<HotelRoomOccupancy> _twoAdults = <HotelRoomOccupancy>[
  HotelRoomOccupancy(adults: 2),
];

const List<HotelRoomOccupancy> _oneAdult = <HotelRoomOccupancy>[
  HotelRoomOccupancy(adults: 1),
];

const List<HotelRoomOccupancy> _oneAdultOneChild = <HotelRoomOccupancy>[
  HotelRoomOccupancy(adults: 1, childAges: <int>[7]),
];

const List<HotelRoomOccupancy> _twoAdultsOneChild = <HotelRoomOccupancy>[
  HotelRoomOccupancy(adults: 2, childAges: <int>[7]),
];

GoRouter _guestRouter() => GoRouter(
  initialLocation: '/booking/hotel-guests',
  routes: <RouteBase>[
    GoRoute(
      path: '/booking/hotel-guests',
      builder: (BuildContext context, GoRouterState state) =>
          const HotelGuestDetailsPage(),
    ),
    GoRoute(
      path: '/booking/review',
      builder: (BuildContext context, GoRouterState state) =>
          const Scaffold(body: Text('REVIEW')),
    ),
  ],
);

/// Pumps the real guest page. When [container] is omitted a fresh one is
/// created with the occupancy override; passing one keeps the same provider
/// state across two pages (the stale-data scenario).
Future<ProviderContainer> _pumpGuestPage(
  WidgetTester tester, {
  required GoRouter router,
  ProviderContainer? container,
  List<HotelRoomOccupancy> occupancies = const <HotelRoomOccupancy>[],
}) async {
  final bool owned = container == null;
  final ProviderContainer resolved = container ??
      ProviderContainer(
        overrides: <Override>[
          hotelOccupanciesProvider.overrideWith((ref) => occupancies),
        ],
      );
  if (owned) addTearDown(resolved.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: resolved,
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
  return resolved;
}

List<String> _fieldLabels(WidgetTester tester) {
  return <String>[
    for (final TextField field
        in tester.widgetList<TextField>(find.byType(TextField)))
      field.decoration?.labelText ?? '',
  ];
}

Future<void> _fillField(WidgetTester tester, int index, String text) async {
  await tester.enterText(find.byType(TextField).at(index), text);
}

Future<void> _tapContinue(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Continue'));
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Checkout fakes
// ---------------------------------------------------------------------------

BookingRecord _bookingRecord({
  String bookingId = 'bk-hotel',
  String offerId = 'offer-hotel',
  String providerId = 'nuitee',
  String searchId = 'search-hotel',
  double price = 500,
  BookingStatus status = BookingStatus.pending,
  String type = 'hotel',
}) {
  return BookingRecord(
    bookingId: bookingId,
    userId: 'user-1',
    searchId: searchId,
    offerId: offerId,
    providerId: providerId,
    providerName: 'Nuitee Connect',
    type: type,
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
      _bookingRecord(bookingId: bookingId, status: BookingStatus.confirmed),
    );
  }

  @override
  Future<ApiResult<BookingRecord>> prepareBooking(
    String offerId,
    String providerId,
    String searchId,
  ) async => ApiResult.success(
    _bookingRecord(
      offerId: offerId,
      providerId: providerId,
      searchId: searchId,
    ),
  );

  @override
  Future<ApiResult<BookingRecord>> revalidateBooking(String bookingId) async =>
      ApiResult.success(_bookingRecord(bookingId: bookingId));

  @override
  Future<ApiResult<BookingRecord>> getBooking(String bookingId) async =>
      ApiResult.success(_bookingRecord(bookingId: bookingId));

  @override
  Future<ApiResult<void>> cancelBooking(String bookingId) async =>
      const ApiResult<void>.success(null);

  @override
  Future<ApiResult<BookingRecord>> getBookingStatus(String bookingId) async =>
      ApiResult.success(_bookingRecord(bookingId: bookingId));
}

/// Always succeeds, so the real `CheckoutPage._pay` continues into the real
/// `BookingController.confirm` path with the travelers it read from the
/// providers.
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

SelectedOffer _hotelOffer() => const SelectedOffer(
  offerId: 'offer-hotel',
  providerId: 'nuitee',
  providerName: 'Nuitee Connect',
  price: 500,
  currency: 'USD',
  searchId: 'search-hotel',
  offerType: 'hotel',
  title: 'Nile Hotel',
  subtitle: 'Cairo, Egypt',
);

SelectedOffer _flightOffer() => const SelectedOffer(
  offerId: 'offer-flight',
  providerId: 'duffel',
  providerName: 'Duffel',
  price: 800,
  currency: 'USD',
  searchId: 'search-flight',
  offerType: 'flight',
  title: 'CAI → DXB',
  subtitle: 'Cairo to Dubai',
);

SelectedOffer _otherHotelOffer() => const SelectedOffer(
  offerId: 'offer-hotel-2',
  providerId: 'nuitee',
  providerName: 'Nuitee Connect',
  price: 700,
  currency: 'USD',
  searchId: 'search-hotel-2',
  offerType: 'hotel',
  title: 'Pyramids Hotel',
  subtitle: 'Giza, Egypt',
);

class _CheckoutHarness {
  _CheckoutHarness({
    required this.repo,
    required this.bag,
    required this.controller,
    required this.router,
    required this.paymentService,
  });

  final _FakeBookingRepository repo;
  final BagController bag;
  final BookingController controller;
  final GoRouter router;
  final _SucceededPaymentService paymentService;

  /// Pumps the real `CheckoutPage` with a prepared booking, a succeeding
  /// payment service and the real `BookingController` over a fake repository.
  static Future<_CheckoutHarness> pump(
    WidgetTester tester, {
    required List<Map<String, dynamic>> hotelGuests,
    required SelectedOffer selectedOffer,
    List<TravelerForm> flightTravelers = const <TravelerForm>[],
    String ownerKey = '',
    List<HotelRoomOccupancy> occupancies = const <HotelRoomOccupancy>[],
    String offerId = 'offer-hotel',
    String providerId = 'nuitee',
    String searchId = 'search-hotel',
  }) async {
    IdempotencyStore.clear();
    final repo = _FakeBookingRepository();
    final bag = BagController();
    final paymentService = _SucceededPaymentService();
    final controller = BookingController(
      prepareUseCase: PrepareBookingUseCase(repo),
      revalidateUseCase: RevalidateBookingUseCase(repo),
      confirmUseCase: ConfirmBookingUseCase(repo),
      bagController: bag,
    );
    final router = GoRouter(
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
    controller.state = BookingState(
      phase: BookingPhase.readyToConfirm,
      record: _bookingRecord(
        offerId: offerId,
        providerId: providerId,
        searchId: searchId,
      ),
      preparation: BookingPreparation(
        request: BookingRequest(
          offerId: offerId,
          providerId: providerId,
          searchId: searchId,
        ),
        revalidation: const PriceRevalidationResult(
          authoritativePrice: 500,
          currency: 'USD',
          priceChanged: false,
          available: true,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          bookingControllerProvider.overrideWith((ref) => controller),
          checkoutPaymentServiceProvider.overrideWithValue(paymentService),
          selectedOfferProvider.overrideWith((ref) => selectedOffer),
          hotelGuestTravelersProvider.overrideWith((ref) => hotelGuests),
          hotelGuestTravelersOwnerProvider.overrideWith((ref) => ownerKey),
          hotelOccupanciesProvider.overrideWith((ref) => occupancies),
          checkoutTravelersProvider.overrideWith((ref) => flightTravelers),
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
          supportedLocales: AppLocalizations.supportedLocales,
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
    return _CheckoutHarness(
      repo: repo,
      bag: bag,
      controller: controller,
      router: router,
      paymentService: paymentService,
    );
  }

  /// Fills the card fields and taps Pay.
  Future<void> pay(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), '4242424242424242');
    await tester.enterText(find.byType(TextField).at(1), 'Nour Adel');
    await tester.enterText(find.byType(TextField).at(2), '12/30');
    await tester.enterText(find.byType(TextField).at(3), '123');
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  test('hotel guest travelers provider defaults empty', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(hotelGuestTravelersProvider), isEmpty);
  });

  test('hotel occupancies provider defaults empty', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(hotelOccupanciesProvider), isEmpty);
  });

  test('hotel guest travelers owner provider defaults empty', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(hotelGuestTravelersOwnerProvider), isEmpty);
  });

  group('A. Guest field generation', () {
    testWidgets('A1 one adult produces exactly one adult field', (tester) async {
      final GoRouter router = _guestRouter();
      await _pumpGuestPage(
        tester,
        router: router,
        occupancies: <HotelRoomOccupancy>[_room(adults: 1)],
      );

      expect(_fieldLabels(tester), <String>['Adult 1 name']);
      expect(find.text('Room 1: 1 adults, 0 children'), findsOneWidget);
    });

    testWidgets('A2 multiple adults produce one field per adult', (tester) async {
      final GoRouter router = _guestRouter();
      await _pumpGuestPage(
        tester,
        router: router,
        occupancies: <HotelRoomOccupancy>[_room(adults: 3)],
      );

      expect(_fieldLabels(tester), <String>[
        'Adult 1 name',
        'Adult 2 name',
        'Adult 3 name',
      ]);
    });

    testWidgets('A3 children produce one child field per known age', (
      tester,
    ) async {
      final GoRouter router = _guestRouter();
      await _pumpGuestPage(
        tester,
        router: router,
        occupancies: <HotelRoomOccupancy>[
          _room(adults: 2, childAges: <int>[5, 8]),
        ],
      );

      expect(_fieldLabels(tester), <String>[
        'Adult 1 name',
        'Adult 2 name',
        'Child 1 (age 5) name',
        'Child 2 (age 8) name',
      ]);
      expect(find.text('Room 1: 2 adults, 2 children'), findsOneWidget);
    });

    testWidgets('A4 multiple rooms keep every room guest in order', (
      tester,
    ) async {
      final GoRouter router = _guestRouter();
      await _pumpGuestPage(
        tester,
        router: router,
        occupancies: <HotelRoomOccupancy>[
          _room(adults: 2),
          _room(adults: 1, childAges: <int>[4]),
        ],
      );

      expect(_fieldLabels(tester), <String>[
        'Adult 1 name',
        'Adult 2 name',
        'Adult 1 name',
        'Child 1 (age 4) name',
      ]);
      expect(find.text('Room 1: 2 adults, 0 children'), findsOneWidget);
      expect(find.text('Room 2: 1 adults, 1 children'), findsOneWidget);
    });

    testWidgets('A5 an empty occupancy shows an explicit error state', (
      tester,
    ) async {
      final GoRouter router = _guestRouter();
      final container = await _pumpGuestPage(
        tester,
        router: router,
        occupancies: <HotelRoomOccupancy>[],
      );

      // The page is reachable without a search context: it must say so
      // instead of showing a blank form with a dead Continue button.
      expect(find.text('No rooms selected'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Go back'), findsOneWidget);
      // No silent submission happened.
      expect(container.read(hotelGuestTravelersProvider), isEmpty);
      expect(container.read(hotelGuestTravelersOwnerProvider), isEmpty);
    });

    testWidgets('A5b the empty-occupancy state can go back', (tester) async {
      final GoRouter router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('HOME')),
          ),
          GoRoute(
            path: '/booking/hotel-guests',
            builder: (BuildContext context, GoRouterState state) =>
                const HotelGuestDetailsPage(),
          ),
        ],
      );
      final container = await _pumpGuestPage(
        tester,
        router: router,
        occupancies: <HotelRoomOccupancy>[],
      );
      router.push('/booking/hotel-guests');
      await tester.pumpAndSettle();

      expect(find.text('No rooms selected'), findsOneWidget);
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, '/');
      expect(find.text('HOME'), findsOneWidget);
      expect(container.read(hotelGuestTravelersProvider), isEmpty);
    });
  });

  group('F. Stale guest data ownership', () {
    testWidgets('F1 matching ownership sends the collected hotel guests', (
      tester,
    ) async {
      final harness = await _CheckoutHarness.pump(
        tester,
        hotelGuests: <Map<String, dynamic>>[
          <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
          <String, dynamic>{'firstName': 'Mona', 'lastName': 'Adel', 'adult': true},
        ],
        selectedOffer: _hotelOffer(),
        occupancies: _twoAdults,
        ownerKey: hotelGuestOwnershipKey(_hotelOffer(), _twoAdults),
      );

      await harness.pay(tester);

      expect(
        harness.repo.travelersCalls.single.map(
          (dynamic t) => (t as Map<String, dynamic>)['firstName'],
        ),
        <dynamic>['Nour', 'Mona'],
      );
    });

    testWidgets('F2 a different selected offer cannot reuse old guests', (
      tester,
    ) async {
      final harness = await _CheckoutHarness.pump(
        tester,
        hotelGuests: <Map<String, dynamic>>[
          <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
        ],
        selectedOffer: _otherHotelOffer(),
        occupancies: _twoAdults,
        ownerKey: hotelGuestOwnershipKey(_hotelOffer(), _twoAdults),
        offerId: 'offer-hotel-2',
        providerId: 'nuitee',
        searchId: 'search-hotel-2',
      );

      await harness.pay(tester);

      // Blocked before any charge or confirmation.
      expect(harness.paymentService.calls, 0);
      expect(harness.repo.travelersCalls, isEmpty);
    });

    testWidgets(
      'F3 direct checkout with a stale owner key ignores the hotel guests',
      (tester) async {
        final harness = await _CheckoutHarness.pump(
          tester,
          hotelGuests: <Map<String, dynamic>>[
            <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
          ],
          selectedOffer: _hotelOffer(),
          occupancies: _twoAdults,
          ownerKey: '', // no ownership recorded for this payload
        );

        await harness.pay(tester);

        // Blocked before any charge or confirmation.
        expect(harness.paymentService.calls, 0);
        expect(harness.repo.travelersCalls, isEmpty);
      },
    );

    testWidgets('F4 switching to a flight offer does not leak hotel travelers', (
      tester,
    ) async {
      final harness = await _CheckoutHarness.pump(
        tester,
        hotelGuests: <Map<String, dynamic>>[
          <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
        ],
        selectedOffer: _flightOffer(),
        flightTravelers: <TravelerForm>[
          const TravelerForm(firstName: 'Mona', lastName: 'Adel'),
        ],
        occupancies: _twoAdults,
        ownerKey: hotelGuestOwnershipKey(_hotelOffer(), _twoAdults),
        offerId: 'offer-flight',
        providerId: 'duffel',
        searchId: 'search-flight',
      );

      await harness.pay(tester);

      expect(
        harness.repo.travelersCalls.single.map(
          (dynamic t) => (t as Map<String, dynamic>)['firstName'],
        ),
        <dynamic>['Mona'],
      );
    });

    testWidgets(
      'F5 the guest page records ownership for its offer and occupancy',
      (tester) async {
        final container = ProviderContainer(
          overrides: <Override>[
            hotelOccupanciesProvider.overrideWith((ref) => _twoAdults),
            selectedOfferProvider.overrideWith((ref) => _hotelOffer()),
          ],
        );
        addTearDown(container.dispose);

        final GoRouter router = _guestRouter();
        await _pumpGuestPage(tester, router: router, container: container);
        await _fillField(tester, 0, 'Nour Adel');
        await _fillField(tester, 1, 'Mona Adel');
        await _tapContinue(tester);

        expect(
          container.read(hotelGuestTravelersOwnerProvider),
          hotelGuestOwnershipKey(_hotelOffer(), _twoAdults),
        );
        expect(container.read(hotelGuestTravelersProvider), hasLength(2));
      },
    );
  });

  group('G. Hotel confirmation gate', () {
    testWidgets('G1 matching owner and valid guests confirms the booking', (
      tester,
    ) async {
      final harness = await _CheckoutHarness.pump(
        tester,
        hotelGuests: <Map<String, dynamic>>[
          <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
          <String, dynamic>{'firstName': 'Mona', 'lastName': 'Adel', 'adult': true},
        ],
        selectedOffer: _hotelOffer(),
        occupancies: _twoAdults,
        ownerKey: hotelGuestOwnershipKey(_hotelOffer(), _twoAdults),
      );

      await harness.pay(tester);

      expect(harness.paymentService.calls, 1);
      expect(harness.repo.travelersCalls, hasLength(1));
      expect(
        harness.router.state.matchedLocation,
        '/booking/review/confirmation',
      );
    });

    testWidgets('G2 an empty owner blocks hotel confirmation', (tester) async {
      final harness = await _CheckoutHarness.pump(
        tester,
        hotelGuests: <Map<String, dynamic>>[
          <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
        ],
        selectedOffer: _hotelOffer(),
        occupancies: _oneAdult,
        ownerKey: '',
      );

      await harness.pay(tester);

      expect(
        find.text(
          "The guest details don't match this hotel booking. Go back and re-enter the guests for this stay.",
        ),
        findsOneWidget,
      );
      expect(harness.paymentService.calls, 0);
      expect(harness.repo.travelersCalls, isEmpty);
      expect(
        harness.router.state.matchedLocation,
        '/booking/review/checkout',
      );
    });

    testWidgets('G3 a mismatched owner blocks hotel confirmation', (
      tester,
    ) async {
      final harness = await _CheckoutHarness.pump(
        tester,
        hotelGuests: <Map<String, dynamic>>[
          <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
        ],
        selectedOffer: _otherHotelOffer(),
        occupancies: _oneAdult,
        ownerKey: hotelGuestOwnershipKey(_hotelOffer(), _oneAdult),
        offerId: 'offer-hotel-2',
        providerId: 'nuitee',
        searchId: 'search-hotel-2',
      );

      await harness.pay(tester);

      expect(harness.paymentService.calls, 0);
      expect(harness.repo.travelersCalls, isEmpty);
    });

    testWidgets('G4 an empty guest list blocks hotel confirmation', (
      tester,
    ) async {
      final harness = await _CheckoutHarness.pump(
        tester,
        hotelGuests: const <Map<String, dynamic>>[],
        selectedOffer: _hotelOffer(),
        occupancies: _oneAdult,
        ownerKey: hotelGuestOwnershipKey(_hotelOffer(), _oneAdult),
      );

      await harness.pay(tester);

      expect(harness.paymentService.calls, 0);
      expect(harness.repo.travelersCalls, isEmpty);
    });

    testWidgets('G5 a missing guest name blocks hotel confirmation', (
      tester,
    ) async {
      final harness = await _CheckoutHarness.pump(
        tester,
        hotelGuests: <Map<String, dynamic>>[
          <String, dynamic>{'firstName': '', 'lastName': 'Adel', 'adult': true},
        ],
        selectedOffer: _hotelOffer(),
        occupancies: _oneAdult,
        ownerKey: hotelGuestOwnershipKey(_hotelOffer(), _oneAdult),
      );

      await harness.pay(tester);

      expect(harness.paymentService.calls, 0);
      expect(harness.repo.travelersCalls, isEmpty);
    });

    testWidgets('G6 an adult/child count mismatch blocks confirmation', (
      tester,
    ) async {
      final harness = await _CheckoutHarness.pump(
        tester,
        hotelGuests: <Map<String, dynamic>>[
          <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
          <String, dynamic>{'firstName': 'Mona', 'lastName': 'Adel', 'adult': true},
        ],
        selectedOffer: _hotelOffer(),
        occupancies: _twoAdultsOneChild,
        ownerKey: hotelGuestOwnershipKey(_hotelOffer(), _twoAdultsOneChild),
      );

      await harness.pay(tester);

      expect(harness.paymentService.calls, 0);
      expect(harness.repo.travelersCalls, isEmpty);
    });

    testWidgets('G7 a child counted as an adult blocks confirmation', (
      tester,
    ) async {
      final harness = await _CheckoutHarness.pump(
        tester,
        hotelGuests: <Map<String, dynamic>>[
          <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
          <String, dynamic>{'firstName': 'Youssef', 'lastName': 'Adel', 'adult': true},
        ],
        selectedOffer: _hotelOffer(),
        occupancies: _oneAdultOneChild,
        ownerKey: hotelGuestOwnershipKey(_hotelOffer(), _oneAdultOneChild),
      );

      await harness.pay(tester);

      expect(harness.paymentService.calls, 0);
      expect(harness.repo.travelersCalls, isEmpty);
    });
  });

  group('H. Booking controller hotel guard', () {
    BookingController controllerWith(_FakeBookingRepository repo) =>
        BookingController(
          prepareUseCase: PrepareBookingUseCase(repo),
          revalidateUseCase: RevalidateBookingUseCase(repo),
          confirmUseCase: ConfirmBookingUseCase(repo),
          bagController: BagController(),
        );

    BookingState readyState(BookingRecord record) => BookingState(
      phase: BookingPhase.readyToConfirm,
      record: record,
      preparation: BookingPreparation(
        request: BookingRequest(
          offerId: record.offerId,
          providerId: record.providerId,
          searchId: record.searchId ?? '',
        ),
        revalidation: const PriceRevalidationResult(
          authoritativePrice: 500,
          currency: 'USD',
          priceChanged: false,
          available: true,
        ),
      ),
    );

    test('H1 hotel confirm with no travelers is blocked', () async {
      final repo = _FakeBookingRepository();
      final controller = controllerWith(repo);
      addTearDown(controller.dispose);
      IdempotencyStore.clear();
      controller.state = readyState(_bookingRecord());

      await controller.confirm(travelers: const <dynamic>[]);

      expect(repo.travelersCalls, isEmpty);
      expect(controller.state.phase, BookingPhase.error);
      expect(controller.state.errorCode, BookingErrorCode.validationFailed);
    });

    test('H2 hotel confirm with a malformed traveler is blocked', () async {
      final repo = _FakeBookingRepository();
      final controller = controllerWith(repo);
      addTearDown(controller.dispose);
      IdempotencyStore.clear();
      controller.state = readyState(_bookingRecord());

      await controller.confirm(
        travelers: <dynamic>[
          <String, dynamic>{
            'firstName': '',
            'lastName': 'Adel',
            'adult': true,
          },
        ],
      );

      expect(repo.travelersCalls, isEmpty);
      expect(controller.state.phase, BookingPhase.error);
    });

    test('H3 hotel confirm with valid guests still succeeds', () async {
      final repo = _FakeBookingRepository();
      final controller = controllerWith(repo);
      addTearDown(controller.dispose);
      IdempotencyStore.clear();
      controller.state = readyState(_bookingRecord());

      await controller.confirm(
        travelers: <dynamic>[
          <String, dynamic>{
            'firstName': 'Nour',
            'lastName': 'Adel',
            'adult': true,
          },
        ],
      );

      expect(repo.travelersCalls, hasLength(1));
      expect(controller.state.phase, BookingPhase.confirmed);
    });

    test('H4 flight confirm with no travelers keeps the sandbox default', () async {
      final repo = _FakeBookingRepository();
      final controller = controllerWith(repo);
      addTearDown(controller.dispose);
      IdempotencyStore.clear();
      controller.state = readyState(_bookingRecord(type: 'flight'));

      await controller.confirm(travelers: const <dynamic>[]);

      expect(repo.travelersCalls, hasLength(1));
      final List<dynamic> sent = repo.travelersCalls.single;
      expect(sent, isNotEmpty);
      expect((sent.first as Map<String, dynamic>)['firstName'], 'Test');
      expect(controller.state.phase, BookingPhase.confirmed);
    });
  });

  group('B. Validation', () {
    testWidgets('B1 empty required names are rejected and do not navigate', (
      tester,
    ) async {
      final GoRouter router = _guestRouter();
      await _pumpGuestPage(
        tester,
        router: router,
        occupancies: <HotelRoomOccupancy>[_room(adults: 1)],
      );

      await _tapContinue(tester);

      expect(find.text('Required'), findsOneWidget);
      expect(router.state.matchedLocation, '/booking/hotel-guests');
    });

    testWidgets('B2 a partially filled party is rejected', (tester) async {
      final GoRouter router = _guestRouter();
      await _pumpGuestPage(
        tester,
        router: router,
        occupancies: <HotelRoomOccupancy>[_room(adults: 2)],
      );

      await _fillField(tester, 0, 'Nour Adel');
      await _tapContinue(tester);

      expect(find.text('Required'), findsOneWidget);
      expect(router.state.matchedLocation, '/booking/hotel-guests');
    });

    testWidgets('B3 valid names navigate to the booking review route', (
      tester,
    ) async {
      final GoRouter router = _guestRouter();
      await _pumpGuestPage(
        tester,
        router: router,
        occupancies: <HotelRoomOccupancy>[_room(adults: 2)],
      );

      await _fillField(tester, 0, 'Nour Adel');
      await _fillField(tester, 1, 'Mona Adel');
      await _tapContinue(tester);

      expect(find.text('Required'), findsNothing);
      expect(router.state.matchedLocation, '/booking/review');
      expect(find.text('REVIEW'), findsOneWidget);
    });
  });

  group('C. Traveler mapping', () {
    testWidgets('C1 a single adult maps to one adult traveler', (tester) async {
      final GoRouter router = _guestRouter();
      final container = await _pumpGuestPage(
        tester,
        router: router,
        occupancies: <HotelRoomOccupancy>[_room(adults: 1)],
      );

      await _fillField(tester, 0, 'Nour Adel');
      await _tapContinue(tester);

      expect(container.read(hotelGuestTravelersProvider), <Map<String, dynamic>>[
        <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
      ]);
    });

    testWidgets('C2 adults and children keep their classification and order', (
      tester,
    ) async {
      final GoRouter router = _guestRouter();
      final container = await _pumpGuestPage(
        tester,
        router: router,
        occupancies: <HotelRoomOccupancy>[
          _room(adults: 2, childAges: <int>[7]),
        ],
      );

      await _fillField(tester, 0, 'Nour Adel');
      await _fillField(tester, 1, 'Mona Adel');
      await _fillField(tester, 2, 'Youssef Adel');
      await _tapContinue(tester);

      final travelers = container.read(hotelGuestTravelersProvider);
      expect(travelers, hasLength(3));
      expect(
        travelers.map((Map<String, dynamic> t) => t['adult']),
        <dynamic>[true, true, false],
      );
      expect(
        travelers.map((Map<String, dynamic> t) => t['firstName']),
        <dynamic>['Nour', 'Mona', 'Youssef'],
      );
    });

    testWidgets('C3 multiple rooms map room by room without leftovers', (
      tester,
    ) async {
      final GoRouter router = _guestRouter();
      final container = await _pumpGuestPage(
        tester,
        router: router,
        occupancies: <HotelRoomOccupancy>[
          _room(adults: 2),
          _room(adults: 1, childAges: <int>[4]),
        ],
      );

      await _fillField(tester, 0, 'Nour Adel');
      await _fillField(tester, 1, 'Mona Adel');
      await _fillField(tester, 2, 'Hassan Adel');
      await _fillField(tester, 3, 'Youssef Adel');
      await _tapContinue(tester);

      expect(
        container.read(hotelGuestTravelersProvider),
        <Map<String, dynamic>>[
          <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
          <String, dynamic>{'firstName': 'Mona', 'lastName': 'Adel', 'adult': true},
          <String, dynamic>{'firstName': 'Hassan', 'lastName': 'Adel', 'adult': true},
          <String, dynamic>{'firstName': 'Youssef', 'lastName': 'Adel', 'adult': false},
        ],
      );
    });

    testWidgets('C4 a multi-word name splits first name and last name', (
      tester,
    ) async {
      final GoRouter router = _guestRouter();
      final container = await _pumpGuestPage(
        tester,
        router: router,
        occupancies: <HotelRoomOccupancy>[_room(adults: 1)],
      );

      await _fillField(tester, 0, 'Nour Mohamed Adel');
      await _tapContinue(tester);

      expect(container.read(hotelGuestTravelersProvider), <Map<String, dynamic>>[
        <String, dynamic>{
          'firstName': 'Nour',
          'lastName': 'Mohamed Adel',
          'adult': true,
        },
      ]);
    });

    testWidgets('C5 surrounding and repeated whitespace is trimmed', (
      tester,
    ) async {
      final GoRouter router = _guestRouter();
      final container = await _pumpGuestPage(
        tester,
        router: router,
        occupancies: <HotelRoomOccupancy>[_room(adults: 1)],
      );

      await _fillField(tester, 0, '  Nour   Adel  ');
      await _tapContinue(tester);

      expect(container.read(hotelGuestTravelersProvider), <Map<String, dynamic>>[
        <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
      ]);
    });
  });

  group('D. Checkout integration', () {
    testWidgets(
      'D1 hotel guests reach the booking confirmation path with the contact email',
      (tester) async {
        final harness = await _CheckoutHarness.pump(
          tester,
          hotelGuests: <Map<String, dynamic>>[
            <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
            <String, dynamic>{'firstName': 'Mona', 'lastName': 'Adel', 'adult': true},
            <String, dynamic>{'firstName': 'Youssef', 'lastName': 'Adel', 'adult': false},
          ],
          selectedOffer: _hotelOffer(),
          occupancies: _twoAdultsOneChild,
          ownerKey: hotelGuestOwnershipKey(_hotelOffer(), _twoAdultsOneChild),
        );

        await harness.pay(tester);

        expect(harness.repo.travelersCalls, hasLength(1));
        expect(harness.repo.travelersCalls.single, <Map<String, dynamic>>[
          <String, dynamic>{
            'firstName': 'Nour',
            'lastName': 'Adel',
            'adult': true,
            'email': 'nour@example.com',
          },
          <String, dynamic>{'firstName': 'Mona', 'lastName': 'Adel', 'adult': true},
          <String, dynamic>{'firstName': 'Youssef', 'lastName': 'Adel', 'adult': false},
        ]);
        expect(
          harness.router.state.matchedLocation,
          '/booking/review/confirmation',
        );
      },
    );

    testWidgets('D2 the selected hotel offer is preserved for the trip', (
      tester,
    ) async {
      final harness = await _CheckoutHarness.pump(
        tester,
        hotelGuests: <Map<String, dynamic>>[
          <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
        ],
        selectedOffer: _hotelOffer(),
        occupancies: _oneAdult,
        ownerKey: hotelGuestOwnershipKey(_hotelOffer(), _oneAdult),
      );

      await harness.pay(tester);

      expect(harness.bag.state.currentTrips, hasLength(1));
      expect(harness.bag.state.currentTrips.single.title, 'Nile Hotel');
      expect(harness.bag.state.currentTrips.single.destination, 'Cairo, Egypt');
    });

    testWidgets('D3 hotel guests win over unrelated flight traveler data', (
      tester,
    ) async {
      final harness = await _CheckoutHarness.pump(
        tester,
        hotelGuests: <Map<String, dynamic>>[
          <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
          <String, dynamic>{'firstName': 'Mona', 'lastName': 'Adel', 'adult': true},
        ],
        selectedOffer: _hotelOffer(),
        occupancies: _twoAdults,
        ownerKey: hotelGuestOwnershipKey(_hotelOffer(), _twoAdults),
        flightTravelers: <TravelerForm>[
          const TravelerForm(
            firstName: 'Stale',
            lastName: 'Flight',
            dob: '1990-01-01',
          ),
        ],
      );

      await harness.pay(tester);

      expect(
        harness.repo.travelersCalls.single.map(
          (dynamic t) => (t as Map<String, dynamic>)['firstName'],
        ),
        <dynamic>['Nour', 'Mona'],
      );
    });

    testWidgets('D4 a non-hotel offer uses the flight travelers', (tester) async {
      final harness = await _CheckoutHarness.pump(
        tester,
        hotelGuests: <Map<String, dynamic>>[
          <String, dynamic>{'firstName': 'Nour', 'lastName': 'Adel', 'adult': true},
        ],
        selectedOffer: _flightOffer(),
        flightTravelers: <TravelerForm>[
          const TravelerForm(
            firstName: 'Stale',
            lastName: 'Flight',
            dob: '1990-01-01',
          ),
        ],
        offerId: 'offer-flight',
        providerId: 'duffel',
        searchId: 'search-flight',
      );

      await harness.pay(tester);

      expect(harness.repo.travelersCalls.single, <Map<String, dynamic>>[
        <String, dynamic>{
          'firstName': 'Stale',
          'lastName': 'Flight',
          'dateOfBirth': '1990-01-01',
          'email': 'nour@example.com',
          'phone': '+201000000000',
          'passengerType': 'adult',
        },
      ]);
    });
  });

  group('E. Stale-data isolation', () {
    testWidgets(
      'E1 a new occupancy regenerates the fields and overwrites old guests',
      (tester) async {
        final container = ProviderContainer(
          overrides: <Override>[
            hotelOccupanciesProvider.overrideWith(
              (ref) => <HotelRoomOccupancy>[_room(adults: 1)],
            ),
          ],
        );
        addTearDown(container.dispose);

        // First search: one adult.
        final GoRouter firstRouter = _guestRouter();
        await _pumpGuestPage(tester, router: firstRouter, container: container);
        await _fillField(tester, 0, 'Nour Adel');
        await _tapContinue(tester);
        expect(container.read(hotelGuestTravelersProvider), hasLength(1));

        // A different search changes the occupancy; a fresh guest page is
        // pushed for it.
        container.read(hotelOccupanciesProvider.notifier).state =
            <HotelRoomOccupancy>[_room(adults: 2)];
        final GoRouter secondRouter = _guestRouter();
        await _pumpGuestPage(tester, router: secondRouter, container: container);

        // The new guest collection reflects the new occupancy.
        expect(_fieldLabels(tester), <String>['Adult 1 name', 'Adult 2 name']);

        await _fillField(tester, 0, 'Mona Adel');
        await _fillField(tester, 1, 'Hassan Adel');
        await _tapContinue(tester);

        // The old guest is gone: only the new party is in the provider.
        final travelers = container.read(hotelGuestTravelersProvider);
        expect(travelers, hasLength(2));
        expect(
          travelers.map((Map<String, dynamic> t) => t['firstName']),
          <dynamic>['Mona', 'Hassan'],
        );
        expect(
          travelers.any((Map<String, dynamic> t) => t['firstName'] == 'Nour'),
          isFalse,
        );
      },
    );
  });
}
