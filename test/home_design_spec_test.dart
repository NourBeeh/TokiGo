import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/features/home/presentation/widgets/home_ai_search_field.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The owner's Home design spec, asserted directly: palette, search-bar
/// geometry and the four quick-action cards.
void main() {
  const Color background = Color(0xFFFAFAFA);
  const Color surface = Color(0xFFFFFFFF);
  // Home's ink is the theme's neutral brand ink (near-black on the light
  // canvas, near-white on the dark one); the placeholder is the AA-safe
  // tertiary step.
  const Color accent = Color(0xFF111111);
  const Color hint = Color(0xFF6E6E6E);
  const Color border = Color(0xFFDBDBDB);

  Widget app(
    Widget child, {
    Locale locale = const Locale('en'),
    ThemeMode mode = ThemeMode.light,
  }) {
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(body: child),
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
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
    );
  }

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(720, 1480);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('search bar', () {
    testWidgets('matches the spec geometry and palette', (tester) async {
      phoneSize(tester);
      // `Center` mirrors the pinned Home header, which gives the field a
      // bounded-but-loose height (a bare Scaffold body would force it tall).
      await tester.pumpWidget(
        app(
          const Center(child: SizedBox(width: 360, child: HomeAiSearchField())),
        ),
      );
      await tester.pumpAndSettle();

      final Container field = tester.widget<Container>(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Container &&
              w.constraints?.minHeight == 48 &&
              w.decoration is BoxDecoration,
        ),
      );
      final BoxDecoration decoration = field.decoration! as BoxDecoration;

      expect(tester.getSize(find.byType(HomeAiSearchField)).height, 48);
      expect(decoration.color, surface);
      // Task 3 — the pill is FLAT in light theme: its edge is the surface step
      // against the canvas, never a drop shadow.
      expect(decoration.boxShadow ?? const <BoxShadow>[], isEmpty);
      // Owner decision (2026-11): no 1dp border — the surface step is the
      // separation.
      expect(decoration.border, isNull);
      expect(decoration.borderRadius, equals(BorderRadius.circular(24)));

      // The old leading magnifier is gone; search is the trailing action.
      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Icon && w.icon == Icons.search_rounded && w.size == 22,
        ),
        findsNothing,
      );
      final Finder searchAction = find.byKey(
        const ValueKey<String>('home-ai-composer-send'),
      );
      final Icon searchGlyph = tester.widget<Icon>(
        find.descendant(of: searchAction, matching: find.byType(Icon)).first,
      );
      expect(searchGlyph.icon, Icons.search_rounded);
      expect(searchGlyph.color, Colors.white);

      // The localized hint, in the spec's hint colour.
      final Text hintText = tester.widget<Text>(
        find.text('Search destinations, hotels & more'),
      );
      expect(hintText.style?.color, hint);
      expect(hintText.maxLines, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('localizes the hint and mirrors in Arabic', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(
          const Center(child: SizedBox(width: 360, child: HomeAiSearchField())),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ابحث عن وجهات وفنادق والمزيد'), findsOneWidget);
      expect(find.text('Search destinations, hotels & more'), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(HomeAiSearchField))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('quick action cards', () {
    testWidgets('four spec tiles on one row', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(const SizedBox(width: 360, child: HomeNavButtons())),
      );
      await tester.pumpAndSettle();

      final Finder tiles = find.descendant(
        of: find.byType(HomeNavButtons),
        matching: find.byType(AnimatedContainer),
      );
      // Trips left the bar (owner decision, 2026-11); Groups was removed.
      expect(tiles, findsNWidgets(4));

      final List<String> labels = <String>[
        'Flights',
        'Stays',
        'Cars Rental',
        'Packages',
      ];
      final List<IconData> icons = <IconData>[
        Icons.flight_rounded,
        Icons.home_rounded,
        Icons.directions_car_rounded,
        Icons.beach_access_rounded,
      ];

      double previousRight = double.negativeInfinity;
      for (int i = 0; i < 4; i++) {
        final Finder tileFinder = tiles.at(i);
        final AnimatedContainer tile = tester.widget<AnimatedContainer>(
          tileFinder,
        );
        final BoxDecoration decoration = tile.decoration! as BoxDecoration;

        expect(tester.getSize(tileFinder).height, 68);
        expect(decoration.color, surface);
        expect(decoration.boxShadow, isEmpty);
        expect(decoration.borderRadius, equals(BorderRadius.circular(18)));
        final Border boxBorder = decoration.border! as Border;
        expect(boxBorder.top.color, border);
        expect(boxBorder.top.width, 1);

        final Finder glyph = find
            .descendant(
              of: tileFinder,
              matching: i == 3 ? find.byType(Image) : find.byType(Icon),
            )
            .first;
        if (i == 3) {
          expect(tester.widget<Image>(glyph).width, 24);
        } else {
          final Icon icon = tester.widget<Icon>(glyph);
          expect(icon.icon, icons[i]);
          expect(icon.size, 24);
          expect(icon.color, accent);
        }

        final Text label = tester.widget<Text>(find.text(labels[i]));
        expect(label.style?.fontSize, 12);
        expect(label.style?.fontWeight, FontWeight.w600);
        expect(label.style?.color, accent);

        // The 6dp glyph-to-label gap.
        final double iconBottom = tester.getRect(glyph).bottom;
        final double labelTop = tester.getRect(find.text(labels[i])).top;
        expect(labelTop - iconBottom, closeTo(4, 0.01));

        // Balanced row: each tile starts after the previous one ends.
        final Rect rect = tester.getRect(tileFinder);
        expect(rect.left, greaterThan(previousRight));
        previousRight = rect.right;
      }

      // Equal, responsive widths.
      final List<double> widths = <double>[
        for (int i = 0; i < 4; i++) tester.getRect(tiles.at(i)).width,
      ];
      for (final double width in widths) {
        expect(width, closeTo(widths.first, 0.01));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('labels are localized in Arabic', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(
          const SizedBox(width: 360, child: HomeNavButtons()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('طيران'), findsOneWidget);
      expect(find.text('إقامات'), findsOneWidget);
      expect(find.text('تأجير سيارات'), findsOneWidget);
      expect(find.text('الباقات'), findsOneWidget);
      // Groups was removed from the bar.
      expect(find.text('رحلاتي'), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(HomeNavButtons))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the Home design palette is exposed as tokens', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(app(const SizedBox.shrink()));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(SizedBox));
    expect(HomeDesignTokens.background, background);
    expect(HomeDesignTokens.surface, surface);
    expect(HomeDesignTokens.accent, accent);
    expect(HomeDesignTokens.hint, hint);
    expect(HomeDesignTokens.border, border);
    expect(HomeDesignTokens.backgroundOf(context), background);
    expect(HomeDesignTokens.surfaceOf(context), surface);
    expect(HomeDesignTokens.accentOf(context), accent);
    expect(HomeDesignTokens.borderOf(context), border);
    expect(HomeDesignTokens.hintOf(context), hint);
  });

  group('dark mode', () {
    testWidgets('quick actions and the composer ink resolve to white', (
      tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(
          const Center(child: SizedBox(width: 360, child: HomeNavButtons())),
          mode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      // The dark canvas's own ink is the near-white brand step.
      expect(
        HomeDesignTokens.accentOf(tester.element(find.byType(HomeNavButtons))),
        const Color(0xFFF5F5F5),
      );

      final Finder tiles = find.descendant(
        of: find.byType(HomeNavButtons),
        matching: find.byType(AnimatedContainer),
      );
      final Icon icon = tester.widget<Icon>(
        find.descendant(of: tiles.at(0), matching: find.byType(Icon)).first,
      );
      expect(icon.color, const Color(0xFFF5F5F5));
      final Text label = tester.widget<Text>(find.text('Flights'));
      expect(label.style?.color, const Color(0xFFF5F5F5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the AI composer search disc is white with a black glyph', (
      tester,
    ) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(
          const Center(child: SizedBox(width: 360, child: HomeAiSearchField())),
          mode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(
        find.byType(HomeAiSearchField),
      );
      expect(HomeDesignTokens.accentOf(context), const Color(0xFFF5F5F5));

      // The search disc is a DecoratedBox with the Home ink as its fill.
      final Finder send = find.byKey(
        const ValueKey<String>('home-ai-composer-send'),
      );
      final DecoratedBox disc = tester.widget<DecoratedBox>(
        find.descendant(of: send, matching: find.byType(DecoratedBox)).first,
      );
      expect((disc.decoration as BoxDecoration).color, const Color(0xFFF5F5F5));
      final Icon glyph = tester.widget<Icon>(
        find.descendant(of: send, matching: find.byType(Icon)).first,
      );
      expect(glyph.color, const Color(0xFF000000));
      expect(tester.takeException(), isNull);
    });
  });
}
