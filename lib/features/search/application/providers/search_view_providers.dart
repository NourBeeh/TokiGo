import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/search_view_mode.dart';

final searchViewModeProvider = StateProvider<SearchViewMode>(
  (ref) => SearchViewMode.list,
);

/// Map viewport state for future map integration
final searchMapViewportProvider = StateProvider<SearchMapViewport?>(
  (ref) => null,
);

/// Selected offer on map for future integration
final searchMapSelectedOfferProvider = StateProvider<String?>((ref) => null);

class SearchMapViewport {
  final double latitude;
  final double longitude;
  final double zoom;

  SearchMapViewport({
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  SearchMapViewport copyWith({
    double? latitude,
    double? longitude,
    double? zoom,
  }) {
    return SearchMapViewport(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      zoom: zoom ?? this.zoom,
    );
  }
}
