import 'dart:ui' show PlatformDispatcher;

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/voice_search_service.dart';

/// US-3 — real `speech_to_text` implementation of [VoiceSearchService].
///
/// Contract-preserving wrapper: the plugin's streams and error codes are
/// translated into the boundary's callbacks/taxonomy, and EVERY plugin
/// exception is swallowed into [VoiceFailure] — this class never throws.
/// Arabic + English locales per the spec (device locale first; an Arabic
/// device explicitly gets `ar-EG`, anything else uses the plugin default
/// which follows the device — covering English).
class SpeechToTextVoiceService implements VoiceSearchService {
  SpeechToTextVoiceService();

  final SpeechToText _speech = SpeechToText();

  /// Spec-friendly session bounds: a short, quiet listen. The plugin
  /// auto-stops after [SpeechListenOptions.listenFor]; partial results
  /// keep the field live.
  static const Duration listenFor = Duration(seconds: 15);
  static const Duration pauseFor = Duration(milliseconds: 1200);

  void Function(String partial, bool finalResult)? _onResult;
  void Function(VoiceFailure failure)? _onError;

  @override
  Future<bool> isAvailable() async {
    try {
      // initialize() is idempotent and requests permission when needed —
      // the spec wants the availability probe BEFORE the user commits.
      return await _speech.initialize();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> start({
    required void Function(String partial, bool finalResult) onResult,
    required void Function(VoiceFailure failure) onError,
  }) async {
    _onResult = onResult;
    _onError = onError;
    try {
      final initialized = await _speech.initialize(
        onError: (SpeechRecognitionError error) {
          _onError?.call(
            VoiceFailure(
              voiceFailureKindFromCode(error.errorMsg),
              'Voice recognition stopped.',
            ),
          );
        },
        // Status changes are informational (listening/notListening): a
        // self-stop (timeout/silence) surfaces through the final result,
        // never as an error.
        onStatus: (String status) {},
      );
      if (!initialized) {
        // initialize() == false ⇒ recognizer unavailable OR permission
        // denied — distinguish through hasPermission (no permission prompt
        // side effect: it only READS the current state).
        bool hasPermission = false;
        try {
          hasPermission = await _speech.hasPermission;
        } catch (_) {
          hasPermission = false;
        }
        onError(
          VoiceFailure(
            hasPermission
                ? VoiceFailureKind.recognitionUnavailable
                : VoiceFailureKind.permissionDenied,
            hasPermission
                ? 'Speech recognition is unavailable on this device.'
                : 'Microphone permission was denied.',
          ),
        );
        return false;
      }
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          _onResult?.call(result.recognizedWords, result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          autoPunctuation: true,
          listenMode: ListenMode.dictation,
          listenFor: listenFor,
          pauseFor: pauseFor,
          localeId: _localeForDevice(),
        ),
      );
      return true;
    } catch (_) {
      onError(
        const VoiceFailure(
          VoiceFailureKind.unknown,
          'Voice search could not start.',
        ),
      );
      return false;
    }
  }

  /// Arabic device → explicit `ar-EG` (the app's Arabic-first market);
  /// otherwise the plugin default follows the device locale (English and
  /// every other language). Never a failure.
  String? _localeForDevice() {
    try {
      final languageTag = PlatformDispatcher.instance.locale.toLanguageTag();
      return languageTag.startsWith('ar') ? 'ar-EG' : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {
      // Never throws — a dead recognizer is a no-op.
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {
      // Never throws.
    }
  }
}
