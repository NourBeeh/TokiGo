// Regression cover: the empty/offline Home states must lay out at all.
// `SliverFillRemaining` + `LayoutBuilder` used to throw "does not support
// returning intrinsic dimensions" once a trailing sliver followed it.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';
import 'package:tokigo/features/home/presentation/pages/home_page.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

List<HomeSection> _sections() => const <HomeSection>[];

List<HomeItem> _hotels() => const <HomeItem>[];

class _Repo implements HomeRepository {
  _Repo({this.sections, this.hotels});

  final List<HomeSection>? sections;
  final List<HomeItem>? hotels;

  @override
  Future<List<HomeSection>?> readHomeSnapshot({required String audience}) async =>
      null;

  @override
  Future<void> clearHomeSnapshot({required String audience}) async {}

  @override
  Future<void> saveHomeSnapshot(
    List<HomeSection> sections, {
    required String audience,
  }) async {}

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() async =>
      ApiResult<List<HomeSection>>.success(sections ?? _sections());

  @override
  Future<ApiResult<List<HomeItem>>> getRecommendedHotels({
    int limit = 6,
    String? countryCode,
    String languageCode = 'en',
    String? currency,
  }) async => ApiResult<List<HomeItem>>.success(hotels ?? _hotels());

  @override
  Future<ApiResult<void>> refresh() async => const ApiResult<void>.success(null);

  @override
  Future<SnapshotState> snapshotState({required String audience}) async =>
      SnapshotState.unavailable;
}

HomeController _controller({List<HomeSection>? sections, List<HomeItem>? hotels}) =>
    HomeController(
      _Repo(sections: sections, hotels: hotels),
      audience: 'anon',
      contextBuilder: (_) async =>
          const HomeCompositionContext(userState: HomeUserState.freshAnonymous),
      liveValidation: null,
      countryCode: null,
      languageCode: null,
      currencyCode: null,
    );

Widget _app({required HomeController controller}) => ProviderScope(
  overrides: <Override>[
    homeControllerProvider.overrideWith((ref) => controller),
    geoCountryProvider.overrideWith((ref) async => null),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ThemeMode.light,
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const HomePage(),
  ),
);

void main() {
  testWidgets('empty Home state lays out (no intrinsic-dimensions crash)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(controller: _controller()));
    await tester.pumpAndSettle();

    // The empty message renders and no layout exception was thrown.
    expect(find.text('No recommendations right now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the empty state keeps clear of the floating pill', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(controller: _controller()));
    await tester.pumpAndSettle();

    final Rect message = tester.getRect(find.text('No recommendations right now'));
    final Rect pill = tester.getRect(
      find.byKey(const ValueKey<String>('home-ai-composer')),
    );
    expect(message.bottom, lessThan(pill.top));
    expect(tester.takeException(), isNull);
  });
}
