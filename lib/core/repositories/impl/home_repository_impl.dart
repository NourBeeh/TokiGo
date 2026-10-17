import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/contracts/home_repository.dart';
import 'package:tokigo/core/storage/offline_cache.dart';

HomeCardType _parseCardType(String? s) {
  switch (s?.toLowerCase()) {
    case 'flight': return HomeCardType.flight;
    case 'hotel': return HomeCardType.hotel;
    case 'car': return HomeCardType.car;
    case 'package': return HomeCardType.package;
    case 'destination': return HomeCardType.destination;
    case 'deal': return HomeCardType.deal;
    default: return HomeCardType.deal;
  }
}

HomeSectionLayout _parseLayout(String? s) {
  switch (s?.toLowerCase()) {
    case 'horizontal': return HomeSectionLayout.horizontal;
    case 'horizontalpeek': return HomeSectionLayout.horizontalPeek;
    case 'grid': return HomeSectionLayout.grid;
    default: return HomeSectionLayout.vertical;
  }
}


class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this.apiClient, {OfflineCache? offlineCache})
      : _offlineCache = offlineCache;

  final ApiClient apiClient;
  final OfflineCache? _offlineCache;

  static const String _cacheKey = 'home|sections';

  // ---------------------------------------------------------------------------
  // Persistent Home snapshot (Phase 1A — Instant Home).
  //
  // A v2 envelope kept under an audience-scoped key so snapshots never leak
  // between the anonymous surface and an authenticated user's surface:
  //
  //   key:     'home|snapshot|anon' | 'home|snapshot|user:<id>'
  //   value:   { schemaVersion, savedAt, audience, sections: [...] }
  //
  // The envelope is deliberately forward-compatible: readers ignore unknown
  // top-level fields, so later phases (Dynamic Personalized Home composer,
  // persona version, experiments) can extend the snapshot without a breaking
  // migration. Only REAL network sections are ever saved — development
  // preview skeletons and AI-generated content never enter the snapshot.
  // ---------------------------------------------------------------------------

  static const String _snapshotSchemaVersion = 'home.snapshot.v2';

  static String homeSnapshotCacheKey(String audience) => 'home|snapshot|$audience';

  /// Audience identifier used to scope snapshots: `'anon'` or `'user:<id>'`.
  static String homeAudienceFor(String? userId) =>
      (userId == null || userId.isEmpty) ? 'anon' : 'user:$userId';

  @override
  Future<List<HomeSection>?> readHomeSnapshot({required String audience}) async {
    final cache = _offlineCache;
    if (cache == null) return null;
    try {
      final map = await cache.read(homeSnapshotCacheKey(audience));
      if (map == null) return null;
      final sections = homeSectionsFromMap(map);
      return sections.isEmpty ? null : sections;
    } catch (_) {
      return null;
    }
  }

  /// Removes the audience's persisted snapshot (best-effort; never throws).
  @override
  Future<void> clearHomeSnapshot({required String audience}) async {
    final cache = _offlineCache;
    if (cache == null) return;
    try {
      await cache.delete(homeSnapshotCacheKey(audience));
    } catch (_) {
      // Best-effort; never crash the UI on storage failure.
    }
  }

  /// Persists the given (network-confirmed) sections as the audience's final
  /// Home snapshot. Best-effort: storage failures never break the UI.
  @override
  Future<void> saveHomeSnapshot(
    List<HomeSection> sections, {
    required String audience,
  }) async {
    final cache = _offlineCache;
    if (cache == null || sections.isEmpty) return;
    try {
      await cache.write(homeSnapshotCacheKey(audience), <String, dynamic>{
        'schemaVersion': _snapshotSchemaVersion,
        'savedAt': DateTime.now().toIso8601String(),
        'audience': audience,
        'sections': sections.map(homeSectionToMap).toList(),
      });
    } catch (_) {
      // Best-effort; never crash the UI on storage failure.
    }
  }

  @override
  Future<ApiResult<List<HomeSection>>> getHomeSections() async {
    final result = await apiClient.get<List<dynamic>>('/home/sections');
    return result.when(
      success: (data) async {
        final sections = _parseSections(data);
        if (sections.isNotEmpty) {
          // Write-through snapshot so a later empty/failed feed still shows
          // the last real content instead of a blank screen.
          await _cacheSections(sections);
          return ApiResult.success(sections);
        }
        // Backend reachable but the feed is legitimately EMPTY: never serve
        // the legacy `home|sections` cache — it can only hold stale content
        // that the backend has since withdrawn (e.g. removed fake sections).
        // The empty feed is authoritative; serving anything else would
        // resurrect data the backend no longer returns.
        return ApiResult.success(sections);
      },
      failure: (error) async {
        final cached = await _readCachedSections();
        if (cached != null && cached.isNotEmpty) {
          return ApiResult.success(cached);
        }
        // No cached data available, return error
        return ApiResult.failure(error);
      },
    );
  }

  Future<List<HomeSection>?> _readCachedSections() async {
    final cache = _offlineCache;
    if (cache == null) return null;
    try {
      final map = await cache.read(_cacheKey);
      if (map == null) return null;
      return homeSectionsFromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheSections(List<HomeSection> sections) async {
    final cache = _offlineCache;
    if (cache == null || sections.isEmpty) return;
    try {
      await cache.write(_cacheKey, <String, dynamic>{
        'sections': sections.map(homeSectionToMap).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Best-effort; never crash the UI on storage failure.
    }
  }

  List<HomeSection> _parseSections(List<dynamic> data) {
    final sections = <HomeSection>[];
    for (final s in data) {
      if (s is Map<String, dynamic>) {
        final cards = <HomeItem>[];
        final cardsJson = s['cards'] as List? ?? [];
        for (final c in cardsJson) {
          if (c is Map<String, dynamic>) {
            cards.add(HomeItem(
              id: c['id']?.toString() ?? '',
              type: _parseCardType(c['type']?.toString()),
              title: c['title']?.toString() ?? '',
              subtitle: c['subtitle']?.toString(),
              description: c['description']?.toString(),
              imageUrl: c['imageUrl']?.toString(),
              price: double.tryParse(c['price']?.toString() ?? ''),
              currency: c['currency']?.toString(),
              rating: double.tryParse(c['rating']?.toString() ?? ''),
              reviewCount: int.tryParse(c['reviewCount']?.toString() ?? ''),
              badge: c['badge']?.toString(),
              highlights: (c['highlights'] as List?)?.map((e)=>e.toString()).toList() ?? [],
              tags: (c['tags'] as List?)?.map((e)=>e.toString()).toList() ?? [],
              actionLabel: c['actionLabel']?.toString() ?? c['action']?.toString(),
              rawPrice: double.tryParse(c['rawPrice']?.toString() ?? ''),
              metadata: c['metadata'] is Map ? Map<String,dynamic>.from(c['metadata']) : {},
            ));
          }
        }
        sections.add(HomeSection(
          id: s['id']?.toString() ?? '',
          title: s['title']?.toString() ?? '',
          subtitle: s['subtitle']?.toString(),
          layout: _parseLayout(s['layout']?.toString()),
          items: cards,
        ));
      }
    }
    return sections;
  }

  @override
  Future<ApiResult<List<HomeItem>>> getRecommendedHotels({int limit = 6}) async {
    final result = await apiClient.get<Map<String, dynamic>>(
      '/home/recommended',
      queryParameters: {'limit': limit.toString()},
    );
    return result.when(
      success: (data) {
        final hotels = (data['hotels'] as List<dynamic>?) ?? <dynamic>[];
        final items = _parseRecommendedHotels(hotels);
        return ApiResult.success(items);
      },
      failure: (error) => ApiResult.failure(error),
    );
  }

  List<HomeItem> _parseRecommendedHotels(List<dynamic> data) {
    final items = <HomeItem>[];
    for (final raw in data) {
      if (raw is! Map) continue;
      final h = Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
      items.add(HomeItem(
        id: h['id']?.toString() ?? '',
        type: HomeCardType.hotel,
        title: h['title']?.toString() ?? h['name']?.toString() ?? '',
        subtitle: h['subtitle']?.toString() ?? h['address']?.toString(),
        description: h['description']?.toString(),
        imageUrl: h['imageUrl']?.toString() ?? h['image']?.toString() ?? h['main_photo']?.toString(),
        price: h['price'] is num ? (h['price'] as num).toDouble() : null,
        currency: h['currency']?.toString(),
        rating: h['rating'] is num ? (h['rating'] as num).toDouble() : null,
        reviewCount: h['reviewCount'] is int
            ? h['reviewCount'] as int
            : (h['review_count'] is num ? (h['review_count'] as num).toInt() : null),
        badge: h['badge']?.toString(),
        highlights: (h['highlights'] as List?)?.map((e) => e.toString()).toList() ?? [],
        tags: (h['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        actionLabel: h['actionLabel']?.toString() ?? h['action']?.toString() ?? 'View deal',
        rawPrice: h['rawPrice'] is num ? (h['rawPrice'] as num).toDouble() : null,
        metadata: h['metadata'] is Map ? Map<String, dynamic>.from(h['metadata']) : {},
      ));
    }
    return items;
  }

  @override
  Future<ApiResult<void>> refresh() async {
    final result = await apiClient.post('/home/refresh');
    return result.when(
      success: (_) => ApiResult.success(null),
      failure: (error) => ApiResult.failure(error),
    );
  }
}

/// JSON-safe snapshot of one section for the offline cache.
Map<String, dynamic> homeSectionToMap(HomeSection s) {
  return <String, dynamic>{
    'id': s.id,
    'title': s.title,
    'subtitle': s.subtitle,
    'layout': s.layout.name,
    'items': s.items.map(homeItemToMap).toList(),
    // Phase 1B: composer marks sections with a semantic id + reason so later
    // phases can localize titles / explain placement. Optional on read.
    if (s.metadata.isNotEmpty) 'metadata': s.metadata,
  };
}

Map<String, dynamic> homeItemToMap(HomeItem i) {
  return <String, dynamic>{
    'id': i.id,
    'type': i.type.name,
    'title': i.title,
    'subtitle': i.subtitle,
    'description': i.description,
    'imageUrl': i.imageUrl,
    if (i.price != null) 'price': i.price,
    'currency': i.currency,
    if (i.rating != null) 'rating': i.rating,
    if (i.reviewCount != null) 'reviewCount': i.reviewCount,
    'badge': i.badge,
    'highlights': i.highlights,
    'tags': i.tags,
    'actionLabel': i.actionLabel,
    // Phase 1B: keep item metadata (composer reason chips, provenance) in the
    // snapshot round-trip. Optional on read — legacy entries keep working.
    if (i.metadata.isNotEmpty) 'metadata': i.metadata,
  };
}

/// Reads `sections` out of a stored map (legacy snapshot shape or v2
/// envelope) — the envelope reader for [HomeRepositoryImpl.readHomeSnapshot]
/// and the fallback reader for the legacy `home|sections` entry share this.
/// Unknown top-level fields are ignored so future envelope versions do not
/// require a destructive migration.
List<HomeSection> homeSectionsFromMap(Map<String, dynamic> map) {
  final sections = <HomeSection>[];
  for (final raw in (map['sections'] as List? ?? [])) {
    if (raw is! Map) continue;
    final s = Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
    final cards = <HomeItem>[];
    for (final rawCard in (s['items'] as List? ?? [])) {
      if (rawCard is! Map) continue;
      final c = Map<String, dynamic>.from(
        rawCard.map((k, v) => MapEntry(k.toString(), v)),
      );
      cards.add(HomeItem(
        id: c['id']?.toString() ?? '',
        type: _parseCardType(c['type']?.toString()),
        title: c['title']?.toString() ?? '',
        subtitle: c['subtitle']?.toString(),
        description: c['description']?.toString(),
        imageUrl: c['imageUrl']?.toString(),
        price: c['price'] is num ? (c['price'] as num).toDouble() : null,
        currency: c['currency']?.toString(),
        rating: c['rating'] is num ? (c['rating'] as num).toDouble() : null,
        reviewCount:
            c['reviewCount'] is int ? c['reviewCount'] as int : null,
        badge: c['badge']?.toString(),
        highlights:
            (c['highlights'] as List?)?.map((e) => e.toString()).toList() ?? [],
        tags: (c['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        actionLabel: c['actionLabel']?.toString(),
        metadata:
            c['metadata'] is Map ? Map<String, dynamic>.from(c['metadata']) : {},
      ));
    }
    sections.add(HomeSection(
      id: s['id']?.toString() ?? '',
      title: s['title']?.toString() ?? '',
      subtitle: s['subtitle']?.toString(),
      layout: _parseLayout(s['layout']?.toString()),
      items: cards,
      metadata:
          s['metadata'] is Map ? Map<String, dynamic>.from(s['metadata']) : {},
    ));
  }
  return sections;
}
