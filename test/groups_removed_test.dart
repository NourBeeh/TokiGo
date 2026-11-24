import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/app/widgets/app_bottom_nav.dart';
import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/core/navigation/app_route.dart';
import 'package:tokigo/core/storage/last_route_store.dart';
import 'package:tokigo/features/home/domain/home_action.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Groups removal acceptance (R9/R10): no route, no navigation destination,
/// no quick action, no restorable path, no Groups label anywhere.
void main() {
  test('no Groups route or navigation destination remains', () {
    expect(AppRoute.values.map((AppRoute route) => route.name), isNot(contains('groups')));
    expect(
      AppBottomNavDestination.values.map((AppBottomNavDestination destination) => destination.name),
      isNot(contains('groups')),
    );
    expect(HomeAction.values.map((HomeAction action) => action.id), isNot(contains('groups')));
    expect(HomeAction.fromPath('/groups'), isNull);
    expect(LastRouteStore.isRestorable('/groups'), isFalse);
  });

  testWidgets('the Home quick-action bar has no Groups tile', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: HomeNavButtons()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Groups'), findsNothing);
    expect(find.byIcon(Icons.groups_rounded), findsNothing);
    expect(find.byIcon(Icons.groups_outlined), findsNothing);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(HomeNavButtons)),
    )!;
    expect(homeActionDefinitions(l10n).length, 4);
  });
}
