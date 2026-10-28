import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/ai/ai_assistant_service.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_serializers.dart';

import '../domain/ai_chat_message.dart';
import '../domain/ai_home_mapper.dart';
import '../domain/ai_query_context.dart';
import '../domain/ai_response.dart';
import 'ai_state.dart';
import 'chat_search_pipeline.dart';

/// Bridges [AiState] to the AI response pipeline.
///
/// Same `StateNotifier` style used across the app: immutable state +
/// explicit transitions. Depends only on the [AiAssistantService] abstraction
/// and the shared boundary mapper — it never touches mock/HTTP specifics.
class AiController extends StateNotifier<AiState> {
  AiController({
    required this._service,
    required this._mapper,
    required this._cache,
    this._searchPipeline,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const AiState());

  final AiAssistantService _service;
  final AiHomeMapper _mapper;
  final OfflineCache _cache;

  /// The deterministic structured-intent pipeline (unified chat-first
  /// surface). When null the controller behaves exactly as before — AI-only.
  final ChatSearchPipeline? _searchPipeline;

  /// Rolling conversation cap — memory stays bounded no matter how long the
  /// session runs.
  static const int maxMessages = 50;

  /// Idle expiry: a conversation untouched for longer than this is cleared
  /// when the user returns. In-memory state means an app restart already
  /// clears everything; backgrounding keeps the conversation alive.
  static const Duration conversationIdleTtl = Duration(hours: 6);

  DateTime? _lastInteraction;

  /// Injectable clock for deterministic TTL tests.
  final DateTime Function() _now;

  /// Drops the oldest messages beyond [maxMessages].
  List<AiChatMessage> _capped(List<AiChatMessage> messages) =>
      messages.length > maxMessages
      ? messages.sublist(messages.length - maxMessages)
      : messages;

  /// Clears the conversation if it has been idle longer than
  /// [conversationIdleTtl]. Exposed for the chat page so opening it after a
  /// long absence starts fresh even before any new submit.
  void expireIfIdle() {
    final last = _lastInteraction;
    if (last != null &&
        state.messages.isNotEmpty &&
        _now().difference(last) > conversationIdleTtl) {
      state = const AiState();
    }
  }

  /// Runs [prompt] through the assistant service, maps the result into
  /// renderable home sections and publishes a new [AiState].
  /// Phase 15B Stage 4: Accepts optional context, auto-builds from home sections if not provided.
  Future<void> submit(
    String prompt, {
    AiQueryContext? context,
    List<HomeSection> currentHomeSections = const [],
    Map<String, double>? geolocation,
    Map<String, String>? travelDates,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final cacheKey = aiQueryCacheKey(prompt: trimmed, context: context);

    // Idle expiry: returning after a long absence starts a fresh
    // conversation instead of resurrecting a stale one.
    expireIfIdle();

    // The user's message enters the conversation immediately, before any
    // network round-trip — the chat must feel instant.
    final messages = _capped([...state.messages, AiChatMessage.user(trimmed)]);

    // Deterministic-first: a query that compiles into a COMPLETE structured
    // intent runs through the EXISTING vertical controllers and returns real
    // product cards without an AI round-trip. Anything else (no intent, an
    // incomplete intent, or no results) falls through to the AI layer, which
    // is never a dead end.
    final pipeline = _searchPipeline;
    if (pipeline != null) {
      final suggestedOrigin = context?.metadata['suggestedOrigin']?.toString();
      final explicitPreferences = context?.metadata['explicitPreferences'];
      final preferences = explicitPreferences is Map
          ? explicitPreferences
          : const <String, dynamic>{};
      final preferredBudget = preferences['budget'];
      final budget = preferredBudget is Map
          ? preferredBudget
          : const <String, dynamic>{};
      final outcome = await pipeline.run(
        trimmed,
        suggestedOrigin: suggestedOrigin,
        preferredDestination: preferences['destination']?.toString(),
        preferredBudgetMin: (budget['min'] as num?)?.toDouble(),
        preferredBudgetMax: (budget['max'] as num?)?.toDouble(),
      );
      if (outcome.complete && outcome.sections.isNotEmpty) {
        _lastInteraction = _now();
        state = AiState(
          status: AiStatus.success,
          currentPrompt: trimmed,
          sections: outcome.sections,
          messages: _capped([
            ...messages,
            AiChatMessage.assistant(
              '',
              sections: outcome.sections,
              isDeterministic: true,
            ),
          ]),
        );
        return;
      }
    }

    // Try to load from cache first (for instant UI). Best-effort, same
    // policy as writes: a corrupt or unreadable entry must never block
    // submission — fall through to the live service instead.
    AiResponse? cachedResponse;
    try {
      final cached = await _cache.read(cacheKey);
      if (cached != null) {
        cachedResponse = aiResponseFromMap(cached);
        if (cachedResponse != null) {
          final sections = _mapper.toHomeSections(cachedResponse);
          final text = cachedResponse.text;

          if (sections.isNotEmpty || (text != null && text.trim().isNotEmpty)) {
            final replyText =
                (text == null || text.trim().isEmpty) && sections.isNotEmpty
                ? 'Here are some suggestions.'
                : text;
            _lastInteraction = _now();
            state = AiState(
              status: AiStatus.success,
              currentPrompt: trimmed,
              responseText: text,
              sections: sections,
              fromCache: true,
              messages: _capped([
                ...messages,
                AiChatMessage.assistant(replyText ?? '', fromCache: true),
              ]),
            );
            return;
          } else {
            cachedResponse = null;
          }
        }
      }
    } catch (_) {
      // Ignore cache read failures — proceed with a live request.
      cachedResponse = null;
    }

    state = AiState(
      status: AiStatus.loading,
      currentPrompt: trimmed,
      messages: messages,
    );

    // Build context automatically if not provided and we have home sections
    final AiQueryContext finalContext =
        context ??
        _mapper.extractContextFromHomeSections(
          currentHomeSections,
          geolocation: geolocation,
          travelDates: travelDates,
        );

    try {
      final response = await _service.query(trimmed, context: finalContext);
      final sections = _mapper.toHomeSections(response);
      final text = response.text;

      // Write to cache (best-effort)
      try {
        await _cache.write(cacheKey, aiResponseToMap(response));
      } catch (_) {
        // Ignore cache write failures
      }

      if (sections.isEmpty && (text == null || text.trim().isEmpty)) {
        _lastInteraction = _now();
        state = AiState(
          status: AiStatus.empty,
          currentPrompt: trimmed,
          messages: _capped([
            ...messages,
            const AiChatMessage.assistant(
              'No suggestions right now. Try a different prompt.',
            ),
          ]),
        );
      } else {
        _lastInteraction = _now();
        state = AiState(
          status: AiStatus.success,
          currentPrompt: trimmed,
          responseText: text,
          sections: sections,
          fromCache: false,
          messages: _capped([
            ...messages,
            AiChatMessage.assistant(
              (text == null || text.trim().isEmpty) && sections.isNotEmpty
                  ? 'Here are some suggestions.'
                  : (text ?? ''),
            ),
          ]),
        );
      }
    } catch (error) {
      // On network failure, show cached results if available
      if (cachedResponse != null) {
        final sections = _mapper.toHomeSections(cachedResponse);
        _lastInteraction = _now();
        state = AiState(
          status: AiStatus.success,
          currentPrompt: trimmed,
          responseText: cachedResponse.text,
          sections: sections,
          errorMessage: _userFacingMessage(error),
          fromCache: true,
          messages: _capped([
            ...messages,
            AiChatMessage.assistant(
              cachedResponse.text ?? 'Here are some suggestions.',
              fromCache: true,
            ),
          ]),
        );
      } else {
        _lastInteraction = _now();
        state = AiState(
          status: AiStatus.error,
          currentPrompt: trimmed,
          errorMessage: _userFacingMessage(error),
          messages: _capped([
            ...messages,
            AiChatMessage.assistant(_userFacingMessage(error)),
          ]),
        );
      }
    }
  }

  /// Re-runs the last prompt (used by the error-state retry action).
  Future<void> retry({
    AiQueryContext? context,
    List<HomeSection> currentHomeSections = const [],
    Map<String, double>? geolocation,
    Map<String, String>? travelDates,
  }) => submit(
    state.currentPrompt,
    context: context,
    currentHomeSections: currentHomeSections,
    geolocation: geolocation,
    travelDates: travelDates,
  );

  /// Returns the controller to its pristine idle state.
  void reset() {
    _lastInteraction = null;
    state = const AiState();
  }

  /// Translates a thrown failure into a message that is safe to display.
  ///
  /// [AiState.errorMessage] is rendered verbatim on the AI surface
  /// (`ai_response_content.dart` → `_AiErrorState`), while `HttpApiClient`
  /// stores the whole HTTP response body in [ApiError.message] and socket
  /// failures carry the host and port. Publishing `error.toString()` therefore
  /// put raw transport, backend and exception text on screen — including the
  /// backend's `AI_API_KEY is missing` configuration notice.
  ///
  /// Reuses the existing [ApiError] hierarchy rather than introducing a new
  /// error type. The switch is exhaustive over the sealed class, so adding a
  /// new [ApiError] subtype fails the build instead of silently leaking again.
  static String _userFacingMessage(Object error) {
    if (error is ApiError) {
      return switch (error) {
        ApiTimeoutError() =>
          'The assistant took too long to respond. Please try again.',
        ApiNetworkError() =>
          'No connection to the assistant. Check your internet and try again.',
        ApiUnauthorizedError() =>
          'Your session has expired. Please sign in and try again.',
        ApiParseError() =>
          'The assistant sent an unexpected reply. Please try again.',
        ApiServerError() =>
          'The assistant is temporarily unavailable. Please try again shortly.',
        ApiClientError() =>
          'That request could not be handled. Please rephrase and try again.',
        ApiRequestCancelledError() => 'Request cancelled.',
        ApiUnknownError() => _genericMessage,
      };
    }
    return _genericMessage;
  }

  static const String _genericMessage =
      'Something went wrong. Please try again.';
}
