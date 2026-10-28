import 'package:tokigo/core/network/api_result.dart';

import 'memory_model.dart';

/// User Memory Spine contract (Phase 2A — Foundation).
///
/// User-owned ONLY: every call targets the JWT-authenticated user; there is
/// deliberately NO API shape that accepts a userId parameter. The spine is
/// standalone in this phase — nothing wires it into Home/AI yet.
abstract interface class MemoryRepository {
  /// Lists the caller's memories (server orders by updatedAt DESC; expired
  /// records are hidden unless [includeExpired] is true).
  Future<ApiResult<List<MemoryRecord>>> getMyMemories({
    String? type,
    String? source,
    bool includeExpired,
  });

  /// Creates (or rewrites — upsert on type+key) one structured fact.
  Future<ApiResult<MemoryRecord>> createMemory({
    required String type,
    required String key,
    required Map<String, dynamic> value,
    required String source,
    double? confidence,
    String? expiresAt,
  });

  /// Updates value/source/confidence/expiry of an owned record.
  Future<ApiResult<MemoryRecord>> updateMemory(
    String id, {
    Map<String, dynamic>? value,
    String? source,
    double? confidence,
    String? expiresAt,
  });

  /// Deletes one owned record.
  Future<ApiResult<void>> deleteMemory(String id);

  /// Clears EVERY memory owned by the caller ("Forget everything").
  Future<ApiResult<void>> clearMyMemories();
}
