/// The travel services Home exposes as quick-action tiles.
///
/// Since the navigation refactor these are ROUTES, not in-page selections:
/// tapping a tile navigates to its top-level section. [today] is the synthetic
/// tile that navigates back to the Home dashboard (`/`); it is prepended by the
/// persistent app chrome and is deliberately not part of
/// `homeActionDefinitions`, which stays the five-service contract.
enum HomeAction {
  today,
  flights,
  hotels,
  cars,
  activities,
  groups,
  trips;

  /// Stable key used by tests and by the routed selected state.
  String get id => switch (this) {
    HomeAction.today => 'today',
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
    '/' => HomeAction.today,
    '/flights' => HomeAction.flights,
    '/hotels' => HomeAction.hotels,
    '/cars' => HomeAction.cars,
    '/packages' => HomeAction.activities,
    '/groups' => HomeAction.groups,
    '/bag' => HomeAction.trips,
    _ => null,
  };
}
