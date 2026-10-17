import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';

void main() {
  group('InMemorySecureTokenStorage', () {
    late InMemorySecureTokenStorage storage;

    setUp(() {
      storage = InMemorySecureTokenStorage();
    });

    test('save and read access token', () async {
      await storage.saveAccessToken('access123');
      expect(await storage.getAccessToken(), 'access123');
    });

    test('save and read refresh token', () async {
      await storage.saveRefreshToken('refresh456');
      expect(await storage.getRefreshToken(), 'refresh456');
    });

    test('delete access token', () async {
      await storage.saveAccessToken('a');
      await storage.deleteAccessToken();
      expect(await storage.getAccessToken(), isNull);
    });

    test('delete refresh token', () async {
      await storage.saveRefreshToken('r');
      await storage.deleteRefreshToken();
      expect(await storage.getRefreshToken(), isNull);
    });

    test('clearAll removes both', () async {
      await storage.saveAccessToken('a');
      await storage.saveRefreshToken('r');
      await storage.clearAll();
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });

    test('missing token returns null', () async {
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });

    test('tokens remain independent', () async {
      await storage.saveAccessToken('a');
      await storage.saveRefreshToken('r');
      await storage.deleteAccessToken();
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), 'r');
    });
  });
}
