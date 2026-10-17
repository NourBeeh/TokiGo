import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// NAV — Home-centric vertical navigation strip (replaces the bottom bar).
///
/// The four product verticals live as a horizontal row of premium buttons
/// directly under the AI search pill on the Home surface:
///
///   ✈ طيران   🏨 إقامات   🚗 سيارات   🧭 باكدجات
///
/// Each button routes to its EXISTING search page ('/flights', '/hotels',
/// '/cars', '/packages') — no new pages, no new controllers, no route
/// changes. Groups + Explore dissolve into Home discovery later (7B);
/// their entry points live here as a compact secondary row so nothing is
/// lost (rules: no page deletion).
///
/// Unified premium minimalist identity for ALL six buttons: identical
/// rounded-rectangle capsules, soft pastel hue tints, a consistent
/// outline/linear icon set at one shared 32px size, and high-contrast
/// text. The rows adapt to ANY screen width through Expanded weights —
/// the six buttons are always fully visible with NO horizontal scrolling
/// (RTL/LTR mirrored automatically by the Row).
class HomeNavButtons extends StatelessWidget {
  const HomeNavButtons({super.key, this.showSecondary = true});

  /// Whether the compact Groups/Explore row renders under the verticals.
  final bool showSecondary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final verticals = <_NavItemData>[
      _NavItemData(
        label: l10n.searchFlights,
        icon: Icons.flight_takeoff_outlined,
        hue: AppColors.flightHue,
        path: '/flights',
      ),
      _NavItemData(
        label: l10n.searchHotels,
        icon: Icons.hotel_outlined,
        hue: AppColors.hotelHue,
        path: '/hotels',
      ),
      _NavItemData(
        label: l10n.searchCars,
        icon: Icons.directions_car_outlined,
        hue: AppColors.carHue,
        path: '/cars',
      ),
      _NavItemData(
        label: l10n.searchPackages,
        icon: Icons.map_outlined,
        hue: AppColors.packageHue,
        path: '/packages',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Primary verticals — the Home navigation row. Equal Expanded
        // weights keep every button fully on-screen at any width.
        Row(
          children: <Widget>[
            for (var index = 0; index < verticals.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _NavButton(item: verticals[index]),
              ),
            ],
          ],
        ),
        if (showSecondary) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: _NavButton(
                  item: _NavItemData(
                    label: l10n.exploreTitle,
                    icon: Icons.explore_outlined,
                    hue: AppColors.exploreHue,
                    path: '/explore',
                  ),
                  wide: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _NavButton(
                  item: _NavItemData(
                    label: l10n.groupsTitle,
                    icon: Icons.groups_outlined,
                    hue: AppColors.groupsHue,
                    path: '/groups',
                  ),
                  wide: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.hue,
    required this.path,
  });

  final String label;
  final IconData icon;
  final Color hue;
  final String path;
}

/// One unified service button — identical capsule, tint, iconography and
/// typography for every destination. The compact variant stacks icon over
/// label (four verticals, 96px tall); the [wide] variant is a slimmer 48px
/// capsule centring icon beside label (Explore / Groups half-width cards).
/// Both share the same 32px outline icon for matched visual weight.
class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, this.wide = false});

  static const double _iconSize = 32;
  static const double _compactHeight = 96;
  static const double _wideHeight = 48;

  final _NavItemData item;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return SizedBox(
      height: wide ? _wideHeight : _compactHeight,
      // 48px minimum accessible target height (the pill is taller).
      child: Material(
        color: item.hue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(item.path),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: wide
                ? Row(
                    // Wide slim card — icon beside label, softly centred.
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(item.icon, size: _iconSize, color: item.hue),
                      const SizedBox(width: AppSpacing.md),
                      Flexible(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: typography.captionSemibold.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    // Compact card — icon over label, centred.
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(item.icon, size: _iconSize, color: item.hue),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: typography.captionSemibold.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
