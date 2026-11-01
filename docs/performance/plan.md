# Performance repair plan (2026-10-28)

Goal: make TokiGo's Home and hotel search feel as fast as Booking.com on a
phone, not just on a laptop with a warm cache.

The diagnosis found five separate problems. They are independent, so each one
below ships on its own and can be reverted on its own.

| # | Problem | Fix | Status |
|---|---------|-----|--------|
| 1 | All timings came from debug builds | `perf:probe` script + documented Release/Profile workflow | done |
| 2 | Hotel photos are 450–600KB originals | Backend image proxy (WebP resize + disk LRU) | done |
| 3 | No gzip on JSON responses | `compression` middleware | done |
| 4 | Home waited for rail *then* feed, then composed | Parallel requests, publish first, compose in background | done |
| 5 | In-memory cache, 120s TTL, cold start after deploy | Redis (optional) + 300s TTL + warmup | done |

---

## 1. Measure on Release, and measure bytes

Debug builds are not a valid signal: `flutter.log` showed
`Skipped 1353 frames!` and `Davey! duration=22712ms` while the same code was
fine on a warm run. The `offline cache ready in 7303ms` line also came from a
debug build.

**Backend probe** — repeatable, no external tooling:

```powershell
cd backend
npm run build
$env:BASE_URL='http://127.0.0.1:3000'; npm run perf:probe
```

It reports, per endpoint, the median latency plus **wire bytes** and **JSON
bytes** (it sends the request twice, with and without `Accept-Encoding: gzip`).
That is the only honest way to show what the radio actually downloads.

**App probe** — always Release or Profile on a real device:

```powershell
flutter run --profile --dart-define=API_BASE_URL=http://<lan-ip>:3000
# then, in DevTools: Performance → record a cold Home → stop
```

Check three numbers: time to first content, frame-build p90, and total bytes
received (DevTools Network tab). A debug run is only useful for logic.

## 2. Image proxy (`GET /images/hotel`)

`static.cupid.travel` ignores resize query params, so every Home card used to
download the full photo.

- `backend/src/modules/images/image-proxy.service.ts` fetches the original
  once, re-encodes it as WebP at the requested width and stores it under
  `backend/.cache/images` (gitignored, size-bounded LRU, atomic writes).
- `images.controller.ts` serves it with `ETag` + `Cache-Control: immutable`,
  and **302-redirects to the original** whenever it cannot proxy. A broken
  proxy degrades to "the old behaviour", never to a blank card.
- Host allowlist (`IMAGE_PROXY_HOSTS`), private-IP/DNS-rebinding guard, 10s
  upstream timeout and a 12MB input cap: this is not an open fetch proxy.
- Client side: `lib/core/network/image_proxy.dart` rewrites remote URLs only.
  The Hive disk cache stays keyed by the **original** URL, so existing cached
  photos keep working.

Measured (`w=480`): **461.8KB original → 19.2KB WebP (−96%)**, first request
~100ms, cache hit ~5ms. `w=1280&f=jpeg` (details hero) is 151KB.

Tuning knobs: `IMAGE_CACHE_DIR`, `IMAGE_CACHE_MAX_BYTES` (default 256MB),
`IMAGE_PROXY_HOSTS`. In production put a CDN in front of `/images/hotel`;
`immutable` + a hashed URL make that safe.

## 3. gzip

`backend/src/main.ts` adds `compression({ threshold: 1024 })`. Measured:

| Response | JSON | Wire (gzip) | Saved |
|---|---|---|---|
| `GET /home/sections` | 10.7KB | 1.6KB | 85% |
| `GET /home/recommended` | 14.4KB | 8.2KB | 43% |
| `POST /search/hotels` | 145–154KB | 54–57KB | 63% |

On a 3G-class link that is seconds off the search screen. Anything under 1KB is
left alone (compressing it costs more than it saves).

## 4. Home loads in parallel and paints before personalizing

`HomeController.load()` used to `await` the feed, `await` the composer (profile
‖ geo ‖ behavior), and only then call `loadRecommendedHotels()`. Three serial
round trips before the traveller saw anything.

Now:

1. the provider-backed rail and the feed start **together**;
2. the network sections are published as soon as the feed lands;
3. personalization composes in the background and replaces them only if it
   still belongs to the same load (`_loadGeneration` guards the race);
4. the snapshot is persisted after composition, so the next cold start is
   instant.

Personalization is an enhancement, never a gate: if it fails or is slow, the
uncomposed sections stay on screen.

## 5. Cache: shared, longer, pre-warmed

- `redis.cache.provider.ts` is a real Redis client (`SCAN`-based invalidation,
  no `KEYS`) that **falls back to the in-memory map on any error** and never
  blocks boot on the socket. `cache.module.ts` picks Redis only when
  `REDIS_URL`/`REDIS_HOST` is set, so local dev is unchanged.
- TTLs: `SEARCH_CACHE_TTL_SECONDS` default **300** (was 120 — shorter than a
  Home → Search → Back round trip), `RECOMMENDED_CACHE_TTL_SECONDS` default 300.
  Cached prices remain presentation snapshots: the booking path revalidates the
  offer before any charge.
- Warmup: `RecommendWarmupService` (`WARM_HOME_ON_BOOT=true`) warms EG/AE/SA/TR/GB
  ~2s after boot; `npm run prewarm:home` does the same on demand (also against
  a deployed host via `BACKEND_URL`).
- `docker-compose.yml` gained an optional `redis` service with
  `allkeys-lru` and a memory cap.

---

## Round 2 (started 2026-10-28)

### 1. Device measurement (Release/Profile on real hardware)

`integration_test/perf_network_test.dart` + `test_driver/integration_test.dart`
measure, on the phone itself: cold start → first frame, `/home/sections`,
`/home/recommended`, cold vs warm hotel search, and the proxied photo vs the
provider original.

```powershell
# backend on a LAN-reachable port, then:
flutter drive --profile -d <device-id> `
  --driver=test_driver/integration_test.dart `
  --target=integration_test/perf_network_test.dart `
  --dart-define=API_BASE_URL=http://<lan-ip>:3000
# → integration_response_data.json + TOKIGO_PERF block on stdout
```

Two Android bugs had to be fixed before a device could be measured at all:

- `AndroidManifest.xml` (main) had **no INTERNET permission** — Flutter's
  template only adds it to the debug/profile manifests, so a release APK could
  not reach the API. Added to main.
- Android 9+ blocks cleartext HTTP, so dev builds could not reach a LAN
  backend. `network_security_config.xml` allows cleartext in debug/profile
  only; release keeps the platform default and `HttpApiClient` still refuses a
  plaintext base URL there.

### Device baseline (Samsung SM-A013G, Android 10, profile build, Wi-Fi)

| Measurement | Result |
|---|---|
| Cold start → first frame | **301 ms** |
| `GET /home/sections` (2 sections) | **30 ms** |
| `GET /home/recommended` (6 hotels, warm) | 21 ms (3.9 s cold) |
| `POST /search/hotels` cold (39 offers) | **4134 ms** |
| `POST /search/hotels` warm (39 offers) | **63 ms** |
| Hotel photo, proxied `w=640` | **40.2KB in 131 ms** |
| Same photo, provider original | **672.6KB in 396 ms** |

The photo is **94% smaller and 3× faster** on the phone itself — that is the
image-proxy win measured where it matters, not on the host.

### 2. Image CDN

Origin side is done: `CDN-Cache-Control` + `Surrogate-Control` (Cloudflare and
Fastly/Varnish) alongside the week-long immutable `Cache-Control`, and the URL
already content-addresses `src`/`w`/`f`, so a cached entry can never be wrong.

- `backend/deploy/nginx/images-cache.conf` — self-hosted edge cache with
  `proxy_cache_lock` and stale-while-revalidate.
- `docs/performance/cdn.md` — Cloudflare/CloudFront setup and verification.
- `--dart-define=IMAGE_BASE_URL=https://cdn.<domain>` points the app at the
  edge; empty keeps images on the API host (local dev).

Remaining: provision the zone and set the build flag (needs a provider account).

### 3. Cold-search prefetch

A cold `POST /search/hotels` is Nuitee-bound (3.5–5s). A warmer makes sure the
first *traveller* is not the one paying for it:

- `SearchWarmupService` (`WARM_SEARCH_ON_BOOT=true`, optional
  `SEARCH_WARM_INTERVAL_MINUTES`) warms the popular cities of the launch
  markets for the next two Friday→Sunday windows, in rotating batches.
- `npm run prewarm:search` does the same on demand / from cron.
- The cache key is now **canonical** (`canonicalSearchCacheKey`): sorted keys,
  trimmed/lowercased strings, ISO dates reduced to their day, nulls dropped,
  filter arrays treated as sets. Before this, a warmed entry never matched a
  real request because `JSON.stringify` is order-sensitive.

Measured end to end (local backend, Nuitee sandbox):

| | cold | after warmup |
|---|---|---|
| `POST /search/hotels` Cairo 2026-10-30 | 4.76s | **18ms** |
| same body, reordered keys + `"  cAIro "` | — | **18ms** (canonical key hit) |

## What is still not fixed

- **Provider latency itself.** Warming removes the cost from the first
  traveller, but a genuinely new city/date pair still takes 3.5–5s. The only
  real fix is a provider-side fast path or a much wider pre-warm net.
- **The edge cache is not provisioned** (see `docs/performance/cdn.md`).
- **Device numbers** depend on the phone and the Wi-Fi; re-run the drive on the
  same device before/after any further change.

## Baseline numbers (2026-10-28, local backend, warm process)

```
GET  /home/sections        raw 10.7KB / gzip 1.6KB     8–11ms (warm)
GET  /home/recommended     raw 14.4KB / gzip 8.2KB     3–27ms (warm)
POST /search/hotels        raw 145KB  / gzip 54KB      3600ms cold, 10ms warm
GET  /images/hotel w=480   19.2KB WebP                 97ms miss, 5ms hit
```

Re-run these with `npm run perf:probe` before and after any further change.
