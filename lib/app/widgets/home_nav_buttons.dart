import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/features/search/domain/search_context.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Home shortcuts for travel services — the owner's spec: four equal cards on
/// one row (Flights, Hotels, Cars, Trips), each a white 88dp tile with 16dp
/// corners, a 1dp `#E0DCD6` border, a 25px accent glyph and a 12/600 accent
/// label 6dp below it. No shadows.
///
/// Every tile keeps its real destination: the three search surfaces receive
/// the traveller's travel context through the router `extra`, and Trips opens
/// the existing My Trips bag.
class HomeNavButtons extends StatelessWidget {
  const HomeNavButtons({super.key, this.searchContext});

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
        icon: Icons.flight_takeoff_rounded,
        path: '/flights',
      ),
      _NavItemData(
        label: l10n.searchHotels,
        icon: Icons.hotel_rounded,
        path: '/hotels',
      ),
      _NavItemData(
        label: l10n.searchCars,
        icon: Icons.directions_car_rounded,
        path: '/cars',
      ),
      _NavItemData(
        label: l10n.homeNavTrips,
        icon: Icons.luggage_rounded,
        path: '/bag',
      ),
    ];

    // Four equal, responsive tiles: `Expanded` shares whatever width the
    // screen leaves after the gutters, so the row never overflows and the
    // spacing stays balanced from 320pt phones up.
    return Row(
      children: <Widget>[
        for (int i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(child: _NavTile(item: items[i], searchContext: searchContext)),
        ],
      ],
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final String path;
}

/// One restrained service shortcut: an accent glyph and a clear, single-line
/// accent label, centred in the spec's bordered tile.
class _NavTile extends StatefulWidget {
  const _NavTile({required this.item, this.searchContext});

  /// The spec's tile height.
  static const double height = 88;

  /// Glyph size from the spec.
  static const double iconSize = 25;

  /// Gap between the glyph and its label.
  static const double iconLabelGap = 6;

  /// Label size from the spec (weight w600 comes from `captionSemibold`).
  static const double labelSize = 12;

  final _NavItemData item;

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
    final accent = HomeDesignTokens.accentOf(context);

    return Semantics(
      button: true,
      label: widget.item.label,
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
            height: _NavTile.height,
            decoration: BoxDecoration(
              color: _pressed
                  ? HomeDesignTokens.pressedSurfaceOf(context)
                  : HomeDesignTokens.surfaceOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: HomeDesignTokens.borderOf(context),
                width: 1,
              ),
              // The spec's tiles carry no elevation.
              boxShadow: const <BoxShadow>[],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  widget.item.icon,
                  size: _NavTile.iconSize,
                  color: accent,
                ),
                const SizedBox(height: _NavTile.iconLabelGap),
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
                          fontSize: _NavTile.labelSize,
                          color: accent,
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
