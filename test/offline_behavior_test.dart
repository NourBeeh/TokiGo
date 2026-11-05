import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/network/network_status.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/presentation/home_controller.dart';

/// Fake home sections for the offline cache tests.
final _fakeSections = <HomeSection>[
  HomeSection(
    id: 'discover',
    title: 'Discover',
    layout: HomeSectionLayout.grid,
    items: <HomeItem>[
      HomeItem(
        id: 'oslo',
        type: HomeCardType.destination,
        title: 'Oslo',
        subtitle: 'Norway',
        imageUrl: 'https://example.invalid/oslo.jpg',
        price: 0,
        currency: 'NOK',
      ),
      HomeItem(
        id: 'hotel-1',
        type: HomeCardType.hotel,
        title: 'Hotel Cairo',
        subtitle: 'Cairo, Egypt',
        imageUrl: 'https://example.invalid/hotel.jpg',
        price: 2400,
        currency: 'EGP',
        rating: 4.5,
        reviewCount: 120,
      ),
    ],
  ),
];

/// A repository whose first call succeeds and subsequent calls fail.
class _CacheRepositoryWithFailingSecondCall extends _CacheRepository {
  _CacheRepositoryWithFailingSecondCall(super.data) : _calls = 0;

  int _calls;

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() async {
    _calls++;
    if (_calls == 1) {
      return super.getHomeSections();
    }
    return ApiResult.failure(
      ApiNetworkError(message: 'simulated network failure'),
    );
  }
}
class _CacheRepository implements HomeRepository {
  _CacheRepository(this._data);

  final Map<String, dynamic> _data;

  @override
  Future<List<HomeSection>?> readHomeSnapshot({required String audience}) async =>
      _data['sections'] as List<HomeSection>?;

  @override
  Future<void> clearHomeSnapshot({required String audience}) async {}

  @override
  Future<void> saveHomeSnapshot(List<HomeSection> sections, {required String audience}) async {}

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() async =>
      _resultFor('/home/sections');

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
  Future<SnapshotState> snapshotState({required String audience}) async {
    // The mock stores only sections, never the v2 envelope with savedAt.
    return SnapshotState.unavailable;
  }

  ApiResult<List<HomeSection>> _resultFor(String path) {
    if (path == '/home/sections') {
      return ApiResult.success(_data['sections'] as List<HomeSection>);
    }
    return const ApiResult<List<HomeSection>>.success(<HomeSection>[]);
  }
}

void main() {
  group('Offline startup — cached Home content', () {
    test('HomeController restores a persisted snapshot and shows it immediately', () async {
      final repo = _CacheRepository(<String, dynamic>{
        'sections': _fakeSections,
      });
      final controller = HomeController(repo, audience: 'anon');
      // The snapshot content is published immediately by restoreFromSnapshot
      // (before the background load). The UI never blocks on the network.
      // The load() callback is async; give it a short moment to settle.
      await Future.delayed(const Duration(milliseconds: 50));
      expect(controller.state.status, HomeStatus.success);
      // The controller publishes the snapshot content. The composer may wrap
      // the sections with metadata tags, so compare by content rather than
      // by reference.
      expect(controller.state.sections, isNotEmpty);
      expect(controller.state.sections!.length, _fakeSections.length);
      expect(controller.state.sections!.single.id, _fakeSections.single.id);
    });

    test('a failing background load keeps cached content and does NOT error', () async {
      // A repository whose first call succeeds and subsequent calls fail.
      var callCount = 0;
      final repo = _CacheRepositoryWithFailingSecondCall(<String, dynamic>{
        'sections': _fakeSections,
      });
      final controller = HomeController(repo, audience: 'anon');
      // The initial load succeeded; cached content is on screen.
      await Future.delayed(const Duration(milliseconds: 50));
      expect(controller.state.status, HomeStatus.success);
      expect(controller.state.sections, isNotEmpty);
      // A second load (simulating a failed refresh) — when it fails, the
      // cached content stays and the page becomes partial, never error.
      controller.load();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(controller.state.status, HomeStatus.partial);
      expect(controller.state.sections, isNotEmpty);
    });
  });

  group('Online → offline transition (home UI)', () {
    test('HomeController keeps cached sections when backend goes offline', () async {
      final repo = _CacheRepositoryWithFailingSecondCall(
        <String, dynamic>{'sections': _fakeSections},
      );
      final controller = HomeController(repo, audience: 'anon');
      await Future.delayed(const Duration(milliseconds: 60));
      expect(controller.state.status, HomeStatus.success);
      expect(controller.state.sections, isNotEmpty);

      final client = HttpClient();
      NetworkStatus.instance.reportOffline();
      final api = HttpApiClient(
        client: client,
        baseUrlOverride: 'http://127.0.0.1:1',
      );

      controller.load();
      await Future.delayed(const Duration(milliseconds: 60));
      expect(controller.state.status, HomeStatus.partial);
      expect(controller.state.sections, isNotEmpty);
    });
  });

  group('NetworkStatus — backend reachability', () {
    test('reportOffline marks offline and reports announcedOffline', () {
      NetworkStatus.instance.reportOffline();
      expect(NetworkStatus.instance.online, false);
      expect(NetworkStatus.instance.announcedOffline, true);
    });

    test('a successful call clears offline', () {
      NetworkStatus.instance.reportOffline();
      expect(NetworkStatus.instance.online, false);
      NetworkStatus.instance.reportOnline();
      expect(NetworkStatus.instance.online, true);
      expect(NetworkStatus.instance.announcedOffline, false);
    });

    test('reportOnline on an already-online instance is a no-op', () {
      NetworkStatus.instance.reportOnline();
      expect(NetworkStatus.instance.announcedOffline, false);
    });

    test('reportOffline on an already-offline instance is a no-op', () {
      NetworkStatus.instance.reportOffline();
      NetworkStatus.instance.reportOffline();
      expect(NetworkStatus.instance.announcedOffline, true);
    });
  });

  group('API timeout — connection failure never crashes the UI', () {
    test('a hanging request returns a timeout or network failure', () async {
      // Use an unreachable port to simulate a connection failure. The
      // platform may report either a timeout or a socket error; both are
      // handled gracefully and never crash the UI.
      final client = HttpClient();
      NetworkStatus.instance.reportOffline();
      final api = HttpApiClient(
        client: client,
        baseUrlOverride: 'http://127.0.0.1:1',
      );
      // A short timeout ensures the test does not block the suite.
      final result = await api.get<List<dynamic>>('/home/sections', timeout: const Duration(milliseconds: 100));
      expect(
        result.isFailure,
        true,
        reason: 'a connection failure must never crash the UI',
      );
      // Could be a timeout or a socket error — both are failures.
      final error = result.errorOrNull;
      expect(error, isNotNull);
      final isTimeoutOrNetwork =
          error is ApiTimeoutError || error is ApiNetworkError;
      expect(isTimeoutOrNetwork, isTrue);
    });
  });

  group('Backend unavailable — offline indicator + cached content', () {
    test('a failed get returns failure and marks the backend offline', () async {
      // Use an unreachable port (1 = reserved) to simulate a backend that
      // cannot be reached at all.
      final client = HttpClient();
      NetworkStatus.instance.reportOffline();
      final api = HttpApiClient(
        client: client,
        baseUrlOverride: 'http://127.0.0.1:1',
      );
      final result = await api.get<List<dynamic>>('/home/sections');
      expect(result.isFailure, true);
      expect(result.errorOrNull, isA<ApiNetworkError>());
      expect(NetworkStatus.instance.online, false);
    });
  });

  group('Reconnection — safe revalidation', () {
    test('reportOnline on a previously-offline instance clears offline state', () {
      NetworkStatus.instance.reportOffline();
      expect(NetworkStatus.instance.announcedOffline, true);
      NetworkStatus.instance.reportOnline();
      expect(NetworkStatus.instance.online, true);
      expect(NetworkStatus.instance.announcedOffline, false);
    });

    test('a successful call during the same request does not double-report', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      var handled = false;
      server.listen((HttpRequest request) {
        if (!handled) {
          handled = true;
          request.response.headers.contentType = ContentType.json;
          request.response.write('[]');
          request.response.close();
        }
      });
      addTearDown(() async {
        client.close(force: true);
        await server.close(force: true);
        NetworkStatus.instance.reportOnline();
      });

      NetworkStatus.instance.reportOffline();
      final HttpApiClient api = HttpApiClient(
        client: client,
        baseUrlOverride: 'http://127.0.0.1:${server.port}',
      );
      final result = await api.get<List<dynamic>>('/home/sections');
      expect(result.isSuccess, true);
      // The client reported the backend as reachable again.
      expect(NetworkStatus.instance.online, true);
    });
  });
}
