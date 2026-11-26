import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/ui/app_wordmark.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Home's header row: the Toki Go wordmark, the notifications bell and the
/// profile avatar.
///
/// The bell and the avatar are the only notifications/profile affordances on a
/// browse page, so a second copy (or a missing one) is a regression.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Reserve space for the 32pt parasol mark, its gap, the wordmark,
        // notification action and profile avatar on narrow phones.
        final double wordmarkWidth = (constraints.maxWidth - 150).clamp(
          0.0,
          172.0,
        );

        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            textDirection: TextDirection.ltr,
            children: <Widget>[
              // One semantics node saying "TokiGo" — the two halves are one word.
              Semantics(
                label: 'TokiGo',
                container: true,
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Image.asset(
                        context.isDark
                            ? 'assets/icon/app_icon_adaptive_dark_foreground_1024.png'
                            : 'assets/icon/app_icon_adaptive_foreground_1024.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: wordmarkWidth,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: AppWordmark(
                            base: typography.title,
                            inkColor: context.tokigoColors.textPrimary,
                            goColor: context.tokigoColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              AnimatedNotificationBell(
                normalColor: context.tokigoColors.textPrimary,
                onTap: () => context.push('/notifications'),
              ),
              const _HomeAvatar(),
            ],
          ),
        );
      },
    );
  }
}

/// Profile destination as a fixed person glyph.
///
/// Intentionally static: the chrome looks the SAME whether or not the
/// traveller is signed in, so the only profile affordance never changes
/// shape (and a signed-in photo never leaks into the header).
class _HomeAvatar extends StatelessWidget {
  const _HomeAvatar();

  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      button: true,
      label: l10n.profile,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(size / 2),
        child: Pressable(
          onTap: () => context.push('/profile'),
          child: ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: Container(
                decoration: BoxDecoration(
                  color: context.tokigoColors.surfaceSecondary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.tokigoColors.hairlineStrong,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.person_rounded,
                  size: 22,
                  color: context.tokigoColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
