import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/cards/card_favorite.dart';
import 'package:tokigo/core/widgets/cards/card_glass.dart';

void _noop(bool _) {}

void main() {
  testWidgets('on-image favorite icon stays legible in Dark mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: CardFavorite(value: false, onChanged: (_) {}, onImage: true),
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(Icons.favorite_border_rounded)).color,
      AppColors.textPrimary,
    );
  });

  testWidgets('favorite sits on a soft white disc, not a glass square', (
    WidgetTester tester,
  ) async {
    const double size = 40;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Center(
          child: CardFavorite(
            value: false,
            onChanged: _noop,
            onImage: true,
            size: size,
          ),
        ),
      ),
    );

    // The old frosted-glass square is gone; one circular platter replaces it.
    expect(find.byType(CardGlass), findsNothing);
    expect(find.byType(HeartPlatter), findsOneWidget);
    expect(tester.widget<HeartPlatter>(find.byType(HeartPlatter)).diameter, size);

    final Container disc = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(HeartPlatter),
            matching: find.byType(Container),
          )
          .first,
    );
    final BoxDecoration deco = disc.decoration! as BoxDecoration;
    expect(deco.shape, BoxShape.circle);
    // White disc whose edge is a shadow, per AppColors.onMediaFill.
    expect(deco.color, AppColors.onMediaFill);

    // The heart is sized to the disc (half its diameter).
    final Icon heartIcon = tester.widget<Icon>(
      find.byIcon(Icons.favorite_border_rounded),
    );
    expect(heartIcon.size, closeTo(size * 0.5, 0.01));

    // The saved heart keeps the brand-red accent on the disc.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Center(
          child: CardFavorite(
            value: true,
            onChanged: _noop,
            onImage: true,
            size: size,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });
}
