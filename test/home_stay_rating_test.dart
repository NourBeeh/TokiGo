import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_item.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/features/home/presentation/widgets/home_stay_card.dart';

/// The Home stay card's review-average honesty (owner decision, 2026-11).
///
/// A rating average is shown ONLY when real review data backs it — never for a
/// stay with no review count, and never invented.
void main() {
  Widget hostOf(HomeItem item) => ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 320, child: HomeStayCard(item: item)),
        ),
      ),
    ),
  );

  HomeItem stay({int? reviewCount}) => HomeItem(
    id: 'a',
    type: HomeCardType.hotel,
    title: 'Riverside Grand',
    subtitle: 'Lisbon',
    price: 186,
    currency: 'USD',
    rating: 4.8,
    reviewCount: reviewCount,
    metadata: const <String, dynamic>{'city': 'Lisbon'},
  );

  testWidgets('a rating backed by real reviews is shown', (tester) async {
    await tester.pumpWidget(hostOf(stay(reviewCount: 48)));
    await tester.pumpAndSettle();
    // The reference card renders the five-star score plus the review count.
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    expect(find.text('48 reviews'), findsOneWidget);
  });

  testWidgets('a rating with no review data is hidden', (tester) async {
    await tester.pumpWidget(hostOf(stay(reviewCount: 0)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.text('48 reviews'), findsNothing);
  });

  testWidgets('a missing review count hides the average', (tester) async {
    await tester.pumpWidget(hostOf(stay()));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.text('48 reviews'), findsNothing);
  });
}
