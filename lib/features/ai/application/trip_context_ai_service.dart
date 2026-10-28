import 'package:tokigo/core/ai/ai_assistant_service.dart';
import 'package:tokigo/features/ai/domain/ai_query_context.dart';
import 'package:tokigo/features/bag/domain/trip_unified.dart';

/// Minimal trip-context AI service (6B) — feeds trip/book facts into the AI
/// query so recommendations are grounded in the real itinerary, not invented.
class TripContextAiService {
  final AiAssistantService _service;

  TripContextAiService(this._service);

  Future<String> contextualRecommendation(Trip trip) async {
    final context = AiQueryContext(
      route: 'bag',
      screenTitle: 'Trip (${trip.tripId})',
      metadata: {
        'tripId': trip.tripId,
        'status': trip.status,
        'itemsCount': trip.items.length,
        'bookingReferences': trip.bookingReferences,
      },
    );
    final response = await _service.query(
      'Based on my trip (${trip.status}) with ${trip.items.length} booked items, '
      'suggest any missing preparation or complementary action.',
      context: context,
    );
    return response.text ?? 'No contextual recommendation available.';
  }
}
