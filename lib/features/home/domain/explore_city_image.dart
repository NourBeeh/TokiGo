/// Central registry: every Explore city id → its ONE bundled image asset.
///
/// ## Why this exists
///
/// Explore cards must never load a photo over the network, never fall back to a
/// generic image, and never silently show an unrelated city's photo. Those
/// three guarantees cannot be met by an `imageUrl` string handed from widget to
/// widget, because a string can point anywhere and nothing checks it. So the
/// mapping lives here, in one place, keyed by the city's stable id, and the
/// card asks for a city — not a path.
///
/// ## Guarantees
///
/// * **Bundled only.** [exploreCityImageAsset] returns an `assets/...` path.
///   There is no remote URL in this registry, by construction.
/// * **Per city.** Two ids never share an asset; the catalog integrity test
/// ///  enforces that.
/// * **Fail loud.** An id with no catalog entry has no asset. Callers resolve
///   through the catalog, so an unknown id is a caller bug, and the integrity
///   test reports it rather than letting a wrong photo reach the UI.
library;

/// Asset-root prefix for every bundled Explore photo.
const String exploreImageAssetRoot = 'assets/explore/cities';

/// Maps a city id to its bundled photo path.
///
/// The path is derived from the city id alone (`<root>/<id>.webp`), which is
/// what makes the mapping auditable: the integrity test can enumerate the
/// catalog, expand this function and assert that every path exists on disk.
String exploreCityImageAsset(String cityId) =>
    '$exploreImageAssetRoot/$cityId.webp';

/// Resolves the catalog city id a bundled photo path belongs to, or null when
/// the path is not an Explore city photo.
///
/// The reverse direction of [exploreCityImageAsset], used by the integrity
/// test to prove every asset on disk is mapped to a real city.
String? exploreCityIdForImageAsset(String assetPath) {
  final String prefix = '$exploreImageAssetRoot/';
  if (!assetPath.startsWith(prefix) || !assetPath.endsWith('.webp')) {
    return null;
  }
  return assetPath.substring(prefix.length, assetPath.length - '.webp'.length);
}