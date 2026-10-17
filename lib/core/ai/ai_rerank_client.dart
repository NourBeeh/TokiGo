import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';

/// Client for the Phase 1C `POST /ai/rerank` endpoint.
///
/// Strict contract on the client side too: the ranked ids are validated
/// against the submitted candidate set — any id the AI did not receive is
/// dropped, and an all-unknown or failed response degrades to
/// [AiRerankResult.fallback] with the ORIGINAL deterministic order. The AI is
/// an optional enhancement; Home never depends on it.
class AiRerankClient {
  AiRerankClient(this._client, this._tokenStorage);

  final ApiClient _client;
  final SecureTokenStorage _tokenStorage;

  Future<AiRerankResult> rerank({
    required Map<String, dynamic> context,
    required List<AiRerankCandidate> candidates,
    required List<String> allowedReasons,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final knownIds = candidates.map((c) => c.id).toSet();
    final deterministic = AiRerankResult(
      rankedCandidateIds: candidates.map((c) => c.id).toList(),
      sectionReason: 'recommendation',
      confidence: null,
      fallback: true,
    );

    if (candidates.isEmpty) return deterministic;
    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) return deterministic;
      final result = await _client.post<Map<String, dynamic>>(
        '/ai/rerank',
        body: <String, dynamic>{
          'context': context,
          'candidates': candidates
              .map((c) => <String, dynamic>{
                    'id': c.id,
                    'title': c.title,
                    if (c.price != null) 'price': c.price,
                    if (c.metadata.isNotEmpty) 'metadata': c.metadata,
                  })
              .toList(),
          'allowedReasons': allowedReasons,
        },
        headers: <String, String>{'Authorization': 'Bearer $token'},
        timeout: timeout,
      );
      return result.when(
        success: (data) {
          final ids = (data['rankedCandidateIds'] as List? ?? [])
              .map((e) => e.toString())
              .where((id) => knownIds.contains(id))
              .toList();
          if (ids.isEmpty) return deterministic;
          final reason = data['sectionReason']?.toString();
          return AiRerankResult(
            rankedCandidateIds: ids,
            sectionReason: (reason != null && allowedReasons.contains(reason))
                ? reason
                : 'recommendation',
            confidence: (data['confidence'] is num)
                ? (data['confidence'] as num).toDouble().clamp(0, 1)
                : null,
            fallback: data['fallback'] == true,
          );
        },
        failure: (_) => deterministic,
      );
    } catch (_) {
      return deterministic; // AI/network/parse failure → deterministic order.
    }
  }
}

/// One real candidate for reranking (from provider/recommendation sources).
class AiRerankCandidate {
  const AiRerankCandidate({
    required this.id,
    required this.title,
    this.price,
    this.metadata = const {},
  });

  final String id;
  final String title;
  final double? price;
  final Map<String, dynamic> metadata;
}

/// Validated rerank outcome.
class AiRerankResult {
  const AiRerankResult({
    required this.rankedCandidateIds,
    required this.sectionReason,
    this.confidence,
    required this.fallback,
  });

  final List<String> rankedCandidateIds;
  final String sectionReason;
  final double? confidence;
  final bool fallback;
}
