# TokiGo — MASTER PROJECT MEMORY

> **Purpose:** The authoritative handoff document for any analytical/architectural AI that must understand the project without access to previous chats.
>
> **Last known project state (updated 2026-09-07):** **Home & Platform workstream complete (M0+H1+H2+H3):** Nuitee-only Home (fake seed purged; empty feed authoritative), single skeleton rail (H1), price/availability-only refresh on Home return (H2), Hive-backed hotel image cache with display-res decode (H3, P2). **Universal Search workstream (sibling agent): US-0/US-1/US-1-Final done; US-2 in progress uncommitted** — NAV (remove bottom nav) blocked until it lands. Memory Spine backend live (`/memory/me`, `/ai/chat`, `/ai/rerank`). Verified baseline (2026-09-07): **647 Flutter tests / ~6 skipped / 0 failed + 232 backend tests / 1 skipped, 0 analyze errors, tsc clean.** Authoritative plan + boundaries + pending decisions P1/P3–P6: `MASTER_PLAN.md` (repo root) — READ IT FIRST. Next: [US-2 lands] → NAV → 2C-C1.
>
> **Important:** This document is compiled from the project history available to the current assistant. It is not a live filesystem scan. Any item marked "verify" should be checked against the repository before making changes.

---

## 1. Project Identity

- Project name: **TokiGo**
- Current product direction/branding: travel application evolving toward **B&GO / BEALDANDGO / B-ANDGO** design language.
- Primary stack: **Flutter + Dart**, with a **NestJS backend**.
- Flutter architecture: feature-first + Riverpod + GoRouter + Repository → UseCase → Controller.
- Flutter environment last reported: **Flutter 3.44.8 / Dart 3.12.2**.
- Linux desktop was enabled and successfully running.
- Backend location: `backend/`.
- Flutter source: `lib/`.
- Tests: `test/`.

## 2. Non-Negotiable Project Rules

1. **Never delete files or directories.**
2. **Never rename files/directories unless explicitly approved.**
3. Never use destructive commands (`rm -rf`, destructive reset/clean, etc.) for project work.
4. Do not add packages unless explicitly required and approved.
5. Do not rewrite architecture merely to solve a local issue.
6. Preserve existing HomeCard/HomeSection engine unless the task explicitly targets it.
7. Preserve GoRouter/AppRoute/navigation architecture unless explicitly targeted.
8. Booking/payment execution was historically out of scope until explicitly started.
9. Every implementation phase must validate with:
   - `flutter analyze`
   - `flutter test`
10. For backend work, validate the relevant TypeScript compile/test command.
11. Work in small phases.
12. Report exactly which files were created/modified and what was validated.
13. If a requested change conflicts with an existing architectural decision, stop and explain before changing architecture.

## 3. How AI Agents Should Work

### Analytical AI (ChatGPT / Claude / equivalent)
Use this file as the primary context. Its job is to:
- understand the whole system,
- identify the current phase,
- reason about architecture,
- produce a small, precise execution prompt,
- avoid asking the executor to rediscover project history.

### Execution AI (DeepSeek / Cline / Qwen / equivalent)
Use `02_AGENT_MEMORY.md` + `03_CURRENT_STATE.md` + the execution prompt.
The executor must:
1. inspect only the relevant files first,
2. make the smallest safe change,
3. never delete/rename,
4. validate,
5. report,
6. stop at the requested phase.

## 4. Current State Snapshot

- Phases 1–9: completed according to the latest project reports.
- Current workstream: Phases 10–15 complete (10A–10D, 11A, 11B1, 11B2, 11C, 12, 13, 14A, 14B, 15A, 15B, 15C). Phase 15A/15B introduced context-aware AI querying and home feed extraction. Phase 15C completed code hygiene cleanup, fixed the bottom sheet cancellation bug, and verified test suites.
- Next phase: Phase 16 (pending explicit approval).
- Phase 9: real OpenAI-compatible provider in NestJS.
- Phase 10 sub-phases 10A–10D: **completed** (response hardening, live integration verification, provider configuration/fallback policy, AI contract tests).
- The product/UX and release-readiness roadmap is recorded in Section 12.
- Flutter AI UI exists and can consume the normalized AI contract.
- NestJS has `POST /ai/query`.
- Real provider is configured through an abstraction and environment variables.
- No real API key is stored in project memory.

## 5. Architecture Summary

### Flutter
```text
UI
 ↓
Riverpod Controller / State
 ↓
UseCase / Service / Repository
 ↓
Contracts / Providers
 ↓
Network / Storage
```

AI path:
```text
AiPromptInput
 ↓
AiController
 ↓
AiAssistantService
 ↓
AiProvider / backend
 ↓
AiResponse
 ↓
AiHomeMapper
 ↓
HomeSectionWidget
 ↓
Existing HomeCard engine
```

### Backend
```text
POST /ai/query
 ↓
AiController
 ↓
AiService
 ↓
AI_PROVIDER abstraction
 ↓
OpenAiAiProvider (current binding)
 ↓
OpenAI-compatible /chat/completions
 ↓
normalized AiResponseDto
```

## 6. Phase History

### Phase 1 — Routing Only
Completed.
- Replaced placeholders for:
  - `/` → `HomePage`
  - `/flights` → `FlightSearchPage`
  - `/hotels` → `HotelSearchPage`
  - `/cars` → `CarSearchPage`
- Only `go_router_config.dart` was changed.
- ShellRoute, redirect, AppRoute, and navigation architecture preserved.
- Remaining placeholder routes were intentionally left alone.
- BookingReview was not wired because it requires mandatory parameters and there was no matching route.

### Phase 2 — AI / Normal Mode State
Completed.
- Added `lib/shared/providers/app_mode_provider.dart`.
- `AppMode { ai, normal }`.
- Default is `AppMode.ai`.
- `shell.dart` hides FloatingNavigation in AI mode and preserves it in normal mode.
- No AI UI or toggle logic yet at this phase.

### Phase 3 — AI Visual Shell
Completed.
Created:
- `lib/features/ai/presentation/pages/ai_visual_shell_page.dart`
- `ai_ambient_visual.dart`
- `ai_empty_state.dart`
- `ai_prompt_input.dart`
- `ai_mode_indicator.dart`

Modified:
- `lib/app/shell.dart`

Behavior:
- AI mode shows a full visual AI shell.
- Normal mode retains FloatingNavigation.
- Ambient animation is presentation-only.
- Prompt input existed without network/backend logic.

### Phase 4 — AI Response Contract
Completed.
Created:
- `ai_response.dart`
- `ai_section.dart`
- `ai_item.dart`
- `ai_action.dart`
- `ai_home_mapper.dart`

Contract:
```text
AiResponse
  text?
  sections[]
  metadata

AiSection
  id?
  title
  subtitle?
  layout
  items[]
  order?
  metadata

AiItem
  id
  type
  HomeItem-compatible display fields
  order?
  data
  actions[]
  metadata

AiAction
  type
  label?
  payload
```

Important architectural decision:
- AI-specific domain models were kept separate from HomeItem/HomeSection.
- Existing `HomeCardType` and `HomeSectionLayout` are reused.
- `AiHomeMapper` is the single boundary into Home display models.
- `data` is merged into HomeItem metadata where needed (for example flight route).

### Phase 5 — Mock AI Response → Existing Home Cards
Completed.
Created:
- `mock_ai_response_data.dart`
- `mock_ai_response_provider.dart`
- `ai_response_content.dart`

Modified:
- `ai_visual_shell_page.dart`

The mock response contained mixed sections:
- hotels
- flights
- destinations
- deals

It exercised multiple HomeCard types and ordering.
Pipeline:
```text
Mock data → AiResponse → AiHomeMapper → HomeSectionWidget → HomeCard
```
No HomeCard engine modification.

### Phase 6 — AI Controller + State
Completed.
Created:
- `ai_state.dart`
- `ai_response_source.dart`
- `ai_controller.dart`
- `ai_providers.dart`

State:
- `idle`
- `loading`
- `success`
- `empty`
- `error`

Controller:
- `submit`
- `retry`
- `reset`

Prompt input became a Riverpod consumer and submits directly to the controller.

### Phase 7 — AI Service Layer
Completed.
- Added `query(String prompt)` to `core/ai/ai_assistant_service.dart`.
- Added `MockAiAssistantService`.
- Controller depends on `AiAssistantService` + `AiHomeMapper`.
- Mock source is hidden behind the service boundary.
- No HTTP/backend yet.

Known architectural note:
- `AiResponse` lives under `features/ai/domain`, while `core/ai/ai_assistant_service.dart` references it. This is an intentional compromise to preserve existing files/contracts.

### Phase 8 — NestJS AI Endpoint
Completed.
Backend module location:
`backend/src/modules/ai/`

Created:
- `backend/src/common/dto/ai.dto.ts`
- `backend/src/modules/ai/ai.provider.ts`
- `mock.ai.provider.ts`
- `ai.service.ts`
- `ai.controller.ts`

Modified:
- `ai.module.ts`

Endpoint:
`POST /ai/query`

Request:
```json
{ "prompt": "user text" }
```

Validation:
- string
- non-empty
- max length 4000
- global whitelist/forbidNonWhitelisted behavior

Provider abstraction:
- `AI_PROVIDER`
- `AiProvider`
- `generate(prompt)`

Response normalized to the Flutter AI contract.

### Phase 9 — Real AI Provider
Completed.
Created:
- `backend/src/modules/ai/openai.ai.provider.ts`
- `backend/.env.example`

Modified:
- `backend/src/modules/ai/ai.module.ts`

Current binding:
```text
AI_PROVIDER → OpenAiAiProvider
```

Environment:
- `AI_API_KEY` required at runtime
- `AI_BASE_URL` default: `https://api.openai.com/v1`
- `AI_MODEL` default: `gpt-4o-mini`

No API key is stored in the repository.

Runtime behavior when key is missing:
- backend can respond with a configuration-related 503 from the AI provider path rather than inventing a key.

## 7. Important Existing Systems

### Home
Home is a mature card/section engine and must be treated as a stable consumer.
Known card types include:
- hotel
- flight
- destination
- deal
- experience
- story
- car
- package

AI must feed Home through the mapper rather than changing the card engine.

### Search
Search foundations exist for:
- flights
- hotels
- cars
- filtering
- sorting
- offer selection

### Booking
Booking domain/application foundations exist, including:
- preparation
- revalidation
- confirmation
- state machine
- idempotency

Do not assume booking execution/payment is complete merely because booking models/controllers exist.

### Payment
Payment domain exists, but payment execution should not be assumed complete without a current validation.

### Navigation
GoRouter + ShellRoute + AppRoute are established.
FloatingNavigation is used in normal mode.

## 8. AI Contract Compatibility

The backend response must stay compatible with Flutter `AiResponse.fromMap()`.

Important fields:
- response `text`
- sections
- `layout`
- items
- item `type`
- item `data`
- item `actions`
- metadata

Examples:
- flight route can be carried in `data.route`
- car-specific type can be carried in `data.type`

Provider identity should not leak into the user-facing AI response contract unless explicitly needed.

## 9. Known Issues / Caveats

- Previous TypeScript compile reports showed `TS2564` strict property initialization errors in old DTOs/entities outside the AI scope.
- These were deliberately not changed during Phase 8/9.
- A live AI request was not validated without a real API key.
- Database connectivity was previously a separate backend boot concern.
- AI provider switching is currently controlled in the module binding rather than a dynamic environment factory.
- The AI service/core direction contains the noted dependency inversion compromise described above.
- `AiResponseSource` remains as an internal/mock-oriented contract unless later cleanup is explicitly approved.

## 10. Phase 10 Candidate Work

> **Addendum (2026-08-18):** The Phase 10 candidates below were executed as sub-phases **10A–10D** and are **complete** (see `03_CURRENT_STATE.md` for the commit record). The original candidate text is preserved additively below for history. The active Phase 11 and future product/UX direction are tracked in Sections 11–13.

Phase 10 was not started when this candidate list was written; it has since been superseded by the completed sub-phases 10A–10D. Candidate objectives should be decided only after inspecting the current repository.

Likely topics:
1. harden LLM JSON parsing/normalization,
2. handle malformed/fenced JSON robustly,
3. verify live Flutter → backend → AI flow,
4. add provider configuration/fallback policy,
5. add AI request/error observability,
6. add tests for the normalized contract,
7. only then consider production concerns.

Do not automatically implement all candidates as one phase.

## 11. Phase 11 — Stabilization

### 11A — Local database/cache foundation
Completed according to the latest repository history.

### 11B1 — Home schema mismatch
**Status: Complete (2026-08-18).**

The Home service now explicitly maps persisted `HomeSection`/`HomeCard` fields into the Flutter wire schema, including flattened `content`, `cardType → type`, visibility/expiry fields, legacy `actionLabel`, and typed presentation values. The backend DTO now records fields actually emitted, and backend/Flutter contract tests cover the shape. The HomeCard/HomeSection engine was preserved.

### 11B2 — Remaining TypeScript errors
Pending after 11B1. Resolve only TypeScript errors that remain in the actual repository after a fresh build; do not perform unrelated refactors merely because historical memory mentioned errors.

### 11C — Search error sanitization
Pending after 11B2. Ensure flight, hotel, and car search failures never expose raw server/provider/network text to users; preserve diagnostic detail only in safe internal handling and tests.

## 12. Approved Product, UX, and Release Roadmap

> **Sequencing decision (2026-08-18):** Work remains small and phase-scoped. Phase 11B1 is first. Do not begin a later item without an explicit instruction.
>
> **Status update (2026-09-02):** Phases 11B1–17 are all complete. Phases 18–21 remain pending and are tracked in `04_PHASE_HISTORY.md` / `08_NEXT_STEPS.md`. In addition, three "Wave" workstreams (approved 2026-09-02) were executed on top and are complete — see section 12.5.

### Ordered implementation phases

1. **11B1 — Home schema mismatch** ✓ complete
2. **11B2 — Remaining TypeScript errors** ✓ complete
3. **11C — Search error sanitization** ✓ complete
4. **12 — Home Marketplace UI** ✓ complete
5. **13 — Floating Navigation** ✓ complete (later superseded by the Wave-0 bottom navigation — see 12.5)
6. **14 — AI Bottom Sheet + Sessions** ✓ complete
7. **15 — AI context + Card Engine integration** ✓ complete
8. **16 — Real identity, profile, and persisted authenticated sessions** ✓ complete
9. **17 — End-to-end booking/payment foundation and Bag synchronization** ✓ complete (funnel UI + provider revalidation + mock EG gateway; real PSP still future)
10. **18 — Unified Trip Bag, imports, readiness, Wallet, and Price Watch** ← pending
11. **19 — Live Travel Companion: Today, Map, Travel Mode, and event-based notifications** — pending
12. **20 — Production readiness and launch** — pending
13. **21 — Trusted Group Trips: discovery, membership, shared plans, safety, and reviews** — pending

The detailed phase outcomes, external dependencies, consent rules, dynamic product flow, and unified UI specification are authoritative in `08_NEXT_STEPS.md`.

## 12.5. Wave Workstreams (2026-09-02) — COMPLETE

Executed after Phase 17, driven by the v2.0 provider/market/payment implementation
spec (`TokiGo_Travel_Providers_Market_Payment_Implementation_Spec_v2.0.docx`
— kept at repo root; extracted text also referenced during implementation).
The spec's hard rules remain binding: no provider secrets in Flutter, no direct
client→supplier calls, market context ≠ provider selector, display currency ≠
settlement currency, revalidation before payment, cars vendor deferred.

### Wave 0 — Design language + navigation (COMPLETE)
- **"Pure White Premium" light-only theme**: white canvas, royal indigo
  `#2B4EFF`, gold accent `#C99A3C`, AI violet `#7C5CFF`, semantic tokens.
  Dark theme DELETED by explicit user decision (was never design-approved);
  `AppTheme.light()` is the only theme. `themeModeProvider` removed.
- Typography: **Manrope (Latin) + Cairo (Arabic)** variable fonts bundled;
  `AppTypography.isArabicLocale` swaps automatically. Arabic/RTL supported
  app-wide from day one.
- Navigation: **attached bottom bar** (Home / Search / **AI centre button**
  / Groups / Explore) with `StatefulShellRoute.indexedStack` (4 branches:
  Home=0, Search=1, Groups=2, Explore=3 — AI is a pushed route, NOT a branch;
  a tab-index mismatch bug was found and fixed, covered by
  `bottom_nav_branch_mapping_test.dart`). Fixed shell header REMOVED — every
  page owns a seamless merged header. Old `AiMorphControl`,
  `FloatingNavigation`, `CommandBar`, legacy `app_router.dart` nav path deleted.
- Motion: unified **fade-through** page transitions (`app_transitions.dart`)
  on every route; solid-minimal buttons (`AppButton` kit); shared widgets:
  `SectionHeader`, `StickyCtaBar`, `StepProgress`/`StatusChip`.
- **l10n**: `flutter_localizations` + gen-l10n; `app_en.arb`/`app_ar.arb`;
  `localeProvider` (+`currencyProvider`) — all new pages are localized.
- Pages added: Search Hub (hosts the hero card moved from Home), Explore
  (destinations/deals/collections), Groups (v1 mock per roadmap Phase 21),
  Notifications, Wishlist, Settings (language+currency only — theme toggle
  intentionally absent), Onboarding (3 slides, Hive `tokigo_settings`
  box `onboarding_seen` flag).

### Wave 1 — Real providers on the backend (COMPLETE)
- **Nuitee hotel adapter** `backend/src/modules/nuitee/nuitee.service.ts`:
  `POST api.liteapi.travel/v3.0/hotels/rates` (ONE base URL — sandbox/live
  chosen by key `sand_***`; there is NO sandbox subdomain), prebook
  `/rates/prebook`, book `/rates/book` (ACC_CREDIT_CARD), content
  `/data/hotels`. **LIVE-VERIFIED**: real Cairo hotels returned through the
  adapter (e.g. Al Masa Hotel Nasr City, USD price, rating halved from the
  Nuitee 10-scale to the 5-star display scale). Response mapping:
  rates at `data[].roomTypes[].rates[]`, hotel metadata snake_case
  (`main_photo`, `city_name`, `review_count`). Deterministic fixtures in
  `NUITEE_FIXTURES`; contract tests in `test/nuitee.contract.spec.ts`;
  opt-in live smoke `test/nuitee.live-smoke.spec.ts` (runs only with
  `NUITEE_LIVE_SMOKE=1`).
- **Duffel**: `revalidateOffer(offerId)` added (offers.get) + price
  provenance metadata (`retrievedAt`/`expiresAt`) on every mapped offer.
- **MarketContext + FX + Pricing** `backend/src/common/market/`:
  `market-context.ts` (EG/EGP/ar-EG default; SA/AE prepared, DISABLED),
  `fx.service.ts` (cached rates, open.er-api.com with static fallback,
  snapshot with source/rateId/capturedAt), `pricing.service.ts`
  (deterministic PriceQuote: BASE/MARKUP/PAYMENT_FEE/TAX lines,
  EGP whole-unit rounding, pricingVersion, expiresAt). SearchService
  enriches every offer with `customerPrice` while provider amounts stay
  untouched (spec point 5).
- **Cars**: rich deterministic mock catalogue behind the real
  `CarProvider` contract (6 vehicles, computed totals, policies,
  provenance) — vendor intentionally deferred per spec point 30.
- **`POST /offers/revalidate`**: unified revalidation endpoint
  (OK / PRICE_CHANGED / UNAVAILABLE / ERROR) routing to Duffel or Nuitee
  prebook by providerId.
- Flutter models: `CustomerPrice`/`PriceLine`
  (`lib/core/domain/models/offers/customer_price.dart`) + `BaseOffer.customerPrice`
  wired through the offer mapper (all four offer types).
- `.env` additions (backend): `NUITEE_API_KEY` (user-supplied sandbox key,
  live in .env), `NUITEE_MODE=sandbox`; documented in `.env.example`.

### Wave 2 — Flutter UI rebuild on real data (COMPLETE)
- **SearchScaffold** (`search_scaffold.dart`): scroll-linked collapsible
  header (Booking/Airbnb pattern) for all 4 verticals + `SearchFieldInput`
  (theme tokens) + `SearchSubmitButton`.
- **4 search pages rebuilt**: flight (trip-type chips, return date,
  passengers stepper, airport picker sheet), hotel (city picker, guests +
  rooms steppers, list/map toggle), car (location pickers, transmission
  chips), packages (trip length). Unified rich states via
  `SearchStatesView` (idle/loading/empty/error + Retry actually wired —
  fixed the old no-op retry bug). `SortChipsRow` horizontal chips + filters.
  **Autocomplete**: `destination_picker_sheet.dart`
  (`showPickerSheet`, `PickerEntry`, `kAirports`, `kCities`).
- **Runtime bug fixes** (user-reported "search/home errors"): search pages
  read `GoRouterState.of(context)` in `initState` → moved to
  `didChangeDependencies` with one-shot guard (flight/hotel/car);
  `SearchViewToggle` used `Expanded` inside app-bar actions → unbounded
  RenderFlex crash → intrinsic sizing. Covered by
  `test/features/search/search_pages_interaction_test.dart` +
  `test/app/full_app_smoke_test.dart` (boots the real app and walks all tabs).
- **Home**: welcome line replaces the hero (hero moved to Search tab);
  `DiscoveryProductCard` (hotel/car/package real-data card with rating,
  highlights, price + `.loading()` skeleton mirror) — dev-preview empty
  items still render the old skeleton surface; **"Continue planning"**
  strip surfaces current Bag trips above the feed.
  Home feed sections: backend-driven (`GET /home/sections`, seed:
  Recommended for you / Trending destinations / Tour packages /
  Experiences & stories) with a dev-preview fallback (Flight
  Recommendations / Hotels / Car Rentals / Tour Packages / Hot Deals /
  Destinations) when the backend returns empty.
- **Card system unified**: favorite callbacks renamed to
  `onFavorite`/`isFavorite` everywhere; dead code deleted
  (price_display_strategy, recommendation_reason, badge_group,
  card_badge_helpers, hotel_search_form stub, filter_engine,
  search_results_state; deal_presentation kept — test exists);
  skeleton colour tokenized.

### Wave 3 — Booking funnel + payment (COMPLETE)
- Booking funnel pages (earlier in the wave set): Booking Review (premium
  redesign, phase timeline, seed into checkout providers), Passenger
  details, Add-ons, Checkout, Confirmation (stroke-drawn checkmark, Bag
  sync). Routes nested under `/booking/review/*`.
- **Flutter `OfferRevalidationService`**
  (`lib/features/booking/application/services/offer_revalidation_service.dart`):
  Continue button on booking review calls `/offers/revalidate` before the
  funnel; PRICE_CHANGED blocks checkout until acceptance; unavailable shows
  a snackbar; backend-unreachable falls back to the last machine price.
- **Payments module** `backend/src/modules/payments/`:
  `PaymentGateway` interface, `MockEgyptGateway` (deterministic EG mock
  with real idempotency, signed webhooks, 3DS→PENDING async settle),
  `PaymentRouter` (by paymentRegion; EG only — SA/AE disabled until
  onboarding), `LedgerService` (immutable append-only entries +
  bookingBalance), `PaymentService` orchestrator + `/payments/*`
  endpoints (intent/confirm/refund/webhook/ledger timeline).
- **Flutter `CheckoutPaymentService`**: checkout calls the real backend
  payment flow (CARD_SUCCESS/CARD_3DS/declined/WALLET method mapping;
  pending3ds proceeds to confirmation, failed/unavailable snackbars).

### Wave validation baseline (2026-09-02)
- Backend: `npx jest` **129/129** (1 skipped live-smoke without env flag);
  `tsc --noEmit` clean.
- Flutter: `flutter test` **432/432**; `dart analyze lib test` **0 errors**
  (remaining infos are pre-existing lints); visual audit 14/14; debug APK
  builds.
- Live Nuitee sandbox smoke: PASS with the user's key in `.env`.

## 12.6. Superseded / supersessions (anti-contradiction ledger)

- **Dark theme**: early Wave-0 work added a premium dark theme and enabled
  `ThemeMode.system`; the user then decided **light-only** — dark code was
  fully removed. Do not reintroduce dark mode without a new explicit request.
- **Floating Navigation / CommandBar** (Phase 13 artifact): retired by the
  user's bottom-navigation decision (Wave 0). Files deleted; the shell no
  longer references them. `08_NEXT_STEPS.md`'s vision text about a
  "persistent bottom command bar" is HISTORICAL — the bottom bar with the
  AI centre button is the implemented reality.
- **Home hero search card**: moved from Home to the Search tab by explicit
  user decision; Home leads with a welcome line + feed. The Search Hub owns
  "Where to next?".
- **Theme mode in Settings**: intentionally absent (light-only). Settings
  holds language + currency only.
- **`/ai` route vs `/ai-chat`**: real assistant page is `/ai-chat`
  (full-screen, outside shell). `/ai` placeholder remains for the future
  AI-mode surface.

### Release-readiness gates retained from the technical review

These are product-critical gaps now represented by Phases 16–20. They remain gates, not permission to expand the current phase scope.

1. **Authentication:** replace the local/placeholder login path with a real, tested authentication journey.
2. **Booking and payment:** implement matching backend booking endpoints and connect the Flutter booking/payment flow end to end.
3. **Complete the core user journey:** replace remaining placeholder pages required for login → discovery/search → offer → booking → bag.
4. **Codebase hygiene:** make `flutter analyze` clean and remove tracked dependency artifacts such as `backend/node_modules` from version control through a safe, separately approved migration.
5. **Production operations:** configure environment separation, restricted CORS, database migrations/backups, monitoring, and a CI pipeline.

## 13. Future Product / UX Vision (Roadmap)

> **Status:** Future product/UX direction (added 2026-08-18). Roadmap/memory only — additive and non-destructive. Preserves completed AI phases 1–10. Its planned work is now represented by the approved phase order in Section 12.

### Home
Home = Marketplace + Discovery.

Sections:
- Hero / Inspiration
- Recommended
- Hotels
- Flights
- Cars
- Packages / Tours
- Experiences / Deals
- Continue browsing

Use horizontal carousels and clear visual hierarchy. Do not give every section equal weight.

### Header
Top-right:
- Notifications
- Profile

Settings lives inside Profile.

### AI
AI = Universal Search + Travel Assistant, not a separate normal chat page.

Bottom of screen:
- AI search/input
- Floating Navigation button

#### Unified search experience — approved UX direction
- The application header keeps the product identity at left and Notifications + Profile at right.
- Profile is the entry point for authentication, profile, settings, and session/account actions; unauthenticated users see login/create-account actions.
- A persistent bottom command bar is available throughout the routed experience. It is the entry point to the travel assistant and does not force the user into a dedicated chat screen.
- The command bar also exposes manual Floating/Orbital Navigation so users can enter Flights, Hotels, Cars, Packages, Trips/Bag, and other primary surfaces at any time.
- AI search and manual search are equal paths: natural-language input discovers and proposes filters/results, while manual pages provide precise direct control.
- The assistant inherits the current page context (Home = trip discovery; Flights/Hotels/Cars = scoped search; Bag = current-trip help).
- Users can move in both directions: AI-extracted filters can populate the manual search form, and a manual result can be sent to the assistant for explanation, comparison, or alternatives.
- Results remain existing Home/Card Engine cards. AI responses should appear as a draggable bottom sheet over the current surface, not as a second navigation hierarchy.

#### Interaction details to preserve during implementation
- Before the user types, the command bar may offer contextual starter prompts such as plan a trip, cheapest flight, weekend hotel, or continue my trip.
- Natural-language intent determines the appropriate path: a route/date query prepares Flight search; accommodation language scopes to Hotels; broad destination/duration input begins trip planning; comparison language operates on the visible results.
- AI output must be actionable, not text-only: extracted filters are editable chips and offer actions include Use in manual search, Show alternatives, Compare, and Save to trip.
- Manual search pages expose a lightweight “Help me choose” entry point that opens the AI sheet over the current results rather than navigating away.
- Offer cards may expose Explain why this fits, Cheaper alternatives, Compare, and Add to trip actions. The assistant explains ranking, but live provider/search data remains the source of price and availability.
- AI should explain its recommendation criteria (for example budget, rating, location, and dates) and distinguish search results from AI interpretation.
- AI sessions represent trips, not only chat logs: a session can retain title, context, filters, saved offers, and conversation history (for example family trip, honeymoon, or business trip).
- In Bag, the assistant summarizes the active itinerary, answers booking-policy questions, surfaces travel reminders, and proposes relevant complementary offers.

#### Travel Companion / During-trip Intelligence — approved product direction
- Bag evolves from a booking list into the live travel hub: **Today**, **Itinerary**, **Map**, and **Wallet**.
- Today prioritizes the next time-sensitive action: an upcoming flight, transfer, hotel check-in, activity, or reservation, with distance, estimated arrival time, and a Start directions action.
- The persistent Travel/Today command bar includes a contextual **Add to trip** action. When a user dismisses, postpones, or has not yet completed a relevant need, it lets them immediately add a booking, transfer, activity, note, document, or planned offer to the current trip without leaving the current screen.
- The quick-add menu is context-aware: before an arrival it can prioritize transfer or accommodation; between itinerary items it can prioritize an activity, meal, or note; before departure it can prioritize return transport, document, or check-in follow-up. It always also provides a generic Add item option.
- Itinerary displays every trip place and booking as a timeline. Each item has its address, map position, distance from the user, suggested departure time, and an external-map handoff for active turn-by-turn navigation.
- Map shows the user’s opted-in location, saved trip places, and the next recommended route. It must work as a trip context/map surface, not attempt to replace the native map app’s navigation experience.
- Wallet keeps booking references, QR codes, selected travel documents, insurance details, and essential itinerary data for offline access where technically feasible.
- AI uses current trip context, optional location, time, reservations, traveler count, and budget to give short actionable guidance: departure timing, delayed-flight adjustments, nearby alternatives, weather-aware replanning, and explanation of next steps.
- The system may create travel events: nearing an appointment, arrival at a saved place, flight/hotel/booking changes, weather disruption, schedule conflict, or departure from a planned route. These events may update the itinerary and send a relevant notification.
- A notification or Today card for an unresolved gap includes a direct action (for example Add transfer, Add return, Add document, or Mark not needed). Ignoring a notification never removes the gap permanently; it remains available in the trip readiness checklist and quick-add entry point.
- Background work is event-driven rather than continuous AI execution: platform location/geofence, time, and provider updates create a short-lived event; the app then evaluates whether a useful notification or plan update is warranted.
- Travel Mode is explicit and trip-scoped. Users can choose location access scope, disable it at any time, use manual “I’m here” confirmation instead, and control which trip companions can see status. Do not treat location sharing as required for core travel features.
- Notifications must be high-signal and rate-limited: for example suggested airport departure time, gate/delay change, nearby reservation, severe weather disruption, or a meaningful itinerary conflict—not every movement.
- Optional companion/safety capabilities include arrival check-ins, selected trusted-contact status updates, emergency information (hotel, insurer, embassy/local emergency contacts), and a quick safety check-in flow.
- Local assistance can recommend contextual useful services such as transfers, eSIM, pharmacies, ATMs, supermarkets, restaurants, and accessible/family-friendly options. Availability, cost, and provider facts must be clearly distinguished from AI recommendations.

#### Unified Trip Bag, external imports, and price watch — approved product direction
- Bag presents one user-owned **Trip** model, never separate “internal trip” and “external trip” experiences. A trip contains a unified list of **TripItem** entries for flights, stays, cars, trains, activities, transfers, and other relevant services.
- The single user action is **Add to trip**. It can search/book inside the app, add a saved in-app offer before booking, add an external booking manually, or import shared confirmation content/PDF, forwarded email, calendar entry, or QR/booking code.
- Confirmed in-app bookings add themselves automatically. External extraction always creates a reviewable draft; it never silently marks an item as confirmed. All sources create the same TripItem shape.
- A TripItem carries an internal source for reliability/actions—`inAppConfirmed`, `inAppPlanned`, `externalImported`, or `manual`—but the source must not split the user’s trip into separate surfaces. Its user-visible lifecycle can be planned, needs review, confirmed, cancelled, or completed.
- Each item appears in Today, Itinerary, Map, and Wallet as appropriate. The unified itinerary is the context used for assistance, map directions, notifications, and readiness evaluation.
- Price Watch has a domain foundation (`WatchItem`) but needs future application, persistence, API, and UI work. It should support target-price and percentage-drop alerts, pause/remove controls, and a clear distinction between live provider price and AI recommendation.
- Price Watch can follow an unbooked offer, alternatives for a planned trip, or a booked cancellable offer when the policy permits rebooking savings. Never imply a saving is actionable before cancellation/change conditions are checked.
- Every trip has a **Trip Readiness / Missing items indicator**, not a vague completion percentage. It evaluates all TripItems together, regardless of source, and shows confirmed essentials and actionable gaps based on trip type, dates, destination, travelers, and user choices.
- Examples of gaps: flight without accommodation, accommodation without arrival/transfer plan, missing return trip, traveler details incomplete, check-in not completed, travel documents/visa/insurance to review, no eSIM/connection plan, or schedule conflicts. A gap can be marked not needed or completed manually.
- The readiness indicator must not shame or block the user. It is a prioritized checklist with explanations, optional recommendations, and direct actions such as Search hotel, Add external booking, Add to trip, Set price watch, or Mark as not needed.
- AI treats the trip as one whole plan: it can identify gaps across internal and external items, help confirm an imported return flight, recommend a transfer for an externally booked hotel, calculate departure guidance, and monitor suitable alternatives without forcing the user to care where each booking originated.

AI input context:
- Home → global travel assistant
- Hotels → hotel context
- Flights → flight context
- Cars → car context

### AI Results
Show AI results in a draggable Bottom Sheet over the current page:
- collapsed
- half
- expanded

Swipe up/down to expand/collapse/close.

Results must use the existing Card Engine, not a separate AI card UI:

```text
AI Response → existing mapper/models → existing Card UI
```

### AI Sessions
Persist conversations as sessions.
User can reopen a session and continue with the same history/context.

### Navigation
Use Floating/Orbital Navigation instead of a permanent bottom bar.
Keep it limited to ~5–7 main actions.

### Future implementation order
1. Home Marketplace layout
2. Unified cards
3. Floating Navigation
4. AI Bottom Sheet
5. AI session persistence
6. Context-aware AI
7. AI → existing Card Engine
8. UX polish

## 14. Validation Baseline

Current verified project report (Phase 15C):
- Flutter analyze: 0 errors (1 warning, 15 info-level items).
- Flutter tests: 203 tests passed (0 failures).
- Backend tests: 84 tests passed across 9 suites.

## 15. Handoff Rule

If another AI receives this file:
- Do not assume the current filesystem exactly matches every historical report.
- First run a non-destructive inspection.
- Compare actual files against this memory.
- Update `03_CURRENT_STATE.md` only after verifying.
- Do not silently reconcile contradictions.
