import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/network/api_error.dart';

void main() {
  test('abort() invoked when RequestToken.cancel() called during slow response', () async {
    // Start an isolated server that delays its response to simulate a slow backend.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => await server.close(force: true));

    final port = server.port;
    final baseUrl = 'http://127.0.0.1:$port';

    final serverHandled = Completer<void>();

    server.listen((HttpRequest req) async {
      // consume request body
      await utf8.decoder.bind(req).join();

      // Delay before sending any bytes to simulate slowness
      await Future<void>.delayed(const Duration(milliseconds: 300));

      try {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"ok":true}');
        await req.response.close();
      } catch (_) {
        // The client may have disconnected; ignore write errors.
      } finally {
        if (!serverHandled.isCompleted) serverHandled.complete();
      }
    });

    bool aborted = false;
    final client = HttpApiClient(baseUrlOverride: baseUrl, onAbort: () => aborted = true);
    final token = RequestToken();

    // Schedule cancellation shortly after issuing the request.
    Future<void>.delayed(const Duration(milliseconds: 50), () => token.cancel());

    final result = await client.post<Map<String, dynamic>>('/slow', body: {'x': 1}, token: token);

    expect(aborted, true, reason: 'onAbort callback should be invoked');
    expect(result.isFailure, true);
    expect(result.errorOrNull, isA<ApiRequestCancelledError>());

    await serverHandled.future;
  });
}
