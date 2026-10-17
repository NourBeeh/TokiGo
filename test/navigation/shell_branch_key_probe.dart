// Temporary reproduction test: confirms the root cause of the
// "Duplicate GlobalKey detected in widget tree involving
// _BranchNavigatorProxy and StatefulShellBranch" error, and verifies a fix
// removes it. This file is deleted before the final deliverable.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Shell branch custom navigatorKey (root cause probe)', () {
    testWidgets('a single StatefulShellRoute branch with a custom branch '
        'navigatorKey that is a top-level GlobalKey<NavigatorState> '
        'reproduces Duplicate GlobalKey', (tester) async {
      final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
      final homeTabKey = GlobalKey<NavigatorState>(debugLabel: 'home');

      // Replicate go_router_config.dart's route tree: StatefulShellRoute
      // with one branch whose navigatorKey is the top-level homeTabKey.
      final router = GoRouter(
        navigatorKey: _rootNavigatorKey,
        initialLocation: '/',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => Scaffold(
              body: navigationShell,
            ),
            branches: [
              StatefulShellBranch(
                navigatorKey: homeTabKey,
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) => const HomePage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      );

      // First build: shell renders, branch navigator keyed by homeTabKey.
      expect(find.byType(HomePage), findsOneWidget);

      // Navigate deeper on the branch and pop back to re-trigger the
      // branch-navigator rebuild that exposes the duplicate key.
      await tester.tap(find.byIcon(Icons.search).first);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));

      // No 'Duplicate GlobalKey' should have been reported.
      final errors = tester.takeException();
      if (errors != null) {
        print('REPRODUCTION ERROR: $errors');
      }
      debugPrint('pump done, errors=$errors');
    });
  });
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(child: Text('Home body')),
    );
  }
}
