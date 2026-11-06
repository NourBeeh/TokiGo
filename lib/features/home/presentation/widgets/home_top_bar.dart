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
        // 320pt phones are the narrowest target. The two 48pt actions and the
        // 56pt avatar take 104pt; give the wordmark only what is left and
        // scale it down rather than letting the row overflow.
        final double wordmarkWidth = (constraints.maxWidth - 112).clamp(
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
                  child: SizedBox(
                    width: wordmarkWidth,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: AppWordmark(base: typography.title),
                    ),
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
