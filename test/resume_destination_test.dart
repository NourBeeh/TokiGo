import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:tokigo/app/config/app_config.dart';
import 'package:tokigo/core/navigation/resume_destination.dart';
import 'package:tokigo/core/storage/resume_destination_store.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Points `path_provider` at a temp dir so the real Hive box can be opened in
/// a test isolate (the platform channel is otherwise unavailable).
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Minimal harness exposing the app's localizations so the domain-level
/// resolution can be tested without launching the shell.
Widget _app(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('tokigo_resume_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    await ResumeDestinationStore.clear();
  });

  tearDownAll(() async {
    try {
      await Hive.deleteFromDisk();
    } catch (_) {
      // A box that never opened has nothing to delete.
    }
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // Best-effort cleanup only.
    }
  });

  group('ResumeDestinationStore', () {
    test('returns null when nothing has been persisted', () async {
      expect(await ResumeDestinationStore.read(), isNull);
    });

    test('writes and reads back the destination (restore)', () async {
      await ResumeDestinationStore.write('/flights');
      expect(await ResumeDestinationStore.read(), '/flights');

      await ResumeDestinationStore.write('/hotels');
      expect(await ResumeDestinationStore.read(), '/hotels');
    });

    test('clears the saved destination on logout', () async {
      await ResumeDestinationStore.write('/flights');
      await ResumeDestinationStore.clear();
      expect(await ResumeDestinationStore.read(), isNull);
    });

    test('does not throw when storage is unavailable (best-effort)', () async {
      // The public contract of the store is that write/read never propagate a
      // storage failure to the caller.
      expect(
        () async => await ResumeDestinationStore.write('/flights'),
        returnsNormally,
      );
      expect(
        () async => await ResumeDestinationStore.read(),
        returnsNormally,
      );
    });
  });

  group('isSavableResumeLocation', () {
    test('accepts the allowlisted top-level browse destinations', () {
      for (final String path in kSavableResumePaths) {
        expect(isSavableResumeLocation(path), isTrue, reason: path);
      }
    });

    test('rejects the booking funnel, offer details, onboarding, auth, root and standalone pages', () {
      for (final String path in <String>[
        '/booking/review',
        '/booking/summary',
        '/booking/confirm',
        '/offer/123',
        '/policy',
        '/onboarding',
        '/login',
        '/profile',
        '/wishlist',
        '/notifications',
        '/',
      ]) {
        expect(isSavableResumeLocation(path), isFalse, reason: path);
      }
    });

    test('Profile and Wishlist are standalone pages, never a cold-start target', () {
      // They behave like Notifications: reachable from the header, never
      // restored. Reopening on them would drop the traveller into an account
      // page with no service context.
      expect(isSavableResumeLocation('/profile'), isFalse);
      expect(isSavableResumeLocation('/wishlist'), isFalse);
      expect(sanitizeResumeLocation('/profile'), '');
      expect(sanitizeResumeLocation('/wishlist'), '');
    });

    test('kTopBarPaths is exactly the six service paths', () {
      expect(kTopBarPaths, <String>{
        '/flights',
        '/hotels',
        '/cars',
        '/packages',
        '/groups',
        '/bag',
      });
      // Profile and Wishlist keep their own header + back button.
      expect(kTopBarPaths, isNot(contains('/profile')));
      expect(kTopBarPaths, isNot(contains('/wishlist')));
    });

    test('homeRoute resolves to Home only while Home is enabled', () {
      expect(homeRoute(homeEnabled: true), '/');
      expect(homeRoute(homeEnabled: false), kDefaultResumePath);
      // The build-time default follows the flag.
      expect(homeRoute(), AppConfig.homeEnabled ? '/' : kDefaultResumePath);
      expect(AppConfig.homeEnabled, isFalse);
    });

    test('accepts query parameters but keeps the path leading edge', () {
      expect(isSavableResumeLocation('/flights?tab=radar'), isTrue);
      expect(isSavableResumeLocation('/flights?section=likes'), isTrue);
      expect(isSavableResumeLocation('/hotels?sort=price'), isTrue);
    });

    test('rejects a missing value, a path without a leading slash and empty', () {
      expect(isSavableResumeLocation(null), isFalse);
      expect(isSavableResumeLocation(''), isFalse);
      expect(isSavableResumeLocation('flights'), isFalse);
    });
  });

  group('sanitizeResumeLocation', () {
    test('keeps an allowlisted parameter with an allowlisted value', () {
      expect(sanitizeResumeLocation('/bag?section=likes'), '/bag?section=likes');
      expect(sanitizeResumeLocation('/bag?section=trips'), '/bag?section=trips');
    });

    test('drops a parameter that is not allowlisted for the route', () {
      expect(sanitizeResumeLocation('/bag?id=123'), '/bag');
      expect(sanitizeResumeLocation('/flights?tab=radar'), '/flights');
      expect(sanitizeResumeLocation('/hotels?sort=price'), '/hotels');
    });

    test('drops an allowlisted parameter carrying a foreign value', () {
      expect(sanitizeResumeLocation('/bag?section=evil'), '/bag');
    });

    test('keeps only the safe parameters when several are present', () {
      expect(
        sanitizeResumeLocation('/bag?section=likes&id=123'),
        '/bag?section=likes',
      );
    });

    test('yields an empty string for a path that is not savable', () {
      expect(sanitizeResumeLocation('/onboarding?x=1'), '');
      expect(sanitizeResumeLocation('/booking/review?offer=9'), '');
      expect(sanitizeResumeLocation('flights'), '');
      expect(sanitizeResumeLocation(''), '');
    });
  });

  group('resolveResumeTarget (restore on launch)', () {
    test('reopens the saved browse destination', () {
      expect(resolveResumeTarget('/hotels'), '/hotels');
      expect(resolveResumeTarget('/bag'), '/bag');
    });

    test('falls back to the default when nothing valid was saved', () {
      // First install, a stale entry, or a path that no longer exists.
      expect(resolveResumeTarget(null), kDefaultResumePath);
      expect(resolveResumeTarget(''), kDefaultResumePath);
      expect(resolveResumeTarget('/onboarding'), kDefaultResumePath);
      expect(resolveResumeTarget('/booking/review'), kDefaultResumePath);
      expect(resolveResumeTarget('flights'), kDefaultResumePath);
    });

    test('the default is itself an allowlisted destination', () {
      expect(kDefaultResumePath, '/flights');
      expect(isSavableResumeLocation(kDefaultResumePath), isTrue);
    });
  });

  group('ResumeDestinationVisual.forPath', () {
    testWidgets('resolves the glyph and label for a path', (tester) async {
      await tester.pumpWidget(_app(const SizedBox()));
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold)),
      )!;

      for (final String path in <String>[
        '/flights',
        '/hotels',
        '/cars',
        '/packages',
        '/groups',
        '/bag',
        '/profile',
        '/wishlist',
        '/unknown',
      ]) {
        final ResumeDestinationVisual visual =
            ResumeDestinationVisual.forPath(path, l10n);
        expect(visual.icon, isNotNull, reason: path);
        expect(visual.label, isNotEmpty, reason: path);
      }

      // Unknown paths fall back to the Flights glyph/label.
      final ResumeDestinationVisual fallback =
          ResumeDestinationVisual.forPath('/unknown', l10n);
      expect(fallback.icon, Icons.flight_takeoff_rounded);
      expect(fallback.label, l10n.searchFlights);
    });

    testWidgets('localizes the label (English + Arabic)', (tester) async {
      await tester.pumpWidget(_app(const SizedBox()));
      final AppLocalizations en = AppLocalizations.of(
        tester.element(find.byType(Scaffold)),
      )!;
      await tester.pumpWidget(
        _app(const SizedBox(), locale: const Locale('ar')),
      );
      final AppLocalizations ar = AppLocalizations.of(
        tester.element(find.byType(Scaffold)),
      )!;

      expect(ResumeDestinationVisual.forPath('/bag', en).label, en.myTrips);
      expect(ResumeDestinationVisual.forPath('/bag', ar).label, ar.myTrips);
      expect(
        ResumeDestinationVisual.forPath('/bag', ar).label,
        isNot(ResumeDestinationVisual.forPath('/bag', en).label),
      );
    });
  });
}
