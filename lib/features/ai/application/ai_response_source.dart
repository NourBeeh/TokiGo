import 'package:tokigo/features/ai/domain/ai_response.dart';

/// Generates an AI response for a submitted prompt.
///
/// TEMPORARY CONTRACT: today it is implemented only by the in-memory mock
/// source; a later phase swaps in a real HTTP/backend provider without
/// touching the controller or the UI.
abstract interface class AiResponseSource {
  Future<AiResponse> generate(String prompt);
}