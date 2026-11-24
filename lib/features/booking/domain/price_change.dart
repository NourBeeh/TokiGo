import 'package:flutter/foundation.dart';

/// Provider-agnostic price/terms change confirmation.
///
/// The backend is the only source of this model. Every field it exposes is
/// stored from a provider revalidation; nothing is derived from a client-side
/// snapshot and nothing is defaulted. A missing value stays missing.
///
/// The same model is used by flights and hotels. Provider-specific
/// revalidation still happens in the backend adapters — this is only the
/// customer-facing confirmation contract.
@immutable
class PriceChangeConfirmation {
  const PriceChangeConfirmation({
    required this.providerId,
    required this.offerId,
    required this.offerType,
    required this.currentPrice,
    required this.currency,
    required this.priceDifference,
    required this.priceChanged,
    required this.termsChanged,
    required this.changedTerms,
    required this.termsVersion,
    required this.requiresAcceptance,
    required this.accepted,
    this.previousPrice,
    this.priceChangePercent,
    this.previousTerms,
    this.currentTerms,
    this.decision,
    this.decidedAt,
    this.checkedAt,
    this.expiresAt,
  });

  final String providerId;
  final String offerId;
  final String offerType;

  /// The amount the customer had accepted before this pending change.
  final double? previousPrice;
  final double currentPrice;
  final String currency;

  /// Signed difference (current - previous), rounded to cents by the backend.
  final double priceDifference;
  final double? priceChangePercent;

  final bool priceChanged;
  final bool termsChanged;
  final List<String> changedTerms;

  /// Normalized terms snapshots. Unknown stays null — never `{}` invented.
  final Map<String, dynamic>? previousTerms;
  final Map<String, dynamic>? currentTerms;

  /// Stable hash of [currentTerms]; the acceptance is bound to it.
  final String termsVersion;

  final bool requiresAcceptance;
  final bool accepted;

  /// `accepted`, `declined`, or null when no decision was recorded.
  final String? decision;
  final DateTime? decidedAt;
  final DateTime? checkedAt;
  final DateTime? expiresAt;

  bool get hasChanges => priceChanged || termsChanged;
  bool get isDeclined => decision == 'declined';
  bool get canAccept => requiresAcceptance && !isDeclined;

  /// Whether [priceDifference] is an increase, decrease or unchanged.
  bool get isIncrease => priceDifference > 0;
  bool get isDecrease => priceDifference < 0;

  /// The exact signature the customer was shown. The backend rejects an
  /// acceptance whose expected values no longer match its stored state.
  Map<String, dynamic> acceptancePayload(String decision) => <String, dynamic>{
    'decision': decision,
    'expectedPrice': currentPrice,
    'expectedCurrency': currency,
    'expectedTermsVersion': termsVersion,
  };

  /// Parses a backend payload, or returns null when it is not a usable
  /// confirmation (missing identity, amount or currency). Never fabricates.
  static PriceChangeConfirmation? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final providerId = _nonEmptyString(map['providerId']);
    final offerId = _nonEmptyString(map['offerId']);
    final currency = _nonEmptyString(map['currency']);
    final currentPrice = _asDouble(map['currentPrice']);
    final termsVersion = _nonEmptyString(map['termsVersion']);
    if (providerId == null ||
        offerId == null ||
        currency == null ||
        currentPrice == null ||
        currentPrice <= 0 ||
        termsVersion == null) {
      return null;
    }
    return PriceChangeConfirmation(
      providerId: providerId,
      offerId: offerId,
      offerType: _nonEmptyString(map['offerType']) ?? '',
      previousPrice: _asDouble(map['previousPrice']),
      currentPrice: currentPrice,
      currency: currency,
      priceDifference: _asDouble(map['priceDifference']) ?? 0,
      priceChangePercent: _asDouble(map['priceChangePercent']),
      priceChanged: map['priceChanged'] == true,
      termsChanged: map['termsChanged'] == true,
      changedTerms: _stringList(map['changedTerms']),
      previousTerms: _mapOrNull(map['previousTerms']),
      currentTerms: _mapOrNull(map['currentTerms']),
      termsVersion: termsVersion,
      requiresAcceptance: map['requiresAcceptance'] == true,
      accepted: map['accepted'] == true,
      decision: _nonEmptyString(map['decision']),
      decidedAt: _dateOrNull(map['decidedAt']),
      checkedAt: _dateOrNull(map['checkedAt']),
      expiresAt: _dateOrNull(map['expiresAt']),
    );
  }

  static String? _nonEmptyString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const <String>[];
    return raw
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, dynamic>? _mapOrNull(dynamic raw) {
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  static DateTime? _dateOrNull(dynamic value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
