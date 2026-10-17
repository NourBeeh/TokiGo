import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/widgets/shimmer.dart';
import 'package:tokigo/features/home/presentation/widgets/flight_recommendation_card.dart';
import 'package:tokigo/features/search/presentation/widgets/flight_route_line.dart';

Widget _wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: SingleChildScrollView(child: child))));

HomeItem _makeItem({
  String id = 'f1',
  String title = 'EgyptAir',
  Map<String, dynamic>? metadata,
}) =>
    HomeItem(
      id: id,
      type: HomeCardType.flight,
      title: title,
      price: 15000,
      currency: 'EGP',
      metadata: metadata ?? const {},
    );

void main() {
  group('FlightRecommendationCard', () {
    testWidgets('renders tile with route strip, airline and price', (tester) async {
      await tester.pumpWidget(_wrap(FlightRecommendationCard(item: _makeItem(
        metadata: {
          'origin': 'CAI',
          'destination': 'DXB',
          'departureTime': DateTime(2026, 1, 1, 8, 0).toIso8601String(),
          'arrivalTime': DateTime(2026, 1, 1, 11, 30).toIso8601String(),
          'airline': 'EgyptAir',
          'flightNumber': 'MS 123',
          'stops': 0,
          'recommendation': 'cheapest',
        },
      ))));

      expect(find.text('EgyptAir'), findsOneWidget);
      expect(find.text('CAI'), findsOneWidget);
      expect(find.text('DXB'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('11:30'), findsOneWidget);
      expect(find.text('3h 30m'), findsOneWidget);
      expect(find.text('Non-stop'), findsOneWidget);
      expect(find.text('Cheapest'), findsOneWidget);
      // Price over scrim-free surface
      expect(find.textContaining('EGP'), findsOneWidget);
      // Uses the shared route line primitive
      expect(find.byType(FlightRouteLine), findsOneWidget);
    });

    testWidgets('renders stops text for 1-stop flights with stop airport', (tester) async {
      await tester.pumpWidget(_wrap(FlightRecommendationCard(item: _makeItem(
        metadata: {
          'origin': 'CAI',
          'destination': 'LHR',
          'stops': 1,
          'stopAirport': 'IST',
        },
      ))));

      expect(find.text('1 stop (IST)'), findsOneWidget);
    });

    testWidgets('renders seats-left badge when few seats remain', (tester) async {
      await tester.pumpWidget(_wrap(FlightRecommendationCard(item: _makeItem(
        metadata: {
          'seatsLeft': 3,
          'recommendation': 'best_value',
        },
      ))));

      expect(find.text('Best Value'), findsOneWidget);
      expect(find.text('3 seats left'), findsOneWidget);
    });

    testWidgets('hides seats badge when many seats remain', (tester) async {
      await tester.pumpWidget(_wrap(FlightRecommendationCard(item: _makeItem(
        metadata: {'seatsLeft': 30},
      ))));

      expect(find.textContaining('seats left'), findsNothing);
    });

    testWidgets('loading: skeleton, no fake data', (tester) async {
      await tester.pumpWidget(_wrap(const FlightRecommendationCard(
        item: HomeItem(id: '', type: HomeCardType.flight, title: ''),
        loading: true,
      )));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ShimmerBox), findsWidgets);
      // No airline, route or price text may render in loading state
      expect(find.text('EgyptAir'), findsNothing);
      expect(find.text('CAI'), findsNothing);
      expect(find.textContaining('EGP'), findsNothing);
    });

    testWidgets('onTap callback fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(FlightRecommendationCard(
        item: _makeItem(),
        onTap: () => taps++,
      )));

      await tester.tap(find.byType(FlightRecommendationCard));
      expect(taps, 1);
    });

    testWidgets('semantics label aggregates info', (tester) async {
      await tester.pumpWidget(_wrap(FlightRecommendationCard(item: _makeItem(
        metadata: {
          'origin': 'CAI',
          'destination': 'DXB',
          'recommendation': 'cheapest',
        },
      ))));

      final semantics = tester.getSemantics(find.byType(FlightRecommendationCard));
      expect(semantics.label, contains('Recommended flight'));
      expect(semantics.label, contains('EgyptAir'));
      expect(semantics.label, contains('CAI to DXB'));
      expect(semantics.label, contains('cheapest'));
    });

    testWidgets('dark mode renders without errors', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: FlightRecommendationCard(item: _makeItem(metadata: {
            'origin': 'CAI',
            'destination': 'DXB',
          })),
        ),
      ));
      expect(find.byType(FlightRecommendationCard), findsOneWidget);
    });

    testWidgets('RTL layout renders without overflow', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(
          body: FlightRecommendationCard(item: _makeItem(metadata: {
            'origin': 'CAI',
            'destination': 'DXB',
            'airline': 'طيران مصر',
            'flightNumber': 'MS 985',
          })),
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text scale renders without overflow', (tester) async {
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: child!,
        ),
        home: Scaffold(
          body: FlightRecommendationCard(item: _makeItem(metadata: {
            'origin': 'CAI',
            'destination': 'DXB',
            'airline': 'EgyptAir',
            'flightNumber': 'MS 985',
          })),
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow width (320) renders without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FlightRecommendationCard(item: _makeItem(metadata: {
            'origin': 'CAI',
            'destination': 'DXB',
          })),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
