import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/core/widgets/compact_step_button.dart';
import 'package:tokigo/features/search/presentation/pages/flight_search_page.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';

/// P3 — the flight search page keeps the traveller party across navigation.
///
/// The page is a `ConsumerStatefulWidget` in its own route, so pushing an
/// offer-details route and popping back must NOT reset the counters.
void main() {
  Future<GoRouter> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authUserProvider.overrideWith((ref) => null),
        geoCountryProvider.overrideWith((ref) async => null),
        currencyProvider.overrideWith(() => CurrencyController()),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: '/flights',
      routes: <RouteBase>[
        GoRoute(
          path: '/flights',
          builder: (BuildContext context, GoRouterState state) =>
              const FlightSearchPage(),
        ),
        GoRoute(
          path: '/offer-details',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('OFFER')),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: const <Locale>[Locale('en')],
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
    return router;
  }

  testWidgets('passenger selections survive navigating away and back', (
    tester,
  ) async {
    final GoRouter router = await pumpPage(tester);

    // Open the travellers sheet and make it 2 adults + 1 child.
    await tester.tap(find.byIcon(Icons.people_outline_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded).at(0)); // adults: 1 → 2
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded).at(1)); // children: 0 → 1
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('3 passengers'), findsOneWidget);

    // Navigate to an offer and back: the party must be untouched.
    router.push('/offer-details');
    await tester.pumpAndSettle();
    expect(find.text('OFFER'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('OFFER'), findsNothing);
    expect(find.text('3 passengers'), findsOneWidget);
  });

  testWidgets('an infant cannot outnumber the adults', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.people_outline_rounded));
    await tester.pumpAndSettle();

    // One adult: the infant stepper may reach 1 but never 2.
    await tester.tap(find.byIcon(Icons.add_rounded).at(2));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded).at(2));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('2 passengers'), findsOneWidget);
  });

  testWidgets('a child added in the sheet keeps its age dropdown', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.people_outline_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded).at(1)); // children: 0 → 1
    await tester.pump();

    // The child's age is collected (default 5), never left unset.
    expect(find.byType(DropdownButton<int>), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('2 passengers'), findsOneWidget);
  });

  testWidgets('the passenger sheet uses the shared compact stepper', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.people_outline_rounded));
    await tester.pumpAndSettle();

    // The adult row is labelled "Adults" — never a plural count string.
    expect(find.text('Adults'), findsOneWidget);
    expect(find.text('Children'), findsOneWidget);
    expect(find.text('Infants'), findsOneWidget);

    // Three steppers (adults / children / infants) × two compact buttons.
    expect(find.byType(CompactStepButton), findsNWidgets(6));
  });

  testWidgets('the passenger steppers disable at their minimum and maximum', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.people_outline_rounded));
    await tester.pumpAndSettle();

    final colors = TokiGoColors.light();
    bool enabledAt(int index) =>
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byType(CompactStepButton).at(index),
                matching: find.byType(Icon),
              ),
            )
            .color ==
        colors.brand;

    // Defaults: 1 adult, no children, no infants — every minus is at its floor.
    expect(enabledAt(0), isFalse); // adults minus
    expect(enabledAt(1), isTrue); // adults plus
    expect(enabledAt(2), isFalse); // children minus
    expect(enabledAt(3), isTrue); // children plus
    expect(enabledAt(4), isFalse); // infants minus
    expect(enabledAt(5), isTrue); // infants plus

    // Fill the party to the provider maximum of nine.
    for (int i = 0; i < 8; i++) {
      await tester.tap(find.byType(CompactStepButton).at(1));
      await tester.pump();
    }
    expect(find.text('9'), findsOneWidget);

    // Every plus is now at the total maximum; the adult minus is still live.
    expect(enabledAt(1), isFalse);
    expect(enabledAt(3), isFalse);
    expect(enabledAt(5), isFalse);
    expect(enabledAt(0), isTrue);
  });
}
