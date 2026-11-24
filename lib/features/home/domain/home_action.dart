/// The travel services Home exposes as quick-action tiles.
///
/// These are ROUTES, not in-page selections: tapping a tile navigates to its
/// top-level section.
enum HomeAction {
  flights,
  hotels,
  cars,
  activities,
  trips;

  /// Stable key used by tests and by the routed selected state.
  String get id => switch (this) {
    HomeAction.flights => 'flights',
    HomeAction.hotels => 'hotels',
    HomeAction.cars => 'cars',
    HomeAction.activities => 'activities',
    HomeAction.trips => 'trips',
  };

  /// The quick action matching a top-level service route.
  ///
  /// Null when the route is not one of Home's tiles (Profile, Wishlist,
  /// Notifications, …), so a host can derive its selected tile from the
  /// current router location without hardcoding the mapping twice.
  static HomeAction? fromPath(String path) => switch (path) {
    '/flights' => HomeAction.flights,
    '/hotels' => HomeAction.hotels,
    '/cars' => HomeAction.cars,
    '/packages' => HomeAction.activities,
    '/bag' => HomeAction.trips,
    _ => null,
  };
}
