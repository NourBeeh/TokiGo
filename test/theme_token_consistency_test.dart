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

    test('the primary action fill clears AA for its on-primary label', () {
      expect(_contrastRatio(light.onBrand, light.brand), greaterThan(4.5));
      expect(_contrastRatio(dark.onBrand, dark.brand), greaterThan(4.5));
    });

    test('the dark canvas is genuinely dark and the light canvas genuinely light', () {
      final double lightLuma = _contrastRatio(light.background, Colors.black);
      final double darkLuma = _contrastRatio(dark.background, Colors.white);
      expect(lightLuma, greaterThan(10));
      expect(darkLuma, greaterThan(10));
    });

    test('the accent is NEUTRAL in both themes — no brand hue remains', () {
      // Owner decision (2026-11): the blue #0064E0 accent is retired. The
      // primary action fill is the canvas's own ink: near-black on the light
      // canvas, near-white on the dark one.
      expect(light.brand, const Color(0xFF111111));
      expect(dark.brand, const Color(0xFFF5F5F5));
      // Neither palette's accent may carry a hue.
      expect(light.brand, isNot(const Color(0xFF0064E0)));
      expect(dark.brand, isNot(const Color(0xFF0064E0)));
      // The AI and info roles share the same neutral accent.
      expect(light.ai, light.brand);
      expect(dark.ai, dark.brand);
      expect(light.info, light.ink);
      expect(dark.info, dark.ink);
      // The feature hues are neutral too, so no rail reintroduces a colour.
      expect(light.brandContainer, const Color(0xFFF0F0F0));
      expect(dark.brandContainer, const Color(0xFF262626));
    });
  });

  group('Phase 3.2 monochrome policy', () {
    // Owner decision: the UI is strictly black/white/grey. The only red left in
    // the product is the TokiGo wordmark (brandRed / wordmarkOnMedia).
    bool isNeutral(Color c) {
      final int argb = c.toARGB32();
      final int r = (argb >> 16) & 0xFF;
      final int g = (argb >> 8) & 0xFF;
      final int b = argb & 0xFF;
      return r == g && g == b;
    }

    Map<String, Color> uiRoles(TokiGoColors c) => <String, Color>{
          'primary': c.primary,
          'onPrimary': c.onPrimary,
          'primaryContainer': c.primaryContainer,
          'onPrimaryContainer': c.onPrimaryContainer,
          'onDangerContainer': c.onDangerContainer,
          'danger': c.danger,
          'dangerContainer': c.dangerContainer,
          'heart': c.heart,
          'success': c.success,
          'successContainer': c.successContainer,
          'onSuccessContainer': c.onSuccessContainer,
          'successStrong': c.successStrong,
          'warning': c.warning,
          'warningContainer': c.warningContainer,
          'onWarningContainer': c.onWarningContainer,
          'warningInk': c.warningInk,
          'info': c.info,
          'infoContainer': c.infoContainer,
        };

    test('every UI semantic role is neutral in both themes', () {
      for (final TokiGoColors c in <TokiGoColors>[light, dark]) {
        uiRoles(c).forEach((String role, Color value) {
          expect(isNeutral(value), isTrue, reason: '$role carries a hue');
        });
      }
    });

    test('the wordmark keeps its red — the single permitted exception', () {
      expect(light.brandRed, const Color(0xFFFF2D2D));
      expect(dark.brandRed, const Color(0xFFFF5C5C));
      expect(light.brandRed.toARGB32() >> 16, greaterThan(0));
      expect(light.wordmarkOnMedia, const Color(0xFFFFC9C9));
    });

    test('the neutral status inks clear AA on their containers', () {
      expect(
        _contrastRatio(light.onSuccessContainer, light.successContainer),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(dark.onSuccessContainer, dark.successContainer),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(light.onWarningContainer, light.warningContainer),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(dark.onWarningContainer, dark.warningContainer),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(light.onDangerContainer, light.dangerContainer),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(dark.onDangerContainer, dark.dangerContainer),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(light.onPrimaryContainer, light.primaryContainer),
        greaterThan(4.5),
      );
      expect(
        _contrastRatio(dark.onPrimaryContainer, dark.primaryContainer),
        greaterThan(4.5),
      );
    });
  });

  group('gradient accents', () {
    test('the accent ramp is neutral — a value step, never a hue', () {
      // The former Instagram purple → red → orange ramp is retired: the ramp
      // keeps the same shape but steps through ink.
      expect(TokiGoGradients.brand, const <Color>[
        Color(0xFF262626),
        Color(0xFF5A5A5A),
        Color(0xFF8E8E8E),
      ]);
      for (final Color stop in TokiGoGradients.brandSmooth) {
        expect(stop.red, stop.green, reason: 'a neutral stop has no hue');
        expect(stop.green, stop.blue, reason: 'a neutral stop has no hue');
      }
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
