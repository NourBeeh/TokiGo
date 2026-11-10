import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/search/domain/search_filters.dart';
import 'package:tokigo/features/search/presentation/widgets/filter_panel.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart';
import 'package:tokigo/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

void main() {
  testWidgets('the filter panel exposes a dedicated Direct only toggle', (
    tester,
  ) async {
    SearchFilters? applied;
    await tester.pumpWidget(
      _app(
        FilterPanel(
          filters: const SearchFilters(),
          onChanged: (filters) => applied = filters,
          showDirectOnly: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Direct only'), findsWidgets);

    await tester.tap(find.widgetWithText(SearchChoiceChip, 'Direct only'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();

    expect(applied, isNotNull);
    expect(applied!.directOnly, isTrue);
    // No other filter was touched.
    expect(applied!.isEmpty, isFalse);
    expect(applied!.maxStops, isNull);
    expect(applied!.priceMax, isNull);
  });

  testWidgets('the toggle is off by default and can be cleared', (tester) async {
    SearchFilters? applied;
    await tester.pumpWidget(
      _app(
        FilterPanel(
          filters: const SearchFilters(directOnly: true),
          onChanged: (filters) => applied = filters,
          showDirectOnly: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The chip reflects the incoming state.
    final SearchChoiceChip chip = tester.widget<SearchChoiceChip>(
      find.widgetWithText(SearchChoiceChip, 'Direct only'),
    );
    expect(chip.selected, isTrue);

    await tester.tap(find.widgetWithText(SearchChoiceChip, 'Direct only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();

    expect(applied!.directOnly, isFalse);
    expect(applied!.isEmpty, isTrue);
  });

  testWidgets('the Direct only section is omitted unless requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        FilterPanel(
          filters: const SearchFilters(),
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Direct only'), findsNothing);
  });
}
