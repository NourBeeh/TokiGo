import 'package:flutter/foundation.dart';

import 'trip.dart';

/// Unified Trip model (Phase 5A) — combines booked items with a coherent
/// timeline and readiness checklist, without inventing missing data.
@immutable
class Trip {
  final String tripId;
  final String userId;
  final List<TripItem> items;
  final DateTime createdAt;
  final String status; /// planned | confirmed | cancelled | completed

  /// Real provider references carried by confirmed bookings.
  final List<String> bookingReferences;

  /// Readiness gaps (missing transfer, return leg, document, etc.)
  /// derived honestly from the trip's real items.
  final List<String> readinessGaps;

  const Trip({
    required this.tripId,
    required this.userId,
    this.items = const <TripItem>[],
    required this.createdAt,
    required this.status,
    this.bookingReferences = const <String>[],
    this.readinessGaps = const <String>[],
  });

  /// Simplified sandbox version (5A) — real items only, no synthetic gaps.
  factory Trip.sandbox({
    required String tripId,
    required String userId,
    required List<TripItem> items,
    required String status,
  }) => Trip(
        tripId: tripId,
        userId: userId,
        items: items,
        createdAt: DateTime.now(),
        status: status,
        bookingReferences: <String>[],
        readinessGaps: <String>[],
      );
}
