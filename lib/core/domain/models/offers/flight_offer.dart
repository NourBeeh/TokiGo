import 'package:flutter/foundation.dart';
import 'base_offer.dart';

double? _doubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    final asDouble = value.toDouble();
    return asDouble.isFinite ? asDouble : null;
  }
  final parsed = double.tryParse(value.toString());
  return parsed != null && parsed.isFinite ? parsed : null;
}

int? _intOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) {
    if (!value.isFinite) return null;
    return value.truncate();
  }
  return int.tryParse(value.toString());
}

String? _nonEmpty(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

/// One included baggage allowance, exactly as the provider stated it.
///
/// `quantity` is a piece count. It is null when the provider states a
/// weight-only allowance (Nuitee) — null never means "no bags".
@immutable
class FlightBaggageAllowance {
  const FlightBaggageAllowance({
    required this.type,
    this.quantity,
    this.weightKg,
    this.description,
    this.passengerType,
  });

  /// Provider bag type: `cabin` (carry-on), `checked`, `equipment`, or another
  /// open-set value the provider sent.
  final String type;
  final int? quantity;
  final double? weightKg;
  final String? description;
  final String? passengerType;

  bool get isCabin => type.toLowerCase() == 'cabin';
  bool get isChecked => type.toLowerCase() == 'checked';

  factory FlightBaggageAllowance.fromJson(Map<String, dynamic> json) {
    return FlightBaggageAllowance(
      type: _nonEmpty(json['type']) ?? '',
      quantity: _intOrNull(json['quantity']),
      weightKg: _doubleOrNull(json['weightKg']),
      description: _nonEmpty(json['description']),
      passengerType: _nonEmpty(json['passengerType']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'quantity': quantity,
    'weightKg': weightKg,
    'description': description,
    'passengerType': passengerType,
  };
}

/// One provider-stated condition (refund or change before departure).
///
/// Every field is tri-state. `allowed == null` means the provider did not say;
/// it is never rendered as "not allowed". `feeApplies == true` with a null
/// `penaltyAmount` means the provider confirmed a fee exists but published no
/// amount — shown as "amount on request", never as a fabricated number.
@immutable
class FlightCondition {
  const FlightCondition({
    this.allowed,
    this.penaltyAmount,
    this.penaltyCurrency,
    this.feeApplies,
  });

  final bool? allowed;
  final double? penaltyAmount;
  final String? penaltyCurrency;
  final bool? feeApplies;

  bool get isKnown =>
      allowed != null || penaltyAmount != null || feeApplies != null;

  factory FlightCondition.fromJson(Map<String, dynamic> json) {
    return FlightCondition(
      allowed: json['allowed'] is bool ? json['allowed'] as bool : null,
      penaltyAmount: _doubleOrNull(json['penaltyAmount']),
      penaltyCurrency: _nonEmpty(json['penaltyCurrency']),
      feeApplies: json['feeApplies'] is bool ? json['feeApplies'] as bool : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'allowed': allowed,
    'penaltyAmount': penaltyAmount,
    'penaltyCurrency': penaltyCurrency,
    'feeApplies': feeApplies,
  };
}

/// The fare's refund/change rules before departure.
@immutable
class FlightConditions {
  const FlightConditions({
    this.refundBeforeDeparture,
    this.changeBeforeDeparture,
  });

  final FlightCondition? refundBeforeDeparture;
  final FlightCondition? changeBeforeDeparture;

  bool get isKnown =>
      (refundBeforeDeparture?.isKnown ?? false) ||
      (changeBeforeDeparture?.isKnown ?? false);

  factory FlightConditions.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? mapOf(dynamic value) {
      if (value is! Map) return null;
      return Map<String, dynamic>.from(value);
    }

    final refund = mapOf(json['refundBeforeDeparture']);
    final change = mapOf(json['changeBeforeDeparture']);
    return FlightConditions(
      refundBeforeDeparture: refund == null
          ? null
          : FlightCondition.fromJson(refund),
      changeBeforeDeparture: change == null
          ? null
          : FlightCondition.fromJson(change),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'refundBeforeDeparture': refundBeforeDeparture?.toJson(),
    'changeBeforeDeparture': changeBeforeDeparture?.toJson(),
  };
}

/// One physical flight segment (one flight number), in itinerary order.
///
/// Marketing and operating carriers are kept separately: a codeshare's
/// marketing number is what the traveller bought, the operating number is who
/// actually flies it. Neither is ever substituted for the other.
@immutable
class FlightSegment {
  const FlightSegment({
    required this.origin,
    required this.destination,
    required this.departureAt,
    required this.arrivalAt,
    this.marketingCarrierCode,
    this.marketingCarrierName,
    this.operatingCarrierCode,
    this.operatingCarrierName,
    this.marketingFlightNumber,
    this.operatingFlightNumber,
    this.stopCount,
    this.cabinClass,
    this.fareBasisCode,
    this.aircraft,
    this.duration,
    this.sliceIndex,
    this.segmentKey,
    this.baggage = const <FlightBaggageAllowance>[],
  });

  final String origin;
  final String destination;
  final DateTime departureAt;
  final DateTime arrivalAt;

  final String? marketingCarrierCode;
  final String? marketingCarrierName;
  final String? operatingCarrierCode;
  final String? operatingCarrierName;
  final String? marketingFlightNumber;
  final String? operatingFlightNumber;

  /// En-route (technical) stops inside this single flight number.
  final int? stopCount;
  final String? cabinClass;
  final String? fareBasisCode;
  final String? aircraft;
  final String? duration;

  /// Which leg of a multi-leg itinerary this segment belongs to.
  final int? sliceIndex;
  final String? segmentKey;
  final List<FlightBaggageAllowance> baggage;

  /// The carrier the passenger bought: marketing wins, operating is fallback.
  String get displayCarrierName =>
      _nonEmpty(marketingCarrierName) ??
      _nonEmpty(operatingCarrierName) ??
      '';

  /// True when the marketing and operating carriers differ (a codeshare).
  bool get isCodeshare {
    final marketing = _nonEmpty(marketingCarrierCode);
    final operating = _nonEmpty(operatingCarrierCode);
    return marketing != null && operating != null && marketing != operating;
  }

  String get marketingDesignator {
    final code = _nonEmpty(marketingCarrierCode) ?? '';
    final number = _nonEmpty(marketingFlightNumber) ?? '';
    if (number.isEmpty) return '';
    if (code.isEmpty || number.toUpperCase().startsWith(code.toUpperCase())) {
      return number;
    }
    return '$code$number';
  }

  String get operatingDesignator {
    final code = _nonEmpty(operatingCarrierCode) ?? '';
    final number = _nonEmpty(operatingFlightNumber) ?? '';
    if (number.isEmpty) return '';
    if (code.isEmpty || number.toUpperCase().startsWith(code.toUpperCase())) {
      return number;
    }
    return '$code$number';
  }

  factory FlightSegment.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> carrier(dynamic value) =>
        value is Map ? Map<String, dynamic>.from(value) : const {};

    final marketing = carrier(json['marketingCarrier']);
    final operating = carrier(json['operatingCarrier']);
    final rawBaggage = json['baggage'];
    final baggage = rawBaggage is List
        ? rawBaggage
              .whereType<Map>()
              .map(
                (entry) => FlightBaggageAllowance.fromJson(
                  Map<String, dynamic>.from(entry),
                ),
              )
              .where((entry) => entry.type.isNotEmpty)
              .toList(growable: false)
        : const <FlightBaggageAllowance>[];

    return FlightSegment(
      origin: _nonEmpty(json['origin']) ?? '',
      destination: _nonEmpty(json['destination']) ?? '',
      departureAt: DateTime.parse(json['departureAt'].toString()),
      arrivalAt: DateTime.parse(json['arrivalAt'].toString()),
      marketingCarrierCode: _nonEmpty(marketing['code']),
      marketingCarrierName: _nonEmpty(marketing['name']),
      operatingCarrierCode: _nonEmpty(operating['code']),
      operatingCarrierName: _nonEmpty(operating['name']),
      marketingFlightNumber: _nonEmpty(json['marketingFlightNumber']),
      operatingFlightNumber: _nonEmpty(json['operatingFlightNumber']),
      stopCount: _intOrNull(json['stopCount']),
      cabinClass: _nonEmpty(json['cabinClass']),
      fareBasisCode: _nonEmpty(json['fareBasisCode']),
      aircraft: _nonEmpty(json['aircraft']),
      duration: _nonEmpty(json['duration']),
      sliceIndex: _intOrNull(json['sliceIndex']),
      segmentKey: _nonEmpty(json['segmentKey']),
      baggage: baggage,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'origin': origin,
    'destination': destination,
    'departureAt': departureAt.toIso8601String(),
    'arrivalAt': arrivalAt.toIso8601String(),
    'marketingCarrier': <String, dynamic>{
      'code': marketingCarrierCode,
      'name': marketingCarrierName,
    },
    'operatingCarrier': <String, dynamic>{
      'code': operatingCarrierCode,
      'name': operatingCarrierName,
    },
    'marketingFlightNumber': marketingFlightNumber,
    'operatingFlightNumber': operatingFlightNumber,
    'stopCount': stopCount,
    'cabinClass': cabinClass,
    'fareBasisCode': fareBasisCode,
    'aircraft': aircraft,
    'duration': duration,
    'sliceIndex': sliceIndex,
    'segmentKey': segmentKey,
    'baggage': baggage.map((entry) => entry.toJson()).toList(growable: false),
  };
}

@immutable
class FlightOffer extends BaseOffer {
  const FlightOffer({
    required super.id,
    required super.providerId,
    required super.providerName,
    required super.title,
    super.subtitle,
    super.description,
    super.imageUrl,
    required super.price,
    required super.currency,
    super.availability,
    super.validUntil,
    super.metadata,
    super.rating,
    super.reviewCount,
    super.customerPrice,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.arrivalTime,
    required this.airline,
    required this.flightNumber,
    this.stops,
    this.cabinClass,
    this.segments = const <FlightSegment>[],
    this.offers = const <FlightOffer>[],
    this.conditions,
    this.baggageAllowances = const <FlightBaggageAllowance>[],
  });

  final String origin;
  final String destination;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final String airline;
  final String flightNumber;
  final int? stops;
  final String? cabinClass;

  /// Every ordered physical segment the provider described.
  final List<FlightSegment> segments;

  /// Every valid fare offer the providers returned for this exact itinerary,
  /// cheapest first. Empty for a single-offer row (and for older payloads).
  final List<FlightOffer> offers;

  /// Provider-stated refund/change rules; null means the provider said nothing.
  final FlightConditions? conditions;

  /// Included baggage, exactly as the provider stated it.
  final List<FlightBaggageAllowance> baggageAllowances;

  /// What the fare selector lists: the grouped fares when present, otherwise
  /// this offer alone (older cached payloads / a single-fare itinerary).
  List<FlightOffer> get selectableOffers =>
      offers.isEmpty ? <FlightOffer>[this] : offers;

  /// The provider's refundability for THIS fare. Typed conditions win; the
  /// legacy metadata key is the backward-compatible fallback. Null stays null.
  bool? get refundable {
    final typed = conditions?.refundBeforeDeparture?.allowed;
    if (typed != null) return typed;
    final legacy = metadata['refundable'];
    return legacy is bool ? legacy : null;
  }

  /// The provider's changeability for THIS fare, same tri-state rules.
  bool? get changeable {
    final typed = conditions?.changeBeforeDeparture?.allowed;
    if (typed != null) return typed;
    final legacy = metadata['changeable'];
    return legacy is bool ? legacy : null;
  }

  /// The airline-defined fare brand for THIS fare.
  ///
  /// A mixed-brand itinerary has no single honest brand, so the backend marks
  /// it and this getter stays null rather than repeating the first leg's brand.
  String? get fareBrand {
    if (metadata['mixedFareFamily'] == true) return null;
    final direct = _nonEmpty(metadata['fareBrand']);
    if (direct != null) return direct;
    return _nonEmpty(metadata['fareFamily']);
  }

  /// A copy of this itinerary row whose own fields are [summary] — used by the
  /// client filters when a different fare becomes the cheapest qualifying one.
  /// The full grouped fare list is preserved; nothing is discarded.
  FlightOffer withSummary(FlightOffer summary) {
    return FlightOffer(
      id: summary.id,
      providerId: summary.providerId,
      providerName: summary.providerName,
      title: summary.title,
      subtitle: summary.subtitle,
      description: summary.description,
      imageUrl: summary.imageUrl,
      price: summary.price,
      currency: summary.currency,
      availability: summary.availability,
      validUntil: summary.validUntil,
      metadata: summary.metadata,
      rating: summary.rating,
      reviewCount: summary.reviewCount,
      customerPrice: summary.customerPrice,
      origin: summary.origin,
      destination: summary.destination,
      departureTime: summary.departureTime,
      arrivalTime: summary.arrivalTime,
      airline: summary.airline,
      flightNumber: summary.flightNumber,
      stops: summary.stops,
      cabinClass: summary.cabinClass,
      segments: summary.segments,
      conditions: summary.conditions,
      baggageAllowances: summary.baggageAllowances,
      offers: offers,
    );
  }

  @override
  String get offerType => 'flight';
}
