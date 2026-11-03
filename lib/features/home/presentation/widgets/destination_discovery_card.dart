import 'package:flutter/material.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/features/home/presentation/widgets/home_discovery_stay_card.dart';

/// Destination discovery card for Home discovery surfaces that are not the
/// swipe rail (grids and vertical lists).
///
/// It renders the same full-bleed editorial city card as the rail. Its skeleton
/// uses the same photo-led geometry without inventing city facts.
class DestinationDiscoveryCard extends StatelessWidget {
  const DestinationDiscoveryCard({
    super.key,
    required this.item,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    this.loading = false,
  });

  final HomeItem item;
  final VoidCallback? onTap;

  /// Kept for callers that still offer saving a destination; the card remains
  /// information-first and does not draw a heart over the photo.
  final ValueChanged<bool>? onFavorite;
  final bool isFavorite;

  /// Skeleton state — renders the same editorial geometry with no data.
  final bool loading;

  static const double _mediaAspectRatio = 1.5;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return HomeDiscoveryStayCardSkeleton(
        aspectRatio: _mediaAspectRatio,
        semanticsLabel: 'Loading destination',
        fillSheet: false,
      );
    }

    return HomeDiscoveryStayCard(
      item: item,
      onTap: onTap,
      aspectRatio: _mediaAspectRatio,
      fillSheet: false,
    );
  }
}
