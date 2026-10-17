import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/theme/app_colors.dart';

void main() {
  test('Light theme uses pure white surfaces', () {
    final theme = AppTheme.light();
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.surface, AppColors.surface);
    expect(theme.colorScheme.primary, AppColors.brand);
  });

  test('Theme is light-only by design', () {
    // The "Pure White Premium" design language ships a single light theme.
    expect(AppTheme.light().scaffoldBackgroundColor, AppColors.background);
  });
}
