/// Builds the Explore section that Home renders, from the bundled catalog.
///
/// Home's destination rail used to be whatever `/home/sections` returned. That
/// made the section — and the whole "where next?" first impression — dependent
/// on a reachable backend. This builder makes the bundled catalog the
/// guaranteed baseline instead:
///
/// * The section ALWAYS exists, so Explore renders on a first offline launch.
/// * It is limited to the curated selection ([curatedHomeCityIds]) — the full
///   catalog lives behind View All, exactly as before.
/// * The layout is `grid`, which the section renderer turns into the same
///   destination cover-flow rail; the card widget, tap handling and section
///   header are unchanged.
///
/// When the backend also publishes destination cards, the caller merges them
/// with [mergeBackendDestinations] rather than replacing the catalog.
library;

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/domain/explore_catalog.dart';
import 'package:tokigo/features/home/domain/explore_catalog_item.dart';

/// The Home Explore section, built from the curated catalog selection.
HomeSection buildHomeExploreSection() {
  return HomeSection(
    id: 'explore',
    title: 'Explore',
    // The presentation layer resolves this published title into the active
    // language ('Explore' / 'استكشف'); see HomeSectionTitles.
    layout: HomeSectionLayout.grid,
    items: exploreCitiesToHomeItems(curatedHomeCities),
    metadata: const <String, dynamic>{
      'semanticId': 'explore',
      'reason': 'discovery',
    },
  );
}

/// The full-catalog section used by the View All page.
///
/// Same identity and layout as the Home section; only the item list differs.
/// Keeping one id means the two surfaces stay the same page — there is no
/// second destination page and no parallel navigation flow.
HomeSection buildAllCitiesSection() {
  return HomeSection(
    id: 'explore',
    title: 'Explore',
    layout: HomeSectionLayout.grid,
    items: exploreCitiesToHomeItems(exploreCities),
    metadata: const <String, dynamic>{
      'semanticId': 'explore',
      'reason': 'discovery',
    },
  );
}

/// Appends backend destination cards to the curated selection, de-duplicated
/// by id, and returns the resulting Home section.
///
/// The catalog cities are never dropped: a backend item with the same id is
/// merged FIELD BY FIELD into the catalog entry (see
/// [mergeExploreDestination]) rather than replacing it wholesale, so an
/// incomplete backend record cannot strip a city's bundled photo or its
/// verified provenance. Anything else is appended after the curated rail.
HomeSection mergeBackendDestinations(
  HomeSection explore, {
  required List<HomeItem> backendDestinations,
}) {
  final Map<String, HomeItem> byId = <String, HomeItem>{
    for (final HomeItem item in explore.items) item.id: item,
  };
  final List<HomeItem> items = <HomeItem>[...explore.items];
  for (final HomeItem item in backendDestinations) {
    if (item.id.trim().isEmpty) continue;
    if (byId.containsKey(item.id)) {
      // Same city from the backend: merge the backend's facts into the
      // catalog entry, keeping the catalog's bundled image unless the backend
      // carries a valid one of its own.
      final int index = items.indexWhere((HomeItem e) => e.id == item.id);
      items[index] = mergeExploreDestination(items[index], item);
      continue;
    }
    byId[item.id] = item;
    items.add(item);
  }
  return HomeSection(
    id: explore.id,
    title: explore.title,
    subtitle: explore.subtitle,
    layout: explore.layout,
    items: items,
    isPaginated: explore.isPaginated,
    metadata: explore.metadata,
  );
}

/// True when [imageUrl] is a usable bundled Explore photo.
///
/// Explore cards are bundled-only by contract: a remote URL would introduce
/// network loading, and an empty/garbage string would blank the card. So only
/// an `assets/...` path counts as a valid image here; anything else
/// (null, empty, http(s), other schemes) is ignored by the merge.
bool isValidExploreImageSource(String? imageUrl) {
  final String value = (imageUrl ?? '').trim();
  return value.startsWith('assets/');
}

/// Merges a backend destination into its catalog counterpart, field by field.
///
/// The catalog entry is the base and keeps its identity (id, type) and every
/// fact the backend does not actually provide. A backend field wins only when
/// it carries a real value:
///
/// * [HomeItem.imageUrl] wins only when it is a bundled asset path
///   ([isValidExploreImageSource]) — otherwise the catalog's photo stays, so a
///   backend record with a missing/empty/remote image can never remove it.
/// * [HomeItem.title], [HomeItem.subtitle], [HomeItem.description] and
///   [HomeItem.tags] win only when non-empty after trimming.
/// * [HomeItem.metadata] is overlaid key by key, skipping null/empty backend
///   values so incomplete backend data cannot erase catalog provenance.
/// * Scalar facts ([HomeItem.price], [HomeItem.rating], …) win when non-null.
///
/// The result is a normal [HomeItem]; no remote image loading is introduced.
HomeItem mergeExploreDestination(HomeItem catalog, HomeItem backend) {
  final Map<String, dynamic> metadata = <String, dynamic>{...catalog.metadata};
  backend.metadata.forEach((String key, Object? value) {
    if (value == null) return;
    if (value is String && value.trim().isEmpty) return;
    metadata[key] = value;
  });

  return HomeItem(
    // Catalog identity is stable: the id and card type never change.
    id: catalog.id,
    type: catalog.type,
    title: backend.title.trim().isNotEmpty ? backend.title : catalog.title,
    subtitle: _nonEmpty(backend.subtitle) ?? catalog.subtitle,
    description: _nonEmpty(backend.description) ?? catalog.description,
    imageUrl: isValidExploreImageSource(backend.imageUrl)
        ? backend.imageUrl
        : catalog.imageUrl,
    price: backend.price ?? catalog.price,
    currency: backend.currency ?? catalog.currency,
    customerPrice: backend.customerPrice ?? catalog.customerPrice,
    rating: backend.rating ?? catalog.rating,
    reviewCount: backend.reviewCount ?? catalog.reviewCount,
    badge: backend.badge ?? catalog.badge,
    highlights: backend.highlights.isNotEmpty
        ? backend.highlights
        : catalog.highlights,
    tags: backend.tags.isNotEmpty ? backend.tags : catalog.tags,
    actionLabel: backend.actionLabel ?? catalog.actionLabel,
    rawPrice: backend.rawPrice ?? catalog.rawPrice,
    metadata: metadata,
  );
}

String? _nonEmpty(String? value) {
  final String trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}