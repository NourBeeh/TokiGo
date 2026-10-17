import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/storage/secure_token_storage_provider.dart';

import '../data/ai_chat_repository.dart';
import '../data/ai_chat_repository_impl.dart';

/// 2C-C1 — provider wiring for the AI conversation repository.
///
/// Deliberately a SEPARATE provider file from `ai_providers.dart`: the
/// conversation repository is additive (2C-C1 must not touch the existing
/// AI wiring or Universal Search), and tests override exactly this node.
///
/// Own local HttpApiClient provider (same shape as the home/booking ones —
/// Riverpod scopes duplicates per-library) + the shared secure token
/// storage. No new infrastructure.
final aiChatApiClientProvider = Provider<ApiClient>((ref) => HttpApiClient());

final aiChatRepositoryProvider = Provider<AiChatRepository>((ref) {
  return AiChatRepositoryImpl(
    ref.watch(aiChatApiClientProvider),
    ref.watch(secureTokenStorageProvider),
  );
});
