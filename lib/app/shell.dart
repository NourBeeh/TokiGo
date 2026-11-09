import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:tokigo/app/widgets/app_chrome.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';

/// The unified application shell.
///
/// The six top-level sections share a persistent chrome: the TokiGo row with
/// notifications + profile, the service navigation bar, and the AI composer
/// directly beneath it. The routed page itself swaps inside the content area
/// beneath that chrome, with no page title and no back control — the
/// navigation bar is the only way back.
///
/// Detail / booking / profile routes keep their own header and back control:
/// the chrome is hidden for every location outside [AppChrome.sectionLocations].
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
    // drop its own header.
    final Widget content = AppChromeScope(
      visible: chromeVisible,
      child: navigationShell,
    );

    return Scaffold(
      backgroundColor: chromeVisible
          ? HomeDesignTokens.backgroundOf(context)
          : null,
      body: Column(
        children: <Widget>[
          if (chromeVisible)
            SafeArea(
              bottom: false,
              child: AppChrome(location: location),
            ),
          Expanded(
            // The chrome consumed the status-bar inset for the whole
            // column; section pages must not add it a second time.
            //
            // `Builder` matters here: `MediaQuery.removePadding` reads the
            // MediaQuery of the context it is given. Using the shell's own
            // context (ABOVE the Scaffold) would re-apply the keyboard
            // inset that the Scaffold already removed from its body — and
            // every bottom sheet opened from a section would then pad for
            // the keyboard a second time, leaving a large empty (dark)
            // band above it.
            child: Builder(
              builder: (BuildContext bodyContext) =>
                  MediaQuery.removePadding(
                    context: bodyContext,
                    removeTop: chromeVisible,
                    child: content,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
