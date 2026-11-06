import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/features/home/domain/home_action.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/features/home/presentation/widgets/home_top_bar.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Tells the routed pages whether the persistent app chrome is on screen.
///
/// The shell renders the wordmark / notifications / profile row and the
/// service navigation bar above the six top-level sections only. Pages read
/// this scope to drop their own redundant header (back button + description)
/// and to reserve room for the floating AI composer.
@immutable
class AppChromeScope extends InheritedWidget {
  const AppChromeScope({
    super.key,
    required this.visible,
    required super.child,
  });

  /// True while the shell chrome (and its AI composer) is displayed.
  final bool visible;

  /// Whether the current page renders under the persistent shell chrome.
  static bool visibleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppChromeScope>()?.visible ??
      false;

  @override
  bool updateShouldNotify(AppChromeScope oldWidget) =>
      oldWidget.visible != visible;
}

/// The persistent top chrome: the TokiGo row (wordmark, notifications,
/// profile) with the service navigation bar beneath it.
///
/// It is rendered by [TokiGoShell] for the six top-level sections
/// ([sectionLocations]) and is intentionally absent from detail, booking and
/// profile pages, which keep their own back-navigable header.
class AppChrome extends StatelessWidget {
  const AppChrome({super.key, required this.location});

  /// Every location that belongs to the six top-level sections.
  static const Set<String> sectionLocations = <String>{
    '/',
    '/flights',
    '/hotels',
    '/cars',
    '/packages',
    '/groups',
  };

  /// Height of the floating AI composer pill (spec: 56dp).
  static const double composerHeight = 56;

  /// Gap between the pill and the bottom edge of the screen.
  static const double composerBottomMargin = AppSpacing.md;

  /// Motion for hiding / revealing the composer with the scroll direction.
  static const Duration composerTransition = Duration(milliseconds: 220);

  /// Space a routed scroll view must reserve so its last card is never hidden
  /// behind the floating composer.
  static double composerReserve(BuildContext context) =>
      composerHeight +
      composerBottomMargin +
      MediaQuery.paddingOf(context).bottom;

  /// Whether [location] is one of the six sections that own the chrome.
  static bool isSection(String location) => sectionLocations.contains(location);

  /// The current router location, used to mark the active navigation tile.
  final String location;

  HomeActionDefinition _today(AppLocalizations l10n) => HomeActionDefinition(
    action: HomeAction.today,
    label: l10n.homeNavToday,
    icon: Icons.home_rounded,
    path: '/',
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final List<HomeActionDefinition> definitions = <HomeActionDefinition>[
      _today(l10n),
      ...homeActionDefinitions(l10n),
    ];
    final Map<HomeAction, String> paths = <HomeAction, String>{
      for (final HomeActionDefinition definition in definitions)
        definition.action: definition.path,
    };

    return ColoredBox(
      color: HomeDesignTokens.backgroundOf(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              0,
            ),
            child: HomeTopBar(),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: HomeActionBar(
              definitions: definitions,
              selectedAction: HomeAction.fromPath(location),
              // Navigation, not in-page switching: `go` replaces the branch
              // location, so tapping the ACTIVE tile is naturally a no-op and
              // never stacks a duplicate page.
              onActionSelected: (HomeAction action) {
                final String? path = paths[action];
                if (path == null || path == location) return;
                context.go(path);
              },
            ),
          ),
        ],
      ),
    );
  }
}
