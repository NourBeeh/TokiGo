import 'package:tokigo/core/ai/ai_assistant_service.dart';
import 'package:tokigo/features/bag/domain/trip_unified.dart';

/// Post-booking contextual AI service (6C) — recommendations based on the
/// confirmed trip/book data (not invented; uses real booking references).
class PostBookingAiService {
  final AiAssistantService _service;

  PostBookingAiService(this._service);

  Future<String> recommendAfterBooking(Trip trip) async {
    final prompt = 'My trip (${trip.status}) with booking references '
        '${trip.bookingReferences.join(', ')} is confirmed. '
        'Suggest a complementary travel action (transfer, document, insurance, weather check) '
        'based only on real booking facts.';
    final response = await _service.generateContent(prompt: prompt);
    return response;
  }
}
