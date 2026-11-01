import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/config/app_config.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/search/domain/search_context.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Home shortcuts for Flights, Hotels, Cars Rental and Activities.
class HomeNavButtons extends StatelessWidget {
  const HomeNavButtons({super.key, this.compact = false, this.searchContext});

  /// A 46×46 tile instead of 64×64 — the hero has to carry the search field
  /// and the destination caption in the same fixed band on short phones.
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
        icon: Icons.hotel,
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
      // TEMPORARY — Groups is parked (owner request). Its tile is hidden, the
      // route redirects Home, and the page stays in the codebase.
      if (AppConfig.groupsEnabled)
        _NavItemData(
          label: l10n.groupsTitle,
          icon: Icons.groups_rounded,
          hue: AppColors.ink,
          path: '/groups',
        ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useCompactTiles =
            compact || constraints.maxWidth / items.length < _NavTile.size;
        return Row(
          children: <Widget>[
            for (final item in items)
              Expanded(
                child: _NavTile(
                  item: item,
                  compact: useCompactTiles,
                  searchContext: searchContext,
                ),
              ),
          ],
        );
      },
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

/// One service tile: a rounded container holding the vertical's glyph, over a
/// single-line label. The whole column is the tap target.
///
/// "Soft lift": the white card floats on a warm glow and presses down with a
/// spring scale + shadow settle, so the flat design reads as physical depth.
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
  void _tapUp(TapUpDetails _) {
    setState(() => _pressed = false);
    HapticFeedback.selectionClick();
    context.push(
      widget.item.path,
      extra: widget.searchContext == null
          ? null
          : <String, dynamic>{'context': widget.searchContext!.toMap()},
    );
  }

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final double iconSize = widget.compact ? 22 : 28;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: SizedBox(
            width: double.infinity,
            height: widget.compact ? 62 : 72,
            child: Semantics(
              button: true,
              label: widget.item.label,
              child: GestureDetector(
                onTapDown: _tapDown,
                onTapUp: _tapUp,
                onTapCancel: () => setState(() => _pressed = false),
                behavior: HitTestBehavior.opaque,
                child: AnimatedScale(
                  scale: _pressed ? 0.955 : 1.0,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      // Snow-white top face with a hair of shade at the base —
                      // the card reads as a machined slab, not a flat fill.
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.white,
                          Color.lerp(Colors.white, const Color(0xFFB9C2CE),
                              _pressed ? 0.10 : 0.05)!,
                        ],
                        stops: const <double>[0.55, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.hairline),
                      boxShadow: <BoxShadow>[
                        // Warm lift glow (brand-tinted) — tight when pressed,
                        // tall and soft when floating.
                        BoxShadow(
                          color: AppColors.brand.withValues(
                            alpha: _pressed ? 0.10 : 0.14,
                          ),
                          blurRadius: _pressed ? 10 : 18,
                          spreadRadius: _pressed ? -2 : 0,
                          offset: Offset(0, _pressed ? 3 : 6),
                        ),
                        // Crisp contact shadow right under the slab.
                        BoxShadow(
                          color: AppColors.ink.withValues(
                            alpha: _pressed ? 0.10 : 0.06,
                          ),
                          blurRadius: 2,
                          offset: Offset(0, _pressed ? 1 : 2),
                        ),
                        // Inner top highlight — the lit edge of the slab.
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.9),
                          blurRadius: 0,
                          spreadRadius: 0,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(widget.item.icon, size: iconSize, color: widget.item.hue),
                      SizedBox(height: widget.compact ? 2 : AppSpacing.xs),
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
                                color: AppColors.textPrimary,
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
          ),
        ),
      ],
    );
  }
}
