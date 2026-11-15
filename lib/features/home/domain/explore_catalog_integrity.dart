/// Catalog integrity: the guarantees the Explore image system depends on.
///
/// These are pure functions so a test can call them without a widget tree, and
/// so the same rules can be re-run from a tool during development. They are
/// the executable form of the requirements: every city has an asset, every
/// asset belongs to exactly one city, no asset is a remote URL, and every
/// image's provenance is present.
library;

import 'package:tokigo/features/home/domain/explore_catalog.dart';
import 'package:tokigo/features/home/domain/explore_city_image.dart';

/// A single catalog problem, with enough context to fix it.
class CatalogIssue {
  const CatalogIssue(this.cityId, this.message);

  final String cityId;
  final String message;

  @override
  String toString() => '$cityId: $message';
}

/// The result of a catalog integrity run.
class CatalogIntegrityReport {
  const CatalogIntegrityReport({
    required this.issues,
    required this.cityCount,
    required this.curatedCount,
  });

  /// Every problem found. Empty means the catalog is sound.
  final List<CatalogIssue> issues;

  final int cityCount;
  final int curatedCount;

  bool get isClean => issues.isEmpty;

  /// City ids whose asset mapping failed, for quick reporting.
  List<String> get affectedCityIds =>
      <String>{for (final CatalogIssue issue in issues) issue.cityId}.toList();
}

/// Validates the catalog against [existingAssets], the set of asset paths that
/// are actually bundled (`assets/explore/cities/<id>.webp`).
///
/// Checks, per the Explore image requirements:
/// 1. every catalog city has a stable, unique id;
/// 2. every city's declared asset matches the registry's derived path (no
///    hand-written path that could point at another city);
/// 3. every declared asset exists in [existingAssets];
/// 4. no two cities share an asset;
/// 5. no asset path is a remote URL;
/// 6. every city carries a verified source and license.
CatalogIntegrityReport checkExploreCatalog(Set<String> existingAssets) {
  final List<CatalogIssue> issues = <CatalogIssue>[];
  final Set<String> seenIds = <String>{};
  final Map<String, String> assetToCity = <String, String>{};

  for (final ExploreCity city in kExploreCities) {
    // 1. stable, unique id
    if (city.id.trim().isEmpty) {
      issues.add(CatalogIssue(city.id, 'empty city id'));
      continue;
    }
    if (!seenIds.add(city.id)) {
      issues.add(CatalogIssue(city.id, 'duplicate city id'));
    }

    // 2. the asset is the one the registry derives — never a free-form path
    final String expected = exploreCityImageAsset(city.id);
    if (city.asset != expected) {
      issues.add(
        CatalogIssue(city.id, 'asset "${city.asset}" != registry path "$expected"'),
      );
    }

    // 5. bundled, not remote
    final String lower = city.asset.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      issues.add(CatalogIssue(city.id, 'asset is a remote URL'));
    }
    if (!city.asset.startsWith('assets/')) {
      issues.add(CatalogIssue(city.id, 'asset is not a bundled asset path'));
    }

    // 3. the asset exists
    if (!existingAssets.contains(city.asset)) {
      issues.add(CatalogIssue(city.id, 'asset missing from bundle: ${city.asset}'));
    }

    // 4. one asset per city
    final String? previous = assetToCity[city.asset];
    if (previous != null) {
      issues.add(
        CatalogIssue(city.id, 'asset shared with "$previous": ${city.asset}'),
      );
    } else {
      assetToCity[city.asset] = city.id;
    }

    // 6. verified provenance
    if (city.imageLicense == null || city.imageLicense!.trim().isEmpty) {
      issues.add(CatalogIssue(city.id, 'missing image license'));
    }
    if (city.imageCredit == null || city.imageCredit!.trim().isEmpty) {
      issues.add(CatalogIssue(city.id, 'missing image author'));
    }
    if (city.imageSource == null || city.imageSource!.trim().isEmpty) {
      issues.add(CatalogIssue(city.id, 'missing image source'));
    }
  }

  // Every bundled asset must map back to a catalog city.
  for (final String asset in existingAssets) {
    final String? id = exploreCityIdForImageAsset(asset);
    if (id == null) {
      issues.add(CatalogIssue(asset, 'bundled asset is not an Explore city image'));
    } else if (exploreCityById(id) == null) {
      issues.add(CatalogIssue(id, 'bundled asset has no catalog entry'));
    }
  }

  return CatalogIntegrityReport(
    issues: issues,
    cityCount: kExploreCities.length,
    curatedCount: curatedHomeCities.length,
  );
}