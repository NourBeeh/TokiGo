import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/features/ai/domain/ai_response.dart';
import 'package:tokigo/features/ai/domain/ai_query_context.dart';

/// AI assistant service boundary.
///
/// The legacy content-generation methods are preserved. `query` is the new
/// prompt → [AiResponse] contract used by the assistant chat workflow; the
/// controller depends on this abstraction and never sees the concrete
/// transport (mock today, HTTP/backend later).
abstract interface class AiAssistantService {
  Future<String> generateDescription({
    required String offerId,
    required String type,
  });
  Future<List<String>> recommend({required String context});
  Future<List<String>> compareOffers({required List<String> offerIds});
  Future<String> generateOfferSummary({required String offerId});
  Future<String> generateContent({required String prompt});

  /// Requests a full structured [AiResponse] for [prompt].
  ///
  /// [token] optionally allows callers to cancel/ignore the request before
  /// completion; [timeout] overrides the default client timeout for this call.
  /// [context] optionally includes current page/route context for context-aware queries.
  Future<AiResponse> query(
    String prompt, {
    RequestToken? token,
    Duration? timeout,
    AiQueryContext? context,
  });
}
