import 'package:tokigo/core/geo/city_catalog.dart';
import 'package:tokigo/core/geo/city_selection.dart';
import 'package:tokigo/core/geo/geo_client.dart';

/// Background city detection.
///
/// One job: ask the backend (`/geo/locate`) for a city and hand it to the
/// selection controller. It never prompts for permission, never blocks a
/// customer flow, never overwrites a manual choice (the controller enforces
/// that), and keeps the last valid automatic city when a lookup fails.
class CityDetectionService {
  CityDetectionService({
    required Future<GeoLocatedCity?> Function() locate,
    required CityOption? Function() currentAutomatic,
    required Future<void> Function(CityOption city, CitySelectionSource source)
    onResolved,
    DateTime Function()? now,
  }) : _locate = locate,
       _currentAutomatic = currentAutomatic,
       _onResolved = onResolved,
       _now = now ?? (() => DateTime.now().toUtc());

  final Future<GeoLocatedCity?> Function() _locate;
  final CityOption? Function() _currentAutomatic;
  final Future<void> Function(CityOption city, CitySelectionSource source)
  _onResolved;
  final DateTime Function() _now;

  /// Detection is cheap but not free; an unchanged city is not re-fetched
  /// within this window unless the caller forces it (permission just granted).
  static const Duration cooldown = Duration(hours: 6);

  DateTime? _lastAttempt;
  bool _running = false;

  /// Runs detection unless it already ran inside [cooldown] and [force] is
  /// false. Returns the resolved city, or null when nothing changed.
  Future<CityOption?> detectIfNeeded({bool force = false}) async {
    if (_running) return null;
    final DateTime now = _now();
    final DateTime? last = _lastAttempt;
    if (!force && last != null && now.difference(last) < cooldown) {
      return null;
    }
    _running = true;
    _lastAttempt = now;
    try {
      final GeoLocatedCity? detected = await _locate();
      if (detected == null) return null;
      final CityOption city = CityOption(
        id: detected.cityId,
        name: detected.city,
        countryCode: detected.countryCode,
        currency: detected.currency,
        latitude: detected.latitude,
        longitude: detected.longitude,
      );
      final CityOption? current = _currentAutomatic();
      if (current != null && current.id == city.id) return null;
      await _onResolved(
        city,
        detected.fromGps ? CitySelectionSource.gps : CitySelectionSource.ip,
      );
      return city;
    } catch (_) {
      // A detection failure is never a customer-facing error.
      return null;
    } finally {
      _running = false;
    }
  }
}
