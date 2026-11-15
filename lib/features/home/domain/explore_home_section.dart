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
/// The catalog cities are never dropped: a backend item with the same id
/// replaces the catalog entry (the backend's own copy of the same city), and
/// anything else is appended after the curated rail.
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
      // Same city from the backend: keep ONE entry, the backend's copy.
      final int index = items.indexWhere((HomeItem e) => e.id == item.id);
      items[index] = item;
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