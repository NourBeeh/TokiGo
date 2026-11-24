import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/geo/city_selection.dart';
import 'package:tokigo/core/geo/location_permission_providers.dart';
import 'package:tokigo/core/geo/location_permission_service.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/features/home/presentation/widgets/location_permission_card.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The permission can change while the app is in the background: the traveller
/// leaves for the OS settings screen, grants access, and comes back. The card
/// caches the permission in a [FutureProvider], so without a lifecycle refresh
/// it would keep showing "Enable location" for the rest of the session.
Widget _host({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: LocationPermissionCard()),
    ),
  );
}

List<Override> _overrides({required void Function() onCheck}) {
  return <Override>[
    offlineCacheProvider.overrideWithValue(MemoryOfflineCache()),
    hasManualCityProvider.overrideWithValue(false),
    locationAccessProvider.overrideWith((ref) {
      onCheck();
      return Future<LocationAccess>.value(LocationAccess.denied);
    }),
  ];
}

void main() {
  testWidgets('returning from the background re-checks the permission', (
    tester,
  ) async {
    int checks = 0;
    await tester.pumpWidget(_host(overrides: _overrides(onCheck: () => checks++)));
    await tester.pump();

    expect(find.text('Enable location'), findsOneWidget);
    final int afterMount = checks;
    expect(afterMount, 1);

    // Leave for the OS settings screen and come back.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(checks, afterMount + 1);
  });

  testWidgets('going to the background alone does not re-check', (
    tester,
  ) async {
    int checks = 0;
    await tester.pumpWidget(_host(overrides: _overrides(onCheck: () => checks++)));
    await tester.pump();
    final int afterMount = checks;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(checks, afterMount);
  });
}
