import 'token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureTokenStorage {
  Future<void> saveAccessToken(String token);
  Future<String?> getAccessToken();
  Future<void> deleteAccessToken();

  Future<void> saveRefreshToken(String token);
  Future<String?> getRefreshToken();
  Future<void> deleteRefreshToken();

  Future<void> clearAll();
}

/// In-memory implementation for development and testing.
/// Platform-secure storage is not available without adding external packages.
/// This implementation must NOT be used in production.
class InMemorySecureTokenStorage implements SecureTokenStorage {
  final MemoryTokenStorage _backend = MemoryTokenStorage();
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  @override
  Future<void> saveAccessToken(String token) =>
      _backend.write(_accessKey, token);
  @override
  Future<String?> getAccessToken() => _backend.read(_accessKey);
  @override
  Future<void> deleteAccessToken() => _backend.delete(_accessKey);

  @override
  Future<void> saveRefreshToken(String token) =>
      _backend.write(_refreshKey, token);
  @override
  Future<String?> getRefreshToken() => _backend.read(_refreshKey);
  @override
  Future<void> deleteRefreshToken() => _backend.delete(_refreshKey);

  @override
  Future<void> clearAll() => _backend.clear();
}

/// Production implementation using OS-backed secure storage.
/// iOS/iPadOS → Keychain
/// Android → Android Keystore-backed
/// Linux → libsecret via flutter_secure_storage_linux
///
/// Tokens are never logged. Failures are handled safely by returning null or swallowing errors on delete/clear.
class PlatformSecureTokenStorage implements SecureTokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  PlatformSecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> saveAccessToken(String token) async {
    try {
      await _storage.write(key: _accessKey, value: token);
    } catch (_) {
      // Safety: do not throw or log token.
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteAccessToken() async {
    try {
      await _storage.delete(key: _accessKey);
    } catch (_) {}
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshKey, value: token);
    } catch (_) {}
  }

  @override
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteRefreshToken() async {
    try {
      await _storage.delete(key: _refreshKey);
    } catch (_) {}
  }

  @override
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
