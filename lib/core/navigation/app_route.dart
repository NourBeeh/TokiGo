import 'package:flutter/material.dart';

/// Canonical navigation destinations for TokiGo.
///
/// Used by the floating navigation, router and future drag/reorder controllers
/// so a single source of truth drives labels, icons and ordering.
enum AppRoute {
  home('Home', Icons.home_outlined, Icons.home),
  search('Search', Icons.search_outlined, Icons.search),
  flights('Flights', Icons.flight, Icons.flight),
  hotels('Hotels', Icons.hotel_outlined, Icons.hotel),
  cars('Cars', Icons.directions_car_outlined, Icons.directions_car),
  packages('Tour programs', Icons.beach_access_outlined, Icons.beach_access),
  transfers(
    'Airport transfer',
    Icons.airport_shuttle_outlined,
    Icons.airport_shuttle,
  ),
  groups('Groups', Icons.groups_outlined, Icons.groups),
  bag('Bag', Icons.shopping_bag_outlined, Icons.shopping_bag),
  notifications('Notifications', Icons.notifications_none, Icons.notifications),
  profile('Profile', Icons.person_outlined, Icons.person),
  settings('Settings', Icons.settings_outlined, Icons.settings),
  auth('Sign in', Icons.login_rounded, Icons.login_rounded);

  const AppRoute(this.label, this.outlinedIcon, this.filledIcon);

  final String label;
  final IconData outlinedIcon;
  final IconData filledIcon;

  /// The route segment used to build paths (e.g. `/flights`).
  String get path => '/$name';

  /// Destinations surfaced in the floating navigation (Settings/Auth are
  /// reached through the shell rather than the primary radial menu).
  static const List<AppRoute> primaryDestinations = <AppRoute>[
    AppRoute.home,
    AppRoute.search,
    AppRoute.flights,
    AppRoute.hotels,
    AppRoute.cars,
    AppRoute.packages,
    AppRoute.transfers,
    AppRoute.groups,
    AppRoute.bag,
    AppRoute.notifications,
    AppRoute.profile,
    AppRoute.settings,
  ];

  IconData iconFor({bool selected = false}) =>
      selected ? filledIcon : outlinedIcon;
}
