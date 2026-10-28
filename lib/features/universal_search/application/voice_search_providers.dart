import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/speech_to_text_voice_service.dart';
import '../domain/voice_search_service.dart';
import 'voice_search_controller.dart';
import 'voice_search_state.dart';

/// US-3 — provider wiring for voice search.
///
/// `autoDispose` (route-scoped like the universal search machine): leaving
/// /smart-search tears the mic session down with the surface.
///
/// The transcription bridge is NOT a provider: the hosting page assigns
/// `controller.onTranscription` directly in initState (it owns the query
/// field), keeping this file dumb and unit-testable.
final voiceSearchServiceProvider = Provider<VoiceSearchService>((ref) {
  return SpeechToTextVoiceService();
});

/// The mic session state. Tests override this node (or the service one)
/// with fakes.
final voiceSearchControllerProvider =
    StateNotifierProvider.autoDispose<VoiceSearchController, VoiceSearchState>((
      ref,
    ) {
      return VoiceSearchController(
        voiceService: ref.watch(voiceSearchServiceProvider),
        onTranscription: (_, _) {},
      );
    });
