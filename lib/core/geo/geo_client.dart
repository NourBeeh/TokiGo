import 'package:geolocator/geolocator.dart';
import 'package:tokigo/core/network/api_client.dart';

/// Country context for personalization (Phase 1C).
///
/// Resolves the user's country once per session through the R-4 backend
/// `GET /geo/country`: GPS coordinates are attempted ONCE, and only when the
/// permission is already granted — this client never raises the OS dialog
/// (the Home explainer owns that, Phase 3). Otherwise the backend falls back
/// to IP geolocation. The resolved country is COUNTRY level only: precise
/// coordinates are used for the single request and then discarded — they are
/// never stored, never cached, never sent to the AI.
class GeoClient {
  GeoClient(this._client, {Future<Position?> Function()? positionProvider})
    : _positionProvider = positionProvider ?? _defaultPosition;

  final ApiClient _client;
  final Future<Position?> Function() _positionProvider;

  bool _attempted = false;
  GeoCountry? _resolved;
  Future<GeoCountry?>? _pending;

  /// The resolved country for this session (null until resolved / on total
  /// failure). Never throws.
  Future<GeoCountry?> resolveCountry() async {
    if (_attempted) return await (_pending ?? Future.value(_resolved));
    _attempted = true;
    final pending = _resolveCountry();
    _pending = pending;
    return await pending;
  }

  Future<GeoCountry?> _resolveCountry() async {
    try {
      final position = await _positionProvider();
      final result = await _client.get<Map<String, dynamic>>(
        '/geo/country',
        queryParameters: <String, String>{
          if (position != null) 'lat': position.latitude.toStringAsFixed(4),
          if (position != null) 'lng': position.longitude.toStringAsFixed(4),
        },
      );
      _resolved = result.when(
        success: (data) {
          if (data['found'] != true) return null;
          return GeoCountry(
            countryCode: data['countryCode']?.toString(),
            country: data['country']?.toString(),
            confidence: data['confidence']?.toString(),
            source: data['source']?.toString(),
          );
        },
        failure: (_) => null,
      );
    } catch (_) {
      _resolved = null; // Geo unavailable → Home continues without it.
    }
    return _resolved;
  }

  /// Re-resolves after the traveller grants location access (Phase 3).
  ///
  /// The previous session result is discarded so the next lookup can use GPS
  /// instead of the IP fallback. Coordinates are still used for one request
  /// and never stored.
  Future<GeoCountry?> refreshCountry() async {
    _attempted = false;
    _pending = null;
    _resolved = null;
    return resolveCountry();
  }

  /// One silent GPS attempt: only when permission is ALREADY granted.
  /// Permission-denied/service-off/anything-else → null (no prompt, no
  /// block, no retry loop).
  static Future<Position?> _defaultPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      // Country-level only: a coarse fix is enough, faster, and keeps the
      // request short-lived (a 10-second ceiling, no endless wait).
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Country-level geo result (NO coordinates — by design).
class GeoCountry {
  const GeoCountry({
    this.countryCode,
    this.country,
    this.confidence,
    this.source,
  });

  final String? countryCode;
  final String? country;
  final String? confidence;
  final String? source;
}
