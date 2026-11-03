import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/search/domain/search_context.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Home shortcuts for travel services (flights, stays, cars, activities).
class HomeNavButtons extends StatelessWidget {
  const HomeNavButtons({super.key, this.compact = false, this.searchContext});

  /// Slightly shorter tiles for the pinned Home header on compact layouts.
  final bool compact;

  /// Phase 4A — the traveller's travel context (mood, city, country, airport,
  /// budget) handed to the search surface the tile opens. Null keeps the
  /// previous behaviour (an empty search form).
  final SearchContext? searchContext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = <_NavItemData>[
      _NavItemData(
        label: l10n.searchFlights,
        icon: Icons.flight_rounded,
        hue: AppColors.flightHue,
        path: '/flights',
      ),
      _NavItemData(
        label: l10n.searchHotels,
        icon: Icons.home_rounded,
        hue: AppColors.hotelHue,
        path: '/hotels',
      ),
      _NavItemData(
        label: l10n.searchCars,
        icon: Icons.directions_car_rounded,
        hue: AppColors.carHue,
        path: '/cars',
      ),
      _NavItemData(
        label: l10n.homeNavActivities,
        icon: Icons.beach_access_rounded,
        hue: AppColors.packageHue,
        path: '/packages',
      ),
    ];

    return GridView.count(
      crossAxisCount: 4,
      mainAxisExtent: compact ? 56 : _NavTile.size,
      padding: EdgeInsets.zero,
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        for (final item in items)
          _NavTile(item: item, compact: compact, searchContext: searchContext),
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

/// One restrained service shortcut: a glyph and a clear, single-line label.
class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.item,
    this.compact = false,
    this.searchContext,
  });

  static const double size = 64;

  final _NavItemData item;
  final bool compact;

  /// Phase 4A — the travel context handed to the search surface this tile
  /// opens (null = an empty search form).
  final SearchContext? searchContext;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _pressed = false;

  void _tapDown(TapDownDetails _) => setState(() => _pressed = true);
  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final tc = context.tokigoColors;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double iconSize = widget.compact ? 24 : 26;
    final Color iconInk = isDark ? tc.textPrimary : widget.item.hue;

    return Semantics(
      button: true,
      label: widget.item.label,
      child: SizedBox.expand(
        child: GestureDetector(
          onTapDown: _tapDown,
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: _tap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: _pressed ? 0.955 : 1.0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: isDark
                    ? (_pressed ? tc.surface : tc.surfaceSecondary)
                    : (_pressed ? const Color(0xFFF5F5F5) : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _pressed ? tc.hairlineStrong : tc.hairline,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(widget.item.icon, size: iconSize, color: iconInk),
                  SizedBox(height: widget.compact ? 2 : 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: ExcludeSemantics(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.item.label,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: typography.captionSemibold.copyWith(
                            color: tc.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _tap() {
    HapticFeedback.selectionClick();
    context.push(
      widget.item.path,
      extra: widget.searchContext == null
          ? null
          : <String, dynamic>{'context': widget.searchContext!.toMap()},
    );
  }
}
