import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/widgets/shimmer.dart';

import 'package:tokigo/core/domain/models/offers/travel_package_offer.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/features/search/presentation/widgets/package_search_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 400, child: child))));

TravelPackageOffer _makeOffer({
  String id = 'p1',
  String title = 'Egypt Explorer',
  String destination = 'Cairo, Luxor, Aswan',
  String? imageUrl,
  double price = 15000,
  String currency = 'EGP',
  int durationDays = 7,
  List<String> inclusions = const ['Flights', 'Hotels', 'Transfers'],
  double? rating = 4.7,
  int? reviewCount = 120,
  Map<String, dynamic>? metadata,
}) =>
    TravelPackageOffer(
      id: id,
      providerId: 'prov1',
      providerName: 'Test Provider',
      title: title,
      destination: destination,
      durationDays: durationDays,
      inclusions: inclusions,
      imageUrl: imageUrl,
      price: price,
      currency: currency,
      rating: rating,
      reviewCount: reviewCount,
      metadata: metadata ?? {},
    );

void main() {
  group('PackageSearchCard', () {
    testWidgets('renders all core elements from TravelPackageOffer (horizontal layout)', (tester) async {
      await tester.pumpWidget(_wrap(PackageSearchCard(offer: _makeOffer())));

      expect(find.text('Egypt Explorer'), findsOneWidget);
      expect(find.text('Cairo · Luxor · Aswan'), findsOneWidget);
      expect(find.text('1 week'), findsOneWidget);
      expect(find.text('Flights'), findsOneWidget);
      expect(find.text('Hotels'), findsOneWidget);
      expect(find.text('Transfers'), findsOneWidget);
      expect(find.byType(CardImage), findsOneWidget);
      // Cities rendered through the shared location primitive
      expect(find.byType(CardLocation), findsOneWidget);
      expect(find.byType(CardFeatureList), findsOneWidget);
      // NO CardRating - removed per spec
      expect(find.byType(CardRating), findsNothing);
      expect(find.byType(CardPriceBlock), findsOneWidget);
      // NO CTA button
      expect(find.byType(CardPrimaryAction), findsNothing);
      expect(find.text('View Package'), findsNothing);
    });

    testWidgets('renders duration formatting correctly', (tester) async {
      // 1 day
      await tester.pumpWidget(_wrap(PackageSearchCard(offer: _makeOffer(durationDays: 1))));
      expect(find.text('1 day'), findsOneWidget);

      // 1 week
      await tester.pumpWidget(_wrap(PackageSearchCard(offer: _makeOffer(durationDays: 7))));
      expect(find.text('1 week'), findsOneWidget);

      // 10 days = 1 week 3 days
      await tester.pumpWidget(_wrap(PackageSearchCard(offer: _makeOffer(durationDays: 10))));
      expect(find.text('1 week 3 days'), findsOneWidget);

      // 2 weeks
      await tester.pumpWidget(_wrap(PackageSearchCard(offer: _makeOffer(durationDays: 14))));
      expect(find.text('2 weeks'), findsOneWidget);
    });

    testWidgets('renders only first 3 inclusions', (tester) async {
      await tester.pumpWidget(_wrap(PackageSearchCard(offer: _makeOffer(
        inclusions: ['Flights', 'Hotels', 'Transfers', 'Meals', 'Guide', 'Insurance'],
      ))));

      expect(find.text('Flights'), findsOneWidget);
      expect(find.text('Hotels'), findsOneWidget);
      expect(find.text('Transfers'), findsOneWidget);
      expect(find.text('Meals'), findsNothing);
      expect(find.text('Guide'), findsNothing);
      expect(find.text('Insurance'), findsNothing);
    });

    testWidgets('does not render rating even when available (removed per spec)', (tester) async {
      await tester.pumpWidget(_wrap(PackageSearchCard(offer: _makeOffer(
        rating: 4.5,
        reviewCount: 88,
      ))));

      expect(find.byType(CardRating), findsNothing);
      expect(find.text('4.5'), findsNothing);
      expect(find.text('(88)'), findsNothing);
    });

    testWidgets('does not render original price strikethrough when in metadata (removed per spec)', (tester) async {
      await tester.pumpWidget(_wrap(PackageSearchCard(offer: _makeOffer(
        price: 12000,
        metadata: {'originalPrice': 15000},
      ))));

      expect(find.text('EGP 12000'), findsOneWidget);
      expect(find.text('EGP 15000'), findsNothing);
    });

    testWidgets('onTap callback fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(PackageSearchCard(
        offer: _makeOffer(),
        onTap: () => taps++,
      )));

      await tester.tap(find.byType(BaseCard));
      expect(taps, 1);
    });

    testWidgets('disabled: reduced opacity, tap swallowed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(PackageSearchCard(
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
      await tester.pumpWidget(_wrap(PackageSearchCard(
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

    testWidgets('no CTA button', (tester) async {
      await tester.pumpWidget(_wrap(PackageSearchCard(offer: _makeOffer())));

      expect(find.byType(CardPrimaryAction), findsNothing);
      expect(find.text('View Package'), findsNothing);
    });

    testWidgets('semantics label aggregates all info (updated format)', (tester) async {
      await tester.pumpWidget(_wrap(PackageSearchCard(offer: _makeOffer())));

      final semantics = tester.getSemantics(find.byType(PackageSearchCard));
      expect(semantics.label, contains('Egypt Explorer'));
      expect(semantics.label, contains('Package to Cairo · Luxor · Aswan'));
      expect(semantics.label, contains('Duration 1 week'));
      expect(semantics.label, contains('Flights'));
      expect(semantics.label, contains('Hotels'));
      expect(semantics.label, contains('Transfers'));
      expect(semantics.label, contains('Price 15,000.00 EGP / person'));
      // NO rating/reviews in semantics
      expect(semantics.label, isNot(contains('stars')));
      expect(semantics.label, isNot(contains('reviews')));
    });

    testWidgets('dark mode renders without errors', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: PackageSearchCard(offer: _makeOffer())),
      ));

      expect(find.byType(PackageSearchCard), findsOneWidget);
    });

    testWidgets('RTL layout renders without overflow', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(body: PackageSearchCard(offer: _makeOffer())),
      ));

      expect(find.byType(PackageSearchCard), findsOneWidget);
    });
  });
}