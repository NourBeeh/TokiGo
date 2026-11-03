import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stay_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_section.dart';

HomeItem _destination(String id, String title) => HomeItem(
  id: id,
  type: HomeCardType.destination,
  title: title,
  subtitle: 'Egypt',
);

HomeItem _stay(String id) => HomeItem(
  id: id,
  type: HomeCardType.hotel,
  title: 'Stay $id',
  subtitle: 'Cairo',
  price: 250,
  currency: 'USD',
  rating: 4.5,
  metadata: const <String, dynamic>{'city': 'Cairo'},
);

Widget _host() => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: HomeSectionWidget(
        section: HomeSection(
          id: 'destinations',
          title: 'Destinations',
          layout: HomeSectionLayout.horizontal,
          items: <HomeItem>[
            _destination('cairo', 'Cairo'),
            _destination('alexandria', 'Alexandria'),
            _destination('luxor', 'Luxor'),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('horizontal sections snap to exactly one card per swipe', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final PageView pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.scrollDirection, Axis.horizontal);

    final Finder scrollableFinder = find.descendant(
      of: find.byType(PageView),
      matching: find.byType(Scrollable),
    );
    final ScrollableState scrollable = tester.state<ScrollableState>(
      scrollableFinder,
    );
    final double pageExtent = scrollable.position.viewportDimension * 0.8;

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, closeTo(pageExtent, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home hotel sections use the wide stay-card carousel', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeSectionWidget(
                section: HomeSection(
                  id: 'stays',
                  title: 'Stays',
                  layout: HomeSectionLayout.horizontal,
                  items: <HomeItem>[_stay('one'), _stay('two')],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect viewport = tester.getRect(find.byType(PageView));
    final Rect firstCard = tester.getRect(find.byType(HomeStayCard).first);
    final Rect nextCard = tester.getRect(find.byType(HomeStayCard).last);
    expect(firstCard.width, closeTo(viewport.width * 0.8 - 12, 1));
    expect(nextCard.left - firstCard.right, closeTo(12, 1));
    expect(
      nextCard.intersect(viewport).width,
      closeTo(viewport.width * 0.2, 1),
    );
    expect(firstCard.width, greaterThan(300));
    expect(tester.takeException(), isNull);
  });
}
