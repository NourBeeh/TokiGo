import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/features/profile/application/wishlist_controller.dart';
import 'package:tokigo/features/search/presentation/widgets/hotel_overlap_card.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Wishlist — the stays the traveller kept.
///
/// **OWNER DECISION (2026-10-19): no fabricated content.** v1 shipped three
/// hardcoded "saved" offers with invented prices (420 / 180 / 320) and images
/// that do not even exist in the bundle. Nothing is saved yet because nothing
/// can be saved yet — the list stays empty and says so, and the favourites
/// service fills it for real.
///
/// The page is DATA-driven ([items]) so the layout below is the real one the
/// moment a favourites service exists: the same card A the results page shows
/// (4:3 photo, −48 sheet, heart ⌀32), a `md` 12 gap between cards and the
/// count under the title.
///
/// Geometry (doc 23 §7):
/// * layout — a vertical list of card A, the very card the results page uses;
/// * gap — `md` 12;
/// * count — `caption` 13/400 under the title ("12 saved");
/// * remove — a heart toggle on the card itself (**no** swipe to dismiss);
/// * empty — a 48px `textTertiary` heart, a title, a body and an
///   "Explore stays" button.
class WishlistPage extends ConsumerWidget {
  const WishlistPage({
    super.key,
    this.items = const <HotelOffer>[],
    this.onRemove,
    this.embedded = false,
  });

  /// The saved stays. When empty, the page falls back to the traveller's own
  /// wishlist (the hearts they pressed on the products).
  final List<HotelOffer> items;

  /// Removes a saved stay when the heart is switched off.
  ///
  /// Null while nothing can be saved: the heart is then NOT rendered at all,
  /// because a control that saves nothing is a dead control.
  final ValueChanged<HotelOffer>? onRemove;

  /// Renders the list without its own scaffold/header inside another page.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // The traveller's own list: the hearts they pressed on the products. A
    // caller that injects the list keeps full control (and the heart only
    // renders when that caller can really remove).
    final bool useStore = items.isEmpty && onRemove == null;
    final List<HotelOffer> stays = useStore
        ? ref.watch(wishlistProvider)
        : items;
    final ValueChanged<HotelOffer>? remove =
        onRemove ??
        (useStore
            ? (HotelOffer offer) =>
                  ref.read(wishlistProvider.notifier).remove(offer)
            : null);
    // Doc 23 §0 — the page ends with `xxl` 32 plus the safe area.
    final double bottom = AppSpacing.xxl + MediaQuery.paddingOf(context).bottom;

    final Widget content = AiEntranceAnimation(
      child: CustomScrollView(
        slivers: <Widget>[
          if (!embedded)
            SliverToBoxAdapter(child: AppPageHeader(title: l10n.wishlist)),
          // The count reads as a caption under the title ("12 saved").
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                l10n.wishlistSavedCount(stays.length),
                style: AppTypography.forLight().caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
          if (stays.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _WishlistEmptyState(),
            )
          else ...<Widget>[
            SliverList.builder(
              itemCount: stays.length,
              itemBuilder: (context, index) {
                final HotelOffer item = stays[index];
                return HotelOverlapCard(
                  offer: item,
                  isFavorite: true,
                  // The heart only exists when it can really remove.
                  onFavorite: remove == null
                      ? null
                      : (bool value) {
                          if (!value) remove(item);
                        },
                  onTap: () => _openOffer(context, item),
                );
              },
            ),
            SliverToBoxAdapter(child: SizedBox(height: bottom)),
          ],
        ],
      ),
    );

    if (embedded) return content;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(bottom: false, child: content),
    );
  }

  /// Opens the offer's own detail page — the same destination the results
  /// page opens.
  void _openOffer(BuildContext context, HotelOffer offer) {
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router == null) return;
    router.push('/offer-details', extra: offer);
  }
}

/// The honest empty state: a 48px `textTertiary` heart, a title, a body and
/// the one action that can actually do something — exploring real stays.
class _WishlistEmptyState extends StatelessWidget {
  const _WishlistEmptyState();

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.favorite_border_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.wishlistEmptyTitle,
              textAlign: TextAlign.center,
              style: typography.bodyLargeMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.wishlistEmptyBody,
              textAlign: TextAlign.center,
              style: typography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: l10n.wishlistExploreStays,
              type: AppButtonType.secondary,
              expanded: false,
              onPressed: () => _explore(context),
            ),
          ],
        ),
      ),
    );
  }

  /// The button opens the hotel search — a real destination with real stays.
  void _explore(BuildContext context) {
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router == null) return;
    router.push('/hotels');
  }
}
