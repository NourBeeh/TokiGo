import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/offers/customer_price.dart';
import 'package:tokigo/core/domain/models/offers/flight_offer.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/search/presentation/widgets/flight_route_line.dart';
import 'package:tokigo/features/search/presentation/widgets/flight_search_card.dart';
import 'package:tokigo/l10n/app_localizations.dart';

FlightOffer _offer({
  String airline = 'Emirates',
  String flightNumber = 'EK123',
  double price = 100,
  String currency = 'USD',
  CustomerPrice? quote,
  DateTime? departure,
  DateTime? arrival,
}) => FlightOffer(
  id: 'f1',
  providerId: 'provider',
  providerName: 'Provider',
  title: 'Flight',
  price: price,
  currency: currency,
  customerPrice: quote,
  origin: 'CAI',
  destination: 'DXB',
  departureTime: departure ?? DateTime(2026, 1, 1, 10),
  arrivalTime: arrival ?? DateTime(2026, 1, 1, 14),
  airline: airline,
  flightNumber: flightNumber,
);

const CustomerPrice _quote = CustomerPrice(
  providerAmount: 100,
  providerCurrency: 'USD',
  customerAmount: 5000,
  customerCurrency: 'EGP',
  pricingVersion: 'v',
  expiresAt: 'x',
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('flight card identity', () {
    testWidgets('shows the provider flight number, never a code made from '
        'the airline name', (tester) async {
      await tester.pumpWidget(
        _wrap(FlightSearchCard(offer: _offer(flightNumber: 'EK123'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('EK 123'), findsOneWidget);
      // "Emirates" must not become the carrier code "EM".
      expect(find.textContaining('EM '), findsNothing);
      expect(find.textContaining('EM123'), findsNothing);
    });

    testWidgets('keeps a bare numeric flight number verbatim', (tester) async {
      await tester.pumpWidget(
        _wrap(FlightSearchCard(offer: _offer(flightNumber: '985'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('985'), findsOneWidget);
    });
  });

  group('flight card price', () {
    testWidgets('shows the quoted customer amount/currency, not the provider '
        'figure', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlightSearchCard(
            offer: _offer(price: 100, currency: 'USD', quote: _quote),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EGP 5000'), findsOneWidget);
      expect(find.text('USD 100'), findsNothing);
    });
  });

  group('flight route line', () {
    testWidgets('marks an arrival on the following day with +1', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FlightRouteLine(
            departureTime: DateTime(2026, 1, 1, 23, 50),
            arrivalTime: DateTime(2026, 1, 2, 5, 10),
            origin: 'CAI',
            destination: 'DXB',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('05:10'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('the +1 badge never overflows a narrow compact card', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 220,
            child: FlightRouteLine(
              departureTime: DateTime(2026, 1, 1, 23, 50),
              arrivalTime: DateTime(2026, 1, 2, 5, 10),
              origin: 'CAI',
              destination: 'DXB',
              compact: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('does not mark a same-day arrival', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlightRouteLine(
            departureTime: DateTime(2026, 1, 1, 10),
            arrivalTime: DateTime(2026, 1, 1, 14),
            origin: 'CAI',
            destination: 'DXB',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+1'), findsNothing);
    });
  });
}
