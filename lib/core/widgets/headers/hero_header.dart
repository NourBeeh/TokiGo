import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/ui/app_wordmark.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/core/widgets/cards/card_image.dart';
import 'package:go_router/go_router.dart';
import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/features/search/domain/search_context.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Hero geometry for hero headers, matching the existing [AppHeroMetrics]
/// from [hero_sheet.dart] but scoped to the header layer.
abstract final class AppHeroMetrics {
  /// Full viewport fraction for hero height (tablet & wide phones).
  static const double fraction = 0.52;

  /// Compact fraction for phones narrower than [compactBreakpoint].
  static const double compactFraction = 0.44;

  /// Below this width the hero uses [compactFraction]. 480pt covers every
  /// phone in portrait; tablets keep the reference proportion.
  static const double compactBreakpoint = 480;

  static double heightFor(Size viewport) =>
      viewport.height * (viewport.width < compactBreakpoint ? compactFraction : fraction);
}

/// Premium hero header for the home screen.
///
/// Features a full-bleed hero image with a scrim overlay, a prominent
/// "price-hero" headline, and an embedded search field. The design follows
/// the "quiet premium" aesthetic: pure white canvas, crisp black typography,
/// and subtle hairline separation.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    this.title,
    this.subtitle,
    this.onSearch,
    this.searchContext,
    this.imageUrl,
    this.showActions = true,
  });

  /// Optional main title displayed in price-hero typography.
  final String? title;

  /// Optional subtitle displayed below the title.
  final String? subtitle;

  /// Called when the user initiates a search.
  final VoidCallback? onSearch;

  /// Context pre-filled into the search field (destination, country, airport).
  final SearchContext? searchContext;

  /// Optional hero image URL. If omitted, a placeholder gradient is shown.
  final String? imageUrl;

  /// Whether to show the trailing actions (bag, notifications, profile).
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    // Hero image: full-bleed or placeholder gradient
    final heroImage = imageUrl != null
        ? CardImage(
            url: imageUrl!,
            fit: BoxFit.cover,
            height: AppHeroMetrics.heightFor(MediaQuery.sizeOf(context)),
          )
        : _PlaceholderGradient(height: 280);

    // Search field embedded in the hero
    final searchField = _SearchField(
      onSearch: onSearch,
      context: searchContext,
      showClear: false,
    );

    return Card(
      color: context.tokigoColors.surface,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Hero image/gradient
          heroImage,

          // Scrim overlay for text legibility over images
          PositionedDirectional(
            bottom: 0,
            start: 0,
            end: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black12,
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),

          // Content positioned above the scrim
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Title in price-hero typography (40px, 800 weight)
                if (title != null) ...<Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title!,
                      style: typography.priceHero.copyWith(
                        color: context.tokigoColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                ],

                // Subtitle if provided
                if (subtitle != null) ...<Widget>[
                  Text(
                    subtitle!,
                    style: typography.body.copyWith(
                      color: context.tokigoColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                // Search field
                _SearchContainer(
                  child: searchField,
                ),

                // Actions (bag, notifications, profile) if enabled
                if (showActions) ...<Widget>[
                  const Spacer(),
                  _ActionRow(l10n: l10n),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder gradient when no hero image is provided.
class _PlaceholderGradient extends StatelessWidget {
  const _PlaceholderGradient({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.tokigoColors.surfaceSecondary,
    height: height,
    width: double.infinity,
    child: Center(
      // The placeholder is a brand surface too: it draws the real logotype
      // through [AppWordmark] instead of a one-colour "TokiGo" string, so the
      // mark can never drift from the splash asset.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: AppWordmark(base: AppTypography.forLight().priceHero),
      ),
    ),
  );
  }
}

/// Search field embedded in the hero header.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.onSearch,
    required this.context,
    this.showClear = true,
  });

  final VoidCallback? onSearch;
  final SearchContext? context;
  final bool showClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: context.tokigoColors.surface,
        border: Border.all(color: context.tokigoColors.hairline),
        borderRadius: AppRadius.mdBorder,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.tokigoColors.brand.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.sm, 0, AppSpacing.sm, 0),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.search_rounded,
              size: 20,
              color: context.tokigoColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  hintStyle: typography.body.copyWith(color: context.tokigoColors.textTertiary),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (_) => onSearch?.call(),
              ),
            ),
            if (showClear)
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: context.tokigoColors.textTertiary,
                ),
                onPressed: () {},
              ),
          ],
        ),
      ),
    );
  }
}

/// Container wrapper for the search field with consistent styling.
class _SearchContainer extends StatelessWidget {
  const _SearchContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.lg, AppSpacing.xs, 0, AppSpacing.xs),
    child: child,
  );
}

/// Trailing action buttons (bag, notifications, profile).
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[_TopActionButton(
        icon: Icons.luggage_outlined,
        label: l10n.bag,
        color: context.tokigoColors.brandRed,
        onTap: () => context.push('/bag'),
      ), const SizedBox(width: AppSpacing.md), _TopActionButton(
        icon: Icons.notifications_none_rounded,
        label: l10n.notifications,
        color: context.tokigoColors.textPrimary,
        onTap: () => context.push('/notifications'),
      ), const SizedBox(width: AppSpacing.md), _HomeAvatar(),],
    );
  }
}

/// Single top-action button style used in headers.
class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).brightness == Brightness.dark
        ? AppTypography.forDark()
        : AppTypography.forLight();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 20, color: color),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                style: typography.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profile destination as a circular avatar showing the user's photo (or a
/// person glyph when no photo is set).
class _HomeAvatar extends ConsumerWidget {
  const _HomeAvatar();

  static const double size = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);
    final avatarUrl = user?.avatarUrl?.trim() ?? '';
    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (user?.email.trim() ?? '');

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(size / 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(size / 2),
        onTap: () => context.push('/profile'),
        child: ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: avatarUrl.isNotEmpty
                ? CardImage(
                    url: avatarUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.person_outline_rounded,
                    semanticLabel: name,
                  )
                : Container(
                    color: context.tokigoColors.surfaceSecondary,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.person_rounded,
                      size: 24,
                      color: context.tokigoColors.textSecondary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
