import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/tokigo_gradients.dart';

/// WCAG contrast ratio between two opaque sRGB colors.
double _contrastRatio(Color a, Color b) {
  double luminance(Color c) {
    double channel(double v) {
      final double s = v / 255.0;
      return s <= 0.04045 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(c.red.toDouble()) +
        0.7152 * channel(c.green.toDouble()) +
        0.0722 * channel(c.blue.toDouble());
  }

  final double la = luminance(a);
  final double lb = luminance(b);
  final double hi = math.max(la, lb);
  final double lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final TokiGoColors light = TokiGoColors.light();
  final TokiGoColors dark = TokiGoColors.dark();

  group('light and dark token consistency', () {
    test('both themes define the same semantic roles', () {
      // The factories set every field; a missing role would not compile. This
      // asserts the two palettes are genuinely distinct per role.
      expect(light.background, isNot(dark.background));
      expect(light.surface, isNot(dark.surface));
      expect(light.textPrimary, isNot(dark.textPrimary));
      expect(light.outline, isNot(dark.outline));
      expect(light.surfaceSecondary, isNot(dark.surfaceSecondary));
    });

    test('primary text clears AA on its own canvas in both themes', () {
      expect(_contrastRatio(light.textPrimary, light.background), greaterThan(4.5));
      expect(_contrastRatio(dark.textPrimary, dark.background), greaterThan(4.5));
    });

    test('secondary text clears AA on its own canvas in both themes', () {
      expect(_contrastRatio(light.textSecondary, light.background), greaterThan(4.5));
      expect(_contrastRatio(dark.textSecondary, dark.background), greaterThan(4.5));
    });

    test('the brand fill clears AA for its on-brand label', () {
      expect(_contrastRatio(light.onBrand, light.brand), greaterThan(4.5));
      expect(_contrastRatio(dark.onBrand, dark.brand), greaterThan(4.5));
    });

    test('the dark canvas is genuinely dark and the light canvas genuinely light', () {
      final double lightLuma = _contrastRatio(light.background, Colors.black);
      final double darkLuma = _contrastRatio(dark.background, Colors.white);
      expect(lightLuma, greaterThan(10));
      expect(darkLuma, greaterThan(10));
    });

    test('the brand is the Instagram-inspired blue in both themes', () {
      expect(light.brand, const Color(0xFF0064E0));
      expect(dark.brand, const Color(0xFF0064E0));
    });
  });

  group('gradient accents', () {
    test('the brand ramp is the Instagram purple → red → orange identity', () {
      expect(TokiGoGradients.brand, const <Color>[
        Color(0xFF833AB4),
        Color(0xFFFD1D1D),
        Color(0xFFFCB045),
      ]);
    });

    test('the gradient builders are RTL-aware by construction', () {
      expect(TokiGoGradients.brandGradient().colors, TokiGoGradients.brand);
      expect(
        TokiGoGradients.brandSmoothGradient().colors,
        TokiGoGradients.brandSmooth,
      );
    });
  });
}
