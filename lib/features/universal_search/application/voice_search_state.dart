import 'package:flutter/foundation.dart';

import '../domain/voice_search_service.dart';

/// US-3 — voice search UI state.
///
/// The transcription itself is NOT stored here (spec: "Voice transcription
/// must enter the SAME controller query. Do not create a parallel voice
/// query state.") — only the mic SESSION state + the last failure, which
/// the header renders. The query field stays the single source of truth.
@immutable
class VoiceSearchState {
  const VoiceSearchState({this.status = VoiceSearchStatus.idle, this.failure});

  final VoiceSearchStatus status;

  /// The last failure shown inline (permission denied, unavailable mic,
  /// empty transcription…) — cleared on the next session.
  final VoiceFailure? failure;

  VoiceSearchState copyWith({
    VoiceSearchStatus? status,
    VoiceFailure? failure,
    bool clearFailure = false,
  }) {
    return VoiceSearchState(
      status: status ?? this.status,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// The mic lifecycle (spec: TAP MIC → requesting permission → listening →
/// transcription → query populated → TYPING).
enum VoiceSearchStatus {
  /// No session — the resting 36px mic affordance.
  idle,

  /// Permission/service negotiation in flight (the tap was accepted).
  starting,

  /// Mic open, partial transcriptions streaming into the field.
  listening,

  /// Session over (stopped, timed out, errored) — back to idle semantics,
  /// kept distinct so tests can observe the transition.
  stopped,
}
