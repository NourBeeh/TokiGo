import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';

import '../../../features/ai/domain/ai_query_context.dart';
import '../../../features/ai/domain/ai_response.dart';
import 'ai_chat_repository.dart';

/// 2C-C1 — HTTP implementation of [AiChatRepository].
///
/// Routing contract:
/// - **Authenticated user** (a non-empty access token exists):
///   `POST /ai/chat` with `Authorization: Bearer <jwt>`. The backend reads
///   the caller's relevant explicit conversation memories, builds the safe
///   AI context block server-side, and extracts new memories from the
///   message after answering. Flutter never sees any of that machinery.
/// - **Guest** (no token): the EXISTING memory-free `POST /ai/query` —
///   byte-for-byte the same call `AiApiService.query` makes today.
///
/// Failure contract: network/provider failures propagate as ApiError
/// exceptions (same `result.when(failure: throw)` pattern as every repo);
/// the CALLER decides the fallback (see AiChatController in 2C-C2 — for
/// 2C-C1 the repository itself must stay a dumb transport).
class AiChatRepositoryImpl implements AiChatRepository {
  AiChatRepositoryImpl(this._client, this._tokenStorage);

  final ApiClient _client;
  final SecureTokenStorage _tokenStorage;

  static const String _chatPath = '/ai/chat';
  static const String _queryPath = '/ai/query';

  /// AI calls legitimately run long — the backend provider allows 90s.
  static const Duration defaultChatTimeout = Duration(seconds: 90);

  @override
  Future<AiResponse> send(
    String prompt, {
    AiQueryContext? context,
    RequestToken? token,
    Duration? timeout,
  }) async {
    // Client-side contract guard — fails fast, never a network round-trip.
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      throw const AiChatValidationException('prompt must not be empty');
    }
    if (trimmed.length > AiChatValidationException.maxPromptLength) {
      throw const AiChatValidationException(
        'prompt must be at most 4000 characters',
      );
    }

    final body = <String, dynamic>{'prompt': trimmed};
    if (context != null) {
      body['context'] = context.toMap();
    }

    // Identity decides the endpoint — exactly one token source: secure
    // storage (the same one ProfileRepository uses).
    final accessToken = await _tokenStorage.getAccessToken();
    final authenticated = accessToken != null && accessToken.isNotEmpty;

    final result = await _client.post<Map<String, dynamic>>(
      authenticated ? _chatPath : _queryPath,
      body: body,
      headers: authenticated
          ? <String, String>{'Authorization': 'Bearer $accessToken'}
          : null,
      timeout: timeout ?? defaultChatTimeout,
      token: token,
    );

    final map = result.when(
      success: (data) => data,
      failure: (error) => throw error,
    );
    return AiResponse.fromMap(map);
  }
}
