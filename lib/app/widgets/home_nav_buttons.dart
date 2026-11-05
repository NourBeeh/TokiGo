import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/home/domain/home_action.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/features/search/domain/search_context.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// One Home quick action, as data.
///
/// The action bar and the legacy four-up row both render this definition, so
/// adding a service means adding a value to [HomeAction] and one entry to
/// [homeActionDefinitions] — the layout code never changes.
@immutable
class HomeActionDefinition {
  const HomeActionDefinition({
    required this.action,
    required this.label,
    required this.icon,
    required this.path,
  });

  /// The in-page selection this tile represents.
  final HomeAction action;

  /// The localized label shown under the glyph.
  final String label;

  /// The service glyph.
  final IconData icon;

  /// Fallback destination for legacy hosts that do not switch in-page.
  final String path;
}

/// The single source of truth for Home's service shortcuts.
///
/// Order is intentional: Flights, Hotels (labelled "Stays"), Cars, Trips.
List<HomeActionDefinition> homeActionDefinitions(AppLocalizations l10n) {
  return <HomeActionDefinition>[
    HomeActionDefinition(
      action: HomeAction.flights,
      label: l10n.searchFlights,
      icon: Icons.flight_takeoff_rounded,
      path: '/flights',
    ),
    HomeActionDefinition(
      action: HomeAction.hotels,
      label: l10n.searchHotels,
      icon: Icons.hotel_rounded,
      path: '/hotels',
    ),
    HomeActionDefinition(
      action: HomeAction.cars,
      label: l10n.searchCars,
      icon: Icons.directions_car_rounded,
      path: '/cars',
    ),
    HomeActionDefinition(
      action: HomeAction.trips,
      label: l10n.homeNavTrips,
      icon: Icons.luggage_rounded,
      path: '/bag',
    ),
  ];
}

/// Home shortcuts for travel services — the owner's spec: four equal cards on
/// one row (Flights, Hotels, Cars, Trips), each a white 88dp tile with 16dp
/// corners, a 1dp `#E0DCD6` border, a 25px accent glyph and a 12/600 accent
/// label 6dp below it. No shadows.
///
/// On Home these tiles are a CONTENT SWITCHER, not navigation: when
/// [onActionSelected] is supplied the tile reports the tapped [HomeAction] and
/// the Home route swaps its in-page content. The legacy push behaviour is kept
/// only for standalone hosts/tests that do not provide a callback.
class HomeNavButtons extends StatelessWidget {
  const HomeNavButtons({
    super.key,
    this.searchContext,
    this.selectedAction,
    this.onActionSelected,
  });

  /// Phase 4A — the traveller's travel context (mood, city, country, airport,
  /// budget) handed to the search surface the tile opens. Null keeps the
  /// previous behaviour (an empty search form).
  final SearchContext? searchContext;

  /// The action whose content is currently displayed inside Home.
  final HomeAction? selectedAction;

  /// Switches the in-page Home content instead of pushing a route.
  final ValueChanged<HomeAction>? onActionSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = homeActionDefinitions(l10n);

    // Four equal, responsive tiles: `Expanded` shares whatever width the
    // screen leaves after the gutters, so the row never overflows and the
    // spacing stays balanced from 320pt phones up.
    return Row(
      children: <Widget>[
        for (int i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: HomeActionTile(
              definition: items[i],
              searchContext: searchContext,
              selected: selectedAction == items[i].action,
              onActionSelected: onActionSelected,
            ),
          ),
        ],
      ],
    );
  }
}

/// The Home bottom action bar.
///
/// The same [HomeActionTile] cards sit in a horizontal, lazily built
/// [ListView.builder] directly above the persistent AI composer. Card width is
/// fixed so the row extends naturally when a service is added, and a small
/// directional fade at the trailing edge hints that more actions are available
/// off-screen. It disappears once the row is scrolled to its end (or when the
/// row fits), so it never becomes permanent decoration.
class HomeActionBar extends StatefulWidget {
  const HomeActionBar({
    super.key,
    this.searchContext,
    this.selectedAction,
    this.onActionSelected,
    this.definitions,
  });

  /// Fixed tile width: square with [HomeActionTile.height], matching the
  /// original card proportions without shrinking the 88dp card.
  static const double cardWidth = HomeActionTile.height;

  /// Space between two cards.
  static const double gap = AppSpacing.sm;

  /// The travel context handed to a legacy (non-switching) destination.
  final SearchContext? searchContext;

  /// The action whose content is currently displayed inside Home.
  final HomeAction? selectedAction;

  /// Switches the in-page Home content instead of pushing a route.
  final ValueChanged<HomeAction>? onActionSelected;

  /// Optional override for tests and future hosts. Null uses the canonical
  /// [homeActionDefinitions].
  final List<HomeActionDefinition>? definitions;

  @override
  State<HomeActionBar> createState() => _HomeActionBarState();
}

class _HomeActionBarState extends State<HomeActionBar> {
  final ScrollController _controller = ScrollController();

  /// True while the row has more content past its trailing edge.
  bool _hasMoreAfter = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateOverflowHint);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateOverflowHint());
  }

  @override
  void dispose() {
    _controller.removeListener(_updateOverflowHint);
    _controller.dispose();
    super.dispose();
  }

  void _updateOverflowHint() {
    if (!mounted || !_controller.hasClients) return;
    final bool hasMore = _controller.position.extentAfter > 0.5;
    if (hasMore != _hasMoreAfter) {
      setState(() => _hasMoreAfter = hasMore);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final List<HomeActionDefinition> items =
        widget.definitions ?? homeActionDefinitions(l10n);
    final Color canvas = HomeDesignTokens.backgroundOf(context);

    // Re-evaluate the trailing cue after this layout too: a locale flip,
    // rotation or a definition change can alter the row's extent without a
    // scroll notification.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateOverflowHint());

    return SizedBox(
      height: HomeActionTile.height,
      child: Stack(
        children: <Widget>[
          ListView.builder(
            key: const ValueKey<String>('home-action-bar'),
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: items.length,
            itemBuilder: (BuildContext context, int index) {
              final HomeActionDefinition definition = items[index];
              return Padding(
                padding: EdgeInsetsDirectional.only(
                  end: index == items.length - 1 ? 0 : HomeActionBar.gap,
                ),
                child: SizedBox(
                  width: HomeActionBar.cardWidth,
                  child: HomeActionTile(
                    definition: definition,
                    searchContext: widget.searchContext,
                    selected: widget.selectedAction == definition.action,
                    onActionSelected: widget.onActionSelected,
                  ),
                ),
              );
            },
          ),
          // The "more actions" cue: a narrow fade in the canvas colour at the
          // trailing edge. It is purely visual and never intercepts a tap.
          if (_hasMoreAfter)
            PositionedDirectional(
              top: 0,
              bottom: 0,
              end: 0,
              width: 28,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey<String>('home-action-bar-overflow'),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: <Color>[canvas.withValues(alpha: 0), canvas],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One restrained service shortcut: an accent glyph and a clear, single-line
/// accent label, centred in the spec's bordered tile. The selected tile gets
/// an accent-tinted surface and a 2dp accent frame so the active service is
/// unmistakable without changing the dashboard's colour language.
class HomeActionTile extends StatefulWidget {
  const HomeActionTile({
    super.key,
    required this.definition,
    this.searchContext,
    this.selected = false,
    this.onActionSelected,
  });

  /// The spec's tile height.
  static const double height = 88;

  /// Glyph size from the spec.
  static const double iconSize = 25;

  /// Gap between the glyph and its label.
  static const double iconLabelGap = 6;

  /// Label size from the spec (weight w600 comes from `captionSemibold`).
  static const double labelSize = 12;

  final HomeActionDefinition definition;

  /// Phase 4A — the travel context handed to the search surface this tile
  /// opens (null = an empty search form).
  final SearchContext? searchContext;

  /// True when this tile's service content is displayed inside Home.
  final bool selected;

  /// When non-null, tapping switches Home content instead of navigating.
  final ValueChanged<HomeAction>? onActionSelected;

  @override
  State<HomeActionTile> createState() => _HomeActionTileState();
}

class _HomeActionTileState extends State<HomeActionTile> {
  bool _pressed = false;

  void _tapDown(TapDownDetails _) => setState(() => _pressed = true);

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final accent = HomeDesignTokens.accentOf(context);
    final selected = widget.selected;
    final definition = widget.definition;

    return Semantics(
      button: true,
      selected: selected,
      label: definition.label,
      child: GestureDetector(
        key: ValueKey<String>('home-action-${definition.action.id}'),
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
            height: HomeActionTile.height,
            decoration: BoxDecoration(
              color: _pressed
                  ? HomeDesignTokens.pressedSurfaceOf(context)
                  : selected
                  ? accent.withValues(alpha: 0.08)
                  : HomeDesignTokens.surfaceOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? accent : HomeDesignTokens.borderOf(context),
                width: selected ? 2 : 1,
              ),
              // The spec's tiles carry no elevation.
              boxShadow: const <BoxShadow>[],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  definition.icon,
                  size: HomeActionTile.iconSize,
                  color: accent,
                ),
                const SizedBox(height: HomeActionTile.iconLabelGap),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: ExcludeSemantics(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        definition.label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: typography.captionSemibold.copyWith(
                          fontSize: HomeActionTile.labelSize,
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
    final onActionSelected = widget.onActionSelected;
    if (onActionSelected != null) {
      onActionSelected(widget.definition.action);
      return;
    }
    context.push(
      widget.definition.path,
      extra: widget.searchContext == null
          ? null
          : <String, dynamic>{'context': widget.searchContext!.toMap()},
    );
  }
}
