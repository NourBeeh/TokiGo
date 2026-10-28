import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/voice_search_service.dart';
import 'voice_search_state.dart';

/// US-3 — voice search controller.
///
/// Owns ONLY the mic session state. The transcription is forwarded to the
/// caller ([onTranscription]) which writes it into the EXISTING
/// UniversalSearchController query (`onQueryChanged`) — voice never
/// creates a parallel query state (spec).
///
/// Every plugin/service failure lands in [VoiceSearchState.failure] for
/// inline display; the controller NEVER throws and NEVER auto-submits —
/// after a complete transcription the user reviews the field and submits
/// normally (spec: "user can submit normally", no auto-search).
class VoiceSearchController extends StateNotifier<VoiceSearchState> {
  VoiceSearchController({
    required VoiceSearchService voiceService,
    required this.onTranscription,
  }) : service = voiceService,
       super(const VoiceSearchState());

  /// The wrapped voice service.
  final VoiceSearchService service;

  /// Receives every transcription chunk: (text, isFinal). Assigned by the
  /// hosting surface (the page owns the query field) — mutable by design
  /// so the route-scoped controller stays provider-dumb.
  void Function(String text, bool isFinal) onTranscription;

  /// Runs one transcription cycle on mic tap.
  ///
  /// TAP MIC → starting (permission/service negotiation) → listening
  /// (partials stream) → stopped. A failure at any point surfaces in
  /// state.failure and returns to idle semantics — never a crash.
  Future<void> startSession() async {
    if (state.status == VoiceSearchStatus.starting ||
        state.status == VoiceSearchStatus.listening) {
      return; // A tap during a live session is a stop, handled by the UI.
    }
    state = state.copyWith(
      status: VoiceSearchStatus.starting,
      clearFailure: true,
    );

    final started = await service.start(
      onResult: (partial, isFinal) {
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        state = state.copyWith(status: VoiceSearchStatus.listening);
        onTranscription(partial, isFinal);
        if (isFinal) {
          // Complete transcription → session over, query populated → the
          // surface returns to TYPING semantics; the user submits normally.
          state = state.copyWith(status: VoiceSearchStatus.stopped);
        }
      },
      onError: (failure) {
        state = VoiceSearchState(
          status: VoiceSearchStatus.stopped,
          failure: failure,
        );
      },
    );

    if (!started) {
      // start() already reported the failure through onError.
      state = state.copyWith(status: VoiceSearchStatus.idle);
    }
  }

  /// User-initiated stop (the listening mic tap): keeps what was heard.
  Future<void> stopSession() async {
    await service.stop();
    state = state.copyWith(status: VoiceSearchStatus.stopped);
  }

  /// Cancel: discard partials (spec: cancellation is a first-class state).
  Future<void> cancelSession() async {
    await service.cancel();
    state = const VoiceSearchState();
  }

  /// Clears the inline failure (next tap starts fresh).
  void dismissFailure() {
    state = state.copyWith(clearFailure: true);
  }

  /// US-7 — the controller is route-scoped (`autoDispose`) and can be torn
  /// down while a mic session is still live (back navigation, route-scope
  /// rebuild). The recognizer must not outlive its owner, so disposal always
  /// cancels the service — the discard path — and never touches `state`
  /// after `super.dispose()` completes.
  @override
  void dispose() {
    unawaited(_cancelOnDispose());
    super.dispose();
  }

  Future<void> _cancelOnDispose() async {
    try {
      await service.cancel();
    } catch (_) {
      // Teardown must never throw; the service dies with the controller.
    }
  }

  /// Test-only state pin (StateNotifier's `state` is protected).
  @visibleForTesting
  set stateForTesting(VoiceSearchState value) => state = value;
}
