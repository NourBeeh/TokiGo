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

BaseOffer? mapOffer(Map<String, dynamic> j) {
  final t = (j['type'] ?? j['offerType'])?.toString().toLowerCase() ?? '';
  final id = j['id']?.toString() ?? '';
  final providerId = j['providerId']?.toString() ?? '';
  final providerName = j['providerName']?.toString() ?? '';
  final title = j['title']?.toString() ?? '';
  final subtitle = j['subtitle']?.toString();
  final description = j['description']?.toString();
  final imageUrl = j['imageUrl']?.toString();
  final price = _toD(j['price']);
  final currency = j['currency']?.toString() ?? 'USD';
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
    case 'flight':
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
        origin: j['origin']?.toString() ?? '',
        destination: j['destination']?.toString() ?? '',
        departureTime:
            _parse(j['departureTime']) ??
            _parse(j['departure']) ??
            DateTime.now(),
        arrivalTime:
            _parse(j['arrivalTime']) ?? _parse(j['arrival']) ?? DateTime.now(),
        airline: j['airline']?.toString() ?? '',
        flightNumber: j['flightNumber']?.toString() ?? '',
        stops: int.tryParse(j['stops']?.toString() ?? ''),
        cabinClass: j['cabinClass']?.toString(),
      );
    case 'hotel':
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
        checkIn: _parse(j['checkIn']) ?? DateTime.now(),
        checkOut: _parse(j['checkOut']) ?? DateTime.now(),
        roomType: j['roomType']?.toString() ?? '',
        amenities:
            (j['amenities'] as List?)?.map((e) => e.toString()).toList() ?? [],
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
