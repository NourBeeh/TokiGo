import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/core/repositories/impl/home_repository_impl.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';

/// Scripted fake used across the controller tests.
///
/// Snapshot storage: the fake mirrors the real repository's snapshot layer
/// exactly — same public codec functions ([homeSectionToMap]
/// / [homeSectionsFromMap]) and the same v2 envelope written to a
/// [MemoryOfflineCache] under the same audience-scoped key. That keeps the
/// tests honest about the real persistence shape without an HTTP client.
class FakeHomeRepo implements HomeRepository {
  FakeHomeRepo({
    required this.result,
    this.recommendedResult = const ApiResult.success([]),
    this.box,
  });

  ApiResult<List<HomeSection>> result;
  ApiResult<List<HomeItem>> recommendedResult;

  /// Backing store; a private [MemoryOfflineCache] when not injected.
  final OfflineCache? box;

  final MemoryOfflineCache _internalBox = MemoryOfflineCache();
  bool refreshed = false;

  OfflineCache get _box => box ?? _internalBox;

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() async => result;

  @override
  Future<ApiResult<List<HomeItem>>> getRecommendedHotels({int limit = 6}) async =>
      recommendedResult;

  @override
  Future<ApiResult<void>> refresh() async {
    refreshed = true;
    return ApiResult.success(null);
  }

  @override
  Future<List<HomeSection>?> readHomeSnapshot({required String audience}) async {
    try {
      final map = await _box.read(
        HomeRepositoryImpl.homeSnapshotCacheKey(audience),
      );
      if (map == null) return null;
      final sections = homeSectionsFromMap(map);
      return sections.isEmpty ? null : sections;
    } catch (_) {
      return null;
    }
  }

  /// Exposed so tests can PRE-SEED a snapshot before startup.
  @override
  Future<void> saveHomeSnapshot(
    List<HomeSection> sections, {
    required String audience,
  }) async {
    await _box.write(
      HomeRepositoryImpl.homeSnapshotCacheKey(audience),
      <String, dynamic>{
        'schemaVersion': 'home.snapshot.v2',
        'savedAt': DateTime.now().toIso8601String(),
        'audience': audience,
        'sections': sections.map(homeSectionToMap).toList(),
      },
    );
  }

  /// Mirrors the real repository: dropping the audience snapshot when the
  /// backend confirms the feed is legitimately empty.
  @override
  Future<void> clearHomeSnapshot({required String audience}) async {
    await _box.delete(HomeRepositoryImpl.homeSnapshotCacheKey(audience));
  }

  Future<bool> hasSnapshot(String audience) =>
      _box.contains(HomeRepositoryImpl.homeSnapshotCacheKey(audience));
}

HomeSection section(String id, String title) => HomeSection(
      id: id,
      title: title,
      layout: HomeSectionLayout.vertical,
      items: const [],
    );

/// Waits until pending microtasks settle so async controller work completes
/// without real clock waits.
Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('HomeController loads success', () async {
    final sections = [
      HomeSection(id: 's1', title: 't', layout: HomeSectionLayout.vertical, items: [])
    ];
    final repo = FakeHomeRepo(result: ApiResult.success(sections));
    final controller = HomeController(repo);
    await settle();

    expect(controller.state.status, HomeStatus.success);
    expect(controller.state.sections.length, 1);
    expect(controller.state.fromCache, isFalse);
  });

  test('HomeController loads empty', () async {
    final repo = FakeHomeRepo(result: ApiResult.success([]));
    final controller = HomeController(repo);
    await settle();

    // 2026-09-08: the honest no-content state replaces the old skeleton
    // preview — an empty feed with no hotel rail renders the explicit
    // empty state (retry affordance), never fake-looking headings.
    expect(controller.state.status, HomeStatus.empty);
    expect(controller.state.sections, isEmpty);
  });

  test('HomeController loads error', () async {
    final repo = FakeHomeRepo(result: ApiResult.failure(const ApiNetworkError(message: 'err')));
    final controller = HomeController(repo);
    await settle();

    expect(controller.state.status, HomeStatus.error);
    expect(controller.state.errorMessage, contains('No connection'));
    expect(controller.state.errorMessage, isNot(contains('err')));
  });

  // H1: 'HomeController refresh triggers repo refresh' retired — the manual
  // pull-to-refresh entry point (controller.refresh) was removed by product
  // decision; the repository refresh hook itself stays part of the contract.
  test('Card type selection', () {
    final item = HomeItem(id: 'i', type: HomeCardType.hotel, title: 'h');
    expect(item.type, HomeCardType.hotel);
  });

  test('Layout selection', () {
    final section = HomeSection(id: 's', title: 't', layout: HomeSectionLayout.grid, items: []);
    expect(section.layout, HomeSectionLayout.grid);
  });

  test('Malformed Home data handled', () {
    final section = HomeSection(id: '', title: '', layout: HomeSectionLayout.vertical, items: []);
    expect(section.title, '');
  });

  test('loadRecommendedHotels fills state on success', () async {
    final hotels = [
      HomeItem(id: 'h1', type: HomeCardType.hotel, title: 'Grand Cairo'),
    ];
    final repo = FakeHomeRepo(
      result: ApiResult.success([]),
      recommendedResult: ApiResult.success(hotels),
    );
    final controller = HomeController(repo);
    await settle();

    expect(controller.state.recommendedHotels.length, 1);
    expect(controller.state.recommendedHotels.first.title, 'Grand Cairo');
  });

  test('Nuitee-only Home: empty feed + real hotels → success with rail only',
      () async {
    final hotels = [
      HomeItem(id: 'h1', type: HomeCardType.hotel, title: 'Grand Cairo'),
    ];
    final repo = FakeHomeRepo(
      result: ApiResult.success([]),
      recommendedResult: ApiResult.success(hotels),
    );
    final controller = HomeController(repo);
    await settle();

    // The rail is the Home content: status is success and NO skeleton
    // preview sections linger alongside it.
    expect(controller.state.status, HomeStatus.success);
    expect(controller.state.sections, isEmpty);
    expect(controller.state.recommendedHotels, isNotEmpty);
  });

  test('Nuitee-only Home: empty feed with NO hotels → honest empty state',
      () async {
    final repo = FakeHomeRepo(
      result: ApiResult.success([]),
      recommendedResult: const ApiResult.success([]),
    );
    final controller = HomeController(repo);
    await settle();

    // 2026-09-08: no skeleton preview — the explicit no-content state with
    // its retry affordance (rendered by the page's empty branch).
    expect(controller.state.status, HomeStatus.empty);
    expect(controller.state.sections, isEmpty); // no fake data, no headings
    expect(controller.state.recommendedHotels, isEmpty);
  });

  test('Nuitee-only Home: empty feed drops the stale audience snapshot',
      () async {
    final repo = FakeHomeRepo(
      result: ApiResult.success([]),
      recommendedResult: const ApiResult.success([]),
    );
    await repo.saveHomeSnapshot(
      [section('legacy', 'Stale fake section')],
      audience: 'anon',
    );
    expect(await repo.hasSnapshot('anon'), isTrue);

    final controller = HomeController(repo);
    await settle();

    // The stale snapshot (fake sections) must be gone so it can never
    // resurface on cold starts or offline.
    expect(await repo.hasSnapshot('anon'), isFalse);
    // 2026-09-08: no dev-* skeleton sections are produced anymore —
    // the empty feed renders the honest empty state instead.
    expect(controller.state.sections, isEmpty);
  });

  test('loadRecommendedHotels ignores failure and empty list silently', () async {
    final repo = FakeHomeRepo(
      result: ApiResult.success([]),
      recommendedResult: const ApiResult.failure(ApiNetworkError(message: 'err')),
    );
    final controller = HomeController(repo);
    await settle();
    expect(controller.state.recommendedHotels, isEmpty);
    expect(controller.state.errorMessage, isNull);

    final emptyRepo = FakeHomeRepo(
      result: ApiResult.success([]),
      recommendedResult: const ApiResult.success([]),
    );
    final controller2 = HomeController(emptyRepo);
    await settle();
    expect(controller2.state.recommendedHotels, isEmpty);
    expect(controller2.state.errorMessage, isNull);
  });

  // ---------------------------------------------------------------------
  // Phase 1A — Instant Home + persistent final snapshot.
  // ---------------------------------------------------------------------

  group('Phase 1A: instant home snapshot', () {
    test('cached home renders before the network completes', () async {
      final completer = Completer<ApiResult<List<HomeSection>>>();
      final repo = _DelayedRepo(
        networkResult: completer.future,
      );
      await repo.saveHomeSnapshot(
        [section('cached-1', 'Cached section')],
        audience: 'anon',
      );
      final controller = HomeController(repo, audience: 'anon');

      // Give the snapshot restore a microtask to land; the network future is
      // still pending, yet content must already be on screen.
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, HomeStatus.success);
      expect(controller.state.fromCache, isTrue);
      expect(controller.state.sections.first.title, 'Cached section');
      expect(controller.state.isRefreshing, isTrue);

      // Network lands → visible content swaps to the fresh data.
      completer.complete(ApiResult.success([section('net-1', 'Fresh from network')]));
      await settle();
      expect(controller.state.status, HomeStatus.success);
      expect(controller.state.fromCache, isFalse);
      expect(controller.state.sections.first.title, 'Fresh from network');
      expect(controller.state.isRefreshing, isFalse);
    });

    test('successful refresh updates the UI', () async {
      final repo = FakeHomeRepo(
        result: ApiResult.success([section('net-1', 'New content')]),
      );
      await repo.saveHomeSnapshot(
        [section('cached-1', 'Old cached content')],
        audience: 'anon',
      );
      final controller = HomeController(repo, audience: 'anon');
      await settle();

      expect(controller.state.sections.first.title, 'New content');
      expect(controller.state.fromCache, isFalse);
    });

    test('successful refresh persists the snapshot to storage (Hive)', () async {
      final box = MemoryOfflineCache();
      final repo = FakeHomeRepo(
        result: ApiResult.success([section('net-1', 'Persisted')]),
        box: box,
      );
      final controller = HomeController(repo, audience: 'anon');
      await settle();

      // The network content rendered (the save path below was its side effect).
      expect(controller.state.sections.first.title, 'Persisted');
      expect(await repo.hasSnapshot('anon'), isTrue);
      final stored = await box.read(
        HomeRepositoryImpl.homeSnapshotCacheKey('anon'),
      );
      expect(stored, isNotNull);
      expect(stored!['schemaVersion'], 'home.snapshot.v2');
      expect(stored['audience'], 'anon');
      expect(stored['savedAt'], isNotNull);
      final sections =
          homeSectionsFromMap(Map<String, dynamic>.from(stored));
      expect(sections.first.title, 'Persisted');
    });

    test('network failure with cached content keeps the cached home (no error state)',
        () async {
      final repo = FakeHomeRepo(
        result: ApiResult.failure(const ApiNetworkError(message: 'offline')),
      );
      await repo.saveHomeSnapshot(
        [section('cached-1', 'Cached survives')],
        audience: 'anon',
      );
      final controller = HomeController(repo, audience: 'anon');
      await settle();

      expect(controller.state.status, HomeStatus.partial);
      expect(controller.state.sections.first.title, 'Cached survives');
      expect(controller.state.fromCache, isTrue);
    });

    test('no cache + network success works and stores a snapshot', () async {
      final repo = FakeHomeRepo(
        result: ApiResult.success([section('net-1', 'First load')]),
      );
      final controller = HomeController(repo, audience: 'anon');
      await settle();

      expect(controller.state.status, HomeStatus.success);
      expect(controller.state.sections.first.title, 'First load');
      expect(await repo.hasSnapshot('anon'), isTrue);
    });

    test("anonymous snapshot never leaks to an authenticated user", () async {
      final box = MemoryOfflineCache();
      final repo = FakeHomeRepo(
        result: ApiResult.success([section('net-1', 'User network content')]),
        box: box,
      );
      // Seed only the ANON snapshot.
      await repo.saveHomeSnapshot(
        [section('anon-1', 'Anonymous content')],
        audience: 'anon',
      );

      // A user-scoped controller over the same box must NOT see the anon
      // snapshot instantly — it waits for its own network content.
      final controller = HomeController(repo, audience: 'user:u-123');
      await settle();

      expect(controller.state.sections.first.title, 'User network content');
      // The user's own snapshot was written under the user key.
      expect(await repo.hasSnapshot('user:u-123'), isTrue);
      // The anon snapshot is untouched.
      final anon = await box.read(
        HomeRepositoryImpl.homeSnapshotCacheKey('anon'),
      );
      expect(anon?['audience'], 'anon');
    });

    test("authenticated snapshot never leaks to the anonymous surface", () async {
      final box = MemoryOfflineCache();
      final repo = FakeHomeRepo(
        result: ApiResult.success([section('net-1', 'Public content')]),
        box: box,
      );
      // Seed only a USER snapshot.
      await repo.saveHomeSnapshot(
        [section('user-1', 'Private user content')],
        audience: 'user:u-9',
      );

      final controller = HomeController(repo, audience: 'anon');
      await settle();

      expect(controller.state.sections.first.title, 'Public content');
      expect(await repo.hasSnapshot('anon'), isTrue);
      final userSnapshot = await box.read(
        HomeRepositoryImpl.homeSnapshotCacheKey('user:u-9'),
      );
      expect(userSnapshot?['audience'], 'user:u-9');
    });

    test('audience key helper maps null/empty ids to anon', () {
      expect(HomeRepositoryImpl.homeAudienceFor(null), 'anon');
      expect(HomeRepositoryImpl.homeAudienceFor(''), 'anon');
      expect(HomeRepositoryImpl.homeAudienceFor('u-1'), 'user:u-1');
    });

    // -----------------------------------------------------------------
    // Phase 1B guards: composition must not break the 1A startup contract.
    // -----------------------------------------------------------------

    test('Phase 1A cached startup still works with the composer wired',
        () async {
      final completer = Completer<ApiResult<List<HomeSection>>>();
      final repo = _DelayedRepo(networkResult: completer.future);
      // Pre-seed a snapshot WITH composer metadata (as 1B would save it).
      await repo.saveHomeSnapshot(
        [
          HomeSection(
            id: 'based-on-activity',
            title: 'Based on what you viewed',
            layout: HomeSectionLayout.horizontal,
            items: const [],
            metadata: const {
              'semanticId': 'based-on-activity',
              'reason': 'local-behavior',
            },
          ),
        ],
        audience: 'anon',
      );

      final controller = HomeController(
        repo,
        audience: 'anon',
        contextBuilder: (recommended) async => HomeCompositionContext(
          userState: HomeUserState.returningAnonymous,
          recommendedHotels: recommended,
        ),
      );

      // Instant snapshot render (composer-tagged sections decode fine) —
      // the network is still pending.
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, HomeStatus.success);
      expect(controller.state.fromCache, isTrue);
      expect(controller.state.sections.first.metadata['semanticId'],
          'based-on-activity');

      // Complete the network; the composed output replaces the snapshot.
      completer.complete(
          ApiResult.success([section('net-1', 'Network content')]));
      await settle();
      expect(controller.state.fromCache, isFalse);
    });

    test('background refresh with content on screen never re-enters loading',
        () async {
      final completer = Completer<ApiResult<List<HomeSection>>>();
      final repo = _DelayedRepo(networkResult: completer.future);
      await repo.saveHomeSnapshot(
        [section('cached-1', 'Cached content')],
        audience: 'anon',
      );
      final controller = HomeController(repo, audience: 'anon');

      // Snapshot rendered instantly; network still pending.
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, HomeStatus.success);
      expect(controller.state.fromCache, isTrue);
      expect(controller.state.isRefreshing, isTrue);

      // Network lands — quiet refresh, no loading flip.
      completer
          .complete(ApiResult.success([section('net-1', 'Network content')]));
      await settle();
      expect(controller.state.status, HomeStatus.success);
      expect(controller.state.fromCache, isFalse);
      expect(controller.state.isRefreshing, isFalse);
      expect(controller.state.status, isNot(HomeStatus.loading));
      expect(controller.state.sections.first.title, 'Network content');
    });
  });
}

/// Fake whose network call hangs on a completer — proves the snapshot renders
/// before the network resolves.
class _DelayedRepo extends FakeHomeRepo {
  _DelayedRepo({required this.networkResult})
      : super(result: const ApiResult.success([])); // never awaited

  final Future<ApiResult<List<HomeSection>>> networkResult;

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() => networkResult;
}
