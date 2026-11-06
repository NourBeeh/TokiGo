/// The travel services Home can display in-page.
///
/// Home is a single-page dashboard: tapping a quick-action tile does NOT push a
/// route — it selects one of these values and the dashboard swaps its content
/// inside the same Home route/Scaffold.
enum HomeAction {
  flights,
  hotels,
  cars,
  activities,
  groups,
  trips;

  /// Stable key used by tests and by the persisted/selected state.
  String get id => switch (this) {
    HomeAction.flights => 'flights',
    HomeAction.hotels => 'hotels',
    HomeAction.cars => 'cars',
    HomeAction.activities => 'activities',
    HomeAction.groups => 'groups',
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
    '/groups' => HomeAction.groups,
    '/bag' => HomeAction.trips,
    _ => null,
  };
}
