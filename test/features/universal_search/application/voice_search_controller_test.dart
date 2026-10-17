import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/features/universal_search/application/voice_search_controller.dart';
import 'package:tokigo/features/universal_search/application/voice_search_state.dart';
import 'package:tokigo/features/universal_search/domain/voice_search_service.dart';

/// US-3 — VoiceSearchController tests (spec's test list).
///
/// Covers: permission handling (denied → failure, no crash), listening
/// state, cancellation, Arabic transcription, English transcription,
/// empty transcription, error result, query preservation (the bridge
/// receives EXACTLY what the recognizer produced — no parallel state),
/// and no auto-submit (the controller only populates; submitting is the
/// user's action).
class _ScriptedVoiceService implements VoiceSearchService {
  _ScriptedVoiceService({
    this.startSucceeds = true,
    VoiceFailure? startFailure,
  })  : available = startSucceeds,
        _startFailure = startFailure;

  final bool available;
  final bool startSucceeds;
  final VoiceFailure? _startFailure;

  void Function(String partial, bool finalResult)? resultSink;
  void Function(VoiceFailure failure)? errorSink;

  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> start({
    required void Function(String partial, bool finalResult) onResult,
    required void Function(VoiceFailure failure) onError,
  }) async {
    startCalls++;
    resultSink = onResult;
    errorSink = onError;
    if (!startSucceeds) {
      onError(_startFailure ??
          const VoiceFailure(
            VoiceFailureKind.permissionDenied,
            'Microphone permission was denied.',
          ));
      return false;
    }
    return true;
  }

  /// Test helper: the recognizer produced a chunk.
  void emit(String text, {bool isFinal = false}) {
    resultSink?.call(text, isFinal);
  }

  /// Test helper: the recognizer errored mid-session.
  void fail(VoiceFailure failure) {
    errorSink?.call(failure);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }
}

void main() {
  test('permission denied → typed failure surfaces, never a crash',
      () async {
    final service = _ScriptedVoiceService(
      startSucceeds: false,
      startFailure: const VoiceFailure(
        VoiceFailureKind.permissionDenied,
        'Microphone permission was denied.',
      ),
    );
    final controller = VoiceSearchController(
      voiceService: service,
      onTranscription: (_, _) {},
    );

    await controller.startSession();

    expect(controller.state.status, VoiceSearchStatus.idle);
    expect(controller.state.failure?.kind, VoiceFailureKind.permissionDenied);
    expect(controller.state.failure?.message,
        'Microphone permission was denied.');
  });

  test('session lifecycle: starting → listening → stopped on final chunk',
      () async {
    final service = _ScriptedVoiceService();
    final controller = VoiceSearchController(
      voiceService: service,
      onTranscription: (_, _) {},
    );

    final pending = controller.startSession();
    expect(controller.state.status, VoiceSearchStatus.starting);
    await pending;

    service.emit('فنادق في', isFinal: false);
    expect(controller.state.status, VoiceSearchStatus.listening);

    service.emit('فنادق في القاهرة', isFinal: true);
    expect(controller.state.status, VoiceSearchStatus.stopped);
  });

  test('Arabic transcription flows to the bridge verbatim', () async {
    final service = _ScriptedVoiceService();
    final received = <(String, bool)>[];
    final controller = VoiceSearchController(
      voiceService: service,
      onTranscription: (text, isFinal) => received.add((text, isFinal)),
    );

    await controller.startSession();
    service.emit('فنادق في دبي');
    service.emit('فنادق في دبي للميزانية', isFinal: true);

    expect(received, [
      ('فنادق في دبي', false),
      ('فنادق في دبي للميزانية', true),
    ]);
  });

  test('English transcription flows to the bridge verbatim', () async {
    final service = _ScriptedVoiceService();
    final received = <(String, bool)>[];
    final controller = VoiceSearchController(
      voiceService: service,
      onTranscription: (text, isFinal) => received.add((text, isFinal)),
    );

    await controller.startSession();
    service.emit('hotels in cairo', isFinal: true);

    expect(received, [('hotels in cairo', true)]);
  });

  test('empty transcription is a typed failure (not a crash)', () async {
    final service = _ScriptedVoiceService();
    final controller = VoiceSearchController(
      voiceService: service,
      onTranscription: (_, _) {},
    );

    await controller.startSession();
    service.fail(const VoiceFailure(
      VoiceFailureKind.emptyTranscription,
      'No speech detected.',
    ));

    expect(controller.state.failure?.kind,
        VoiceFailureKind.emptyTranscription);
    expect(controller.state.status, VoiceSearchStatus.stopped);
  });

  test('mid-session recognizer error → failure surfaced, session over',
      () async {
    final service = _ScriptedVoiceService();
    final controller = VoiceSearchController(
      voiceService: service,
      onTranscription: (_, _) {},
    );

    await controller.startSession();
    service.emit('hotels');
    service.fail(const VoiceFailure(
      VoiceFailureKind.network,
      'Recognition service unreachable.',
    ));

    expect(controller.state.failure?.kind, VoiceFailureKind.network);
    expect(controller.state.status, VoiceSearchStatus.stopped);
  });

  test('cancellation resets the state completely and cancels the service',
      () async {
    final service = _ScriptedVoiceService();
    final controller = VoiceSearchController(
      voiceService: service,
      onTranscription: (_, _) {},
    );

    await controller.startSession();
    service.emit('partial');
    await controller.cancelSession();

    expect(service.cancelCalls, 1);
    expect(controller.state.status, VoiceSearchStatus.idle);
    expect(controller.state.failure, isNull);
  });

  test('user stop keeps the state traceable (stopped, no failure)',
      () async {
    final service = _ScriptedVoiceService();
    final controller = VoiceSearchController(
      voiceService: service,
      onTranscription: (_, _) {},
    );

    await controller.startSession();
    service.emit('hotels in');
    await controller.stopSession();

    expect(service.stopCalls, 1);
    expect(controller.state.status, VoiceSearchStatus.stopped);
    expect(controller.state.failure, isNull);
  });

  test('a second tap during a live session is ignored by startSession',
      () async {
    final service = _ScriptedVoiceService();
    final controller = VoiceSearchController(
      voiceService: service,
      onTranscription: (_, _) {},
    );

    await controller.startSession();
    service.emit('x');
    // Still listening → the tap-to-stop path is the UI's job; a double
    // start must not re-enter the service.
    await controller.startSession();
    expect(service.startCalls, 1);
  });

  test('dismissFailure clears the inline error for the next session',
      () async {
    final service = _ScriptedVoiceService(
      startSucceeds: false,
      startFailure: const VoiceFailure(
        VoiceFailureKind.permissionDenied,
        'denied',
      ),
    );
    final controller = VoiceSearchController(
      voiceService: service,
      onTranscription: (_, _) {},
    );

    await controller.startSession();
    expect(controller.state.failure, isNotNull);
    controller.dismissFailure();
    expect(controller.state.failure, isNull);
  });

  test('failure taxonomy maps plugin codes deterministically', () {
    expect(voiceFailureKindFromCode('permission-denied'),
        VoiceFailureKind.permissionDenied);
    expect(voiceFailureKindFromCode('permanently-denied'),
        VoiceFailureKind.permissionDenied);
    expect(voiceFailureKindFromCode('mic-unavailable'),
        VoiceFailureKind.microphoneUnavailable);
    expect(voiceFailureKindFromCode('speech-not-available'),
        VoiceFailureKind.recognitionUnavailable);
    expect(voiceFailureKindFromCode('network-error'),
        VoiceFailureKind.network);
    expect(voiceFailureKindFromCode('cancel'), VoiceFailureKind.cancelled);
    expect(voiceFailureKindFromCode('weird-new-code'),
        VoiceFailureKind.unknown);
  });
}
