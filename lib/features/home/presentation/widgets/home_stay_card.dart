import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/domain/models/offers/display_price.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/cards/overlap_stay_card.dart';
import 'package:tokigo/features/home/presentation/home_stay_offer.dart';
import 'package:tokigo/features/home/presentation/open_stay_map.dart';
import 'package:tokigo/features/home/presentation/stay_distance.dart';
import 'package:tokigo/features/home/presentation/widgets/cached_hotel_image.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/profile/application/wishlist_controller.dart';
import 'package:tokigo/features/search/domain/stay_price.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// A stay on the Home feed — a wide hotel photo above a distinct details panel.
///
/// This is the one card the Home uses for a hotel, so the stays in the feed
/// and the stays in the results are the same object on screen.
class HomeStayCard extends ConsumerWidget {
  const HomeStayCard({
    super.key,
    required this.item,
    this.margin,
    this.onTap,
    this.aspectRatio = 4 / 3,
    this.loading = false,
  });

  /// Skeleton entry point — no item needed; the card renders its own
  /// placeholder state at the same geometry.
  const HomeStayCard.loading({
    super.key,
    this.margin,
    this.aspectRatio = 4 / 3,
  }) : item = const HomeItem(id: '', type: HomeCardType.hotel, title: ''),
       onTap = null,
       loading = true;

  final HomeItem item;

  /// The card's own margin. A rail supplies its own spacing.
  final EdgeInsetsGeometry? margin;

  /// What a tap does. Null (the default) opens the stay's own details page; a
  /// surface that owns its own destination — the AI answer, for example —
  /// passes its own action.
  final VoidCallback? onTap;

  /// The Home rail uses a wider image than other stay surfaces.
  final double aspectRatio;

  /// Skeleton state — same geometry, no data. The card delegates to
  /// [OverlapStayCard]'s loading state, so the placeholder is the same card.
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (loading) {
      return OverlapStayCard.skeleton(
        margin: margin,
        aspectRatio: aspectRatio,
        semanticsLabel: l10n?.hotelLoading ?? 'Loading hotel',
      );
    }
    final String city = (item.metadata['city'] ?? '').toString().trim();
    final String country = (item.metadata['country'] ?? '').toString().trim();
    final String location = <String>[
      city,
      country,
    ].where((String part) => part.isNotEmpty).join(', ');
    final HotelOffer? offer = hotelOfferFromHomeStay(item);

    // The provider quotes a stay total. The card labels a per-night figure
    // only when it can be derived from the offer's own window — never by
    // assuming a nightly rate for a total that has no dates.
    final StayPrice? stayPrice = offer == null ? null : StayPrice.of(offer);
    final double? providerAmount = stayPrice?.perNight ?? item.price;
    // Show the backend's converted CUSTOMER price when it exists, in the
    // traveller's display currency; otherwise the provider's own figure.
    final DisplayMoney? money = providerAmount == null
        ? null
        : displayMoneyFor(
            providerAmount,
            item.currency ?? '',
            offer?.customerPrice,
          );
    final String amountText = money == null ? '' : _wholeAmount(money.amount);
    final String? unit = stayPrice?.perNight != null
        ? (l10n?.unitNight ?? 'night')
        : null;

    final int? starClass =
        offer?.starClass ??
        (item.metadata['stars'] is num
            ? (item.metadata['stars'] as num).toInt()
            : null);

    final double? distanceKm = stayDistanceToCenterKm(
      metadata: item.metadata,
      city: city,
    );
    final String? distanceText = distanceKm == null
        ? null
        : (l10n?.hotelDistanceFromCenter(formatStayDistance(distanceKm)) ??
              '${formatStayDistance(distanceKm)} km from the center');

    final double? latitude = _number(
      item.metadata['latitude'] ?? item.metadata['lat'],
    );
    final double? longitude = _number(
      item.metadata['longitude'] ??
          item.metadata['lng'] ??
          item.metadata['long'],
    );

    final bool isSaved = offer == null
        ? false
        : ref.watch(wishlistProvider).any((HotelOffer o) => o.id == offer.id);

    return OverlapStayCard(
      media: StayPhoto(item: item),
      title: item.title,
      starClass: starClass,
      rating: item.rating,
      reviewCount: item.reviewCount,
      location: location.isEmpty ? null : location,
      onLocationTap: location.isEmpty
          ? null
          : () => openStayInMaps(
              name: item.title,
              location: location,
              latitude: latitude,
              longitude: longitude,
            ),
      distanceText: distanceText,
      amountText: amountText,
      currency: money?.currency ?? item.currency ?? '',
      unit: unit,
      enabled: onTap != null || offer != null || city.isNotEmpty,
      margin: margin,
      aspectRatio: aspectRatio,
      isFavorite: isSaved,
      onFavorite: offer == null
          ? null
          : (bool saved) => ref
              .read(wishlistProvider.notifier)
              .setSaved(offer, saved),
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

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }
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
        color: context.tokigoColors.surfaceTertiary,
        alignment: Alignment.center,
        child: Icon(
          Icons.house_rounded,
          size: 40,
          color: context.tokigoColors.textTertiary,
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
