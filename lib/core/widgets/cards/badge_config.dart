import 'package:flutter/material.dart';
import 'package:tokigo/core/theme/app_colors.dart';

/// Semantic badge categories for consistent UX and theming
enum BadgeCategory {
  commercial, // discount, limitedDeal, memberPrice
  trust, // verified, topRated
  booking, // freeCancellation, payLater, instantConfirmation
  flight, // cheapest, fastest, best, selfTransfer, airportChange, riskyConnection
  hotel, // breakfastIncluded, limitedRooms
}

/// Individual badge types with semantic meaning
enum BadgeType {
  // Commercial
  discount,
  limitedDeal,
  memberPrice,
  // Trust
  verified,
  topRated,
  // Booking
  freeCancellation,
  payLater,
  instantConfirmation,
  // Flight
  cheapest,
  fastest,
  best,
  selfTransfer,
  airportChange,
  riskyConnection,
  // Hotel
  breakfastIncluded,
  limitedRooms,
}

/// Semantic emphasis level for badge styling
enum BadgeEmphasis {
  primary, // Most important - primary semantic color
  secondary, // Standard - uses theme container colors
  warning, // Warning/attention - warning semantic color
  error, // Error/unavailable - error semantic color
  info, // Informational - info semantic color
}

/// Configuration for each badge type
class BadgeSpec {
  const BadgeSpec({
    required this.type,
    required this.category,
    required this.label,
    required this.icon,
    required this.emphasis,
    required this.priority,
  });

  final BadgeType type;
  final BadgeCategory category;
  final String label;
  final IconData icon;
  final BadgeEmphasis emphasis;
  final int priority; // Lower = more important (shown first)

  /// Get semantic color based on emphasis and theme
  Color getColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (emphasis) {
      case BadgeEmphasis.primary:
        return scheme.primary;
      case BadgeEmphasis.secondary:
        return scheme.onSurfaceVariant;
      case BadgeEmphasis.warning:
        return AppColors.warning;
      case BadgeEmphasis.error:
        return scheme.error;
      case BadgeEmphasis.info:
        return scheme.primary;
    }
  }

  /// Get background color for tinted variant
  Color getBackgroundColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (emphasis) {
      case BadgeEmphasis.primary:
        return scheme.primaryContainer;
      case BadgeEmphasis.secondary:
        return scheme.surfaceContainerHighest;
      case BadgeEmphasis.warning:
        return AppColors.warning.withValues(alpha: 0.15);
      case BadgeEmphasis.error:
        return scheme.errorContainer;
      case BadgeEmphasis.info:
        return scheme.primaryContainer;
    }
  }
}

/// Central registry of all badge specifications
class BadgeRegistry {
  static const List<BadgeSpec> _all = [
    // Commercial
    BadgeSpec(
      type: BadgeType.discount,
      category: BadgeCategory.commercial,
      label: 'Discount',
      icon: Icons.local_offer,
      emphasis: BadgeEmphasis.primary,
      priority: 1,
    ),
    BadgeSpec(
      type: BadgeType.limitedDeal,
      category: BadgeCategory.commercial,
      label: 'Limited Deal',
      icon: Icons.flash_on,
      emphasis: BadgeEmphasis.warning,
      priority: 2,
    ),
    BadgeSpec(
      type: BadgeType.memberPrice,
      category: BadgeCategory.commercial,
      label: 'Member Price',
      icon: Icons.verified_user,
      emphasis: BadgeEmphasis.info,
      priority: 3,
    ),
    // Trust
    BadgeSpec(
      type: BadgeType.verified,
      category: BadgeCategory.trust,
      label: 'Verified',
      icon: Icons.verified,
      emphasis: BadgeEmphasis.primary,
      priority: 1,
    ),
    BadgeSpec(
      type: BadgeType.topRated,
      category: BadgeCategory.trust,
      label: 'Top Rated',
      icon: Icons.star,
      emphasis: BadgeEmphasis.secondary,
      priority: 2,
    ),
    // Booking
    BadgeSpec(
      type: BadgeType.freeCancellation,
      category: BadgeCategory.booking,
      label: 'Free Cancellation',
      icon: Icons.free_cancellation,
      emphasis: BadgeEmphasis.primary,
      priority: 1,
    ),
    BadgeSpec(
      type: BadgeType.payLater,
      category: BadgeCategory.booking,
      label: 'Pay Later',
      icon: Icons.payment,
      emphasis: BadgeEmphasis.info,
      priority: 2,
    ),
    BadgeSpec(
      type: BadgeType.instantConfirmation,
      category: BadgeCategory.booking,
      label: 'Instant Confirmation',
      icon: Icons.check_circle,
      emphasis: BadgeEmphasis.primary,
      priority: 3,
    ),
    // Flight
    BadgeSpec(
      type: BadgeType.cheapest,
      category: BadgeCategory.flight,
      label: 'Cheapest',
      icon: Icons.attach_money,
      emphasis: BadgeEmphasis.primary,
      priority: 1,
    ),
    BadgeSpec(
      type: BadgeType.fastest,
      category: BadgeCategory.flight,
      label: 'Fastest',
      icon: Icons.speed,
      emphasis: BadgeEmphasis.primary,
      priority: 2,
    ),
    BadgeSpec(
      type: BadgeType.best,
      category: BadgeCategory.flight,
      label: 'Best Value',
      icon: Icons.star,
      emphasis: BadgeEmphasis.primary,
      priority: 3,
    ),
    BadgeSpec(
      type: BadgeType.selfTransfer,
      category: BadgeCategory.flight,
      label: 'Self Transfer',
      icon: Icons.swap_horiz,
      emphasis: BadgeEmphasis.warning,
      priority: 4,
    ),
    BadgeSpec(
      type: BadgeType.airportChange,
      category: BadgeCategory.flight,
      label: 'Airport Change',
      icon: Icons.flight_land,
      emphasis: BadgeEmphasis.warning,
      priority: 5,
    ),
    BadgeSpec(
      type: BadgeType.riskyConnection,
      category: BadgeCategory.flight,
      label: 'Risky Connection',
      icon: Icons.warning,
      emphasis: BadgeEmphasis.error,
      priority: 6,
    ),
    // Hotel
    BadgeSpec(
      type: BadgeType.breakfastIncluded,
      category: BadgeCategory.hotel,
      label: 'Breakfast Included',
      icon: Icons.free_breakfast,
      emphasis: BadgeEmphasis.secondary,
      priority: 1,
    ),
    BadgeSpec(
      type: BadgeType.limitedRooms,
      category: BadgeCategory.hotel,
      label: 'Limited Rooms',
      icon: Icons.hotel,
      emphasis: BadgeEmphasis.error,
      priority: 2,
    ),
  ];

  static BadgeSpec? getSpec(BadgeType type) {
    try {
      return _all.firstWhere((s) => s.type == type);
    } catch (_) {
      return null;
    }
  }

  static List<BadgeSpec> getByCategory(BadgeCategory category) {
    final specs = _all.where((s) => s.category == category).toList();
    specs.sort((a, b) => a.priority.compareTo(b.priority));
    return specs;
  }

  static List<BadgeSpec> getAll() => List.unmodifiable(_all);
}