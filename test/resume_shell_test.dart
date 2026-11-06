import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/shell.dart';
import 'package:tokigo/app/widgets/resume_top_bar.dart';
import 'package:tokigo/core/navigation/resume_destination.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/app_back_button.dart';
import 'package:tokigo/features/groups/presentation/pages/groups_page.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The real shell over a tiny branch: the six service paths plus the two
/// standalone pages. '/' is a marker so a stray Home navigation is visible.
GoRouter _shellRouter({String initial = '/flights'}) {
  return GoRouter(
    initialLocation: initial,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) => TokiGoShell(
          navigationShell: navigationShell,
          location: state.uri,
        ),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
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
                      Scaffold(
                    body: path == '/groups'
                        ? const GroupsPage()
                        : Text('$path-page'),
                  ),
                ),
              GoRoute(
                path: '/profile',
                builder: (BuildContext context, GoRouterState state) =>
                    const Scaffold(body: Text('profile-page')),
              ),
              GoRoute(
                path: '/wishlist',
                builder: (BuildContext context, GoRouterState state) =>
                    const Scaffold(body: Text('wishlist-page')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Pumps [router] under the same chrome the app uses (theme + localizations).
Future<void> _pump(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: AppTheme.light(),
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
}

void main() {
  testWidgets('pins the top bar on the six service paths only', (
    tester,
  ) async {
    final GoRouter router = _shellRouter();
    await _pump(tester, router);

    expect(find.byType(ResumeTopBar), findsOneWidget);

    // Profile and Wishlist are standalone: no bar, and never Home.
    router.go('/profile');
    await tester.pumpAndSettle();
    expect(find.byType(ResumeTopBar), findsNothing);
    expect(find.text('profile-page'), findsOneWidget);
    expect(find.text('home-page'), findsNothing);

    router.go('/wishlist');
    await tester.pumpAndSettle();
    expect(find.byType(ResumeTopBar), findsNothing);
    expect(find.text('wishlist-page'), findsOneWidget);
    expect(find.text('home-page'), findsNothing);

    // The six service paths all keep the bar.
    router.go('/groups');
    await tester.pumpAndSettle();
    expect(find.byType(ResumeTopBar), findsOneWidget);
    expect(find.text('home-page'), findsNothing);
  });

  testWidgets('Groups shows no back button under the top bar', (
    tester,
  ) async {
    final GoRouter router = _shellRouter(initial: '/groups');
    await _pump(tester, router);

    expect(find.byType(ResumeTopBar), findsOneWidget);
    expect(find.byType(AppBackButton), findsNothing);
    expect(find.text('home-page'), findsNothing);
  });

  testWidgets('a pushed Groups keeps its header and back button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const ResumeTopBarScope(
            visible: false,
            child: GroupsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBackButton), findsOneWidget);
  });

  testWidgets('the shell strips the top inset only under the bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.resetPadding);

    final GoRouter router = _shellRouter();
    await _pump(tester, router);

    // Under the bar: the bar owns the status-bar inset.
    expect(
      MediaQuery.of(tester.element(find.text('/flights-page'))).padding.top,
      0,
    );

    // Standalone: the page keeps its own inset, so its SafeArea still clears
    // the status bar.
    router.go('/profile');
    await tester.pumpAndSettle();
    expect(
      MediaQuery.of(tester.element(find.text('profile-page'))).padding.top,
      24,
    );
  });
}
