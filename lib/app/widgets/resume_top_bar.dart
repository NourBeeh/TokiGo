import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/app/providers/resume_providers.dart';
import 'package:tokigo/app/widgets/home_nav_buttons.dart';
import 'package:tokigo/core/navigation/resume_destination.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/features/home/domain/home_action.dart';
import 'package:tokigo/features/home/presentation/home_design_tokens.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The pinned top bar shown while Home is disabled: the quick-action row plus
/// the resume button, so every service stays one tap away.
///
/// It is the Home top area extracted for the service pages — the same
/// tiles, the same fixed size, no scroll-driven changes.
class ResumeTopBar extends ConsumerWidget {
  const ResumeTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ColoredBox(
      color: HomeDesignTokens.backgroundOf(context),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: HomeActionBar(
                  onActionSelected: (HomeAction action) =>
                      _openAction(context, action),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const ResumeButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Top-level destinations replace the current page: the resume target is a
  /// root, not a pushed detail, so Back from it exits the app instead of
  /// looping back onto itself.
  void _openAction(BuildContext context, HomeAction action) {
    final String path = switch (action) {
      HomeAction.flights => '/flights',
      HomeAction.hotels => '/hotels',
      HomeAction.cars => '/cars',
      HomeAction.activities => '/packages',
      HomeAction.groups => '/groups',
      HomeAction.trips => '/bag',
    };
    context.go(path);
  }
}

/// The pinned "resume" button — Home's replacement.
///
/// Shows the last visited browse section and returns to it. It is selected
/// while the traveller is already on that section. Same fixed 68dp tile, same
/// ink accent, no red in light mode and no scroll-driven size change.
class ResumeButton extends ConsumerWidget {
  const ResumeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String? destination = ref.watch(resumeDestinationProvider);
    final String current = ref.watch(currentLocationProvider);
    final String path =
        destination != null && isSavableResumeLocation(destination)
        ? destination
        : kDefaultResumePath;
    final ResumeDestinationVisual visual = ResumeDestinationVisual.forPath(
      path,
      l10n,
    );
    final Color accent = HomeDesignTokens.accentOf(context);
    final bool selected = path == current;

    return Semantics(
      button: true,
      selected: selected,
      label: visual.label,
      child: GestureDetector(
        key: const ValueKey<String>('home-resume-button'),
        onTap: () => context.go(path),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: HomeActionTile.height,
          width: HomeActionTile.height,
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.08)
                : HomeDesignTokens.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : HomeDesignTokens.borderOf(context),
              width: selected ? 2 : 1,
            ),
            boxShadow: const <BoxShadow>[],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(visual.icon, size: HomeActionTile.iconSize, color: accent),
              const SizedBox(height: HomeActionTile.iconLabelGap),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                ),
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      visual.label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: AppTypography.forLight().captionSemibold.copyWith(
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
    );
  }
}
