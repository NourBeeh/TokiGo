import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../core/navigation/resume_destination.dart';
import 'config/app_config.dart';
import 'widgets/resume_top_bar.dart';

/// The unified application shell.
///
/// NAV (2026-09-07): the floating bottom navigation pill is REMOVED — the
/// app is Home-centric. All product verticals route from the Home surface
/// through `HomeNavButtons` (flights / hotels / cars / packages) plus the
/// compact Groups entry; former tab pages are pushed routes on
/// the Home branch. The shell now simply hosts the navigation stack.
///
/// The historical pill (Home/Search/Groups/Explore) is retired by product
/// decision — `AppBottomNav` itself is KEPT in the codebase (no-deletion
/// rule) but has no consumer outside its own tests.
///
/// HOME OFF (2026-11, Task 11): while [AppConfig.homeEnabled] is false, the
/// shell pins the top bar (Home header + quick actions + resume button) above
/// the current page on browse destinations. The bar owns the status-bar inset,
/// so the page below has its top padding removed — and only there: every other
/// destination (auth, onboarding, notifications, …) keeps its own padding.
/// [ResumeTopBarScope] tells those pages the bar replaced their own header.
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
    final bool showTopBar =
        !AppConfig.homeEnabled && kSavableResumePaths.contains(location.path);
    return Scaffold(
      body: ResumeTopBarScope(
        visible: showTopBar,
        child: Column(
          children: <Widget>[
            if (showTopBar) const ResumeTopBar(),
            Expanded(
              // The top bar owns the status-bar inset, so the page's own top
              // padding is only redundant when the bar is actually there. On
              // every other destination (auth, onboarding, notifications, …)
              // the page still needs it — removing it unconditionally laid
              // those pages out under the status bar.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: showTopBar,
                child: navigationShell,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
