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
}
