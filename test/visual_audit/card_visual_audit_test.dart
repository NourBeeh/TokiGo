import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/widgets/deal_card.dart';
import 'package:tokigo/features/home/presentation/widgets/destination_discovery_card.dart';
import 'package:tokigo/features/home/presentation/widgets/flight_recommendation_card.dart';
import 'package:tokigo/features/home/presentation/widgets/flight_recommendation_list.dart';
import 'package:tokigo/features/home/presentation/widgets/home_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_section.dart';
import 'package:tokigo/features/search/presentation/widgets/car_search_card.dart';
import 'package:tokigo/features/search/presentation/widgets/flight_search_card.dart';
import 'package:tokigo/features/search/presentation/widgets/hotel_search_card.dart';
import 'package:tokigo/features/search/presentation/widgets/package_search_card.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/domain/models/offers/travel_package_offer.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';

/// Visual audit for the Card System.
///
/// NOT a pass/fail golden test: it RENDERS the approved cards with real
/// geometry into PNGs under /tmp/opencode/card_audit so the visuals can be
/// inspected by a human (and by the agent) after the build. Any layout
/// exception during rendering fails the test.
///
/// Run: flutter test test/visual_audit/card_visual_audit_test.dart
void main() {
  final dir = Directory('/tmp/opencode/card_audit');
  setUpAll(() => dir.createSync(recursive: true));

  setUp(() {
    // Freeze shimmer/pulse animations so the test driver never waits on an
    // infinite ticker when capturing pixels.
    debugSemanticsDisableAnimations = true;
  });

  tearDown(() {
    debugSemanticsDisableAnimations = false;
  });

  Future<void> capture(
    WidgetTester tester,
    String name,
    Widget child, {
    Size size = const Size(430, 932),
  }) async {
    final key = GlobalKey();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: Material(child: child),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '$name threw a layout error');

    // toImage()/toByteData() are real async IO on the test driver — they must
    // run inside runAsync to avoid hanging the fake async test zone.
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/$name.png')
          .writeAsBytesSync(byteData!.buffer.asUint8List());
    });
  }

  testWidgets('audit: FlightSearchCard', (tester) async {
    await capture(
      tester,
      'flight_search_card',
      FlightSearchCard(
        offer: FlightOffer(
          id: 'f1',
          providerId: 'p1',
          providerName: 'Provider',
          title: 'Cairo to Dubai',
          price: 450,
          currency: 'USD',
          origin: 'CAI',
          destination: 'DXB',
          departureTime: DateTime(2026, 1, 1, 8, 0),
          arrivalTime: DateTime(2026, 1, 1, 11, 30),
          airline: 'EgyptAir',
          flightNumber: '985',
          stops: 0,
          cabinClass: 'Economy',
          metadata: {'baggage': '1 bag (23kg)', 'pricePerTraveler': 450, 'totalPrice': 900},
        ),
        onTap: () {},
        onFavorite: (_) {},
      ),
    );
  });

  testWidgets('audit: HotelSearchCard', (tester) async {
    await capture(
      tester,
      'hotel_search_card',
      HotelSearchCard(
        offer: HotelOffer(
          id: 'h1',
          providerId: 'p1',
          providerName: 'Provider',
          title: 'Nile Grand Hotel & Suites Riverside',
          price: 120,
          currency: 'USD',
          city: 'Luxor',
          country: 'Egypt',
          checkIn: DateTime(2026, 1, 1),
          checkOut: DateTime(2026, 1, 4),
          roomType: 'Deluxe Double',
          rating: 4.6,
          reviewCount: 1240,
          amenities: ['Pool', 'WiFi', 'Breakfast'],
          metadata: {'pricePerNight': 120, 'totalPrice': 360, 'freeCancellation': true},
        ),
        onTap: () {},
        onFavorite: (_) {},
      ),
    );
  });

  testWidgets('audit: PackageSearchCard', (tester) async {
    await capture(
      tester,
      'package_search_card',
      PackageSearchCard(
        offer: TravelPackageOffer(
          id: 'pk1',
          providerId: 'p1',
          providerName: 'Provider',
          title: 'Egypt Explorer',
          price: 899,
          currency: 'USD',
          destination: 'Cairo, Luxor, Aswan',
          durationDays: 7,
          inclusions: ['Flights', 'Hotels', 'Transfers', 'Guide'],
        ),
        onTap: () {},
        onFavorite: (_) {},
      ),
    );
  });

  testWidgets('audit: CarSearchCard', (tester) async {
    await capture(
      tester,
      'car_search_card',
      CarSearchCard(
        offer: CarOffer(
          id: 'c1',
          providerId: 'p1',
          providerName: 'Provider',
          title: 'Toyota Corolla',
          price: 55,
          currency: 'USD',
          pickupLocation: 'CAI Airport',
          dropoffLocation: 'CAI Airport',
          pickupTime: DateTime(2026, 1, 1, 10, 0),
          dropoffTime: DateTime(2026, 1, 4, 10, 0),
          carType: 'Economy',
          transmission: 'Automatic',
          seats: 5,
          metadata: {
            'luggage': '2 bags',
            'freeCancellation': true,
            'mileagePolicy': 'Unlimited mileage',
          },
        ),
        onTap: () {},
        onFavorite: (_) {},
      ),
    );
  });

  testWidgets('audit: FlightRecommendationCard', (tester) async {
    await capture(
      tester,
      'flight_recommendation_card',
      FlightRecommendationCard(
        item: HomeItem(
          id: 'r1',
          type: HomeCardType.flight,
          title: 'EgyptAir',
          price: 320,
          currency: 'USD',
          metadata: {
            'origin': 'CAI',
            'destination': 'DXB',
            'departureTime': DateTime(2026, 1, 1, 8, 0).toIso8601String(),
            'arrivalTime': DateTime(2026, 1, 1, 11, 30).toIso8601String(),
            'airline': 'EgyptAir',
            'flightNumber': 'MS 985',
            'stops': 0,
            'cabinClass': 'Economy',
            'recommendation': 'cheapest',
            'seatsLeft': 4,
          },
        ),
        onTap: () {},
      ),
    );
  });

  testWidgets('audit: DealCard', (tester) async {
    await capture(
      tester,
      'deal_card',
      DealCard(
        item: HomeItem(
          id: 'd1',
          type: HomeCardType.deal,
          title: 'Luxury Sharm Escape',
          subtitle: 'Sharm El Sheikh · 5 stars',
          price: 499,
          currency: 'USD',
          metadata: {'savingsPercent': 30},
        ),
        onTap: () {},
      ),
      size: const Size(360, 400),
    );
  });

  testWidgets('audit: DestinationDiscoveryCard', (tester) async {
    await capture(
      tester,
      'destination_discovery_card',
      DestinationDiscoveryCard(
        item: HomeItem(
          id: 'dest1',
          type: HomeCardType.destination,
          title: 'Paris',
          metadata: {'country': 'France'},
        ),
        onTap: () {},
      ),
      size: const Size(360, 400),
    );
  });

  testWidgets('audit: HomeSkeletonCard', (tester) async {
    await capture(
      tester,
      'home_skeleton_card',
      const SizedBox(
        width: 220,
        height: 240,
        child: HomeSkeletonCard(),
      ),
    );
  });

  testWidgets('audit: FlightRecommendationList (carousel)', (tester) async {
    await capture(
      tester,
      'flight_recommendation_list',
      FlightRecommendationList(
        items: List.generate(
          3,
          (i) => HomeItem(
            id: 'fl$i',
            type: HomeCardType.flight,
            title: 'EgyptAir',
            price: 300.0 + i * 20,
            currency: 'USD',
            metadata: {
              'origin': 'CAI',
              'destination': 'DXB',
              'departureTime': DateTime(2026, 1, 1, 8, 0).toIso8601String(),
              'arrivalTime': DateTime(2026, 1, 1, 11, 30).toIso8601String(),
              'airline': 'EgyptAir',
              'stops': 0,
              'recommendation': i == 0 ? 'cheapest' : null,
            },
          ),
        ),
        onViewAll: () {},
      ),
    );
  });

  testWidgets('audit: loading skeletons (search)', (tester) async {
    await capture(
      tester,
      'skeletons_search',
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlightSearchCard.loading(),
          SizedBox(height: 16),
          HotelSearchCard.loading(),
          SizedBox(height: 16),
          CarSearchCard.loading(),
          SizedBox(height: 16),
          PackageSearchCard.loading(),
        ],
      ),
    );
  });

  testWidgets('audit: Home section composition (marketplace)', (tester) async {
    await capture(
      tester,
      'home_section_marketplace',
      HomeSectionWidget(
        section: HomeSection(
          id: 'sec-1',
          title: 'Recommended for you',
          layout: HomeSectionLayout.flightRecommendationList,
          items: List.generate(
            3,
            (i) => HomeItem(
              id: 'hm$i',
              type: HomeCardType.flight,
              title: 'EgyptAir',
              price: 320.0 + i * 15,
              currency: 'USD',
              metadata: {
                'origin': 'CAI',
                'destination': 'DXB',
                'departureTime': DateTime(2026, 1, 1, 8, 0).toIso8601String(),
                'arrivalTime': DateTime(2026, 1, 1, 11, 30).toIso8601String(),
                'airline': 'EgyptAir',
                'stops': 0,
                'recommendation': 'cheapest',
              },
            ),
          ),
        ),
      ),
    );
  });

  testWidgets('audit: Home skeleton preview sections', (tester) async {
    HomeItem skeletonOf(HomeCardType type, String id) => HomeItem(
          id: id,
          type: type,
          title: '',
          subtitle: '',
          description: '',
          imageUrl: null,
          price: null,
          currency: null,
          metadata: const {},
        );
    await capture(
      tester,
      'home_skeleton_sections',
      SizedBox(
        height: 480,
        child: ListView(
          children: [
            HomeSectionWidget(
              section: HomeSection(
                id: 'sec-h',
                title: 'Hotels',
                layout: HomeSectionLayout.horizontalPeek,
                items: [
                  skeletonOf(HomeCardType.hotel, 'sk1'),
                  skeletonOf(HomeCardType.hotel, 'sk2'),
                ],
              ),
            ),
            HomeSectionWidget(
              section: HomeSection(
                id: 'sec-d',
                title: 'Hot Deals',
                layout: HomeSectionLayout.verticalDealList,
                items: [
                  skeletonOf(HomeCardType.deal, 'sk3'),
                  skeletonOf(HomeCardType.deal, 'sk4'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  });

  testWidgets('audit: compact flight card', (tester) async {
    await capture(
      tester,
      'flight_search_card_compact',
      FlightSearchCard(
        offer: FlightOffer(
          id: 'f1',
          providerId: 'p1',
          providerName: 'Provider',
          title: 'Cairo to Dubai',
          price: 450,
          currency: 'USD',
          origin: 'CAI',
          destination: 'DXB',
          departureTime: DateTime(2026, 1, 1, 8, 0),
          arrivalTime: DateTime(2026, 1, 1, 11, 30),
          airline: 'EgyptAir',
          flightNumber: '985',
          stops: 1,
          cabinClass: 'Economy',
          metadata: {'pricePerTraveler': 450, 'totalPrice': 900},
        ),
        onTap: () {},
      ),
    );
  });

  testWidgets('audit: RTL flight search card', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: Material(
              child: FlightSearchCard(
                offer: FlightOffer(
                  id: 'f1',
                  providerId: 'p1',
                  providerName: 'Provider',
                  title: 'القاهرة إلى دبي',
                  price: 450,
                  currency: 'USD',
                  origin: 'CAI',
                  destination: 'DXB',
                  departureTime: DateTime(2026, 1, 1, 8, 0),
                  arrivalTime: DateTime(2026, 1, 1, 11, 30),
                  airline: 'EgyptAir',
                  flightNumber: '985',
                  stops: 0,
                ),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'RTL flight card overflowed');

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/flight_search_card_rtl.png')
          .writeAsBytesSync(byteData!.buffer.asUint8List());
    });
  });
}
