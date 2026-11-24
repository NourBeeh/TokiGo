import 'package:flutter/foundation.dart';

import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/storage/offline_cache.dart';

/// One selectable city from the backend's canonical catalog.
///
/// The catalog is the single source of truth (`GET /geo/cities`): the app
/// never ships a second copy. It is cached on disk so the picker keeps working
/// offline after the first successful fetch.
@immutable
class CityOption {
  const CityOption({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.currency,
    required this.latitude,
    required this.longitude,
    this.aliases = const <String>[],
  });

  final String id;
  final String name;
  final String countryCode;
  final String currency;
  final double latitude;
  final double longitude;

  /// Local/spoken names the picker may be searched by (`لندن` → London).
  /// Display always uses [name]; aliases are search aids only.
  final List<String> aliases;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'name': name,
    'countryCode': countryCode,
    'currency': currency,
    'latitude': latitude,
    'longitude': longitude,
    if (aliases.isNotEmpty) 'aliases': aliases,
  };

  static CityOption? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(
      raw.map((Object? key, Object? value) => MapEntry(key.toString(), value)),
    );
    final String id = map['id']?.toString().trim() ?? '';
    final String name = map['name']?.toString().trim() ?? '';
    final String countryCode = map['countryCode']?.toString().trim().toUpperCase() ?? '';
    final String currency = map['currency']?.toString().trim().toUpperCase() ?? '';
    final double? latitude = _number(map['latitude']);
    final double? longitude = _number(map['longitude']);
    if (id.isEmpty ||
        name.isEmpty ||
        countryCode.length != 2 ||
        currency.length != 3 ||
        latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    final List<String> aliases = <String>[];
    final Object? rawAliases = map['aliases'];
    if (rawAliases is List) {
      for (final Object? alias in rawAliases) {
        final String value = alias?.toString().trim() ?? '';
        if (value.isNotEmpty) aliases.add(value);
      }
    }
    return CityOption(
      id: id,
      name: name,
      countryCode: countryCode,
      currency: currency,
      latitude: latitude,
      longitude: longitude,
      aliases: aliases,
    );
  }

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is CityOption && other.id == id && other.countryCode == countryCode;

  @override
  int get hashCode => Object.hash(id, countryCode);
}

/// The parsed catalog plus its version.
@immutable
class CityCatalog {
  const CityCatalog({required this.version, required this.cities});

  final int version;
  final List<CityOption> cities;

  CityOption? byId(String? id) {
    final key = id?.trim();
    if (key == null || key.isEmpty) return null;
    for (final CityOption city in cities) {
      if (city.id == key) return city;
    }
    return null;
  }

  /// Free-text search over city name, local aliases, country code and (when
  /// supplied) the localized country name. Case-insensitive; an empty query
  /// returns all.
  List<CityOption> search(String query, {String Function(String code)? countryName}) {
    final String term = query.trim().toLowerCase();
    if (term.isEmpty) return cities;
    return cities.where((CityOption city) {
      if (city.name.toLowerCase().contains(term)) return true;
      if (city.aliases.any(
        (String alias) => alias.toLowerCase().contains(term),
      )) {
        return true;
      }
      if (city.countryCode.toLowerCase() == term) return true;
      final String? country = countryName?.call(city.countryCode);
      return country != null && country.toLowerCase().contains(term);
    }).toList(growable: false);
  }

  static CityCatalog? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(
      raw.map((Object? key, Object? value) => MapEntry(key.toString(), value)),
    );
    final rawCities = map['cities'];
    if (rawCities is! List) return null;
    final List<CityOption> cities = <CityOption>[];
    for (final Object? entry in rawCities) {
      final CityOption? city = CityOption.tryParse(entry);
      if (city != null) cities.add(city);
    }
    if (cities.isEmpty) return null;
    final int version = (map['version'] is num)
        ? (map['version'] as num).toInt()
        : 0;
    return CityCatalog(version: version, cities: cities);
  }
}

/// Fetches and caches the canonical city catalog.
class CityCatalogClient {
  CityCatalogClient(this._client, this._cache);

  final ApiClient _client;
  final OfflineCache _cache;

  static const String cacheKey = 'settings:city-catalog';
  static const Duration ttl = Duration(days: 7);

  /// Cache-first load. A stale cache is refreshed in the background; when the
  /// network fails the stale catalog is still returned (better than an empty
  /// picker), and only a total absence yields null.
  Future<CityCatalog?> load({bool forceRefresh = false}) async {
    final _CachedCatalog? cached = await _readCache();
    if (!forceRefresh && cached != null && !cached.isStale) {
      return cached.catalog;
    }
    final CityCatalog? fetched = await fetch();
    if (fetched != null) {
      await _writeCache(fetched);
      return fetched;
    }
    return cached?.catalog;
  }

  Future<CityCatalog?> fetch() async {
    try {
      final result = await _client.get<Map<String, dynamic>>('/geo/cities');
      final CityCatalog? catalog = result.when<CityCatalog?>(
        success: (Map<String, dynamic> data) => CityCatalog.tryParse(data),
        failure: (_) => null,
      );
      return catalog;
    } catch (_) {
      return null;
    }
  }

  Future<_CachedCatalog?> _readCache() async {
    try {
      final stored = await _cache.read(cacheKey);
      if (stored == null) return null;
      final catalog = CityCatalog.tryParse(stored['catalog']);
      if (catalog == null) return null;
      final DateTime? fetchedAt = DateTime.tryParse(
        stored['fetchedAt']?.toString() ?? '',
      );
      return _CachedCatalog(catalog: catalog, fetchedAt: fetchedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(CityCatalog catalog) async {
    try {
      await _cache.write(cacheKey, <String, dynamic>{
        'fetchedAt': DateTime.now().toUtc().toIso8601String(),
        'catalog': <String, dynamic>{
          'version': catalog.version,
          'cities': catalog.cities.map((CityOption city) => city.toMap()).toList(),
        },
      });
    } catch (_) {
      // Best-effort: an unavailable disk must not block selection.
    }
  }
}

class _CachedCatalog {
  const _CachedCatalog({required this.catalog, required this.fetchedAt});

  final CityCatalog catalog;
  final DateTime? fetchedAt;

  bool get isStale {
    final DateTime? at = fetchedAt;
    if (at == null) return true;
    return DateTime.now().toUtc().difference(at.toUtc()) > CityCatalogClient.ttl;
  }
}
