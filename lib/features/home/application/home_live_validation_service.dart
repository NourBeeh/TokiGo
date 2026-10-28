import 'package:flutter/foundation.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_section.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/features/booking/application/services/offer_revalidation_service.dart';

/// Outcome of one live product validation (Phase 1D).
enum LiveValidationStatus {
  /// Provider confirmed the offer: available, price valid, not expired.
  valid,

  /// Provider confirmed availability but the price moved — the cached price
  /// must NOT be presented as live; the item goes to the replacement flow.
  priceChanged,

  /// Provider reports the offer is no longer bookable.
  unavailable,

  /// The offer expired (checked locally from metadata or by the provider).
  expired,

  /// Network/provider failure ONLY — the product is NOT invalid; the cached
  /// item is kept as-is and revalidated on a later refresh.
  validationFailed,

  /// The card has no provider-backed offer identity (pure discovery card) —
  /// never validated, kept as-is.
  unsupported,
}

/// Validation result for one snapshot product. Carries ONLY what the Home
/// needs: identity, provider, status, and the live facts the provider
/// returned. No sensitive data.
@immutable
class LiveValidationResult {
  const LiveValidationResult({
    required this.productId,
    required this.provider,
    required this.status,
    this.currentPrice,
    this.currency,
    this.expiresAt,
    this.availability,
  });

  final String productId;
  final String provider;
  final LiveValidationStatus status;
  final double? currentPrice;
  final String? currency;
  final String? expiresAt;
  final bool? availability;

  bool get needsReplacement =>
      status == LiveValidationStatus.priceChanged ||
      status == LiveValidationStatus.unavailable ||
      status == LiveValidationStatus.expired;

  bool get keepCached => status == LiveValidationStatus.validationFailed;
}

/// One collectable bookable product extracted from the Home snapshot.
@immutable
class _BookableProduct {
  const _BookableProduct({
    required this.sectionIndex,
    required this.itemIndex,
    required this.item,
    required this.productId,
    required this.provider,
    required this.offerType,
    this.knownPrice,
  });

  final int sectionIndex;
  final int itemIndex;
  final HomeItem item;
  final String productId;
  final String provider;
  final String offerType;
  final double? knownPrice;
}

/// Background live-validation layer for the Home snapshot (Phase 1D).
///
/// Hive is NEVER the source of truth for price/availability: after the
/// cached Home renders, this service re-checks every provider-backed
/// product through the EXISTING `/offers/revalidate` pipeline (the same one
/// booking uses — no parallel revalidation architecture). Only changed or
/// invalid products trigger the replacement flow.
///
/// Rules (§9 network minimization):
/// - Only provider-backed items are validated (pure discovery cards are
///   `unsupported` and kept as-is).
/// - Dedupe by offer identity — one call per product.
/// - Locally-expired offers are marked `expired` without any network call.
/// - Concurrency is capped and every call has its own timeout.
/// - Provider failures are isolated (`Future.wait` over chunks); one broken
///   provider never fails the batch.
class HomeLiveValidationService {
  HomeLiveValidationService(this._revalidation);

  final OfferRevalidationService _revalidation;

  /// Providers with a live revalidation path on the backend.
  static const Set<String> supportedProviders = {'duffel-flight', 'nuitee'};

  /// Maximum simultaneous validation calls.
  static const int maxConcurrentValidations = 4;

  /// Per-call ceiling so a slow provider cannot stall the batch.
  static const Duration perCallTimeout = Duration(seconds: 10);

  /// Validates [sections] in the background. Returns ONLY the results for
  /// products worth acting on — `valid` results carry the fresh
  /// price/expiry, everything needing replacement or keeping is reported.
  /// Never throws; a total failure yields an empty list (Home stays).
  Future<List<LiveValidationResult>> validate(
    List<HomeSection> sections,
  ) async {
    final products = _collectBookable(sections);
    final results = <LiveValidationResult>[];

    // Chunked fan-out with a hard concurrency cap.
    for (var i = 0; i < products.length; i += maxConcurrentValidations) {
      final chunk = products.skip(i).take(maxConcurrentValidations);
      final settled = await Future.wait(chunk.map((p) => _validateOne(p)))
          .then<List<LiveValidationResult?>>(
            (list) => list,
            onError: (_) =>
                List<LiveValidationResult?>.filled(chunk.length, null),
          );
      for (final result in settled) {
        if (result != null) results.add(result);
      }
    }
    return results;
  }

  /// Extracts the provider-backed bookable products from the snapshot.
  /// Skips (with no network cost):
  /// - items without a supported provider identity (discovery cards),
  /// - items whose cached validity already lapsed (local `expired` result),
  /// - duplicate offer identities (dedupe).
  List<_BookableProduct> _collectBookable(List<HomeSection> sections) {
    final products = <_BookableProduct>[];
    final seenIds = <String>{};

    for (var s = 0; s < sections.length; s++) {
      final items = sections[s].items;
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final provider = item.metadata['providerId']?.toString();
        if (provider == null || !supportedProviders.contains(provider)) {
          continue; // Pure discovery card — never validated.
        }
        final productId =
            item.metadata['providerOfferId']?.toString() ?? item.id;
        if (!seenIds.add(productId)) continue; // Dedupe.

        // Local expiry check from the cached offer metadata.
        final validUntil = item.metadata['validUntil']?.toString();
        final expiry = DateTime.tryParse(validUntil ?? '');
        if (expiry != null && expiry.isBefore(DateTime.now())) {
          products.add(
            _BookableProduct(
              sectionIndex: s,
              itemIndex: i,
              item: item,
              productId: productId,
              provider: provider,
              offerType: _offerTypeFor(item),
              knownPrice: item.price,
            ),
          );
          // Expired items are resolved locally; no validation call is made.
          continue;
        }

        products.add(
          _BookableProduct(
            sectionIndex: s,
            itemIndex: i,
            item: item,
            productId: productId,
            provider: provider,
            offerType: _offerTypeFor(item),
            knownPrice: item.price,
          ),
        );
      }
    }
    return products;
  }

  Future<LiveValidationResult?> _validateOne(_BookableProduct p) async {
    // Locally expired → short-circuit without a network call.
    final validUntil = p.item.metadata['validUntil']?.toString();
    final expiry = DateTime.tryParse(validUntil ?? '');
    if (expiry != null && expiry.isBefore(DateTime.now())) {
      return LiveValidationResult(
        productId: p.productId,
        provider: p.provider,
        status: LiveValidationStatus.expired,
      );
    }

    try {
      final outcome = await _revalidation
          .revalidate(
            offerId: p.productId,
            providerId: p.provider,
            offerType: p.offerType,
            knownPrice: p.knownPrice,
          )
          .timeout(perCallTimeout);

      switch (outcome.status) {
        case RevalidationStatus.ok:
          return LiveValidationResult(
            productId: p.productId,
            provider: p.provider,
            status: LiveValidationStatus.valid,
            currentPrice: outcome.price,
            currency: outcome.currency,
            expiresAt: outcome.expiresAt,
            availability: true,
          );
        case RevalidationStatus.priceChanged:
          return LiveValidationResult(
            productId: p.productId,
            provider: p.provider,
            status: LiveValidationStatus.priceChanged,
            currentPrice: outcome.newPrice,
            currency: outcome.currency,
            expiresAt: outcome.expiresAt,
            availability: true,
          );
        case RevalidationStatus.unavailable:
          return LiveValidationResult(
            productId: p.productId,
            provider: p.provider,
            status: LiveValidationStatus.unavailable,
            availability: false,
          );
        case RevalidationStatus.error:
          // Provider/network failure: the product is NOT invalid — keep the
          // cached item and retry on a later refresh.
          return LiveValidationResult(
            productId: p.productId,
            provider: p.provider,
            status: LiveValidationStatus.validationFailed,
          );
      }
    } catch (_) {
      // Timeout / transport failure — same keep-cached semantics.
      return LiveValidationResult(
        productId: p.productId,
        provider: p.provider,
        status: LiveValidationStatus.validationFailed,
      );
    }
  }

  String _offerTypeFor(HomeItem item) {
    switch (item.type) {
      case HomeCardType.hotel:
        return 'hotel';
      case HomeCardType.flight:
        return 'flight';
      case HomeCardType.car:
        return 'car';
      case HomeCardType.package:
        return 'package';
      case HomeCardType.destination:
      case HomeCardType.deal:
        return 'package'; // Backend DTO requires one of the four types.
    }
  }
}
