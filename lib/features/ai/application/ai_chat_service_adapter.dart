import 'package:tokigo/core/network/api_client.dart' show RequestToken;
import 'package:tokigo/core/ai/ai_assistant_service.dart';
import 'package:tokigo/features/ai/data/ai_chat_repository.dart';
import 'package:tokigo/features/ai/domain/ai_query_context.dart';
import 'package:tokigo/features/ai/domain/ai_response.dart';

/// 2C-C2 — bridges the 2C-C1 [AiChatRepository] into the EXISTING
/// [AiAssistantService] boundary so [AiController] keeps its cache,
/// retry, and state machinery with ZERO duplication ("لا duplicate state
/// management").
///
/// Routing: the repository itself decides the endpoint (token present →
/// memory-enriched `POST /ai/chat`; guest → the unchanged memory-free
/// `POST /ai/query`). This adapter adds exactly ONE policy the controller
/// cannot know: **caching is guest-only**.
///
/// Why: an authenticated reply depends on the caller's explicit memories
/// (and the personalization opt-out) at answer time — the same prompt can
/// legitimately answer differently after a memory edit, a clear, or a
/// personalization toggle. Serving a cached reply there would resurrect a
/// stale personalization forever (the same anti-resurrection policy Home
/// applies to withdrawn content). Guests have no memory machinery, so
/// their memory-free answers stay safely cacheable and instant.
class AiChatServiceAdapter implements AiAssistantService {
  AiChatServiceAdapter(this._repository);

  final AiChatRepository _repository;

  @override
  Future<AiResponse> query(
    String prompt, {
    RequestToken? token,
    Duration? timeout,
    AiQueryContext? context,
  }) {
    // The repository owns the endpoint choice (/ai/chat vs /ai/query).
    // The cache policy lives in `AiChatGuestOnlyCache`, which wraps the
    // OfflineCache handed to the controller — NOT here.
    return _repository.send(
      prompt,
      context: context,
      token: token,
      timeout: timeout,
    );
  }

  // Legacy content-generation surface: the conversation page never calls
  // these (verified — zero callers outside the interface). They stay as
  // explicit failures so an accidental future caller fails loudly instead
  // of silently hitting a dead path.
  @override
  Future<String> generateDescription({
    required String offerId,
    required String type,
  }) => throw UnimplementedError('legacy AI surface — not part of 2C chat');

  @override
  Future<List<String>> recommend({required String context}) =>
      throw UnimplementedError('legacy AI surface — not part of 2C chat');

  @override
  Future<List<String>> compareOffers({required List<String> offerIds}) =>
      throw UnimplementedError('legacy AI surface — not part of 2C chat');

  @override
  Future<String> generateOfferSummary({required String offerId}) =>
      throw UnimplementedError('legacy AI surface — not part of 2C chat');

  @override
  Future<String> generateContent({required String prompt}) =>
      throw UnimplementedError('legacy AI surface — not part of 2C chat');
}
