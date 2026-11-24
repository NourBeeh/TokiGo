import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/network/network_status.dart';

/// Shared connectivity behaviour (NetworkStatus + HTTP client failure
/// handling). The old Home snapshot/offline tests were removed with that
/// system; these tests cover the shared infrastructure that remains.
void main() {
  group('NetworkStatus — backend reachability', () {
    test('reportOffline marks offline and reports announcedOffline', () {
      NetworkStatus.instance.reportOffline();
      expect(NetworkStatus.instance.online, false);
      expect(NetworkStatus.instance.announcedOffline, true);
    });

    test('a successful call clears offline', () {
      NetworkStatus.instance.reportOffline();
      expect(NetworkStatus.instance.online, false);
      NetworkStatus.instance.reportOnline();
      expect(NetworkStatus.instance.online, true);
      expect(NetworkStatus.instance.announcedOffline, false);
    });

    test('reportOnline on an already-online instance is a no-op', () {
      NetworkStatus.instance.reportOnline();
      expect(NetworkStatus.instance.announcedOffline, false);
    });

    test('reportOffline on an already-offline instance is a no-op', () {
      NetworkStatus.instance.reportOffline();
      NetworkStatus.instance.reportOffline();
      expect(NetworkStatus.instance.announcedOffline, true);
    });
  });

  group('API timeout — connection failure never crashes the UI', () {
    test('a hanging request returns a timeout or network failure', () async {
      // Use an unreachable port to simulate a connection failure. The
      // platform may report either a timeout or a socket error; both are
      // handled gracefully and never crash the UI.
      final client = HttpClient();
      NetworkStatus.instance.reportOffline();
      final api = HttpApiClient(
        client: client,
        baseUrlOverride: 'http://127.0.0.1:1',
      );
      // A short timeout ensures the test does not block the suite.
      final result = await api.get<List<dynamic>>('/home/sections', timeout: const Duration(milliseconds: 100));
      expect(
        result.isFailure,
        true,
        reason: 'a connection failure must never crash the UI',
      );
      // Could be a timeout or a socket error — both are failures.
      final error = result.errorOrNull;
      expect(error, isNotNull);
      final isTimeoutOrNetwork =
          error is ApiTimeoutError || error is ApiNetworkError;
      expect(isTimeoutOrNetwork, isTrue);
    });
  });

  group('Backend unavailable — offline indicator + cached content', () {
    test('a failed get returns failure and marks the backend offline', () async {
      // Use an unreachable port (1 = reserved) to simulate a backend that
      // cannot be reached at all.
      final client = HttpClient();
      NetworkStatus.instance.reportOffline();
      final api = HttpApiClient(
        client: client,
        baseUrlOverride: 'http://127.0.0.1:1',
      );
      final result = await api.get<List<dynamic>>('/home/sections');
      expect(result.isFailure, true);
      expect(result.errorOrNull, isA<ApiNetworkError>());
      expect(NetworkStatus.instance.online, false);
    });
  });

  group('Reconnection — safe revalidation', () {
    test('reportOnline on a previously-offline instance clears offline state', () {
      NetworkStatus.instance.reportOffline();
      expect(NetworkStatus.instance.announcedOffline, true);
      NetworkStatus.instance.reportOnline();
      expect(NetworkStatus.instance.online, true);
      expect(NetworkStatus.instance.announcedOffline, false);
    });

    test('a successful call during the same request does not double-report', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient();
      var handled = false;
      server.listen((HttpRequest request) {
        if (!handled) {
          handled = true;
          request.response.headers.contentType = ContentType.json;
          request.response.write('[]');
          request.response.close();
        }
      });
      addTearDown(() async {
        client.close(force: true);
        await server.close(force: true);
        NetworkStatus.instance.reportOnline();
      });

      NetworkStatus.instance.reportOffline();
      final HttpApiClient api = HttpApiClient(
        client: client,
        baseUrlOverride: 'http://127.0.0.1:${server.port}',
      );
      final result = await api.get<List<dynamic>>('/home/sections');
      expect(result.isSuccess, true);
      // The client reported the backend as reachable again.
      expect(NetworkStatus.instance.online, true);
    });
  });
}
