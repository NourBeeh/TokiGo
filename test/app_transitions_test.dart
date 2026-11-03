import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/navigation/app_transitions.dart';

void main() {
  for (final TextDirection direction in <TextDirection>[
    TextDirection.ltr,
    TextDirection.rtl,
  ]) {
    testWidgets('page transition enters from the physical right ($direction)', (
      WidgetTester tester,
    ) async {
      final SlideFromRightTransition page = SlideFromRightTransition(
        child: const SizedBox(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Builder(
              builder: (BuildContext context) => page.transitionsBuilder(
                context,
                const AlwaysStoppedAnimation<double>(0),
                const AlwaysStoppedAnimation<double>(0),
                const SizedBox(),
              ),
            ),
          ),
        ),
      );

      final SlideTransition transition = tester.widget<SlideTransition>(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is SlideTransition &&
              widget.position.value == const Offset(1, 0),
        ),
      );
      expect(transition.position.value, const Offset(1, 0));
    });
  }
}
