import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/step_progress.dart'
    show BookingStatusTone;
import 'package:tokigo/l10n/app_localizations.dart';

/// The Bag's one vocabulary for a trip: which vertical it is, what its status
/// reads as, and the dates it may honestly claim.
///
/// Shared by the My Trips list and the trip details page so a hotel trip cannot
/// be called "Flight" on one surface and "Hotel" on the other.

/// The icon that stands for a vertical (also the card's photo fallback).
IconData tripTypeIcon(String type) {
  return switch (type) {
    'hotel' => Icons.house_rounded,
    'flight' => Icons.flight_takeoff_rounded,
    'car' => Icons.directions_car_rounded,
    'package' => Icons.card_travel_rounded,
    _ => Icons.receipt_long_rounded,
  };
}

/// The localized name of a vertical. Unknown types read as "Booking" rather
/// than leaking a raw backend token.
String tripTypeLabel(AppLocalizations l10n, String type) {
  return switch (type) {
    'hotel' => l10n.tripTypeHotel,
    'flight' => l10n.tripTypeFlight,
    'car' => l10n.tripTypeCar,
    'package' => l10n.tripTypePackage,
    _ => l10n.tripTypeBooking,
  };
}

/// The localized label of a booking status (`BookingStatus.name`).
String tripStatusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'confirmed' => l10n.bookingStatusConfirmed,
    'pending' => l10n.tripStatusPending,
    'cancelled' => l10n.tripStatusCancelled,
    'failed' => l10n.tripStatusFailed,
    'draft' => l10n.tripStatusDraft,
    _ => l10n.tripStatusPending,
  };
}

/// The [BookingStatusTone] a booking status maps onto.
///
/// The chip's fill and ink both come from `StatusChip.forTone`, so the label
/// and the palette can never drift apart: `confirmed` is the success pair,
/// `pending`/`draft` the warning pair, and the terminal states (`cancelled`,
/// `failed`) share the neutral pair. Unknown statuses follow
/// [tripStatusLabel] and read as pending.
BookingStatusTone tripStatusTone(String status) {
  return switch (status) {
    'confirmed' => BookingStatusTone.confirmed,
    'cancelled' || 'failed' => BookingStatusTone.cancelled,
    _ => BookingStatusTone.pending,
  };
}

/// The semantic hue for a booking status, resolved from the ACTIVE palette.
///
/// Kept for surfaces that need the bare colour (a trailing dot or icon); the
/// status chips themselves go through `StatusChip.forTone`, which pairs the hue
/// with its container and an AA-passing ink.
Color tripStatusColor(TokiGoColors palette, String status) {
  return switch (status) {
    'confirmed' => palette.success,
    'cancelled' || 'failed' => palette.danger,
    'pending' || 'draft' => palette.warning,
    _ => palette.textSecondary,
  };
}

/// The two date labels a vertical uses (start, end). A package has no such
/// pair, so it returns nulls and the surface omits both rows.
(String?, String?) tripDateLabels(AppLocalizations l10n, String type) {
  return switch (type) {
    'hotel' => (l10n.offerCheckIn, l10n.offerCheckOut),
    'car' => (l10n.offerPickup, l10n.offerDropOff),
    'flight' => (l10n.confirmationDeparture, l10n.confirmationArrival),
    _ => (null, null),
  };
}
