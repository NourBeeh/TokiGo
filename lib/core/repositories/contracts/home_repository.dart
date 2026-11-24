import '../../domain/models/home/home_section.dart';
import '../../../core/network/api_result.dart';
import '../../../features/home/domain/promotional_stay.dart';

/// The Home data contract.
///
/// Only two things remain: the backend destination feed used by the Explore
/// Cities page, and the promotional Nearby Stays cache/fetch. The old Home
/// snapshot, recommended-rail and price-verification methods are gone.
abstract interface class HomeRepository {
  /// Backend-published destination sections (Explore Cities page).
  Future<ApiResult<List<HomeSection>>> getHomeSections();

  /// Promotional Nearby Stays (R5). Returns null when no cached payload
  /// exists. Implementations must not throw.
  Future<NearbyStaysResponse?> readCachedNearbyStays();

  /// Replaces the promotional Nearby Stays cache (best-effort; never throws).
  Future<void> writeCachedNearbyStays(NearbyStaysResponse response);

  /// Fetches fresh promotional Nearby Stays from the backend. A null
  /// latitude/longitude/city means "no usable center": the backend answers
  /// `locationRequired` instead of a nationwide list.
  Future<ApiResult<NearbyStaysResponse>> fetchNearbyStays({
    double? latitude,
    double? longitude,
    double? accuracy,
    String? cityId,
    String? city,
    String? country,
    String languageCode = 'en',
    String? currency,
  });
}
