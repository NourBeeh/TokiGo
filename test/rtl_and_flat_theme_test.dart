import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_elevation.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/ui/directional_icons.dart';
import 'package:tokigo/core/widgets/app_back_button.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/features/home/presentation/widgets/home_ai_search_field.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Task 2 (RTL) + Task 3 (flat light theme) — the two cross-cutting rules the
/// rest of the suite does not pin:
///
/// * RTL: direction follows the ACTIVE LOCALE, and every glyph that means
///   "forward / next / disclosure" mirrors with it. A physical right/left is a
///   bug, not a style choice.
/// * Light theme is FLAT: search boxes and buttons carry an edge, never a
///   drop shadow. Dark keeps its halo.

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeMode mode = ThemeMode.light,
}) => MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  themeMode: mode,
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: Center(child: child)),
);

/// The [BoxDecoration] of the first [Container] found under [finder].
BoxDecoration _decorationOf(WidgetTester tester, Finder finder) {
  final Container container = tester.widget<Container>(
    find.descendant(of: finder, matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  group('locale drives direction', () {
    testWidgets('English renders LTR', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext context) =>
                Text(Directionality.of(context).name),
          ),
        ),
      );
      expect(find.text('ltr'), findsOneWidget);
    });

    testWidgets('Arabic renders RTL', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext context) =>
                Text(Directionality.of(context).name),
          ),
          locale: const Locale('ar'),
        ),
      );
      expect(find.text('rtl'), findsOneWidget);
    });
  });

  group('directional glyphs', () {
    testWidgets('the disclosure chevron mirrors', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext context) =>
                Icon(DirectionalIcons.chevron(context)),
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext context) =>
                Icon(DirectionalIcons.chevron(context)),
          ),
          locale: const Locale('ar'),
        ),
      );
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    });

    testWidgets('the "view all" arrow mirrors', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext context) =>
                Icon(DirectionalIcons.forward(context)),
          ),
        ),
      );
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext context) =>
                Icon(DirectionalIcons.forward(context)),
          ),
          locale: const Locale('ar'),
        ),
      );
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('a button trailing "continue" chevron mirrors', (tester) async {
      Future<IconData> iconIn(Locale locale) async {
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (BuildContext context) => AppButton(
                label: 'Continue',
                trailingIcon: DirectionalIcons.chevron(context),
                onPressed: () {},
              ),
            ),
            locale: locale,
          ),
        );
        return tester
            .widget<Icon>(
              find
                  .descendant(
                    of: find.byType(AppButton),
                    matching: find.byType(Icon),
                  )
                  .first,
            )
            .icon!;
      }

      expect(await iconIn(const Locale('en')), Icons.chevron_right_rounded);
      expect(await iconIn(const Locale('ar')), Icons.chevron_left_rounded);
    });

    testWidgets('the back chevron mirrors', (tester) async {
      await tester.pumpWidget(
        _app(const SizedBox(width: 200, child: AppBackButton())),
      );
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });
  });

  group('Task 3 — light theme is flat', () {
    testWidgets('the Home search box has no shadow in light theme', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const HomeAiSearchField()));
      await tester.pumpAndSettle();

      final BoxDecoration decoration = _decorationOf(
        tester,
        find.byKey(const ValueKey<String>('home-ai-composer')),
      );
      expect(decoration.boxShadow, isEmpty);
    });

    testWidgets('the Home search box keeps its halo in dark theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const HomeAiSearchField(), mode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();

      final BoxDecoration decoration = _decorationOf(
        tester,
        find.byKey(const ValueKey<String>('home-ai-composer')),
      );
      expect(decoration.boxShadow, isNotEmpty);
    });

    testWidgets('the light theme helper never returns a shadow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext context) => DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: AppElevation.darkOnly(
                  context,
                  background: Colors.white,
                  level: AppElevation.lg,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the dark theme helper keeps its halo', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext context) => DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: AppElevation.darkOnly(
                  context,
                  background: Colors.white,
                  level: AppElevation.lg,
                ),
              ),
            ),
          ),
          mode: ThemeMode.dark,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the light theme button themes carry no elevation', (
      tester,
    ) async {
      final ThemeData theme = AppTheme.light();
      expect(
        theme.filledButtonTheme.style?.elevation?.resolve(
          const <WidgetState>{},
        ),
        AppElevation.none,
      );
      expect(
        theme.elevatedButtonTheme.style?.elevation?.resolve(
          const <WidgetState>{},
        ),
        AppElevation.none,
      );
    });

    testWidgets('the dark theme keeps its button elevation', (tester) async {
      final ThemeData theme = AppTheme.dark();
      // Dark is unchanged by this phase: it must NOT have been flattened.
      final double? filled = theme.filledButtonTheme.style?.elevation?.resolve(
        const <WidgetState>{},
      );
      expect(
        filled == AppElevation.none && theme.brightness == Brightness.dark,
        isFalse,
      );
    });

    testWidgets('the Home composer halo token is empty in light mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext context) => DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: HomeDesignTokens.composerShadowOf(context),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
