import 'dart:async';

import 'package:flutter/foundation.dart';

/// US-3 — Voice search service boundary.
///
/// Wraps the `speech_to_text` plugin behind a narrow, testable interface.
/// The UI NEVER talks to the plugin directly: every entry point degrades
/// to typed failures ([VoiceFailure]) instead of throwing, so the search
/// surface can never crash on unavailable permissions/services (spec:
/// "gracefully handle unavailable permissions/services", "Never crash").
///
/// Languages: Arabic + English (spec) — the recognizer is asked for the
/// device locale first; when the plugin cannot match, English is the
/// fallback (never a failure).
abstract interface class VoiceSearchService {
  /// Whether a speech recognizer is available on this device at all
  /// (checked WITHOUT requesting any permission).
  Future<bool> isAvailable();

  /// Starts (or restarts) listening.
  ///
  /// [onResult] fires for every recognized chunk: [partial] is the live
  /// in-progress transcription, [finalResult] marks a stable chunk.
  /// Returns false + [onError] when the service cannot start (permission
  /// denied, mic busy, recognizer unavailable) — never throws.
  Future<bool> start({
    required void Function(String partial, bool finalResult) onResult,
    required void Function(VoiceFailure failure) onError,
  });

  /// Stops listening, keeping any transcription so far.
  Future<void> stop();

  /// Cancels listening, discarding in-flight partial results.
  Future<void> cancel();
}

/// Failure taxonomy (spec: permission denied / microphone unavailable /
/// speech recognition unavailable / network-service error / empty
/// transcription / cancellation).
enum VoiceFailureKind {
  permissionDenied,
  microphoneUnavailable,
  recognitionUnavailable,
  network,
  emptyTranscription,
  cancelled,
  unknown,
}

@immutable
class VoiceFailure {
  const VoiceFailure(this.kind, this.message);

  final VoiceFailureKind kind;
  final String message;

  @override
  String toString() => 'VoiceFailure(${kind.name}): $message';
}

/// Maps plugin error codes onto the taxonomy — the plugin's string codes
/// are an implementation detail that must not leak into the UI.
VoiceFailureKind voiceFailureKindFromCode(String code) {
  switch (code) {
    case 'permission-denied':
    case 'permanently-denied':
      return VoiceFailureKind.permissionDenied;
    case 'mic-unavailable':
    case 'microphone-unavailable':
      return VoiceFailureKind.microphoneUnavailable;
    case 'speech-not-available':
    case 'no-recognizer':
    case 'not-allowed':
      return VoiceFailureKind.recognitionUnavailable;
    case 'network':
    case 'network-error':
      return VoiceFailureKind.network;
    case 'cancel':
      return VoiceFailureKind.cancelled;
    default:
      return VoiceFailureKind.unknown;
  }
}
