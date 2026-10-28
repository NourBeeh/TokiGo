import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/network/http_api_client.dart';

/// The base URL must never encode one developer's network (regression,
/// 2026-10-25).
///
/// `HttpApiClient` used to fall back to a hardcoded `http://192.168.1.3:3000`
/// on Android. That address only exists on the machine it was typed on; every
/// other device and every CI run then sat on the request timeout and the app
/// reported "we couldn't reach the travel service" with no hint why.
///
/// There are two supported ways to aim the app at a backend — `adb reverse`
/// plus localhost, or `--dart-define=API_BASE_URL=…` — and this pins that the
/// default is the one that is true everywhere.
void main() {
  test('without a build-time override the client talks to localhost', () {
    final HttpApiClient client = HttpApiClient();

    expect(client.baseUrl, 'http://localhost:3000');
    // A LAN address copied into source is exactly the bug this file guards.
    expect(client.baseUrl, isNot(contains('192.168.')));
  });

  test('an explicit override still wins', () {
    final HttpApiClient client = HttpApiClient(
      baseUrlOverride: 'http://10.1.2.3:8080',
    );

    expect(client.baseUrl, 'http://10.1.2.3:8080');
  });
}
