import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/memory/memory_repository.dart';
import 'package:tokigo/core/memory/memory_repository_impl.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/storage/secure_token_storage_provider.dart';

import 'explicit_memory_controller.dart';

/// 2C-C2 — wiring for the "What I Know About You" memory controls.
///
/// Deliberately a SEPARATE provider file (same convention as
/// `ai_chat_providers.dart` from 2C-C1): additive, tests override exactly
/// this node, and the existing AI wiring (`ai_providers.dart`) is untouched.
///
/// The repository itself is the EXISTING Phase 2A `MemoryRepositoryImpl`
/// behind a dedicated ApiClient provider local to this library (Riverpod
/// scopes duplicate provider names per-import — the home feature already
/// owns `apiClientProvider` in its own library scope).

/// Local ApiClient provider for the memory-controls feature slice.
final memoryControlsApiClientProvider = Provider<ApiClient>((ref) {
  return HttpApiClient();
});

/// The Phase 2A memory repository, wired for this slice.
final memoryControlsRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepositoryImpl(
    ref.watch(memoryControlsApiClientProvider),
    ref.watch(secureTokenStorageProvider),
  );
});

/// Exposes the [ExplicitMemoryController] state for the memory page.
///
/// `autoDispose`: the memory controls are a visited page, not app-lifetime
/// state — leaving the page discards the list; reopening reloads fresh.
final explicitMemoryControllerProvider =
    StateNotifierProvider.autoDispose<ExplicitMemoryController,
        ExplicitMemoryState>((ref) {
  final controller = ExplicitMemoryController(
    ref.watch(memoryControlsRepositoryProvider),
  );
  Future.microtask(() => controller.load());
  return controller;
});

/// Whether the current session is authenticated (token exists — enough for
/// "guest sees a sign-in prompt, no memory surface").
///
/// NOTE: reading the token once at mount is intentional: the page is
/// autoDispose, so a login/logout mid-visit simply rebuilds it.
final memoryControlsSignedInProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureTokenStorageProvider);
  try {
    final token = await storage.getAccessToken();
    return token != null && token.isNotEmpty;
  } catch (_) {
    return false;
  }
});
