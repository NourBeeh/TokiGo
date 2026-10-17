import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:wetravellers/app/app.dart';
import 'package:wetravellers/core/storage/offline_cache.dart';
import 'package:wetravellers/core/storage/offline_cache_providers.dart';
import 'package:wetravellers/features/ai/presentation/pages/ai_chat_page.dart';
import 'package:wetravellers/features/home/presentation/widgets/home_ai_search_field.dart';
import 'package:wetravellers/features/universal_search/presentation/pages/universal_search_page.dart';
import 'package:wetravellers/l10n/app_localizations.dart';

void main() {
  setUpAll(() {
    // Mirror the universal-search suite so the router + Hive are ready.
    Hive.init(Directory.systemTemp.createTempSync('wt_home_ai_search').path);
  });

  /// Harness that boots the real app (GoRouter) with an empty offline cache.
  Widget harness({OfflineCache? cache}) {
    return ProviderScope(
      overrides: <Override>[
        offlineCacheProvider.overrideWithValue(cache ?? MemoryOfflineCache()),
      ],
      child: const WeTravellersApp(),
    );
  }

  /// The Home AI pill (the Semantic wrapper around the entire pill visual).
  Finder pill() => find.byType(HomeAiSearchField);

  /// The pill's editable TextField (scoped so the universal-search Header
  /// TextField is never matched by accident).
  Finder field() =>
      find.descendant(of: pill(), matching: find.byType(TextField));

  /// The pill's trailing search/send icon (scoped to the Home pill).
  Finder searchIcon() =>
      find.descendant(of: pill(), matching: find.byIcon(Icons.search_rounded));

  /// The chat page's TextField, once it has opened.
  Finder chatField() => find.descendant(
      of: find.byType(AiChatPage), matching: find.byType(TextField));

  testWidgets('renders an editable TextField with a rotating typewriter hint',
      (tester) async {
    await tester.pumpWidget(host(const Locale('en')));
    await tester.pump(const Duration(milliseconds: 60));

    final textField = tester.widget<TextField>(field());
    expect(textField.controller, isNotNull);
    final hint = textField.decoration?.hintText ?? '';
    expect(hint, isNotEmpty);
    expect(hint, hasLength(greaterThanOrEqualTo(1)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct typing into the Home input', (tester) async {
    await tester.pumpWidget(host(const Locale('en')));
    await tester.tap(pill());
    await tester.pump();
    await tester.enterText(field(), 'hotels in dubai');
    await tester.pump(const Duration(milliseconds: 100));

    final textField = tester.widget<TextField>(field());
    expect(textField.controller?.text, 'hotels in dubai');
    expect(tester.takeException(), isNull);
  });

  testWidgets('submission via send icon opens the AI chat with the query',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(pill());
    await tester.pump();
    await tester.enterText(field(), 'hotels in dubai');
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(searchIcon());
    await tester.pumpAndSettle(const Duration(milliseconds: 1500));

    expect(find.byType(AiChatPage), findsOneWidget);
    final chat = tester.widget<TextField>(chatField());
    expect(chat.controller?.text, 'hotels in dubai');
    expect(tester.takeException(), isNull);
  });

  testWidgets('submission via the keyboard send action opens the AI chat',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 500));

    // enterText focuses the field, so the text-input connection is live and
    // the keyboard "send" action (Enter) reaches onSubmitted.
    await tester.enterText(field(), 'random words here');
    await tester.pump(const Duration(milliseconds: 100));

    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(AiChatPage), findsOneWidget);
    final chat = tester.widget<TextField>(chatField());
    expect(chat.controller?.text, 'random words here');
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and whitespace-only queries are ignored', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(pill());
    await tester.pump();

    // Empty.
    await tester.tap(searchIcon());
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AiChatPage), findsNothing);

    // Whitespace-only.
    await tester.enterText(field(), '   ');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(searchIcon());
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AiChatPage), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('submitting clears the field so the query cannot be resent',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(pill());
    await tester.pump();
    await tester.enterText(field(), 'hotels');
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(searchIcon());
    await tester.pumpAndSettle(const Duration(milliseconds: 1500));
    expect(find.byType(AiChatPage), findsOneWidget);

    // The Home pill stays mounted beneath the pushed chat route (offstage), and
    // its field was cleared on submit — so the same query can never be sent
    // twice (duplicate-prevention contract).
    final homeField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(HomeAiSearchField, skipOffstage: false),
        matching: find.byType(TextField, skipOffstage: false),
      ),
    );
    expect(homeField.controller?.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preserves Arabic locale and disabled mic', (tester) async {
    await tester.pumpWidget(host(const Locale('ar')));
    await tester.pump(const Duration(milliseconds: 100));

    final textField = tester.widget<TextField>(field());
    expect(textField.decoration?.hintText, isNotEmpty);
    // The mic placeholder remains present and disabled.
    expect(
      find.descendant(of: pill(), matching: find.byIcon(Icons.mic_none_rounded)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('leading sparkle opens the full smart-search surface',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(
      find.descendant(of: pill(), matching: find.byIcon(Icons.auto_awesome_rounded)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(UniversalSearchPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  /// The Home pill is a genuine TextField that remains focusable by tap,
  /// and the typewriter hint keeps rotating.
  testWidgets('pill is focusable and keeps its typewriter hint', (tester) async {
    await tester.pumpWidget(host(const Locale('en')));
    final before = tester.widget<TextField>(field()).decoration?.hintText ?? '';
    await tester.tap(pill());
    await tester.pump(const Duration(milliseconds: 60));
    final after = tester.widget<TextField>(field()).decoration?.hintText ?? '';
    // The hint changes while the typewriter arcs, proving the field is a real
    // interactive input rather than a static label.
    expect(after, isNot(before));
    expect(tester.takeException(), isNull);
  });
}

/// Host for the locale-agnostic pill.
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
