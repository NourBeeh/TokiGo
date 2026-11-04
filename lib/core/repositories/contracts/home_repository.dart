import '../../domain/models/home/home_section.dart';
import '../../domain/models/home/home_item.dart';
import '../../../core/network/api_result.dart';

/// The freshness state of a cached Home snapshot, as the data layer reports it.
/// This is a plain enum (no classes, no factories) so it can be used as a
/// type argument in the `snapshotState` contract method.
enum SnapshotState { fresh, stale, unavailable }

abstract interface class HomeRepository {
  Future<ApiResult<List<HomeSection>>> getHomeSections();
  Future<ApiResult<List<HomeItem>>> getRecommendedHotels({
    int limit = 6,

    /// ISO-2 country the rail should be built for. Omitted → the backend falls
    /// back to the signed-in profile's country, then to the launch market.
    /// Every provider query needs the city's country; without it Nuitee
    /// answers with an empty list (a false "no availability").
    String? countryCode,
    String languageCode = 'en',

    /// Explicit display currency (ISO-4217) chosen by the traveller. Null =
    /// the backend applies the market currency (EGP/SAR/AED, else USD).
    String? currency,
  });
  Future<ApiResult<void>> refresh();

  /// Reads the audience-scoped persistent Home snapshot (Phase 1A — Instant
  /// Home) from local storage without touching the network. Returns null when
  /// no snapshot exists for [audience]; never returns another audience's
  /// snapshot. Implementations must not throw.
  Future<List<HomeSection>?> readHomeSnapshot({required String audience});

  /// Removes the audience's persisted Home snapshot (best-effort; never
  /// throws). Called when the backend confirms the feed is legitimately EMPTY
  /// so a stale snapshot (e.g. legacy fake sections) can never resurface on
  /// cold starts or offline.
  Future<void> clearHomeSnapshot({required String audience});

  /// Persists network-confirmed sections as the audience's final Home
  /// snapshot (best-effort; storage failures must never throw).
  Future<void> saveHomeSnapshot(
    List<HomeSection> sections, {
    required String audience,
  });

  /// Reports whether the cached Home snapshot for [audience] is fresh, stale,
  /// or unavailable. A snapshot is fresh within [HomeCacheConfig.ttl] of
  /// `savedAt`; it is stale when it is older than the TTL or when the envelope
  /// lacks a parseable `savedAt`; it is unavailable when no snapshot exists.
  /// Implementations must not throw.
  Future<SnapshotState> snapshotState({required String audience});
}
