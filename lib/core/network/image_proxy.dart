import 'package:tokigo/core/network/http_api_client.dart';

/// Routes remote images through the backend resizer.
///
/// Nuitee's CDN serves 450–600KB originals and ignores resize query params, so
/// a six-card Home rail used to download ~3MB. `GET /images/hotel` re-encodes
/// the photo as WebP at the requested width (and caches it), which is the
/// difference between a 500KB photo and a 40KB one on mobile data.
///
/// Only absolute http(s) URLs are proxied; bundled assets and already-proxied
/// URLs pass through untouched. If the backend cannot proxy a source it
/// redirects to the original, so callers keep working either way.
class ImageProxy {
  const ImageProxy._();

  /// Optional CDN origin for images, e.g.
  /// `--dart-define=IMAGE_BASE_URL=https://cdn.tokigo.app`.
  ///
  /// Pointing this at an edge cache keeps the API host free of photo traffic
  /// and lets the CDN serve repeats without touching the backend. Empty means
  /// "same host as the API", which is what local development uses.
  static const String _configuredBase = String.fromEnvironment('IMAGE_BASE_URL');

  /// Card / rail photo width (physical pixels). Covers a ~260dp card at 2.5x.
  static const int cardWidth = 640;

  /// Full-bleed details-page hero.
  static const int heroWidth = 1280;

  /// Airline / provider logo plate.
  static const int logoWidth = 160;

  /// Returns [url] routed through the image proxy, or [url] unchanged when it
  /// is not a remote image (asset, data URI, empty) or the proxy base is
  /// unavailable.
  static String? proxied(String? url, {int width = cardWidth}) {
    if (url == null || url.isEmpty) return url;
    final String lower = url.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return url;
    }
    // Never wrap an already-proxied URL.
    if (url.contains('/images/hotel?')) return url;

    final String base;
    try {
      base = _imageBase;
    } catch (_) {
      return url;
    }
    if (base.isEmpty) return url;

    final int safeWidth = width.clamp(80, 1600);
    return '$base/images/hotel?src=${Uri.encodeComponent(url)}&w=$safeWidth';
  }

  /// The CDN override when set, otherwise the API host, without a trailing
  /// slash (so the path concatenation above never doubles one).
  static String get _imageBase {
    final String configured = _configuredBase.trim();
    final String resolved =
        configured.isNotEmpty ? configured : HttpApiClient.defaultBaseUrl;
    return resolved.endsWith('/')
        ? resolved.substring(0, resolved.length - 1)
        : resolved;
  }
}
