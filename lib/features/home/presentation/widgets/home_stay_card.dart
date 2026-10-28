import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/widgets/cards/overlap_stay_card.dart';
import 'package:tokigo/features/home/presentation/home_stay_offer.dart';
import 'package:tokigo/features/home/presentation/widgets/cached_hotel_image.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';

/// A stay on **card A** — the reference-A overlap card (4:3 photo, the white
/// sheet biting 48px over it).
///
/// This is the one card the Home uses for a hotel, so the stays in the feed
/// and the stays in the results are the same object on screen.
class HomeStayCard extends ConsumerWidget {
  const HomeStayCard({super.key, required this.item, this.margin, this.onTap});

  final HomeItem item;

  /// The card's own margin. A rail supplies its own spacing.
  final EdgeInsetsGeometry? margin;

  /// What a tap does. Null (the default) opens the stay's own details page; a
  /// surface that owns its own destination — the AI answer, for example —
  /// passes its own action.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String city = (item.metadata['city'] ?? '').toString().trim();
    final HotelOffer? offer = hotelOfferFromHomeStay(item);
    final double? price = item.price;
    final String amount = price == null ? '' : _wholeAmount(price);

    return OverlapStayCard(
      media: StayPhoto(item: item),
      title: item.title,
      rating: item.rating,
      reviewCount: item.reviewCount,
      amountText: amount,
      currency: item.currency ?? '',
      // The card is tappable when it has an action: its own details, or the
      // surface's (the AI answer hands the offer to the booking flow).
      enabled: onTap != null || offer != null || city.isNotEmpty,
      margin: margin,
      // Owner decision (2026-10-25): the stay opens ITSELF. Sending the
      // traveller to a city search hid the hotel they had just tapped.
      onTap: onTap ?? _openStay(context, offer: offer, city: city),
    );
  }

  /// Details when the card carries the facts to draw one; otherwise the city
  /// search — the honest fallback for a stay with no window or no price. A
  /// details page with invented dates would be worse than a search.
  VoidCallback? _openStay(
    BuildContext context, {
    required HotelOffer? offer,
    required String city,
  }) {
    if (offer != null) {
      return () => context.push('/offer-details', extra: offer);
    }
    if (city.isEmpty) return null;
    return () =>
        context.push('/hotels', extra: <String, dynamic>{'city': city});
  }

  /// Whole amounts read as "320", not "320.00" — a provider's fractional
  /// total keeps its cents.
  static String _wholeAmount(double amount) =>
      amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
}

/// The provider's real photo through [CachedHotelImage], sized from the card's
/// own box so the decode resolution follows the layout.
class StayPhoto extends ConsumerWidget {
  const StayPhoto({super.key, required this.item});

  final HomeItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? url = item.imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: AppColors.surfaceTertiary,
        alignment: Alignment.center,
        child: const Icon(
          Icons.hotel_outlined,
          size: 40,
          color: AppColors.textTertiary,
        ),
      );
    }
    // H3 — the Hive-backed photo cache is wired HERE. It used to be left at
    // the widget's nullable defaults, so the Home rail silently skipped the
    // disk cache entirely (the box never received a `hotel_image|` entry) and
    // re-downloaded every photo on every launch. The session memory layer in
    // front of it keeps scroll-back flash-free.
    final imageCache = ref.watch(hotelImageCacheProvider);
    final memoryCache = ref.watch(hotelImageMemoryCacheProvider);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 320;
        final double height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : width * 3 / 4;
        return CachedHotelImage(
          url: url,
          width: width,
          height: height,
          cache: imageCache,
          memoryCache: memoryCache,
        );
      },
    );
  }
}
