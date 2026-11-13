import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/presentation/home_card_dimensions.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stay_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stays_carousel.dart';

/// Section 5 — narrow-width and large-text-scale regressions for the Home
/// "Stays Near You" split card.
///
/// The 40% information column is the narrowest text surface in the Home feed.
/// At a large text scale — or on a 320pt phone — a fixed-width row inside it
/// would throw a `RenderFlex` overflow. The card must scale its rows down and
/// grow its height instead, so the facts are never clipped.
///
/// Every test pumps the real rail at a real size/scale and asserts that the
/// framework reported no overflow exception, i.e. the rendered layout fit.

const Size _phone = Size(720, 1480); // 360 x 740 logical
const Size _narrowPhone = Size(640, 1280); // 320 x 640 logical

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _setTextScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

HomeItem _stay(String id) => HomeItem(
      id: id,
      type: HomeCardType.hotel,
      title: 'Riverside Grand Hotel $id',
      subtitle: 'Lisbon',
      price: 186,
      currency: 'USD',
      rating: 4.8,
      reviewCount: 48,
      metadata: const <String, dynamic>{'city': 'Lisbon', 'stars': 5},
    );

Widget _railHost(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

Widget _splitRail(List<HomeItem> items) => HomeStaysCarousel(
      items: items,
      splitLayout: true,
      showHeartPlatter: false,
      viewportFraction: HomeCardDimensions.destinationViewportFraction,
      cardHeightBuilder: HomeStaysCarousel.splitCardHeightFor,
    );

void main() {
  group('Section 5 — split card overflow regressions', () {
    testWidgets('no overflow at a large text scale on a 360pt phone', (
      tester,
    ) async {
      _setView(tester, _phone);
      _setTextScale(tester, 2.0);

      await tester.pumpWidget(_railHost(_splitRail(<HomeItem>[_stay('a')])));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('186'), findsOneWidget);
    });

    testWidgets('no overflow on a 320pt phone at a 2.0x text scale', (
      tester,
    ) async {
      _setView(tester, _narrowPhone);
      _setTextScale(tester, 2.0);

      await tester.pumpWidget(_railHost(_splitRail(<HomeItem>[_stay('a')])));
      await tester.pump(const Duration(milliseconds: 300));

      // This is the case that used to throw "A RenderFlex overflowed by
      // 5.4 pixels on the right" from the rating row.
      expect(tester.takeException(), isNull);
      expect(find.text('186'), findsOneWidget);
    });

    testWidgets('no overflow in RTL at a large text scale on a 320pt phone', (
      tester,
    ) async {
      _setView(tester, _narrowPhone);
      _setTextScale(tester, 2.0);

      await tester.pumpWidget(
        _railHost(
          _splitRail(<HomeItem>[_stay('a')]),
          direction: TextDirection.rtl,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets('the card grows with the text scale instead of clipping', (
      tester,
    ) async {
      _setView(tester, _phone);

      await tester.pumpWidget(_railHost(_splitRail(<HomeItem>[_stay('a')])));
      await tester.pump(const Duration(milliseconds: 300));
      final Rect normal = tester.getRect(find.byType(HomeStayCard));

      _setTextScale(tester, 2.0);
      await tester.pumpWidget(_railHost(_splitRail(<HomeItem>[_stay('a')])));
      await tester.pump(const Duration(milliseconds: 300));
      final Rect scaled = tester.getRect(find.byType(HomeStayCard));

      // The height budget grows with the traveller's text scale so the facts
      // column keeps its room; the width stays the city card's page width.
      expect(scaled.height, greaterThan(normal.height));
      expect(scaled.width, normal.width);
      expect(tester.takeException(), isNull);
    });
  });
}
