import 'dart:async';

import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';

/// Fire-and-forget behavioral event tracker (Phase 1C).
///
/// Posts the EXISTING backend event types to `POST /events` — auth-only by
/// design (the endpoint's JWT guard rejects guests; the approved decision for
/// this phase). Rules:
///
/// - Fire-and-forget: every call returns immediately; failures are silent.
/// - No duplicates: the last payload hash per event type is remembered and
///   identical repeats within the session are dropped.
/// - Never blocks or breaks any UI: all errors are swallowed.
class EventsTracker {
  EventsTracker(this._client, this._tokenStorage);

  final ApiClient _client;
  final SecureTokenStorage _tokenStorage;

  /// Event types the backend accepts (EVENT_TYPES in event.dto.ts).
  static const List<String> knownTypes = [
    'hotel_search',
    'hotel_view',
    'hotel_favorite',
    'trip_planned',
    'booking_confirmed',
  ];

  final Map<String, String> _lastPayloadHash = <String, String>{};

  /// Records a `hotel_search` signal.
  void hotelSearch({
    required String destination,
    double? minPrice,
    double? maxPrice,
  }) {
    _track('hotel_search', <String, dynamic>{
      'destination': destination,
      'minPrice': ?minPrice,
      'maxPrice': ?maxPrice,
    });
  }

  /// Records a `hotel_view` signal (offer details opened).
  void hotelView({required String hotelId, required String title}) {
    _track('hotel_view', <String, dynamic>{'hotelId': hotelId, 'title': title});
  }

  /// Records a `hotel_favorite` toggle (value=false unfavorites are not
  /// tracked — the backend list models favorites, not unfavorites).
  void hotelFavorite({required String hotelId, required String title}) {
    _track('hotel_favorite', <String, dynamic>{
      'hotelId': hotelId,
      'title': title,
    });
  }

  /// Records a `trip_planned` signal (trip added to the Bag).
  void tripPlanned({required String destination}) {
    _track('trip_planned', <String, dynamic>{'destination': destination});
  }

  /// Records a `booking_confirmed` signal.
  void bookingConfirmed({required String destination}) {
    _track('booking_confirmed', <String, dynamic>{'destination': destination});
  }

  void _track(String type, Map<String, dynamic> payload) {
    // Duplicate guard: identical type+payload within this session is dropped.
    final hash = '$type:${payload.hashCode}';
    if (_lastPayloadHash[type] == hash) return;
    _lastPayloadHash[type] = hash;

    // Fire-and-forget — never await from the caller's flow.
    unawaited(() async {
      try {
        final token = await _tokenStorage.getAccessToken();
        if (token == null || token.isEmpty) return; // Guests are not tracked.
        await _client.post<void>(
          '/events',
          body: <String, dynamic>{'type': type, 'payload': payload},
          headers: <String, String>{'Authorization': 'Bearer $token'},
        );
      } catch (_) {
        // Event failures must never affect the UI. Silent.
      }
    }());
  }
}
