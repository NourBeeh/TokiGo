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
  const Color background = Color(0xFFFAF8F5);
  const Color surface = Color(0xFFFFFFFF);
  const Color accent = Color(0xFF111111);
  const Color hint = Color(0xFF757575);
  const Color border = Color(0xFFE0DCD6);

  Widget app(Widget child, {Locale locale = const Locale('en')}) {
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
          const Center(
            child: SizedBox(width: 360, child: HomeAiSearchField()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Container field = tester.widget<Container>(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Container &&
              w.constraints?.minHeight == 56 &&
              w.decoration is BoxDecoration,
        ),
      );
      final BoxDecoration decoration = field.decoration! as BoxDecoration;

      expect(tester.getSize(find.byType(HomeAiSearchField)).height, 56);
      expect(decoration.color, surface);
      expect(decoration.boxShadow, isEmpty);
      expect(decoration.border, isA<Border>());
      final Border boxBorder = decoration.border! as Border;
      expect(boxBorder.top.color, border);
      expect(boxBorder.top.width, 1);
      expect(
        decoration.borderRadius,
        equals(BorderRadius.circular(32)),
      );

      // Leading search glyph in the accent, on the leading edge of the field.
      final Icon leading = tester.widget<Icon>(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Icon && w.icon == Icons.search_rounded && w.size == 22,
        ),
      );
      expect(leading.color, accent);
      final Rect glyph = tester.getRect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Icon && w.icon == Icons.search_rounded && w.size == 22,
        ),
      );
      final Rect textField = tester.getRect(find.byType(TextField));
      expect(glyph.right, lessThanOrEqualTo(textField.left));

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
          const Center(
            child: SizedBox(width: 360, child: HomeAiSearchField()),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('ابحث عن وجهات وفنادق والمزيد'),
        findsOneWidget,
      );
      expect(
        find.text('Search destinations, hotels & more'),
        findsNothing,
      );
      expect(
        Directionality.of(
          tester.element(find.byType(HomeAiSearchField)),
        ),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('quick action cards', () {
    testWidgets('six spec tiles on one row', (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        app(const SizedBox(width: 360, child: HomeNavButtons())),
      );
      await tester.pumpAndSettle();

      final Finder tiles = find.descendant(
        of: find.byType(HomeNavButtons),
        matching: find.byType(AnimatedContainer),
      );
      expect(tiles, findsNWidgets(6));

      final List<String> labels = <String>[
        'Flights',
        'Stays',
        'Cars Rental',
        'Activities',
        'Groups',
        'Trips',
      ];
      final List<IconData> icons = <IconData>[
        Icons.flight_takeoff_rounded,
        Icons.hotel_rounded,
        Icons.directions_car_rounded,
        Icons.beach_access_rounded,
        Icons.groups_rounded,
        Icons.luggage_rounded,
      ];

      double previousRight = double.negativeInfinity;
      for (int i = 0; i < 6; i++) {
        final Finder tileFinder = tiles.at(i);
        final AnimatedContainer tile = tester.widget<AnimatedContainer>(
          tileFinder,
        );
        final BoxDecoration decoration = tile.decoration! as BoxDecoration;

        expect(tester.getSize(tileFinder).height, 68);
        expect(decoration.color, surface);
        expect(decoration.boxShadow, isEmpty);
        expect(
          decoration.borderRadius,
          equals(BorderRadius.circular(16)),
        );
        final Border boxBorder = decoration.border! as Border;
        expect(boxBorder.top.color, border);
        expect(boxBorder.top.width, 1);

        final Icon icon = tester.widget<Icon>(
          find.descendant(of: tileFinder, matching: find.byType(Icon)).first,
        );
        expect(icon.icon, icons[i]);
        expect(icon.size, 25);
        expect(icon.color, accent);

        final Text label = tester.widget<Text>(find.text(labels[i]));
        expect(label.style?.fontSize, 12);
        expect(label.style?.fontWeight, FontWeight.w600);
        expect(label.style?.color, accent);

        // The 6dp glyph-to-label gap.
        final double iconBottom = tester
            .getRect(
              find.descendant(
                of: tileFinder,
                matching: find.byType(Icon),
              ).first,
            )
            .bottom;
        final double labelTop = tester.getRect(find.text(labels[i])).top;
        expect(labelTop - iconBottom, closeTo(6, 0.01));

        // Balanced row: each tile starts after the previous one ends.
        final Rect rect = tester.getRect(tileFinder);
        expect(rect.left, greaterThan(previousRight));
        previousRight = rect.right;
      }

      // Equal, responsive widths.
      final List<double> widths = <double>[
        for (int i = 0; i < 6; i++) tester.getRect(tiles.at(i)).width,
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
      expect(find.text('أنشطة'), findsOneWidget);
      expect(find.text('الجروبات'), findsOneWidget);
      expect(find.text('رحلاتي'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(HomeNavButtons))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the Home design palette is exposed as tokens', (
    tester,
  ) async {
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
}
