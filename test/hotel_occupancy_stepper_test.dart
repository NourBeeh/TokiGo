import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/domain/models/search/hotel_room_occupancy.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/compact_step_button.dart';
import 'package:tokigo/core/widgets/compact_stepper_row.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/search/presentation/pages/hotel_search_page.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/shared/providers/locale_provider.dart';

/// The hotel occupancy selector (owner decision, 2026-11).
///
/// The SAME shared [CompactStepperRow] the flight passenger sheet uses, so the
/// two selectors are one control:
/// * one row per occupant kind per room, with the shared disabled states;
/// * multiple rooms, each with its own adults/children and child ages;
/// * the occupancy model's serialization round-trips every room and age.
Future<GoRouter> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      authUserProvider.overrideWith((ref) => null),
      geoCountryProvider.overrideWith((ref) async => null),
      currencyProvider.overrideWith(() => CurrencyController()),
    ],
  );
  addTearDown(container.dispose);

  final GoRouter router = GoRouter(
    initialLocation: '/search',
    routes: <RouteBase>[
      GoRoute(
        path: '/search',
        builder: (BuildContext context, GoRouterState state) =>
            const HotelSearchPage(),
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: const <Locale>[Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// The colour of the icon inside the [index]th stepper button.
bool _enabledAt(WidgetTester tester, int index) =>
    tester
        .widget<Icon>(
          find.descendant(
            of: find.byType(CompactStepButton).at(index),
            matching: find.byType(Icon),
          ),
        )
        .color ==
    TokiGoColors.light().brand;

void main() {
  testWidgets('the occupancy card uses the shared stepper rows', (tester) async {
    await _pumpPage(tester);

    // One room: one adults row and one children row.
    expect(find.byType(CompactStepperRow), findsNWidgets(2));
    expect(find.text('Adults'), findsOneWidget);
    expect(find.text('Children'), findsOneWidget);

    // Room 1 defaults to 2 adults, no children: the adult minus is live and
    // the children minus is at its floor.
    expect(_enabledAt(tester, 0), isTrue);
    expect(_enabledAt(tester, 1), isTrue);
    expect(_enabledAt(tester, 2), isFalse);
    expect(_enabledAt(tester, 3), isTrue);

    expect(find.text('1 room · 2 guests · 0 children'), findsOneWidget);
  });

  testWidgets('a second room gets its own rows and its own constraints', (
    tester,
  ) async {
    await _pumpPage(tester);

    await tester.tap(find.byTooltip('Add room'));
    await tester.pumpAndSettle();

    // Two rooms × two occupant kinds.
    expect(find.byType(CompactStepperRow), findsNWidgets(4));

    // Room 2 starts at one adult: its minus is disabled.
    expect(_enabledAt(tester, 4), isFalse); // room 2 adults minus
    expect(_enabledAt(tester, 5), isTrue); // room 2 adults plus
    expect(_enabledAt(tester, 6), isFalse); // room 2 children minus
    expect(_enabledAt(tester, 7), isTrue); // room 2 children plus

    // Room 1's own rows are untouched.
    expect(_enabledAt(tester, 0), isTrue);
    expect(_enabledAt(tester, 2), isFalse);
  });

  testWidgets('a child added in a room keeps its age dropdown', (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.byType(CompactStepButton).at(3)); // room 1 children +
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<int>), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('1 room · 2 guests · 1 child'), findsOneWidget);
  });

  test('the occupancy model round-trips every room and child age', () {
    const HotelRoomOccupancy room = HotelRoomOccupancy(
      adults: 2,
      childAges: <int>[5, 8],
    );
    final Map<String, dynamic> json = room.toJson();

    expect(json, <String, dynamic>{'adults': 2, 'childAges': <int>[5, 8]});
    expect(HotelRoomOccupancy.fromJson(json), room);
    expect(HotelRoomOccupancy.fromJson(json).children, 2);
  });
}
