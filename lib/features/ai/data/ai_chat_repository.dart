import 'package:tokigo/core/network/api_client.dart';

import '../../../features/ai/domain/ai_query_context.dart';
import '../../../features/ai/domain/ai_response.dart';

/// 2C-C1 — AI conversation repository boundary (Phase 2C-C1 contract).
///
/// The ONLY surface Flutter has for the memory-enriched conversation
/// endpoint `POST /ai/chat`. Contract (from محرك التوصيات.txt 2C-C1):
/// - authenticated users → `/ai/chat` (server enriches with explicit
///   conversation memories; extraction happens server-side too);
/// - guests → the EXISTING memory-free `/ai/query` path, unchanged;
/// - `prompt <= 4000` enforced client-side BEFORE any network call;
/// - Flutter NEVER extracts memories, NEVER decides relevance, NEVER sends
///   a raw transcript as memory — all memory intelligence lives in the
///   backend (RelevantMemorySelector + ConversationMemoryService).
abstract interface class AiChatRepository {
  /// Sends one conversation turn.
  ///
  /// [prompt] is trimmed client-side; empty or >4000 chars fails fast with
  /// [AiChatValidationException] before any request is made.
  ///
  /// [token] optionally allows cancellation (same RequestToken pattern as
  /// every repository in the app). [timeout] overrides the client default
  /// (AI calls run long — the backend provider allows up to 90s).
  Future<AiResponse> send(
    String prompt, {
    AiQueryContext? context,
    RequestToken? token,
    Duration? timeout,
  });
}

/// Client-side prompt contract violations (empty / over-limit).
///
/// Deliberately NOT an ApiError — the request never left the device.
class AiChatValidationException implements Exception {
  const AiChatValidationException(this.message);

  final String message;

  /// The 2C-C1 hard prompt limit, mirrored from the backend AiChatDto
  /// MaxLength(4000) so the client rejects early with a clear message.
  static const int maxPromptLength = 4000;

  @override
  String toString() => 'AiChatValidationException: $message';
}
