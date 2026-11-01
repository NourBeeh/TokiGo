import 'package:flutter_test/flutter_test.dart';

import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/network/image_proxy.dart';

/// Remote photos must go through the backend resizer; everything else must
/// pass through untouched.
///
/// The proxy is a pure URL rewrite, so these cases are the whole contract:
/// bundled assets and data URIs are not remote, and re-wrapping an already
/// proxied URL would produce a proxy-of-a-proxy (and a broken `src`).
void main() {
  // The proxy must follow whatever host the API talks to, including a LAN
  // override — so the expected prefix is derived, not hardcoded.
  final String base = HttpApiClient.defaultBaseUrl;

  test('the proxy lives on the same host as the API', () {
    expect(ImageProxy.proxied('https://example.com/a.jpg'), startsWith('$base/'));
  });

  test('a remote https photo is routed through the resizer', () {
    const String photo = 'https://static.cupid.travel/hotels/491132974.jpg';

    final String? proxied = ImageProxy.proxied(photo, width: 480);

    expect(proxied, isNotNull);
    expect(proxied, startsWith('$base/images/hotel?'));
    expect(proxied, contains('w=480'));
    // The original URL is encoded, so its query string cannot leak into ours.
    expect(proxied, contains(Uri.encodeComponent(photo)));
  });

  test('the requested width is clamped to a sane range', () {
    expect(ImageProxy.proxied('https://example.com/a.jpg', width: 1), contains('w=80'));
    expect(
      ImageProxy.proxied('https://example.com/a.jpg', width: 99999),
      contains('w=1600'),
    );
  });

  test('assets, data URIs and empty values are returned unchanged', () {
    expect(ImageProxy.proxied('assets/images/hotel.png'), 'assets/images/hotel.png');
    expect(ImageProxy.proxied('data:image/png;base64,AAAA'), 'data:image/png;base64,AAAA');
    expect(ImageProxy.proxied(''), '');
    expect(ImageProxy.proxied(null), isNull);
  });

  test('an already proxied URL is never wrapped twice', () {
    const String already = 'http://localhost:3000/images/hotel?src=x&w=480';
    expect(ImageProxy.proxied(already), already);
  });
}
