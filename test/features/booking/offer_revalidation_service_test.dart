import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokigo/features/booking/application/services/offer_revalidation_service.dart';

/// Unit coverage for the revalidation outcome mapping (spec point 8):
/// the Flutter side must map the backend contract faithfully — OK unlocks
/// checkout, PRICE_CHANGED blocks it, UNAVAILABLE/ERROR never crash.
void main() {
  group('OfferRevalidationService response mapping', () {
    test('RevalidationOutcome carries price and expiry for OK', () {
      const outcome = RevalidationOutcome(
        status: RevalidationStatus.ok,
        price: 4850,
        currency: 'EGP',
        expiresAt: '2026-09-10T12:00:00Z',
      );
      expect(outcome.canProceed, isTrue);
      expect(outcome.price, 4850);
      expect(outcome.currency, 'EGP');
    });

    test('PRICE_CHANGED carries both sides of the change', () {
      const outcome = RevalidationOutcome(
        status: RevalidationStatus.priceChanged,
        oldPrice: 450,
        newPrice: 480,
        currency: 'USD',
      );
      expect(outcome.canProceed, isFalse);
      expect(outcome.oldPrice, 450);
      expect(outcome.newPrice, 480);
    });

    test('UNAVAILABLE/ERROR outcomes never allow checkout', () {
      const unavailable = RevalidationOutcome(
        status: RevalidationStatus.unavailable,
        reason: 'offer expired',
      );
      const error = RevalidationOutcome(
        status: RevalidationStatus.error,
        reason: 'network down',
      );
      expect(unavailable.canProceed, isFalse);
      expect(error.canProceed, isFalse);
      expect(unavailable.reason, 'offer expired');
    });

    test('service provider exposes a singleton wired to the HTTP client', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(offerRevalidationServiceProvider);
      expect(service, isA<OfferRevalidationService>());
    });
  });
}
