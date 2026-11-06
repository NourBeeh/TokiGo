// Router-level restore tests (Task 11 / regression 5).
//
// These build the REAL router the way `main()` does — the saved resume
// location is injected through `savedResumeLocationProvider` before the first
// frame — and assert where a cold start lands.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:tokigo/app/config/app_config.dart';
import 'package:tokigo/app/providers/resume_providers.dart';
import 'package:tokigo/app/router/go_router_config.dart';
import 'package:tokigo/core/auth/auth_controller.dart';
import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/auth/auth_repository.dart';
import 'package:tokigo/core/auth/user_model.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/navigation/resume_destination.dart';
import 'package:tokigo/core/storage/resume_destination_store.dart';
import 'package:tokigo/shared/providers/onboarding_provider.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// The smallest [AuthRepository] that can sign in and out.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<ApiResult<AuthUser>> login(AuthCredentials credentials) async =>
      ApiResult<AuthUser>.success(
        const AuthUser(id: 'u1', email: 't@example.com'),
      );

  @override
  Future<ApiResult<AuthUser>> register(RegistrationData data) async =>
      ApiResult<AuthUser>.success(
        const AuthUser(id: 'u1', email: 't@example.com'),
      );

  @override
  Future<ApiResult<AuthUser>> signInWithGoogle(String idToken) async =>
      ApiResult<AuthUser>.success(
        const AuthUser(id: 'u1', email: 't@example.com'),
      );

  @override
  Future<ApiResult<AuthUser>> updateProfile(AuthUser user) async =>
      ApiResult<AuthUser>.success(user);

  @override
  Future<ApiResult<void>> logout() async => const ApiResult<void>.success(null);

  @override
  Future<ApiResult<AuthUser?>> currentSession() async =>
      ApiResult<AuthUser?>.success(null);
}

/// The real router, with the onboarding gate already satisfied.
GoRouter _buildRouter({
  String? savedResume,
  AuthController? authController,
}) {
  final OnboardingController onboarding = OnboardingController.pinned(
    const OnboardingState(seen: true, ready: true),
  );
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      onboardingProvider.overrideWith((ref) => onboarding),
      savedResumeLocationProvider.overrideWithValue(savedResume),
      if (authController != null)
        authControllerProvider.overrideWith((ref) => authController),
    ],
  );
  addTearDown(container.dispose);
  return container.read(goRouterProvider);
}

/// The location the router was created with — i.e. where a cold start lands,
/// before any redirect runs.
String _initialLocation(GoRouter router) =>
    router.routeInformationProvider.value.uri.toString();

void main() {
  final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding
      .ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('tokigo_resume_router_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    binding.platformDispatcher.defaultRouteNameTestValue = '/';
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

  group('cold start while Home is disabled', () {
    test('no saved value lands on the default browse page', () {
      expect(_initialLocation(_buildRouter()), kDefaultResumePath);
    });

    test('a saved valid location is restored exactly', () {
      expect(_initialLocation(_buildRouter(savedResume: '/hotels')), '/hotels');
      expect(_initialLocation(_buildRouter(savedResume: '/bag')), '/bag');
      expect(
        _initialLocation(_buildRouter(savedResume: '/bag?section=likes')),
        '/bag?section=likes',
      );
    });

    test('a stale or unknown saved path falls back to the default', () {
      expect(
        _initialLocation(_buildRouter(savedResume: '/')),
        kDefaultResumePath,
      );
      expect(
        _initialLocation(_buildRouter(savedResume: '/onboarding')),
        kDefaultResumePath,
      );
      expect(
        _initialLocation(_buildRouter(savedResume: '/booking/review')),
        kDefaultResumePath,
      );
      expect(
        _initialLocation(_buildRouter(savedResume: 'flights')),
        kDefaultResumePath,
      );
    });

    test('a destination needing a session falls back while signed out', () {
      expect(
        _initialLocation(_buildRouter(savedResume: '/profile')),
        kDefaultResumePath,
      );
    });

    test('a platform deep link overrides the resume target', () {
      // The app leaves `overridePlatformDefaultLocation` at its default, so
      // the platform's initial location wins over the router's fallback.
      binding.platformDispatcher.defaultRouteNameTestValue = '/hotels';
      expect(_initialLocation(_buildRouter()), '/hotels');
      expect(
        _initialLocation(_buildRouter(savedResume: '/bag')),
        '/hotels',
      );
    });
  });

  group('homeEnabled flipped back to true', () {
    test('Home is the initial route again', () {
      // The flag is a const, so the decision is covered where it is pure.
      expect(initialLocationFor(homeEnabled: true, savedResume: '/hotels'), '/');
      expect(initialLocationFor(homeEnabled: true, savedResume: null), '/');
      expect(AppConfig.homeEnabled, isFalse);
    });
  });

  test('signing out clears the saved resume destination', () async {
    await ResumeDestinationStore.write('/hotels');
    final AuthController controller = AuthController(_FakeAuthRepository());

    // Reading the provider is what wires the auth listener.
    _buildRouter(authController: controller);
    expect(await ResumeDestinationStore.read(), '/hotels');

    await controller.login(email: 't@example.com', password: 'secret');
    expect(await ResumeDestinationStore.read(), '/hotels');

    await controller.logout();
    await _untilCleared();
    expect(await ResumeDestinationStore.read(), isNull);
  });
}

/// The auth listener clears the store without awaiting it, so give the write a
/// moment to land before asserting.
Future<void> _untilCleared() async {
  for (int i = 0; i < 100; i++) {
    if (await ResumeDestinationStore.read() == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
