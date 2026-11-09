import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/search/presentation/widgets/destination_picker_sheet.dart';
import 'package:tokigo/l10n/app_localizations.dart';

void main() {
  testWidgets('picker Arabic query matches Cairo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showPickerSheet(
                  context,
                  title: 'من',
                  entries: kAirports,
                  onSelected: (_) {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // clear and type Arabic alias
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'القاهرة');
    await tester.pumpAndSettle();
    expect(find.text('Cairo International'), findsOneWidget);
  });

  testWidgets('picker English code query matches', (tester) async {
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
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showPickerSheet(
                  context,
                  title: 'From',
                  entries: kAirports,
                  onSelected: (_) {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'DXB');
    await tester.pumpAndSettle();
    expect(find.text('Dubai International'), findsOneWidget);
  });

  testWidgets('picker clear search restores list', (tester) async {
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
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showPickerSheet(
                  context,
                  title: 'From',
                  entries: kAirports,
                  onSelected: (_) {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
    // clear via suffix
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Cairo International'), findsOneWidget);
  });
}
