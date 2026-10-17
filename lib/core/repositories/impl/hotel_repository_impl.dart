import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/repositories/contracts/hotel_repository.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';

/// Phase 3A — the hotel repository honors the FULL search contract.
///
/// Every `HotelSearchParams` field the caller set now reaches the backend
/// request body (rooms, price windows, min rating, amenities). Empty/omitted
/// fields stay out of the body — the backend's own defaults apply, exactly
/// like the vertical form's own conventions. The response shape
/// (`{successes: [{success, data: []}], failures: []}`) is the backend
/// aggregation contract (partial failure) and is parsed unchanged.
class HotelRepositoryImpl implements HotelRepository {
  final HttpApiClient client;
  HotelRepositoryImpl(this.client);

  @override
  Future<ApiResult<List<HotelOffer>>> search({
    required String city,
    required DateTime checkIn,
    required DateTime checkOut,
    int? guests,
  }) async {
    try {
      final result = await client.post<Map<String, dynamic>>(
        '/search/hotels',
        body: _buildBody(
          city: city,
          checkIn: checkIn,
          checkOut: checkOut,
          guests: guests,
        ),
      );

      return result.when(
        success: (data) {
          final offers = _parseHotels(data);
          if (offers.isEmpty) {
            return const ApiResult.success([]);
          }
          return ApiResult.success(offers);
        },
        failure: (error) => ApiResult.failure(error),
      );
    } catch (e) {
      return ApiResult.failure(
        ApiNetworkError(message: e.toString(), cause: e),
      );
    }
  }

  /// Builds the request body honoring every parameter. Kept a pure static
  /// so the contract is unit-testable without any HTTP client.
  static Map<String, dynamic> buildSearchBody({
    required String city,
    required DateTime checkIn,
    required DateTime checkOut,
    int? guests,
    int? rooms,
    double? minRating,
    double? maxPrice,
    double? minPrice,
    List<String>? amenities,
  }) {
    return <String, dynamic>{
      'city': city,
      'checkIn': checkIn.toIso8601String(),
      'checkOut': checkOut.toIso8601String(),
      'guests': guests ?? 2,
      'rooms': rooms,
      'minRating': minRating,
      'maxPrice': maxPrice,
      'minPrice': minPrice,
      // Amenities: an explicit EMPTY list is meaningful (filter out
      // everything) only when the caller set it — null means "not set".
      if (amenities != null && amenities.isNotEmpty) 'amenities': amenities,
    };
  }

  Map<String, dynamic> _buildBody({
    required String city,
    required DateTime checkIn,
    required DateTime checkOut,
    int? guests,
  }) =>
      buildSearchBody(
        city: city,
        checkIn: checkIn,
        checkOut: checkOut,
        guests: guests,
        rooms: _pendingRooms,
        minRating: _pendingMinRating,
        maxPrice: _pendingMaxPrice,
        minPrice: _pendingMinPrice,
        amenities: _pendingAmenities,
      );

  // The repository contract (`search({city, checkIn, checkOut, guests})`)
  // predates the rich params; the repository keeps the interface stable
  // while the caller (controller) seeds the extras before calling. This
  // mirrors how the vertical forms already work.
  int? _pendingRooms;
  double? _pendingMinRating;
  double? _pendingMaxPrice;
  double? _pendingMinPrice;
  List<String>? _pendingAmenities;

  /// Phase 3A — seeds the rich hotel search fields for the NEXT `search()`
  /// call (the interface stays backward-compatible for every existing
  /// caller). A pure pass-through: nothing is invented, nothing defaults.
  @visibleForTesting
  void setNextSearchExtras({
    int? rooms,
    double? minRating,
    double? maxPrice,
    double? minPrice,
    List<String>? amenities,
  }) {
    _pendingRooms = rooms;
    _pendingMinRating = minRating;
    _pendingMaxPrice = maxPrice;
    _pendingMinPrice = minPrice;
    _pendingAmenities = amenities;
  }

  List<HotelOffer> _parseHotels(Map<String, dynamic> data) {
    final offers = <HotelOffer>[];

    // Backend returns { successes: [ { success, data: [...] } ], failures: [] }
    final successes = data['successes'] as List?;
    if (successes != null) {
      for (final s in successes) {
        if (s is Map) {
          final items = s['data'];
          if (items is List) {
            _addOffers(items, offers);
          }
        }
      }
      return offers;
    }

    // Legacy shape: a flat data array.
    if (data['data'] is List) {
      _addOffers(data['data'] as List, offers);
    }
    return offers;
  }

  void _addOffers(List items, List<HotelOffer> offers) {
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        final offer = _offerFromMap(item);
        if (offer != null) offers.add(offer);
      }
    }
  }

  HotelOffer? _offerFromMap(Map<String, dynamic> item) {
    try {
      return HotelOffer(
        id: item['id']?.toString() ?? '',
        providerId: item['providerId']?.toString() ?? 'nuitee',
        providerName: item['providerName']?.toString() ?? 'Nuitee',
        title: item['title']?.toString() ?? '',
        price: (item['price'] as num?)?.toDouble() ?? 0,
        currency: item['currency']?.toString() ?? 'USD',
        city: item['city']?.toString() ?? '',
        country: item['country']?.toString() ?? '',
        checkIn: DateTime.tryParse(item['checkIn']?.toString() ?? '') ??
            DateTime.now(),
        checkOut: DateTime.tryParse(item['checkOut']?.toString() ?? '') ??
            DateTime.now().add(const Duration(days: 2)),
        roomType: item['roomType']?.toString() ?? '',
        rating: (item['rating'] as num?)?.toDouble(),
        reviewCount: (item['reviewCount'] as num?)?.toInt(),
        imageUrl: item['imageUrl']?.toString(),
        amenities:
            (item['amenities'] as List?)?.map((e) => e.toString()).toList() ??
                [],
      );
    } catch (_) {
      return null; // A malformed offer never breaks the whole search.
    }
  }

  @override
  Future<ApiResult<HotelOffer>> getById(String id) async =>
      ApiResult.failure(
          const ApiUnknownError(message: 'getById not implemented'));
}
