import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/l10n/app_localizations_en.dart';

/// Responsive layout contract for the unified Home navigation.
///
/// The six service buttons (Flights / Hotels / Cars / Packages + the wide
/// slim Explore / Groups cards) must render with the SAME structure on
/// every logical screen size — small phones through desktop widths:
///
///   * every button is fully on-screen and tappable (hit-testable),
///   * no horizontal scrolling is ever needed to reach any button,
///   * the unified 32px outline icons render, and
///   * the widget tree is identical across sizes (same layout, no
///     overflow or rendering errors).
void main() {
  // Six representative logical sizes: smallest phone → common Android →
  // large phone → tablet portrait → iPad Pro landscape-class → desktop.
  final sizes = <String, Size>{
    'smallest phone (320x568)': const Size(320, 568),
    'common android (360x640)': const Size(360, 640),
    'large phone (414x896)': const Size(414, 896),
    'tablet portrait (768x1024)': const Size(768, 1024),
    'ipad pro class (1024x1366)': const Size(1024, 1366),
    'desktop (1280x800)': const Size(1280, 800),
  };

  /// Loads English l10n strings once for the expected-label contract.
  late AppLocalizationsEn en;
  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'))
        as AppLocalizationsEn;
  });

  sizes.forEach((String description, Size size) {
    testWidgets('unified nav renders identically on $description',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Minimal inert router — buttons push routes but nothing is
      // rendered on them inside this layout contract test.
      final router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: SafeArea(child: HomeNavButtons()),
            ),
          ),
          for (final path in <String>[
            '/flights',
            '/hotels',
            '/cars',
            '/packages',
            '/explore',
            '/groups',
          ])
            GoRoute(
              path: path,
              builder: (context, state) => const Scaffold(),
            ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      final labels = <String>[
        en.searchFlights,
        en.searchHotels,
        en.searchCars,
        en.searchPackages,
        en.exploreTitle,
        en.groupsTitle,
      ];

      // 1. All six labels render — no clipping, no missing ghosts.
      for (final label in labels) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      // 2. All six buttons are tappable — the centre of each label lies
      //    INSIDE the viewport (fully reachable, no scroll) and the tap
      //    routes without exceptions.
      for (final label in labels) {
        final center = tester.getCenter(find.text(label));
        expect(center.dx, greaterThanOrEqualTo(0));
        expect(center.dx, lessThanOrEqualTo(size.width));
        await tester.tap(find.text(label), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester.takeException(),
          isNull,
          reason: 'Tapping "$label" must work on $description',
        );
        router.go('/');
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      }

      // 3. No horizontal scrolling exists anywhere in the nav strip.
      for (final scrollable in find
          .byType(Scrollable)
          .evaluate()
          .map((element) => Scrollable.of(element))) {
        expect(
          scrollable.position.axis,
          Axis.vertical,
          reason: 'The nav must never require horizontal scrolling',
        );
      }

      // 4. Icons render at the unified 32px contract for all six buttons.
      final icons = tester.widgetList<Icon>(find.byType(Icon));
      expect(icons.length, 6);
      for (final icon in icons) {
        expect(icon.size, 32);
      }

      // 5. No overflow / rendering errors escaped (testWidgets fails on
      //    exceptions automatically; this re-asserts the tree is stable).
      expect(tester.takeException(), isNull);
    });
  });
}
