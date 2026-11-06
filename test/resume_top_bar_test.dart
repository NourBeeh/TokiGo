import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/providers/resume_providers.dart';
import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/app/widgets/resume_top_bar.dart';
import 'package:tokigo/core/navigation/resume_destination.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Builds a thin shell whose providers can be overridden per test.
Widget _app(Widget child, {String? resumeDestination, String currentPath = '/'}) {
  return ProviderScope(
    overrides: <Override>[
      resumeDestinationProvider.overrideWith((ref) => resumeDestination),
      currentLocationProvider.overrideWith((ref) => currentPath),
    ],
    child: MaterialApp(
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
    testWidgets('pins the quick-action row next to the resume button', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const ResumeTopBar()));

      expect(find.byType(HomeActionBar), findsOneWidget);
      expect(find.byType(ResumeButton), findsOneWidget);
      // The bar paints its own canvas so the page below never shows through.
      expect(
        find.descendant(
          of: find.byType(ResumeTopBar),
          matching: find.byType(ColoredBox),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping the resume button returns to the saved destination', (
      tester,
    ) async {
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
            builder: (BuildContext context, GoRouterState state) => const Scaffold(
              body: ResumeTopBar(),
            ),
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
}
