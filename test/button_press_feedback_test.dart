import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/ui/app_button.dart';
import 'package:tokigo/core/widgets/app_icon_action.dart';
import 'package:tokigo/core/widgets/cards/base_card.dart';
import 'package:tokigo/core/widgets/cards/card_favorite.dart';
import 'package:tokigo/core/widgets/cards/card_primary_action.dart';

void main() {
  test('both themes disable ripples and icon-button press circles', () {
    for (final ThemeData theme in <ThemeData>[
      AppTheme.light(),
      AppTheme.dark(),
    ]) {
      expect(theme.splashFactory, NoSplash.splashFactory);
      expect(
        theme.iconButtonTheme.style!.overlayColor!.resolve(<WidgetState>{
          WidgetState.pressed,
        }),
        Colors.transparent,
      );
      expect(theme.highlightColor, isNot(Colors.transparent));
    }
  });

  testWidgets('AppButton scales while pressed without an ink ripple', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppButton(label: 'Continue', onPressed: () {}),
        ),
      ),
    );

    final Finder button = find.text('Continue');
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(button),
    );
    await tester.pump(const Duration(milliseconds: 30));

    final Finder scale = find
        .ancestor(of: button, matching: find.byType(AnimatedScale))
        .first;
    expect(tester.widget<AnimatedScale>(scale).scale, lessThan(1));
    expect(find.byType(InkRipple), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
  });

  testWidgets('BaseCard removes its shadow during press feedback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: BaseCard(
              onTap: () {},
              child: const SizedBox(width: 120, height: 60),
            ),
          ),
        ),
      ),
    );

    final Finder card = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Container && widget.decoration is BoxDecoration,
    );
    BoxDecoration decoration() =>
        tester.widget<Container>(card).decoration! as BoxDecoration;

    expect(decoration().boxShadow, isNotEmpty);
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(BaseCard)),
    );
    await tester.pump(const Duration(milliseconds: 30));
    expect(decoration().boxShadow, isNull);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(decoration().boxShadow, isNotEmpty);
  });

  testWidgets('card actions scale while pressed without adding a ripple', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: <Widget>[
              CardPrimaryAction(label: 'Book', onPressed: () {}),
              CardFavorite(value: false, onChanged: (_) {}),
            ],
          ),
        ),
      ),
    );

    final Finder book = find.text('Book');
    final TestGesture bookGesture = await tester.startGesture(
      tester.getCenter(book),
    );
    await tester.pump(const Duration(milliseconds: 30));
    final Finder primaryScale = find.ancestor(
      of: book,
      matching: find.byType(AnimatedScale),
    );
    expect(tester.widget<AnimatedScale>(primaryScale.first).scale, lessThan(1));
    await bookGesture.up();
    await tester.pumpAndSettle();

    final Finder favorite = find.byType(CardFavorite);
    final TestGesture favoriteGesture = await tester.startGesture(
      tester.getCenter(favorite),
    );
    await tester.pump(const Duration(milliseconds: 30));
    final Finder favoriteScale = find.descendant(
      of: favorite,
      matching: find.byType(AnimatedScale),
    );
    expect(
      tester.widget<AnimatedScale>(favoriteScale.first).scale,
      lessThan(1),
    );
    await favoriteGesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(InkRipple), findsNothing);
  });

  testWidgets('AppIconAction scales and removes its shadow while pressed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppIconAction(
            icon: Icons.close,
            onTap: () {},
            variant: AppIconActionVariant.disc,
            showTooltip: false,
          ),
        ),
      ),
    );

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.close)),
    );
    await tester.pump(const Duration(milliseconds: 30));

    final AnimatedScale scale = tester.widget<AnimatedScale>(
      find.byType(AnimatedScale),
    );
    expect(scale.scale, lessThan(1));
    final AnimatedContainer disc = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect((disc.decoration! as BoxDecoration).boxShadow, isNull);

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
