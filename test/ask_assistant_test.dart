import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/ask_assistant_card.dart';
import 'package:tokigo/features/search/presentation/widgets/search_scaffold.dart';
import 'package:tokigo/l10n/app_localizations.dart';

Widget _app(GoRouter router, {Locale locale = const Locale('en')}) {
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

/// A root route that renders the [AskAssistantCard] as the page body, plus the
/// existing `/ai-chat` destination the card pushes.
GoRouter _router({String prompt = 'compare these flights'}) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(child: AskAssistantCard(prompt: prompt)),
        ),
      ),
      GoRoute(
        path: '/ai-chat',
        builder: (context, state) {
          final Object? extra = state.extra;
          return Scaffold(body: Text('AI:${extra ?? 'empty'}'));
        },
      ),
    ],
  );
}

void main() {
  testWidgets('the card renders the localized title and subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_router()));
    await tester.pumpAndSettle();

    expect(find.text('Ask your assistant'), findsOneWidget);
    expect(
      find.text('Need help choosing? Compare these options with AI'),
      findsOneWidget,
    );
  });

  testWidgets('tapping the card opens the existing AI chat with the prompt', (
    tester,
  ) async {
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AskAssistantCard));
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, '/ai-chat');
    expect(find.text('AI:compare these flights'), findsOneWidget);
  });

  testWidgets('the search scaffold shows the card only with a prompt', (
    tester,
  ) async {
    Widget scaffold(String? prompt) => Scaffold(
      body: SearchScaffold(
        subtitle: 'Results',
        form: const SizedBox.shrink(),
        body: const SizedBox.shrink(),
        askAssistantPrompt: prompt,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: scaffold(null),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AskAssistantCard), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: scaffold('compare these flights'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AskAssistantCard), findsOneWidget);
  });

  testWidgets('the Arabic card mirrors', (tester) async {
    final GoRouter router = _router(prompt: 'قارن هذه الرحلات');
    await tester.pumpWidget(_app(router, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(AskAssistantCard))),
      TextDirection.rtl,
    );
    expect(find.text('اسأل مساعدك'), findsOneWidget);

    await tester.tap(find.byType(AskAssistantCard));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/ai-chat');
  });
}
