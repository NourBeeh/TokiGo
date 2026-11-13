import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/cards/card_favorite.dart';
import 'package:tokigo/features/home/presentation/widgets/cover_flow_carousel.dart';
import 'package:tokigo/features/home/presentation/widgets/home_split_stay_card.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stays_carousel.dart';

/// Home's "Stays Near You" split card (owner decision, 2026-11).
///
/// * a horizontal 60/40 split — the photo is the larger share;
/// * the photo sits on the STARTING side, so it mirrors in Arabic;
/// * the favourite heart is drawn directly on the photo (no white disc);
/// * the skeleton keeps the loaded geometry;
/// * the rail still runs the shared 3D cover flow.
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

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  testWidgets('the photo takes the larger 60% share on the starting side', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const HomeSplitStayCard(
          media: ColoredBox(key: ValueKey<String>('media'), color: Colors.red),
          title: 'Riverside Grand',
          amountText: '186',
          currency: 'USD',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect splitRow = tester.getRect(
      find
          .descendant(
            of: find.byType(HomeSplitStayCard),
            matching: find.byType(Row),
          )
          .first,
    );
    final Rect media = tester.getRect(
      find.byKey(const ValueKey<String>('media')),
    );
    expect(media.width, closeTo(splitRow.width * 0.6, 1));
    // LTR: the starting side is the left.
    expect(media.left, closeTo(splitRow.left, 1));
  });

  testWidgets('the photo mirrors to the starting side in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const HomeSplitStayCard(
          media: ColoredBox(key: ValueKey<String>('media'), color: Colors.red),
          title: 'Riverside Grand',
          amountText: '186',
          currency: 'USD',
        ),
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();

    final Rect splitRow = tester.getRect(
      find
          .descendant(
            of: find.byType(HomeSplitStayCard),
            matching: find.byType(Row),
          )
          .first,
    );
    final Rect media = tester.getRect(
      find.byKey(const ValueKey<String>('media')),
    );
    expect(media.width, closeTo(splitRow.width * 0.6, 1));
    // RTL: the starting side is the right.
    expect(media.right, closeTo(splitRow.right, 1));
  });

  testWidgets('the favourite heart has no white disc platter', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeSplitStayCard(
          media: const ColoredBox(color: Colors.red),
          title: 'Riverside Grand',
          amountText: '186',
          currency: 'USD',
          onFavorite: (_) {},
          showHeartPlatter: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CardFavorite), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CardFavorite),
        matching: find.byType(HeartPlatter),
      ),
      findsNothing,
    );
    // The action is still wired and the card still renders.
    await tester.tap(find.byType(CardFavorite));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the skeleton keeps the loaded split geometry', (tester) async {
    Widget card({required bool loading}) => SizedBox(
          width: 288,
          height: 360,
          child: loading
              ? const HomeSplitStayCard.loading()
              : const HomeSplitStayCard(
                  media: ColoredBox(color: Colors.red),
                  title: 'Riverside Grand',
                  amountText: '186',
                  currency: 'USD',
                ),
        );

    await tester.pumpWidget(_host(card(loading: true)));
    await tester.pump(const Duration(milliseconds: 300));
    final Rect skeleton = tester.getRect(find.byType(HomeSplitStayCard));

    await tester.pumpWidget(_host(card(loading: false)));
    await tester.pump(const Duration(milliseconds: 300));
    final Rect loaded = tester.getRect(find.byType(HomeSplitStayCard));

    expect(skeleton.size, loaded.size);
    expect(skeleton.topLeft, loaded.topLeft);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Home rail opts into the split and keeps the cover flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1480);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        HomeStaysCarousel(
          items: <HomeItem>[_stay('a')],
          splitLayout: true,
          showHeartPlatter: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CoverFlowCarousel), findsOneWidget);
    expect(find.byType(HomeSplitStayCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CardFavorite),
        matching: find.byType(HeartPlatter),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
