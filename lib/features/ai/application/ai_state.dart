import 'package:flutter/foundation.dart';

import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/features/ai/domain/ai_chat_message.dart';

/// Lifecycle status of an AI interaction.
enum AiStatus { idle, loading, success, empty, error }

/// Immutable AI assistant state.
/// // Immutable AI assistant state.
///
/// Mirrors the `StateNotifier` state shapes used by Home/Search/Auth:
/// a `status` gate plus the data that each phase needs.
@immutable
class AiState {
  const AiState({
    this.status = AiStatus.idle,
    this.currentPrompt = '',
    this.responseText,
    this.sections = const [],
    this.errorMessage,
    this.fromCache = false,
    this.messages = const [],
  });

  final AiStatus status;

  /// The most recent submitted prompt (empty until the first submit).
  final String currentPrompt;

  /// Natural-language content of the latest response.
  final String? responseText;

  /// Mapped renderable home sections for the latest response.
  final List<HomeSection> sections;

  final String? errorMessage;

  /// Whether the current data was loaded from the offline cache.
  final bool fromCache;

  /// The running conversation shown in the chat window: user prompts and
  /// assistant replies, oldest first. Persists across panel open/close
  /// within a session; [reset] clears it.
  final List<AiChatMessage> messages;

  /// The last message in the conversation, or null when empty.
  AiChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  AiState copyWith({
    AiStatus? status,
    String? currentPrompt,
    String? responseText,
    List<HomeSection>? sections,
    String? errorMessage,
    bool? fromCache,
    List<AiChatMessage>? messages,
  }) {
    return AiState(
      status: status ?? this.status,
      currentPrompt: currentPrompt ?? this.currentPrompt,
      responseText: responseText ?? this.responseText,
      sections: sections ?? this.sections,
      errorMessage: errorMessage ?? this.errorMessage,
      fromCache: fromCache ?? this.fromCache,
      messages: messages ?? this.messages,
    );
  }
}
