import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/search/presentation/widgets/destination_picker_sheet.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Task 5 — the airport and city pickers must open with the keyboard hidden.
///
/// Both pickers share [showPickerSheet]; each is exercised independently with
/// its real entry list (airports for the flight form, cities for the hotel
/// form). The search field's focus is the keyboard's proxy: unfocused means the
/// keyboard never opened, focused means tapping the field opened it.
GoRouter _router(List<PickerEntry> entries, String title) => GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) => Scaffold(
        body: Center(
          child: Builder(
            builder: (BuildContext ctx) => ElevatedButton(
              onPressed: () => showPickerSheet(
                ctx,
                title: title,
                entries: entries,
                onSelected: (_) {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ],
);

Widget _app(GoRouter router) => ProviderScope(
  overrides: <Override>[
    geoCountryProvider.overrideWith((ref) async => null),
  ],
  child: MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ThemeMode.light,
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

/// Whether the picker's search field currently owns focus.
bool _searchFieldHasFocus(WidgetTester tester) {
  final EditableText editable = tester.widget<EditableText>(
    find.descendant(
      of: find.byType(TextField),
      matching: find.byType(EditableText),
    ),
  );
  return editable.focusNode.hasFocus;
}

void main() {
  for (final ({
    String name,
    List<PickerEntry> entries,
    String title,
    String firstEntry,
  }) picker in <({String name, List<PickerEntry> entries, String title, String firstEntry})>[
    (
      name: 'airport',
      entries: kAirports,
      title: 'From',
      firstEntry: 'Cairo International',
    ),
    (name: 'city', entries: kCities, title: 'To', firstEntry: 'Cairo'),
  ]) {
    testWidgets('${picker.name} picker opens with the list visible and no focus', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(_router(picker.entries, picker.title)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The list appears immediately.
      expect(find.text(picker.firstEntry), findsOneWidget);
      // The search field is not focused: the keyboard stays hidden.
      expect(_searchFieldHasFocus(tester), isFalse);

      // Tapping the search box focuses it (the keyboard opens).
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(_searchFieldHasFocus(tester), isTrue);

      // The field still filters normally.
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
    });
  }
}
