import 'package:tokigo/core/ai/ai_assistant_service.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/features/ai/domain/ai_response.dart';
import 'package:tokigo/features/ai/domain/ai_query_context.dart';

/// Real HTTP implementation of [AiAssistantService].
///
/// Talks to the TokiGo NestJS BFF endpoint `POST /ai/query` through the
/// shared [ApiClient] — timeouts, non-2xx, malformed JSON and connectivity
/// failures are already mapped by the client into [ApiResult] failures, so
/// this service never crashes; it simply rethrows the failure for the
/// controller to surface. The normalized backend payload is parsed straight
/// into the exact Flutter contract via [AiResponse.fromMap].
class AiApiService implements AiAssistantService {
  AiApiService(this._client);

  final ApiClient _client;

  static const String _queryPath = '/ai/query';
  static const String _suggestPath = '/ai/suggest';

  @override
  Future<AiResponse> query(
    String prompt, {
    RequestToken? token,
    Duration? timeout,
    AiQueryContext? context,
  }) async {
    final body = <String, dynamic>{'prompt': prompt};
    if (context != null) {
      body['context'] = context.toMap();
    }

    final result = await _client.post<Map<String, dynamic>>(
      _queryPath,
      body: body,
      timeout: timeout,
      token: token,
    );

    final map = result.when(
      success: (data) => data,
      failure: (error) => throw error,
    );
    return AiResponse.fromMap(map);
  }

  @override
  Future<String> generateContent({required String prompt}) async {
    final response = await query(prompt);
    return response.text ?? '';
  }

  /// Live typeahead suggestions for the smart search sheet.
  ///
  /// Short timeout on purpose: suggestions are a progressive enhancement —
  /// on any failure the caller silently falls back to local prompts.
  Future<List<String>> suggest(
    String query, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final body = <String, dynamic>{'query': query};

    final result = await _client.post<Map<String, dynamic>>(
      _suggestPath,
      body: body,
      timeout: timeout,
    );

    final map = result.when(
      success: (data) => data,
      failure: (error) => throw error,
    );
    final suggestions = map['suggestions'];
    if (suggestions is List) {
      return suggestions
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  @override
  Future<String> generateDescription({
    required String offerId,
    required String type,
  }) {
    throw UnimplementedError(
      'generateDescription is not implemented by the HTTP AI service.',
    );
  }

  @override
  Future<List<String>> recommend({required String context}) {
    throw UnimplementedError(
      'recommend is not implemented by the HTTP AI service.',
    );
  }

  @override
  Future<List<String>> compareOffers({required List<String> offerIds}) {
    throw UnimplementedError(
      'compareOffers is not implemented by the HTTP AI service.',
    );
  }

  @override
  Future<String> generateOfferSummary({required String offerId}) {
    throw UnimplementedError(
      'generateOfferSummary is not implemented by the HTTP AI service.',
    );
  }
}
