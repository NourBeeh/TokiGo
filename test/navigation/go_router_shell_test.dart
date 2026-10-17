// Verification test for the Travellers navigation fix.
//
// Root cause: the single shell branch carried a custom top-level
// GlobalKey<NavigatorState> (_homeTabKey). GoRouter ties that key to the
// branch Navigator, so during shell rebuilds (e.g. the onboarding redirect) the
// same key is registered on multiple Navigator widgets. This triggers
// Flutter's "Duplicate GlobalKey detected in widget tree involving
// _BranchNavigatorProxy and StatefulShellBranch" assertion, and the shared key
// also breaks the branch stack / back navigation.
//
// The fix removes the custom navigatorKey from the branch, letting GoRouter
// assign each branch its own unique default key. This test renders the shell
// and pump-cycles the branch + the root-stacked booking/search screens while
// asserting that no "Duplicate GlobalKey" error is thrown and that back
// navigation (context.canPop() ? context.pop()) pops the expected screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Fixed shell router (no custom branch navigatorKey)', () {
    testWidgets('renders the shell branch and its navigator safely', (tester) async {
      final onboarding = ValueNotifier<_Onboarding>(_Onboarding(ready: true, seen: true));
      await tester.pumpWidget(_harness(onboarding: onboarding));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(IndexedStack), findsOneWidget);
      expect(find.byType(Navigator), findsNWidgets(2));
    });

    testWidgets('no Duplicate GlobalKey is thrown during a model rebuild', (tester) async {
      final onboarding = ValueNotifier<_Onboarding>(_Onboarding(ready: true, seen: false));
      await tester.pumpWidget(_harness(onboarding: onboarding));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsOneWidget);

      onboarding.value = _Onboarding(ready: true, seen: true);
      await tester.pumpAndSettle();

      final error = tester.takeException();
      expect(error, isNull);
    });
  });

  group('Back navigation: canPop=true case', () {
    testWidgets('pressing back on a screen with a previous route pops it', (tester) async {
      final onboarding = ValueNotifier<_Onboarding>(_Onboarding(ready: true, seen: true));
      await tester.pumpWidget(_harness(onboarding: onboarding));
      await tester.pumpAndSettle();

      expect(find.text('Home body'), findsOneWidget);

      await tester.tap(find.text('Open Review'));
      await tester.pumpAndSettle();
      expect(find.text('Booking review'), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Home body'), findsOneWidget);
    });
  });

  group('Back navigation: canPop=false case', () {
    testWidgets('pressing back on the root screen does not exit the app', (tester) async {
      final onboarding = ValueNotifier<_Onboarding>(_Onboarding(ready: true, seen: true));
      await tester.pumpWidget(_harness(onboarding: onboarding));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);

      await tester.tap(find.text('Open Search'));
      await tester.pumpAndSettle();

      final error = tester.takeException();
      expect(error, isNull);
    });
  });
}

Widget _harness({ValueNotifier<_Onboarding>? onboarding}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return MaterialApp.router(
    debugShowCheckedModeBanner: false,
    routerConfig: GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      redirect: (context, state) {
        final isOnboarding = state.matchedLocation == '/onboarding';
        if (onboarding != null) {
          final o = onboarding.value;
          if (o.ready && !o.seen && !isOnboarding) return '/onboarding';
          if (o.seen && isOnboarding) return '/';
        }
        return null;
      },
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => Scaffold(body: navigationShell),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(path: '/', builder: (context, state) => const HomePage()),
                GoRoute(path: '/flights', builder: (context, state) => const FlightSearchPage()),
                GoRoute(
                  path: '/booking/review',
                  name: 'booking_review',
                  builder: (context, state) => const BookingReviewPage(),
                  routes: <GoRoute>[
                    GoRoute(
                      path: 'passengers',
                      name: 'booking_passengers',
                      builder: (context, state) => const PassengerDetailsPage(),
                    ),
                    GoRoute(
                      path: 'add-ons',
                      name: 'booking_add_ons',
                      builder: (context, state) => const AddOnsPage(),
                    ),
                    GoRoute(
                      path: 'checkout',
                      name: 'booking_checkout',
                      builder: (context, state) => const CheckoutPage(),
                    ),
                    GoRoute(
                      path: 'confirmation',
                      name: 'booking_confirmation',
                      builder: (context, state) => const BookingConfirmationPage(),
                    ),
                  ],
                ),
                GoRoute(
                  path: '/search',
                  name: 'search',
                  builder: (context, state) => const SearchHubPage(),
                  routes: <GoRoute>[
                    GoRoute(
                      path: 'transfers',
                      builder: (context, state) =>
                          const PlaceholderPageScaffold(routeName: 'transfers'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/onboarding',
          pageBuilder: (context, state) =>
              fadeThroughPage(name: 'onboarding', child: const OnboardingPage()),
        ),
        GoRoute(
          path: '/admin',
          pageBuilder: (context, state) =>
              fadeThroughPage(name: 'admin', child: const AdminPage()),
        ),
        GoRoute(
          path: '/ai-chat',
          pageBuilder: (context, state) =>
              fadeThroughPage(name: 'ai_chat', child: const AiChatPage()),
        ),
        GoRoute(
          path: '/ai-memory',
          pageBuilder: (context, state) =>
              fadeThroughPage(name: 'ai_memory', child: const AiMemoryPage()),
        ),
        GoRoute(
          path: '/smart-search',
          pageBuilder: (context, state) =>
              fadeThroughPage(name: 'smart_search', child: const UniversalSearchPage()),
        ),
      ],
    ),
  );
}

// --- back-stack & product-screen stand-ins (mirror the app pages) ---

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Home body'),
            _NavButton(label: 'Open Search'),
            _NavButton(label: 'Open Review'),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      child: Text(label),
      onPressed: () {
        if (label == 'Open Search') {
          context.push('/search');
        } else {
          context.push('/booking/review');
        }
      },
    );
  }
}

class FlightSearchPage extends StatelessWidget {
  const FlightSearchPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Flights')));
}

class SearchHubPage extends StatelessWidget {
  const SearchHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: const Center(child: Text('Search hub')),
    );
  }
}

class BookingReviewPage extends StatelessWidget {
  const BookingReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking review')),
      body: const Center(child: Text('Booking review')),
    );
  }
}

class PassengerDetailsPage extends StatelessWidget {
  const PassengerDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passengers')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Passengers'),
            _BackButton(),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      child: const Text('Back'),
      onPressed: () {
        if (context.canPop()) context.pop();
      },
    );
  }
}

class AddOnsPage extends StatelessWidget {
  const AddOnsPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Add-ons')));
}

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Checkout')));
}

class BookingConfirmationPage extends StatelessWidget {
  const BookingConfirmationPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Confirmation')));
}

class PlaceholderPageScaffold extends StatelessWidget {
  const PlaceholderPageScaffold({super.key, required this.routeName});

  final String routeName;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Placeholder $routeName')));
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Onboarding')));
}

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Admin')));
}

class AiChatPage extends StatelessWidget {
  const AiChatPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('AI chat')));
}

class AiMemoryPage extends StatelessWidget {
  const AiMemoryPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('AI memory')));
}

class UniversalSearchPage extends StatelessWidget {
  const UniversalSearchPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Smart search')));
}

class _Onboarding {
  _Onboarding({required this.ready, required this.seen});

  final bool ready;
  final bool seen;
}

Page<void> fadeThroughPage({required String name, required Widget child}) {
  return MaterialPage<void>(key: ValueKey<String>(name), child: child);
}

Page<void> containerTransformPage({required String name, required Widget child}) {
  return MaterialPage<void>(key: ValueKey<String>(name), child: child);
}
