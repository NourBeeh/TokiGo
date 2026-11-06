import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:tokigo/app/widgets/app_chrome.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/features/home/presentation/widgets/home_ai_search_field.dart';

/// The unified application shell.
///
/// The six top-level sections share a persistent chrome: the TokiGo row with
/// notifications + profile, and the service navigation bar. The routed page
/// itself swaps inside the content area beneath that chrome, with no page
/// title and no back control — the navigation bar is the only way back.
///
/// Detail / booking / profile routes keep their own header and back control:
/// the chrome is hidden for every location outside [AppChrome.sectionLocations].
///
/// The floating AI composer is available on all six sections and stays put —
/// it never hides on scroll.
class TokiGoShell extends StatelessWidget {
  const TokiGoShell({
    super.key,
    required this.navigationShell,
    required this.location,
  });

  final StatefulNavigationShell navigationShell;

  /// The current router location (e.g. `/`, `/flights`, `/booking/review`).
  final String location;

  @override
  Widget build(BuildContext context) {
    final bool chromeVisible = AppChrome.isSection(location);

    // The scope is above the branch navigator so every routed section page can
    // drop its own header and reserve the composer's footprint.
    final Widget content = AppChromeScope(
      visible: chromeVisible,
      child: navigationShell,
    );

    return Scaffold(
      backgroundColor: chromeVisible
          ? HomeDesignTokens.backgroundOf(context)
          : null,
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              if (chromeVisible)
                SafeArea(
                  bottom: false,
                  child: AppChrome(location: location),
                ),
              Expanded(
                // The chrome consumed the status-bar inset for the whole
                // column; section pages must not add it a second time.
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: chromeVisible,
                  child: content,
                ),
              ),
            ],
          ),
          if (chromeVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppChrome.composerBottomMargin +
                      MediaQuery.paddingOf(context).bottom,
                ),
                child: HomeAiSearchField(
                  accentColor: HomeDesignTokens.accentOf(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
