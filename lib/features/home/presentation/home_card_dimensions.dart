import 'package:flutter/material.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';

/// Client-side card dimension defaults for Home Discovery carousels.
///
/// These are UI-level constants — no API/model changes.
class HomeCardDimensions {
  HomeCardDimensions._();

  /// Default card width per category for horizontal carousels.
  static double cardWidthForType(HomeCardType type) {
    switch (type) {
      case HomeCardType.hotel:
        return 220.0;
      case HomeCardType.flight:
        return 280.0; // full recommendation card width
      case HomeCardType.car:
        return 220.0;
      case HomeCardType.package:
        return 220.0;
      case HomeCardType.destination:
        return 280.0;
      case HomeCardType.deal:
        return 280.0;
    }
  }

  /// Default card height per category.
  static double cardHeightForType(HomeCardType type) {
    switch (type) {
      case HomeCardType.hotel:
        return 240.0;
      case HomeCardType.flight:
        return 240.0;
      case HomeCardType.car:
        return 220.0;
      case HomeCardType.package:
        return 220.0;
      case HomeCardType.destination:
        return 240.0;
      case HomeCardType.deal:
        return 220.0;
    }
  }

  /// Image aspect ratio (width / height) per category.
  static double imageRatioForType(HomeCardType type) {
    switch (type) {
      case HomeCardType.hotel:
      case HomeCardType.flight:
      case HomeCardType.car:
        return 16 / 9;
      case HomeCardType.destination:
      case HomeCardType.deal:
        return 7 / 6;
      case HomeCardType.package:
        return 16 / 9;
    }
  }

  /// Carousel height for a section based on its primary card type.
  static double carouselHeightForType(HomeCardType type) {
    return cardHeightForType(type) + 56; // card height + section title spacing
  }

  /// Responsive grid cross-axis count based on available width.
  static int gridCrossAxisCount(
    BuildContext context, {
    double minCardWidth = 160,
  }) {
    final width = MediaQuery.of(context).size.width;
    final count = (width / minCardWidth).floor();
    return count.clamp(1, 2); // max 2 columns
  }

  /// Grid child aspect ratio (width / height).
  static double gridChildAspectRatio(HomeCardType type) {
    final w = cardWidthForType(type);
    final h = cardHeightForType(type);
    return w / h;
  }
}
