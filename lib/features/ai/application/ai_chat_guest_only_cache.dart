import 'package:tokigo/core/storage/offline_cache.dart';
import 'package:tokigo/core/storage/secure_token_storage.dart';

/// 2C-C2 — guest-only offline cache for the conversation page.
///
/// Wraps the shared [OfflineCache] and serves entries to [AiController]
/// ONLY while the caller is a guest. Authenticated turns bypass BOTH the
/// read and the write:
///
/// - an authenticated reply depends on the caller's explicit memories (and
///   the personalization opt-out) at answer time — the same prompt can
///   legitimately answer differently after a memory edit, a clear, or a
///   toggle. Serving a cached reply there would resurrect stale
///   personalization forever (the same anti-resurrection policy Home
///   applies to withdrawn content);
/// - guests have no memory machinery, so their memory-free answers stay
///   safely cacheable and instant offline.
///
/// Management operations ([delete], [contains], [clear], [keys]) delegate
/// unconditionally — they never serve content, and [AiController] never
/// calls them.
class AiChatGuestOnlyCache implements OfflineCache {
  AiChatGuestOnlyCache({required this.inner, required this.tokenStorage});

  final OfflineCache inner;
  final SecureTokenStorage tokenStorage;

  /// Guest = cacheable. Unreadable storage is NOT guest — fail closed.
  Future<bool> _allowsCaching() async {
    try {
      final token = await tokenStorage.getAccessToken();
      return token == null || token.isEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    if (!await _allowsCaching()) return null;
    return inner.read(key);
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    if (!await _allowsCaching()) return;
    return inner.write(key, value);
  }

  @override
  Future<void> delete(String key) => inner.delete(key);

  @override
  Future<bool> contains(String key) => inner.contains(key);

  @override
  Future<void> clear() => inner.clear();

  @override
  Future<List<String>> keys() => inner.keys();

  @override
  Future<void> compact() => inner.compact();
}
