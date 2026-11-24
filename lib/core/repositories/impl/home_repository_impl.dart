import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/features/home/domain/promotional_stay.dart';

/// The card type the app can actually render.
///
/// `null` for a type the app does not support: a card it cannot draw is
/// **skipped**, never relabelled as something else.
HomeCardType? _parseCardType(String? s) {
  switch (s?.toLowerCase()) {
    case 'flight':
      return HomeCardType.flight;
    case 'hotel':
      return HomeCardType.hotel;
    case 'car':
      return HomeCardType.car;
    case 'package':
      return HomeCardType.package;
    case 'destination':
      return HomeCardType.destination;
    case 'deal':
      return HomeCardType.deal;
    default:
      return null;
  }
}

HomeSectionLayout _parseLayout(String? s) {
  switch (s?.toLowerCase()) {
    case 'horizontal':
      return HomeSectionLayout.horizontal;
    case 'horizontalpeek':
      return HomeSectionLayout.horizontalPeek;
    case 'grid':
      return HomeSectionLayout.grid;
    default:
      return HomeSectionLayout.vertical;
  }
}

/// Home data access.
///
/// The old Home snapshot envelope, the `home|sections` write-through cache and
/// the recommended-rail request are gone. What remains is the backend
/// destination feed (Explore Cities page) and the promotional Nearby Stays
/// cache/fetch.
class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this.apiClient, {this._offlineCache});

  final ApiClient apiClient;
  final OfflineCache? _offlineCache;

  /// Promotional Nearby Stays cache (R5). One key, one box: the shared
  /// OfflineCache (Hive) is used for preferences and images too, so this entry
  /// is namespaced and never clears the box.
  static const String promotionalStaysCacheKey = 'home:promotional-stays:v1';

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() async {
    final result = await apiClient.get<List<dynamic>>('/home/sections');
    return result.when(
      success: (List<dynamic> data) => ApiResult.success(_parseSections(data)),
      failure: (ApiError error) => ApiResult.failure(error),
    );
  }

  List<HomeSection> _parseSections(List<dynamic> data) {
    final sections = <HomeSection>[];
    for (final s in data) {
      if (s is Map<String, dynamic>) {
        final cards = <HomeItem>[];
        final cardsJson = s['cards'] as List? ?? [];
        for (final c in cardsJson) {
          if (c is Map<String, dynamic>) {
            final HomeCardType? type = _parseCardType(c['type']?.toString());
            // A card type the app cannot draw is skipped, not renamed.
            if (type == null) continue;
            cards.add(
              HomeItem(
                id: c['id']?.toString() ?? '',
                type: type,
                title: c['title']?.toString() ?? '',
                subtitle: c['subtitle']?.toString(),
                description: c['description']?.toString(),
                imageUrl: c['imageUrl']?.toString(),
                price: double.tryParse(c['price']?.toString() ?? ''),
                currency: c['currency']?.toString(),
                rating: double.tryParse(c['rating']?.toString() ?? ''),
                reviewCount: int.tryParse(c['reviewCount']?.toString() ?? ''),
                badge: c['badge']?.toString(),
                highlights:
                    (c['highlights'] as List?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    [],
                tags:
                    (c['tags'] as List?)?.map((e) => e.toString()).toList() ??
                    [],
                actionLabel:
                    c['actionLabel']?.toString() ?? c['action']?.toString(),
                rawPrice: double.tryParse(c['rawPrice']?.toString() ?? ''),
                metadata: c['metadata'] is Map
                    ? Map<String, dynamic>.from(c['metadata'])
                    : {},
              ),
            );
          }
        }
        sections.add(
          HomeSection(
            id: s['id']?.toString() ?? '',
            title: s['title']?.toString() ?? '',
            subtitle: s['subtitle']?.toString(),
            layout: _parseLayout(s['layout']?.toString()),
            items: cards,
          ),
        );
      }
    }
    return sections;
  }

  @override
  Future<NearbyStaysResponse?> readCachedNearbyStays() async {
    final cache = _offlineCache;
    if (cache == null) return null;
    try {
      final map = await cache.read(promotionalStaysCacheKey);
      if (map == null) return null;
      return NearbyStaysResponse.tryParse(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeCachedNearbyStays(NearbyStaysResponse response) async {
    final cache = _offlineCache;
    if (cache == null) return;
    try {
      await cache.write(promotionalStaysCacheKey, response.toMap());
    } catch (_) {
      // Best-effort; never crash the UI on storage failure.
    }
  }

  @override
  Future<ApiResult<NearbyStaysResponse>> fetchNearbyStays({
    double? latitude,
    double? longitude,
    double? accuracy,
    String? cityId,
    String? city,
    String? country,
    String languageCode = 'en',
    String? currency,
  }) async {
    final query = <String, String>{};
    if (latitude != null && longitude != null) {
      query['lat'] = latitude.toString();
      query['lng'] = longitude.toString();
    }
    if (accuracy != null && accuracy >= 0) {
      query['accuracy'] = accuracy.round().toString();
    }
    final String? canonicalId = cityId?.trim();
    if (canonicalId != null && canonicalId.isNotEmpty) {
      query['cityId'] = canonicalId;
    }
    final String? cityName = city?.trim();
    if (cityName != null && cityName.isNotEmpty) {
      query['city'] = cityName;
      final String? code = country?.trim().toUpperCase();
      if (code != null && code.length == 2) query['country'] = code;
    }
    query['language'] = languageCode == 'ar' ? 'ar' : 'en';
    final String? currencyCode = currency?.trim().toUpperCase();
    if (currencyCode != null && currencyCode.length == 3) {
      query['currency'] = currencyCode;
    }

    final result = await apiClient.get<Map<String, dynamic>>(
      '/home/nearby-stays',
      queryParameters: query,
    );
    return result.when(
      success: (data) {
        final NearbyStaysResponse? response = NearbyStaysResponse.tryParse(data);
        if (response == null) {
          return ApiResult<NearbyStaysResponse>.failure(
            const ApiParseError(message: 'Invalid nearby stays payload'),
          );
        }
        return ApiResult<NearbyStaysResponse>.success(response);
      },
      failure: (ApiError error) => ApiResult<NearbyStaysResponse>.failure(error),
    );
  }
}
