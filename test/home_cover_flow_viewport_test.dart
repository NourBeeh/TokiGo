import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/features/home/presentation/widgets/destination_cover_flow_carousel.dart';
import 'package:tokigo/features/home/presentation/widgets/home_discovery_stay_card.dart';

/// Focused contract for the Discover cover-flow rail.
///
/// The rail must show ONE full 90 %-wide focal card inside the viewport, with
/// the neighbouring city peeking at the trailing edge — and the loading
/// skeleton must occupy exactly the same box.
void main() {
  const Size phone = Size(720, 1480); // 360 x 740 logical

  void phoneSize(WidgetTester tester, {Size size = phone}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  List<HomeItem> cities() => <HomeItem>[
        for (int i = 0; i < 4; i++)
          HomeItem(
            id: 'city-$i',
            type: HomeCardType.destination,
            title: 'City $i',
            subtitle: 'Country $i',
            metadata: <String, dynamic>{'country': 'Country $i'},
          ),
      ];

  Widget host(Widget child, {TextDirection direction = TextDirection.ltr}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Directionality(textDirection: direction, child: child),
        ),
      ),
    );
  }

  Rect viewportRect(WidgetTester tester) => tester.getRect(find.byType(PageView));

  /// The cover-flow rail's own box: the PageView viewport.
  Rect railRect(WidgetTester tester) => viewportRect(tester);

  group('focal card positioning', () {
    testWidgets('the initial card sits inside the viewport, flush and unclipped', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(
        host(
          DestinationCoverFlowCarousel(
            items: cities(),
            onItemTap: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final Rect viewport = viewportRect(tester);
      final Rect focal = tester.getRect(find.byType(HomeDiscoveryStayCard).at(0));

      // 90 % page, exactly as the design token says.
      expect(focal.width, closeTo(viewport.width * 0.9, 0.5));
      expect(focal.height, closeTo(viewport.height, 0.5));
      // No half-page pivot shift: the card hugs the rail's leading edge and
      // the top of the rail.
      expect(focal.left, closeTo(viewport.left, 0.5));
      expect(focal.top, closeTo(viewport.top, 0.5));
      // Fully inside — nothing clipped.
      expect(focal.right, lessThanOrEqualTo(viewport.right + 0.5));
      expect(focal.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the pager uses the intended 0.9 viewport fraction', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(
        host(
          DestinationCoverFlowCarousel(
            items: cities(),
            onItemTap: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final PageController controller =
          tester.widget<PageView>(find.byType(PageView)).controller!;
      expect(controller.viewportFraction, 0.9);
      expect(
        HomeCardDimensions.destinationViewportFraction,
        controller.viewportFraction,
      );
    });
  });

  group('adjacent cards stay visible', () {
    testWidgets('the next city peeks at the trailing edge', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(
        host(
          DestinationCoverFlowCarousel(
            items: cities(),
            onItemTap: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final Rect viewport = viewportRect(tester);
      final Rect focal = tester.getRect(find.byType(HomeDiscoveryStayCard).at(0));
      final Rect next = tester.getRect(find.byType(HomeDiscoveryStayCard).at(1));

      // Partially visible: it crosses the viewport's trailing edge but is not
      // fully on screen.
      final double visible = next.intersect(viewport).width;
      expect(visible, greaterThan(0));
      expect(visible, lessThan(next.width));
      // Its inner edge sits flush against the focal card's trailing edge (a
      // pixel or two of overlap is the rotated bounding box, not a gap).
      expect(next.left, closeTo(focal.right, 3));
      // The 3D scale is preserved: the neighbour is smaller than the focal
      // card, so it reads as depth rather than a second full card.
      expect(next.width, lessThan(focal.width));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a swipe keeps the newly focused card inside the viewport', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(
        host(
          DestinationCoverFlowCarousel(
            items: cities(),
            onItemTap: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(PageView), const Offset(-320, 0));
      await tester.pumpAndSettle();

      final Rect viewport = viewportRect(tester);
      final Finder cards = find.byType(HomeDiscoveryStayCard);
      final List<Rect> rects = <Rect>[
        for (int i = 0; i < cards.evaluate().length; i++)
          tester.getRect(cards.at(i)),
      ];
      // Exactly one card is the settled focal card: fully inside the viewport
      // at the rail's full 90 % width.
      final Iterable<Rect> inside = rects.where(
        (Rect r) =>
            r.left >= viewport.left - 0.5 &&
            r.right <= viewport.right + 0.5 &&
            r.top >= viewport.top - 0.5 &&
            r.bottom <= viewport.bottom + 0.5,
      );
      expect(inside, isNotEmpty);
      expect(inside.first.width, closeTo(viewport.width * 0.9, 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('loading and loaded geometry stay in sync', () {
    testWidgets('the skeleton page matches the loaded focal card box', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);

      await tester.pumpWidget(
        host(
          DestinationCoverFlowCarousel(
            items: cities(),
            onItemTap: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final Rect loaded = tester.getRect(find.byType(HomeDiscoveryStayCard).at(0));

      await tester.pumpWidget(
        host(
          DestinationCoverFlowCarousel(
            items: const <HomeItem>[],
            onItemTap: null,
            loading: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final Rect skeleton = tester.getRect(find.byType(HomeDiscoveryStayCard));

      expect(skeleton.size, loaded.size);
      expect(skeleton.topLeft, loaded.topLeft);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the skeleton is also inside the viewport', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(
        host(
          DestinationCoverFlowCarousel(
            items: const <HomeItem>[],
            onItemTap: null,
            loading: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final Rect viewport = viewportRect(tester);
      final Rect skeleton = tester.getRect(find.byType(HomeDiscoveryStayCard));
      expect(skeleton.left, closeTo(viewport.left, 0.5));
      expect(skeleton.top, closeTo(viewport.top, 0.5));
      expect(skeleton.right, lessThanOrEqualTo(viewport.right + 0.5));
      expect(skeleton.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
      expect(tester.takeException(), isNull);
    });
  });

  group('RTL and narrow widths', () {
    testWidgets('RTL keeps the focal card inside the viewport', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(
        host(
          DestinationCoverFlowCarousel(
            items: cities(),
            onItemTap: (_) {},
          ),
          direction: TextDirection.rtl,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final Rect viewport = viewportRect(tester);
      final Rect focal = tester.getRect(find.byType(HomeDiscoveryStayCard).at(0));

      expect(focal.width, closeTo(viewport.width * 0.9, 0.5));
      expect(focal.right, closeTo(viewport.right, 0.5));
      expect(focal.top, closeTo(viewport.top, 0.5));
      expect(focal.left, greaterThanOrEqualTo(viewport.left - 0.5));
      expect(focal.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));

      // The neighbour peeks from the LEADING (left) edge in RTL.
      final Rect neighbour = tester.getRect(
        find.byType(HomeDiscoveryStayCard).at(1),
      );
      expect(neighbour.intersect(viewport).width, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 320pt phone keeps the 90 % card inside the viewport', (
      WidgetTester tester,
    ) async {
      phoneSize(tester, size: const Size(640, 1280));
      await tester.pumpWidget(
        host(
          DestinationCoverFlowCarousel(
            items: cities(),
            onItemTap: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final Rect viewport = viewportRect(tester);
      final Rect focal = tester.getRect(find.byType(HomeDiscoveryStayCard).at(0));

      expect(viewport.width, 320);
      expect(focal.width, closeTo(288, 0.5));
      expect(focal.left, closeTo(viewport.left, 0.5));
      expect(focal.right, lessThanOrEqualTo(viewport.right + 0.5));
      expect(
        tester.getRect(find.byType(HomeDiscoveryStayCard).at(1)).intersect(
              viewport,
            ).width,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the reduced-motion fallback also shows a 90 % page', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      // Force the reduced-motion branch (no 3D transforms) through the
      // platform flag the widget actually reads.
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(
        host(
          DestinationCoverFlowCarousel(
            items: cities(),
            onItemTap: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final Rect viewport = viewportRect(tester);
      final Rect focal = tester.getRect(find.byType(HomeDiscoveryStayCard).at(0));
      expect(focal.width, closeTo(viewport.width * 0.9, 0.5));
      expect(focal.left, closeTo(viewport.left, 0.5));
      expect(focal.right, lessThanOrEqualTo(viewport.right + 0.5));
      expect(tester.takeException(), isNull);
    });
  });

  group('rail box', () {
    testWidgets('the rail height is unchanged by the fix', (
      WidgetTester tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(
        host(
          DestinationCoverFlowCarousel(
            items: cities(),
            onItemTap: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final Rect viewport = viewportRect(tester);
      // pageWidth / mediaAspectRatio — the same formula the widget uses.
      final double expected =
          viewport.width * 0.9 / HomeCardDimensions.destinationMediaAspectRatio;
      expect(viewport.height, closeTo(expected, 0.5));
      expect(railRect(tester).height, closeTo(expected, 0.5));
    });
  });
}
