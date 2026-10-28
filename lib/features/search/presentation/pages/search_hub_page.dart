import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/navigation/app_route.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/page_header.dart';
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: AiEntranceAnimation(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(child: AppPageHeader(title: l10n.navSearch)),
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
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.searchPromptTitle,
            style: typography.headline.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.searchPromptSubtitle,
            style: typography.body.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
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
                icon: Icons.hotel_rounded,
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
      child: Material(
        color: Colors.white,
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
                const Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: AppColors.brand,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.searchHint,
                    style: typography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.brandContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.brand,
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
    return InkWell(
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
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 22, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: typography.captionSemibold.copyWith(color: Colors.white),
            ),
          ],
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
            color: AppColors.textPrimary,
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
              color: AppColors.flightHue,
              colorContainer: AppColors.flightContainer,
              onTap: () => context.go(AppRoute.flights.path),
            ),
            _ServiceTile(
              label: l10n.searchHotels,
              icon: Icons.hotel_rounded,
              color: AppColors.hotelHue,
              colorContainer: AppColors.hotelContainer,
              onTap: () => context.go(AppRoute.hotels.path),
            ),
            _ServiceTile(
              label: l10n.searchCars,
              icon: Icons.directions_car_rounded,
              color: AppColors.carHue,
              colorContainer: AppColors.carContainer,
              onTap: () => context.go(AppRoute.cars.path),
            ),
            _ServiceTile(
              label: l10n.searchPackages,
              icon: Icons.card_travel_rounded,
              color: AppColors.packageHue,
              colorContainer: AppColors.packageContainer,
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
    required this.color,
    required this.colorContainer,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color colorContainer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const Spacer(),
              Text(
                label,
                style: typography.bodyLargeMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
