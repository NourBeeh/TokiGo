import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_token_storage.dart';

/// Production provider for secure token storage.
///
/// Returns [PlatformSecureTokenStorage] which uses OS-backed secure storage.
/// [InMemorySecureTokenStorage] is reserved for tests/dev only and must not be
/// used in production code paths.
///
/// The [SecureTokenStorage] abstraction is preserved unchanged.
final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return PlatformSecureTokenStorage();
});
