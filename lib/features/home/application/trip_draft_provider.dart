import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/core/domain/models/offers/base_offer.dart';
import 'package:tokigo/features/search/application/providers/offer_selection_provider.dart';

class TripDraft {
  const TripDraft({required this.destination, this.items = const []});

  final String destination;
  final List<SelectedOffer> items;

  Map<String, double> get totalsByCurrency {
    final totals = <String, double>{};
    for (final item in items) {
      totals.update(
        item.currency,
        (sum) => sum + item.price,
        ifAbsent: () => item.price,
      );
    }
    return totals;
  }

  TripDraft add(BaseOffer offer) {
    final selected = SelectedOffer.fromOffer(offer);
    final remaining = items.where(
      (item) => item.offerType != selected.offerType,
    );
    return TripDraft(destination: destination, items: [...remaining, selected]);
  }

  TripDraft remove(String offerType) => TripDraft(
    destination: destination,
    items: items.where((item) => item.offerType != offerType).toList(),
  );
}

class TripDraftController extends StateNotifier<TripDraft?> {
  TripDraftController() : super(null);

  void create(String destination) =>
      state = TripDraft(destination: destination);
  void add(BaseOffer offer) {
    final current = state;
    if (current != null) state = current.add(offer);
  }

  void remove(String offerType) {
    final current = state;
    if (current != null) state = current.remove(offerType);
  }

  void clear() => state = null;
}

final tripDraftProvider =
    StateNotifierProvider<TripDraftController, TripDraft?>(
      (ref) => TripDraftController(),
    );
