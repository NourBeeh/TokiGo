import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/profile/presentation/pages/onboarding_page.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/onboarding_provider.dart';

Widget _app(Widget child, {ThemeData? theme}) {
  // The widget under test is the first-launch hero; pin the gate so the test
  // never depends on Hive state left by another test.
  return ProviderScope(
    overrides: <Override>[
      onboardingProvider.overrideWith(
        (Ref ref) => OnboardingController.pinned(
          const OnboardingState(seen: false, ready: true),
        ),
      ),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    ),
  );
}

void _phoneSize(WidgetTester tester, {int width = 390}) {
  tester.view.physicalSize = Size(width * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder get _servicePlates => find.byWidgetPredicate(
  (Widget widget) =>
      widget is Container &&
      widget.key is ValueKey<String> &&
      (widget.key as ValueKey<String>).value.startsWith('onboarding-service-'),
);

void main() {
  testWidgets('the startup four-up uses Home glyphs, size and spacing', (
    tester,
  ) async {
    _phoneSize(tester);
    await tester.pumpWidget(_app(const OnboardingPage()));
    await tester.pumpAndSettle();

    expect(_servicePlates, findsNWidgets(4));

    final List<Rect> rects = <Rect>[
      for (int i = 0; i < 4; i++) tester.getRect(_servicePlates.at(i)),
    ];
    for (final Rect rect in rects) {
      expect(rect.width, 68, reason: 'startup tiles must match HomeActionTile');
      expect(rect.height, 68);
    }
    for (int i = 1; i < rects.length; i++) {
      expect(
        rects[i].left - rects[i - 1].right,
        HomeActionBar.gap,
        reason: 'startup tiles must use HomeActionBar.gap',
      );
    }
    expect(rects.first.left, closeTo(rects.last.right - 4 * 68 - 3 * 16, 0.01));

    final List<IconData> expectedIcons = <IconData>[
      Icons.flight_rounded,
      Icons.home_rounded,
      Icons.directions_car_rounded,
    ];
    for (int i = 0; i < expectedIcons.length; i++) {
      final Finder glyph = find.descendant(
        of: _servicePlates.at(i),
        matching: find.byType(Icon),
      );
      expect(glyph, findsOneWidget);
      final Icon icon = tester.widget<Icon>(glyph);
      expect(icon.icon, expectedIcons[i]);
      expect(icon.size, HomeActionTile.iconSize);
    }

    // Owner follow-up: the fourth Home action keeps the parasol — this tile
    // is the only exception to the white-wordmark brand.
    final Finder mark = find.descendant(
      of: _servicePlates.at(3),
      matching: find.byType(Image),
    );
    expect(mark, findsOneWidget);
    final Image image = tester.widget<Image>(mark);
    expect(image.width, HomeActionTile.iconSlotHeight);
    expect(
      (image.image as AssetImage).assetName,
      HomeActionGlyph.parasolAsset(tester.element(_servicePlates.at(3))),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow phones shrink the four tiles evenly', (tester) async {
    _phoneSize(tester, width: 320);
    await tester.pumpWidget(_app(const OnboardingPage()));
    await tester.pumpAndSettle();

    expect(_servicePlates, findsNWidgets(4));
    final List<Rect> rects = <Rect>[
      for (int i = 0; i < 4; i++) tester.getRect(_servicePlates.at(i)),
    ];
    expect(
      rects.every((Rect rect) => rect.width < HomeActionTile.height),
      isTrue,
    );
    expect(rects.map((Rect rect) => rect.width).toSet().length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero slides use the enlarged 64dp standalone glyph', (
    tester,
  ) async {
    _phoneSize(tester);
    await tester.pumpWidget(_app(const OnboardingPage()));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    final Icon icon = tester.widget<Icon>(
      find.byIcon(Icons.auto_awesome_rounded),
    );
    expect(icon.size, 64);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark mode uses Home dark parasol asset', (tester) async {
    _phoneSize(tester);
    await tester.pumpWidget(
      _app(const OnboardingPage(), theme: AppTheme.dark()),
    );
    await tester.pumpAndSettle();

    final Finder mark = find.descendant(
      of: _servicePlates.at(3),
      matching: find.byType(Image),
    );
    final Image image = tester.widget<Image>(mark);
    expect(
      (image.image as AssetImage).assetName,
      'assets/icon/packages_parasol_dark_1024.png',
    );
  });
}
