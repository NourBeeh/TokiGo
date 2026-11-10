import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/features/notifications/domain/app_notification.dart';
import 'package:tokigo/features/notifications/providers/notifications_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The Home title-bar bell, with a one-shot "new notification" response.
///
/// The animation is deliberately contained:
/// * a tiny rotational shake of the glyph (never the 42dp button);
/// * the outline bell lerps from its normal ink to translucent crimson;
/// * a filled bell glyph in the same 25dp box pulses inside that silhouette —
///   no background disc, no external glow, no size change;
/// * every value returns to zero when the controller completes, so the bell
///   ends exactly in its original colour.
///
/// It fires once per genuine arrival: the feed present at mount is the
/// baseline (opening Home or showing already-loaded entries never animates),
/// and only IDs that were not in that baseline count. Several new IDs in one
/// update still produce ONE animation. Reduced-motion users get the badge but
/// no movement.
class AnimatedNotificationBell extends ConsumerStatefulWidget {
  const AnimatedNotificationBell({
    super.key,
    required this.onTap,
    required this.normalColor,
    this.buttonSize = 42,
    this.iconSize = 25,
  });

  /// The accent used by the flash — the palette's `danger` role, so the bell
  /// never carries a colour the rest of the app does not own.
  static Color flashColorOf(BuildContext context) =>
      context.tokigoColors.danger;

  /// Opens the notifications surface.
  final VoidCallback onTap;

  /// The bell's resting colour (the surrounding bar's ink).
  final Color normalColor;

  /// Touch-target box. Fixed, so the badge and animation can never resize it.
  final double buttonSize;

  /// Glyph size. The flash uses the exact same box.
  final double iconSize;

  @override
  ConsumerState<AnimatedNotificationBell> createState() =>
      _AnimatedNotificationBellState();
}

class _AnimatedNotificationBellState
    extends ConsumerState<AnimatedNotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shake;
  late final Animation<double> _flash;

  /// Notification IDs observed since mount. This is the baseline that makes
  /// rebuilds, re-opens and unchanged refreshes silent.
  final Set<String> _seenIds = <String>{};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    );
    _shake = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0,
          end: -0.10,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: -0.10,
          end: 0.09,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.09,
          end: -0.06,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: -0.06,
          end: 0.035,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.035,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 2,
      ),
    ]).animate(_controller);
    _flash = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: 1),
        weight: 2,
      ),
      TweenSequenceItem<double>(tween: ConstantTween<double>(1), weight: 2),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 0),
        weight: 6,
      ),
    ]).animate(_controller);

    // Anything already in the feed is history, not news.
    _seenIds.addAll(
      ref
          .read(notificationsProvider)
          .map((AppNotification notification) => notification.id),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleFeed(List<AppNotification> feed) {
    final Set<String> currentIds = feed
        .map((AppNotification notification) => notification.id)
        .toSet();
    final bool hasNew = currentIds.any((String id) => !_seenIds.contains(id));
    // Retain every id ever seen: a re-delivery of an old event is not news.
    _seenIds.addAll(currentIds);
    if (!hasNew || !mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    // A burst of arrivals must not restart the single controller mid-flight.
    if (_controller.isAnimating) return;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<AppNotification>>(notificationsProvider, (
      _,
      List<AppNotification> next,
    ) {
      _handleFeed(next);
    });
    final int unread = ref.watch(unreadNotificationCountProvider);
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      button: true,
      label: l10n.notifications,
      value: unread > 0 ? '$unread' : null,
      child: Material(
        color: Colors.transparent,
        child: Pressable(
          key: const ValueKey<String>('home-notification-bell'),
          onTap: widget.onTap,
          child: SizedBox(
            width: widget.buttonSize,
            height: widget.buttonSize,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget? child) {
                    final double flash = _flash.value;
                    final Color glyphColor = Color.lerp(
                      widget.normalColor,
                      AnimatedNotificationBell.flashColorOf(context).withValues(
                        alpha: 0.88,
                      ),
                      flash,
                    )!;
                    return Transform.rotate(
                      angle: _shake.value,
                      child: SizedBox(
                        width: widget.iconSize,
                        height: widget.iconSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Icon(
                              Icons.notifications_none_rounded,
                              size: widget.iconSize,
                              color: glyphColor,
                            ),
                            // The flash is a FILLED bell glyph in the same box:
                            // it is clipped by its own silhouette, never a
                            // glow or a background circle.
                            Opacity(
                              key: const ValueKey<String>(
                                'notification-bell-flash',
                              ),
                              opacity: flash * 0.55,
                              child: Icon(
                                Icons.notifications_rounded,
                                size: widget.iconSize,
                                color: AnimatedNotificationBell.flashColorOf(
                                  context,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (unread > 0)
                  PositionedDirectional(
                    top: 5,
                    end: 5,
                    // The count is already announced as the button's value.
                    child: ExcludeSemantics(child: _UnreadBadge(count: unread)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact count pinned inside the button's existing 42dp box.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('home-notification-badge'),
      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AnimatedNotificationBell.flashColorOf(context),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        maxLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
