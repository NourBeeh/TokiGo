import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The initial location for the app shell, decided once at app start.
///
/// Overridden in `main()` with the persisted `LastRouteStore.read()` value so
/// the app reopens on the tab the user was last on. Defaults to Flights.
final lastInitialRouteProvider = Provider<String>((ref) => '/flights');
