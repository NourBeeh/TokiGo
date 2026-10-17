import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/widgets/cards/card_image.dart';

void main() {
  group('CardImage unified source resolver', () {
    test('isAssetSource detects bundled assets', () {
      expect(CardImage.isAssetSource('assets/images/placeholder_hotel.png'), isTrue);
      expect(CardImage.isAssetSource('assets/images/x.png'), isTrue);
    });

    test('isAssetSource rejects network urls', () {
      expect(CardImage.isAssetSource('https://example.com/img.jpg'), isFalse);
      expect(CardImage.isAssetSource('http://example.com/img.jpg'), isFalse);
      expect(CardImage.isAssetSource('/absolute/path.png'), isFalse);
    });

    testWidgets('asset url renders Image.asset without network access',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CardImage(
              url: 'assets/images/placeholder_hotel.png',
              fit: BoxFit.cover,
              semanticLabel: 'Hotel placeholder',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
    });

    testWidgets('network url still renders Image.network for the live API',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CardImage(url: 'https://example.com/img.jpg'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<NetworkImage>());
    });

    testWidgets('missing asset degrades to fallback without crashing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CardImage(
              url: 'assets/images/does_not_exist.png',
              fallbackIcon: Icons.hotel,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // errorBuilder path: no Image exception escapes, icon fallback shown
      expect(find.byIcon(Icons.hotel), findsOneWidget);
    });
  });
}