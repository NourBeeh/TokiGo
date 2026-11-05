import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/domain/home_action.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/l10n/app_localizations.dart';

Widget _app(Widget child, {Locale locale = const Locale('en'), double width = 320}) {
  return MaterialApp(
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
      body: Center(child: SizedBox(width: width, child: child)),
    ),
  );
}

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(780, 1400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

List<AnimatedContainer> _tiles(WidgetTester tester) {
  return tester
      .widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(HomeActionBar),
          matching: find.byType(AnimatedContainer),
        ),
      )
      .toList();
}

void main() {
  testWidgets('keeps the original card design at a fixed size', (tester) async {
    _phoneSize(tester);
    // Wide enough to lay out all six tiles at once (the real Home row is a
    // lazy horizontal list, so a 320dp viewport builds only the first five).
    await tester.pumpWidget(
      _app(HomeActionBar(onActionSelected: (_) {}), width: 640),
    );
    await tester.pumpAndSettle();

    final Finder tileFinders = find.descendant(
      of: find.byType(HomeActionBar),
      matching: find.byType(AnimatedContainer),
    );
    expect(tileFinders, findsNWidgets(6));

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

    for (int i = 0; i < 6; i++) {
      final Finder tile = tileFinders.at(i);
      final BoxDecoration decoration =
          tester.widget<AnimatedContainer>(tile).decoration! as BoxDecoration;

      expect(tester.getSize(tile).height, 68);
      expect(tester.getSize(tile).width, HomeActionBar.cardWidth);
      expect(decoration.color, HomeDesignTokens.surface);
      expect(decoration.boxShadow, isEmpty);
      expect(decoration.borderRadius, BorderRadius.circular(16));
      final Border border = decoration.border! as Border;
      expect(border.top.color, HomeDesignTokens.border);
      expect(border.top.width, 1);

      final Icon icon = tester.widget<Icon>(
        find.descendant(of: tile, matching: find.byType(Icon)).first,
      );
      expect(icon.icon, icons[i]);
      expect(icon.size, 25);
      expect(icon.color, HomeDesignTokens.accent);

      final Text label = tester.widget<Text>(find.text(labels[i]));
      expect(label.style?.fontSize, 12);
      expect(label.style?.fontWeight, FontWeight.w600);
      expect(label.style?.color, HomeDesignTokens.accent);

      final double iconBottom = tester
          .getRect(find.descendant(of: tile, matching: find.byType(Icon)).first)
          .bottom;
      final double labelTop = tester.getRect(find.text(labels[i])).top;
      expect(labelTop - iconBottom, closeTo(6, 0.01));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolls horizontally and hides the hint at the end', (
    tester,
  ) async {
    _phoneSize(tester);
    await tester.pumpWidget(_app(HomeActionBar(onActionSelected: (_) {})));
    await tester.pumpAndSettle();

    final Finder bar = find.byKey(const ValueKey<String>('home-action-bar'));
    final ListView list = tester.widget<ListView>(bar);
    expect(list.scrollDirection, Axis.horizontal);

    // Six fixed-width cards exceed the 320dp viewport, so the trailing cue is
    // shown and the row can travel.
    expect(
      find.byKey(const ValueKey<String>('home-action-bar-overflow')),
      findsOneWidget,
    );

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.descendant(of: bar, matching: find.byType(Scrollable)),
    );
    await tester.drag(bar, const Offset(-220, 0));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(0));
    expect(
      find.byKey(const ValueKey<String>('home-action-bar-overflow')),
      findsNothing,
    );
  });

  testWidgets('a wide viewport shows every card without a hint', (
    tester,
  ) async {
    // A genuinely wide viewport (700dp logical): the six cards plus their gaps
    // total 448dp, so they all fit and the trailing cue must disappear.
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              child: HomeActionBar(onActionSelected: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('home-action-bar-overflow')),
      findsNothing,
    );
    // Cards keep the same 68dp width instead of stretching.
    for (final AnimatedContainer tile in _tiles(tester)) {
      expect(tester.getSize(find.byWidget(tile)).width, 68);
    }
  });

  testWidgets('is data-driven and taps switch content without navigation', (
    tester,
  ) async {
    _phoneSize(tester);
    HomeAction? selected;
    await tester.pumpWidget(
      _app(HomeActionBar(onActionSelected: (action) => selected = action)),
    );
    await tester.pumpAndSettle();

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(HomeActionBar)),
    )!;
    final List<HomeActionDefinition> definitions = homeActionDefinitions(l10n);
    expect(definitions.length, 6);
    expect(
      definitions.map((definition) => definition.action).toList(),
      HomeAction.values,
    );

    final ListView list = tester.widget<ListView>(
      find.byKey(const ValueKey<String>('home-action-bar')),
    );
    final SliverChildBuilderDelegate delegate =
        list.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.estimatedChildCount, definitions.length);

    await tester.tap(
      find.byKey(const ValueKey<String>('home-action-hotels')),
      warnIfMissed: true,
    );
    await tester.pumpAndSettle();
    expect(selected, HomeAction.hotels);
  });

  testWidgets('Arabic mirrors the bar and scrolls toward the later cards', (
    tester,
  ) async {
    _phoneSize(tester);
    await tester.pumpWidget(
      _app(HomeActionBar(onActionSelected: (_) {}), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('طيران'), findsOneWidget);
    expect(find.text('إقامات'), findsOneWidget);
    expect(find.text('أنشطة'), findsOneWidget);
    expect(find.text('الجروبات'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(HomeActionBar))),
      TextDirection.rtl,
    );

    final Finder bar = find.byKey(const ValueKey<String>('home-action-bar'));
    final Finder tiles = find.descendant(
      of: find.byType(HomeActionBar),
      matching: find.byType(AnimatedContainer),
    );
    // RTL starts at the right: Flights is the right-most card.
    expect(
      tester.getRect(tiles.at(0)).right,
      greaterThan(tester.getRect(tiles.at(1)).right),
    );

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.descendant(of: bar, matching: find.byType(Scrollable)),
    );
    await tester.drag(bar, const Offset(220, 0));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
    // The lazy row builds the last tile only once the row travels.
    expect(find.text('رحلاتي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
