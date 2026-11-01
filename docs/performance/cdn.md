# Image CDN (edge cache)

Status: **origin ready, edge not provisioned.** The backend already sends the
headers a CDN needs and the app can be pointed at an edge host with a build
flag; what is left is a provider account and a DNS record.

## Why

`GET /images/hotel` re-encodes a 460KB provider photo into a ~19KB WebP. That
work is done once per photo **per backend instance**, and every cold instance
(restart, deploy, autoscale) pays it again. An edge cache pays it once globally
and then answers from the nearest PoP.

## What the origin already does

`backend/src/modules/images/images.controller.ts`:

| Header | Value | Meaning |
|---|---|---|
| `Cache-Control` | `public, max-age=604800, stale-while-revalidate=86400, immutable` | browser / shared cache |
| `CDN-Cache-Control` | `public, max-age=604800, immutable` | Cloudflare, Fastly |
| `Surrogate-Control` | `public, max-age=604800, immutable` | Fastly, Varnish |
| `ETag` | content hash | `If-None-Match` → `304` |
| `X-Image-Cache` | `HIT` / `MISS` | origin disk cache state |
| `Access-Control-Allow-Origin` | `*` | web build |

Caching for a week is safe because the URL is the content address:
`/images/hotel?src=<encoded original>&w=480&f=webp`. Change any input and the
URL changes, so a stale entry is impossible.

> The API's CORS middleware also emits `Vary: Origin`. Do not include request
> headers in the edge cache key — key on the full URL only (Cloudflare does
> this by default; the nginx config below pins it explicitly), otherwise every
> origin gets its own copy of the same photo.

## 1. Cloudflare (recommended: free tier covers this)

1. Add the zone and proxy the record (orange cloud) for `cdn.<domain>`.
2. **Caching → Cache Rules → Create rule**
   - When: `URI Path starts with "/images/"`
   - Then: *Eligible for cache*, **Edge TTL: 1 week**, **Browser TTL: respect origin**.
3. **Caching → Tiered Cache**: on (fewer origin fetches on a miss).
4. Verify:

   ```bash
   curl -sI "https://cdn.<domain>/images/hotel?src=https%3A%2F%2Fstatic.cupid.travel%2Fhotels%2F491132974.jpg&w=480" | grep -i -E 'cf-cache-status|cache-control'
   # first call: cf-cache-status: MISS (origin: X-Image-Cache: MISS)
   # second call: cf-cache-status: HIT
   ```

5. Point the app at it (see below).

CloudFront equivalent: cache policy with `MinTTL/DefaultTTL/MaxTTL = 604800`,
forward **all** query strings (`src`, `w`, `f` are the cache key), compress off
(the payload is already WebP).

## 2. Self-hosted nginx

`backend/deploy/nginx/images-cache.conf` is a ready `proxy_cache` config: disk
cache, `proxy_cache_lock` (one origin fetch per photo under concurrency),
`stale-while-revalidate` behaviour and `X-Cache-Status` for verification.

```bash
curl -sI "http://cdn.local/images/hotel?src=…&w=480" | grep -i x-cache-status
```

## 3. Point the app at the edge

The app talks to the API on `API_BASE_URL` and to images on `IMAGE_BASE_URL`.
Leaving `IMAGE_BASE_URL` empty keeps images on the API host (local dev).

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.tokigo.app \
  --dart-define=IMAGE_BASE_URL=https://cdn.tokigo.app
```

`lib/core/network/image_proxy.dart` strips a trailing slash and falls back to
the API host, so a misconfigured flag degrades to the previous behaviour rather
than to broken images.

## Expected effect

| | origin only | behind an edge |
|---|---|---|
| First request for a photo, per region | ~100ms + 460KB upstream | ~100ms once |
| Repeat request | ~5ms (origin disk) | ~5–20ms, **no origin traffic** |
| Origin resize work per photo | once per instance | once globally |

The origin still needs `IMAGE_CACHE_MAX_BYTES` (default 256MB) because it is
the last line of defence when the edge misses.
