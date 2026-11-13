import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/widgets/compact_step_button.dart';
import 'package:tokigo/core/widgets/compact_stepper_row.dart';

/// The shared compact stepper row (owner decision, 2026-11).
///
/// ONE row recipe for the flight passenger sheet and the hotel occupancy
/// card, so the two selectors are the same control:
/// * the label, the 28dp value box and the 30dp +/- controls;
/// * a null callback renders that control DISABLED (muted fill/ink) and inert;
/// * the row mirrors in RTL;
/// * each control announces its action to screen readers.
Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: child),
    ),
  );
}

/// The colour of the icon inside the [index]th stepper button.
Color _iconColor(WidgetTester tester, int index) => tester
    .widget<Icon>(
      find.descendant(
        of: find.byType(CompactStepButton).at(index),
        matching: find.byType(Icon),
      ),
    )
    .color!;

void main() {
  final TokiGoColors colors = TokiGoColors.light();

  testWidgets('the row renders the shared label / value / +/- geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const CompactStepperRow(
          label: 'Adults',
          value: 2,
          onDecrement: null,
          onIncrement: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Adults'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(CompactStepButton), findsNWidgets(2));

    // Both controls are the shared 30dp square.
    expect(tester.getSize(find.byType(CompactStepButton).at(0)), const Size(30, 30));
    expect(tester.getSize(find.byType(CompactStepButton).at(1)), const Size(30, 30));

    // The value column is the shared fixed 28dp box.
    final SizedBox valueBox = tester.widget<SizedBox>(
      find.ancestor(of: find.text('2'), matching: find.byType(SizedBox)).first,
    );
    expect(valueBox.width, 28);
  });

  testWidgets('a null callback renders that control disabled and inert', (
    tester,
  ) async {
    int value = 1;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) =>
              CompactStepperRow(
                label: 'Adults',
                value: value,
                onDecrement: null,
                onIncrement: () => setState(() => value++),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Minus is disabled (muted), plus is enabled (brand).
    expect(_iconColor(tester, 0), colors.textTertiary);
    expect(_iconColor(tester, 1), colors.brand);
    expect(
      tester.widget<Material>(
        find
            .descendant(
              of: find.byType(CompactStepButton).at(0),
              matching: find.byType(Material),
            )
            .first,
      ).color,
      colors.surfaceTertiary,
    );

    // Tapping the disabled control does nothing.
    await tester.tap(find.byType(CompactStepButton).at(0));
    await tester.pump();
    expect(value, 1);
    expect(find.text('1'), findsOneWidget);

    // The enabled control works.
    await tester.tap(find.byType(CompactStepButton).at(1));
    await tester.pump();
    expect(value, 2);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('the row mirrors in RTL: the label leads and plus trails', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const CompactStepperRow(
          label: 'Adults',
          value: 1,
          onDecrement: null,
          onIncrement: null,
        ),
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();

    final Rect label = tester.getRect(find.text('Adults'));
    final Rect minus = tester.getRect(find.byType(CompactStepButton).at(0));
    final Rect plus = tester.getRect(find.byType(CompactStepButton).at(1));

    // RTL: the label is on the starting (right) side; plus is on the far left.
    expect(label.right, greaterThan(minus.right));
    expect(plus.right, lessThan(minus.left));
  });

  testWidgets('the row keeps the LTR order: label left, plus right', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const CompactStepperRow(
          label: 'Adults',
          value: 1,
          onDecrement: null,
          onIncrement: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect label = tester.getRect(find.text('Adults'));
    final Rect minus = tester.getRect(find.byType(CompactStepButton).at(0));
    final Rect plus = tester.getRect(find.byType(CompactStepButton).at(1));

    expect(label.left, lessThan(minus.left));
    expect(plus.left, greaterThan(minus.right));
  });

  testWidgets('each control announces its action exactly once', (tester) async {
    await tester.pumpWidget(
      _host(
        const CompactStepperRow(
          label: 'Adults',
          value: 1,
          onDecrement: null,
          onIncrement: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder decrease = find.byWidgetPredicate(
      (Widget w) => w is Semantics && w.properties.label == 'Decrease Adults',
    );
    final Finder increase = find.byWidgetPredicate(
      (Widget w) => w is Semantics && w.properties.label == 'Increase Adults',
    );

    expect(decrease, findsOneWidget);
    expect(increase, findsOneWidget);
    expect(tester.widget<Semantics>(decrease).properties.button, isTrue);
    expect(tester.widget<Semantics>(increase).properties.button, isTrue);
  });

  testWidgets('a disabled control is announced as disabled', (tester) async {
    await tester.pumpWidget(
      _host(
        const CompactStepperRow(
          label: 'Adults',
          value: 1,
          onDecrement: null,
          onIncrement: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Semantics decrease = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (Widget w) => w is Semantics && w.properties.label == 'Decrease Adults',
      ),
    );
    expect(decrease.properties.enabled, isFalse);
  });

  testWidgets('an enabled control is announced as enabled', (tester) async {
    await tester.pumpWidget(
      _host(
        const CompactStepperRow(
          label: 'Adults',
          value: 1,
          onDecrement: null,
          onIncrement: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Semantics increase = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (Widget w) => w is Semantics && w.properties.label == 'Increase Adults',
      ),
    );
    expect(increase.properties.enabled, isTrue);
  });
}

void _noop() {}
