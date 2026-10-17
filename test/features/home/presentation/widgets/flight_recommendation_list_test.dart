import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/widgets/flight_recommendation_card.dart';
import 'package:tokigo/features/home/presentation/widgets/flight_recommendation_list.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(height: 600, child: child)));

List<HomeItem> _flightItems(int count) => List.generate(
      count,
      (i) => HomeItem(
        id: 'f$i',
        type: HomeCardType.flight,
        title: 'EgyptAir $i',
        price: 1200 + i * 100,
        currency: 'USD',
        imageUrl: null,
        metadata: {
          'origin': 'CAI',
          'destination': 'DXB',
          'departureTime': DateTime(2026, 1, 1, 8, 0).toIso8601String(),
          'arrivalTime': DateTime(2026, 1, 1, 11, 30).toIso8601String(),
          'airline': 'EgyptAir $i',
        },
      ),
    );

void main() {
  group('FlightRecommendationList', () {
    testWidgets('renders header with title and View All', (tester) async {
      await tester.pumpWidget(_wrap(FlightRecommendationList(
        items: _flightItems(3),
        title: 'Recommended Flights',
        onViewAll: () {},
      )));

      expect(find.text('Recommended Flights'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);
    });

    testWidgets('renders a horizontal carousel of FlightRecommendationCards',
        (tester) async {
      await tester.pumpWidget(_wrap(FlightRecommendationList(
        items: _flightItems(3),
      )));

      expect(find.byType(FlightRecommendationCard), findsNWidgets(3));
      // Carousel is a horizontal scroll list
      final listView = tester.widget<ListView>(
        find
            .descendant(
              of: find.byType(FlightRecommendationList),
              matching: find.byType(ListView),
            )
            .first,
      );
      expect(listView.scrollDirection, Axis.horizontal);
    });

    testWidgets('respects maxRows limit', (tester) async {
      await tester.pumpWidget(_wrap(FlightRecommendationList(
        items: _flightItems(5),
        maxRows: 2,
      )));

      expect(find.byType(FlightRecommendationCard), findsNWidgets(2));
    });

    testWidgets('loading renders skeleton cards with no data', (tester) async {
      await tester.pumpWidget(_wrap(FlightRecommendationList(
        items: const [],
        loading: true,
        maxRows: 3,
      )));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FlightRecommendationCard), findsNWidgets(3));
      // No airline or route text may render in loading state
      expect(find.textContaining('EgyptAir'), findsNothing);
      expect(find.text('CAI'), findsNothing);
      // View All is hidden while loading
      expect(find.text('View All'), findsNothing);
    });

    testWidgets('skeleton items render loading cards', (tester) async {
      final skeletonItems = List.generate(
        2,
        (i) => HomeItem(
          id: 's$i',
          type: HomeCardType.flight,
          title: '',
        ),
      );
      await tester.pumpWidget(_wrap(FlightRecommendationList(
        items: skeletonItems,
        maxRows: 3,
      )));
      await tester.pump(const Duration(milliseconds: 100));

      // No real content may appear
      expect(find.textContaining('CAI'), findsNothing);
      expect(find.textContaining('USD'), findsNothing);
    });

    testWidgets('does not duplicate flight row UI inside the list itself',
        (tester) async {
      await tester.pumpWidget(_wrap(FlightRecommendationList(
        items: _flightItems(2),
      )));

      // The list must be a container only: all text lives inside the cards.
      // With 2 cards rendered, 'CAI' appears exactly twice (once per card).
      expect(find.text('CAI'), findsNWidgets(2));
    });

    testWidgets('onTapFlight forwards the tapped item', (tester) async {
      HomeItem? tapped;
      await tester.pumpWidget(_wrap(FlightRecommendationList(
        items: _flightItems(2),
        onTapFlight: (item) => tapped = item,
      )));

      await tester.tap(find.byType(FlightRecommendationCard).first);
      expect(tapped, isNotNull);
      expect(tapped!.id, 'f0');
    });

    testWidgets('renders without overflow at narrow width', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FlightRecommendationList(items: _flightItems(3)),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
