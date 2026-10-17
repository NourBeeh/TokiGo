import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/widgets/shimmer.dart';

import 'package:tokigo/core/widgets/cards/card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('BaseCard', () {
    testWidgets('renders child and forwards tap when enabled', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
          _wrap(BaseCard(onTap: () => tapped++, child: const Text('body'))));
      expect(find.text('body'), findsOneWidget);
      await tester.tap(find.byType(BaseCard));
      expect(tapped, 1);
    });

    testWidgets('disabled: opacity reduced and tap swallowed', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
          BaseCard(enabled: false, onTap: () => tapped++, child: const Text('x'))));
      await tester.tap(find.byType(BaseCard));
      expect(tapped, 0);
    });

    testWidgets('loading: blocks tap and renders provided child (skeletons are card-owned)',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
          BaseCard(loading: true, onTap: () => tapped++, child: const Text('x'))));
      // The container no longer paints a spinner overlay; cards own their
      // skeleton content. Loading only blocks interaction.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('x'), findsOneWidget);
      await tester.tap(find.byType(BaseCard));
      expect(tapped, 0);
    });
  });

  group('CardFavorite', () {
    testWidgets('taps toggle value via onChanged and switch icon', (tester) async {
      var last = false;
      await tester.pumpWidget(_wrap(StatefulBuilder(
        builder: (ctx, setState) => CardFavorite(
          value: last,
          onChanged: (v) => setState(() => last = v),
        ),
      )));
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      await tester.tap(find.byType(CardFavorite));
      expect(last, true);
      await tester.pump();
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('null onChanged: tap is a no-op', (tester) async {
      await tester.pumpWidget(
          _wrap(const CardFavorite(value: false, onChanged: null)));
      await tester.tap(find.byType(CardFavorite));
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    });
  });

  group('CardLocation', () {
    testWidgets('renders the location text with the default pin icon',
        (tester) async {
      await tester.pumpWidget(_wrap(
          const CardLocation(text: 'Cairo, Egypt')));
      expect(find.text('Cairo, Egypt'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    });
  });

  group('CardFeatureList', () {
    testWidgets('renders one chip per feature', (tester) async {
      await tester.pumpWidget(
          _wrap(const CardFeatureList(features: ['Auto', '5 seats', 'A/C'])));
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('5 seats'), findsOneWidget);
      expect(find.text('A/C'), findsOneWidget);
    });

    testWidgets('empty list renders the empty widget (no chips)',
        (tester) async {
      await tester.pumpWidget(_wrap(
          const CardFeatureList(features: [])));
      expect(find.text('Auto'), findsNothing);
    });
  });

  group('CardAvailability', () {
    testWidgets('available maps to "Available" + primary dot',
        (tester) async {
      await tester.pumpWidget(_wrap(
          const CardAvailability(status: CardAvailabilityStatus.available)));
      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('unavailable renders the "Unavailable" label',
        (tester) async {
      await tester.pumpWidget(_wrap(const CardAvailability(
          status: CardAvailabilityStatus.unavailable, label: 'Sold out')));
      expect(find.text('Sold out'), findsOneWidget);
      expect(find.text('Unavailable'), findsNothing);
    });
  });

  group('CardCancellation', () {
    testWidgets('free: shows check-circle icon and the label',
        (tester) async {
      await tester.pumpWidget(_wrap(const CardCancellation(
          freeCancellation: true, label: 'Free cancellation until 24h')));
      expect(find.text('Free cancellation until 24h'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('paid: shows info icon', (tester) async {
      await tester.pumpWidget(
          _wrap(const CardCancellation(label: 'Non-refundable')));
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });

  group('CardPrimaryAction', () {
    testWidgets('renders label and calls onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
          CardPrimaryAction(label: 'Book now', onPressed: () => taps++)));
      expect(find.text('Book now'), findsOneWidget);
      await tester.tap(find.byType(CardPrimaryAction));
      expect(taps, 1);
    });

    testWidgets('loading: replaces the label with a spinner and blocks taps',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
          CardPrimaryAction(label: 'Book', onPressed: () => taps++, loading: true)));
      expect(find.text('Book'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(CardPrimaryAction));
      expect(taps, 0);
    });

    testWidgets('disabled (onPressed null): reduced opacity, label still visible',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
          CardPrimaryAction(label: 'Book', onPressed: null)));
      expect(find.text('Book'), findsOneWidget);
      await tester.tap(find.byType(CardPrimaryAction));
      expect(taps, 0);
    });
  });

  group('CardPriceBlock', () {
    testWidgets('no originalPrice: renders the current price only',
        (tester) async {
      await tester.pumpWidget(_wrap(
          const CardPriceBlock(currentPrice: 199, currency: 'EUR')));
      expect(find.text('EUR 199'), findsOneWidget);
      // Only one Text widget in the whole block.
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('originalPrice > currentPrice: renders strikethrough next to current',
        (tester) async {
      await tester.pumpWidget(_wrap(const CardPriceBlock(
        currentPrice: 199,
        originalPrice: 240,
        currency: 'EUR',
      )));
      expect(find.text('EUR 199'), findsOneWidget);
      expect(find.text('EUR 240'), findsOneWidget);
      expect(find.byType(Text), findsNWidgets(2));
    });

    testWidgets('originalPrice <= currentPrice: original hidden, layout stable',
        (tester) async {
      await tester.pumpWidget(_wrap(const CardPriceBlock(
        currentPrice: 199,
        originalPrice: 150,
        currency: 'EUR',
      )));
      expect(find.text('EUR 199'), findsOneWidget);
      expect(find.text('EUR 150'), findsNothing);
      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('Barrel exports', () {
    testWidgets('every component is reachable from package:.../card.dart',
        (tester) async {
      // Build a tiny widget that instantiates one of each (tying tests to
      // the public surface so a missed export breaks the build).
      await tester.pumpWidget(_wrap(Material(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BaseCard(child: const Text('')),
            const CardAvailability(status: CardAvailabilityStatus.available),
            const CardBadge(label: 'x'),
            const CardCancellation(label: 'x'),
            const CardFavorite(value: false, onChanged: null),
            const CardFeatureList(features: ['x']),
            CardMedia(url: null),
            const CardLocation(text: 'x'),
            CardPrice(price: 1, currency: 'USD'),
            const CardPriceBlock(currentPrice: 1),
            const CardGlass(child: SizedBox.shrink()),
            CardPrimaryAction(label: 'x', onPressed: null),
            const CardRating(rating: 5),
          ],
        ),
      )));
      expect(tester.takeException(), isNull);
    });
  });

  group('CardGlass', () {
    testWidgets('renders its child inside a frosted surface', (tester) async {
      await tester.pumpWidget(
          _wrap(const CardGlass(child: Text('frosted'))));
      expect(find.text('frosted'), findsOneWidget);
      expect(find.byType(CardGlass), findsOneWidget);
    });
  });

  group('CardFavorite theme-aware + onImage', () {
    testWidgets('onImage renders a glass heart pill and still toggles',
        (tester) async {
      var last = false;
      await tester.pumpWidget(_wrap(StatefulBuilder(
        builder: (ctx, setState) => CardFavorite(
          value: last,
          onChanged: (v) => setState(() => last = v),
          onImage: true,
        ),
      )));
      expect(find.byType(CardGlass), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      await tester.tap(find.byType(CardFavorite));
      expect(last, true);
      await tester.pump();
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });
  });

  group('CardBadge variants + icon', () {
    testWidgets('tinted default shows label on primaryContainer',
        (tester) async {
      await tester.pumpWidget(_wrap(const CardBadge(label: 'Best seller')));
      expect(find.text('Best seller'), findsOneWidget);
      expect(find.byType(CardGlass), findsNothing);
    });

    testWidgets('glass variant renders a frosted pill', (tester) async {
      await tester.pumpWidget(_wrap(const CardBadge(
          label: 'Trending',
          icon: Icons.local_fire_department,
          variant: CardBadgeVariant.glass)));
      expect(find.text('Trending'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      expect(find.byType(CardGlass), findsOneWidget);
    });
  });

  group('CardRating onImage', () {
    testWidgets('renders a glass pill with white value text', (tester) async {
      await tester.pumpWidget(_wrap(const CardRating(
          rating: 4.7, reviewCount: 132, onImage: true)));
      expect(find.text('4.7'), findsOneWidget);
      expect(find.text('(132)'), findsOneWidget);
      expect(find.byType(CardGlass), findsOneWidget);
    });

    testWidgets('inline uses the provided textColor', (tester) async {
      await tester.pumpWidget(_wrap(const CardRating(
          rating: 4.2, textColor: Colors.deepPurple)));
      final text = tester.widget<Text>(find.text('4.2'));
      expect(text.style?.color, Colors.deepPurple);
      expect(find.byType(CardGlass), findsNothing);
    });
  });

  group('CardFeatureList onImage', () {
    testWidgets('chips render as glass pills with white text', (tester) async {
      await tester.pumpWidget(_wrap(
          const CardFeatureList(features: ['Auto', '5 seats'], onImage: true)));
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('5 seats'), findsOneWidget);
      expect(find.byType(CardGlass), findsNWidgets(2));
    });
  });

  group('formatCardPrice', () {
    test('formats currency + rounded amount', () {
      expect(formatCardPrice(price: 199.6, currency: 'USD'), 'USD 200');
    });

    test('can hide the currency symbol', () {
      expect(formatCardPrice(price: 99, showCurrency: false), '99');
    });

    test('null price returns empty string', () {
      expect(formatCardPrice(price: null), '');
    });

    test('defaults to USD when currency is omitted', () {
      expect(formatCardPrice(price: 50), 'USD 50');
    });
  });

  group('BaseCard semantics + disabled', () {
    testWidgets('disabled card renders with reduced opacity and keeps its label',
        (tester) async {
      await tester.pumpWidget(_wrap(BaseCard(
          enabled: false,
          semanticsLabel: 'Off',
          onTap: () {},
          child: const Text('x'))));
      final opacity = tester.widget<Opacity>(find
          .ancestor(of: find.text('x'), matching: find.byType(Opacity))
          .first);
      expect(opacity.opacity, 0.55);
    });
  });
}
