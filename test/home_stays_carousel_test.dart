import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stay_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stays_carousel.dart';

/// Home's "Hotels recommended for you" rail (owner decision, 2026-10-25):
/// a SWIPE pager, one stay per page, snapped card by card.
///
/// What is pinned here:
/// * one page per stay, and the pager is horizontal (not a vertical stack);
/// * a swipe advances exactly ONE card and the pager lands on it — no free
///   scrolling that leaves two halves of two stays on screen;
/// * the same gesture works in Arabic (RTL), where "next" is a drag the other
///   way;
/// * a large text scale still renders the price (the rail grows with it).
///
/// Cards are keyed by stay id in the rail, so the tests can name the card they
/// mean instead of counting widgets.
HomeItem _stay(String id, String title) => HomeItem(
  id: id,
  type: HomeCardType.hotel,
  title: title,
  subtitle: 'Cairo',
  price: 291.01,
  currency: 'USD',
  rating: 4.1,
  reviewCount: 2934,
  metadata: const <String, dynamic>{'city': 'Cairo'},
);

List<HomeItem> _threeStays() => <HomeItem>[
  _stay('stay-a', 'Al Masa Hotel Nasr City'),
  _stay('stay-b', 'Steigenberger Hotel El Tahrir Cairo'),
  _stay('stay-c', 'Pickalbatros Royal Grand Sharm'),
];

Widget _host(
  List<HomeItem> items, {
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            // Same contract as Home: the rail lives inside the feed's
            // scrollable, so its height is unbounded from above.
            child: Scaffold(
              body: SingleChildScrollView(
                child: HomeStaysCarousel(items: items),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Finder _card(String id) => find.byKey(ValueKey<String>(id));

void main() {
  testWidgets('renders one page per stay, horizontally', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_threeStays()));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    // A PageView scrolls horizontally by definition; the old vertical stack
    // was a SliverList of full-width cards.
    final PageView pager = tester.widget<PageView>(find.byType(PageView));
    expect(pager.scrollDirection, Axis.horizontal);

    expect(find.byType(HomeStayCard), findsWidgets);
    expect(_card('stay-a'), findsOneWidget);
    expect(find.text('Al Masa Hotel Nasr City'), findsOneWidget);
  });

  testWidgets('a swipe advances exactly one card and snaps onto it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_threeStays()));
    await tester.pumpAndSettle();

    final double viewportCenter =
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2;

    // The first stay starts centred.
    expect(
      tester.getRect(_card('stay-a')).center.dx,
      closeTo(viewportCenter, 1),
    );

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // The SECOND stay is now the one that owns the centre: one swipe, one
    // card — no half-card resting position.
    expect(
      tester.getRect(_card('stay-b')).center.dx,
      closeTo(viewportCenter, 1),
    );
    expect(tester.getRect(_card('stay-a')).center.dx, lessThan(viewportCenter));
  });

  testWidgets('a swipe in Arabic moves the same way physically', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_threeStays(), direction: TextDirection.rtl));
    await tester.pumpAndSettle();

    // RTL reverses the scroll axis, so the first stay starts on the RIGHT and
    // the gesture that reveals the next one is a drag to the right.
    await tester.drag(find.byType(PageView), const Offset(400, 0));
    await tester.pumpAndSettle();

    final double viewportCenter =
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2;
    expect(
      tester.getRect(_card('stay-b')).center.dx,
      closeTo(viewportCenter, 1),
    );
  });

  testWidgets('a large text scale keeps the price on screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_threeStays(), textScale: 2));
    await tester.pumpAndSettle();

    // The rail's height is derived from the text scale, so the sheet must not
    // overflow and the provider's amount must still be readable.
    expect(tester.takeException(), isNull);
    expect(find.textContaining('291.01'), findsWidgets);
  });

  testWidgets('a single stay renders without a pager to swipe', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(<HomeItem>[_stay('solo', 'Solo Stay')]));
    await tester.pumpAndSettle();

    expect(find.byType(HomeStayCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
