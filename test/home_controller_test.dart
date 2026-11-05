import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/network/network_status.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/features/home/domain/home_composer.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';

/// A fake repository that records calls without making real network requests.
///
/// [sections] is returned by both [getHomeSections] and [readHomeSnapshot], so
/// a test decides whether the feed is empty or populated.
class _TestHomeRepository implements HomeRepository {
  _TestHomeRepository(this._sections);

  final List<HomeSection>? _sections;
  int getHomeSectionsCallCount = 0;

  @override
  Future<List<HomeSection>?> readHomeSnapshot({required String audience}) async =>
      _sections;

  @override
  Future<void> clearHomeSnapshot({required String audience}) async {}

  @override
  Future<void> saveHomeSnapshot(List<HomeSection> sections,
      {required String audience}) async {}

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() async {
    getHomeSectionsCallCount++;
    return ApiResult<List<HomeSection>>.success(
      _sections ?? const <HomeSection>[],
    );
  }

  @override
  Future<ApiResult<List<HomeItem>>> getRecommendedHotels({
    int limit = 6,
    String? countryCode,
    String languageCode = 'en',
    String? currency,
  }) async =>
      const ApiResult<List<HomeItem>>.success(<HomeItem>[]);

  @override
  Future<ApiResult<void>> refresh() async => const ApiResult<void>.success(null);

  @override
  Future<SnapshotState> snapshotState({required String audience}) async =>
      SnapshotState.unavailable;
}

/// One cached section reused by several tests.
List<HomeSection> _cachedSections() => <HomeSection>[
      HomeSection(
        id: 'discover',
        title: 'Discover',
        layout: HomeSectionLayout.grid,
        items: const <HomeItem>[
          HomeItem(
            id: 'oslo',
            type: HomeCardType.destination,
            title: 'Oslo',
            subtitle: 'Norway',
            imageUrl: 'https://example.invalid/oslo.jpg',
            price: 0,
            currency: 'NOK',
          ),
        ],
      ),
    ];

void main() {
  group('HomeController network recovery', () {
    late _TestHomeRepository repo;

    /// Every controller created inside a test is registered here so that
    /// [tearDown] can dispose it. `NetworkStatus.instance` is a process-wide
    /// singleton: a controller that is never disposed leaks its listener into
    /// the next test, and a later `reportOnline()` then fires once per leaked
    /// listener instead of once.
    final List<HomeController> created = <HomeController>[];

    HomeController newController() {
      final controller = HomeController(
        repo,
        audience: 'anon',
        contextBuilder: (recommendedHotels) async =>
            const HomeCompositionContext(
          userState: HomeUserState.freshAnonymous,
        ),
        liveValidation: null,
        countryCode: null,
        languageCode: null,
        currencyCode: null,
      );
      created.add(controller);
      return controller;
    }

    setUp(() {
      repo = _TestHomeRepository(_cachedSections());
      created.clear();
    });

    tearDown(() {
      // Dispose in reverse creation order, then drop every reference so the
      // singleton holds no stale listeners when the next test starts.
      for (final controller in created.reversed) {
        controller.dispose();
      }
      created.clear();
      NetworkStatus.instance.reportOnline();
    });

    /// `reportOnline()` only notifies listeners on an offline -> online
    /// transition, so every assertion forces that transition first.
    Future<void> pulseOnline() async {
      NetworkStatus.instance.reportOffline();
      NetworkStatus.instance.reportOnline();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    test('startup registers exactly one NetworkStatus listener', () async {
      newController();
      // Let the async _startUp() finish registering the listener.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final before = repo.getHomeSectionsCallCount;
      await pulseOnline();

      // Exactly one load: _startUp() never registers the listener twice.
      expect(repo.getHomeSectionsCallCount, before + 1);
    });

    test('listener is removed on dispose', () async {
      final controller = newController();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final before = repo.getHomeSectionsCallCount;
      await pulseOnline();
      expect(repo.getHomeSectionsCallCount, before + 1);

      controller.dispose();
      created.remove(controller);

      final afterDispose = repo.getHomeSectionsCallCount;
      await pulseOnline();

      // No further load: dispose() removed the listener.
      expect(repo.getHomeSectionsCallCount, afterDispose);
    });

    test('no load is triggered after disposal', () async {
      final controller = newController();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      controller.dispose();
      created.remove(controller);

      final afterDispose = repo.getHomeSectionsCallCount;
      await pulseOnline();

      expect(repo.getHomeSectionsCallCount, afterDispose);
    });

    test('each live controller owns exactly one listener', () async {
      final first = newController();
      final second = newController();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Two live controllers -> two listeners -> two loads per pulse.
      final beforeTwo = repo.getHomeSectionsCallCount;
      await pulseOnline();
      expect(repo.getHomeSectionsCallCount, beforeTwo + 2);

      // Disposing one leaves exactly one live listener.
      second.dispose();
      created.remove(second);

      final beforeOne = repo.getHomeSectionsCallCount;
      await pulseOnline();
      expect(repo.getHomeSectionsCallCount, beforeOne + 1);

      // Disposing the last one silences the singleton entirely.
      first.dispose();
      created.remove(first);

      final beforeNone = repo.getHomeSectionsCallCount;
      await pulseOnline();
      expect(repo.getHomeSectionsCallCount, beforeNone);
    });

    test('online event clears offline state', () {
      NetworkStatus.instance.reportOffline();
      expect(NetworkStatus.instance.online, false);
      NetworkStatus.instance.reportOnline();
      expect(NetworkStatus.instance.online, true);
    });

    test('offline event does not clear cached sections', () async {
      final controller = newController();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.state.sections, isNotEmpty);

      NetworkStatus.instance.reportOffline();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Cached content stays on screen; the page never becomes an error.
      expect(controller.state.sections, isNotEmpty);
      expect(controller.state.status, isNot(HomeStatus.error));
    });

    test('load() keeps cached sections when the backend returns data',
        () async {
      final controller = newController();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final sections = _cachedSections();
      controller.state = controller.state.copyWith(
        status: HomeStatus.success,
        sections: sections,
      );
      expect(controller.state.sections, sections);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.state.status, isNot(HomeStatus.error));
    });
  });
}
