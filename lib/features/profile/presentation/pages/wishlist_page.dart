import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:wetravellers/core/theme/app_colors.dart';
import 'package:wetravellers/core/theme/app_radius.dart';
import 'package:wetravellers/core/theme/app_spacing.dart';
import 'package:wetravellers/core/theme/app_typography.dart';
import 'package:wetravellers/l10n/app_localizations.dart';

/// Wishlist — saved offers collected via the card favorite toggles.
///
/// v1 surface with mock entries; persistence wiring arrives with the
/// favorites-service phase.
class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  static const List<_WishItem> _items = <_WishItem>[
    _WishItem(
      title: 'Nile cruise, 4 nights',
      subtitle: 'Luxor → Aswan • Egypt',
      price: 420,
      image: 'assets/images/package.png',
    ),
    _WishItem(
      title: 'Red Sea resort',
      subtitle: 'Hurghada • Egypt',
      price: 180,
      image: 'assets/images/hotel.png',
    ),
    _WishItem(
      title: 'Cairo → Dubai flight',
      subtitle: 'Direct • Economy',
      price: 320,
      image: 'assets/images/flight.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                    tooltip: l10n.back,
                  ),
                  Text(
                    l10n.wishlist,
                    style: typography.title.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Nothing saved yet',
                            style: typography.bodyLargeMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: _items.length,
                      itemBuilder: (context, index) =>
                          _WishTile(item: _items[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishTile extends StatelessWidget {
  const _WishTile({required this.item});

  final _WishItem item;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.asset(
                item.image,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 64,
                  height: 64,
                  color: AppColors.surfaceTertiary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    style: typography.bodyLargeMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    item.subtitle,
                    style: typography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '\$${item.price}',
                  style: typography.bodyLargeMedium.copyWith(
                    color: AppColors.brand,
                  ),
                ),
                const Icon(
                  Icons.favorite_rounded,
                  size: 18,
                  color: AppColors.danger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _WishItem {
  const _WishItem({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.image,
  });

  final String title;
  final String subtitle;
  final double price;
  final String image;
}
