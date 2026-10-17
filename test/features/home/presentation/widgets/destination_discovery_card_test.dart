import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/core/widgets/shimmer.dart';
import 'package:tokigo/features/home/presentation/widgets/destination_discovery_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 300, height: 250, child: child))));

HomeItem _makeItem({
  String id = 'd1',
  String title = 'Paris',
  String? imageUrl,
  String? currency = 'USD',
  Map<String, dynamic>? metadata,
}) =>
    HomeItem(
      id: id,
      type: HomeCardType.destination,
      title: title,
      imageUrl: imageUrl,
      currency: currency,
      metadata: metadata ?? {},
    );

void main() {
  group('DestinationDiscoveryCard', () {
    testWidgets('renders all core elements', (tester) async {
      await tester.pumpWidget(_wrap(DestinationDiscoveryCard(item: _makeItem(
        imageUrl: null,
        metadata: {'country': 'France'},
      ))));

      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('France'), findsOneWidget);
      expect(find.byType(CardImage), findsOneWidget);
      // NO price
      expect(find.textContaining('USD'), findsNothing);
      // NO rating
      expect(find.byType(CardRating), findsNothing);
      // NO CTA button
      expect(find.byType(CardPrimaryAction), findsNothing);
      expect(find.text('View Deal'), findsNothing);
      expect(find.text('Explore'), findsNothing);
      // NO Bag
      expect(find.byType(CardFavorite), findsNothing);
    });

    testWidgets('renders country from metadata.region when country not present', (tester) async {
      await tester.pumpWidget(_wrap(DestinationDiscoveryCard(item: _makeItem(
        imageUrl: null,
        metadata: {'region': 'Provence'},
      ))));

      expect(find.text('Provence'), findsOneWidget);
    });

    testWidgets('renders country from item.subtitle when no country/region in metadata', (tester) async {
      // The _getCountry method falls back to item.subtitle
      // We need to create an item with subtitle directly
      await tester.pumpWidget(_wrap(DestinationDiscoveryCard(item: HomeItem(
        id: 'd1',
        type: HomeCardType.destination,
        title: 'Paris',
        subtitle: 'France',
        imageUrl: null,
        currency: 'USD',
        metadata: {},
      ))));

      expect(find.text('France'), findsOneWidget);
    });

    testWidgets('renders no country when not available', (tester) async {
      await tester.pumpWidget(_wrap(DestinationDiscoveryCard(item: _makeItem(
        imageUrl: null,
        metadata: {},
      ))));

      // Should only have destination name
      expect(find.text('Paris'), findsOneWidget);
    });

    testWidgets('onTap callback fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(DestinationDiscoveryCard(
        item: _makeItem(metadata: {'country': 'France'}),
        onTap: () => taps++,
      )));

      await tester.tap(find.byType(DestinationDiscoveryCard));
      expect(taps, 1);
    });

    testWidgets('semantics label aggregates info', (tester) async {
      await tester.pumpWidget(_wrap(DestinationDiscoveryCard(item: _makeItem(
        title: 'Paris',
        metadata: {'country': 'France'},
      ))));

      final semantics = tester.getSemantics(find.byType(DestinationDiscoveryCard));
      expect(semantics.label, contains('Destination'));
      expect(semantics.label, contains('Paris'));
      expect(semantics.label, contains('France'));
    });

    testWidgets('long destination name ellipsizes', (tester) async {
      await tester.pumpWidget(_wrap(DestinationDiscoveryCard(item: _makeItem(
        title: 'Very Long Destination Name That Should Be Truncated Properly',
        imageUrl: null,
        metadata: {'country': 'France'},
      ))));

      expect(find.byType(DestinationDiscoveryCard), findsOneWidget);
    });

    testWidgets('dark mode renders without errors', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: DestinationDiscoveryCard(item: _makeItem(
          imageUrl: null,
          metadata: {'country': 'France'},
        ))),
      ));

      expect(find.byType(DestinationDiscoveryCard), findsOneWidget);
    });

    testWidgets('RTL layout renders without overflow', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(body: DestinationDiscoveryCard(item: _makeItem(
          imageUrl: null,
          metadata: {'country': 'France'},
        ))),
      ));

      expect(find.byType(DestinationDiscoveryCard), findsOneWidget);
    });

    testWidgets('loading: skeleton, no fake data, tap blocked', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(DestinationDiscoveryCard(
        item: _makeItem(),
        loading: true,
        onTap: () => taps++,
      )));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ShimmerBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // No destination text may render in loading state
      expect(find.text('Paris'), findsNothing);
      expect(find.text('France'), findsNothing);
      await tester.tap(find.byType(BaseCard));
      expect(taps, 0);
    });

    testWidgets('large text scale renders without overflow', (tester) async {
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: child!,
        ),
        home: Scaffold(body: DestinationDiscoveryCard(item: _makeItem(
          title: 'Very Long Destination Name',
          metadata: {'country': 'France'},
        ))),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}