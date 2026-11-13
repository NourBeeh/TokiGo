import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/app_icon_action.dart';

void main() {
  testWidgets('media disc icon remains legible in Dark mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: AppIconAction(
          icon: Icons.arrow_back_rounded,
          onTap: () {},
          variant: AppIconActionVariant.disc,
          showTooltip: false,
        ),
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(Icons.arrow_back_rounded)).color,
      AppColors.textPrimary,
    );
  });

  testWidgets('plain variant keeps the floating geometry without a fill', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AppIconAction(
          icon: Icons.arrow_back_rounded,
          onTap: () {},
          variant: AppIconActionVariant.plain,
          showTooltip: false,
        ),
      ),
    );

    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.arrow_back_rounded));
    // The same floating geometry as the disc (20dp glyph in a 44dp box)…
    expect(icon.size, 20);
    // …but the ink is the on-media white and no disc fill is painted.
    expect(icon.color, Colors.white);
  });
}
