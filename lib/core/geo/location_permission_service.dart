import 'package:geolocator/geolocator.dart';

/// The outcome of a location-permission check or request.
///
/// The distinction matters to the UI:
/// - [denied] may be asked again — show the in-app explainer + Allow button;
/// - [deniedForever] can only be changed in the system settings;
/// - [serviceDisabled] means the permission may be fine but GPS is off;
/// - [unavailable] means the platform could not answer (desktop, tests) —
///   never surface a prompt for it.
enum LocationAccess {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unavailable,
}

/// One place that talks to the OS location permission.
///
/// Owner decision (2026-10-22): the app asks for location only from an
/// explicit, dismissible in-app prompt — never automatically on launch and
/// never from a background path. The permission is used ONCE to resolve the
/// traveller's country (for the departure-airport suggestion); precise
/// coordinates are not stored by the app.
///
/// The platform calls are injectable so the mapping is unit-testable without
/// a device.
class LocationPermissionService {
  LocationPermissionService({
    Future<bool> Function()? isServiceEnabled,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Future<bool> Function()? openAppSettings,
    Future<bool> Function()? openLocationSettings,
  }) : _isServiceEnabled =
           isServiceEnabled ?? Geolocator.isLocationServiceEnabled,
       _checkPermission = checkPermission ?? Geolocator.checkPermission,
       _requestPermission = requestPermission ?? Geolocator.requestPermission,
       _openAppSettings = openAppSettings ?? Geolocator.openAppSettings,
       _openLocationSettings =
           openLocationSettings ?? Geolocator.openLocationSettings;

  final Future<bool> Function() _isServiceEnabled;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;
  final Future<bool> Function() _openAppSettings;
  final Future<bool> Function() _openLocationSettings;

  /// Current permission WITHOUT prompting.
  Future<LocationAccess> check() async {
    try {
      if (!await _isServiceEnabled()) return LocationAccess.serviceDisabled;
      return _map(await _checkPermission());
    } catch (_) {
      return LocationAccess.unavailable;
    }
  }

  /// Ask the OS — only ever called from the user's own tap.
  Future<LocationAccess> request() async {
    try {
      if (!await _isServiceEnabled()) return LocationAccess.serviceDisabled;
      var permission = await _checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _requestPermission();
      }
      return _map(permission);
    } catch (_) {
      return LocationAccess.unavailable;
    }
  }

  Future<void> openSettings() async {
    try {
      await _openAppSettings();
    } catch (_) {
      // Settings are best-effort; the prompt simply stays as it is.
    }
  }

  Future<void> openLocationSettings() async {
    try {
      await _openLocationSettings();
    } catch (_) {
      // See above.
    }
  }

  LocationAccess _map(LocationPermission permission) {
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      // `denied` (not yet asked) and `unableToDetermine` both allow a prompt.
      _ => LocationAccess.denied,
    };
  }
}
