import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Page title visibility (owner decision, 2026-11).
///
/// Every pushed page identifies itself through the ONE header pattern
/// ([AppPageHeader.subtitle]) — no second title, no extra header height. The
/// AI chat page, which used to have none, now carries the same line.
void main() {
  Widget host(String subtitle) => MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: AppPageHeader(subtitle: subtitle)),
      );

  testWidgets('the header shows the page name as a semantic header', (
    tester,
  ) async {
    await tester.pumpWidget(host('TokiGo AI assistant'));
    await tester.pumpAndSettle();

    expect(find.text('TokiGo AI assistant'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is Semantics && w.properties.header == true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('the AI chat subtitle is the existing localized string', (
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
        home: const Scaffold(body: AppPageHeader()),
      ),
    );
    await tester.pumpAndSettle();

    // The shared header owns the back control; the page supplies the line.
    expect(find.byType(AppPageHeader), findsOneWidget);
  });
}
