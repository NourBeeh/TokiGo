import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/core/widgets/shimmer.dart';
import 'package:tokigo/features/home/presentation/widgets/deal_card.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 300, height: 400, child: child))));

HomeItem _makeItem({
  String id = 'deal-1',
  String title = 'Weekend in Sharm',
  String? subtitle = 'Sharm El Sheikh',
  String? imageUrl,
  double? price = 499,
  String? currency = 'USD',
  Map<String, dynamic>? metadata,
}) =>
    HomeItem(
      id: id,
      type: HomeCardType.deal,
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
      price: price,
      currency: currency,
      metadata: metadata ?? const {},
    );

void main() {
  group('DealCard', () {
    testWidgets('renders all core elements (image-first full-bleed)', (tester) async {
      await tester.pumpWidget(_wrap(DealCard(item: _makeItem(
        metadata: {'savingsPercent': 20},
      ))));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Weekend in Sharm'), findsOneWidget);
      expect(find.text('Sharm El Sheikh'), findsOneWidget);
      expect(find.text('20% OFF'), findsOneWidget);
      expect(find.byType(CardImage), findsOneWidget);
      // Price over scrim
      expect(find.textContaining('USD'), findsOneWidget);
      expect(find.text('Save 20%'), findsOneWidget);
    });

    testWidgets('hides optional data cleanly', (tester) async {
      await tester.pumpWidget(_wrap(DealCard(item: _makeItem(
        title: 'Mystery deal',
        subtitle: null,
        price: null,
        metadata: const {},
      ))));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mystery deal'), findsOneWidget);
      // No subtitle, no price, no savings when absent
      expect(find.textContaining('USD'), findsNothing);
      expect(find.textContaining('% OFF'), findsNothing);
      expect(find.textContaining('Save'), findsNothing);
    });

    testWidgets('loading: skeleton, no fake data, tap blocked', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(DealCard(
        item: _makeItem(),
        loading: true,
        onTap: () => taps++,
      )));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ShimmerBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // No deal text may render in loading state
      expect(find.text('Weekend in Sharm'), findsNothing);
      expect(find.textContaining('USD'), findsNothing);
      await tester.tap(find.byType(BaseCard));
      expect(taps, 0);
    });

    testWidgets('onTap callback fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(DealCard(
        item: _makeItem(),
        onTap: () => taps++,
      )));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(BaseCard));
      expect(taps, 1);
    });

    testWidgets('semantics label aggregates info', (tester) async {
      await tester.pumpWidget(_wrap(DealCard(item: _makeItem(
        metadata: {'savingsPercent': 20},
      ))));
      await tester.pump(const Duration(milliseconds: 300));

      final semantics = tester.getSemantics(find.byType(DealCard));
      expect(semantics.label, contains('Deal'));
      expect(semantics.label, contains('Weekend in Sharm'));
      expect(semantics.label, contains('Save 20%'));
    });

    testWidgets('long title ellipsizes without overflow', (tester) async {
      await tester.pumpWidget(_wrap(DealCard(item: _makeItem(
        title: 'An Extremely Long Deal Title That Should Ellipsize Gracefully In Place',
      ))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('large price renders without overflow', (tester) async {
      await tester.pumpWidget(_wrap(DealCard(item: _makeItem(
        price: 123456789,
      ))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark mode renders without errors', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: DealCard(item: _makeItem())),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(DealCard), findsOneWidget);
    });

    testWidgets('RTL layout renders without overflow', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(body: DealCard(item: _makeItem())),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });
}
