import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/widgets/cover_flow_carousel.dart';
import 'package:tokigo/features/home/presentation/widgets/home_section.dart';

/// Every Home card rail shares ONE 3D cover-flow implementation (owner
/// decision, 2026-11): the Discover rail, the stay rail, the flight rail and
/// the mixed car/package/deal rail must all run [CoverFlowCarousel] with the
/// same mechanics — a centred focal page, neighbours peeking, a 3D tilt.
HomeItem _car(String id) => HomeItem(
      id: id,
      type: HomeCardType.car,
      title: 'Car $id',
      subtitle: 'Cairo',
      price: 120,
      currency: 'USD',
    );

HomeItem _flight(String id) => HomeItem(
      id: id,
      type: HomeCardType.flight,
      title: 'Flight $id',
      subtitle: 'CAI → RUH',
      price: 480,
      currency: 'USD',
    );

Widget _host(HomeSection section) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: HomeSectionWidget(section: section)),
        ),
      ),
    );

void main() {
  testWidgets('a car rail runs the shared 3D cover flow', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        HomeSection(
          id: 'cars',
          title: 'Cars',
          layout: HomeSectionLayout.horizontal,
          items: <HomeItem>[_car('a'), _car('b'), _car('c')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The rail is the SHARED cover-flow pager, not a bare PageView.
    expect(find.byType(CoverFlowCarousel), findsOneWidget);
    final PageView pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.scrollDirection, Axis.horizontal);
    expect(pageView.padEnds, isTrue, reason: 'the focal card is centred');

    // The focal card sits at the START of the rail (the page gutter), with the
    // next card peeking at the trailing edge — the same leading-aligned
    // presentation the mixed rail always had, now driven by the shared
    // cover-flow pager instead of a bare PageView.
    final Rect viewport = tester.getRect(find.byType(PageView));
    final Rect first = tester.getRect(find.text('Car a'));
    final Rect next = tester.getRect(find.text('Car b'));
    expect(first.left, greaterThanOrEqualTo(viewport.left));
    expect(next.left, greaterThan(first.right - 1));
    expect(next.intersect(viewport).width, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a flight rail runs the shared 3D cover flow', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        HomeSection(
          id: 'flights',
          title: 'Flights',
          layout: HomeSectionLayout.horizontal,
          items: <HomeItem>[_flight('a'), _flight('b')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CoverFlowCarousel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping a mixed rail advances exactly one card', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        HomeSection(
          id: 'cars',
          title: 'Cars',
          layout: HomeSectionLayout.horizontal,
          items: <HomeItem>[_car('a'), _car('b'), _car('c')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final PageView pageView = tester.widget<PageView>(find.byType(PageView));
    final double pageExtent =
        pageView.controller!.position.viewportDimension * 0.8;
    await tester.drag(find.byType(PageView), Offset(-pageExtent, 0));
    await tester.pumpAndSettle();

    expect(pageView.controller!.page, closeTo(1.0, 0.1));
    expect(tester.takeException(), isNull);
  });
}
