import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:tokigo/app/widgets/app_chrome.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/features/home/presentation/widgets/home_ai_search_field.dart';

/// The unified application shell.
///
/// The six top-level sections share a persistent chrome (the TokiGo row with
/// notifications + profile, and the service navigation bar with a **Today**
/// tile). The routed page itself swaps inside the content area beneath that
/// chrome, with no page title and no back control — the navigation bar is the
/// only way back.
///
/// Detail / booking / profile routes keep their own header and back control:
/// the chrome is hidden for every location outside [AppChrome.sectionLocations].
///
/// The floating AI composer lives here too, because it is available on all six
/// sections. It hides while the user scrolls down and returns on the first
/// upward scroll (Facebook settings style), and it is always visible while the
/// keyboard is open so the field cannot slide away mid-typing.
class TokiGoShell extends StatefulWidget {
  const TokiGoShell({
    super.key,
    required this.navigationShell,
    required this.location,
  });

  final StatefulNavigationShell navigationShell;

  /// The current router location (e.g. `/`, `/flights`, `/booking/review`).
  final String location;

  @override
  State<TokiGoShell> createState() => _TokiGoShellState();
}

class _TokiGoShellState extends State<TokiGoShell> {
  /// Scroll distance (logical px) that flips the composer's visibility.
  ///
  /// A small threshold keeps trackpad jitter and scroll-bounce from making the
  /// pill flicker on every frame.
  static const double _composerScrollThreshold = 12;

  /// Travel accumulated in the current direction since the last state flip.
  double _scrollTravel = 0;

  /// True unless the user scrolled down with the intent to read.
  bool _composerVisible = true;

  bool get _chromeVisible => AppChrome.isSection(widget.location);

  @override
  void didUpdateWidget(covariant TokiGoShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      // Every section starts with its composer visible, and no stale scroll
      // direction carries over from the previous page.
      _scrollTravel = 0;
      _composerVisible = true;
    }
  }

  /// Hides the composer on downward scroll and reveals it on upward scroll.
  ///
  /// Horizontal carousels (the Home rails) also emit scroll notifications;
  /// they are ignored so swiping a card never moves the composer.
  bool _onScrollNotification(ScrollNotification notification) {
    if (!_chromeVisible) return false;
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is ScrollUpdateNotification) {
      final double delta = notification.scrollDelta ?? 0;
      if (delta == 0) return false;
      _scrollTravel += delta;
      if (_scrollTravel > _composerScrollThreshold && _composerVisible) {
        _scrollTravel = 0;
        setState(() => _composerVisible = false);
      } else if (_scrollTravel < -_composerScrollThreshold &&
          !_composerVisible) {
        _scrollTravel = 0;
        setState(() => _composerVisible = true);
      }
    } else if (notification is ScrollEndNotification) {
      // The top of a page is its resting state: never leave the composer
      // hidden there.
      if (notification.metrics.pixels <=
          notification.metrics.minScrollExtent) {
        _scrollTravel = 0;
        if (!_composerVisible) setState(() => _composerVisible = true);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool chromeVisible = _chromeVisible;
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bool showComposer = chromeVisible && (_composerVisible || keyboardOpen);

    // The scope is above the branch navigator so every routed section page can
    // drop its own header and reserve the composer's footprint.
    final Widget content = AppChromeScope(
      visible: chromeVisible,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: widget.navigationShell,
      ),
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
                  child: AppChrome(location: widget.location),
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
              child: IgnorePointer(
                key: const ValueKey<String>('shell-ai-composer'),
                ignoring: !showComposer,
                child: AnimatedSlide(
                  offset: showComposer
                      ? Offset.zero
                      : const Offset(0, 1.6),
                  duration: AppChrome.composerTransition,
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    key: const ValueKey<String>('shell-composer-opacity'),
                    opacity: showComposer ? 1 : 0,
                    duration: AppChrome.composerTransition,
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
                ),
              ),
            ),
        ],
      ),
    );
  }
}
