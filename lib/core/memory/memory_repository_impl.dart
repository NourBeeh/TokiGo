import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';

import 'memory_model.dart';
import 'memory_repository.dart';

/// HTTP implementation of the Memory Spine repository (Phase 2A).
///
/// Follows the existing auth pattern (ProfileRepository / AdminHttpMixin):
/// the access token is read from [SecureTokenStorage] and attached as a
/// Bearer header per call. WITHOUT a token the repository skips the network
/// entirely and returns a failure — guests have no server memory yet.
/// Every failure degrades to [ApiResult.failure]; this layer never throws.
class MemoryRepositoryImpl implements MemoryRepository {
  MemoryRepositoryImpl(this._client, this._tokenStorage);

  final ApiClient _client;
  final SecureTokenStorage _tokenStorage;

  Future<Map<String, String>?> _authHeaders() async {
    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) return null;
      return <String, String>{'Authorization': 'Bearer $token'};
    } catch (_) {
      return null;
    }
  }

  List<MemoryRecord> _parseList(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((raw) => MemoryRecord.fromMap(Map<String, dynamic>.from(raw)))
        .toList();
  }

  @override
  Future<ApiResult<List<MemoryRecord>>> getMyMemories({
    String? type,
    String? source,
    bool includeExpired = false,
  }) async {
    final headers = await _authHeaders();
    if (headers == null) {
      return const ApiResult.failure(ApiNetworkError(message: 'Not signed in'));
    }
    final result = await _client.get<List<dynamic>>(
      '/memory/me',
      queryParameters: <String, String>{
        'type': ?type,
        'source': ?source,
        if (includeExpired) 'includeExpired': 'true',
      },
      headers: headers,
    );
    return result.when(
      success: (data) => ApiResult.success(_parseList(data)),
      failure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<MemoryRecord>> createMemory({
    required String type,
    required String key,
    required Map<String, dynamic> value,
    required String source,
    double? confidence,
    String? expiresAt,
  }) async {
    final headers = await _authHeaders();
    if (headers == null) {
      return const ApiResult.failure(ApiNetworkError(message: 'Not signed in'));
    }
    final result = await _client.post<Map<String, dynamic>>(
      '/memory',
      body: <String, dynamic>{
        'type': type,
        'key': key,
        'value': value,
        'source': source,
        'confidence': ?confidence,
        'expiresAt': ?expiresAt,
      },
      headers: headers,
    );
    return result.when(
      success: (data) => ApiResult.success(MemoryRecord.fromMap(data)),
      failure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<MemoryRecord>> updateMemory(
    String id, {
    Map<String, dynamic>? value,
    String? source,
    double? confidence,
    String? expiresAt,
  }) async {
    final headers = await _authHeaders();
    if (headers == null) {
      return const ApiResult.failure(ApiNetworkError(message: 'Not signed in'));
    }
    final result = await _client.patch<Map<String, dynamic>>(
      '/memory/$id',
      body: <String, dynamic>{
        'value': ?value,
        'source': ?source,
        'confidence': ?confidence,
        'expiresAt': ?expiresAt,
      },
      headers: headers,
    );
    return result.when(
      success: (data) => ApiResult.success(MemoryRecord.fromMap(data)),
      failure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<void>> deleteMemory(String id) async {
    final headers = await _authHeaders();
    if (headers == null) {
      return const ApiResult.failure(ApiNetworkError(message: 'Not signed in'));
    }
    final result = await _client.delete<void>('/memory/$id', headers: headers);
    return result.when(
      success: (_) => ApiResult.success(null),
      failure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<void>> clearMyMemories() async {
    final headers = await _authHeaders();
    if (headers == null) {
      return const ApiResult.failure(ApiNetworkError(message: 'Not signed in'));
    }
    final result = await _client.delete<void>('/memory/me', headers: headers);
    return result.when(
      success: (_) => ApiResult.success(null),
      failure: (error) => ApiResult.failure(error),
    );
  }
}
