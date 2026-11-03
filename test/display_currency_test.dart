import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/offers/customer_price.dart';
import 'package:tokigo/core/domain/models/offers/display_price.dart';
import 'package:tokigo/core/geo/currency.dart';
import 'package:tokigo/core/repositories/impl/flight_repository_impl.dart';
import 'package:tokigo/core/repositories/impl/hotel_repository_impl.dart';

void main() {
  group('display currency resolution', () {
    test('auto follows the configured markets, else USD', () {
      expect(autoCurrencyFor('EG'), 'EGP');
      expect(autoCurrencyFor(' sa '), 'SAR');
      expect(autoCurrencyFor('AE'), 'AED');
      // Owner decision (2026-11-03): outside EG/SA/AE the default is USD.
      expect(autoCurrencyFor('GB'), 'USD');
      expect(autoCurrencyFor('FR'), 'USD');
      expect(autoCurrencyFor(null), 'USD');
    });

    test('an explicit choice wins; unknown codes fall back to auto', () {
      expect(effectiveCurrency(chosen: 'EUR', countryCode: 'EG'), 'EUR');
      expect(effectiveCurrency(chosen: null, countryCode: 'AE'), 'AED');
      expect(effectiveCurrency(chosen: 'ZZZ', countryCode: 'GB'), 'USD');
    });
  });

  group('display money', () {
    test('without a quote the provider amount/currency stand unchanged', () {
      final DisplayMoney money = displayMoneyFor(100, 'EUR', null);
      expect(money.amount, 100);
      expect(money.currency, 'EUR');
    });

    test('a quote scales the amount into the display currency', () {
      const CustomerPrice quote = CustomerPrice(
        providerAmount: 100,
        providerCurrency: 'USD',
        customerAmount: 4850,
        customerCurrency: 'EGP',
        pricingVersion: 'v',
        expiresAt: 'x',
      );
      // A per-night figure (half the stay total) scaled by the same ratio.
      final DisplayMoney money = displayMoneyFor(50, 'USD', quote);
      expect(money.amount, closeTo(2425, 0.001));
      expect(money.currency, 'EGP');
    });

    test('a zero-provider quote is ignored (never divides by zero)', () {
      const CustomerPrice quote = CustomerPrice(
        providerAmount: 0,
        providerCurrency: 'USD',
        customerAmount: 10,
        customerCurrency: 'EGP',
        pricingVersion: 'v',
        expiresAt: 'x',
      );
      final DisplayMoney money = displayMoneyFor(50, 'USD', quote);
      expect(money.amount, 50);
      expect(money.currency, 'USD');
    });
  });

  group('search requests carry the chosen currency', () {
    test('hotel search body includes it when set', () {
      final Map<String, dynamic> body = HotelRepositoryImpl.buildSearchBody(
        city: 'Cairo',
        checkIn: DateTime(2026, 1, 1),
        checkOut: DateTime(2026, 1, 3),
        currency: 'EGP',
      );
      expect(body['currency'], 'EGP');

      final Map<String, dynamic> without = HotelRepositoryImpl.buildSearchBody(
        city: 'Cairo',
        checkIn: DateTime(2026, 1, 1),
        checkOut: DateTime(2026, 1, 3),
      );
      expect(without.containsKey('currency'), isFalse);
    });

    test('flight search body includes it when set', () {
      final Map<String, dynamic> body = FlightRepositoryImpl.buildSearchBody(
        origin: 'CAI',
        destination: 'DXB',
        departure: DateTime(2026, 1, 1),
        currency: 'AED',
      );
      expect(body['currency'], 'AED');
    });
  });
}
