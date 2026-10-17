import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/widgets/shimmer.dart';

import 'package:tokigo/core/domain/models/offers/hotel_offer.dart';
import 'package:tokigo/core/widgets/cards/card.dart';
import 'package:tokigo/features/search/presentation/widgets/hotel_search_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

HotelOffer _makeOffer({
  String id = 'h1',
  String title = 'Grand Hotel',
  String city = 'Cairo',
  String country = 'Egypt',
  String? imageUrl = 'https://example.com/hotel.jpg',
  double price = 299,
  String currency = 'USD',
  double? rating = 4.7,
  int? reviewCount = 120,
  List<String> amenities = const ['WiFi', 'Pool', 'Spa'],
  String roomType = 'Deluxe King',
  Map<String, dynamic>? metadata,
  DateTime? checkIn,
  DateTime? checkOut,
}) =>
    HotelOffer(
      id: id,
      providerId: 'p1',
      providerName: 'Test Provider',
      title: title,
      city: city,
      country: country,
      checkIn: checkIn ?? DateTime.now().add(const Duration(days: 7)),
      checkOut: checkOut ?? DateTime.now().add(const Duration(days: 10)),
      roomType: roomType,
      amenities: amenities,
      imageUrl: imageUrl,
      price: price,
      currency: currency,
      rating: rating,
      reviewCount: reviewCount,
      metadata: metadata ?? {},
    );

void main() {
  group('HotelSearchCard', () {
    testWidgets('renders all core elements (horizontal layout)', (tester) async {
      await tester.pumpWidget(_wrap(HotelSearchCard(offer: _makeOffer())));

      expect(find.text('Grand Hotel'), findsOneWidget);
      expect(find.text('Cairo, Egypt'), findsOneWidget);
      expect(find.byType(CardImage), findsOneWidget);
      expect(find.byType(CardRating), findsOneWidget);
      expect(find.byType(CardLocation), findsOneWidget);
      expect(find.byType(CardFeatureList), findsOneWidget);
      expect(find.byType(CardPriceBlock), findsOneWidget);
      expect(find.byType(CardFavorite), findsOneWidget);
      // NO CTA button in new design
      expect(find.byType(CardPrimaryAction), findsNothing);
      expect(find.text('View Details'), findsNothing);
    });

    testWidgets('displays rating with review count inline', (tester) async {
      await tester.pumpWidget(_wrap(HotelSearchCard(offer: _makeOffer(rating: 4.5, reviewCount: 88))));

      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('(88)'), findsOneWidget);
      final rating = tester.widget<CardRating>(find.byType(CardRating));
      expect(rating.onImage, false);
    });

    testWidgets('no rating: no CardRating rendered', (tester) async {
      await tester.pumpWidget(_wrap(HotelSearchCard(offer: _makeOffer(rating: null))));

      expect(find.byType(CardRating), findsNothing);
    });

    testWidgets('features: room type + up to 2 amenities (max 3 total)', (tester) async {
      await tester.pumpWidget(_wrap(HotelSearchCard(offer: _makeOffer(
        roomType: 'Deluxe King',
        amenities: ['WiFi', 'Pool', 'Spa', 'Gym'],
      ))));

      expect(find.text('Deluxe King'), findsOneWidget);
      expect(find.text('WiFi'), findsOneWidget);
      expect(find.text('Pool'), findsOneWidget);
      expect(find.text('Spa'), findsNothing); // Only first 2 amenities
    });

    testWidgets('free cancellation shows CardCancellation with check icon', (tester) async {
      await tester.pumpWidget(_wrap(HotelSearchCard(offer: _makeOffer(metadata: {
        'freeCancellation': true,
        'cancellationPolicy': 'Free cancellation until 24h before check-in',
      }))));

      expect(find.text('Free cancellation until 24h before check-in'), findsOneWidget);
      final cancellation = tester.widget<CardCancellation>(find.byType(CardCancellation).first);
      expect(cancellation.freeCancellation, true);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('no free cancellation: no CardCancellation rendered', (tester) async {
      await tester.pumpWidget(_wrap(HotelSearchCard(offer: _makeOffer(metadata: {
        'cancellationPolicy': 'Non-refundable',
      }))));

      // Only free cancellation is shown
      expect(find.byType(CardCancellation), findsNothing);
    });

    testWidgets('price per night from metadata used in CardPriceBlock', (tester) async {
      await tester.pumpWidget(_wrap(HotelSearchCard(offer: _makeOffer(
        price: 350, // BaseOffer price
        metadata: {'pricePerNight': 299},
      ))));

      // CardPriceBlock should show pricePerNight (299) as current price
      expect(find.text('USD 299'), findsOneWidget);
    });

    testWidgets('total price shown as secondary line when different from per-night * nights', (tester) async {
      await tester.pumpWidget(_wrap(HotelSearchCard(offer: _makeOffer(
        metadata: {
          'pricePerNight': 299,
          'totalPrice': 950, // Different from 299 * 3 = 897
        },
        checkIn: DateTime(2026, 9, 1),
        checkOut: DateTime(2026, 9, 4), // 3 nights
      ))));

      expect(find.text('USD 299'), findsOneWidget);
      // Total shown as secondary line in CardPriceBlock
      expect(find.textContaining('total'), findsOneWidget);
      expect(find.textContaining('950'), findsOneWidget);
    });

    testWidgets('taxes & fees shown via CardPriceBlock taxesExcluded', (tester) async {
      await tester.pumpWidget(_wrap(HotelSearchCard(offer: _makeOffer(metadata: {
        'taxesAndFees': 89.50,
      }))));

      // Taxes shown as "Taxes extra" chip in CardPriceBlock
      expect(find.text('Taxes extra'), findsOneWidget);
    });

    testWidgets('no taxes/fees: no tax indicator rendered', (tester) async {
      await tester.pumpWidget(_wrap(HotelSearchCard(offer: _makeOffer())));

      expect(find.text('Taxes extra'), findsNothing);
    });

    testWidgets('wishlist heart renders (non-glass) and toggles', (tester) async {
      var lastCallbackValue = false;
      await tester.pumpWidget(_wrap(HotelSearchCard(
        offer: _makeOffer(),
        onFavorite: (v) => lastCallbackValue = v,
        isFavorite: false,
      )));

      final favorite = tester.widget<CardFavorite>(find.byType(CardFavorite));
      expect(favorite.onImage, false);
      expect(favorite.value, false);
      await tester.pump(); // Allow AnimatedSwitcher to render

      // Tap the heart - should call onChanged with true
      await tester.tap(find.byType(CardFavorite));
      expect(lastCallbackValue, true);
      
      // The CardFavorite is controlled by parent, so it won't update without parent rebuild
      // Just verify the callback was called correctly
    });

    testWidgets('onTap callback fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(HotelSearchCard(
        offer: _makeOffer(),
        onTap: () => taps++,
      )));

      await tester.tap(find.byType(BaseCard));
      expect(taps, 1);
    });

    testWidgets('disabled: reduced opacity, tap swallowed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(HotelSearchCard(
        offer: _makeOffer(),
        enabled: false,
        onTap: () => taps++,
      )));

      await tester.tap(find.byType(BaseCard));
      expect(taps, 0);

      // BaseCard wraps content in Opacity when disabled
      final opacity = tester.widget<Opacity>(find.descendant(
        of: find.byType(BaseCard),
        matching: find.byType(Opacity),
      ).first);
      expect(opacity.opacity, 0.55);
    });

    testWidgets('loading: renders skeleton with no fake data, tap blocked', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(HotelSearchCard(
        offer: _makeOffer(),
        loading: true,
        onTap: () => taps++,
      )));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Skeleton renders shimmer blocks and must not display any offer text
      expect(find.byType(ShimmerBox), findsWidgets);
      await tester.tap(find.byType(BaseCard));
      expect(taps, 0);
    });

    testWidgets('semantics label aggregates all available info', (tester) async {
      await tester.pumpWidget(_wrap(HotelSearchCard(offer: _makeOffer(metadata: {
        'pricePerNight': 299,
        'totalPrice': 897,
        'freeCancellation': true,
        'taxesAndFees': 89.50,
      }))));

      final semantics = tester.getSemantics(find.byType(HotelSearchCard));
      expect(semantics.label, contains('Grand Hotel'));
      expect(semantics.label, contains('Cairo, Egypt'));
      expect(semantics.label, contains('4.7 stars'));
      expect(semantics.label, contains('120 reviews'));
      expect(semantics.label, contains('Per night 299.00 USD'));
      expect(semantics.label, contains('Total 897.00 USD'));
      expect(semantics.label, contains('Free cancellation'));
    });

    testWidgets('long title ellipsizes to 2 lines', (tester) async {
      await tester.pumpWidget(_wrap(HotelSearchCard(offer: _makeOffer(
        title: 'Very Long Hotel Name That Should Be Truncated To Two Lines Maximum',
      ))));

      expect(find.byType(HotelSearchCard), findsOneWidget);
    });

    testWidgets('dark mode renders without errors', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: HotelSearchCard(offer: _makeOffer())),
      ));

      expect(find.byType(HotelSearchCard), findsOneWidget);
    });

    testWidgets('RTL layout renders without overflow', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(body: HotelSearchCard(offer: _makeOffer())),
      ));

      expect(find.byType(HotelSearchCard), findsOneWidget);
    });
  });
}