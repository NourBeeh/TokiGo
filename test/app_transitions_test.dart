import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tokigo/core/navigation/app_transitions.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = null);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('directional horizontal offsets', () {
    testWidgets('LTR enters from the physical right edge', (tester) async {
      late Offset offset;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              offset = horizontalPageEnterOffset(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(offset, const Offset(1, 0));
      expect(offset.dy, 0);
    });

    testWidgets('RTL enters from the physical left edge', (tester) async {
      late Offset offset;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (context) {
              offset = horizontalPageEnterOffset(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(offset, const Offset(-1, 0));
      expect(offset.dy, 0);
    });

    testWidgets('transition never applies vertical movement', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 1),
      );
      addTearDown(controller.dispose);

      for (final TextDirection direction in TextDirection.values) {
        controller.value = 0;
        await tester.pumpWidget(
          Directionality(
            textDirection: direction,
            child: HorizontalPageTransition(
              animation: controller,
              secondaryAnimation: controller,
              child: const SizedBox.expand(),
            ),
          ),
        );

        final Iterable<FractionalTranslation> translations = tester
            .widgetList<FractionalTranslation>(
              find.byType(FractionalTranslation),
            );
        expect(translations, isNotEmpty);
        for (final FractionalTranslation translation in translations) {
          expect(translation.translation.dy, 0);
        }
      }
    });
  });

  group('horizontal transition geometry', () {
    // Returns the two fractional translations applied by
    // [HorizontalPageTransition]: index 0 is the page underneath (secondary),
    // index 1 is the page being pushed/popped (primary).
    Future<List<Offset>> sample(
      WidgetTester tester, {
      required TextDirection direction,
      required double t,
    }) async {
      final AnimationController primary = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 1000),
        value: t,
      );
      final AnimationController secondary = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 1000),
        value: t,
      );
      addTearDown(primary.dispose);
      addTearDown(secondary.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: HorizontalPageTransition(
            animation: primary,
            secondaryAnimation: secondary,
            child: const SizedBox.expand(),
          ),
        ),
      );

      return tester
          .widgetList<FractionalTranslation>(
            find.byType(FractionalTranslation),
          )
          .map((FractionalTranslation widget) => widget.translation)
          .toList();
    }

    testWidgets('LTR enters from the right and exits to the right', (
      tester,
    ) async {
      final List<Offset> start = await sample(
        tester,
        direction: TextDirection.ltr,
        t: 0,
      );
      expect(start[1], const Offset(1, 0));
      expect(start[0], Offset.zero);

      final List<Offset> midway = await sample(
        tester,
        direction: TextDirection.ltr,
        t: 0.5,
      );
      expect(midway[1].dx, greaterThan(0));
      expect(midway[0].dx, lessThan(0));
      expect(midway[1].dy, 0);
      expect(midway[0].dy, 0);

      final List<Offset> end = await sample(
        tester,
        direction: TextDirection.ltr,
        t: 1,
      );
      expect(end[1], Offset.zero);
      expect(end[0].dx, closeTo(-1 / 3, 1e-9));
      expect(end[0].dy, 0);
    });

    testWidgets('RTL enters from the left and exits to the left', (
      tester,
    ) async {
      final List<Offset> start = await sample(
        tester,
        direction: TextDirection.rtl,
        t: 0,
      );
      expect(start[1], const Offset(-1, 0));
      expect(start[0], Offset.zero);

      final List<Offset> midway = await sample(
        tester,
        direction: TextDirection.rtl,
        t: 0.5,
      );
      expect(midway[1].dx, lessThan(0));
      expect(midway[0].dx, greaterThan(0));
      expect(midway[1].dy, 0);
      expect(midway[0].dy, 0);

      final List<Offset> end = await sample(
        tester,
        direction: TextDirection.rtl,
        t: 1,
      );
      expect(end[1], Offset.zero);
      expect(end[0].dx, closeTo(1 / 3, 1e-9));
      expect(end[0].dy, 0);
    });
  });

  group('iOS page route', () {
    testWidgets('keeps its key, name, arguments and restoration id', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        const key = ValueKey<String>('second');
        final page = slideFromRightPage(
          key: key,
          name: 'second',
          arguments: <String, Object?>{'id': 7},
          restorationId: 'second',
          child: const SizedBox.shrink(),
        );

        expect(page, isA<CupertinoSlideFromRightPage>());
        expect(page.key, key);
        expect(page.name, 'second');
        expect(page.arguments, <String, Object?>{'id': 7});
        expect(page.restorationId, 'second');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('page-based route uses the Page as its RouteSettings', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final page = CupertinoSlideFromRightPage(
          key: const ValueKey<String>('second'),
          name: 'second',
          child: const Text('second'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Navigator(
              pages: <Page<void>>[page],
              onDidRemovePage: (Page<Object?> _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // This is the regression guard for the iOS back-swipe freeze:
        // GoRouter/Navigator read `route.settings as Page` when the gesture
        // completes. A null/mismatched settings value made that cast fail and
        // left the route stuck mid-drag.
        final ModalRoute<dynamic>? route = ModalRoute.of(
          tester.element(find.text('second')),
        );
        expect(route, isNotNull);
        expect(route!.settings, same(page));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('iOS interactive back-swipe', () {
    testWidgets('slow completed swipe pops exactly once', (tester) async {
      await _withIOSRouter(tester, (router) async {
        await _pushSecond(tester, router);

        final gesture = await tester.startGesture(const Offset(2, 300));
        await gesture.moveBy(const Offset(450, 0));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
        expect(find.text('second'), findsNothing);
      });
    });

    testWidgets('fast fling pops', (tester) async {
      await _withIOSRouter(tester, (router) async {
        await _pushSecond(tester, router);

        await tester.flingFrom(
          const Offset(2, 300),
          const Offset(120, 0),
          1500,
        );
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
        expect(find.text('second'), findsNothing);
      });
    });

    testWidgets('cancelled partial swipe restores the current page', (
      tester,
    ) async {
      await _withIOSRouter(tester, (router) async {
        await _pushSecond(tester, router);

        final gesture = await tester.startGesture(const Offset(2, 300));
        await gesture.moveBy(const Offset(80, 0));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text('second'), findsOneWidget);
        expect(find.text('home'), findsNothing);
      });
    });

    testWidgets('repeated push/swipe cycles never freeze', (tester) async {
      await _withIOSRouter(tester, (router) async {
        for (int i = 0; i < 3; i += 1) {
          await _pushSecond(tester, router);

          final gesture = await tester.startGesture(const Offset(2, 300));
          await gesture.moveBy(const Offset(450, 0));
          await tester.pump(const Duration(milliseconds: 16));
          await gesture.up();
          await tester.pumpAndSettle();

          expect(find.text('home'), findsOneWidget);
          expect(find.text('second'), findsNothing);
        }
      });
    });

    testWidgets('RTL swipe starts at the right edge and pops', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final router = _buildRouter();
      try {
        await tester.pumpWidget(
          MaterialApp.router(
            locale: const Locale('ar'),
            supportedLocales: const <Locale>[Locale('ar')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        await _pushSecond(tester, router);

        final gesture = await tester.startGesture(const Offset(798, 300));
        await gesture.moveBy(const Offset(-450, 0));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
        expect(find.text('second'), findsNothing);
      } finally {
        router.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('nested shell branch swipes back correctly', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final router = _buildShellRouter();
      try {
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        router.push('/child');
        await tester.pumpAndSettle();
        router.push('/child/grandchild');
        await tester.pumpAndSettle();
        expect(find.text('grandchild'), findsOneWidget);

        // Pop the grandchild through the branch navigator's native gesture.
        final first = await tester.startGesture(const Offset(2, 300));
        await first.moveBy(const Offset(450, 0));
        await tester.pump(const Duration(milliseconds: 16));
        await first.up();
        await tester.pumpAndSettle();
        expect(find.text('child'), findsOneWidget);

        // And pop the child back to the shell root.
        final second = await tester.startGesture(const Offset(2, 300));
        await second.moveBy(const Offset(450, 0));
        await tester.pump(const Duration(milliseconds: 16));
        await second.up();
        await tester.pumpAndSettle();
        expect(find.text('home'), findsOneWidget);
      } finally {
        router.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('Android route + predictive back configuration', () {
    testWidgets('slideFromRightPage returns a MaterialPage with a unique key', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final first = slideFromRightPage(
          key: const ValueKey<String>('first'),
          name: 'first',
          child: const SizedBox.shrink(),
        );
        final second = slideFromRightPage(
          key: const ValueKey<String>('second'),
          name: 'second',
          child: const SizedBox.shrink(),
        );

        expect(first, isA<MaterialPage<void>>());
        expect(second, isA<MaterialPage<void>>());
        expect(first.key, isNot(equals(second.key)));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('theme keeps Android predictive back and iOS Cupertino', () {
      for (final ThemeData theme in <ThemeData>[
        AppTheme.light(),
        AppTheme.dark(),
      ]) {
        final builders = theme.pageTransitionsTheme.builders;
        expect(
          builders[TargetPlatform.android],
          isA<PredictiveBackPageTransitionsBuilder>(),
        );
        expect(
          builders[TargetPlatform.iOS],
          isA<CupertinoPageTransitionsBuilder>(),
        );
      }
    });

    testWidgets('system back pops exactly once', (tester) async {
      final router = _buildRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await _pushSecond(tester, router);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.text('second'), findsNothing);
    });
  });

  group('content entrance', () {
    testWidgets('AiEntranceAnimation adds no scale or corner motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: AiEntranceAnimation(child: Text('content'))),
      );

      expect(find.text('content'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AiEntranceAnimation),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });
  });
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => slideFromRightPage(
          key: state.pageKey,
          restorationId: state.pageKey.value,
          name: 'home',
          child: const Scaffold(body: Text('home')),
        ),
        routes: <RouteBase>[
          GoRoute(
            path: 'second',
            pageBuilder: (context, state) => slideFromRightPage(
              key: state.pageKey,
              restorationId: state.pageKey.value,
              name: 'second',
              child: const Scaffold(body: Text('second')),
            ),
          ),
        ],
      ),
    ],
  );
}

Future<void> _pushSecond(WidgetTester tester, GoRouter router) async {
  router.push('/second');
  await tester.pumpAndSettle();
  expect(find.text('second'), findsOneWidget);
}

GoRouter _buildShellRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            Scaffold(body: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                pageBuilder: (context, state) => slideFromRightPage(
                  key: state.pageKey,
                  restorationId: state.pageKey.value,
                  name: 'home',
                  child: const Scaffold(body: Text('home')),
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'child',
                    pageBuilder: (context, state) => slideFromRightPage(
                      key: state.pageKey,
                      restorationId: state.pageKey.value,
                      name: 'child',
                      child: const Scaffold(body: Text('child')),
                    ),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'grandchild',
                        pageBuilder: (context, state) => slideFromRightPage(
                          key: state.pageKey,
                          restorationId: state.pageKey.value,
                          name: 'grandchild',
                          child: const Scaffold(body: Text('grandchild')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Future<void> _withIOSRouter(
  WidgetTester tester,
  Future<void> Function(GoRouter router) body,
) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  final router = _buildRouter();
  try {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await body(router);
  } finally {
    router.dispose();
    debugDefaultTargetPlatformOverride = null;
  }
}
