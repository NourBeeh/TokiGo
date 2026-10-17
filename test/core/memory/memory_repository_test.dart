import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/memory/memory_model.dart';
import 'package:tokigo/core/memory/memory_repository.dart';
import 'package:tokigo/core/memory/memory_repository_impl.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';

/// Phase 2A — Memory Spine repository tests.
///
/// Covers: model round-trip, every HTTP verb + path + body shape, the
/// Bearer-header behavior (and the no-token → no-network contract), query
/// filtering parameters, and failure propagation (ApiResult.failure, never
/// a throw).

class _FakeTokenStorage implements SecureTokenStorage {
  _FakeTokenStorage(this.token);
  final String? token;

  @override
  Future<String?> getAccessToken() async => token;

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

class _RecordedCall {
  _RecordedCall(this.method, this.path, this.body, this.headers, this.query);
  final String method;
  final String path;
  final Object? body;
  final Map<String, String>? headers;
  final Map<String, String>? query;

  String? get bearer => headers?['Authorization'];
}

class _ScriptedClient implements ApiClient {
  _ScriptedClient(this.handler);

  final ApiResult<dynamic> Function(_RecordedCall call) handler;
  final List<_RecordedCall> calls = <_RecordedCall>[];

  @override
  String get baseUrl => 'http://test';
  @override
  Duration get defaultTimeout => const Duration(seconds: 10);
  @override
  Map<String, String> get defaultHeaders => const <String, String>{};

  Future<ApiResult<T>> _record<T>(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
    Map<String, String>? query,
  }) async {
    final call = _RecordedCall(method, path, body, headers, query);
    calls.add(call);
    // The scripted handler returns ApiResult<dynamic>; rewrap the value so
    // the generic type matches what the real client would produce.
    return handler(call).cast<T>();
  }

  @override
  Future<ApiResult<T>> get<T>(String path,
          {Map<String, String>? queryParameters,
          Map<String, String>? headers,
          Duration? timeout,
          RequestToken? token}) =>
      _record<T>('GET', path,
          headers: headers, query: queryParameters);

  @override
  Future<ApiResult<T>> post<T>(String path,
          {Object? body,
          Map<String, String>? headers,
          Duration? timeout,
          RequestToken? token}) =>
      _record<T>('POST', path, body: body, headers: headers);

  @override
  Future<ApiResult<T>> patch<T>(String path,
          {Object? body,
          Map<String, String>? headers,
          Duration? timeout,
          RequestToken? token}) =>
      _record<T>('PATCH', path, body: body, headers: headers);

  @override
  Future<ApiResult<T>> delete<T>(String path,
          {Map<String, String>? headers,
          Duration? timeout,
          RequestToken? token}) =>
      _record<T>('DELETE', path, headers: headers);

  @override
  Future<ApiResult<T>> put<T>(String path,
          {Object? body,
          Map<String, String>? headers,
          Duration? timeout,
          RequestToken? token}) =>
      _record<T>('PUT', path, body: body, headers: headers);

  @override
  ApiResult<T> mapError<T>(Object error, {StackTrace? stackTrace}) {
    return ApiResult.failure(ApiClientError(message: error.toString()));
  }
}

const _sampleMemory = <String, dynamic>{
  'id': 'mem-1',
  'userId': 'u-1',
  'type': 'preference',
  'key': 'preferred_destination',
  'value': <String, dynamic>{'destination': 'Cairo'},
  'source': 'behavior_event',
  'confidence': 0.72,
  'expiresAt': null,
  'updatedAt': '2026-09-04T00:00:00.000Z',
};

extension _CastApiResult<T> on ApiResult<T> {
  /// Rebuilds the result with a different payload type (the scripted fakes
  /// return ApiResult<dynamic>; the repository expects typed results).
  ApiResult<R> cast<R>() => when(
        success: (value) => ApiResult.success(value as R),
        failure: ApiResult.failure,
      );
}

void main() {
  test('model serialization round-trip preserves every field', () {
    final record = MemoryRecord.fromMap(_sampleMemory);
    expect(record.id, 'mem-1');
    expect(record.type, 'preference');
    expect(record.key, 'preferred_destination');
    expect(record.value, {'destination': 'Cairo'});
    expect(record.source, 'behavior_event');
    expect(record.confidence, 0.72);
    expect(record.expiresAt, isNull);
    expect(record.updatedAt, '2026-09-04T00:00:00.000Z');

    final map = record.toMap();
    expect(map['type'], 'preference');
    expect(map['value'], {'destination': 'Cairo'});
    expect(map['confidence'], 0.72);
    // Round-trip stability for the fields the client owns.
    final roundTrip = MemoryRecord.fromMap(map);
    expect(roundTrip.key, record.key);
    expect(roundTrip.value, record.value);
    expect(roundTrip.source, record.source);
  });

  test('model tolerates missing optional fields', () {
    final record = MemoryRecord.fromMap(<String, dynamic>{
      'id': 'x',
      'type': 'derived',
      'key': 'k',
      'value': <String, dynamic>{},
      'source': 'system_derived',
    });
    expect(record.confidence, 1.0);
    expect(record.expiresAt, isNull);
    expect(record.updatedAt, isNull);
  });

  test('repository GET lists memories with the bearer header', () async {
    final client = _ScriptedClient(
      (_) => const ApiResult.success(<dynamic>[_sampleMemory]),
    );
    final repo = MemoryRepositoryImpl(client, _FakeTokenStorage('jwt-1'));

    final result = await repo.getMyMemories();

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, hasLength(1));
    expect(result.valueOrNull!.first.key, 'preferred_destination');
    final call = client.calls.single;
    expect(call.method, 'GET');
    expect(call.path, '/memory/me');
    expect(call.bearer, 'Bearer jwt-1');
  });

  test('repository GET forwards type/source/includeExpired filters', () async {
    final client = _ScriptedClient((_) => const ApiResult.success(<dynamic>[]));
    final repo = MemoryRepositoryImpl(client, _FakeTokenStorage('jwt-1'));

    await repo.getMyMemories(
      type: 'behavior',
      source: 'behavior_event',
      includeExpired: true,
    );

    final query = client.calls.single.query!;
    expect(query['type'], 'behavior');
    expect(query['source'], 'behavior_event');
    expect(query['includeExpired'], 'true');
  });

  test('repository POST records a structured fact with the right body',
      () async {
    final client = _ScriptedClient(
      (_) => const ApiResult.success(_sampleMemory),
    );
    final repo = MemoryRepositoryImpl(client, _FakeTokenStorage('jwt-1'));

    final result = await repo.createMemory(
      type: 'preference',
      key: 'preferred_destination',
      value: const {'destination': 'Cairo'},
      source: 'behavior_event',
      confidence: 0.72,
    );

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull!.id, 'mem-1');
    final call = client.calls.single;
    expect(call.method, 'POST');
    expect(call.path, '/memory');
    expect(call.bearer, 'Bearer jwt-1');
    final body = call.body as Map<String, dynamic>;
    expect(body['type'], 'preference');
    expect(body['key'], 'preferred_destination');
    expect(body['value'], {'destination': 'Cairo'});
    expect(body['confidence'], 0.72);
    expect(body.containsKey('expiresAt'), isFalse); // Omitted when null.
  });

  test('repository PATCH updates only the provided fields', () async {
    final client = _ScriptedClient(
      (_) => const ApiResult.success(_sampleMemory),
    );
    final repo = MemoryRepositoryImpl(client, _FakeTokenStorage('jwt-1'));

    final result = await repo.updateMemory(
      'mem-1',
      value: const {'destination': 'Dubai'},
      confidence: 0.9,
    );

    expect(result.isSuccess, isTrue);
    final call = client.calls.single;
    expect(call.method, 'PATCH');
    expect(call.path, '/memory/mem-1');
    expect(call.bearer, 'Bearer jwt-1');
    final body = call.body as Map<String, dynamic>;
    expect(body['value'], {'destination': 'Dubai'});
    expect(body['confidence'], 0.9);
    expect(body.containsKey('source'), isFalse); // Untouched fields omitted.
  });

  test('repository DELETE removes one memory by id', () async {
    final client = _ScriptedClient((_) => ApiResult.success(null));
    final repo = MemoryRepositoryImpl(client, _FakeTokenStorage('jwt-1'));

    final result = await repo.deleteMemory('mem-9');

    expect(result.isSuccess, isTrue);
    final call = client.calls.single;
    expect(call.method, 'DELETE');
    expect(call.path, '/memory/mem-9');
    expect(call.bearer, 'Bearer jwt-1');
  });

  test('repository clear targets /memory/me only', () async {
    final client = _ScriptedClient((_) => ApiResult.success(null));
    final repo = MemoryRepositoryImpl(client, _FakeTokenStorage('jwt-1'));

    final result = await repo.clearMyMemories();

    expect(result.isSuccess, isTrue);
    final call = client.calls.single;
    expect(call.method, 'DELETE');
    expect(call.path, '/memory/me');
  });

  test('no token → no network call, silent failure (guests have no memory)',
      () async {
    final client = _ScriptedClient((_) => const ApiResult.success(<dynamic>[]));
    final repo = MemoryRepositoryImpl(client, _FakeTokenStorage(null));

    final results = await Future.wait<dynamic>([
      repo.getMyMemories(),
      repo.createMemory(
        type: 'preference',
        key: 'k',
        value: const {},
        source: 'user_explicit',
      ),
      repo.updateMemory('id'),
      repo.deleteMemory('id'),
      repo.clearMyMemories(),
    ]);

    for (final result in results) {
      expect((result as ApiResult<dynamic>).isFailure, isTrue);
    }
    expect(client.calls, isEmpty); // Zero network traffic without a JWT.
  });

  test('API failure propagates as ApiResult.failure (never throws)', () async {
    final client = _ScriptedClient(
      (_) => const ApiResult.failure(ApiServerError(message: 'boom')),
    );
    final repo = MemoryRepositoryImpl(client, _FakeTokenStorage('jwt-1'));

    final list = await repo.getMyMemories();
    expect(list.isFailure, isTrue);

    final created = await repo.createMemory(
      type: 'preference',
      key: 'k',
      value: const {},
      source: 'user_explicit',
    );
    expect(created.isFailure, isTrue);

    final deleted = await repo.deleteMemory('mem-1');
    expect(deleted.isFailure, isTrue);
  });
}
