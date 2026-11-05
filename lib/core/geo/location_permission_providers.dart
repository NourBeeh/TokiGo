import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/geo/location_permission_service.dart';

/// The single source of OS-permission truth for the in-app explainer.
final locationPermissionServiceProvider = Provider<LocationPermissionService>(
  (ref) => LocationPermissionService(),
);

/// Non-prompting permission check. Resolves [LocationAccess.unavailable] on
/// platforms/tests that cannot answer, so no prompt is ever shown there.
final locationAccessProvider = FutureProvider<LocationAccess>((ref) {
  return ref.watch(locationPermissionServiceProvider).check();
});

/// Incremented when the traveller grants location access, so the country is
/// re-resolved with GPS instead of the IP fallback. An unchanged counter keeps
/// the session-scoped result — no repeated lookups.
final geoRefreshProvider = StateProvider<int>((ref) => 0);
