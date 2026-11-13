/// A coarse, transient position fix.
///
/// Used ONLY to rank the Home "Stays Near You" rail by real distance. It is
/// never persisted, never cached and never sent to the AI — the app stores a
/// COUNTRY, not a location (owner decision, 2026-10-22).
class UserLocation {
  const UserLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}
