import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/search/presentation/pages/flight_search_page.dart';
import 'package:tokigo/features/search/presentation/pages/hotel_search_page.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';

/// Task 5 — the pickers must not open the keyboard when they are opened from
/// the REAL entry points (the flight origin field and the hotel destination
/// field), not only from the shared sheet in isolation.
Finder _pickerField() => find.descendant(
  of: find.byType(BottomSheet),
  matching: find.byType(TextField),
);

bool _searchFieldHasFocus(WidgetTester tester) {
  final EditableText editable = tester.widget<EditableText>(
    find.descendant(of: _pickerField(), matching: find.byType(EditableText)),
  );
  return editable.focusNode.hasFocus;
}

Widget _app(GoRouter router) => UncontrolledProviderScope(
  container: _container,
  child: MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  ),
);

late ProviderContainer _container;

void main() {
  setUp(() {
    _container = ProviderContainer(
      overrides: <Override>[
        authUserProvider.overrideWith((ref) => null),
        geoCountryProvider.overrideWith((ref) async => null),
        currencyProvider.overrideWith(() => CurrencyController()),
      ],
    );
  });
  tearDown(() => _container.dispose());

  testWidgets('flight origin picker opens with the list visible and no focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/flights',
      routes: <RouteBase>[
        GoRoute(
          path: '/flights',
          builder: (BuildContext context, GoRouterState state) =>
              const FlightSearchPage(),
        ),
      ],
    );
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    // The real entry point: the origin field (its 20px leading glyph).
    await tester.tap(
      find.byWidgetPredicate(
        (Widget w) =>
            w is Icon &&
            w.icon == Icons.flight_takeoff_rounded &&
            w.size == 20,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cairo International'), findsOneWidget);
    expect(_searchFieldHasFocus(tester), isFalse);

    // Tapping the search box focuses it.
    await tester.tap(_pickerField());
    await tester.pumpAndSettle();
    expect(_searchFieldHasFocus(tester), isTrue);
  });

  testWidgets('hotel destination picker opens with the list visible and no focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/hotels',
      routes: <RouteBase>[
        GoRoute(
          path: '/hotels',
          builder: (BuildContext context, GoRouterState state) =>
              const HotelSearchPage(),
        ),
      ],
    );
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    // The real entry point: the destination field.
    await tester.tap(find.byIcon(Icons.location_on_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Cairo'), findsOneWidget);
    expect(_searchFieldHasFocus(tester), isFalse);

    // Tapping the search box focuses it.
    await tester.tap(_pickerField());
    await tester.pumpAndSettle();
    expect(_searchFieldHasFocus(tester), isTrue);
  });
}
