import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/features/home/presentation/widgets/home_ai_search_field.dart';
import 'package:tokigo/l10n/app_localizations.dart';
import 'package:tokigo/l10n/app_localizations_en.dart';
import 'package:tokigo/l10n/app_localizations_ar.dart';

/// Typewriter hint contract for the Home AI search pill.
///
/// The hint self-writes the locale's `aiHintPhrase1..3` character by
/// character (~45ms/tick), holds the finished line, wipes it faster, then
/// rotates to the next phrase. These tests pin the observable contract:
///
///   * the first English phrase types progressively (one char after one
///     tick, the full line after enough ticks),
///   * rotation reaches the later phrases,
///   * the Arabic locale writes the Arabic phrases instead,
///   * and the pill never throws across locale switches.
///
/// NOTE: the aura animations loop forever, so pumps use explicit durations
/// (never pumpAndSettle).
void main() {
  Widget host(Locale locale) => MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: Center(child: HomeAiSearchField())),
      );

  testWidgets('types the first English phrase progressively', (tester) async {
    await tester.pumpWidget(host(const Locale('en')));

    final en =
        await AppLocalizations.delegate.load(const Locale('en'))
            as AppLocalizationsEn;
    final phrase1 = en.aiHintPhrase1;

    // After the first typing tick exactly one character is visible.
    await tester.pump(const Duration(milliseconds: 45));
    final text0 = tester.widget<Text>(find.byType(Text).first);
    // The visible span + optional cursor live inside a Text.rich; assert
    // against the accumulated characters.
    final visible0 = (text0.data ?? (text0.textSpan as TextSpan?)?.toPlainText())!;
    expect(visible0, isNot(phrase1));
    expect(visible0.replaceAll('▌', ''), hasLength(1));

    // Type the whole first line (one tick per character).
    for (var i = 0; i < phrase1.length; i++) {
      await tester.pump(const Duration(milliseconds: 45));
    }
    final text1 = tester.widget<Text>(find.byType(Text).first);
    final visible1 = (text1.data ?? (text1.textSpan as TextSpan?)?.toPlainText())!;
    expect(visible1.replaceAll('▌', ''), phrase1);

    expect(tester.takeException(), isNull);
  });

  testWidgets('rotates to the later English phrases', (tester) async {
    await tester.pumpWidget(host(const Locale('en')));

    final en =
        await AppLocalizations.delegate.load(const Locale('en'))
            as AppLocalizationsEn;

    // Full verified cycle from the debug trace: phrase 1 completes by
    // ~1.8s, holds 2s, wipes, and phrase 2 is typing by ~5.4s.
    // Pump 6 seconds of typed time to land mid-phrase-2.
    for (var i = 0; i < 135; i++) {
      await tester.pump(const Duration(milliseconds: 45));
    }

    final text = tester.widget<Text>(find.byType(Text).first);
    final visible =
        (text.data ?? (text.textSpan as TextSpan?)?.toPlainText())!
            .replaceAll('▌', '');
    // Rotation landed somewhere inside phrase 2 (prefix or complete) —
    // never still phrase 1.
    expect(
      visible == en.aiHintPhrase2 || en.aiHintPhrase2.startsWith(visible),
      isTrue,
      reason: 'Expected rotation into phrase 2, saw: "$visible"',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('writes the Arabic phrases in the Arabic locale', (tester) async {
    await tester.pumpWidget(host(const Locale('ar')));

    final ar =
        await AppLocalizations.delegate.load(const Locale('ar'))
            as AppLocalizationsAr;
    final phrase1 = ar.aiHintPhrase1;

    // Type the whole first Arabic line.
    for (var i = 0; i < phrase1.length; i++) {
      await tester.pump(const Duration(milliseconds: 45));
    }
    final text = tester.widget<Text>(find.byType(Text).first);
    final visible =
        (text.data ?? (text.textSpan as TextSpan?)?.toPlainText())!
            .replaceAll('▌', '');
    expect(visible, phrase1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives a locale switch mid-flight', (tester) async {
    await tester.pumpWidget(host(const Locale('en')));
    // Partially type the English line.
    await tester.pump(const Duration(milliseconds: 45) * 5);

    // Switch the tree to Arabic — the hint must re-seed and keep ticking.
    await tester.pumpWidget(host(const Locale('ar')));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 45));
    }
    expect(tester.takeException(), isNull);
  });
}
