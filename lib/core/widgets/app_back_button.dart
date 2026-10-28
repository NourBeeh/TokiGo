import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/widgets/app_icon_action.dart';

/// Consistent, localized back action for pages pushed onto the app router.
///
/// One glyph — `arrow_back_ios_new_rounded`, the thin One UI chevron, which
/// carries `matchTextDirection` and therefore mirrors itself in Arabic — and one
/// behaviour everywhere: `pop` when the route can pop, [fallbackLocation]
/// otherwise (home by default; a funnel's root for its step pages, so a deep
/// link still lands somewhere sensible).
///
/// Pass [AppIconActionVariant.disc] over photography, where a bare glyph would
/// disappear against a light image.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.variant = AppIconActionVariant.bare,
    this.color,
    this.fallbackLocation = '/',
    this.enabled = true,
  });

  /// Chrome role to render — see [AppIconActionVariant].
  final AppIconActionVariant variant;

  /// Optional ink override.
  final Color? color;

  /// Where a back press lands when the route cannot pop (no history to return
  /// to — a deep link, or a page entered with `go`).
  final String fallbackLocation;

  /// Whether leaving is currently allowed — see [AppIconAction.enabled].
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppIconAction(
      icon: Icons.arrow_back_ios_new_rounded,
      variant: variant,
      color: color,
      enabled: enabled,
      // The control now sits BESIDE the page title, so a floating "Back"
      // chip on hover would compete with the very title it introduces.
      // The semantic label stays — it is what a screen reader announces.
      showTooltip: false,
      // No press ripple: a circle bursting out of a bare chevron reads as a
      // second, unlabelled button rather than as feedback.
      splashEnabled: false,
      // Localized by Material — the app ships English and Arabic.
      semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
      onTap: () {
        // Router-first, since every product surface is a route. A widget test
        // (or a preview) that mounts the page under a bare Navigator still
        // gets working back behaviour instead of a crash.
        final GoRouter? router = GoRouter.maybeOf(context);
        if (router == null) {
          Navigator.of(context).maybePop();
          return;
        }
        if (router.canPop()) {
          router.pop();
        } else {
          router.go(fallbackLocation);
        }
      },
    );
  }
}
