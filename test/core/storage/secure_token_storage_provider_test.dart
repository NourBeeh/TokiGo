import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';
import 'package:tokigo/core/storage/secure_token_storage_provider.dart';

void main() {
  group('secureTokenStorageProvider', () {
    test('production provider returns PlatformSecureTokenStorage', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final storage = container.read(secureTokenStorageProvider);
      expect(storage, isA<PlatformSecureTokenStorage>());
      expect(storage, isNot(isA<InMemorySecureTokenStorage>()));
    });

    test('production provider does not use MemoryTokenStorage', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final storage = container.read(secureTokenStorageProvider);
      // PlatformSecureTokenStorage should not be InMemory which internally uses MemoryTokenStorage
      expect(storage, isNot(isA<InMemorySecureTokenStorage>()));
    });
  });
}
