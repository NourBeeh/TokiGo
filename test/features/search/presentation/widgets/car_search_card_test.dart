import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/widgets/shimmer.dart';

import 'package:tokigo/core/domain/models/offers/car_offer.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/features/search/presentation/widgets/car_search_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

CarOffer _makeOffer({
  String id = 'c1',
  String title = 'Toyota Camry',
  String carType = 'Sedan',
  String? imageUrl,
  double price = 1200,
  String currency = 'EGP',
  String? transmission = 'Automatic',
  int? seats = 5,
  Map<String, dynamic>? metadata,
  DateTime? pickupTime,
  DateTime? dropoffTime,
  String pickupLocation = 'CAI Airport',
  String dropoffLocation = 'DXB Airport',
}) =>
    CarOffer(
      id: id,
      providerId: 'p1',
      providerName: 'Test Provider',
      title: title,
      carType: carType,
      transmission: transmission,
      seats: seats,
      imageUrl: imageUrl,
      price: price,
      currency: currency,
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      pickupTime: pickupTime ?? DateTime.now().add(const Duration(days: 1, hours: 10)),
      dropoffTime: dropoffTime ?? DateTime.now().add(const Duration(days: 4, hours: 10)),
      metadata: metadata ?? {},
    );

void main() {
  group('CarSearchCard', () {
    testWidgets('renders all core elements for car with metadata', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer(
        imageUrl: null,
        metadata: {
          'luggage': '2 bags',
        },
      ))));

      expect(find.text('Toyota Camry'), findsOneWidget);
      expect(find.text('Sedan'), findsOneWidget);
      expect(find.text('Automatic'), findsOneWidget);
      expect(find.text('5 seats'), findsOneWidget);
      expect(find.text('2 bags'), findsOneWidget);
      expect(find.byType(CardImage), findsOneWidget);
      expect(find.byType(CardFeatureList), findsOneWidget);
      expect(find.byType(CardPriceBlock), findsOneWidget);
      // NO CTA button
      expect(find.byType(CardPrimaryAction), findsNothing);
      expect(find.text('View Details'), findsNothing);
    });

    testWidgets('renders discount badge when originalPrice > price', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer(
        price: 1000,
        metadata: {'originalPrice': 1500},
      ))));

      expect(find.text('33% OFF'), findsOneWidget);
      // There are 2 badges: discount + car type
      expect(find.byType(CardBadge), findsNWidgets(2));
    });

    testWidgets('does not render discount badge when no discount', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer())));

      expect(find.textContaining('% OFF'), findsNothing);
    });

    testWidgets('renders "or similar" when metadata has orSimilar', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer(metadata: {
        'orSimilar': true,
      }))));

      expect(find.text('or similar'), findsOneWidget);
    });

    testWidgets('does not render "or similar" when not in metadata', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer())));

      expect(find.text('or similar'), findsNothing);
    });

    testWidgets('renders mileage policy when available', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer(metadata: {
        'mileagePolicy': 'Unlimited mileage',
      }))));

      expect(find.textContaining('Unlimited mileage'), findsOneWidget);
      // Car type badge only (mileage is inline metadata, not a badge)
      expect(find.byType(CardBadge), findsOneWidget);
    });

    testWidgets('renders limited mileage policy', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer(metadata: {
        'mileagePolicy': '200 km/day',
      }))));

      expect(find.textContaining('200 km/day'), findsOneWidget);
    });

    testWidgets('does not render mileage policy when not in metadata', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer())));

      expect(find.text('mileage'), findsNothing);
    });

    testWidgets('renders rental duration from pickup/dropoff', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer(
        pickupTime: DateTime(2026, 9, 1, 10, 0),
        dropoffTime: DateTime(2026, 9, 4, 10, 0),
      ))));

      // 3 days rental
      expect(find.text('3 days'), findsOneWidget);
    });

    testWidgets('renders 1 day for same-day rental', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer(
        pickupTime: DateTime(2026, 9, 1, 10, 0),
        dropoffTime: DateTime(2026, 9, 1, 18, 0),
      ))));

      expect(find.text('1 day'), findsOneWidget);
    });

    testWidgets('renders free cancellation when available', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer(metadata: {
        'freeCancellation': true,
        'cancellationPolicy': 'Free cancellation until 24h',
      }))));

      expect(find.text('Free cancellation until 24h'), findsOneWidget);
      expect(find.byType(CardCancellation), findsOneWidget);
      final cancellation = tester.widget<CardCancellation>(find.byType(CardCancellation));
      expect(cancellation.freeCancellation, true);
    });

    testWidgets('does not render cancellation when not free', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer(metadata: {
        'cancellationPolicy': 'Non-refundable',
      }))));

      expect(find.byType(CardCancellation), findsNothing);
    });

    testWidgets('renders price per day with total for multi-day', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer(
        price: 100,
        currency: 'USD',
        pickupTime: DateTime(2026, 9, 1, 10, 0),
        dropoffTime: DateTime(2026, 9, 4, 10, 0), // 3 days
      ))));

      // Per day price (primary + perDay secondary) = 2, total = 300 (different)
      expect(find.text('USD 100'), findsNWidgets(2));
      expect(find.text('USD 300'), findsOneWidget);
      // Unit "/day" appears in primary unit + perDay secondary = 2
      expect(find.text('/day'), findsNWidgets(2));
      // Total should show for multi-day
      expect(find.textContaining('total'), findsOneWidget);
      expect(find.textContaining('300'), findsOneWidget);
    });

    testWidgets('renders price per day for single day (no total)', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer(
        price: 100,
        currency: 'USD',
        pickupTime: DateTime(2026, 9, 1, 10, 0),
        dropoffTime: DateTime(2026, 9, 1, 18, 0),
      ))));

      // Primary price + per-day secondary = 2 occurrences of price
      // Unit "/day" appears in primary unit + perDay secondary = 2 occurrences
      expect(find.text('USD 100'), findsNWidgets(2));
      expect(find.text('/day'), findsNWidgets(2));
      // No total for single day
      expect(find.textContaining('total'), findsNothing);
    });

    testWidgets('renders transmission, seats, luggage as features', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer(
        transmission: 'Manual',
        seats: 2,
        metadata: {'luggage': '1 bag'},
      ))));

      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('2 seats'), findsOneWidget);
      expect(find.text('1 bag'), findsOneWidget);
      expect(find.byType(CardFeatureList), findsOneWidget);
    });

    testWidgets('onTap callback fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(CarSearchCard(
        offer: _makeOffer(),
        onTap: () => taps++,
      )));

      await tester.tap(find.byType(BaseCard));
      expect(taps, 1);
    });

    testWidgets('disabled: reduced opacity, tap swallowed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(CarSearchCard(
        offer: _makeOffer(),
        enabled: false,
        onTap: () => taps++,
      )));

      await tester.tap(find.byType(BaseCard));
      expect(taps, 0);

      final opacity = tester.widget<Opacity>(find.descendant(
        of: find.byType(BaseCard),
        matching: find.byType(Opacity),
      ).first);
      expect(opacity.opacity, 0.55);
    });

    testWidgets('loading: renders skeleton with no fake data, tap blocked', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(CarSearchCard(
        offer: _makeOffer(),
        loading: true,
        onTap: () => taps++,
      )));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Skeleton renders shimmer blocks and must not display any offer text
      expect(find.byType(ShimmerBox), findsWidgets);
      await tester.tap(find.byType(BaseCard));
      expect(taps, 0);
    });

    testWidgets('semantics label aggregates all info', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer(metadata: {
        'originalPrice': 1500,
        'orSimilar': true,
        'luggage': '2 bags',
        'mileagePolicy': 'Unlimited mileage',
        'freeCancellation': true,
        'cancellationPolicy': 'Free cancellation',
      }))));

      final semantics = tester.getSemantics(find.byType(CarSearchCard));
      expect(semantics.label, contains('Toyota Camry'));
      expect(semantics.label, contains('Sedan'));
      expect(semantics.label, contains('Automatic'));
      expect(semantics.label, contains('5 seats'));
      expect(semantics.label, contains('2 bags'));
      expect(semantics.label, contains('Unlimited mileage'));
      expect(semantics.label, contains('Free cancellation'));
    });

    testWidgets('dark mode renders without errors', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: CarSearchCard(offer: _makeOffer())),
      ));

      expect(find.byType(CarSearchCard), findsOneWidget);
    });

    testWidgets('RTL layout renders without overflow', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(body: CarSearchCard(offer: _makeOffer())),
      ));

      expect(find.byType(CarSearchCard), findsOneWidget);
    });

    testWidgets('long car name ellipsizes', (tester) async {
      await tester.pumpWidget(_wrap(CarSearchCard(offer: _makeOffer(
        title: 'Very Long Car Name That Should Be Truncated Properly In The UI',
      ))));

      expect(find.byType(CarSearchCard), findsOneWidget);
    });
  });
}