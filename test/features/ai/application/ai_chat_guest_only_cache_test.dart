import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';
import 'package:tokigo/features/ai/application/ai_chat_guest_only_cache.dart';

/// 2C-C2 — the identity-aware conversation cache policy.
///
/// Guests read+write the shared cache; authenticated turns bypass BOTH
/// (anti-resurrection: a memory-enriched reply must never be replayed after
/// a memory edit/clear/toggle). Unreadable storage fails CLOSED (no
/// caching when identity is unknown).
class _FakeTokenStorage implements SecureTokenStorage {
  _FakeTokenStorage(this.token);

  final String? token;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> saveAccessToken(String value) async {}

  @override
  Future<void> saveRefreshToken(String value) async {}

  @override
  Future<void> deleteAccessToken() async {}

  @override
  Future<void> deleteRefreshToken() async {}

  @override
  Future<void> clearAll() async {}
}

class _ThrowingTokenStorage implements SecureTokenStorage {
  @override
  Future<String?> getAccessToken() => throw StateError('unreadable');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError();
}

void main() {
  const entry = <String, dynamic>{'text': 'hello'};

  test('GUEST: read and write pass through to the inner cache', () async {
    final inner = MemoryOfflineCache();
    final cache = AiChatGuestOnlyCache(
      inner: inner,
      tokenStorage: _FakeTokenStorage(null),
    );

    await cache.write('ai|k1', entry);
    expect(await cache.read('ai|k1'), entry);
    expect(await inner.read('ai|k1'), entry);
  });

  test('AUTHENTICATED: read returns null and write is a no-op (bypass)',
      () async {
    final inner = MemoryOfflineCache();
    // A stale entry exists under the guest key from an earlier session.
    await inner.write('ai|k1', entry);
    final cache = AiChatGuestOnlyCache(
      inner: inner,
      tokenStorage: _FakeTokenStorage('jwt-token'),
    );

    // Read bypassed — no stale personalization is ever replayed.
    expect(await cache.read('ai|k1'), isNull);
    // Write bypassed — the inner cache stays untouched.
    await cache.write('ai|k2', entry);
    expect(await inner.read('ai|k2'), isNull);
    expect(await inner.read('ai|k1'), entry); // pre-existing guest entry kept
  });

  test('unreadable storage fails CLOSED: no caching on unknown identity',
      () async {
    final inner = MemoryOfflineCache();
    await inner.write('ai|k1', entry);
    final cache = AiChatGuestOnlyCache(
      inner: inner,
      tokenStorage: _ThrowingTokenStorage(),
    );

    expect(await cache.read('ai|k1'), isNull);
    await cache.write('ai|k2', entry);
    expect(await inner.read('ai|k2'), isNull);
  });

  test('empty token counts as guest', () async {
    final inner = MemoryOfflineCache();
    final cache = AiChatGuestOnlyCache(
      inner: inner,
      tokenStorage: _FakeTokenStorage(''),
    );

    await cache.write('ai|k1', entry);
    expect(await cache.read('ai|k1'), entry);
  });

  test('management verbs delegate unconditionally', () async {
    final inner = MemoryOfflineCache();
    final cache = AiChatGuestOnlyCache(
      inner: inner,
      tokenStorage: _FakeTokenStorage('jwt-token'),
    );

    // Never called by AiController, but the contract stays a plain
    // delegation for anything else that holds the cache.
    await inner.write('ai|k1', entry);
    expect(await cache.contains('ai|k1'), isTrue);
    expect(await cache.keys(), contains('ai|k1'));
    await cache.delete('ai|k1');
    expect(await cache.contains('ai|k1'), isFalse);
    await cache.clear();
    expect(await cache.keys(), isEmpty);
  });
}
