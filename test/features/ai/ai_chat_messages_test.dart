import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/ai/ai_assistant_service.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/features/ai/application/ai_controller.dart';
import 'package:tokigo/features/ai/application/ai_state.dart';
import 'package:tokigo/features/ai/domain/ai_chat_message.dart';
import 'package:tokigo/features/ai/domain/ai_home_mapper.dart';
import 'package:tokigo/features/ai/domain/ai_query_context.dart';
import 'package:tokigo/features/ai/domain/ai_response.dart';
import 'package:tokigo/core/storage/offline_cache.dart';

/// Chat conversation building — the controller must append the user's
/// message immediately and the assistant's reply on every terminal state.
class _StaticAiService implements AiAssistantService {
  _StaticAiService(this.response);

  final AiResponse response;

  @override
  Future<AiResponse> query(String prompt,
      {RequestToken? token, Duration? timeout, AiQueryContext? context}) async {
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _ThrowingAiService implements AiAssistantService {
  _ThrowingAiService(this.error);

  final Object error;

  @override
  Future<AiResponse> query(String prompt,
      {RequestToken? token, Duration? timeout, AiQueryContext? context}) async {
    throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

AiController _controllerFor(AiAssistantService service,
    {DateTime Function()? now}) {
  final controller = AiController(
    service: service,
    mapper: const AiHomeMapper(),
    cache: MemoryOfflineCache(),
    now: now,
  );
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('AiController — chat message history', () {
    test('successful submit appends user message then assistant reply',
        () async {
      final controller = _controllerFor(
        _StaticAiService(const AiResponse(text: 'Flights to Cairo found!')),
      );

      await controller.submit('flights to cairo');

      final messages = controller.state.messages;
      expect(messages.length, 2);
      expect(messages[0].isUser, isTrue);
      expect(messages[0].text, 'flights to cairo');
      expect(messages[1].role, AiChatRole.assistant);
      expect(messages[1].text, 'Flights to Cairo found!');
      expect(messages[1].fromCache, isFalse);
    });

    test('conversation accumulates across multiple turns', () async {
      final controller = _controllerFor(
        _StaticAiService(const AiResponse(text: 'Reply')),
      );

      await controller.submit('one');
      await controller.submit('two');

      expect(controller.state.messages.length, 4);
      expect(controller.state.messages[0].text, 'one');
      expect(controller.state.messages[2].text, 'two');
    });

    test('failed submit appends a friendly assistant error bubble', () async {
      final controller = _controllerFor(
        _ThrowingAiService(
          const ApiNetworkError(message: 'SocketException: raw'),
        ),
      );

      await controller.submit('hello');

      final messages = controller.state.messages;
      expect(messages.length, 2);
      expect(messages.last.isUser, isFalse);
      expect(messages.last.text, isNot(contains('SocketException')));
      // The friendly text comes from the existing ApiError mapping.
      expect(
        messages.last.text,
        'No connection to the assistant. Check your internet and try again.',
      );
    });

    test('reset clears the whole conversation', () async {
      final controller = _controllerFor(
        _StaticAiService(const AiResponse(text: 'Reply')),
      );

      await controller.submit('hello');
      expect(controller.state.messages, isNotEmpty);

      controller.reset();
      expect(controller.state.messages, isEmpty);
      expect(controller.state.status, AiStatus.idle);
    });

    test(
      'rolling cap: the conversation never exceeds 50 messages — the oldest '
      'are dropped first',
      () async {
        final controller =
            _controllerFor(_StaticAiService(const AiResponse(text: 'Reply')));

        // 30 turns x 2 messages = 60 entries.
        for (var i = 0; i < 30; i++) {
          await controller.submit('msg $i');
        }

        final messages = controller.state.messages;
        expect(messages.length, AiController.maxMessages);
        // 60 - 50 = 10 oldest dropped => first kept is turn #5's user msg.
        expect(messages.first.text, 'msg 5');
        expect(messages.last.text, 'Reply');
      },
    );

    test(
      'idle expiry: a conversation untouched for longer than the TTL starts '
      'fresh on the next submit',
      () async {
        var now = DateTime(2026, 1, 1, 12);
        final controller = _controllerFor(
          _StaticAiService(const AiResponse(text: 'Reply')),
          now: () => now,
        );

        await controller.submit('first');
        expect(controller.state.messages.length, 2);

        // Jump past the 6-hour TTL.
        now = now.add(const Duration(hours: 7));
        await controller.submit('second');

        final messages = controller.state.messages;
        expect(messages.length, 2);
        expect(messages.first.text, 'second');
      },
    );

    test(
      'idle expiry: backgrounded within the TTL keeps the conversation',
      () async {
        var now = DateTime(2026, 1, 1, 12);
        final controller = _controllerFor(
          _StaticAiService(const AiResponse(text: 'Reply')),
          now: () => now,
        );

        await controller.submit('first');

        now = now.add(const Duration(hours: 1));
        await controller.submit('second');

        // Both turns survive — nothing was expired.
        expect(controller.state.messages.length, 4);
        expect(controller.state.messages[0].text, 'first');
      },
    );
  });
}
