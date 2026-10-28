/// Derived Preference Profile (Phase 2B — computed read model).
///
/// Built SERVER-SIDE from behavioral memories + the R-4 profile and shipped
/// on `GET /profile/me` as the additive `derivedPreferences` field. This is
/// a READ MODEL: it is never persisted on its own and building it twice from
/// the same inputs yields the same output. Only fields derivable from
/// today's event payloads exist here (no countries/stars/patterns — the
/// events carry no such data, so deriving them would be guessing).
class DerivedPreferenceProfile {
  const DerivedPreferenceProfile({
    this.topDestinations = const [],
    this.budgetRange,
    this.favoriteHotels = const [],
    this.recentDestinations = const [],
  });

  factory DerivedPreferenceProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const DerivedPreferenceProfile();
    return DerivedPreferenceProfile(
      topDestinations: _parseDestinations(map['topDestinations']),
      budgetRange: map['budgetRange'] is Map
          ? DerivedBudgetRange.fromMap(
              Map<String, dynamic>.from(map['budgetRange'] as Map),
            )
          : null,
      favoriteHotels: _parseHotels(map['favoriteHotels']),
      recentDestinations: (map['recentDestinations'] as List? ?? [])
          .map((e) => e.toString())
          .take(5)
          .toList(),
    );
  }

  /// Ranked by effective confidence (conflict ladder), capped at 6.
  final List<DerivedDestination> topDestinations;

  /// Explicit preferences > preferred_budget memory > legacy fold.
  final DerivedBudgetRange? budgetRange;

  /// favorite_hotel memories, capped at 20.
  final List<DerivedHotelRef> favoriteHotels;

  /// Distinct destinations in most-recently-touched order, capped at 5.
  final List<String> recentDestinations;

  static List<DerivedDestination> _parseDestinations(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => DerivedDestination.fromMap(Map<String, dynamic>.from(m)))
        .take(6)
        .toList();
  }

  static List<DerivedHotelRef> _parseHotels(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => DerivedHotelRef.fromMap(Map<String, dynamic>.from(m)))
        .take(20)
        .toList();
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'topDestinations': topDestinations.map((d) => d.toMap()).toList(),
      if (budgetRange != null) 'budgetRange': budgetRange!.toMap(),
      'favoriteHotels': favoriteHotels.map((h) => h.toMap()).toList(),
      'recentDestinations': recentDestinations,
    };
  }
}

class DerivedDestination {
  const DerivedDestination({
    required this.name,
    required this.confidence,
    required this.source,
  });

  factory DerivedDestination.fromMap(Map<String, dynamic> map) {
    return DerivedDestination(
      name: map['name']?.toString() ?? '',
      confidence: map['confidence'] is num
          ? (map['confidence'] as num).toDouble()
          : 0,
      source: map['source']?.toString() ?? '',
    );
  }

  final String name;
  final double confidence;

  /// user_explicit | behavior_event | trip_planned | profile_derived.
  final String source;

  Map<String, dynamic> toMap() => {
    'name': name,
    'confidence': confidence,
    'source': source,
  };
}

class DerivedBudgetRange {
  const DerivedBudgetRange({this.min, this.max});

  factory DerivedBudgetRange.fromMap(Map<String, dynamic> map) {
    return DerivedBudgetRange(
      min: map['min'] is num ? (map['min'] as num).toDouble() : null,
      max: map['max'] is num ? (map['max'] as num).toDouble() : null,
    );
  }

  final double? min;
  final double? max;

  Map<String, dynamic> toMap() => {
    if (min != null) 'min': min,
    if (max != null) 'max': max,
  };
}

class DerivedHotelRef {
  const DerivedHotelRef({required this.hotelId, this.title});

  factory DerivedHotelRef.fromMap(Map<String, dynamic> map) {
    return DerivedHotelRef(
      hotelId: map['hotelId']?.toString() ?? '',
      title: map['title']?.toString(),
    );
  }

  final String hotelId;
  final String? title;

  Map<String, dynamic> toMap() => {
    'hotelId': hotelId,
    if (title != null) 'title': title,
  };
}
