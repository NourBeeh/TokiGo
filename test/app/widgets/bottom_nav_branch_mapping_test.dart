import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/shell.dart';
import 'package:tokigo/app/widgets/app_bottom_nav.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// NAV regression coverage (2026-09-07): the floating bottom navigation pill
/// is RETIRED — the shell hosts the navigation stack only. The historical
/// four-tab tests are superseded by this suite:
/// - the shell renders NO AppBottomNav anywhere (branch roots included);
/// - the retired `AppBottomNavDestination` enum is kept intact (no-deletion
///   rule) so any future consumer finds it unchanged;
/// - former tab pages now live as pushed routes on the Home branch.
void main() {
  testWidgets('shell renders without the bottom nav pill on branch roots',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => TokiGoShell(
            navigationShell: navigationShell,
            location: state.uri,
          ),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  path: '/',
                  builder: (_, __) => const _BranchLabel('HOME'),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
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
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('HOME'), findsOneWidget);
    // NAV: the pill never renders anymore.
    expect(find.byType(AppBottomNav), findsNothing);
  });

  testWidgets('former tab pages are pushable routes on the Home branch',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => TokiGoShell(
            navigationShell: navigationShell,
            location: state.uri,
          ),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  path: '/',
                  builder: (_, __) => const _BranchLabel('HOME'),
                  routes: <GoRoute>[
                    GoRoute(
                      path: 'groups',
                      builder: (_, __) => const _BranchLabel('GROUPS'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
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
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('HOME'), findsOneWidget);

    // Groups is now a pushed route on the Home branch (NAV).
    router.push('/groups');
    // Two pumps: one to start the fade-through transition, one to land it.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('GROUPS'), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);
  });

  test('retired AppBottomNavDestination enum stays intact (no-deletion rule)',
      () {
    // The historical four-destination vocabulary is preserved for any
    // future consumer; nothing consumes it in the shell anymore.
    expect(AppBottomNavDestination.values.length, 4);
    expect(AppBottomNavDestination.values, containsAll(<AppBottomNavDestination>[
      AppBottomNavDestination.home,
      AppBottomNavDestination.search,
      AppBottomNavDestination.groups,
      AppBottomNavDestination.explore,
    ]));
  });
}

class _BranchLabel extends StatelessWidget {
  const _BranchLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(label, textDirection: TextDirection.ltr),
      );
}
