import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tokigo/core/ai/ai_assistant_service.dart';
import 'package:tokigo/core/auth/auth_provider.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/theme/app_theme.dart';
import 'package:tokigo/core/widgets/ai_robot_avatar.dart';
import 'package:tokigo/features/ai/application/ai_chat_page_providers.dart';
import 'package:tokigo/features/ai/application/ai_controller.dart';
import 'package:tokigo/features/ai/domain/ai_home_mapper.dart';
import 'package:tokigo/features/ai/domain/ai_query_context.dart';
import 'package:tokigo/features/ai/domain/ai_response.dart';
import 'package:tokigo/features/ai/presentation/pages/ai_chat_page.dart';
import 'package:tokigo/features/home/providers/home_providers.dart';
import 'package:tokigo/features/universal_search/application/voice_search_controller.dart';
import 'package:tokigo/features/universal_search/application/voice_search_providers.dart';
import 'package:tokigo/features/universal_search/domain/voice_search_service.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// The assistant's brand identity during the THINKING state (owner decision,
/// 2026-11).
///
/// The typing indicator is a real page state, so this drives the actual
/// [AiChatPage] with a service that never answers: the page must show the
/// brand mark beside the indicator AND run its breathing pulse, matching the
/// documented contract of [AiRobotAvatar].
class _HangingAiService implements AiAssistantService {
  @override
  Future<AiResponse> query(
    String prompt, {
    RequestToken? token,
    Duration? timeout,
    AiQueryContext? context,
  }) => Completer<AiResponse>().future;

  @override
  Future<String> generateDescription({
    required String offerId,
    required String type,
  }) async => '';

  @override
  Future<List<String>> recommend({required String context}) async => const [];

  @override
  Future<List<String>> compareOffers({required List<String> offerIds}) async =>
      const [];

  @override
  Future<String> generateOfferSummary({required String offerId}) async => '';

  @override
  Future<String> generateContent({required String prompt}) async => '';
}

class _FakeVoiceService implements VoiceSearchService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> start({
    required void Function(String partial, bool finalResult) onResult,
    required void Function(VoiceFailure failure) onError,
  }) async => false;

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

void main() {
  testWidgets('the thinking indicator carries the animated brand mark', (
    tester,
  ) async {
    final AiController controller = AiController(
      service: _HangingAiService(),
      mapper: const AiHomeMapper(),
      cache: MemoryOfflineCache(),
    );

    final VoiceSearchController voice = VoiceSearchController(
      voiceService: _FakeVoiceService(),
      onTranscription: (_, _) {},
    );

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authUserProvider.overrideWith((ref) => null),
        geoCountryProvider.overrideWith((ref) async => null),
        aiChatControllerProvider.overrideWith((ref) => controller),
        voiceSearchControllerProvider.overrideWith((ref) => voice),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/ai-chat',
            routes: <RouteBase>[
              GoRoute(
                path: '/ai-chat',
                builder: (BuildContext context, GoRouterState state) =>
                    const AiChatPage(initialPrompt: 'hello'),
              ),
            ],
          ),
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: const <Locale>[Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The thread is showing the typing indicator, not the welcome hero.
    expect(find.byType(AiRobotAvatar), findsOneWidget);
    expect(
      tester.widget<AiRobotAvatar>(find.byType(AiRobotAvatar)).animate,
      isTrue,
      reason: 'the thinking indicator runs the breathing pulse',
    );
  });
}
