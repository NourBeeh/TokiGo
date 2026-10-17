import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

/// The unified application shell.
///
/// NAV (2026-09-07): the floating bottom navigation pill is REMOVED — the
/// app is Home-centric. All product verticals route from the Home surface
/// through `HomeNavButtons` (flights / hotels / cars / packages) plus the
/// compact Explore + Groups entries; former tab pages are pushed routes on
/// the Home branch. The shell now simply hosts the navigation stack.
///
/// The historical pill (Home/Search/Groups/Explore) is retired by product
/// decision — `AppBottomNav` itself is KEPT in the codebase (no-deletion
/// rule) but has no consumer outside its own tests.
class TokiGoShell extends StatelessWidget {
  const TokiGoShell({
    super.key,
    required this.navigationShell,
    required this.location,
  });

  final StatefulNavigationShell navigationShell;

  /// Live router location (kept for interface stability; the shell no longer
  /// branches its chrome on it).
  final Uri location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: navigationShell);
  }
}
