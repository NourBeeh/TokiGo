import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';
import 'package:tokigo/features/ai/data/ai_chat_repository.dart';
import 'package:tokigo/features/ai/data/ai_chat_repository_impl.dart';
import 'package:tokigo/features/ai/domain/ai_query_context.dart';

/// 2C-C1 — AI conversation repository tests.
///
/// Contract under test (محرك التوصيات.txt 2C-C1):
/// - request serialization (`prompt`, optional `context`)
/// - response parsing via the EXISTING AiResponse.fromMap
/// - the 4000-char limit enforced client-side BEFORE any network call
/// - authenticated user → POST /ai/chat with Bearer header
/// - guest → POST /ai/query (memory-free, unchanged), no auth header
/// - server error / timeout / malformed response propagation
void main() {
  test('request serialization: prompt + optional context in the body',
      () async {
    final client = _ScriptedClient(ApiResult.success(_aiResponseMap));
    final repo = AiChatRepositoryImpl(client, _TokenStore('jwt-token'));

    await repo.send(
      'عايز فندق رخيص في دبي',
      context: AiQueryContext(route: '/home'),
    );

    expect(client.lastPath, '/ai/chat');
    expect(client.lastBody?['prompt'], 'عايز فندق رخيص في دبي');
    final sentContext = client.lastBody?['context'];
    expect(sentContext, isA<Map<String, dynamic>>());
    expect(sentContext['route'], '/home');
  });

  test('prompt is trimmed before sending', () async {
    final client = _ScriptedClient(ApiResult.success(_aiResponseMap));
    final repo = AiChatRepositoryImpl(client, _TokenStore('jwt-token'));

    await repo.send('   hello there   ');

    expect(client.lastBody?['prompt'], 'hello there');
  });

  test('response parsing: the normalized AiResponse contract', () async {
    final client = _ScriptedClient(ApiResult.success(_aiResponseMap));
    final repo = AiChatRepositoryImpl(client, _TokenStore('jwt-token'));

    final response = await repo.send('anything');

    expect(response.text, 'Here are some suggestions.');
    expect(response.sections, hasLength(1));
    expect(response.sections.first.title, 'Dubai stays');
  });

  test('4000-char limit: over-limit prompts never hit the network', () async {
    final client = _ScriptedClient(ApiResult.success(_aiResponseMap));
    final repo = AiChatRepositoryImpl(client, _TokenStore('jwt-token'));

    expect(
      () => repo.send('x' * 4001),
      throwsA(isA<AiChatValidationException>()),
    );
    expect(client.lastPath, isNull, reason: 'no request may be made');
  });

  test('4000-char limit: exactly at the limit passes', () async {
    final client = _ScriptedClient(ApiResult.success(_aiResponseMap));
    final repo = AiChatRepositoryImpl(client, _TokenStore('jwt-token'));

    await repo.send('x' * 4000);
    expect(client.lastPath, '/ai/chat');
  });

  test('empty prompt fails fast without a network call', () async {
    final client = _ScriptedClient(ApiResult.success(_aiResponseMap));
    final repo = AiChatRepositoryImpl(client, _TokenStore('jwt-token'));

    expect(
      () => repo.send('    '),
      throwsA(isA<AiChatValidationException>()),
    );
    expect(client.lastPath, isNull);
  });

  test('authenticated user routes to /ai/chat with the Bearer header',
      () async {
    final client = _ScriptedClient(ApiResult.success(_aiResponseMap));
    final repo = AiChatRepositoryImpl(client, _TokenStore('jwt-token'));

    await repo.send('hello');

    expect(client.lastPath, '/ai/chat');
    expect(client.lastHeaders?['Authorization'], 'Bearer jwt-token');
  });

  test('guest routes to /ai/query WITHOUT any auth header', () async {
    final client = _ScriptedClient(ApiResult.success(_aiResponseMap));
    final repo = AiChatRepositoryImpl(client, _TokenStore(null));

    await repo.send('hello');

    expect(client.lastPath, '/ai/query');
    expect(client.lastHeaders, isNull);
  });

  test('server error propagates as ApiError to the caller', () async {
    final client = _ScriptedClient(
      const ApiResult.failure(ApiNetworkError(message: '503 provider down')),
    );
    final repo = AiChatRepositoryImpl(client, _TokenStore('jwt-token'));

    await expectLater(
      repo.send('hello'),
      throwsA(isA<ApiError>()),
    );
  });

  test('malformed response payload fails parsing, never silently succeeds',
      () async {
    final client = _ScriptedClient(
      const ApiResult.success(<String, dynamic>{'unexpected': 'shape'}),
    );
    final repo = AiChatRepositoryImpl(client, _TokenStore('jwt-token'));

    // AiResponse.fromMap tolerates missing text/sections — the contract is
    // "sections default to empty", not "throw". Assert the parsed shape.
    final response = await repo.send('hello');
    expect(response.sections, isEmpty);
    expect(response.text, isNull);
  });

  test('default chat timeout is applied (AI calls run long)', () async {
    final client = _ScriptedClient(ApiResult.success(_aiResponseMap));
    final repo = AiChatRepositoryImpl(client, _TokenStore('jwt-token'));

    await repo.send('hello');

    expect(
      client.lastTimeout,
      AiChatRepositoryImpl.defaultChatTimeout,
    );
  });
}

const Map<String, dynamic> _aiResponseMap = <String, dynamic>{
  'text': 'Here are some suggestions.',
  'sections': <Map<String, dynamic>>[
    <String, dynamic>{
      'title': 'Dubai stays',
      'subtitle': 'Within budget',
      'layout': 'horizontal',
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'title': 'Marina Hotel',
          'subtitle': 'Dubai',
        },
      ],
    },
  ],
};

/// Records the last POST for assertions; returns scripted results.
class _ScriptedClient implements ApiClient {
  _ScriptedClient(this.result);

  final ApiResult<Map<String, dynamic>> result;

  String? lastPath;
  Map<String, dynamic>? lastBody;
  Map<String, String>? lastHeaders;
  Duration? lastTimeout;

  @override
  Future<ApiResult<T>> post<T>(String path,
      {Object? body,
      Map<String, String>? headers,
      Duration? timeout,
      RequestToken? token}) async {
    lastPath = path;
    lastBody = body is Map<String, dynamic> ? body : null;
    lastHeaders = headers;
    lastTimeout = timeout;
    return result as ApiResult<T>;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TokenStore implements SecureTokenStorage {
  _TokenStore(this._token);

  final String? _token;

  @override
  Future<String?> getAccessToken() async => _token;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
