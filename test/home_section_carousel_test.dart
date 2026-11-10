import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/widgets/destination_cover_flow_carousel.dart';
import 'package:tokigo/features/home/presentation/widgets/home_discovery_stay_card.dart';
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

    await tester.drag(find.byType(PageView), Offset(-pageExtent, 0));
    await tester.pumpAndSettle();

    expect(pageView.controller?.page, closeTo(1.0, 0.1));
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
    // Owner decision (2026-11): the stay rail shares the Discover rail's
    // centred cover flow, so the focal card is centred and the next card's
    // inner edge sits flush against it.
    expect(firstCard.center.dx, closeTo(viewport.center.dx, 1));
    expect(firstCard.width, closeTo(viewport.width * 0.8, 1));
    expect(nextCard.left, closeTo(firstCard.right, 1));
    expect(nextCard.intersect(viewport).width, greaterThan(0));
    expect(firstCard.width, greaterThan(300));
    expect(tester.takeException(), isNull);
  });

  // ─── Destination cover flow ────────────────────────────────────────────────

  Widget _coverFlowHost({TextDirection direction = TextDirection.ltr}) {
    return ProviderScope(
      child: MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
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
        ),
      ),
    );
  }

  testWidgets('destination cover flow renders one page per destination',
      (WidgetTester tester) async {
    await tester.pumpWidget(_coverFlowHost());
    await tester.pumpAndSettle();

    expect(find.byType(DestinationCoverFlowCarousel), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('destination cover flow handles a single item without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
              body: SingleChildScrollView(
                child: HomeSectionWidget(
                  section: HomeSection(
                    id: 'destinations',
                    title: 'Destinations',
                    layout: HomeSectionLayout.horizontal,
                    items: <HomeItem>[
                      _destination('cairo', 'Cairo'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(DestinationCoverFlowCarousel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('destination cover flow respects RTL layout', (WidgetTester tester) async {
    await tester.pumpWidget(_coverFlowHost(direction: TextDirection.rtl));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    // The viewport should be constrained to the rail width.
    final Rect viewport = tester.getRect(find.byType(PageView));
    expect(viewport.width, greaterThan(100.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'the Home rail card opens the city page even without a host action',
      (WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(
                body: SingleChildScrollView(
                  child: HomeSectionWidget(
                    section: HomeSection(
                      id: 'destinations',
                      title: 'Discover',
                      layout: HomeSectionLayout.grid,
                      items: <HomeItem>[
                        HomeItem(
                          id: 'paris',
                          type: HomeCardType.destination,
                          title: 'Paris',
                          subtitle: 'France',
                        ),
                        HomeItem(
                          id: 'london',
                          type: HomeCardType.destination,
                          title: 'London',
                          subtitle: 'United Kingdom',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ),
        GoRoute(
          path: '/city',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Text(
              'City opened: ${(state.extra as HomeItem).title}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();

    // No `onItemTap` is supplied — Home's own feed passes none — so the card
    // must still open its city page.
    expect(find.byType(HomeDiscoveryStayCard), findsWidgets);
    await tester.tap(find.byType(HomeDiscoveryStayCard).first);
    await tester.pumpAndSettle();

    expect(find.text('City opened: Paris'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('destination card tap opens the city page', (WidgetTester tester) async {
    String? openedCity;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
              body: SingleChildScrollView(
                child: HomeSectionWidget(
                  section: HomeSection(
                    id: 'destinations',
                    title: 'Destinations',
                    layout: HomeSectionLayout.horizontal,
                    items: <HomeItem>[
                      _destination('cairo', 'Cairo'),
                      _destination('alexandria', 'Alexandria'),
                    ],
                  ),
                  onItemTap: (HomeItem item) {
                    openedCity = item.title;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The focal card is the leading page; with the 90 % viewport the next
    // city peeks in too, so target the focal one explicitly.
    final Finder cityCard = find.byType(HomeDiscoveryStayCard).first;
    expect(find.byType(HomeDiscoveryStayCard), findsWidgets);
    await tester.tap(cityCard);
    await tester.pumpAndSettle();

    expect(openedCity, 'Cairo');
    expect(tester.takeException(), isNull);
  });
}
