import 'package:tokigo/core/domain/models/home/home_item.dart';

/// Whether a [HomeItem] carries no renderable data at all.
///
/// Such an item is a development-preview/skeleton entry: it must render the
/// approved card in its LOADING state, never an empty card. Every Home surface
/// (the feed dispatcher, the section widget and the flight rail) asks this one
/// predicate, so the definition cannot drift between them.
bool isHomeSkeletonItem(HomeItem item) =>
    item.title.trim().isEmpty &&
    item.price == null &&
    (item.imageUrl == null || item.imageUrl!.isEmpty);
