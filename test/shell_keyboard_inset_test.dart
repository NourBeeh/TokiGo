import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/shell.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/search/presentation/widgets/destination_picker_sheet.dart';
import 'package:tokigo/l10n/app_localizations.dart';

GoRouter _router() => GoRouter(
  initialLocation: '/flights',
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => TokiGoShell(
        navigationShell: navigationShell,
        location: state.matchedLocation,
      ),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/flights',
              builder: (context, state) => Scaffold(
                body: SafeArea(
                  child: Builder(
                    builder: (BuildContext ctx) => Center(
                      child: ElevatedButton(
                        onPressed: () => showPickerSheet(
                          ctx,
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
            ),
          ],
        ),
      ],
    ),
  ],
);

Widget _app({required bool dark}) => ProviderScope(
  overrides: <Override>[geoCountryProvider.overrideWith((ref) async => null)],
  child: MaterialApp.router(
  routerConfig: _router(),
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (BuildContext context, Widget? child) {
    final MediaQueryData media = MediaQuery.of(context);
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: <Widget>[
          Expanded(
            child: MediaQuery(
              data: media.copyWith(
                padding: media.padding.copyWith(top: media.padding.top),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  },
  ),
);

void main() {
  for (final bool dark in <bool>[false, true]) {
    testWidgets('picker sheet above the keyboard ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(dark: dark));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final Finder list = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(ListView),
      );
      final Rect sheet = tester.getRect(find.byType(BottomSheet));
      final Rect listRect = tester.getRect(list);

      // The Scaffold body is already shortened by the keyboard, so the sheet
      // must NOT reserve the keyboard inset a second time: the list runs to
      // the sheet's bottom edge.
      expect(
        MediaQuery.of(tester.element(list)).viewInsets.bottom,
        0,
        reason: 'the shell must not re-apply the removed keyboard inset',
      );
      expect(
        listRect.bottom,
        closeTo(sheet.bottom, 1),
        reason: 'no empty band between the last row and the keyboard',
      );
    });
  }
}
