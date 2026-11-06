import 'package:flutter/material.dart';

import 'package:tokigo/l10n/app_localizations.dart';

/// The destinations the app may reopen on (Task 11 — Home disabled by flag).
///
/// Only top-level **browse** destinations are allowed. A saved path has to be
/// a stable page that renders on its own, so the booking funnel, offer
/// details, onboarding, auth, notifications and anything carrying a
/// short-lived id is deliberately excluded — restoring one of those would
/// either strand the traveller or rebuild a dead flow.
const Set<String> kSavableResumePaths = <String>{
  '/flights',
  '/hotels',
  '/cars',
  '/packages',
  '/groups',
  '/bag',
  '/profile',
  '/wishlist',
};

/// The destination used when nothing valid was saved (first install, a stale
/// entry, or a saved path that no longer exists).
const String kDefaultResumePath = '/flights';

/// Whether [location] may be persisted as the resume target.
///
/// Compares the path only — query parameters are ignored so a saved
/// `/bag?section=likes` still restores `/bag`. A null/empty value is simply
/// not savable.
bool isSavableResumeLocation(String? location) {
  if (location == null || location.isEmpty) return false;
  final Uri? uri = Uri.tryParse(location);
  if (uri == null || !uri.path.startsWith('/')) return false;
  return kSavableResumePaths.contains(uri.path);
}

/// The location a cold start should open on while Home is disabled.
///
/// The saved location wins when it is still valid; anything else (first
/// install, a stale entry, a path that no longer exists) falls back to
/// [kDefaultResumePath]. Pure, so the restore decision is unit-testable.
String resolveResumeTarget(String? saved) =>
    isSavableResumeLocation(saved) ? saved! : kDefaultResumePath;

/// The resume destination's glyph and localized label, for the pinned button.
class ResumeDestinationVisual {
  const ResumeDestinationVisual(this.icon, this.label);

  final IconData icon;
  final String label;

  /// Resolves [path] to its visual. Unknown paths fall back to Flights, the
  /// same default the restore logic uses.
  static ResumeDestinationVisual forPath(
    String path,
    AppLocalizations l10n,
  ) {
    return switch (path) {
      '/hotels' => ResumeDestinationVisual(
        Icons.hotel_rounded,
        l10n.searchHotels,
      ),
      '/cars' => ResumeDestinationVisual(
        Icons.directions_car_rounded,
        l10n.searchCars,
      ),
      '/packages' => ResumeDestinationVisual(
        Icons.beach_access_rounded,
        l10n.homeNavActivities,
      ),
      '/groups' => ResumeDestinationVisual(
        Icons.groups_rounded,
        l10n.homeNavGroups,
      ),
      '/bag' => ResumeDestinationVisual(
        Icons.shopping_bag_rounded,
        l10n.myTrips,
      ),
      '/profile' => ResumeDestinationVisual(
        Icons.person_rounded,
        l10n.profile,
      ),
      '/wishlist' => ResumeDestinationVisual(
        Icons.favorite_rounded,
        l10n.wishlist,
      ),
      _ => ResumeDestinationVisual(
        Icons.flight_takeoff_rounded,
        l10n.searchFlights,
      ),
    };
  }
}
