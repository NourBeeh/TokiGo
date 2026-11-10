import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/navigation/app_route.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/core/widgets/pressable.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Unified search hub — the "known destination" tab.
///
/// Hosts the hero card (greeting, prompt and search entry) followed by
/// direct entries into every vertical's search form.
class SearchHubPage extends StatelessWidget {
  const SearchHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.tokigoColors.background,
      body: SafeArea(
        // `bottom: false` left the list's last row under the Android
        // navigation bar (the pill it was written for is gone).
        child: AiEntranceAnimation(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(child: AppPageHeader(subtitle: l10n.searchPromptSubtitle)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _SearchHero(),
                      const SizedBox(height: AppSpacing.lg),
                      _ServiceGrid(l10n: l10n),
                    ],
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

/// The premium hero card — greeting, search prompt and quick service links.
class _SearchHero extends StatelessWidget {
  const _SearchHero();

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        // Owner decision (2026-11): the hero follows Home's neutral surface
        // language — a white card with a hairline border, not a brand-blue
        // block — so the search surface reads as the same calm, content-first
        // dashboard as Home.
        color: context.tokigoColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: context.tokigoColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.searchPromptTitle,
            style: typography.headline.copyWith(
              color: context.tokigoColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.searchPromptSubtitle,
            style: typography.body.copyWith(
              color: context.tokigoColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _HeroSearchField(onTap: () => context.go(AppRoute.flights.path)),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _HeroQuickLink(
                icon: Icons.flight_takeoff_rounded,
                label: l10n.searchFlights,
                onTap: () => context.go(AppRoute.flights.path),
              ),
              _HeroQuickLink(
                icon: Icons.house_rounded,
                label: l10n.searchHotels,
                onTap: () => context.go(AppRoute.hotels.path),
              ),
              _HeroQuickLink(
                icon: Icons.directions_car_rounded,
                label: l10n.searchCars,
                onTap: () => context.go(AppRoute.cars.path),
              ),
              _HeroQuickLink(
                icon: Icons.card_travel_rounded,
                label: l10n.searchPackages,
                onTap: () => context.go(AppRoute.packages.path),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroSearchField extends StatelessWidget {
  const _HeroSearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      button: true,
      label: l10n.searchHint,
      child: Pressable.wrap(
        child: Material(
          // An inset well on the white hero card, so the field reads as an
          // input rather than a second white card.
          color: context.tokigoColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: context.tokigoColors.textPrimary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.searchHint,
                    style: typography.bodyLarge.copyWith(
                      color: context.tokigoColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.tokigoColors.surfaceTertiary,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: context.tokigoColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _HeroQuickLink extends StatelessWidget {
  const _HeroQuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Pressable.wrap(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.tokigoColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                icon,
                size: 22,
                color: context.tokigoColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: typography.captionSemibold.copyWith(
                color: context.tokigoColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.searchAllServices,
          style: AppTypography.forLight().title.copyWith(
            color: context.tokigoColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.55,
          children: <Widget>[
            _ServiceTile(
              label: l10n.searchFlights,
              icon: Icons.flight_takeoff_rounded,
              onTap: () => context.go(AppRoute.flights.path),
            ),
            _ServiceTile(
              label: l10n.searchHotels,
              icon: Icons.house_rounded,
              onTap: () => context.go(AppRoute.hotels.path),
            ),
            _ServiceTile(
              label: l10n.searchCars,
              icon: Icons.directions_car_rounded,
              onTap: () => context.go(AppRoute.cars.path),
            ),
            _ServiceTile(
              label: l10n.searchPackages,
              icon: Icons.card_travel_rounded,
              onTap: () => context.go(AppRoute.packages.path),
            ),
          ],
        ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();

    return Pressable.wrap(
      child: Material(
        color: context.tokigoColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: context.tokigoColors.outline),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    // Owner decision (2026-11): the service tiles use Home's
                    // neutral quick-action language — a grey well with an ink
                    // glyph — instead of the retired per-vertical hues.
                    color: context.tokigoColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: context.tokigoColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  label,
                  style: typography.bodyLargeMedium.copyWith(
                    color: context.tokigoColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
