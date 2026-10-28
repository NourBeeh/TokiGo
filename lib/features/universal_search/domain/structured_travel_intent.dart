import 'package:flutter/foundation.dart';

/// Budget band extracted from natural language (US-2) — a controlled
/// vocabulary, never a raw free-form number: the LLM/grammar may say
/// "cheap" or "luxury", the EXECUTION layer decides what each band means
/// in concrete search-param values.
enum IntentBudgetBand { none, low, medium, high }

/// A missing piece of a valid intent — surfaced to the user as a
/// follow-up question chip instead of silently inventing a value
/// (US-2 §3: never invent facts).
enum IntentGap {
  origin,
  destination,
  dates,
  passengers,
  budget,
  rooms,
  service,
  unsupportedPackage,
}

/// The structured travel intent a natural query is compiled into
/// (US-0 contract §10): AI never answers with bare text — the query is
/// parsed into this shape, then fed into the EXISTING search controllers.
///
/// US-2 extension: strongly-typed fields for duration, rooms, budget band,
/// minimum stars and amenities — each maps onto an EXISTING search-params
/// field. No free-form blobs.
@immutable
class StructuredTravelIntent {
  const StructuredTravelIntent({
    required this.type,
    this.origin,
    this.destination,
    this.date,
    this.returnDate,
    this.durationNights,
    this.passengers,
    this.rooms,
    this.budget = IntentBudgetBand.none,
    this.preferredBudgetMin,
    this.preferredBudgetMax,
    this.minStars,
    this.amenities = const [],
  });

  /// `flight` | `hotel` | `car` | `package` — mirrors the existing search
  /// verticals, never invents a new service.
  final String type;

  final String? origin;
  final String? destination;

  final DateTime? date;
  final DateTime? returnDate;

  /// "3 ليالي" — nights between checkIn/checkOut (hotel) or the rental
  /// span (car). Maps onto the existing date arithmetic, never a new param.
  final int? durationNights;

  final int? passengers;

  /// Hotel rooms — HotelSearchParams.rooms.
  final int? rooms;

  /// Controlled budget vocabulary (see [IntentBudgetBand]).
  final IntentBudgetBand budget;

  /// Explicit AI-memory budget bounds for a chat/search request only.
  final double? preferredBudgetMin;
  final double? preferredBudgetMax;

  /// "5 نجوم" — HotelSearchParams.minRating.
  final double? minStars;

  /// Named hotel amenities — HotelSearchParams.amenities.
  final List<String> amenities;

  /// Applies a follow-up patch (US-0 §12 / US-2 §8): cheaper/more
  /// premium/change dates/... return a NEW intent with the patched field —
  /// the original stays immutable.
  StructuredTravelIntent copyWith({
    String? type,
    String? origin,
    String? destination,
    DateTime? date,
    DateTime? returnDate,
    int? durationNights,
    int? passengers,
    int? rooms,
    IntentBudgetBand? budget,
    double? preferredBudgetMin,
    double? preferredBudgetMax,
    double? minStars,
    List<String>? amenities,
  }) {
    return StructuredTravelIntent(
      type: type ?? this.type,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      date: date ?? this.date,
      returnDate: returnDate ?? this.returnDate,
      durationNights: durationNights ?? this.durationNights,
      passengers: passengers ?? this.passengers,
      rooms: rooms ?? this.rooms,
      budget: budget ?? this.budget,
      preferredBudgetMin: preferredBudgetMin ?? this.preferredBudgetMin,
      preferredBudgetMax: preferredBudgetMax ?? this.preferredBudgetMax,
      minStars: minStars ?? this.minStars,
      amenities: amenities ?? this.amenities,
    );
  }

  /// The gaps that MUST be resolved before the intent may execute
  /// (US-2 §3 — no invented facts). Anything optional is not a gap:
  /// hotel/car searches run fine without explicit dates by the vertical
  /// flows' own conventions; flights REQUIRE both endpoints.
  List<IntentGap> missingFields() {
    final gaps = <IntentGap>[];
    switch (type) {
      case 'flight':
        if (origin == null) gaps.add(IntentGap.origin);
        if (destination == null) gaps.add(IntentGap.destination);
      case 'hotel':
        if (destination == null) gaps.add(IntentGap.destination);
      case 'car':
        if (destination == null && origin == null) {
          gaps.add(IntentGap.destination);
        }
      case 'package':
        // Phase 19B: package search is a mock surface with no backend
        // controller — flag instead of pretending to execute.
        gaps.add(IntentGap.unsupportedPackage);
    }
    return gaps;
  }

  /// True when every field the vertical flow REQUIRES is present.
  bool get isComplete => missingFields().isEmpty;

  /// The canonical end date for stay/rental spans — an explicit return
  /// date wins, then the parsed duration, then the vertical's own default.
  DateTime effectiveEndDate(DateTime start, {int defaultNights = 2}) {
    if (returnDate != null && returnDate!.isAfter(start)) {
      return returnDate!;
    }
    if (durationNights != null && durationNights! > 0) {
      return start.add(Duration(days: durationNights!));
    }
    return start.add(Duration(days: defaultNights));
  }
}

/// The follow-up patch vocabulary (US-2 §8) — every action maps directly
/// onto structured intent fields or a concrete params change.
enum FollowUpAction {
  cheaper,
  morePremium,
  changeDates,
  twoPeople,
  nearAirport,

  /// US-4 — comparison CONTRACT ONLY: the chip signals the user's intent
  /// to compare results; the surface marks selection mode and the FULL
  /// comparison implementation lands with US-6 (spec: "Introduce only the
  /// contract needed for comparison. Full comparison may remain US-6.").
  compare,
}
