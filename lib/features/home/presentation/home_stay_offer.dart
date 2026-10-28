import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';

/// The details page a Home stay card opens (owner decision, 2026-10-25).
///
/// A stay on Home is a REAL rate the provider returned for a real window, so
/// tapping it must open that hotel's own details — the same page the results
/// list opens — instead of dropping the traveller into a fresh search for the
/// city they can already see on the card.
///
/// The endpoint already carries everything the page needs (hotel id, provider
/// provenance, the stay window, the room and the facilities). This turns a
/// [HomeItem] back into the [HotelOffer] that page speaks.
///
/// It returns **null** rather than filling gaps: a card without a price, a city,
/// a country or a real stay window cannot honestly render a details page (the
/// dates would be invented), and the caller falls back to the city search it
/// used before. No field here is guessed.
HotelOffer? hotelOfferFromHomeStay(HomeItem item) {
  final Map<String, dynamic> metadata = item.metadata;

  // City comes from the endpoint's own field only. The subtitle is the
  // provider's descriptor line ("Cairo · 4.7★ · 4★ hotel · …"), and using it as
  // a location is the exact bug that made the old tap search for a sentence.
  final String city = _text(metadata['city']) ?? '';
  final String country = _text(metadata['country']) ?? '';
  final String providerId = _text(metadata['providerId']) ?? '';
  final String providerName = _text(metadata['providerName']) ?? providerId;
  final DateTime? checkIn = _date(metadata['checkIn']);
  final DateTime? checkOut = _date(metadata['checkOut']);
  final double? price = item.price;
  final String currency = item.currency ?? '';

  // The page's spine: who, where, when, how much. Everything else is optional
  // on it (the hotel identity block hides what the provider did not report).
  if (city.isEmpty ||
      country.isEmpty ||
      providerId.isEmpty ||
      checkIn == null ||
      checkOut == null ||
      price == null ||
      currency.isEmpty) {
    return null;
  }

  return HotelOffer(
    // The offer id is the RATE id, exactly as a search result carries it: the
    // booking provider prebooks with `rateId: offerId`. The hotel id stays in
    // the metadata for identity/display.
    id:
        _text(metadata['providerRateId']) ??
        _text(metadata['providerOfferId']) ??
        item.id,
    providerId: providerId,
    providerName: providerName,
    title: item.title,
    // The card's subtitle is the provider's own descriptor line ("Cairo · 4.7★
    // · 4★ hotel · Free cancellation"); repeating it under the title of the
    // details page would read as an address. The city/country line below the
    // name already carries the location.
    description: item.description,
    imageUrl: item.imageUrl,
    price: price,
    currency: currency,
    rating: item.rating,
    reviewCount: item.reviewCount,
    metadata: metadata,
    city: city,
    country: country,
    checkIn: checkIn,
    checkOut: checkOut,
    roomType: _text(metadata['roomType']) ?? '',
    amenities: _amenities(metadata['amenities']),
  );
}

String? _text(Object? value) {
  final String? text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

DateTime? _date(Object? value) {
  final String? text = _text(value);
  if (text == null) return null;
  return DateTime.tryParse(text);
}

/// The provider's facility list. The endpoint caps it at six entries; a shape
/// the client does not recognise simply yields no facilities rather than a row
/// of "null"s.
List<String> _amenities(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((Object? entry) => entry?.toString().trim())
      .whereType<String>()
      .where((String entry) => entry.isNotEmpty)
      .toList();
}
