import 'package:flutter/foundation.dart';
import 'home_item.dart';
import 'home_types.dart';

@immutable
class HomeSection {
  const HomeSection({
    required this.id,
    required this.title,
    this.subtitle,
    required this.layout,
    required this.items,
    this.isPaginated = false,
    this.metadata = const {},
  });

  final String id;
  final String title;
  final String? subtitle;
  final HomeSectionLayout layout;
  final List<HomeItem> items;
  final bool isPaginated;
  final Map<String, dynamic> metadata;

  /// Returns a copy of this section with [items] replaced. Every other field is
  /// preserved, so a presentation-layer guard (hiding an unverified price, for
  /// example) cannot accidentally drop the composer's tags or pagination.
  HomeSection withItems(List<HomeItem> items) => HomeSection(
    id: id,
    title: title,
    subtitle: subtitle,
    layout: layout,
    items: items,
    isPaginated: isPaginated,
    metadata: metadata,
  );
}
