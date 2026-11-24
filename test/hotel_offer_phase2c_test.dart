import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/offers/customer_price.dart';
import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/mappers/offer_mapper_fixed.dart';
import 'package:tokigo/core/storage/offline_cache_serializers.dart';

/// Phase 2C — the grouped hotel offer contract on the client.
///
/// The backend returns ONE hotel row whose `offers` list preserves every valid
/// room-type offer. These tests pin the client half: parsing, honest defaults
/// for absent provider fields, cache round-trips and the freshness gate.
void main() {
  Map<String, dynamic> roomOffer({
    required String id,
    required String roomType,
    required double price,
    String currency = 'USD',
    bool? refundable = true,
    String? boardName,
    Map<String, dynamic>? cancellationPolicy,
  }) {
    return <String, dynamic>{
      'type': 'hotel',
      'id': id,
      'providerId': 'nuitee',
      'providerName': 'Nuitee Connect',
      'title': 'Nile Hotel',
      'subtitle': 'Cairo',
      'price': price,
      'currency': currency,
      'city': 'Cairo',
      'country': 'EG',
      'checkIn': '2027-01-10',
      'checkOut': '2027-01-12',
      'roomType': roomType,
      'metadata': <String, dynamic>{
        'boardName': ?boardName,
        'refundable': refundable,
        'cancellationPolicy': ?cancellationPolicy,
        'occupancy': <String, dynamic>{'rooms': 1, 'adults': 2},
      },
    };
  }

  Map<String, dynamic> groupedHotel() {
    final cheap = roomOffer(
      id: 'offer-cheap',
      roomType: 'Classic Double',
      price: 300,
      boardName: 'Room Only',
      cancellationPolicy: <String, dynamic>{
        'refundableUntil': '2027-01-09T12:00:00Z',
        'feeAmount': 50,
        'feeCurrency': 'USD',
        'timezone': 'UTC',
      },
    );
    final flexible = roomOffer(
      id: 'offer-flex',
      roomType: 'Deluxe Suite',
      price: 480,
      refundable: false,
      boardName: 'Breakfast included',
    );
    return <String, dynamic>{
      ...cheap,
      'offers': <Map<String, dynamic>>[cheap, flexible],
    };
  }

  group('grouped hotel offers', () {
    test('parses every nested room-type offer and keeps the row identity', () {
      final offer = mapOffer(groupedHotel()) as HotelOffer;

      expect(offer.id, 'offer-cheap');
      expect(offer.selectableOffers, hasLength(2));
      expect(offer.selectableOffers.map((HotelOffer o) => o.roomType), <String>[
        'Classic Double',
        'Deluxe Suite',
      ]);
      expect(offer.selectableOffers[1].price, 480);
      expect(offer.selectableOffers[1].boardName, 'Breakfast included');
    });

    test('a single (non-grouped) offer is still selectable', () {
      final offer =
          mapOffer(roomOffer(id: 'only', roomType: 'Twin', price: 200))
              as HotelOffer;

      expect(offer.offers, isEmpty);
      expect(offer.selectableOffers, <HotelOffer>[offer]);
    });

    test(
      'refundability is tri-state and the cancellation window is verbatim',
      () {
        final offer = mapOffer(groupedHotel()) as HotelOffer;
        final cheap = offer.selectableOffers[0];
        final flexible = offer.selectableOffers[1];

        expect(cheap.refundable, isTrue);
        expect(cheap.freeCancellationUntil, DateTime.utc(2027, 1, 9, 12));
        expect(cheap.cancellationFee, 50);
        expect(cheap.cancellationFeeCurrency, 'USD');
        expect(flexible.refundable, isFalse);
        expect(flexible.freeCancellationUntil, isNull);
      },
    );

    test('an untagged rate is unknown, never assumed non-refundable', () {
      final offer =
          mapOffer(
                roomOffer(
                  id: 'unknown',
                  roomType: 'Twin',
                  price: 200,
                  refundable: null,
                ),
              )
              as HotelOffer;

      expect(offer.refundable, isNull);
    });
  });

  group('honest defaults', () {
    test('absent dates stay absent instead of becoming "now"', () {
      final map = roomOffer(id: 'no-dates', roomType: 'Twin', price: 200)
        ..remove('checkIn')
        ..remove('checkOut');

      final offer = mapOffer(map) as HotelOffer;

      expect(offer.checkIn, isNull);
      expect(offer.checkOut, isNull);
    });

    test('an absent currency stays empty instead of being relabelled USD', () {
      final map = roomOffer(id: 'no-currency', roomType: 'Twin', price: 200)
        ..remove('currency');

      final offer = mapOffer(map) as HotelOffer;

      expect(offer.currency, '');
    });
  });

  group('offline cache', () {
    test('round-trips the grouped offers, dates and customer quote', () {
      final original = mapOffer(groupedHotel()) as HotelOffer;
      final priced = HotelOffer(
        id: original.id,
        providerId: original.providerId,
        providerName: original.providerName,
        title: original.title,
        subtitle: original.subtitle,
        price: original.price,
        currency: original.currency,
        city: original.city,
        country: original.country,
        checkIn: original.checkIn,
        checkOut: original.checkOut,
        roomType: original.roomType,
        metadata: original.metadata,
        offers: original.offers,
        customerPrice: const CustomerPrice(
          providerAmount: 300,
          providerCurrency: 'USD',
          customerAmount: 15000,
          customerCurrency: 'EGP',
          pricingVersion: 'pricing-v1',
          expiresAt: '2026-11-23T12:00:00Z',
          fxSource: 'cbe',
          fxRate: 50,
          lines: <PriceLine>[
            PriceLine(
              type: 'BASE',
              label: 'Stay',
              amount: 15000,
              currency: 'EGP',
            ),
          ],
        ),
      );

      final stored = offerToMap(priced);
      expect(stored['offers'], isA<List<dynamic>>());
      expect((stored['offers'] as List<dynamic>), hasLength(2));
      expect(stored['customerPrice'], isA<Map<String, dynamic>>());

      final restored = offerFromMap(stored) as HotelOffer;
      expect(restored.checkIn, DateTime(2027, 1, 10));
      expect(restored.checkOut, DateTime(2027, 1, 12));
      expect(restored.offers, hasLength(2));
      expect(restored.offers[1].id, 'offer-flex');
      expect(restored.customerPrice?.customerAmount, 15000);
      expect(restored.customerPrice?.customerCurrency, 'EGP');
      expect(restored.customerPrice?.fxRate, 50);
      expect(restored.customerPrice?.lines.single.label, 'Stay');
    });

    test('a cached search is fresh only inside the short TTL', () {
      final now = DateTime.utc(2026, 11, 23, 12);
      final fresh = <String, dynamic>{
        'timestamp': now
            .subtract(const Duration(minutes: 14))
            .toIso8601String(),
      };
      final stale = <String, dynamic>{
        'timestamp': now
            .subtract(const Duration(minutes: 16))
            .toIso8601String(),
      };

      expect(isHotelSearchCacheFresh(fresh, now: now), isTrue);
      expect(isHotelSearchCacheFresh(stale, now: now), isFalse);
      expect(isHotelSearchCacheFresh(<String, dynamic>{}, now: now), isFalse);
    });

    test('a future timestamp is treated as fresh (clock skew)', () {
      final now = DateTime.utc(2026, 11, 23, 12);
      final skewed = <String, dynamic>{
        'timestamp': now.add(const Duration(minutes: 5)).toIso8601String(),
      };

      expect(isHotelSearchCacheFresh(skewed, now: now), isTrue);
    });
  });
}
