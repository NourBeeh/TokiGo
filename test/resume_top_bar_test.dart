import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/config/app_config.dart';
import 'package:tokigo/app/providers/resume_providers.dart';
import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/app/widgets/resume_top_bar.dart';
import 'package:tokigo/core/navigation/resume_destination.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/presentation/widgets/home_top_bar.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Builds a thin shell whose providers can be overridden per test.
Widget _app(
  Widget child, {
  String? resumeDestination,
  String currentPath = '/',
  ThemeMode themeMode = ThemeMode.light,
}) {
  return ProviderScope(
    overrides: <Override>[
      resumeDestinationProvider.overrideWith((ref) => resumeDestination),
      currentLocationProvider.overrideWith((ref) => currentPath),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    ),
  );
}

/// A router whose service pages host the real [ResumeTopBar], so the bar's
/// tap behaviour is exercised end to end. '/' is a plain marker page: the
/// tests assert it is never built.
GoRouter _serviceRouter({String initial = '/flights'}) {
  return GoRouter(
    initialLocation: initial,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('home-page')),
      ),
      for (final String path in kTopBarPaths)
        GoRoute(
          path: path,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: ResumeTopBar()),
        ),
    ],
  );
}

/// Hosts [router] under the same chrome the app uses (theme + localizations).
Widget _routerApp(GoRouter router) {
  return ProviderScope(
    child: MaterialApp.router(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  group('ResumeButton', () {
    testWidgets('renders the Flights fallback when nothing was saved', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const ResumeButton()));
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold)),
      )!;

      expect(find.byType(ResumeButton), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.searchFlights), findsOneWidget);
    });

    testWidgets('shows the saved destination and is not selected elsewhere', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _app(const ResumeButton(), resumeDestination: '/hotels', currentPath: '/flights'),
      );
      await tester.pumpAndSettle();
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold)),
      )!;
      expect(find.bySemanticsLabel(l10n.searchHotels), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey<String>('home-resume-button')))
            .hasFlag(SemanticsFlag.isSelected),
        isFalse,
      );
      handle.dispose();
    });

    testWidgets('is selected while already on the saved destination', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _app(const ResumeButton(), resumeDestination: '/flights', currentPath: '/flights'),
      );
      await tester.pumpAndSettle();
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold)),
      )!;
      expect(find.bySemanticsLabel(l10n.searchFlights), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey<String>('home-resume-button')))
            .hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('falls back to Flights for a stale saved path', (tester) async {
      await tester.pumpWidget(
        _app(const ResumeButton(), resumeDestination: 'flights', currentPath: '/flights'),
      );
      await tester.pumpAndSettle();
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold)),
      )!;
      expect(find.bySemanticsLabel(l10n.searchFlights), findsOneWidget);
    });

    testWidgets('is at least a 44dp tap target', (tester) async {
      await tester.pumpWidget(_app(const ResumeButton()));
      expect(
        tester.getSize(find.byType(ResumeButton)).height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('ResumeTopBar', () {
    testWidgets('pins the header row and the quick-action row only', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const ResumeTopBar()));

      expect(find.byType(HomeTopBar), findsOneWidget);
      expect(find.byType(HomeActionBar), findsOneWidget);
      // Unpinned (AppConfig.showResumeButton == false): the bar must not draw
      // it, and must not reserve any height for it either.
      expect(find.byType(ResumeButton), findsNothing);
      expect(AppConfig.showResumeButton, isFalse);
      // The bar paints its own canvas so the page below never shows through.
      expect(
        find.descendant(
          of: find.byType(ResumeTopBar),
          matching: find.byType(ColoredBox),
        ),
        findsOneWidget,
      );
    });

    testWidgets('keeps the same height in light and dark', (tester) async {
      // The bar is exactly its two rows plus their own padding — nothing is
      // reserved for the unpinned button.
      double expectedHeight(WidgetTester tester) {
        return AppSpacing.xs +
            tester.getSize(find.byType(HomeTopBar)).height +
            AppSpacing.md +
            tester.getSize(find.byType(HomeActionBar)).height +
            AppSpacing.md;
      }

      await tester.pumpWidget(_app(const ResumeTopBar()));
      final double light = tester.getSize(find.byType(ResumeTopBar)).height;
      expect(light, expectedHeight(tester));

      await tester.pumpWidget(
        _app(const ResumeTopBar(), themeMode: ThemeMode.dark),
      );
      expect(tester.getSize(find.byType(ResumeTopBar)).height, light);
    });

    testWidgets('leaves no gap where the button used to be', (tester) async {
      await tester.pumpWidget(_app(const ResumeTopBar()));

      // The action row runs to the trailing gutter: nothing is reserved for an
      // unpinned button, so the bar ends with the quick-action row.
      final Rect bar = tester.getRect(find.byType(ResumeTopBar));
      final Rect actions = tester.getRect(find.byType(HomeActionBar));
      expect(actions.bottom, lessThan(bar.bottom));
      expect(
        bar.bottom - actions.bottom,
        AppSpacing.md,
        reason: 'only the action row\'s own bottom padding follows it',
      );
    });
  });

  group('ResumeButton (unpinned, kept reusable)', () {
    testWidgets('tapping it returns to the saved destination', (tester) async {
      final GoRouter router = GoRouter(
        initialLocation: '/resume',
        routes: <RouteBase>[
          GoRoute(
            path: '/flights',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('flights-page')),
          ),
          GoRoute(
            path: '/hotels',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('hotels-page')),
          ),
          GoRoute(
            path: '/resume',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: ResumeButton()),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            resumeDestinationProvider.overrideWith((ref) => '/flights'),
            currentLocationProvider.overrideWith((ref) => '/resume'),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('hotels-page'), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('home-resume-button')));
      await tester.pumpAndSettle();
      expect(find.text('flights-page'), findsOneWidget);
    });
  });

  group('ResumeTopBar navigation', () {
    testWidgets('re-tapping the active service is a no-op and never opens Home', (
      tester,
    ) async {
      final GoRouter router = _serviceRouter();
      await tester.pumpWidget(_routerApp(router));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/flights');
      expect(find.text('home-page'), findsNothing);

      // Tapping the already-active tile must not navigate at all — no go, no
      // push, no rebuild — and must never fall back to Home.
      await tester.tap(find.byKey(const ValueKey<String>('home-action-flights')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/flights');
      expect(find.text('home-page'), findsNothing);

      // A different service switches the page.
      await tester.tap(find.byKey(const ValueKey<String>('home-action-hotels')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/hotels');
      expect(find.text('home-page'), findsNothing);

      // The new page is now the active one, so its tile is a no-op too.
      await tester.tap(find.byKey(const ValueKey<String>('home-action-hotels')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/hotels');
      expect(find.text('home-page'), findsNothing);
    });

    testWidgets('marks the current service as selected', (tester) async {
      final GoRouter router = _serviceRouter();
      await tester.pumpWidget(_routerApp(router));
      await tester.pumpAndSettle();

      HomeActionTile tile(String key) => tester.widget<HomeActionTile>(
        find.ancestor(
          of: find.byKey(ValueKey<String>(key)),
          matching: find.byType(HomeActionTile),
        ),
      );

      expect(
        tile('home-action-flights').selected,
        isTrue,
        reason: 'the current service tile is selected',
      );
      expect(tile('home-action-hotels').selected, isFalse);

      await tester.tap(find.byKey(const ValueKey<String>('home-action-hotels')));
      await tester.pumpAndSettle();

      expect(tile('home-action-hotels').selected, isTrue);
      expect(tile('home-action-flights').selected, isFalse);
    });

    testWidgets('a top-level service page cannot pop (system Back exits)', (
      tester,
    ) async {
      final GoRouter router = _serviceRouter();
      await tester.pumpWidget(_routerApp(router));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/flights');
      expect(router.canPop(), isFalse);

      // Switching services replaces the root, so Back still has nowhere to go.
      await tester.tap(find.byKey(const ValueKey<String>('home-action-cars')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/cars');
      expect(router.canPop(), isFalse);
    });
  });
}
