import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/domain/models/offers/travel_package_offer.dart';
import 'package:tokigo/features/search/presentation/pages/offer_details_page.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Phase 3D — Product details (regression suite).
///
/// Contract pinned here:
/// - Every vertical's provider-verbatim fields render on the details page
///   (Flight: fare/refundable/baggage · Hotel: stars/board/taxes/cancellation
///   · Car: mileage/cancellation/features · Package: inclusions).
/// - ABSENT fields stay absent — nothing is ever invented (3B/3D rule).
/// - The sticky CTA keeps routing through /booking/review (revalidation
///   before booking — spec point 8/44).
/// - The honest pricing note ("Revalidated at booking") is visible.

Widget _host(Widget child) {
  final router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, __) => child,
      ),
      GoRoute(
        path: '/booking/review',
        builder: (_, __) => const Scaffold(body: Center(child: Text('REVIEW'))),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => ProviderScope(child: child!),
  );
}

FlightOffer _flight({
  Map<String, dynamic> metadata = const {},
  String? cabinClass,
}) {
  return FlightOffer(
    id: 'of-1',
    providerId: 'duffel',
    providerName: 'Duffel',
    title: 'CAI → DXB',
    price: 320,
    currency: 'USD',
    origin: 'CAI',
    destination: 'DXB',
    departureTime: DateTime(2026, 9, 12, 8, 30),
    arrivalTime: DateTime(2026, 9, 12, 12, 45),
    airline: 'EgyptAir',
    flightNumber: 'MS910',
    stops: 1,
    cabinClass: cabinClass,
    metadata: metadata,
  );
}

HotelOffer _hotel({Map<String, dynamic> metadata = const {}}) {
  return HotelOffer(
    id: 'rate-1',
    providerId: 'nuitee',
    providerName: 'Nuitee Connect',
    title: 'Cairo Grand Hotel',
    price: 490,
    currency: 'USD',
    city: 'Cairo',
    country: 'Egypt',
    checkIn: DateTime(2026, 9, 12),
    checkOut: DateTime(2026, 9, 15),
    roomType: 'Twin Room (Madina Deluxe)',
    rating: 4.8,
    metadata: metadata,
  );
}

CarOffer _car({Map<String, dynamic> metadata = const {}}) {
  return CarOffer(
    id: 'car-1',
    providerId: 'mock-car',
    providerName: 'Mock Car Co',
    title: 'Toyota Corolla',
    price: 210,
    currency: 'USD',
    pickupLocation: 'Cairo Downtown',
    dropoffLocation: 'Cairo Downtown',
    pickupTime: DateTime(2026, 9, 12, 10),
    dropoffTime: DateTime(2026, 9, 15, 10),
    carType: 'Economy',
    transmission: 'Automatic',
    seats: 5,
    metadata: metadata,
  );
}

TravelPackageOffer _package() {
  return TravelPackageOffer(
    id: 'pkg-1',
    providerId: 'packages',
    providerName: 'TokiGo Packages',
    title: 'Sharm El Sheikh · 5 days',
    price: 599,
    currency: 'USD',
    destination: 'Sharm El Sheikh',
    durationDays: 5,
    inclusions: const <String>['Flights', 'Resort stay', 'Airport transfer'],
  );
}

void main() {
  testWidgets('FLIGHT details: fare/refundable/baggage render from provider metadata',
      (tester) async {
    await tester.pumpWidget(_host(OfferDetailsPage(
      offer: _flight(metadata: const <String, dynamic>{
        'fareFamily': 'Basic',
        'refundable': true,
        'baggage': <String, dynamic>{'quantity': 1, 'type': 'checked'},
      }),
    )));
    await tester.pumpAndSettle();

    // Summary card rows.
    expect(find.text('Basic'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    // Baggage section (map form: quantity × type).
    expect(find.text('1 × checked'), findsOneWidget);
  });

  testWidgets('FLIGHT details: absent fare fields render nothing invented',
      (tester) async {
    await tester.pumpWidget(_host(OfferDetailsPage(offer: _flight())));
    await tester.pumpAndSettle();

    expect(find.text('Basic'), findsNothing);
    expect(find.text('Yes'), findsNothing);
    expect(find.text('1 × checked'), findsNothing);
    expect(find.text('Baggage'), findsNothing);
  });

  testWidgets('HOTEL details: stars/board/taxes/cancellation render verbatim',
      (tester) async {
    await tester.pumpWidget(_host(OfferDetailsPage(
      offer: _hotel(metadata: const <String, dynamic>{
        'stars': 5,
        'boardName': 'Room Only',
        'refundable': true,
        'taxesAndFees': <String, dynamic>{
          'amount': 25.69,
          'currency': 'USD',
          'included': true,
          'description': 'Tax',
        },
        'cancellationPolicy': <String, dynamic>{
          'refundableUntil': '2026-10-13 07:00:00',
          'feeAmount': 623.2,
          'feeCurrency': 'USD',
        },
      }),
    )));
    await tester.pumpAndSettle();

    // Summary rows.
    expect(find.text('5'), findsWidgets); // stars
    expect(find.text('Room Only'), findsOneWidget);
    // Taxes & fees section.
    expect(find.textContaining('USD 25.69'), findsOneWidget);
    expect(find.textContaining('included in price'), findsOneWidget);
    // Cancellation policy section.
    expect(find.textContaining('Free cancellation until 2026-10-13'), findsOneWidget);
    expect(find.textContaining('623.2'), findsOneWidget);
  });

  testWidgets('HOTEL details: non-refundable rate — honest label, no invented policy',
      (tester) async {
    await tester.pumpWidget(_host(OfferDetailsPage(
      offer: _hotel(metadata: const <String, dynamic>{
        'refundable': false,
      }),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Non-refundable rate'), findsOneWidget);
    expect(find.textContaining('Free cancellation until'), findsNothing);
  });

  testWidgets('CAR details: mileage/cancellation/features render from catalog',
      (tester) async {
    await tester.pumpWidget(_host(OfferDetailsPage(
      offer: _car(metadata: const <String, dynamic>{
        'mileagePolicy': 'Unlimited mileage',
        'cancellationPolicy': 'Free cancellation up to 24h before pickup',
        'features': <String>['GPS', 'Bluetooth'],
      }),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Unlimited mileage'), findsOneWidget);
    expect(find.text('Free cancellation up to 24h before pickup'), findsOneWidget);
    expect(find.text('GPS · Bluetooth'), findsOneWidget);
  });

  testWidgets('PACKAGE details: inclusions list renders with check icons',
      (tester) async {
    await tester.pumpWidget(_host(OfferDetailsPage(offer: _package())));
    await tester.pumpAndSettle();

    expect(find.text('Inclusions'), findsOneWidget);
    for (final line in <String>['Flights', 'Resort stay', 'Airport transfer']) {
      expect(find.text(line), findsOneWidget);
    }
  });

  testWidgets('CTA routes to /booking/review (revalidation path) and shows honest price note',
      (tester) async {
    await tester.pumpWidget(_host(OfferDetailsPage(offer: _hotel())));
    await tester.pumpAndSettle();

    // Honest pricing note (spec point 44).
    expect(find.text('Revalidated at booking'), findsOneWidget);

    await tester.tap(find.text('Book now'));
    await tester.pumpAndSettle();
    expect(find.text('REVIEW'), findsOneWidget);
  });
}
