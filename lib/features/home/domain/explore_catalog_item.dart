/// Adapts the bundled Explore catalog into the Home feed's card model.
///
/// The catalog is a client-side data library; the Home feed, the section
/// renderer and the city page all speak [HomeItem]. This is the ONE bridge
/// between them, so a catalog city and a backend city render through the exact
/// same widget and navigation path.
///
/// ## What the adapter does and does not invent
///
/// It copies the catalog's own facts (name, country, region, photo asset,
/// photo attribution). It does not synthesize a rating, a review count, a
/// popularity score or a stay count — none of those exist for a catalog city,
/// and the city page would otherwise present a fabricated number.
library;

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/home/domain/explore_catalog.dart';

/// Converts a catalog city into the card model the Home feed renders.
///
/// The item id IS the city id, so the existing `ValueKey('explore-city-<id>')`
/// and the existing tap-through to `/city` keep working with no special case.
HomeItem exploreCityToHomeItem(ExploreCity city) {
  return HomeItem(
    id: city.id,
    type: HomeCardType.destination,
    title: city.name,
    subtitle: city.country,
    description: city.subtitle,
    // Bundled asset path — never a remote URL. CardImage resolves an
    // `assets/...` path to an AssetImage, so the card needs no network.
    imageUrl: city.asset,
    tags: city.tags,
    metadata: <String, dynamic>{
      'country': city.country,
      'region': city.region,
      'city': city.name,
      // Photo provenance, shown as the credit on the city page.
      if (city.imageCredit != null) 'imageCredit': city.imageCredit,
      if (city.imageLicense != null) 'imageLicense': city.imageLicense,
      if (city.imageSource != null) 'imageSource': city.imageSource,
      'moods': city.tags,
      'audiences': city.audiences,
    },
  );
}

/// Converts a list of catalog cities, preserving order.
List<HomeItem> exploreCitiesToHomeItems(List<ExploreCity> cities) =>
    <HomeItem>[for (final ExploreCity city in cities) exploreCityToHomeItem(city)];