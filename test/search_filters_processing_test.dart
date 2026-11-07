import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/offers/customer_price.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/features/search/application/search_facets.dart';
import 'package:tokigo/features/search/application/search_results_processing.dart';
import 'package:tokigo/features/search/domain/search_filters.dart';

CustomerPrice _quote({
  double providerAmount = 100,
  double customerAmount = 5000,
  String customerCurrency = 'EGP',
}) => CustomerPrice(
  providerAmount: providerAmount,
  providerCurrency: 'USD',
  customerAmount: customerAmount,
  customerCurrency: customerCurrency,
  pricingVersion: 'v',
  expiresAt: 'x',
);

FlightOffer _flight({
  String id = 'f1',
  double price = 100,
  String currency = 'USD',
  CustomerPrice? quote,
}) => FlightOffer(
  id: id,
  providerId: 'provider',
  providerName: 'Provider',
  title: 'Flight',
  price: price,
  currency: currency,
  customerPrice: quote,
  origin: 'CAI',
  destination: 'DXB',
  departureTime: DateTime(2026, 1, 1, 22),
  arrivalTime: DateTime(2026, 1, 2, 6),
  airline: 'Emirates',
  flightNumber: 'EK 123',
);

void main() {
  group('SearchFilters.copyWith', () {
    test('an omitted argument keeps the current value', () {
      const SearchFilters filters = SearchFilters(
        priceMax: 500,
        minStars: 4,
        budgetMax: 3000,
        budgetCurrency: 'EGP',
      );

      final SearchFilters copy = filters.copyWith(priceMax: 700);

      expect(copy.priceMax, 700);
      expect(copy.minStars, 4);
      expect(copy.budgetMax, 3000);
      expect(copy.budgetCurrency, 'EGP');
    });

    test('an explicit null clears the value', () {
      const SearchFilters filters = SearchFilters(
        priceMax: 500,
        minStars: 4,
        airlines: <String>['Emirates'],
        budgetMax: 3000,
        budgetCurrency: 'EGP',
      );

      final SearchFilters cleared = filters.copyWith(
        priceMax: null,
        minStars: null,
        airlines: null,
        budgetMax: null,
        budgetCurrency: null,
      );

      expect(cleared.priceMax, isNull);
      expect(cleared.minStars, isNull);
      expect(cleared.airlines, isNull);
      expect(cleared.budgetMax, isNull);
      expect(cleared.budgetCurrency, isNull);
      expect(cleared.isEmpty, isTrue);
    });

    test('withMinRating / withMinStars / withoutBudget clear cleanly', () {
      const SearchFilters filters = SearchFilters(
        minRating: 8,
        minStars: 5,
        budgetMax: 3000,
        budgetCurrency: 'EGP',
      );

      expect(filters.withMinRating(null).minRating, isNull);
      expect(filters.withMinStars(null).minStars, isNull);
      expect(filters.withoutBudget().budgetMax, isNull);
      expect(filters.withoutBudget().budgetCurrency, isNull);
      // Everything else survives.
      expect(filters.withMinRating(null).minStars, 5);
      expect(filters.withMinStars(null).minRating, 8);
    });
  });

  group('effective currency', () {
    test('uses the quoted customer currency when attached', () {
      final FlightOffer offer = _flight(quote: _quote());
      expect(effectiveSortAmount(offer), 5000);
      expect(effectiveSortCurrency(offer), 'EGP');
    });

    test('falls back to the provider currency without a quote', () {
      final FlightOffer offer = _flight(currency: 'EUR');
      expect(effectiveSortAmount(offer), 100);
      expect(effectiveSortCurrency(offer), 'EUR');
    });

    test('a list mixing quoted and unquoted currencies is not comparable', () {
      expect(
        hasComparableCustomerTotals(<FlightOffer>[
          _flight(id: 'a', quote: _quote()),
          _flight(id: 'b', currency: 'USD'),
        ]),
        isFalse,
      );
    });
  });

  group('budget filter', () {
    test('compares the customer amount in the customer currency', () {
      final FlightOffer offer = _flight(quote: _quote(customerAmount: 5000));

      // Provider amount (100 USD) is under the cap; the customer total
      // (5000 EGP) is over it. The customer total is what the traveller sees.
      final List<FlightOffer> filtered = applyFlightFilters(<FlightOffer>[
        offer,
      ], const SearchFilters(budgetMax: 4000, budgetCurrency: 'EGP'));
      expect(filtered, isEmpty);

      final List<FlightOffer> kept = applyFlightFilters(<FlightOffer>[offer], const SearchFilters(
        budgetMax: 6000,
        budgetCurrency: 'EGP',
      ));
      expect(kept, hasLength(1));
    });

    test('applies when the customer currency matches, not the provider one', () {
      final FlightOffer offer = _flight(quote: _quote(customerCurrency: 'EGP'));

      expect(
        budgetAppliesTo(<FlightOffer>[offer], const SearchFilters(
          budgetMax: 6000,
          budgetCurrency: 'EGP',
        )),
        isTrue,
      );
      expect(
        budgetAppliesTo(<FlightOffer>[offer], const SearchFilters(
          budgetMax: 6000,
          budgetCurrency: 'USD',
        )),
        isFalse,
      );
    });
  });

  group('price facet', () {
    test('spans the same customer amount/currency the filters use', () {
      final PriceFacet? facet = priceFacetOf(<FlightOffer>[
        _flight(id: 'a', quote: _quote(customerAmount: 5000)),
        _flight(
          id: 'b',
          price: 200,
          quote: _quote(providerAmount: 200, customerAmount: 9000),
        ),
      ]);

      expect(facet, isNotNull);
      expect(facet!.currency, 'EGP');
      expect(facet.min, 5000);
      expect(facet.max, 9000);
    });
  });
}
