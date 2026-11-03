import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/network/http_api_client.dart';

void main() {
  group('HttpApiClient.validateBaseUrl (release mode)', () {
    test('HTTPS is always allowed', () {
      expect(
        () => HttpApiClient.validateBaseUrl(
          'https://api.example.com',
          isRelease: true,
          allowInsecureLocalApi: false,
        ),
        returnsNormally,
      );
    });

    test('HTTP is rejected when the insecure flag is false', () {
      expect(
        () => HttpApiClient.validateBaseUrl(
          'http://192.168.1.3:3000',
          isRelease: true,
          allowInsecureLocalApi: false,
        ),
        throwsStateError,
      );
    });

    test('HTTP is rejected for public IPs even with the flag', () {
      expect(
        () => HttpApiClient.validateBaseUrl(
          'http://8.8.8.8:3000',
          isRelease: true,
          allowInsecureLocalApi: true,
        ),
        throwsStateError,
      );
    });

    test('HTTP is rejected for hostnames even with the flag', () {
      expect(
        () => HttpApiClient.validateBaseUrl(
          'http://example.com:3000',
          isRelease: true,
          allowInsecureLocalApi: true,
        ),
        throwsStateError,
      );
    });

    test('HTTP is rejected for localhost even with the flag', () {
      expect(
        () => HttpApiClient.validateBaseUrl(
          'http://localhost:3000',
          isRelease: true,
          allowInsecureLocalApi: true,
        ),
        throwsStateError,
      );
    });

    test('HTTP is allowed for 10/8 with the flag', () {
      expect(
        () => HttpApiClient.validateBaseUrl(
          'http://10.0.0.5:3000',
          isRelease: true,
          allowInsecureLocalApi: true,
        ),
        returnsNormally,
      );
    });

    test('HTTP is allowed for 172.16/12 with the flag', () {
      expect(
        () => HttpApiClient.validateBaseUrl(
          'http://172.16.5.4:3000',
          isRelease: true,
          allowInsecureLocalApi: true,
        ),
        returnsNormally,
      );
      expect(
        () => HttpApiClient.validateBaseUrl(
          'http://172.31.255.1:3000',
          isRelease: true,
          allowInsecureLocalApi: true,
        ),
        returnsNormally,
      );
    });

    test('HTTP is rejected for 172.15 and 172.32 even with the flag', () {
      expect(
        () => HttpApiClient.validateBaseUrl(
          'http://172.15.0.1:3000',
          isRelease: true,
          allowInsecureLocalApi: true,
        ),
        throwsStateError,
      );
      expect(
        () => HttpApiClient.validateBaseUrl(
          'http://172.32.0.1:3000',
          isRelease: true,
          allowInsecureLocalApi: true,
        ),
        throwsStateError,
      );
    });

    test('HTTP is allowed for 192.168/16 with the flag', () {
      expect(
        () => HttpApiClient.validateBaseUrl(
          'http://192.168.1.3:3000',
          isRelease: true,
          allowInsecureLocalApi: true,
        ),
        returnsNormally,
      );
    });
  });

  group('HttpApiClient.validateBaseUrl (debug mode)', () {
    test('does not restrict URLs', () {
      expect(
        () => HttpApiClient.validateBaseUrl(
          'http://example.com:3000',
          isRelease: false,
        ),
        returnsNormally,
      );
    });
  });
}
