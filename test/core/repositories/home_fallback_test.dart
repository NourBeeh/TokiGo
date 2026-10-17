import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/impl/home_repository_impl.dart';
import 'package:tokigo/core/storage/offline_cache.dart';

class _ScriptedHomeApiClient implements ApiClient {
  _ScriptedHomeApiClient(this.payload);

  ApiResult<List<dynamic>> payload;

  @override
  String get baseUrl => 'http://test';

  @override
  Duration get defaultTimeout => const Duration(seconds: 1);

  @override
  Map<String, String> get defaultHeaders => const {};

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async =>
      payload as ApiResult<T>;

  @override
  Future<ApiResult<T>> post<T>(String path,
      {Object? body,
      Map<String, String>? headers,
      Duration? timeout,
      RequestToken? token}) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<T>> put<T>(String path,
      {Object? body,
      Map<String, String>? headers,
      Duration? timeout,
      RequestToken? token}) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<T>> patch<T>(String path,
      {Object? body,
      Map<String, String>? headers,
      Duration? timeout,
      RequestToken? token}) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<T>> delete<T>(String path,
      {Map<String, String>? headers, Duration? timeout, RequestToken? token}) async =>
      throw UnimplementedError();

  @override
  ApiResult<T> mapError<T>(Object error, {StackTrace? stackTrace}) =>
      ApiResult.failure(ApiNetworkError(message: error.toString(), cause: error));
}

const _realFeed = <Map<String, dynamic>>[
  {
    'id': 'sec-1',
    'title': 'Recommended',
    'layout': 'horizontal',
    'cards': [
      {
        'id': 'c1',
        'type': 'hotel',
        'title': 'Real Hotel',
        'price': 250,
        'currency': 'USD',
      },
    ],
  },
];

void main() {
  group('HomeRepositoryImpl — empty/failure fallback chain', () {
    test('returns real sections and writes them to the cache', () async {
      final client = _ScriptedHomeApiClient(ApiResult.success(_realFeed));
      final cache = MemoryOfflineCache();
      final repo = HomeRepositoryImpl(client, offlineCache: cache);

      final result = await repo.getHomeSections();

      expect(result.valueOrNull, hasLength(1));
      expect(result.valueOrNull!.first.items.first.title, 'Real Hotel');
      // Snapshot persisted for later offline/empty reads.
      expect(await cache.contains('home|sections'), isTrue);
    });

    test(
        'empty feed is authoritative — stale legacy cache is NOT resurrected',
        () async {
      final client = _ScriptedHomeApiClient(const ApiResult.success([]));
      final cache = MemoryOfflineCache();
      // Legacy `home|sections` entry still holding withdrawn fake content.
      await cache.write('home|sections', {
        'sections': [
          {
            'id': 'cached-sec',
            'title': 'Cached section',
            'layout': 'grid',
            'items': [
              {'id': 'x1', 'type': 'deal', 'title': 'Cached card'},
            ],
          },
        ],
      });
      final repo = HomeRepositoryImpl(client, offlineCache: cache);

      final result = await repo.getHomeSections();

      // The backend confirmed the feed is empty; the cached fake sections
      // must never come back.
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });

    test('empty feed + no cache → returns empty state', () async {
      final client = _ScriptedHomeApiClient(const ApiResult.success([]));
      final repo = HomeRepositoryImpl(client, offlineCache: MemoryOfflineCache());

      final result = await repo.getHomeSections();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });

    test('network failure + cached snapshot → serves the snapshot', () async {
      final client = _ScriptedHomeApiClient(
        const ApiResult.failure(ApiNetworkError(message: 'offline')),
      );
      final cache = MemoryOfflineCache();
      await cache.write('home|sections', {
        'sections': [
          {
            'id': 's',
            'title': 'Last known feed',
            'items': <Map<String, dynamic>>[],
          },
        ],
      });
      final repo = HomeRepositoryImpl(client, offlineCache: cache);

      final result = await repo.getHomeSections();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.single.title, 'Last known feed');
    });

    test('failure + no cache → returns error', () async {
      final client = _ScriptedHomeApiClient(
        const ApiResult.failure(ApiNetworkError(message: 'offline')),
      );
      final repo = HomeRepositoryImpl(client, offlineCache: MemoryOfflineCache());

      final result = await repo.getHomeSections();

      expect(result.isFailure, isTrue);
    });

    test(
        'cache write/read round-trip preserves section and card fields',
        () async {
      final client = _ScriptedHomeApiClient(ApiResult.success(_realFeed));
      final cache = MemoryOfflineCache();
      final repo = HomeRepositoryImpl(client, offlineCache: cache);

      await repo.getHomeSections();
      // Second read is a network FAILURE — the offline fallback must restore
      // the cached feed (the empty-feed path no longer resurrects cache).
      client.payload = const ApiResult.failure(ApiNetworkError(message: 'x'));

      final second = await repo.getHomeSections();

      expect(second.valueOrNull, hasLength(1));
      final card = second.valueOrNull!.first.items.single;
      expect(card.id, 'c1');
      expect(card.title, 'Real Hotel');
      expect(card.price, 250);
      expect(card.currency, 'USD');
    });

    test('empty feed + no cache injected → returns empty state', () async {
      final client = _ScriptedHomeApiClient(const ApiResult.success([]));
      final repo = HomeRepositoryImpl(client); // legacy single-arg ctor

      final result = await repo.getHomeSections();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });
  });
}
