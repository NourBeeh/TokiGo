import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/cards/card_scrim_overlay.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Explore tab — the "still deciding" discovery surface.
///
/// Destinations carousel, today's deals, and curated collections rendered
/// with the shared card primitives. Mock content feeds the v1 surface.
class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  static const List<_Destination> _destinations = <_Destination>[
    _Destination('Sharm El Sheikh', 'Egypt', 'assets/images/destination.png'),
    _Destination('Luxor', 'Egypt', 'assets/images/destination.png'),
    _Destination('Hurghada', 'Egypt', 'assets/images/destination.png'),
    _Destination('Siwa Oasis', 'Egypt', 'assets/images/destination.png'),
    _Destination('Cairo', 'Egypt', 'assets/images/destination.png'),
    _Destination('Aswan', 'Egypt', 'assets/images/destination.png'),
  ];

  static const List<_Collection> _collections = <_Collection>[
    _Collection('Weekend escapes', Icons.beach_access_rounded, AppColors.flightHue),
    _Collection('Family adventures', Icons.family_restroom_rounded, AppColors.hotelHue),
    _Collection('Desert expeditions', Icons.landscape_rounded, AppColors.carHue),
    _Collection('Nile cruises', Icons.directions_boat_rounded, AppColors.packageHue),
  ];

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.exploreTitle,
                      style: typography.display.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.exploreSubtitle,
                      style: typography.body.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Popular destinations — horizontal carousel
            SliverToBoxAdapter(
              child: _SectionHeader(title: l10n.exploreDestinations),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.md),
                  itemCount: _destinations.length,
                  itemBuilder: (context, index) {
                    final destination = _destinations[index];
                    return _DestinationCard(
                      name: destination.name,
                      country: destination.country,
                      image: destination.image,
                    );
                  },
                ),
              ),
            ),
            // Today's deals
            SliverToBoxAdapter(
              child: _SectionHeader(title: l10n.exploreDeals),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.md),
                  itemCount: 4,
                  itemBuilder: (context, index) => _DealCard(
                    title: 'Sharm all-inclusive ${index + 3}★',
                    discountPercent: 20 + index * 5,
                  ),
                ),
              ),
            ),
            // Curated collections
            SliverToBoxAdapter(
              child: _SectionHeader(title: l10n.exploreCollections),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              sliver: SliverList.separated(
                itemCount: _collections.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final collection = _collections[index];
                  return _CollectionTile(
                    title: collection.title,
                    icon: collection.icon,
                    color: collection.color,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: typography.title.copyWith(color: AppColors.textPrimary),
            ),
          ),
          Text(
            AppLocalizations.of(context)!.viewAll,
            style: typography.captionSemibold.copyWith(
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.name,
    required this.country,
    required this.image,
  });

  final String name;
  final String country;
  final String image;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Container(
      width: 160,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            image,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceTertiary),
          ),
          CardScrimFooter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: typography.bodyLargeMedium.copyWith(
                      color: Colors.white,
                      fontWeight: AppTypography.weightBold,
                    ),
                  ),
                  Text(
                    country,
                    style: typography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.title, required this.discountPercent});

  final String title;
  final int discountPercent;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '-$discountPercent%',
              style: typography.captionSemibold.copyWith(
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: typography.bodyLargeMedium.copyWith(
              color: AppColors.onAccentContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  title,
                  style: typography.bodyLargeMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _Destination {
  const _Destination(this.name, this.country, this.image);

  final String name;
  final String country;
  final String image;
}

final class _Collection {
  const _Collection(this.title, this.icon, this.color);

  final String title;
  final IconData icon;
  final Color color;
}
