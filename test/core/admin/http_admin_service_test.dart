import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/admin/admin_home_content_service.dart';
import 'package:tokigo/core/admin/admin_home_service.dart';
import 'package:tokigo/core/admin/admin_provider_models.dart';
import 'package:tokigo/core/admin/http_admin_home_service.dart';
import 'package:tokigo/core/admin/http_admin_provider_service.dart';
import 'package:tokigo/core/admin/http_admin_service_base.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';

class _FakeTokenStorage implements SecureTokenStorage {
  _FakeTokenStorage(this._token);
  final String? _token;

  @override
  Future<String?> getAccessToken() async => _token;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> saveAccessToken(String value) async {}

  @override
  Future<void> saveRefreshToken(String value) async {}

  @override
  Future<void> deleteAccessToken() async {}

  @override
  Future<void> deleteRefreshToken() async {}

  @override
  Future<void> clearAll() async {}
}

class _FakeApiClient implements ApiClient {
  _FakeApiClient(this.handler);

  final ApiResult<dynamic> Function(String method, String path) handler;
  final List<(String, String)> calls = <(String, String)>[];

  @override
  String get baseUrl => 'http://localhost:3000/api';

  @override
  Duration get defaultTimeout => const Duration(seconds: 10);

  @override
  Map<String, String> get defaultHeaders => const <String, String>{};

  @override
  Future<ApiResult<T>> get<T>(String path,
      {Map<String, String>? queryParameters,
      Map<String, String>? headers,
      Duration? timeout,
      RequestToken? token}) async {
    calls.add(('GET', path));
    return handler('GET', path) as ApiResult<T>;
  }

  @override
  Future<ApiResult<T>> post<T>(String path,
      {Object? body,
      Map<String, String>? headers,
      Duration? timeout,
      RequestToken? token}) async {
    calls.add(('POST', path));
    return handler('POST', path) as ApiResult<T>;
  }

  @override
  Future<ApiResult<T>> put<T>(String path,
      {Object? body,
      Map<String, String>? headers,
      Duration? timeout,
      RequestToken? token}) async {
    calls.add(('PUT', path));
    return handler('PUT', path) as ApiResult<T>;
  }

  @override
  Future<ApiResult<T>> patch<T>(String path,
      {Object? body,
      Map<String, String>? headers,
      Duration? timeout,
      RequestToken? token}) async {
    calls.add(('PATCH', path));
    return handler('PATCH', path) as ApiResult<T>;
  }

  @override
  Future<ApiResult<T>> delete<T>(String path,
      {Map<String, String>? headers,
      Duration? timeout,
      RequestToken? token}) async {
    calls.add(('DELETE', path));
    return handler('DELETE', path) as ApiResult<T>;
  }

  @override
  ApiResult<T> mapError<T>(Object error, {StackTrace? stackTrace}) {
    return ApiResult<T>.failure(ApiUnknownError(message: error.toString()));
  }
}

const Map<String, dynamic> _sectionRow = <String, dynamic>{
  'id': 'sec-1',
  'title': 'Recommended',
  'subtitle': 'For you',
  'layout': 'horizontal',
  'order': 1,
  'isVisible': true,
  'status': 'published',
  'cards': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'card-1',
      'sectionId': 'sec-1',
      'cardType': 'hotel',
      'order': 1,
      'isVisible': true,
      'status': 'published',
      'content': <String, dynamic>{
        'title': 'Grand Palm',
        'price': 250.0,
        'currency': 'EGP',
        'rating': 4.5,
        'actionLabel': 'View hotel',
      },
    },
  ],
};

void main() {
  group('HttpAdminHomeService (legacy AdminHomeService contract)', () {
    late _FakeApiClient client;
    late HttpAdminHomeService service;

    setUp(() {
      client = _FakeApiClient((method, path) {
        if (path == '/admin/home/sections') {
          return ApiResult<List<dynamic>>.success(<dynamic>[_sectionRow]);
        }
        return ApiResult<Map<String, dynamic>>.success(
          const <String, dynamic>{},
        );
      });
      service = HttpAdminHomeService(
        apiClient: client,
        tokenStorage: _FakeTokenStorage('token-1'),
      );
    });

    test('listSections returns presentation HomeSection from raw admin rows',
        () async {
      final sections = await service.listSections();
      expect(sections, isA<List<HomeSection>>());
      expect(sections.single.title, 'Recommended');
      expect(sections.single.layout, HomeSectionLayout.horizontal);
      final item = sections.single.items.single;
      expect(item.type, HomeCardType.hotel);
      expect(item.title, 'Grand Palm');
      expect(item.price, 250.0);
      expect(item.actionLabel, 'View hotel');
    });

    test('updateCard hits the card endpoint', () async {
      await service.updateCard(cardId: 'card-1', patch: <String, dynamic>{
        'content': <String, dynamic>{'price': 300},
      });
      expect(client.calls.single.$1, 'PATCH');
      expect(client.calls.single.$2, '/admin/home/cards/card-1');
    });

    test('setVisibility and setExpiration route through updateCard', () async {
      await service.setVisibility('card-1', false);
      await service.setExpiration(
        'card-1',
        DateTime.parse('2099-01-01T00:00:00.000Z'),
      );
      expect(client.calls.length, 2);
      expect(client.calls.every((c) => c.$1 == 'PATCH'), isTrue);
    });
  });

  group('HttpAdminContentService (admin raw rows)', () {
    test('listSections preserves drafts, scheduling and raw content',
        () async {
      final client = _FakeApiClient((method, path) {
        return ApiResult<List<dynamic>>.success(<dynamic>[
          <String, dynamic>{
            ..._sectionRow,
            'status': 'draft',
            'publishAt': '2099-01-01T00:00:00.000Z',
          },
        ]);
      });
      final service = HttpAdminContentService(
        apiClient: client,
        tokenStorage: _FakeTokenStorage(null),
      );
      final sections = await service.listSections();
      expect(sections.single.status, 'draft');
      expect(sections.single.publishAt, isNotNull);
      expect(sections.single.cards.single.content['title'], 'Grand Palm');
    });

    test('failure results surface as AdminApiException', () async {
      final client = _FakeApiClient((method, path) {
        return ApiResult<List<dynamic>>.failure(
          const ApiClientError(
            message: 'Admin access required.',
            statusCode: 403,
          ),
        );
      });
      final service = HttpAdminContentService(
        apiClient: client,
        tokenStorage: _FakeTokenStorage(null),
      );
      await expectLater(
        service.listSections(),
        throwsA(isA<AdminApiException>()),
      );
    });
  });

  group('HttpAdminProviderService', () {
    test('parses provider rows and toggles status by key', () async {
      final client = _FakeApiClient((method, path) {
        if (method == 'GET' && path == '/admin/providers') {
          return ApiResult<List<dynamic>>.success(<dynamic>[
            <String, dynamic>{
              'providerKey': 'nuitee',
              'name': 'Nuitee Hotels',
              'vertical': 'hotel',
              'isActive': true,
              'priority': 1,
              'isFallback': false,
              'healthStatus': 'healthy',
              'latencyMs': 210,
            },
          ]);
        }
        if (path == '/admin/providers/nuitee/status') {
          return ApiResult<Map<String, dynamic>>.success(<String, dynamic>{
            'providerKey': 'nuitee',
            'name': 'Nuitee Hotels',
            'vertical': 'hotel',
            'isActive': false,
            'priority': 1,
            'healthStatus': 'unknown',
          });
        }
        throw StateError('unexpected call: ' + method + ' ' + path);
      });
      final service = HttpAdminProviderService(
        apiClient: client,
        tokenStorage: _FakeTokenStorage('token-1'),
      );

      final providers = await service.listProviders();
      expect(providers.single, isA<ManagedProvider>());
      expect(providers.single.providerKey, 'nuitee');
      expect(providers.single.latencyMs, 210);

      final updated = await service.setStatus('nuitee', false);
      expect(updated.isActive, isFalse);
      expect(
        client.calls
            .any((c) => c == ('PATCH', '/admin/providers/nuitee/status')),
        isTrue,
      );
    });
  });
}
