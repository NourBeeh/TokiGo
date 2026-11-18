# TokiGo Backend — Architecture Audit (Phase 0)

Date: 2026-11-18 · Scope: `C:\dev\TokiGo\backend` · Audit only, no source files changed.

## 1. Repository state

| Item | Value |
| --- | --- |
| Repository | `C:\dev\TokiGo` (backend lives in `backend/`, Flutter app at repo root) |
| Branch | `Main` |
| HEAD | `9d209127cb975d007907acc470f2ddaeb88ae538` |
| Upstream | `origin/Main` → `https://github.com/NourBeeh/TokiGo.git` (in sync) |
| Working tree | Clean except untracked `.audit_tmp/` (pre-existing Flutter UI audit reports; untouched) |
| Node | v26.12.1 / npm 12.2.2 · `node_modules` absent at audit time (`npm ci` run to establish baseline) |

The backend is NestJS 10 + TypeORM 0.3 + PostgreSQL 16, ~18.3k LOC of TypeScript across 120 source files and 56 Jest specs. It is a BFF for the Flutter app; there is no separate language runtime.

## 2. Module map

- **providers/** — `ProviderRegistryImpl` + `SearchService` fan-out with a 20s per-provider timeout, deterministic dedup, display-currency enrichment (`PricingService`/`FxService`). `SearchWarmupService` pre-warms popular cities. Adapters: `NuiteeService` (hotels), `DuffelHotelService`, mocks.
- **nuitee/** — Connect REST v3 transport (`nuitte.client.ts`), pure mapper, city→country table. Operations: `searchHotels → POST /hotels/rates`, `prebookHotel → POST /rates/prebook`, `bookHotel → POST /rates/book` (ACC_CREDIT_CARD), `hotelContent → GET /data/hotels`, `trackBooking → GET /bookings/:id`.
- **bookings/** — `Booking` entity + `BookingsService` (prepare/revalidate/create/get/status/cancel), `BookingProviderRegistry` resolving per-provider `BookingProvider` capability adapters (Nuitee, Duffel, Nuitee flight).
- **payments/** — `PaymentRouter` → `MockEgyptGateway` (market EG only), durable `PaymentAttemptService` (state machine + CAS transitions), `LedgerService` (CUSTOMER/SUPPLIER legs), webhook replay store (`webhook_events` + legacy archive), ownership checks.
- **images/** — `ImageProxyService`: allowlisted fetch, SSRF/DNS-rebind guard, manual redirects, sharp WebP/JPEG resize, disk LRU cache, ETag + CDN headers.
- **cache/** — global `CacheModule` binding `CACHE_PROVIDER` to `RedisCacheProvider` (ioredis, in-process fallback) or `InMemoryCacheProvider`; `CacheService` wrapper.
- **others** — auth (JWT + Google), admin (home sections/cards, provider registry), home, recommend, AI/memory, geo, events, notifications (stub feed), audit, duffel flights, profile.

## 3. Hotel provider and live pricing

- Primary hotel provider is **Nuitee Connect** (`providerId: 'nuitee'`); Duffel Stays is registered but disabled by default; mock provider present.
- Search (`/hotels/rates`) returns per-hotel cheapest rate with `rateId`, price, currency, cancellation policy, taxes; mapping is provider-verbatim into `NuiteeHotelOffer`.
- Revalidation today = `POST /rates/prebook` (`prebookHotel`), which freezes a quote and returns `prebookId`/`transactionId`, `priceChanged`, `newPrice`, `expiresAt`. It is single-use handoff data persisted in `bookings.offerSnapshot`.
- Booking = `POST /rates/book` using the prebook handoff. There is **no independent live re-price op distinct from prebook**; `prebook` doubles as both revalidation and inventory hold.
- Hotel content (`GET /data/hotels`) exists for metadata/localization; results are cached 24h/7d in the shared cache, never in PostgreSQL.

## 4. Payment integration

- One gateway: `MockEgyptGateway` (`mock-egypt-gateway`, market `EG`), HMAC-SHA256 webhook verification, idempotency-keyed create/confirm/refund, simulated 3DS PENDING + `settlePending`.
- Routing is region-based (`routesForMarket`); SA/AE return null → checkout disabled.
- Money authority: `bookings.authoritativePrice`/`currency` (written only by provider revalidation); the client quote is validated against it and rejected on mismatch.
- Durable artifacts: `payment_attempts` (unique `(userId, idempotencyKey)`, gateway ref unique), `payment_transactions` (leg-checked, idempotent), `webhook_events` (PK `(provider, eventId)`), `processed_webhooks` (legacy archive).
- **Booking/payment ordering today:** `POST /bookings` performs the provider booking first (create → confirming → confirmed) and payment is a separate later `POST /payments/intent` + `/confirm`. Payment does not gate the provider booking.

## 5. Booking and payment states

- Booking: `prepared → revalidated → confirming → confirmed | failed | cancelled | expired` (+ optimistic `version`, `confirmingSince/Owner` lease columns that are not yet used by a recovery sweep).
- Payment attempt: `created → processing → requires_action | pending → succeeded | declined | failed | unknown | cancelled | refunded | partially_refunded | consumed | voided`, enforced by `payment-attempt.state.ts` and conditional UPDATEs.
- Booking-side `paymentStatus`: `unverified | legacy_unverified | pending | verified | failed | refunded | partially_refunded`.

## 6. Database schema and indexes

Migrations: `1731000000000` … `1731000000010` (base bookings/providers, payment_attempts, provider_operations, booking payment columns, payment_transactions, webhook_events, flight provider selection + triggers, attempt status CHECK widening, webhook retryable status, processed-webhook retire/restore).

- **There is no `hotels` table.** Hotel records live only in the provider API and (ephemerally) in Redis/disk caches. `offers`, `home_cards`, `home_sections`, `users`, `sessions`, `user_profiles`, `user_memories`, `audit_logs`, `user_events` exist as entities but most are created by TypeORM `synchronize` in development, not by migrations.
- Existing indexes are booking/payment-centric (see entity `@Index` decorators + migrations). No GIN/tsvector indexes anywhere. `offers.data` jsonb has no index; it is not queried by discovery today.
- Consequently the spec's `CREATE INDEX … ON hotels(city, checkin_date)` **cannot be applied** — neither column exists — and `checkin_date` must not be invented as hotel metadata.

## 7. Redis / queues / notifications

- Redis: opt-in via `REDIS_URL`/`REDIS_HOST`; `RedisCacheProvider` with lazy connect, offline-queue disabled, in-memory fallback on any error. Used for search (TTL default **300s**, env `SEARCH_CACHE_TTL_SECONDS`), Home rail (300s), localized hotel content (24h/7d), recommend cache.
- **No BullMQ / queue library**, no background workers beyond the search warmer, no socket gateway, no FCM. `notifications` controller returns an empty stub feed.
- `@nestjs/throttler` is installed and globally bound (`ttl 60000, limit 30`), but there is no Redis throttler store, no per-route limits, and no trusted-proxy configuration.
- Rate limiting/pagination: list endpoints (`admin/home/sections`, `notifications`, ledger, providers) return unbounded arrays.

## 8. API contracts and dependencies (summary)

- Public: `POST /search/{flights,hotels,cars}`, `POST /offers/revalidate`, `GET /images/hotel`, `GET /recommended-hotels`, `GET /home/*`.
- JWT-guarded: `/bookings/*` (prepare/revalidate/create/get/status/cancel), `/payments/{intent,confirm,refund,ledger/:id,ledger/:id/balance}`.
- Public: `POST /payments/webhook` (HMAC-verified).
- Admin: `/admin/home/*`, `/admin/providers*` (role-guarded).
- Key deps: `@nestjs/*` 10, `typeorm`/`pg`, `ioredis`, `sharp`, `@nestjs/throttler`, `@duffel/api`, `google-auth-library`, `bcryptjs`. **Absent:** `bullmq`, `meilisearch`, `@socket.io`, `firebase-admin`, `@aws-sdk/*` or S3/R2 client.

## 9. Gaps vs the refactor spec (implementation targets)

1. Hotel search cache: TTL 300s (spec: exactly 45s), key lacks occupancy/currency/nationality normalization required by spec, no single-flight/stampede lock, no negative-result protection beyond failures.
2. No Meilisearch index/sync/fallback; no PostgreSQL metadata table or discovery indexes/GIN.
3. Images: no S3/R2 upload, no CDN-domain config, no immutable 1-year cache policy, no deterministic object keys/idempotent upload, no DB metadata persistence.
4. Booking pipeline: no BullMQ orchestration, no distributed lock, no explicit live re-price-before-charge step returning 409 (today revalidation happens inside `create()` before provider booking, but payment is decoupled and later), no reconciliation sweep for ambiguous outcomes, no crash recovery worker.
5. No Socket.io gateway, no FCM, notifications stub only.
6. Throttler not Redis-backed/per-route; pagination absent; no structured correlation-id logging, health checks, metrics, graceful shutdown, startup config validation.
7. `.env.example` lacks Redis/Meilisearch/S3/CDN/Firebase/provider/payment variable documentation (partially present).

## 10. Non-negotiables confirmed

NestJS + PostgreSQL stay; prices remain live and are never persisted in PostgreSQL (`bookings.authoritativePrice` is a *booking* truth derived from provider revalidation, not a stored hotel price; search caches are presentation-only); Redis is temporary acceleration; Meilisearch (when added) is metadata-only; BullMQ coordinates work, PostgreSQL stays authoritative. No files deleted, nothing committed/pushed, `.audit_tmp/` preserved.
