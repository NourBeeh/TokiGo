import 'package:flutter/material.dart';

import 'package:tokigo/app/config/app_config.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The destinations the app may reopen on (Task 11 — Home disabled by flag).
///
/// Only top-level **browse** destinations are allowed. A saved path has to be
/// a stable page that renders on its own, so the booking funnel, offer
/// details, onboarding, auth, notifications, Profile, Wishlist and anything
/// carrying a short-lived id is deliberately excluded — restoring one of those
/// would either strand the traveller or rebuild a dead flow. Profile and
/// Wishlist behave like Notifications: reachable from the header, never a
/// cold-start destination.
const Set<String> kSavableResumePaths = <String>{
  '/flights',
  '/hotels',
  '/cars',
  '/packages',
  '/groups',
  '/bag',
};

/// The six top-level service paths that render underneath the pinned resume
/// top bar.
///
/// Deliberately a SEPARATE set from [kSavableResumePaths]: the bar is chrome
/// for the service surfaces, while the resume allowlist also decides what a
/// cold start may reopen on. Profile and Wishlist are standalone pages — they
/// keep their own header and back button, so they must never grow a top bar.
const Set<String> kTopBarPaths = <String>{
  '/flights',
  '/hotels',
  '/cars',
  '/packages',
  '/groups',
  '/bag',
};

/// Query parameters that are safe to persist, per route.
///
/// A saved location must never carry a short-lived id (an offer, a search, a
/// trip) or anything account-specific, so each allowlisted path names the
/// parameters it accepts AND the values that are safe. Everything else is
/// dropped before the location is written.
const Map<String, Map<String, Set<String>>> kResumeQueryAllowlist =
    <String, Map<String, Set<String>>>{
      // Bag's only state is which of its two tabs is open; the default (trips)
      // needs no parameter at all.
      '/bag': <String, Set<String>>{
        'section': <String>{'likes', 'trips'},
      },
    };

/// The destination used when nothing valid was saved (first install, a stale
/// entry, or a saved path that no longer exists).
const String kDefaultResumePath = '/flights';

/// Whether [location] points at a destination the app may reopen on.
///
/// Compares the path only — query parameters are handled separately by
/// [sanitizeResumeLocation]. A null/empty value, or a path that is not
/// absolute, is not savable.
bool isSavableResumeLocation(String? location) {
  if (location == null || location.isEmpty) return false;
  final Uri? uri = Uri.tryParse(location);
  if (uri == null || !uri.path.startsWith('/')) return false;
  return kSavableResumePaths.contains(uri.path);
}

/// Strips every query parameter that is not explicitly allowlisted for the
/// location's path.
///
/// `/bag?section=likes` → `/bag?section=likes`, but `/bag?id=123` and
/// `/flights?tab=radar` → the bare path. A location whose path is not
/// savable yields an empty string, so the caller can skip the write.
String sanitizeResumeLocation(String location) {
  final Uri? uri = Uri.tryParse(location);
  if (uri == null || !isSavableResumeLocation(uri.path)) return '';
  final Map<String, Set<String>>? allowed = kResumeQueryAllowlist[uri.path];
  if (allowed == null || uri.queryParameters.isEmpty) return uri.path;
  final List<String> kept = <String>[];
  uri.queryParameters.forEach((String key, String value) {
    final Set<String>? values = allowed[key];
    if (values != null && values.contains(value)) {
      kept.add('${Uri.encodeComponent(key)}=${Uri.encodeComponent(value)}');
    }
  });
  return kept.isEmpty ? uri.path : '${uri.path}?${kept.join('&')}';
}

/// The location a cold start opens on.
///
/// Home first when it is enabled; otherwise the resume target. Pure, so both
/// branches are unit-testable without flipping the global flag.
String initialLocationFor({
  required bool homeEnabled,
  String? savedResume,
}) =>
    homeEnabled ? '/' : resolveResumeTarget(savedResume);

/// The route a "go Home" intent should land on.
///
/// Home exists only while `AppConfig.homeEnabled` is true. While it is off,
/// every fallback that used to point at '/' — a back press with no history, an
/// auth redirect, a disabled Groups route, a legacy Discover hand-off — must
/// resolve to the default service page instead, so no code path can land on a
/// route the app deliberately never builds. The router's own redirects use the
/// saved resume target when there is one; this is the pure fallback.
///
/// The flag is a parameter (defaulting to the build-time value) so both
/// branches are unit-testable without flipping the global.
String homeRoute({bool? homeEnabled}) =>
    (homeEnabled ?? AppConfig.homeEnabled) ? '/' : kDefaultResumePath;

/// The location a cold start should open on while Home is disabled.
///
/// The saved location wins when it is still valid; anything else (first
/// install, a stale entry, a path that no longer exists) falls back to
/// [kDefaultResumePath]. Pure, so the restore decision is unit-testable.
String resolveResumeTarget(String? saved) {
  if (!isSavableResumeLocation(saved)) return kDefaultResumePath;
  return saved!;
}

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
