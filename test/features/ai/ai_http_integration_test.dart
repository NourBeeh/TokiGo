import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/domain/models/home/home_types.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/features/ai/application/ai_controller.dart';
import 'package:tokigo/features/ai/application/ai_state.dart';
import 'package:tokigo/features/ai/data/ai_api_service.dart';
import 'package:tokigo/features/ai/domain/ai_home_mapper.dart';
import 'package:tokigo/core/storage/offline_cache.dart';

/// Phase 10B-A — real HTTP integration for the Flutter half of the AI path:
///
///   AiController (real)
///     -> AiApiService (real)
///     -> HttpApiClient (real transport, real dart:io HttpClient)
///     -> real TCP POST /ai/query
///     -> local dart:io HttpServer replaying the backend contract
///     -> AiResponse.fromMap
///     -> AiHomeMapper
///
/// No fake `ApiClient` and no fake `AiAssistantService`: the request leaves the
/// process over a real socket and every byte is parsed by the production code.
/// Only `baseUrl` and `defaultTimeout` are overridden, both of which are
/// already `ApiClient` extension points — the request/response pipeline in
/// `HttpApiClient._request` is untouched.
///
/// Runs with no internet, no backend process and no credentials.
///
/// The success fixture below is not hand-written: it is the verbatim output of
/// the real backend `normalizeAiResponse()` for a hotel completion, captured
/// from `backend/src/modules/ai/openai.ai.provider.ts`. Using those exact bytes
/// keeps this test honest about the shape the backend actually emits.
const String _realBackendDtoJson =
    '{"text":"Here are two hotels.","sections":[{"title":"Recommended Hotels",'
    '"layout":"horizontalPeek","items":[{"id":"h1","type":"hotel",'
    '"title":"Grand Palm","price":320,"currency":"USD","rating":4.6,'
    '"reviewCount":214,"data":{"city":"Paris"},"tags":["4-star"],'
    '"actions":[{"type":"book","label":"Book","payload":{"offerId":"h1"}}]}],'
    '"metadata":{},"id":"hotels","subtitle":"Best match","order":1}],'
    '"metadata":{"queryId":"ab127317-2ad2-4f46-8282-8407c9eeaaa7","version":1}}';

/// One captured inbound request to the local backend stand-in.
class _Captured {
  const _Captured({
    required this.method,
    required this.path,
    required this.contentType,
    required this.authorization,
    required this.accept,
    required this.body,
  });

  final String method;
  final String path;
  final String? contentType;
  final String? authorization;
  final String? accept;
  final String body;
}

/// The real client, redirected at the local server.
///
/// [defaultTimeout] is shortened so the genuine timeout branch in
/// `HttpApiClient._request` can be exercised without a 30 second test.
class _LocalHttpApiClient extends HttpApiClient {
  _LocalHttpApiClient(this._baseUrl, {Duration? timeout})
      : _timeout = timeout ?? const Duration(seconds: 5);

  final String _baseUrl;
  final Duration _timeout;

  @override
  String get baseUrl => _baseUrl;

  @override
  Duration get defaultTimeout => _timeout;
}

void main() {
  late HttpServer server;
  late String baseUrl;
  late List<_Captured> captured;
  late Future<void> Function(HttpRequest request) respond;

  /// Default: a valid backend payload.
  Future<void> okDto(HttpRequest request) async {
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..write(_realBackendDtoJson);
    await request.response.close();
  }

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';

    server.listen((HttpRequest request) async {
      final body = await utf8.decoder.bind(request).join();
      captured.add(
        _Captured(
          method: request.method,
          path: request.uri.path,
          contentType: request.headers.contentType?.mimeType,
          authorization: request.headers.value(HttpHeaders.authorizationHeader),
          accept: request.headers.value(HttpHeaders.acceptHeader),
          body: body,
        ),
      );
      try {
        await respond(request);
      } catch (_) {
        // The client may already have given up (timeout case).
      }
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  setUp(() {
    captured = <_Captured>[];
    respond = okDto;
  });

  AiApiService serviceWith(ApiClient client) => AiApiService(client);

  AiController controllerWith(ApiClient client) {
    final controller = AiController(
      service: serviceWith(client),
      mapper: const AiHomeMapper(),
      cache: MemoryOfflineCache(),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  group('the request really leaves the process over TCP', () {
    test('POST /ai/query arrives with the documented request contract',
        () async {
      final service = serviceWith(_LocalHttpApiClient(baseUrl));

      await service.query('find hotels in Paris');

      expect(captured, hasLength(1));
      final sent = captured.single;
      expect(sent.method, 'POST');
      expect(sent.path, '/ai/query');
      expect(sent.contentType, 'application/json');
      expect(sent.accept, 'application/json');
      expect(
        jsonDecode(sent.body),
        <String, dynamic>{'prompt': 'find hotels in Paris'},
      );
    });

    test('the client sends no Authorization header — the AI key stays server side',
        () async {
      final service = serviceWith(_LocalHttpApiClient(baseUrl));

      await service.query('find hotels');

      expect(captured.single.authorization, isNull);
      expect(captured.single.body, isNot(contains('Bearer')));
      expect(captured.single.body, isNot(contains('sk-')));
      expect(captured.single.body, isNot(contains('api_key')));
      expect(captured.single.body, isNot(contains('AI_API_KEY')));
    });
  });

  group('scenario: 200 with the real backend payload', () {
    test('parses the captured backend DTO into the Flutter contract', () async {
      final service = serviceWith(_LocalHttpApiClient(baseUrl));

      final response = await service.query('find hotels');

      expect(response.text, 'Here are two hotels.');
      expect(response.metadata['version'], 1);
      expect(response.sections, hasLength(1));

      final section = response.sections.single;
      expect(section.id, 'hotels');
      expect(section.title, 'Recommended Hotels');
      expect(section.subtitle, 'Best match');
      expect(section.layout, HomeSectionLayout.horizontalPeek);
      expect(section.order, 1);
      expect(section.items, hasLength(1));

      final item = section.items.single;
      expect(item.id, 'h1');
      expect(item.type, HomeCardType.hotel);
      expect(item.title, 'Grand Palm');
      expect(item.price, 320.0);
      expect(item.currency, 'USD');
      expect(item.rating, 4.6);
      expect(item.reviewCount, 214);
      expect(item.tags, <String>['4-star']);
      expect(item.data['city'], 'Paris');
      expect(item.actions, hasLength(1));
      expect(item.actions.single.type, 'book');
      expect(item.actions.single.payload['offerId'], 'h1');
    });

    test('the controller reaches success and maps renderable sections',
        () async {
      final controller = controllerWith(_LocalHttpApiClient(baseUrl));

      await controller.submit('find hotels');

      expect(controller.state.status, AiStatus.success);
      expect(controller.state.responseText, 'Here are two hotels.');
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.sections, hasLength(1));
      expect(controller.state.sections.single.id, 'hotels');
      expect(
        controller.state.sections.single.items.single.type,
        HomeCardType.hotel,
      );
    });
  });

  group('scenario: HTTP 500', () {
    setUp(() {
      respond = (HttpRequest request) async {
        request.response
          ..statusCode = 500
          ..headers.contentType = ContentType.json
          ..write('{"statusCode":500,"message":"AI provider is not configured: '
              'AI_API_KEY is missing.","error":"Internal Server Error"}');
        await request.response.close();
      };
    });

    test('surfaces ApiServerError with the status preserved', () async {
      final service = serviceWith(_LocalHttpApiClient(baseUrl));

      final error = await service.query('find hotels').then<Object?>(
            (_) => null,
            onError: (Object e) => e,
          );

      expect(error, isA<ApiServerError>());
      expect((error as ApiServerError).statusCode, 500);
    });

    test('the controller shows a safe message and hides the backend body',
        () async {
      final controller = controllerWith(_LocalHttpApiClient(baseUrl));

      await controller.submit('find hotels');

      expect(controller.state.status, AiStatus.error);
      final message = controller.state.errorMessage!;
      expect(message, 'The assistant is temporarily unavailable. Please try again shortly.');
      expect(message, isNot(contains('AI_API_KEY')));
      expect(message, isNot(contains('statusCode')));
      expect(message, isNot(contains('ApiServerError')));
      expect(message, isNot(contains('500')));
    });
  });

  group('scenario: timeout', () {
    setUp(() {
      respond = (HttpRequest request) async {
        await Future<void>.delayed(const Duration(seconds: 3));
        request.response.statusCode = 200;
        await request.response.close();
      };
    });

    test('surfaces ApiTimeoutError from the real timeout branch', () async {
      final client = _LocalHttpApiClient(
        baseUrl,
        timeout: const Duration(milliseconds: 250),
      );

      final error = await serviceWith(client).query('find hotels').then<Object?>(
            (_) => null,
            onError: (Object e) => e,
          );

      expect(captured, hasLength(1));
      expect(error, isA<ApiTimeoutError>());
    });

    test('the controller shows a safe timeout message', () async {
      final controller = controllerWith(
        _LocalHttpApiClient(baseUrl, timeout: const Duration(milliseconds: 250)),
      );

      await controller.submit('find hotels');

      expect(controller.state.status, AiStatus.error);
      expect(
        controller.state.errorMessage,
        'The assistant took too long to respond. Please try again.',
      );
      expect(controller.state.errorMessage, isNot(contains('TimeoutException')));
    });
  });

  group('scenario: empty body', () {
    setUp(() {
      respond = (HttpRequest request) async {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json;
        await request.response.close();
      };
    });

    test('surfaces ApiParseError instead of crashing', () async {
      final service = serviceWith(_LocalHttpApiClient(baseUrl));

      final error = await service.query('find hotels').then<Object?>(
            (_) => null,
            onError: (Object e) => e,
          );

      expect(error, isA<ApiParseError>());
    });

    test('the controller shows a safe message', () async {
      final controller = controllerWith(_LocalHttpApiClient(baseUrl));

      await controller.submit('find hotels');

      expect(controller.state.status, AiStatus.error);
      expect(
        controller.state.errorMessage,
        'The assistant sent an unexpected reply. Please try again.',
      );
    });
  });

  group('scenario: malformed JSON', () {
    test('a truncated object surfaces ApiParseError', () async {
      respond = (HttpRequest request) async {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"text":"ok","sections":[');
        await request.response.close();
      };

      final error = await serviceWith(_LocalHttpApiClient(baseUrl))
          .query('find hotels')
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<ApiParseError>());
    });

    test('an HTML error page surfaces ApiParseError and a safe message',
        () async {
      respond = (HttpRequest request) async {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write('<html><body>502 Bad Gateway upstream=10.0.0.7</body></html>');
        await request.response.close();
      };

      final controller = controllerWith(_LocalHttpApiClient(baseUrl));
      await controller.submit('find hotels');

      expect(controller.state.status, AiStatus.error);
      final message = controller.state.errorMessage!;
      expect(message, 'The assistant sent an unexpected reply. Please try again.');
      expect(message, isNot(contains('<html>')));
      expect(message, isNot(contains('10.0.0.7')));
    });

    test('a JSON array body is reported as an error, never as a crash',
        () async {
      respond = (HttpRequest request) async {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('[{"not":"an object"}]');
        await request.response.close();
      };

      final controller = controllerWith(_LocalHttpApiClient(baseUrl));

      // The shape mismatch is caught by HttpApiClient's outer guard, so the
      // controller must still land on a sanitized error rather than throwing.
      await controller.submit('find hotels');

      expect(controller.state.status, AiStatus.error);
      final message = controller.state.errorMessage!;
      expect(message, isNot(contains('subtype')));
      expect(message, isNot(contains('List<dynamic>')));
      expect(message.length, lessThan(120));
    });
  });

  group('scenario: valid payload missing optional fields', () {
    test('a minimal backend payload parses with contract defaults', () async {
      respond = (HttpRequest request) async {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"text":"minimal","sections":[{"title":"Bare",'
              '"layout":"vertical","items":[{"id":"m1","type":"deal",'
              '"title":"Deal"}],"metadata":{}}],"metadata":{}}');
        await request.response.close();
      };

      final response =
          await serviceWith(_LocalHttpApiClient(baseUrl)).query('find deals');

      expect(response.text, 'minimal');
      final section = response.sections.single;
      expect(section.id, isNull);
      expect(section.subtitle, isNull);
      expect(section.order, isNull);
      expect(section.layout, HomeSectionLayout.vertical);

      final item = section.items.single;
      expect(item.id, 'm1');
      expect(item.type, HomeCardType.deal);
      expect(item.title, 'Deal');
      expect(item.price, isNull);
      expect(item.currency, isNull);
      expect(item.rating, isNull);
      expect(item.highlights, isEmpty);
      expect(item.tags, isEmpty);
      expect(item.actions, isEmpty);
    });

    test('a payload with no sections lands on the empty state', () async {
      respond = (HttpRequest request) async {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"sections":[],"metadata":{}}');
        await request.response.close();
      };

      final controller = controllerWith(_LocalHttpApiClient(baseUrl));

      await controller.submit('find deals');

      expect(controller.state.status, AiStatus.empty);
      expect(controller.state.errorMessage, isNull);
    });

    test('the parse-fallback payload still renders as success', () async {
      respond = (HttpRequest request) async {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"text":"I received a response from the AI assistant, but I '
              "couldn't parse the suggestions at this time. Please try again.\","
              '"sections":[],"metadata":{"parseFallback":true,"version":1}}');
        await request.response.close();
      };

      final controller = controllerWith(_LocalHttpApiClient(baseUrl));

      await controller.submit('find deals');

      expect(controller.state.status, AiStatus.success);
      expect(controller.state.sections, isEmpty);
      expect(controller.state.responseText, contains("couldn't parse"));
    });
  });

  group('scenario: 4xx from the backend', () {
    test('a validation rejection is sanitized for display', () async {
      respond = (HttpRequest request) async {
        request.response
          ..statusCode = 400
          ..headers.contentType = ContentType.json
          ..write('{"statusCode":400,"message":["prompt must not be empty"],'
              '"error":"Bad Request"}');
        await request.response.close();
      };

      final controller = controllerWith(_LocalHttpApiClient(baseUrl));

      await controller.submit('x');

      expect(controller.state.status, AiStatus.error);
      final message = controller.state.errorMessage!;
      expect(message,
          'That request could not be handled. Please rephrase and try again.');
      expect(message, isNot(contains('Bad Request')));
      expect(message, isNot(contains('statusCode')));
    });

    test('a 401 is sanitized for display', () async {
      respond = (HttpRequest request) async {
        request.response
          ..statusCode = 401
          ..headers.contentType = ContentType.json
          ..write('{"statusCode":401,"error":"Unauthorized"}');
        await request.response.close();
      };

      final controller = controllerWith(_LocalHttpApiClient(baseUrl));

      await controller.submit('x');

      expect(controller.state.status, AiStatus.error);
      expect(
        controller.state.errorMessage,
        'Your session has expired. Please sign in and try again.',
      );
    });
  });

  group('connection failure without a listener', () {
    test('a refused connection is sanitized and hides host and port', () async {
      // Bind and immediately release a port so nothing is listening on it.
      final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = probe.port;
      await probe.close(force: true);

      final controller =
          controllerWith(_LocalHttpApiClient('http://127.0.0.1:$deadPort'));

      await controller.submit('find hotels');

      expect(controller.state.status, AiStatus.error);
      final message = controller.state.errorMessage!;
      expect(
        message,
        'No connection to the assistant. Check your internet and try again.',
      );
      expect(message, isNot(contains('SocketException')));
      expect(message, isNot(contains('127.0.0.1')));
      expect(message, isNot(contains('$deadPort')));
    });
  });

  group('captured live OpenRouter payload', () {
    // Verbatim body returned by POST /ai/query on 2026-08-17 against
    // AI_BASE_URL=https://openrouter.ai/api/v1 with AI_MODEL=openrouter/auto.
    // OpenRouter's auto router resolved to openai/gpt-5.6-luna; upstream 200,
    // endpoint 201. Replayed here so the real-world shape stays covered
    // offline. Note what the model omitted: no section id, and no price,
    // currency, imageUrl or badge on either item — exactly the partial payload
    // the Phase 10A hardening has to absorb.
    const String liveDto =
        '{"text":"Here are two well-reviewed Paris hotels suitable for a '
        'weekend trip, offering different styles and locations.",'
        '"sections":[{"title":"Weekend hotel picks in Paris",'
        '"layout":"horizontal","items":[{"id":"hotel-paris-1","type":"hotel",'
        '"title":"H\u00f4tel Lutetia",'
        '"subtitle":"Saint-Germain-des-Pr\u00e9s, 6th arrondissement",'
        '"description":"A landmark luxury hotel on the Left Bank, ideal for '
        'art, dining, and exploring central Paris on foot.","rating":4.6,'
        '"reviewCount":1800,"actionLabel":"View hotel","order":1,'
        '"tags":["Luxury","Historic","Spa"],"actions":[{"type":"view",'
        '"label":"View hotel","payload":{"hotelName":"H\u00f4tel Lutetia",'
        '"city":"Paris"}}]},{"id":"hotel-paris-2","type":"hotel",'
        '"title":"Le Bristol Paris",'
        '"subtitle":"Champs-\u00c9lys\u00e9es, 8th arrondissement",'
        '"description":"An elegant palace hotel with refined rooms, acclaimed '
        'dining, and a peaceful garden near major attractions.","rating":4.8,'
        '"reviewCount":2200,"actionLabel":"View hotel","order":2,'
        '"tags":["Luxury","Fine dining","Central location"],'
        '"actions":[{"type":"view","label":"View hotel",'
        '"payload":{"hotelName":"Le Bristol Paris","city":"Paris"}}]}],'
        '"metadata":{},'
        '"subtitle":"Choose between classic Left Bank charm and a central '
        'boutique stay","order":1}],'
        '"metadata":{"queryId":"3b090536-dc09-4833-9acc-6333e5ebfe77",'
        '"version":1}}';

    setUp(() {
      respond = (HttpRequest request) async {
        request.response
          ..statusCode = 201
          ..headers.contentType = ContentType.json
          ..write(liveDto);
        await request.response.close();
      };
    });

    test('parses the live payload into the Flutter contract', () async {
      final response =
          await serviceWith(_LocalHttpApiClient(baseUrl)).query('paris hotels');

      expect(response.text, startsWith('Here are two well-reviewed Paris'));
      expect(response.metadata['version'], 1);
      expect(response.sections, hasLength(1));

      final section = response.sections.single;
      expect(section.title, 'Weekend hotel picks in Paris');
      expect(section.layout, HomeSectionLayout.horizontal);
      expect(section.order, 1);
      // The model supplied a subtitle but no id.
      expect(section.subtitle, isNotNull);
      expect(section.id, isNull);
      expect(section.items, hasLength(2));

      final first = section.items.first;
      expect(first.id, 'hotel-paris-1');
      expect(first.type, HomeCardType.hotel);
      expect(first.title, 'H\u00f4tel Lutetia');
      expect(first.rating, 4.6);
      expect(first.reviewCount, 1800);
      expect(first.actionLabel, 'View hotel');
      expect(first.order, 1);
      expect(first.tags, <String>['Luxury', 'Historic', 'Spa']);
      expect(first.actions.single.type, 'view');
      expect(first.actions.single.payload['city'], 'Paris');
      // Omitted by the model — must degrade, not throw.
      expect(first.price, isNull);
      expect(first.currency, isNull);
      expect(first.imageUrl, isNull);
      expect(first.badge, isNull);
      expect(first.highlights, isEmpty);
    });

    test('the controller renders the live payload and generates the section id',
        () async {
      final controller = controllerWith(_LocalHttpApiClient(baseUrl));

      await controller.submit('paris hotels');

      expect(controller.state.status, AiStatus.success);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.sections, hasLength(1));

      final mapped = controller.state.sections.single;
      // No id in the payload, so the mapper synthesises a stable one.
      expect(mapped.id, 'ai-section-0');
      expect(mapped.layout, HomeSectionLayout.horizontal);
      expect(mapped.items, hasLength(2));
      // Explicit order hints 1 and 2 are honoured.
      expect(
        mapped.items.map((i) => i.id).toList(),
        <String>['hotel-paris-1', 'hotel-paris-2'],
      );
      expect(mapped.items.every((i) => i.type == HomeCardType.hotel), isTrue);
    });

    test('the live payload carries no credential material', () async {
      final response =
          await serviceWith(_LocalHttpApiClient(baseUrl)).query('paris hotels');

      final serialised = response.metadata.toString() +
          response.sections
              .expand((s) => s.items)
              .map((i) => '${i.data}${i.metadata}')
              .join();
      expect(serialised, isNot(contains('sk-or')));
      expect(serialised, isNot(contains('Bearer')));
      expect(serialised, isNot(contains('openrouter')));
      // Provider identity must not reach the client contract.
      expect(response.metadata.containsKey('model'), isFalse);
      expect(response.metadata.containsKey('provider'), isFalse);
    });
  });
}
