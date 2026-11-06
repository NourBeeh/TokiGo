import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/profile/presentation/pages/settings_page.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';
import 'package:tokigo/shared/providers/theme_provider.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('Settings renders in $mode / $locale', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              themeModeProvider.overrideWith(
                () => ThemeModeController(initialMode: mode),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: mode,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const SettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
