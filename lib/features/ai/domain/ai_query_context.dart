import 'package:flutter/foundation.dart';
import '../../../core/navigation/app_route.dart';

/// Immutable context describing where the user currently is within the app
/// when an AI query is triggered (Phase 15A context-aware foundation).
@immutable
class AiQueryContext {
  const AiQueryContext({
    required this.route,
    this.screenTitle,
    this.selectedOfferIds = const [],
    this.geolocation, // {lat: double, lng: double}
    this.travelDates, // {from: ISO string, to: ISO string}
    this.metadata = const {},
  });

  /// The current page/route identifier matching AppRoute values:
  /// home, flights, hotels, cars, bag, other
  final String route;

  /// Optional human-readable screen title from AppRoute.title
  final String? screenTitle;

  /// Optional lightweight selected offer or item identifiers on the current page.
  final List<String> selectedOfferIds;

  /// Optional user's current geolocation coordinates (Phase 15B)
  final Map<String, double>? geolocation;

  /// Optional selected travel dates for the current search (Phase 15B)
  final Map<String, String>? travelDates;

  /// Optional arbitrary metadata payload for future extensions.
  final Map<String, dynamic> metadata;

  /// Create AiQueryContext from an AppRoute enum value (used in shell.dart)
  factory AiQueryContext.fromAppRoute(
    AppRoute appRoute, {
    String? screenTitle,
    Map<String, double>? geolocation,
    Map<String, String>? travelDates,
    List<String> selectedOfferIds = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return AiQueryContext(
      route: appRoute.path,
      screenTitle: screenTitle,
      geolocation: geolocation,
      travelDates: travelDates,
      selectedOfferIds: selectedOfferIds,
      metadata: metadata,
    );
  }

  /// Serialize to map for API request body
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'route': route,
      if (screenTitle != null) 'screenTitle': screenTitle,
      if (selectedOfferIds.isNotEmpty) 'selectedOfferIds': selectedOfferIds,
      if (geolocation != null) 'geolocation': geolocation,
      if (travelDates != null) 'travelDates': travelDates,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  /// Deserialize from map if needed
  factory AiQueryContext.fromMap(Map<String, dynamic> map) {
    return AiQueryContext(
      route: map['route'] as String? ?? 'home',
      screenTitle: map['screenTitle'] as String?,
      selectedOfferIds:
          (map['selectedOfferIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      geolocation: (map['geolocation'] as Map<String, dynamic>?)
          ?.cast<String, double>(),
      travelDates: (map['travelDates'] as Map<String, dynamic>?)
          ?.cast<String, String>(),
      metadata: map['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AiQueryContext &&
        other.route == route &&
        other.screenTitle == screenTitle &&
        mapEquals(other.geolocation, geolocation) &&
        mapEquals(other.travelDates, travelDates) &&
        mapEquals(other.metadata, metadata) &&
        listEquals(other.selectedOfferIds, selectedOfferIds);
  }

  @override
  int get hashCode => Object.hash(
    route,
    screenTitle,
    geolocation,
    travelDates,
    Object.hashAllUnordered(
      metadata.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    Object.hashAll(selectedOfferIds),
  );
}
