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

/// Session-scoped dismissal of the Home explainer. A refusal is not a
/// permanent preference: the OS keeps the real decision, and a new session
/// may ask again. Persisting a "never ask" flag would silently strand
/// travellers who dismissed the card by accident.
final locationPromptDismissedProvider = StateProvider<bool>((ref) => false);
