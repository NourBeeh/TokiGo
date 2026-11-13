import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/search/presentation/widgets/search_map_placeholder.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/l10n/app_localizations_en.dart';

/// The accommodation page's copy (owner decision, 2026-11).
///
/// * ONE term for the vertical — "stays" — in the page title, the results
///   count, the search action and the empty state;
/// * the map placeholder never claims the results are shown in list view while
///   the map is the active view.
void main() {
  test('the accommodation page uses one term for stays', () {
    final AppLocalizations l10n = AppLocalizationsEn();
    expect(l10n.searchHotels, 'Stays');
    expect(l10n.findHotels, 'Find stays');
    expect(l10n.hotelEmptyTitle, 'No stays found');
    expect(l10n.hotelResultsCount(1), '1 stay');
    expect(l10n.hotelResultsCount(3), '3 stays');
  });

  testWidgets('the map placeholder does not claim the list is showing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: SearchMapPlaceholder()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Results are shown in list view'), findsNothing);
    expect(
      find.textContaining('Switch back to the list view'),
      findsOneWidget,
    );
  });
}
