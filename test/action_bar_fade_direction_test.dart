// The navigation rail bleeds to both screen edges in both reading directions.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/l10n/app_localizations.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('the rail reaches both edges (${locale.languageCode})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(780, 1400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: HomeActionBar(onActionSelected: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final double screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final Rect bar = tester.getRect(find.byType(HomeActionBar));
      expect(bar.left, 0);
      expect(bar.right, screenWidth);

      // No overflow fades anywhere in either direction.
      expect(
        find.byKey(const ValueKey<String>('home-action-bar-overflow-start')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('home-action-bar-overflow')),
        findsNothing,
      );
    });
  }
}
