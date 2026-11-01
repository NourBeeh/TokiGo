import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/ui/app_wordmark.dart';

/// The brand mark is a fixed shape, so it is pinned here rather than left to
/// each surface: one font, one weight, one tracking, one gap, one colour pair —
/// and the same numbers inside `tool/branding/generate_wordmark.py`, which
/// renders the splash raster the native splash screen shows.
///
/// A drift in any of these is a logo that differs between the splash and the
/// app, which is exactly the defect these tests exist to prevent.
void main() {
  TextStyle styleOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!;

  Future<void> pumpMark(
    WidgetTester tester, {
    TextStyle? base,
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Center(
              child: AppWordmark(base: base ?? AppTypography.forLight().title),
            ),
          ),
        ),
      ),
    );
  }

  group('AppWordmark', () {
    testWidgets('uses the brand colours for the two halves', (
      WidgetTester tester,
    ) async {
      await pumpMark(tester);

      expect(styleOf(tester, 'Toki').color, AppColors.wordmarkInk);
      expect(styleOf(tester, 'Go').color, AppColors.brandRed);
      expect(AppColors.wordmarkInk, AppColors.brand);
      expect(AppColors.brandRed, const Color(0xFFFF2D2D));
    });

    testWidgets('is Manrope ExtraBold, whatever typography step it is given', (
      WidgetTester tester,
    ) async {
      await pumpMark(tester, base: AppTypography.forLight().body);

      for (final String half in <String>['Toki', 'Go']) {
        final TextStyle style = styleOf(tester, half);
        expect(style.fontFamily, AppWordmark.fontFamily);
        expect(style.fontFamily, 'Manrope');
        expect(style.fontWeight, FontWeight.w800);
      }
    });

    testWidgets('scales its tracking and gap with the type step', (
      WidgetTester tester,
    ) async {
      const double size = AppTypography.fontSizeHeadline;
      await pumpMark(
        tester,
        base: const TextStyle(fontSize: size, fontFamily: 'Cairo'),
      );

      expect(styleOf(tester, 'Toki').letterSpacing, size * AppWordmark.trackingEm);
      final SizedBox gap = tester.widget<SizedBox>(
        find.byType(SizedBox).first,
      );
      expect(gap.width, size * AppWordmark.gapEm);
      // The regression that started this: the header's 25px mark kept its
      // -0.3px tracking when it was re-drawn at 36px.
      expect(
        AppTypography.fontSizeTitle * AppWordmark.trackingEm,
        moreOrLessEquals(-0.3, epsilon: 0.001),
      );
    });

    testWidgets('keeps its letterforms in an Arabic (RTL) session', (
      WidgetTester tester,
    ) async {
      AppTypography.isArabicLocale = true;
      addTearDown(() => AppTypography.isArabicLocale = false);

      await pumpMark(
        tester,
        base: AppTypography.forLight().title,
        direction: TextDirection.rtl,
      );

      // Copy turns to Cairo in Arabic; the logotype must not.
      expect(styleOf(tester, 'Toki').fontFamily, 'Manrope');
      expect(styleOf(tester, 'Go').fontFamily, 'Manrope');
      expect(
        tester.getTopLeft(find.text('Toki')).dx,
        lessThan(tester.getTopLeft(find.text('Go')).dx),
        reason: 'RTL must not mirror the mark into "GoToki"',
      );
    });
  });

  group('splash raster spec', () {
    late String generator;

    setUpAll(() {
      final File file = File('tool/branding/generate_wordmark.py');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'the splash masters are generated; the generator must exist',
      );
      generator = file.readAsStringSync();
    });

    /// Reads one `NAME = value` constant out of the generator.
    String constant(String name) {
      final RegExpMatch? match = RegExp(
        '^$name\\s*=\\s*(.+?)\\s*(?:#.*)?\$',
        multiLine: true,
      ).firstMatch(generator);
      expect(match, isNotNull, reason: '$name is missing from the generator');
      return match!.group(1)!;
    }

    test('mirrors the widget spec', () {
      expect(double.parse(constant('TRACKING_EM')), AppWordmark.trackingEm);
      expect(double.parse(constant('GAP_EM')), AppWordmark.gapEm);
      expect(num.parse(constant('WEIGHT')), AppWordmark.markWeight.value);
      expect(constant('FONT_PATH'), contains(AppWordmark.fontFamily));
    });

    test('mirrors the brand colours', () {
      Color parseRgbTuple(String value) {
        final List<String> parts = RegExp(r'0x([0-9A-Fa-f]{2})')
            .allMatches(value)
            .map((RegExpMatch m) => m.group(1)!)
            .toList();
        expect(parts.length, 3, reason: 'expected an (r, g, b) tuple: $value');
        return Color.fromARGB(
          0xFF,
          int.parse(parts[0], radix: 16),
          int.parse(parts[1], radix: 16),
          int.parse(parts[2], radix: 16),
        );
      }

      expect(parseRgbTuple(constant('INK')), AppColors.wordmarkInk);
      expect(parseRgbTuple(constant('GO')), AppColors.brandRed);
    });
  });
}
