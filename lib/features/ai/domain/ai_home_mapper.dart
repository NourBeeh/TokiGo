import 'package:flutter/foundation.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';

import 'ai_item.dart';
import 'ai_response.dart';
import 'ai_section.dart';
import 'ai_query_context.dart';

/// Maps the AI response contract onto the home *rendering* models.
///
/// This is the only boundary where AI domain models meet the HomeCard engine:
/// [HomeItem] / [HomeSection] / [HomeSectionWidget] stay untouched, so the
/// home feed pipeline is never coupled to how AI answers are structured.
class AiHomeMapper {
  const AiHomeMapper();

  /// Converts a full response into renderable home sections, applying the
  /// contract's explicit `order` hints (list order wins when absent).
  List<HomeSection> toHomeSections(AiResponse response) {
    final sections = _sortedByOrder(response.sections, (s) => s.order);
    return List<HomeSection>.generate(sections.length, (index) {
      return _toHomeSection(sections[index], sectionIndex: index);
    });
  }

  /// Extracts context from current home sections to pass to AI queries.
  /// Phase 15B Stage 3: Collects visible item IDs and metadata from the home feed
  /// to build a rich context for the AI assistant, keeping the HomeCard engine decoupled.
  AiQueryContext extractContextFromHomeSections(List<HomeSection> sections, {
    String? route,
    String? screenTitle,
    Map<String, double>? geolocation,
    Map<String, String>? travelDates,
  }) {
    final selectedOfferIds = sections.expand((section) => section.items.map((item) => item.id)).toList();
    
    final metadata = <String, dynamic>{
      'totalSections': sections.length,
      'totalItems': sections.fold<int>(0, (sum, section) => sum + section.items.length),
      'sectionTypes': sections.map((s) => s.layout.name).toSet().toList(),
    };

    return AiQueryContext(
      route: route ?? '/home',
      screenTitle: screenTitle ?? 'Home Feed',
      selectedOfferIds: selectedOfferIds,
      geolocation: geolocation,
      travelDates: travelDates,
      metadata: metadata,
    );
  }

  HomeSection _toHomeSection(AiSection section, {required int sectionIndex}) {
    final items = _sortedByOrder(section.items, (i) => i.order);
    return HomeSection(
      id: section.id ?? 'ai-section-$sectionIndex',
      title: section.title,
      subtitle: section.subtitle,
      layout: section.layout,
      items: List<HomeItem>.generate(items.length, (index) {
        return _toHomeItem(items[index], itemIndex: index);
      }),
      metadata: Map<String, dynamic>.unmodifiable(section.metadata),
    );
  }

  static HomeItem _toHomeItem(AiItem item, {required int itemIndex}) {
    return HomeItem(
      id: item.id.isEmpty ? 'ai-item-$itemIndex' : item.id,
      type: item.type,
      title: item.title,
      subtitle: item.subtitle,
      description: item.description,
      imageUrl: item.imageUrl,
      price: item.price,
      currency: item.currency,
      rating: item.rating,
      reviewCount: item.reviewCount,
      badge: item.badge,
      highlights: item.highlights,
      tags: item.tags,
      actionLabel: item.actionLabel,
      rawPrice: item.rawPrice,
      // Type-specific AI extras merge into metadata so existing cards
      // (e.g. FlightCard reading metadata['route']) keep rendering details.
      metadata: <String, dynamic>{...item.metadata, ...item.data},
    );
  }

  /// Stable sort: explicit `order` positions first, then original index.
  static List<T> _sortedByOrder<T>(
    List<T> source,
    int? Function(T value) orderOf,
  ) {
    if (source.length < 2) {
      return List<T>.of(source);
    }
    final indexed = <_OrderedEntry<T>>[];
    for (var i = 0; i < source.length; i++) {
      indexed.add(_OrderedEntry<T>(source[i], orderOf(source[i]) ?? i, i));
    }
    indexed.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.index.compareTo(b.index);
    });
    return indexed.map((e) => e.value).toList();
  }
}

@immutable
class _OrderedEntry<T> {
  const _OrderedEntry(this.value, this.order, this.index);

  final T value;
  final int order;
  final int index;
}