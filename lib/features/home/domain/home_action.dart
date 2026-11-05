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
}
