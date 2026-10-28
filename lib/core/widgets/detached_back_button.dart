import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/widgets/app_back_button.dart';
import 'package:tokigo/core/widgets/app_icon_action.dart';

/// One UI 8.5 navigation: one back control that travels with the page.
///
/// Wrap a page body whose header was built with `showBackButton: false`. At rest
/// the control renders as the bare chevron inside the header's reserved row —
/// geometrically identical to a header-drawn button. Once the body scrolls past
/// [detachAfter] the very same instance becomes the floating One UI disc, pinned
/// to the top-start corner, so the user can always leave the page without
/// scrolling back up. Scroll up again and it re-unifies with the header.
///
/// There is deliberately exactly ONE [AppBackButton] in the tree: the back
/// contract (a single visible control, `pop`, system back, edge swipe) does not
/// depend on the scroll state.
class DetachedBackButton extends StatefulWidget {
  const DetachedBackButton({
    super.key,
    required this.child,
    this.detachAfter = AppSpacing.xxxl,
  });

  /// The page body — it must contain the scrollable whose notifications drive
  /// the detach.
  final Widget child;

  /// Scroll offset (px) past which the control leaves the header. The default
  /// clears the 48px control row, so the swap happens as that row scrolls away.
  final double detachAfter;

  @override
  State<DetachedBackButton> createState() => _DetachedBackButtonState();
}

class _DetachedBackButtonState extends State<DetachedBackButton> {
  bool _detached = false;

  bool _onScroll(ScrollNotification notification) {
    final bool detached = notification.metrics.pixels > widget.detachAfter;
    if (detached != _detached) setState(() => _detached = detached);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: <Widget>[
          widget.child,
          PositionedDirectional(
            start: AppSpacing.lg,
            top: AppSpacing.sm,
            child: AppBackButton(
              variant: _detached
                  ? AppIconActionVariant.disc
                  : AppIconActionVariant.bare,
            ),
          ),
        ],
      ),
    );
  }
}
