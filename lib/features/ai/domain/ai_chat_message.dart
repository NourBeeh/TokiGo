import 'package:flutter/foundation.dart';

import 'package:tokigo/core/domain/models/home/home_section.dart';

/// Who authored a chat message in the AI conversation.
enum AiChatRole { user, assistant }

/// A single immutable message in the AI chat conversation.
///
/// Assistant replies may carry renderable product [sections] — the unified
/// chat-first surface renders them as real cards inside the thread. Text-only
/// replies keep an empty [sections] list. [fromCache] marks a reply served
/// from the offline cache; [isDeterministic] marks a reply produced by the
/// direct structured-intent search (no AI round-trip).
@immutable
class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.text,
    this.fromCache = false,
    this.sections = const <HomeSection>[],
    this.isDeterministic = false,
  });

  const AiChatMessage.user(String text)
    : this(role: AiChatRole.user, text: text);

  const AiChatMessage.assistant(
    String text, {
    bool fromCache = false,
    List<HomeSection> sections = const <HomeSection>[],
    bool isDeterministic = false,
  }) : this(
         role: AiChatRole.assistant,
         text: text,
         fromCache: fromCache,
         sections: sections,
         isDeterministic: isDeterministic,
       );

  final AiChatRole role;
  final String text;

  /// Whether an assistant reply was served from the offline cache.
  final bool fromCache;

  /// Renderable product sections attached to an assistant reply.
  final List<HomeSection> sections;

  /// Whether this reply came from the deterministic structured-intent search.
  final bool isDeterministic;

  bool get isUser => role == AiChatRole.user;

  AiChatMessage copyWith({
    String? text,
    bool? fromCache,
    List<HomeSection>? sections,
    bool? isDeterministic,
  }) => AiChatMessage(
    role: role,
    text: text ?? this.text,
    fromCache: fromCache ?? this.fromCache,
    sections: sections ?? this.sections,
    isDeterministic: isDeterministic ?? this.isDeterministic,
  );

  // Equality is intentionally text/role/flag based (not sections): product
  // sections are rendering payloads, and keeping them out of equality keeps
  // the conversation-level tests deterministic.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiChatMessage &&
          other.role == role &&
          other.text == text &&
          other.fromCache == fromCache &&
          other.isDeterministic == isDeterministic;

  @override
  int get hashCode => Object.hash(role, text, fromCache, isDeterministic);

  @override
  String toString() => 'AiChatMessage(${role.name}, $text)';
}
