// Direction check for the overflow fades on the navigation rail: the leading
// fade sits at the reading-start edge and the trailing fade at the
// reading-end edge, in both LTR and RTL.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/l10n/app_localizations.dart';

Widget _app(Locale locale) => MaterialApp(
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
    body: Center(
      child: SizedBox(
        width: 360,
        child: HomeActionBar(onActionSelected: (_) {}),
      ),
    ),
  ),
);

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('overflow fades face the reading direction (${locale.languageCode})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(locale));
      await tester.pumpAndSettle();

      final double screenW = tester.view.physicalSize.width /
          tester.view.devicePixelRatio;

      // Start-of-row fade must NOT exist while the row is at its start.
      expect(
        find.byKey(const ValueKey<String>('home-action-bar-overflow-start')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('home-action-bar-overflow')),
        findsOneWidget,
      );

      // Drag the row: in RTL the axis flips, but the visible drag direction is
      // the same physical gesture toward the reading-start edge.
      final bool rtl = locale.languageCode == 'ar';
      await tester.drag(
        find.byKey(const ValueKey<String>('home-action-bar')),
        Offset(rtl ? 260 : -260, 0),
      );
      await tester.pumpAndSettle();

      final Finder startFade = find.byKey(
        const ValueKey<String>('home-action-bar-overflow-start'),
      );
      expect(startFade, findsOneWidget, reason: 'start fade must appear');

      // The start fade must sit at the reading-start edge of the row.
      final Rect startRect = tester.getRect(startFade);
      if (rtl) {
        expect(startRect.right, greaterThan(screenW - 1));
      } else {
        expect(startRect.left, lessThan(1));
      }
    });
  }
}
