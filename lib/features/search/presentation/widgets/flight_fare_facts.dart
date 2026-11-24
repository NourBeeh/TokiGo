import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Provider-verbatim fare facts shared by the flight card, the details
/// journey block and the fare selector.
///
/// Every helper returns null when the provider said nothing. A missing fact
/// simply has no line — it is never replaced with a default (no "0 bags",
/// no "non-refundable", no invented fee).

String _formatWeight(double weightKg) {
  final text = weightKg == weightKg.roundToDouble()
      ? weightKg.toStringAsFixed(0)
      : weightKg.toStringAsFixed(1);
  return text;
}

String _money(double amount, String currency) {
  final text = amount.toStringAsFixed(2);
  return currency.isEmpty ? text : '$currency $text';
}

String _baggageLine(
  AppLocalizations l10n,
  String type,
  int? quantity,
  double? weightKg,
) {
  final normalized = type.toLowerCase();
  String base;
  if (normalized == 'cabin') {
    base = quantity != null
        ? l10n.offerBaggageCabinCount(quantity)
        : l10n.offerBaggageCabin;
  } else if (normalized == 'checked') {
    base = quantity != null
        ? l10n.offerBaggageCheckedCount(quantity)
        : l10n.offerBaggageChecked;
  } else if (normalized == 'equipment') {
    base = l10n.offerBaggageEquipment;
  } else {
    // Open-set provider value: keep it verbatim rather than mapping it to a
    // label that may be wrong.
    base = quantity != null ? '$quantity × $type' : type;
  }
  if (weightKg == null) return base;
  return l10n.offerBaggageWeight(base, _formatWeight(weightKg));
}

/// The included baggage across every allowance the fare states, or null when
/// the provider sent none. A legacy `metadata.baggage` `{type, quantity}` is
/// the backward-compatible fallback for cached/pre-2D payloads.
String? flightBaggageSummary(AppLocalizations l10n, FlightOffer offer) {
  final parts = <String>[];
  for (final allowance in offer.baggageAllowances) {
    if (allowance.type.isEmpty) continue;
    final line = _baggageLine(
      l10n,
      allowance.type,
      allowance.quantity,
      allowance.weightKg,
    );
    if (!parts.contains(line)) parts.add(line);
  }
  if (parts.isEmpty) {
    final legacy = offer.metadata['baggage'];
    if (legacy is Map) {
      final type = legacy['type']?.toString().trim() ?? '';
      final quantity = int.tryParse(legacy['quantity']?.toString() ?? '');
      if (type.isNotEmpty) {
        parts.add(_baggageLine(l10n, type, quantity, null));
      }
    }
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The provider's refund rule for this fare, tri-state.
String flightRefundLine(AppLocalizations l10n, FlightOffer offer) {
  final allowed = offer.refundable;
  if (allowed == false) return l10n.offerNonRefundable;
  if (allowed == null) return l10n.offerConditionsUnknown;
  final condition = offer.conditions?.refundBeforeDeparture;
  final amount = condition?.penaltyAmount;
  final currency = condition?.penaltyCurrency ?? '';
  if (amount != null) {
    return l10n.offerRefundableWithFee(_money(amount, currency));
  }
  if (condition?.feeApplies == true) {
    return l10n.offerRefundableFeeOnRequest;
  }
  return l10n.offerRefundable;
}

/// The provider's change rule for this fare, tri-state.
String flightChangeLine(AppLocalizations l10n, FlightOffer offer) {
  final allowed = offer.changeable;
  if (allowed == false) return l10n.offerNotChangeable;
  if (allowed == null) return l10n.offerConditionsUnknown;
  final condition = offer.conditions?.changeBeforeDeparture;
  final amount = condition?.penaltyAmount;
  final currency = condition?.penaltyCurrency ?? '';
  if (amount != null) {
    return l10n.offerChangeableWithFee(_money(amount, currency));
  }
  if (condition?.feeApplies == true) {
    return l10n.offerChangeableFeeOnRequest;
  }
  return l10n.offerChangeable;
}

/// The provider's own policy messages (`terms.summary`), verbatim. Provider
/// text is data, not vocabulary, so it is not translated here.
String? flightRestrictionsLine(FlightOffer offer) {
  final raw = offer.metadata['termsSummary'];
  if (raw is! List) return null;
  final messages = <String>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final message = entry['message']?.toString().trim() ?? '';
    if (message.isNotEmpty && !messages.contains(message)) {
      messages.add(message);
    }
  }
  return messages.isEmpty ? null : messages.join(' · ');
}

/// The fare's own name: the airline brand when stated, otherwise a numbered
/// "Fare" label so a selector with several unbranded fares stays readable.
String flightFareTitle(AppLocalizations l10n, FlightOffer offer, int index) {
  final brand = offer.fareBrand;
  if (brand != null && brand.isNotEmpty) return brand;
  return l10n.offerFareOption(index + 1);
}
