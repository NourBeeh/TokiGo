import '../domain/models/offers/flight_offer.dart';
import '../domain/models/offers/hotel_offer.dart';
import '../domain/models/offers/car_offer.dart';
import '../domain/models/offers/travel_package_offer.dart';
import '../domain/models/offers/base_offer.dart';
import '../domain/models/offers/customer_price.dart';

DateTime? _parse(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  try {
    return DateTime.parse(v.toString());
  } catch (_) {
    return null;
  }
}

double _toD(dynamic v, [double def = 0]) {
  if (v == null) return def;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? def;
}

Map<String, dynamic> _mapOf(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<FlightBaggageAllowance> _mapFlightBaggage(dynamic raw) {
  if (raw is! List) return const <FlightBaggageAllowance>[];
  final allowances = <FlightBaggageAllowance>[];
  for (final entry in raw.whereType<Map>()) {
    final map = Map<String, dynamic>.from(entry);
    final type = map['type']?.toString().trim() ?? '';
    if (type.isEmpty) continue;
    allowances.add(
      FlightBaggageAllowance(
        type: type,
        quantity: int.tryParse(map['quantity']?.toString() ?? ''),
        weightKg: double.tryParse(map['weightKg']?.toString() ?? ''),
        description: map['description']?.toString(),
        passengerType: map['passengerType']?.toString(),
      ),
    );
  }
  return List<FlightBaggageAllowance>.unmodifiable(allowances);
}

List<FlightSegment> _mapFlightSegments(dynamic raw) {
  if (raw is! List) return const <FlightSegment>[];
  final segments = <FlightSegment>[];
  for (final entry in raw.whereType<Map>()) {
    final j = Map<String, dynamic>.from(entry);
    final origin = j['origin']?.toString() ?? '';
    final destination = j['destination']?.toString() ?? '';
    final departure = _parse(j['departureAt']);
    final arrival = _parse(j['arrivalAt']);
    // A segment without a provable route/time is not rendered: the offer's
    // own top-level route/time still stands, but no invented segment is added.
    if (origin.isEmpty ||
        destination.isEmpty ||
        departure == null ||
        arrival == null) {
      continue;
    }
    final marketing = _mapOf(j['marketingCarrier']);
    final operating = _mapOf(j['operatingCarrier']);
    segments.add(
      FlightSegment(
        origin: origin,
        destination: destination,
        departureAt: departure,
        arrivalAt: arrival,
        marketingCarrierCode: marketing['code']?.toString(),
        marketingCarrierName: marketing['name']?.toString(),
        operatingCarrierCode: operating['code']?.toString(),
        operatingCarrierName: operating['name']?.toString(),
        marketingFlightNumber: j['marketingFlightNumber']?.toString(),
        operatingFlightNumber: j['operatingFlightNumber']?.toString(),
        stopCount: int.tryParse(j['stopCount']?.toString() ?? ''),
        cabinClass: j['cabinClass']?.toString(),
        fareBasisCode: j['fareBasisCode']?.toString(),
        aircraft: j['aircraft']?.toString(),
        duration: j['duration']?.toString(),
        sliceIndex: int.tryParse(j['sliceIndex']?.toString() ?? ''),
        segmentKey: j['segmentKey']?.toString(),
        baggage: _mapFlightBaggage(j['baggage']),
      ),
    );
  }
  return List<FlightSegment>.unmodifiable(segments);
}

FlightConditions? _mapFlightConditions(dynamic raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final refund = map['refundBeforeDeparture'];
  final change = map['changeBeforeDeparture'];
  if (refund is! Map && change is! Map) return null;
  return FlightConditions(
    refundBeforeDeparture: refund is Map
        ? FlightCondition.fromJson(Map<String, dynamic>.from(refund))
        : null,
    changeBeforeDeparture: change is Map
        ? FlightCondition.fromJson(Map<String, dynamic>.from(change))
        : null,
  );
}

BaseOffer? mapOffer(Map<String, dynamic> j) => _mapOffer(j, 0);

BaseOffer? _mapOffer(Map<String, dynamic> j, int depth) {
  final t = (j['type'] ?? j['offerType'])?.toString().toLowerCase() ?? '';
  final id = j['id']?.toString() ?? '';
  final providerId = j['providerId']?.toString() ?? '';
  final providerName = j['providerName']?.toString() ?? '';
  final title = j['title']?.toString() ?? '';
  final subtitle = j['subtitle']?.toString();
  final description = j['description']?.toString();
  final imageUrl = j['imageUrl']?.toString();
  final price = _toD(j['price']);
  // No currency is not USD: an absent code stays absent (`''`) instead of
  // relabelling provider money.
  final currency = j['currency']?.toString() ?? '';
  final availability = j['availability'];
  final validUntil = _parse(j['validUntil']);
  final rawMeta = j['metadata'];
  final Map<String, dynamic> metadata = rawMeta is Map<String, dynamic>
      ? Map<String, dynamic>.from(rawMeta)
      : const <String, dynamic>{};
  final rating = _toD(j['rating'], 0);
  final reviewCount = int.tryParse(j['reviewCount']?.toString() ?? '');
  final rawCustomerPrice = j['customerPrice'];
  final customerPrice = rawCustomerPrice is Map<String, dynamic>
      ? CustomerPrice.fromJson(rawCustomerPrice)
      : null;
  switch (t) {
    case 'flight': {
      final origin = j['origin']?.toString() ?? '';
      final destination = j['destination']?.toString() ?? '';
      final departure = _parse(j['departureTime']) ?? _parse(j['departure']);
      final arrival = _parse(j['arrivalTime']) ?? _parse(j['arrival']);
      // A flight without a usable price, currency, route or times cannot be
      // shown or booked honestly. Dropping it is the only honest option: an
      // invented USD/0 price or a "now" departure would be fake data.
      if (price <= 0 ||
          currency.isEmpty ||
          origin.isEmpty ||
          destination.isEmpty ||
          departure == null ||
          arrival == null) {
        return null;
      }
      // Nested fare offers (Phase 2D). Parsed one level deep: the backend's
      // grouped row carries every valid fare, each a complete offer.
      final nested = depth == 0 && j['offers'] is List
          ? (j['offers'] as List)
                .whereType<Map>()
                .map((e) => _mapOffer(Map<String, dynamic>.from(e), depth + 1))
                .whereType<FlightOffer>()
                .toList(growable: false)
          : const <FlightOffer>[];
      return FlightOffer(
        id: id,
        providerId: providerId,
        providerName: providerName,
        title: title,
        subtitle: subtitle,
        description: description,
        imageUrl: imageUrl,
        price: price,
        currency: currency,
        availability: availability,
        validUntil: validUntil,
        metadata: metadata,
        rating: rating == 0 ? null : rating,
        reviewCount: reviewCount,
        customerPrice: customerPrice,
        origin: origin,
        destination: destination,
        departureTime: departure,
        arrivalTime: arrival,
        airline: j['airline']?.toString() ?? '',
        flightNumber: j['flightNumber']?.toString() ?? '',
        stops: int.tryParse(j['stops']?.toString() ?? ''),
        cabinClass: j['cabinClass']?.toString(),
        segments: _mapFlightSegments(j['segments']),
        offers: nested,
        conditions: _mapFlightConditions(j['conditions']),
        baggageAllowances: _mapFlightBaggage(j['baggageAllowances']),
      );
    }
    case 'hotel':
      // Nested room-type offers (Phase 2C). Parsed one level deep: the
      // backend's grouped row carries every valid offer, each of which is a
      // complete hotel offer in its own right.
      final nested = depth == 0 && j['offers'] is List
          ? (j['offers'] as List)
                .whereType<Map>()
                .map((e) => _mapOffer(Map<String, dynamic>.from(e), depth + 1))
                .whereType<HotelOffer>()
                .toList(growable: false)
          : const <HotelOffer>[];
      return HotelOffer(
        id: id,
        providerId: providerId,
        providerName: providerName,
        title: title,
        subtitle: subtitle,
        description: description,
        imageUrl: imageUrl,
        price: price,
        currency: currency,
        availability: availability,
        validUntil: validUntil,
        metadata: metadata,
        rating: rating == 0 ? null : rating,
        reviewCount: reviewCount,
        customerPrice: customerPrice,
        city: j['city']?.toString() ?? '',
        country: j['country']?.toString() ?? '',
        // Absent dates stay null — never "now".
        checkIn: _parse(j['checkIn']),
        checkOut: _parse(j['checkOut']),
        roomType: j['roomType']?.toString() ?? '',
        amenities:
            (j['amenities'] as List?)?.map((e) => e.toString()).toList() ?? [],
        offers: nested,
      );
    case 'car':
      return CarOffer(
        id: id,
        providerId: providerId,
        providerName: providerName,
        title: title,
        subtitle: subtitle,
        description: description,
        imageUrl: imageUrl,
        price: price,
        currency: currency,
        availability: availability,
        validUntil: validUntil,
        metadata: metadata,
        rating: rating == 0 ? null : rating,
        reviewCount: reviewCount,
        customerPrice: customerPrice,
        pickupLocation: j['pickupLocation']?.toString() ?? '',
        dropoffLocation: j['dropoffLocation']?.toString() ?? '',
        pickupTime: _parse(j['pickupTime']) ?? DateTime.now(),
        dropoffTime: _parse(j['dropoffTime']) ?? DateTime.now(),
        carType: j['carType']?.toString() ?? '',
        transmission: j['transmission']?.toString(),
        seats: int.tryParse(j['seats']?.toString() ?? ''),
      );
    case 'package':
      return TravelPackageOffer(
        id: id,
        providerId: providerId,
        providerName: providerName,
        title: title,
        subtitle: subtitle,
        description: description,
        imageUrl: imageUrl,
        price: price,
        currency: currency,
        availability: availability,
        validUntil: validUntil,
        metadata: metadata,
        rating: rating == 0 ? null : rating,
        reviewCount: reviewCount,
        customerPrice: customerPrice,
        destination: j['destination']?.toString() ?? '',
        durationDays: int.tryParse(j['durationDays']?.toString() ?? '0') ?? 0,
        inclusions:
            (j['inclusions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
    default:
      return null;
  }
}
