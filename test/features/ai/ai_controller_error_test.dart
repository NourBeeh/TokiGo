import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/ai/ai_assistant_service.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/features/ai/application/ai_controller.dart';
import 'package:tokigo/features/ai/application/ai_state.dart';
import 'package:tokigo/features/ai/domain/ai_home_mapper.dart';
import 'package:tokigo/features/ai/domain/ai_response.dart';
import 'package:tokigo/features/ai/domain/ai_section.dart';
import 'package:tokigo/features/ai/domain/ai_query_context.dart';
import 'package:tokigo/core/storage/offline_cache.dart';

/// Phase 10A-F — `AiController` error boundary.
///
/// `AiState.errorMessage` is rendered verbatim on screen by
/// `ai_response_content.dart` (`_AiErrorState` → `Text(message)`), and
/// `HttpApiClient` stores the whole HTTP response body in `ApiError.message`.
/// These tests pin that no raw transport, backend or exception text can reach
/// that field, while the success / empty / retry / reset transitions stay
/// exactly as they were.

/// Raw payloads that must never surface to the user.
const String _rawClientBody =
    '{"statusCode":400,"message":["prompt must not be empty"],'
    '"error":"Bad Request"}';
const String _rawServerBody =
    '{"statusCode":503,"message":"AI provider is not configured: '
    'AI_API_KEY is missing.","error":"Service Unavailable"}';
const String _rawSocketText =
    'SocketException: Connection refused (OS Error: Connection refused, '
    'errno = 111), address = localhost, port = 45678';

/// Fails every call with [error].
class _ThrowingAiService implements AiAssistantService {
  _ThrowingAiService(this.error);

  final Object error;
  int calls = 0;

  @override
  Future<AiResponse> query(String prompt, {RequestToken? token, Duration? timeout, AiQueryContext? context}) async {
    calls++;
    throw error;
  }

  @override
  Future<String> generateContent({required String prompt}) =>
      throw UnimplementedError();
  @override
  Future<String> generateDescription({
    required String offerId,
    required String type,
  }) => throw UnimplementedError();
  @override
  Future<List<String>> recommend({required String context}) =>
      throw UnimplementedError();
  @override
  Future<List<String>> compareOffers({required List<String> offerIds}) =>
      throw UnimplementedError();
  @override
  Future<String> generateOfferSummary({required String offerId}) =>
      throw UnimplementedError();
}

/// Fails the first call, then succeeds — used to pin retry behaviour.
class _FailThenSucceedAiService implements AiAssistantService {
  int calls = 0;
  final List<String> prompts = <String>[];

  @override
  Future<AiResponse> query(String prompt, {RequestToken? token, Duration? timeout, AiQueryContext? context}) async {
    calls++;
    prompts.add(prompt);
    if (calls == 1) {
      throw const ApiServerError(message: _rawServerBody, statusCode: 503);
    }
    return const AiResponse(
      text: 'recovered',
      sections: <AiSection>[AiSection(title: 'S')],
    );
  }

  @override
  Future<String> generateContent({required String prompt}) =>
      throw UnimplementedError();
  @override
  Future<String> generateDescription({
    required String offerId,
    required String type,
  }) => throw UnimplementedError();
  @override
  Future<List<String>> recommend({required String context}) =>
      throw UnimplementedError();
  @override
  Future<List<String>> compareOffers({required List<String> offerIds}) =>
      throw UnimplementedError();
  @override
  Future<String> generateOfferSummary({required String offerId}) =>
      throw UnimplementedError();
}

/// Returns a fixed response.
class _StaticAiService implements AiAssistantService {
  _StaticAiService(this.response);

  final AiResponse response;
  int calls = 0;

  @override
  Future<AiResponse> query(String prompt, {RequestToken? token, Duration? timeout, AiQueryContext? context}) async {
    calls++;
    return response;
  }

  @override
  Future<String> generateContent({required String prompt}) =>
      throw UnimplementedError();
  @override
  Future<String> generateDescription({
    required String offerId,
    required String type,
  }) => throw UnimplementedError();
  @override
  Future<List<String>> recommend({required String context}) =>
      throw UnimplementedError();
  @override
  Future<List<String>> compareOffers({required List<String> offerIds}) =>
      throw UnimplementedError();
  @override
  Future<String> generateOfferSummary({required String offerId}) =>
      throw UnimplementedError();
}

AiController _controllerFor(AiAssistantService service) {
  final controller = AiController(
    service: service,
    mapper: const AiHomeMapper(),
    cache: MemoryOfflineCache(),
  );
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('AiController — no raw error text reaches errorMessage', () {
    test('ApiClientError does not leak the HTTP response body', () async {
      final controller = _controllerFor(
        _ThrowingAiService(
          const ApiClientError(message: _rawClientBody, statusCode: 400),
        ),
      );

      await controller.submit('find hotels');

      final message = controller.state.errorMessage;
      expect(controller.state.status, AiStatus.error);
      expect(message, isNotNull);
      expect(message, isNot(contains('statusCode')));
      expect(message, isNot(contains('Bad Request')));
      expect(message, isNot(contains(_rawClientBody)));
      expect(message, isNot(contains('ApiClientError')));
      expect(message, isNot(contains('400')));
    });

    test('ApiServerError does not leak backend configuration details',
        () async {
      final controller = _controllerFor(
        _ThrowingAiService(
          const ApiServerError(message: _rawServerBody, statusCode: 503),
        ),
      );

      await controller.submit('find hotels');

      final message = controller.state.errorMessage;
      expect(controller.state.status, AiStatus.error);
      // The backend names the env var in its 503 body; it must not reach the UI.
      expect(message, isNot(contains('AI_API_KEY')));
      expect(message, isNot(contains('AI provider')));
      expect(message, isNot(contains('Service Unavailable')));
      expect(message, isNot(contains('ApiServerError')));
    });

    test('ApiNetworkError does not leak host, port or exception type',
        () async {
      final controller = _controllerFor(
        _ThrowingAiService(const ApiNetworkError(message: _rawSocketText)),
      );

      await controller.submit('find hotels');

      final message = controller.state.errorMessage;
      expect(controller.state.status, AiStatus.error);
      expect(message, isNot(contains('SocketException')));
      expect(message, isNot(contains('localhost')));
      expect(message, isNot(contains('45678')));
      expect(message, isNot(contains('errno')));
    });

    test('ApiTimeoutError maps to a safe timeout message', () async {
      final controller = _controllerFor(
        _ThrowingAiService(
          const ApiTimeoutError(message: 'TimeoutException after 0:00:30.000'),
        ),
      );

      await controller.submit('find hotels');

      final message = controller.state.errorMessage;
      expect(controller.state.status, AiStatus.error);
      expect(message, isNot(contains('TimeoutException')));
      expect(message, isNot(contains('0:00:30')));
      expect(message, isNotEmpty);
    });

    test('ApiUnauthorizedError maps to a safe message', () async {
      final controller = _controllerFor(
        _ThrowingAiService(
          const ApiUnauthorizedError(
            message: '{"statusCode":401,"error":"Unauthorized"}',
            statusCode: 401,
          ),
        ),
      );

      await controller.submit('find hotels');

      final message = controller.state.errorMessage;
      expect(controller.state.status, AiStatus.error);
      expect(message, isNot(contains('statusCode')));
      expect(message, isNot(contains('401')));
      expect(message, isNotEmpty);
    });

    test('ApiParseError maps to a safe message', () async {
      final controller = _controllerFor(
        _ThrowingAiService(
          const ApiParseError(
            message: 'Invalid JSON response',
            cause: '<html>500 upstream</html>',
          ),
        ),
      );

      await controller.submit('find hotels');

      final message = controller.state.errorMessage;
      expect(controller.state.status, AiStatus.error);
      expect(message, isNot(contains('<html>')));
      expect(message, isNot(contains('Invalid JSON')));
      expect(message, isNotEmpty);
    });

    test('ApiUnknownError maps to a safe message', () async {
      final controller = _controllerFor(
        _ThrowingAiService(
          const ApiUnknownError(message: 'internal token=abc123 failed'),
        ),
      );

      await controller.submit('find hotels');

      final message = controller.state.errorMessage;
      expect(controller.state.status, AiStatus.error);
      expect(message, isNot(contains('token=abc123')));
      expect(message, isNotEmpty);
    });

    test('a non-ApiError exception does not leak its text', () async {
      final controller = _controllerFor(
        _ThrowingAiService(
          Exception('Bearer sk-or-v1-secret leaked into the message'),
        ),
      );

      await controller.submit('find hotels');

      final message = controller.state.errorMessage;
      expect(controller.state.status, AiStatus.error);
      expect(message, isNot(contains('sk-or-v1')));
      expect(message, isNot(contains('Bearer')));
      expect(message, isNot(contains('Exception')));
      expect(message, isNotEmpty);
    });

    test('a runtime TypeError does not leak its text', () async {
      final controller = _controllerFor(
        _ThrowingAiService(StateError('internal invariant broken at 0xdeadbeef')),
      );

      await controller.submit('find hotels');

      final message = controller.state.errorMessage;
      expect(controller.state.status, AiStatus.error);
      expect(message, isNot(contains('0xdeadbeef')));
      expect(message, isNot(contains('invariant')));
      expect(message, isNot(contains('Bad state')));
      expect(message, isNotEmpty);
    });

    test('every mapped message is short, plain prose', () async {
      final errors = <Object>[
        const ApiClientError(message: _rawClientBody, statusCode: 400),
        const ApiServerError(message: _rawServerBody, statusCode: 503),
        const ApiNetworkError(message: _rawSocketText),
        const ApiTimeoutError(message: 'TimeoutException'),
        const ApiUnauthorizedError(message: 'nope', statusCode: 401),
        const ApiParseError(message: 'Invalid JSON response'),
        const ApiUnknownError(message: 'boom'),
        Exception('boom'),
      ];

      for (final error in errors) {
        final controller = _controllerFor(_ThrowingAiService(error));
        await controller.submit('p');

        final message = controller.state.errorMessage!;
        expect(message.length, lessThan(120), reason: 'for $error');
        expect(message, isNot(contains('{')), reason: 'for $error');
        expect(message, isNot(contains('Api')), reason: 'for $error');
        expect(message, isNot(contains('\n')), reason: 'for $error');
      }
    });
  });

  group('AiController — existing transitions are unchanged', () {
    test('success publishes text and mapped sections', () async {
      final controller = _controllerFor(
        _StaticAiService(
          const AiResponse(
            text: 'here you go',
            sections: <AiSection>[AiSection(title: 'Hotels')],
          ),
        ),
      );

      await controller.submit('find hotels');

      expect(controller.state.status, AiStatus.success);
      expect(controller.state.responseText, 'here you go');
      expect(controller.state.sections, hasLength(1));
      expect(controller.state.currentPrompt, 'find hotels');
      expect(controller.state.errorMessage, isNull);
    });

    test('a response with no text and no sections becomes empty', () async {
      final controller = _controllerFor(_StaticAiService(const AiResponse()));

      await controller.submit('find hotels');

      expect(controller.state.status, AiStatus.empty);
      expect(controller.state.currentPrompt, 'find hotels');
    });

    test('a blank prompt is ignored and leaves the state idle', () async {
      final service = _StaticAiService(const AiResponse(text: 'x'));
      final controller = _controllerFor(service);

      await controller.submit('   ');

      expect(controller.state.status, AiStatus.idle);
      expect(controller.state.currentPrompt, '');
      expect(service.calls, 0);
    });

    test('the prompt is trimmed before being submitted', () async {
      final controller = _controllerFor(
        _StaticAiService(const AiResponse(text: 'x')),
      );

      await controller.submit('  find hotels  ');

      expect(controller.state.currentPrompt, 'find hotels');
    });

    test('retry re-runs the last prompt and can recover', () async {
      final service = _FailThenSucceedAiService();
      final controller = _controllerFor(service);

      await controller.submit('find hotels');
      expect(controller.state.status, AiStatus.error);
      expect(controller.state.currentPrompt, 'find hotels');

      await controller.retry();

      expect(service.calls, 2);
      expect(service.prompts, <String>['find hotels', 'find hotels']);
      expect(controller.state.status, AiStatus.success);
      expect(controller.state.responseText, 'recovered');
      expect(controller.state.errorMessage, isNull);
    });

    test('retry with no previous prompt does nothing', () async {
      final service = _StaticAiService(const AiResponse(text: 'x'));
      final controller = _controllerFor(service);

      await controller.retry();

      expect(service.calls, 0);
      expect(controller.state.status, AiStatus.idle);
    });

    test('reset returns the controller to a pristine idle state', () async {
      final controller = _controllerFor(
        _ThrowingAiService(const ApiNetworkError(message: _rawSocketText)),
      );

      await controller.submit('find hotels');
      expect(controller.state.status, AiStatus.error);

      controller.reset();

      expect(controller.state.status, AiStatus.idle);
      expect(controller.state.currentPrompt, '');
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.responseText, isNull);
      expect(controller.state.sections, isEmpty);
    });

    test('a mapped success carries the card type through to the sections',
        () async {
      final controller = _controllerFor(
        _StaticAiService(
          AiResponse(
            text: 'ok',
            sections: <AiSection>[
              AiSection.fromMap(<String, dynamic>{
                'title': 'Flights',
                'items': <Object?>[
                  <String, dynamic>{
                    'id': 'f1',
                    'type': 'flight',
                    'title': 'QR',
                  },
                ],
              }),
            ],
          ),
        ),
      );

      await controller.submit('flights');

      expect(controller.state.status, AiStatus.success);
      expect(
        controller.state.sections.single.items.single.type,
        HomeCardType.flight,
      );
    });
  });
}