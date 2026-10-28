import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/ai/ai_assistant_service.dart';
import '../domain/ai_home_mapper.dart';
import '../data/ai_api_service.dart';
import '../../home/providers/home_providers.dart';

import 'ai_controller.dart';
import 'ai_state.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';

/// Single shared instance of the boundary mapper.
final aiHomeMapperProvider = Provider<AiHomeMapper>((ref) {
  return const AiHomeMapper();
});

/// AI service provider - real HTTP implementation connected to the backend.
final aiAssistantServiceProvider = Provider<AiAssistantService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AiApiService(client);
});

/// Suggestions service for the smart search typeahead sheet. Separate from
/// [aiAssistantServiceProvider] so tests can stub typeahead independently.
final aiSuggestionsServiceProvider = Provider<AiApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AiApiService(client);
});

// Memory sync test
/// Exposes the reactive [AiState] produced by [AiController].
///
/// The controller is wired to the real HTTP `AiAssistantService`; pointing it
/// elsewhere (another backend, a mock in tests) happens only at the provider
/// level, leaving the controller, mapper and UI untouched.
final aiControllerProvider = StateNotifierProvider<AiController, AiState>((
  ref,
) {
  return AiController(
    service: ref.watch(aiAssistantServiceProvider),
    mapper: ref.watch(aiHomeMapperProvider),
    cache: ref.watch(offlineCacheProvider),
  );
});
