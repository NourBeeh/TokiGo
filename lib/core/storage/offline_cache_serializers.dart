import 'package:tokigo/core/domain/models/search/flight_search_params.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../domain/models/offers/base_offer.dart';
import '../domain/models/offers/car_offer.dart';
import '../domain/models/offers/flight_offer.dart';
import '../domain/models/offers/hotel_offer.dart';
import '../domain/models/offers/travel_package_offer.dart';
import '../mappers/offer_mapper_fixed.dart';
import '../../features/ai/domain/ai_response.dart';
import '../../features/ai/domain/ai_section.dart';
import '../../features/ai/domain/ai_item.dart';
import '../../features/ai/domain/ai_action.dart';
import '../../features/ai/domain/ai_query_context.dart';
import '../../core/domain/models/home/home_types.dart';

/// Serialization helpers for the Phase 16 offline cache.
///
/// Offers are stored as plain JSON-safe maps and rehydrated with the same
/// `mapOffer` used by the live API repositories, so the offline path cannot
/// drift from the live path. The cache is write-through: it snapshots the
/// normalized map of a successful search result, and `mapOffer` reconstructs
/// the objects identically whether they came from the network or the cache.

String? _iso(Object? value) {
  if (value is DateTime) return value.toIso8601String();
  if (value == null) return null;
  return value.toString();
}

/// Serializes one normalized offer into the shared map shape consumed by
/// [mapOffer] (same keys, same semantics as the live API payloads).
Map<String, dynamic> offerToMap(BaseOffer offer) {
  final map = <String, dynamic>{
    'type': offer.offerType,
    'id': offer.id,
    'providerId': offer.providerId,
    'providerName': offer.providerName,
    'title': offer.title,
    'subtitle': offer.subtitle,
    'description': offer.description,
    'imageUrl': offer.imageUrl,
    'price': offer.price,
    'currency': offer.currency,
    'availability': offer.availability,
    'validUntil': _iso(offer.validUntil),
    'metadata': offer.metadata,
    'rating': offer.rating,
    'reviewCount': offer.reviewCount,
  };
  if (offer is FlightOffer) {
    return map..addAll(<String, dynamic>{
      'origin': offer.origin,
      'destination': offer.destination,
      'departureTime': _iso(offer.departureTime),
      'arrivalTime': _iso(offer.arrivalTime),
      'airline': offer.airline,
      'flightNumber': offer.flightNumber,
      'stops': offer.stops,
      'cabinClass': offer.cabinClass,
    });
  }
  if (offer is HotelOffer) {
    return map..addAll(<String, dynamic>{
      'city': offer.city,
      'country': offer.country,
      'checkIn': _iso(offer.checkIn),
      'checkOut': _iso(offer.checkOut),
      'roomType': offer.roomType,
      'amenities': offer.amenities,
    });
  }
  if (offer is CarOffer) {
    return map..addAll(<String, dynamic>{
      'pickupLocation': offer.pickupLocation,
      'dropoffLocation': offer.dropoffLocation,
      'pickupTime': _iso(offer.pickupTime),
      'dropoffTime': _iso(offer.dropoffTime),
      'carType': offer.carType,
      'transmission': offer.transmission,
      'seats': offer.seats,
    });
  }
  if (offer is TravelPackageOffer) {
    return map..addAll(<String, dynamic>{
      'destination': offer.destination,
      'durationDays': offer.durationDays,
      'inclusions': offer.inclusions,
    });
  }
  return map;
}

/// Rehydrates a stored offer map via the same mapper used by the live APIs.
/// Returns `null` for unknown/malformed entries instead of throwing.
BaseOffer? offerFromMap(Map<String, dynamic> map) => mapOffer(map);

/// Builds a deterministic cache key for a flight search.
String flightSearchCacheKey({
  required String origin,
  required String destination,
  required DateTime departure,
  DateTime? returnDate,
  int? passengers,
  List<FlightSearchLeg>? legs,
  String? market,
}) {
  final sb = StringBuffer();
  sb.write('flight|');
  // A multi-city itinerary is its own search: its legs are part of the key,
  // so a DXB→FCO→JFK result can never be served for a DXB→FCO query.
  if (legs != null && legs.isNotEmpty) {
    for (final FlightSearchLeg leg in legs) {
      sb.write(leg.origin.toLowerCase());
      sb.write('>');
      sb.write(leg.destination.toLowerCase());
      sb.write('@');
      sb.write(leg.date.toIso8601String());
      sb.write(';');
    }
    sb.write('|');
    sb.write((passengers ?? 1).toString());
    sb.write('|${market?.toUpperCase() ?? ''}');
    return sb.toString();
  }
  sb.write(origin.toLowerCase());
  sb.write('|');
  sb.write(destination.toLowerCase());
  sb.write('|');
  sb.write(departure.toIso8601String());
  if (returnDate != null) {
    sb.write('|');
    sb.write(returnDate.toIso8601String());
  }
  if (passengers != null) {
    sb.write('|');
    sb.write(passengers);
  }
  sb.write('|${market?.toUpperCase() ?? ''}');
  return sb.toString();
}

/// Builds a deterministic cache key for a hotel search.
String hotelSearchCacheKey({
  required String city,
  required DateTime checkIn,
  required DateTime checkOut,
  int? guests,
  String? country,
  String? market,
}) {
  final sb = StringBuffer();
  sb.write('hotel|');
  sb.write(city.toLowerCase());
  sb.write('|');
  sb.write(checkIn.toIso8601String());
  sb.write('|');
  sb.write(checkOut.toIso8601String());
  if (guests != null) {
    sb.write('|');
    sb.write(guests);
  }
  sb.write('|${country?.toUpperCase() ?? ''}|${market?.toUpperCase() ?? ''}');
  return sb.toString();
}

/// Builds a deterministic cache key for a car search.
String carSearchCacheKey({
  required String pickupLocation,
  required DateTime pickupTime,
  required DateTime dropoffTime,
}) {
  final sb = StringBuffer();
  sb.write('car|');
  sb.write(pickupLocation.toLowerCase());
  sb.write('|');
  sb.write(pickupTime.toIso8601String());
  sb.write('|');
  sb.write(dropoffTime.toIso8601String());
  return sb.toString();
}

/// Serializes an [AiResponse] to a JSON-safe map for caching.
Map<String, dynamic> aiResponseToMap(AiResponse response) {
  return <String, dynamic>{
    'text': response.text,
    'sections': response.sections.map((s) => aiSectionToMap(s)).toList(),
    'metadata': response.metadata,
  };
}

/// Deserializes an [AiResponse] from a cached map.
AiResponse? aiResponseFromMap(Map<String, dynamic> map) {
  try {
    final sections = <AiSection>[];
    for (final entry in (map['sections'] as List? ?? [])) {
      if (entry is Map<String, dynamic>) {
        final section = aiSectionFromMap(entry);
        if (section != null) sections.add(section);
      }
    }
    return AiResponse(
      text: map['text']?.toString(),
      sections: sections,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  } catch (_) {
    return null;
  }
}

/// Serializes an [AiSection] to a JSON-safe map.
Map<String, dynamic> aiSectionToMap(AiSection section) {
  return <String, dynamic>{
    'id': section.id,
    'title': section.title,
    'subtitle': section.subtitle,
    'layout': section.layout.name,
    'items': section.items.map((i) => aiItemToMap(i)).toList(),
    'order': section.order,
    'metadata': section.metadata,
  };
}

/// Deserializes an [AiSection] from a cached map.
AiSection? aiSectionFromMap(Map<String, dynamic> map) {
  try {
    final items = <AiItem>[];
    for (final entry in (map['items'] as List? ?? [])) {
      if (entry is Map<String, dynamic>) {
        final item = aiItemFromMap(entry);
        if (item != null) items.add(item);
      }
    }
    return AiSection(
      id: map['id']?.toString(),
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString(),
      layout: HomeSectionLayout.values.firstWhere(
        (e) => e.name == map['layout'],
        orElse: () => HomeSectionLayout.vertical,
      ),
      items: items,
      order: map['order'] as int?,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  } catch (_) {
    return null;
  }
}

/// Serializes an [AiItem] to a JSON-safe map.
Map<String, dynamic> aiItemToMap(AiItem item) {
  return <String, dynamic>{
    'id': item.id,
    'type': item.type.name,
    'title': item.title,
    'subtitle': item.subtitle,
    'imageUrl': item.imageUrl,
    'price': item.price,
    'currency': item.currency,
    'rating': item.rating,
    'reviewCount': item.reviewCount,
    'actions': item.actions
        .map(
          (a) => <String, dynamic>{
            'type': a.type,
            'label': a.label,
            'payload': a.payload,
          },
        )
        .toList(),
    'metadata': item.metadata,
  };
}

/// Deserializes an [AiItem] from a cached map.
AiItem? aiItemFromMap(Map<String, dynamic> map) {
  try {
    final actions = <AiAction>[];
    for (final entry in (map['actions'] as List? ?? [])) {
      if (entry is Map<String, dynamic>) {
        actions.add(
          AiAction(
            type: entry['type']?.toString() ?? '',
            label: entry['label']?.toString(),
            payload: Map<String, dynamic>.from(entry['payload'] ?? {}),
          ),
        );
      }
    }
    return AiItem(
      id: map['id']?.toString() ?? '',
      type: HomeCardType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => HomeCardType.deal,
      ),
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
      price: map['price'] as double?,
      currency: map['currency']?.toString(),
      rating: map['rating'] as double?,
      reviewCount: map['reviewCount'] as int?,
      actions: actions,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  } catch (_) {
    return null;
  }
}

/// Builds a deterministic cache key for an AI query.
/// Uses a hash of the prompt + context for privacy and length limits.
String aiQueryCacheKey({required String prompt, AiQueryContext? context}) {
  final sb = StringBuffer();
  sb.write('ai|');
  // Hash the prompt to avoid storing PII and keep key length bounded
  final promptHash = sha256.convert(utf8.encode(prompt.trim().toLowerCase()));
  sb.write(promptHash.toString().substring(0, 16));
  if (context != null) {
    sb.write('|');
    sb.write(context.route);
    if (context.geolocation != null) {
      sb.write('|geo');
    }
    if (context.travelDates != null) {
      sb.write('|dates');
    }
  }
  return sb.toString();
}
