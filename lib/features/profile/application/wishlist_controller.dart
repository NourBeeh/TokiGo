import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/offline_cache_providers.dart';
import 'package:tokigo/core/storage/offline_cache_serializers.dart';

/// The stays the traveller kept.
///
/// **The wishlist's source is the heart on the product** (owner, 2026-10-20):
/// pressing the heart on a stay in the results — or on its detail page —
/// saves it here, and the wishlist page lists exactly those. There is no
/// second way in and no list that appears from nowhere.
///
/// Until the backend owns an account-scoped wishlist, the list lives in the
/// app's own Hive cache: it is the traveller's, on their device, and it
/// survives an app restart.
class WishlistController extends StateNotifier<List<HotelOffer>> {
  WishlistController(this._cache) : super(const <HotelOffer>[]) {
    _restore();
  }

  /// The cache entry the list is stored under.
  static const String cacheKey = 'wishlist:hotels';

  final OfflineCache _cache;

  Future<void> _restore() async {
    final Map<String, dynamic>? stored = await _cache.read(cacheKey);
    final List<dynamic> raw = (stored?['offers'] as List?) ?? const <dynamic>[];
    final List<HotelOffer> offers = <HotelOffer>[];
    for (final Object? item in raw) {
      if (item is Map<String, dynamic>) {
        final Object? offer = offerFromMap(item);
        if (offer is HotelOffer) offers.add(offer);
      }
    }
    if (offers.isNotEmpty && mounted) state = offers;
  }

  /// Whether this offer is already saved.
  bool isSaved(String offerId) =>
      state.any((HotelOffer offer) => offer.id == offerId);

  /// Saves the offer when [saved] is true, removes it otherwise.
  void setSaved(HotelOffer offer, bool saved) {
    final List<HotelOffer> next = List<HotelOffer>.from(state);
    final int index = next.indexWhere((HotelOffer item) => item.id == offer.id);
    if (saved && index < 0) {
      // The newest save is the first row — the list reads as a timeline.
      next.insert(0, offer);
    } else if (!saved && index >= 0) {
      next.removeAt(index);
    } else {
      return;
    }
    state = next;
    _persist(next);
  }

  /// Flips the offer's saved state.
  void toggle(HotelOffer offer) => setSaved(offer, !isSaved(offer.id));

  /// Removes the offer from the list.
  void remove(HotelOffer offer) => setSaved(offer, false);

  Future<void> _persist(List<HotelOffer> offers) async {
    await _cache.write(cacheKey, <String, dynamic>{
      'offers': <Map<String, dynamic>>[
        for (final HotelOffer offer in offers) offerToMap(offer),
      ],
    });
  }
}

/// The traveller's saved stays, persisted in the app's own Hive cache.
final wishlistProvider =
    StateNotifierProvider<WishlistController, List<HotelOffer>>((ref) {
      return WishlistController(ref.watch(offlineCacheProvider));
    });
