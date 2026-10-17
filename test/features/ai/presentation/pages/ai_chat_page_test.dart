import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/ai/ai_assistant_service.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/features/ai/application/ai_chat_page_providers.dart';
import 'package:tokigo/features/ai/application/ai_controller.dart';
import 'package:tokigo/features/ai/domain/ai_home_mapper.dart';
import 'package:tokigo/features/ai/domain/ai_query_context.dart';
import 'package:tokigo/features/ai/domain/ai_response.dart';
import 'package:tokigo/features/ai/presentation/pages/ai_chat_page.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Returns a fixed response.
class _StaticAiService implements AiAssistantService {
  @override
  Future<AiResponse> query(String prompt,
      {RequestToken? token, Duration? timeout, AiQueryContext? context}) async {
    return AiResponse(text: 'Reply to: $prompt');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiChatControllerProvider.overrideWith((ref) => AiController(
              service: _StaticAiService(),
              mapper: const AiHomeMapper(),
              cache: MemoryOfflineCache(),
            )),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: SizedBox()),
        routes: {'/chat': (_) => const AiChatPage()},
      ),
    ),
  );
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.pushNamed('/chat');
  // Welcome state is static — settle is safe until a request starts.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'full-screen page renders header, welcome content and input',
    (tester) async {
      await pumpPage(tester);

      expect(find.text('TokiGo AI'), findsOneWidget);
      expect(find.text('Hi! Ask me about flights, hotels, and more…'),
          findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      // Glass circular ✕ on the right of the header.
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sending a prompt appends the user bubble and the assistant reply',
    (tester) async {
      await pumpPage(tester);

      await tester.enterText(find.byType(TextField), 'flights to cairo');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      // Loading (typing dots animate forever) then the reply lands.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('flights to cairo'), findsOneWidget);
      expect(find.text('Reply to: flights to cairo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the header ✕ button pops back',
    (tester) async {
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.close));
      // Idle page has no looping animations, so settling is safe and covers
      // the full exit transition.
      await tester.pumpAndSettle();

      expect(find.text('TokiGo AI'), findsNothing);
    },
  );

  testWidgets(
    'the Escape key pops back (web/desktop parity)',
    (tester) async {
      await pumpPage(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('TokiGo AI'), findsNothing);
    },
  );
}
