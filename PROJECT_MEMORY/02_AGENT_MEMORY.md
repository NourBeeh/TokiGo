# TokiGo — EXECUTION AGENT MEMORY

## Mission
You are the implementation agent. Work only on the requested task.

## READ FIRST (any session)
`MASTER_PLAN.md` (repo root) — merged execution plan + workstream boundaries + pending decisions. Then this file, then `03_CURRENT_STATE.md`.

## Current known state (updated 2026-09-07)
- **Home & Platform workstream: M0 + H1 + H2 + H3 ALL DONE.** Baseline verified: **Flutter 647 passed / ~6 skipped / 0 failed; analyze 0 errors; backend tsc clean; jest 232 passed / 1 skipped.**
  - Home is **Nuitee-only**: Postgres home tables PURGED (0 rows — do NOT run `npm run seed:home`); empty feed authoritative; stale snapshots dropped (`clearHomeSnapshot`).
  - H1: single skeleton rail (exact real-rail geometry) + pull-to-refresh REMOVED.
  - H2: `refreshPrices()` — price/availability-only refresh on app resume + return-to-Home (GoRouter delegate listener, lazy `GoRouter.maybeOf` hook, router ref saved for dispose).
  - H3: `HotelImageCache` (LRU 30 / TTL 7d on the shared OfflineCache box) + `CachedHotelImage` (shimmer miss → shared fetch → store; P2 `cacheWidth` decode; never throws) wired into the Home hotel card.
- **Universal Search workstream (other agent): US-0/US-1/US-1-Final done (legacy v1 deleted); US-2 in progress uncommitted.** NAV phase is BLOCKED until US-2 lands (shared router).
- Memory Spine backend LIVE (modules/memory + `/ai/chat` + `/ai/rerank`, jest green); Flutter `/ai/chat` wiring = 2C-C1 (next after NAV).
- Next in order: **[US-2 lands] → NAV → 2C-C1 → 2C-C2 → 2D → US-3 → US-4 → 3A–3D → US-5 → US-6 → PH-7 → 4A–4E → 5A–5C → 6A–6C → 7A–7B → US-7 → 8A–8B → 9A–9B → 10A–10C.**
- Pending user decisions: P1 (speech_to_text package for US-3), P3 (integration_test), P4 (OWASP MASVS audit), P5 (predictive back), P6 (order confirmation). P2 APPROVED (ResizeImage/cacheWidth + packages allowed with per-case confirmation).
- Flutter 3.44.8 / Dart 3.12.2. Feature-first + Riverpod + GoRouter + Repository→UseCase→Controller. NestJS backend under `backend/`. LIGHT-ONLY design; fade-through motion; Manrope+Cairo; en/ar l10n.
- Navigation TODAY: 4-tab shell (Home/Search/Groups/Explore) — NAV will remove it.
- Providers: Nuitee hotels, Duffel flights + revalidateOffer, MarketContext EG/EGP + PricingEngine customerPrice; `POST /offers/revalidate` gates checkout. Payments: MockEgyptGateway (idempotent, signed webhooks, 3DS) + LedgerService.
- Booking funnel pages under `/booking/review/*`; Flutter calls `/bookings/*` which DO NOT exist server-side yet (Phase 4A builds them).
- Test env note: `ShimmerBox` animates forever → NEVER use `pumpAndSettle` while a shimmer placeholder is on screen (fixed pump loops instead).

## Mandatory rules
- NEVER delete files/directories; NEVER rename without approval; no destructive commands.
- No packages without explicit per-case approval. No unrelated changes. Phase-scoped only.
- Preserve HomeCard/HomeSection engine, GoRouter architecture, EventsTracker, SearchIntentParser behavior (unless a phase explicitly authorizes).
- No ML / vector DB / embeddings. Cache is never price/availability truth.
- Per phase: implement → `dart analyze lib test` + `flutter test` (backend: `npx tsc --noEmit` + `npx jest`) → report → STOP for approval.
- `backend/test-nuitee.ts`: never modify/delete/commit. `.env`: never read/print/commit.
- Standing security gap: `/api/duffel/create-booking` unguarded — resolve before any non-localhost exposure.
