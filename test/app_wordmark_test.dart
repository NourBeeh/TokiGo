import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/ui/app_wordmark.dart';

void main() {
  testWidgets('wordmark ink follows the active theme', (
    WidgetTester tester,
  ) async {
    const wordmark = AppWordmark(base: TextStyle(fontSize: 24));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: wordmark),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Toki')).style?.color,
      TokiGoColors.light().wordmarkInk,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: wordmark),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Toki')).style?.color,
      TokiGoColors.dark().wordmarkInk,
    );
  });
}
