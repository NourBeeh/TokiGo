import 'package:flutter/foundation.dart';

import 'package:tokigo/core/memory/explicit_preference_signal.dart';

/// Phase 4A — the ONE value object that carries the traveller's travel
/// context from Home into the search surfaces.
///
/// What it is NOT:
/// * the budget is the traveller's own stated cap, and it only ever applies
///   to the offers priced in the cap's currency.
///
/// The context travels through the router `extra` (never through a global
/// singleton), so a pushed page owns exactly the context it was given.
@immutable
class SearchContext {
  const SearchContext({
    this.destination,
    this.destinationCountryCode,
    this.countryCode,
    this.airport,
    this.budget,
    this.userState,
    this.hasUserProfile = false,
  });

  /// A real city (from the published Discover cards), used to prefill the
  /// destination.
  final String? destination;

  /// ISO-3166-1 alpha-2 country of [destination], when known from Discover.
  final String? destinationCountryCode;

  /// The traveller's country (ISO-3166-1 alpha-2).
  final String? countryCode;

  /// The departure airport (IATA) suggested for [countryCode].
  final String? airport;

  /// The traveller's explicit budget, with its currency.
  final ExplicitBudgetRange? budget;

  /// Phase 2C — AI-context fields (never provider filters).
  final String? userState; // authenticated | anonymous | null
  final bool hasUserProfile; // true when user has profile/JWT

  /// The wire shape (router `extra`).
  Map<String, dynamic> toMap() => <String, dynamic>{
    if (destination != null) 'destination': destination,
    if (destinationCountryCode != null)
      'destinationCountryCode': destinationCountryCode,
    if (countryCode != null) 'countryCode': countryCode,
    if (airport != null) 'airport': airport,
    if (budget != null) 'budget': budget!.toMap(),
    if (userState != null) 'userState': userState,
    'hasUserProfile': hasUserProfile,
  };

  /// Reads a context back from the wire shape. Tolerant: a malformed budget
  /// yields null instead of throwing.
  static SearchContext? fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final budgetRaw = map['budget'];
    final budget = budgetRaw is Map
        ? ExplicitBudgetRange.fromMap(Map<String, dynamic>.from(budgetRaw))
        : null;
    return SearchContext(
      destination: map['destination']?.toString(),
      destinationCountryCode: map['destinationCountryCode']?.toString(),
      countryCode: map['countryCode']?.toString(),
      airport: map['airport']?.toString(),
      budget: budget,
      userState: map['userState']?.toString(),
      hasUserProfile: map['hasUserProfile'] == true,
    );
  }
}
