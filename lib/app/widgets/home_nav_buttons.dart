import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_radius.dart';
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
/// Order is intentional: Flights, Hotels (labelled "Stays"), Cars, Packages.
///
/// **OWNER DECISION (2026-11):** the Trips tile is gone from the quick-action
/// bar — My Trips stays reachable from Profile (and the Bag route), so the row
/// is no longer the only way in. [HomeAction.trips] and its in-page branch are
/// deliberately KEPT: removing them would break the selected-state persistence
/// and the existing `home-trips-content` contract for no gain.
List<HomeActionDefinition> homeActionDefinitions(AppLocalizations l10n) {
  return <HomeActionDefinition>[
    HomeActionDefinition(
      action: HomeAction.flights,
      label: l10n.searchFlights,
      icon: Icons.flight_rounded,
      path: '/flights',
    ),
    HomeActionDefinition(
      action: HomeAction.hotels,
      label: l10n.searchHotels,
      icon: Icons.home_rounded,
      path: '/hotels',
    ),
    HomeActionDefinition(
      action: HomeAction.cars,
      label: l10n.searchCars,
      icon: Icons.directions_car_rounded,
      path: '/cars',
    ),
    HomeActionDefinition(
      action: HomeAction.activities,
      label: l10n.homeNavActivities,
      icon: Icons.beach_access_rounded,
      path: '/packages',
    ),
  ];
}

/// The one glyph recipe shared by every Home service surface.
///
/// Owner follow-up (2026-11-27): the parasol is restored **only** on the
/// Activities/Packages quick-action tile. Every other surface (launcher,
/// splash, AI avatar, the in-app wordmark) keeps the white TokiGo brand with
/// no parasol, so the two assets live in separate files and cannot drift.
///
/// The parasol is an in-app asset with transparent adaptive safe-zone padding;
/// drawing it at [HomeActionTile.iconSlotHeight] makes its visible mark match
/// the enlarged Material icons beside it. Material glyphs share the slot's
/// baseline so labels on a row of four tiles stay aligned.
///
/// Onboarding renders this same widget from [homeActionDefinitions], so the
/// first screen a traveller sees cannot drift from the Home buttons.
class HomeActionGlyph extends StatelessWidget {
  const HomeActionGlyph({
    super.key,
    required this.definition,
    required this.color,
    this.slotHeight = HomeActionTile.iconSlotHeight,
    this.glyphSize = HomeActionTile.iconSize,
  });

  /// Parasol asset used **only** by the Activities/Packages quick action.
  ///
  /// Kept in dedicated files so restoring the mascot here cannot put it back
  /// on the splash, launcher or AI avatar (those use the white wordmark).
  static String parasolAsset(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? 'assets/icon/packages_parasol_dark_1024.png'
      : 'assets/icon/packages_parasol_1024.png';

  final HomeActionDefinition definition;
  final Color color;
  final double slotHeight;
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: slotHeight,
      child: definition.action == HomeAction.activities
          ? Image.asset(
              parasolAsset(context),
              width: slotHeight,
              height: slotHeight,
              fit: BoxFit.contain,
            )
          : Align(
              // Bottom-align the shorter Material glyph with the parasol's
              // baseline: labels then share one row.
              alignment: Alignment.bottomCenter,
              child: Icon(definition.icon, size: glyphSize, color: color),
            ),
    );
  }
}

/// Home shortcuts for travel services — the owner's spec: a horizontal row of
/// equal white tiles (Flights, Stays, Cars, Packages), each a 68dp white tile
/// with 18dp corners ([AppRadius.lg]), a hairline border, a 28px accent glyph
/// (the parasol for Packages, by owner exception) and a 12/600 accent label
/// 4dp below it ([AppSpacing.xs]). No shadows.
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
          if (i > 0) const SizedBox(width: AppSpacing.lg),
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
/// The same [HomeActionTile] cards sit in a single, centred row directly
/// above the persistent AI composer. The four cards keep equal widths and
/// equal gaps, with matching outer space on both sides. On narrow screens the
/// cards shrink evenly rather than overflowing the viewport.
class HomeActionBar extends StatelessWidget {
  const HomeActionBar({
    super.key,
    this.searchContext,
    this.selectedAction,
    this.onActionSelected,
    this.definitions,
  });

  /// Maximum tile width: square with [HomeActionTile.height], matching the
  /// tile's own proportions. The row may shrink tiles evenly on narrow screens.
  static const double cardWidth = HomeActionTile.height;

  /// Equal space between adjacent cards.
  static const double gap = AppSpacing.lg;

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final List<HomeActionDefinition> items =
        definitions ?? homeActionDefinitions(l10n);

    return SizedBox(
      height: HomeActionTile.height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double availableTileWidth =
              (constraints.maxWidth - HomeActionBar.gap * (items.length - 1)) /
              items.length;
          final double tileWidth = availableTileWidth
              .clamp(0.0, HomeActionBar.cardWidth)
              .toDouble();
          return Row(
            key: const ValueKey<String>('home-action-bar'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int index = 0; index < items.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: HomeActionBar.gap),
                SizedBox(
                  width: tileWidth,
                  child: HomeActionTile(
                    definition: items[index],
                    searchContext: searchContext,
                    selected: selectedAction == items[index].action,
                    onActionSelected: onActionSelected,
                  ),
                ),
              ],
            ],
          );
        },
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

  /// The tile height. Compact by design (23% shorter than the original 88dp
  /// card) while staying far above the 44dp minimum tap target.
  static const double height = 68;

  /// Glyph size — enlarged to 28px by owner request (2026-11-27).
  static const double iconSize = 28;

  /// Every tile reserves the same glyph slot. The parasol is drawn at 42dp
  /// (28 × 1.5); Material glyphs keep their 28dp size and sit on the slot's
  /// baseline so all four labels share one row.
  static const double iconSlotHeight = iconSize * 1.5;

  /// Gap between the glyph and its label.
  static const double iconLabelGap = AppSpacing.xs;

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
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();
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
              borderRadius: AppRadius.lgBorder,
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
                HomeActionGlyph(definition: definition, color: accent),
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
