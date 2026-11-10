import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The initial location for the router, decided once at app start.
///
/// The app always launches on Today (`/`). Tests override this provider to
/// start on a specific route.
final lastInitialRouteProvider = Provider<String>((ref) => '/');
