import 'package:flutter/material.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';

/// Client-side card dimension defaults for the Home feed.
///
/// These are UI-level constants — no API/model changes.
///
/// ## One source of truth
///
/// Every Home card and its loading skeleton reads its geometry from here, so a
/// change made to a card's dimensions, corner radius or rail fraction moves
/// the skeleton with it automatically. A skeleton is never a second copy of
/// the layout: it is the same card widget with these tokens applied and its
/// content replaced by shimmer placeholders.
class HomeCardDimensions {
  HomeCardDimensions._();

  // ── Shared card shell ───────────────────────────────────────────────────

  /// Corner radius shared by every Home card and its skeleton.
  static const double radius = AppRadius.lg;

  /// The same radius as a [BorderRadius], for cards that build their own
  /// decoration instead of going through `BaseCard`.
  static BorderRadius get borderRadius => BorderRadius.circular(radius);

  /// Hairline width on a Home card.
  static const double borderWidth = 1;

  /// Inline gap between rail cards (the 12dp peek).
  static const double railGap = AppSpacing.md;

  // ── Media ratios ────────────────────────────────────────────────────────

  /// Hotel photo width ÷ height in the Home stay rail.
  static const double stayMediaAspectRatio = 1.6;

  /// Destination photo width ÷ height in the Home Discover rail.
  static const double destinationMediaAspectRatio = 1.3;

  // ── Rail geometry ───────────────────────────────────────────────────────

  /// Width of one stay page as a fraction of the rail's width. A little under
  /// the full width so the next stay peeks — the only affordance that says
  /// "swipe me" without a tutorial.
  static const double stayViewportFraction = 0.8;

  /// Width of one Discover page as a fraction of the rail's width.
  static const double destinationViewportFraction = 0.9;

  // ── Sheet budgets ───────────────────────────────────────────────────────

  /// A stay sheet's content budget at the default text scale: name, class or
  /// score, location, distance, price and their gaps — including a two-line
  /// stay name — grown with the traveller's text scale.
  static const double staySheetTextHeight = 188;

  /// A city sheet's content budget at the default text scale: name, place,
  /// one description line and the pinned action row.
  static const double destinationSheetTextHeight = 60;

  // ── Per-type grid figures ───────────────────────────────────────────────
  //
  // Used by the flight/product rails and the responsive grid math. New Home
  // cards should express their geometry through the shared tokens above and
  // the card widgets themselves, not by adding entries here.

  /// Default card width per category for horizontal carousels.
  static double cardWidthForType(HomeCardType type) {
    switch (type) {
      case HomeCardType.hotel:
        return 220.0;
      case HomeCardType.flight:
        return 300.0; // full recommendation card width
      case HomeCardType.car:
        return 220.0;
      case HomeCardType.package:
        return 220.0;
      case HomeCardType.destination:
        return 220.0;
      case HomeCardType.deal:
        return 280.0;
    }
  }

  /// Default card height per category.
  static double cardHeightForType(HomeCardType type) {
    switch (type) {
      case HomeCardType.hotel:
        return 276.0;
      case HomeCardType.flight:
        return 252.0;
      case HomeCardType.car:
        return 276.0;
      case HomeCardType.package:
        return 276.0;
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
      case HomeCardType.destination:
        return 16 / 9;
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
