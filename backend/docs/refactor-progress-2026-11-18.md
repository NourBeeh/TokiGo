# TokiGo Backend — High-Load Refactor Progress (2026-11-18)

Companion to `architecture-audit-2026-11-18.md`. Phases are landed incrementally;
nothing was deleted, nothing committed or pushed. `.audit_tmp/` untouched.

## Phase 0 — Audit ✅

Delivered in `architecture-audit-2026-11-18.md`: repository state, module map,
Nuitee/Duffel provider operations, payment state machines, schema/indexes,
Redis/queue/notification inventory, API contracts, and a gap list mapped to the
spec. Key finding: **no `hotels` table exists**, so the suggested
`hotels(city, checkin_date)` index was not applicable and no `checkin_date`
column was invented.

Baseline before changes: `npx jest --runInBand` → **52 suites passed, 5 skipped,
538 tests passed, 115 skipped, 0 failed** (`node_modules` installed with
`npm ci`; TypeScript build clean).

## Phase 1 — Fast live hotel search ✅

New/changed files:
- `src/modules/providers/hotel-search-key.ts` — mandated
  `hotels:{city}:{checkin}:{sha256}` key; normalises city casing/spacing,
  date-time vs date, `rooms:null`≡1, children ages as a set, and keys on
  currency, market, country, nationality, stay length and filters.
  `HOTEL_SEARCH_CACHE_TTL_SECONDS = 45` (fixed).
- `src/common/cache/cache-lock.service.ts` — in-process single-flight plus a
  Redis `SET NX PX` distributed lock with token-checked Lua release and expiry.
- `src/modules/providers/search.service.ts` — hotels use the new key and the
  fixed 45s TTL; cache read/write failures degrade to the provider; only fully
  successful non-empty aggregations are cached; identical concurrent searches
  share one fan-out; lock losers wait for the winner's entry, then fall back to
  a bounded fetch.
- `src/common/dto/hotel.search.dto.ts` / `nuitee.types.ts` / `nuitee.service.ts`
  — optional `nationality` passed to the provider as `guestNationality`.

Tests: `test/hotel.search.cache-key.spec.ts` (key format, exactly 45s, occupancy
key separation, cache hit/miss, partial-failure not cached, Redis-down fallback,
single-flight) — **13 new tests pass**; existing search/cache suites unaffected.

## Phase 2 — Schema & migrations ✅ (additive)

Migration `1731000000011-HighLoadDiscoverySchema.ts`:
- `hotels` — metadata ONLY (no price/rate/availability, no check-in date);
  unique `(providerId, providerHotelId)`, indexes on `(city, countryCode)`,
  `(isActive, city)`, GIN on `facilities`, GIN full-text on name/city/address/
  description, plus a sync watermark index.
- `hotel_images` — deterministic unique `objectKey`, `cdnUrl`, dimensions,
  content type, size, immutable cache policy; FK to `hotels`.
- `device_tokens` — token hash unique + AES-GCM encrypted token (FCM, Phase 6).
- Operational indexes: open payment attempts sweep, traveller booking list.

Entities: `hotel.entity.ts`, `hotel-image.entity.ts`, `device-token.entity.ts`.
**Not applied to a live database yet** — run `npm run migration:run` against a
provisioned Postgres when ready (dev `synchronize` also creates them).

## Phase 3 — Meilisearch discovery ✅ (metadata-only, PG source of truth)

- `src/config/meilisearch.config.ts`, `src/types/meilisearch.d.ts`.
- `meilisearch-hotel-index.service.ts` — lazy native ESM import of the SDK
  (avoids the CJS/Jest ESM problem), index setup, upsert/remove, filtered
  metadata search; every failure returns "unavailable" for the fallback.
- `hotel-metadata.service.ts` — PostgreSQL source of truth + provider mapper
  + fallback search (`tsvector`/ILIKE + JSONB facility containment).
- `hotel-discovery.service.ts` — Meilisearch-first, PostgreSQL-fallback, with
  `source` reported per response.
- `hotel-sync.service.ts` / `hotel-sync.worker.ts` — idempotent BullMQ sync per
  city (deterministic jobId, bounded concurrency 2, exponential backoff); runs
  inline when Redis is absent.
- `src/common/queue/*` — global BullMQ queue/worker registry, bounded
  concurrency, graceful close.
- API: `GET /hotels` (paginated, limit default 20 / max 100),
  `POST /hotels/sync` (JWT). Prices are never part of this path.

Tests: `test/hotel.discovery.spec.ts` (mapper, Meili-first, PG fallback, page
metadata, pagination defaults) — **6 new tests pass**.

## Phase 4 (image pipeline) ✅

- `src/common/storage/object-storage.service.ts` — S3/R2 (`@aws-sdk/client-s3`),
  R2 endpoint + path-style, CDN domain via env.
- `src/common/images/image-fetch.util.ts` — HTTPS-only, DNS-rebind/private-IP
  guard, manual redirects (SSRF-safe), type/size limits.
- `src/modules/images/image.service.ts` — validate → WebP transcode (sharp,
  dimension/format bounds) → deterministic content-addressed key
  `hotels/{sourceHash}/{width}x/{outputHash}.webp` → upload (idempotent) →
  persist CDN URL + metadata only. Dedupes by source-hash before downloading.
- `image-processing.service.ts` / `image-processing.worker.ts` — BullMQ job per
  source hash, bounded concurrency; inline fallback.
- API: `POST /images/hotel-image` (JWT), `GET /images/hotel-image/:id`;
  original `GET /images/hotel` proxy untouched. Cache policy constant
  `public, max-age=31536000, immutable`.

Tests: `test/image.service.spec.ts` — **7 new tests pass** (WebP conversion,
invalid rejection, deterministic key, dedupe-before-download, object reuse,
CDN persistence, cache header).

## New dependencies

`meilisearch`, `bullmq`, `@aws-sdk/client-s3`, `firebase-admin`, `socket.io`,
`@socket.io/redis-adapter` (installed; FCM/socket code still pending).

## Verification status

- `npx tsc --noEmit -p tsconfig.json` → clean.
- Full Jest suite after phases 0–3 + image pipeline: **54 suites passed,
  5 skipped, 551 tests passed, 115 skipped, 0 failed** (`npx jest --runInBand`).

## Remaining phases (not started)

1. Booking/payment pipeline (BullMQ orchestration, distributed booking lock,
   live re-price-before-charge returning 409, ambiguous-outcome reconciliation,
   crash recovery) — spec §3.
2. Socket.io gateway + Firebase FCM notifications — spec §3.
3. Redis-backed throttler store + per-route limits; remaining pagination;
   health checks (Redis/Meilisearch/DB), correlation-id logging, startup config
   validation, metrics — spec §4–5.
4. Full integration test pass and deployment/migration documentation — spec
   §6–7.
