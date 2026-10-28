import 'package:tokigo/core/memory/budget_currency.dart';

/// Explicit Preference Signal (PH-7 — computed read model).
///
/// Built SERVER-SIDE from EXPLICIT AI-conversation memories
/// (`type='conversation'` + `source='ai_conversation'`) and shipped on
/// `GET /profile/me` as the additive `explicitPreferences` field.
///
/// This is deliberately SEPARATE from [DerivedPreferenceProfile] (Phase 2B):
/// explicit user-declared preferences are NOT behavioural memory and are
/// never folded into the derived read model. Consumers treat a null signal
/// (guests / opt-out / no facts / older backend) exactly like "no signal".
///
/// Only two fields drive ranking — [destination] and [budget]. [travelStyles]
/// is carried for contract completeness only: Home candidates expose no
/// deterministic style/amenity vocabulary, so it is DELIBERATELY unused
/// (inventing a mapping is forbidden).
class ExplicitPreferenceSignal {
  const ExplicitPreferenceSignal({
    this.destination,
    this.budget,
    this.travelStyles = const [],
  });

  factory ExplicitPreferenceSignal.fromMap(Map<String, dynamic> map) {
    return ExplicitPreferenceSignal(
      destination: map['destination']?.toString(),
      budget: map['budget'] is Map
          ? ExplicitBudgetRange.fromMap(
              Map<String, dynamic>.from(map['budget'] as Map),
            )
          : null,
      travelStyles: (map['travelStyles'] as List? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .take(60)
          .toList(),
    );
  }

  /// Most-recent explicit destination (destination/city matching only).
  final String? destination;

  /// Most-recent explicit budget range; a missing bound is never zero.
  final ExplicitBudgetRange? budget;

  /// Documented deferral — NOT consumed by ranking (see class docs).
  final List<String> travelStyles;

  /// True when the signal carries nothing a consumer can use.
  bool get isEmpty =>
      (destination == null || destination!.isEmpty) &&
      budget == null &&
      travelStyles.isEmpty;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (destination != null) 'destination': destination,
      if (budget != null) 'budget': budget!.toMap(),
      if (travelStyles.isNotEmpty) 'travelStyles': travelStyles,
    };
  }
}

class ExplicitBudgetRange {
  const ExplicitBudgetRange({this.min, this.max, this.currency});

  factory ExplicitBudgetRange.fromMap(Map<String, dynamic> map) {
    return ExplicitBudgetRange(
      min: map['min'] is num ? (map['min'] as num).toDouble() : null,
      max: map['max'] is num ? (map['max'] as num).toDouble() : null,
      // Phase 4B: only a supported currency survives — the app never
      // converts a price, so an unknown currency must not reach a consumer.
      currency: normalizeBudgetCurrency(map['currency']?.toString()),
    );
  }

  final double? min;
  final double? max;

  /// The currency the bounds are expressed in (ISO 4217). Null for a legacy
  /// budget that was stated without one.
  final String? currency;

  Map<String, dynamic> toMap() => {
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    if (currency != null) 'currency': currency,
  };
}
