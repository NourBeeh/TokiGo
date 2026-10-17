import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/ai/ai_assistant_service.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/storage/secure_token_storage_provider.dart';
import 'package:tokigo/features/ai/application/ai_chat_guest_only_cache.dart';
import 'package:tokigo/features/ai/application/ai_chat_service_adapter.dart';
import 'package:tokigo/features/ai/application/ai_controller.dart';
import 'package:tokigo/features/ai/application/ai_state.dart';
import 'package:tokigo/features/ai/data/ai_chat_repository.dart';
import 'package:tokigo/features/ai/data/ai_chat_repository_impl.dart';
import 'package:tokigo/features/ai/domain/ai_home_mapper.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';

/// 2C-C2 — provider wiring for the full-screen AI conversation page.
///
/// The CHAT PAGE watches [aiChatControllerProvider] (this file); the legacy
/// `aiControllerProvider` in `ai_providers.dart` stays untouched for its
/// existing consumers (AI-mode shell + bottom sheet) — zero edits there.
///
/// Composition (all existing pieces, one new adapter node):
///   AiController (existing, unchanged)
///     → AiChatServiceAdapter (2C-C2 — identity-aware cache policy)
///       → AiChatRepositoryImpl (2C-C1 — /ai/chat | /ai/query routing)
///
/// Own local HttpApiClient (per-library Riverpod scoping, same shape as
/// 2C-C1's `aiChatApiClientProvider`) + the shared secure token storage.
final aiChatServiceApiClientProvider = Provider<ApiClient>((ref) {
  return HttpApiClient();
});

/// The 2C-C1 conversation repository, rebound for the chat-page slice.
final aiChatServiceRepositoryProvider = Provider<AiChatRepository>((ref) {
  return AiChatRepositoryImpl(
    ref.watch(aiChatServiceApiClientProvider),
    ref.watch(secureTokenStorageProvider),
  );
});

/// The [AiAssistantService] the conversation page talks to — the 2C-C2
/// adapter carrying the guest-only cache policy.
final aiChatServiceAdapterProvider = Provider<AiAssistantService>((ref) {
  return AiChatServiceAdapter(
    ref.watch(aiChatServiceRepositoryProvider),
  );
});

/// Single shared mapper instance (mirrors `aiHomeMapperProvider`).
final aiChatHomeMapperProvider = Provider<AiHomeMapper>((ref) {
  return const AiHomeMapper();
});

/// The conversation page's reactive state — the EXISTING [AiController]
/// (cache, retry, idle-expiry, rolling cap) driven by the 2C-C2 adapter,
/// with the shared cache wrapped guest-only (see [AiChatGuestOnlyCache]).
final aiChatControllerProvider =
    StateNotifierProvider<AiController, AiState>((ref) {
  final tokenStorage = ref.watch(secureTokenStorageProvider);
  return AiController(
    service: ref.watch(aiChatServiceAdapterProvider),
    mapper: ref.watch(aiChatHomeMapperProvider),
    cache: AiChatGuestOnlyCache(
      inner: ref.watch(offlineCacheProvider),
      tokenStorage: tokenStorage,
    ),
  );
});
