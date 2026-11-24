import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/mappers/offer_mapper_fixed.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/search/presentation/widgets/offer_details/offer_details_room_selector.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Phase 2C — the details-page room selector.
///
/// The selector must list every valid offer the backend grouped (room, board,
/// price, cancellation), and a tap must hand the chosen offer back so the page
/// can reprice and book THAT room type.
void main() {
  Map<String, dynamic> roomOffer({
    required String id,
    required String roomType,
    required double price,
    bool? refundable = true,
    String? boardName,
  }) {
    return <String, dynamic>{
      'type': 'hotel',
      'id': id,
      'providerId': 'nuitee',
      'providerName': 'Nuitee Connect',
      'title': 'Nile Hotel',
      'price': price,
      'currency': 'USD',
      'city': 'Cairo',
      'country': 'EG',
      'checkIn': '2027-01-10',
      'checkOut': '2027-01-12',
      'roomType': roomType,
      'metadata': <String, dynamic>{
        'refundable': refundable,
        'boardName': ?boardName,
      },
    };
  }

  HotelOffer grouped() {
    final cheap = roomOffer(
      id: 'offer-cheap',
      roomType: 'Classic Double',
      price: 300,
      boardName: 'Room Only',
    );
    final flexible = roomOffer(
      id: 'offer-flex',
      roomType: 'Deluxe Suite',
      price: 480,
      refundable: false,
      boardName: 'Breakfast included',
    );
    return mapOffer(<String, dynamic>{
          ...cheap,
          'offers': <Map<String, dynamic>>[cheap, flexible],
        })
        as HotelOffer;
  }

  Future<void> pump(
    WidgetTester tester, {
    required List<HotelOffer> offers,
    required HotelOffer selected,
    required ValueChanged<HotelOffer> onSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: const <Locale>[Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: OfferDetailsRoomSelector(
              offers: offers,
              selected: selected,
              onSelected: onSelected,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists room, board, price and cancellation for every offer', (
    tester,
  ) async {
    final hotel = grouped();
    await pump(
      tester,
      offers: hotel.selectableOffers,
      selected: hotel.selectableOffers.first,
      onSelected: (_) {},
    );

    expect(find.text('Choose a room'), findsOneWidget);
    expect(find.text('Classic Double'), findsOneWidget);
    expect(find.text('Deluxe Suite'), findsOneWidget);
    expect(find.text('Room Only'), findsOneWidget);
    expect(find.text('Breakfast included'), findsOneWidget);
    expect(find.text('USD 300.00'), findsOneWidget);
    expect(find.text('USD 480.00'), findsOneWidget);
    expect(find.text('Free cancellation'), findsOneWidget);
    expect(find.text('Non-refundable'), findsOneWidget);
    expect(find.text('per stay'), findsNWidgets(2));
  });

  testWidgets('a tap hands the chosen room-type offer back', (tester) async {
    final hotel = grouped();
    HotelOffer? chosen;
    await pump(
      tester,
      offers: hotel.selectableOffers,
      selected: hotel.selectableOffers.first,
      onSelected: (HotelOffer value) => chosen = value,
    );

    await tester.tap(find.text('Deluxe Suite'));
    await tester.pumpAndSettle();

    expect(chosen?.id, 'offer-flex');
    expect(chosen?.price, 480);
  });

  testWidgets('a hotel with one offer shows no chooser', (tester) async {
    final hotel =
        mapOffer(roomOffer(id: 'only', roomType: 'Twin', price: 200))
            as HotelOffer;
    await pump(
      tester,
      offers: hotel.selectableOffers,
      selected: hotel,
      onSelected: (_) {},
    );

    expect(find.text('Choose a room'), findsNothing);
    expect(find.text('Twin'), findsNothing);
  });
}
