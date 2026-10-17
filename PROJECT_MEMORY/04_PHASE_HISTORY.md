# WeTravellers — PHASE HISTORY

| Phase | Status | Main result |
|---|---|---|
| 1 | Complete | Four real GoRouter routes wired |
| 2 | Complete | AI/Normal AppMode state |
| 3 | Complete | AI visual shell |
| 4 | Complete | AI response contract + mapper |
| 5 | Complete | Mock response rendered by existing Home cards |
| 6 | Complete | AI controller + state |
| 7 | Complete | AI service abstraction |
| 8 | Complete | NestJS AI endpoint + mock provider |
| 9 | Complete | OpenAI-compatible real provider |
| 10 | Complete (10A–10D) | Response hardening, live integration, provider config/fallback, AI contract tests |
| 11A | Complete | Local database/cache foundation |
| 11B1 | Complete | Home schema mapped and contract-tested end to end |
| 11B2 | Complete | Remaining verified TypeScript errors resolved (backend tsc build clean) |
| 11C | Complete | Search error sanitization |
| 12 | Complete | Home Marketplace UI |
| 13 | Complete | Floating Navigation + persistent CommandBar |
| 14 | Complete (14A UI + 14B wiring/timeouts) | AI Bottom Sheet + CommandBar wiring + 90s timeout hardening; Mock fallback now engages on timeout |
| 15A | Complete | Context-aware AI foundation: AiQueryContext model, service contract extended with optional context, context wired from shell/AI sheet path, backend supports context injection into prompts |
| 15B | Complete | Context-aware AI + Card Engine integration + Home feed context extraction |
| 15C | Complete | Code hygiene & test stabilization: bottom sheet cancellation fix, 0 analyze errors (16 non-blocking), 203 passing tests |
| 16 | Complete | Offline support foundation: Hive-backed OfflineCache wired in main(); write-through cache for flight/hotel/car search results + AI responses (SHA-256 prompt-hash keys); cache-first read with graceful fallback on network failure; `crypto` package added; 23 new tests, 226 total passing |
| 17 | Complete | Auth: backend register/login/me (bcryptjs, JwtStrategy+Guard, validated DTOs) + Flutter secure-storage session, `/auth` page, profile split, logout; plus Home empty-state fix (demo+cache fallback), `npm run seed:home` dev seed, CommandBar layout fix. Booking/payment foundation later completed via the Wave workstreams (see below) |
| W0 | Complete (2026-09-02) | "Pure White Premium" light-only design language (dark REMOVED by user decision); attached bottom nav Home/Search/AI-centre/Groups/Explore + StatefulShellRoute; seamless merged headers (fixed shell header removed); fade-through transitions; Manrope+Cairo fonts; en/ar l10n; Search Hub/Explore/Groups/Notifications/Wishlist/Settings/Onboarding pages; booking funnel pages (review/passengers/add-ons/checkout/confirmation); dead code cleanup (AiMorphControl, FloatingNavigation, CommandBar, legacy nav) |
| W1 | Complete (2026-09-02) | Real providers: Nuitee hotel adapter (LIVE-verified; rates/prebook/book/content; sandbox key in backend/.env) + Duffel revalidateOffer + MarketContext/FX/Pricing (EGP display, spec point 5 currency separation) + cars rich mock behind CarProvider contract + POST /offers/revalidate + Flutter CustomerPrice model |
| W2 | Complete (2026-09-02) | UI rebuild: SearchScaffold scroll-linked collapsible headers on all 4 verticals + SearchStatesView rich states (retry wired; no-op retry bug fixed) + SortChipsRow + destination picker sheets (autocomplete) + richer forms (trip type/passengers/rooms/transmission) + Home rebuild (DiscoveryProductCard, welcome line, Continue planning strip) + card unification (onFavorite) + runtime fixes (initState router read → didChangeDependencies; SearchViewToggle Expanded crash) |
| W3 | Complete (2026-09-02) | Booking+payment: Flutter OfferRevalidationService wired into booking-review Continue (PRICE_CHANGED blocks checkout) + backend payments module (PaymentGateway, MockEgyptGateway idempotent+webhooks+3DS, PaymentRouter, LedgerService, PaymentService, /payments/*) + Flutter CheckoutPaymentService on real backend flow |
| 18 | Pending | PROJECT_MEMORY cloud sync (auto-backup of memory files to external storage) + analytics foundation (AI query tracking) |
| 19 | Pending | Unified Trip Bag, imports, readiness, Wallet, Price Watch (bag page + trip details v1 shipped in W0; full surfaces pending) |
| 20 | Pending | Live Travel Companion: Today, Map, Travel Mode, event-based notifications |
| 21 | Pending | Accessibility improvements (screen reader support, text scaling compliance) |
| 22 | Pending | Production readiness and launch |
| 23 | Pending | Trusted Group Trips (v1 mock Groups tab shipped in W0; full Phase-24 scope pending) |
| 22 | Pending | Live Travel Companion, Map, Travel Mode, event notifications |
| 23 | Pending | Production readiness and launch (performance optimization, security hardening) |
| 24 | Pending | Trusted Group Trips: members, shared plans, safety, reviews |

### Phase discipline
Each phase is intentionally small. Never start the next phase without an explicit instruction.

### Notes (addendum 2026-08-19)
- Phase 10 was executed as sub-phases 10A–10D and is complete (commit `eda9668e`).
- Phases 11A, 11B1, 11B2 and 11C completed; 11B2's remaining TypeScript errors resolved (backend `tsc` build clean).
- Phase 12 (Home Marketplace) and Phase 13 (Floating/Orbital Navigation + persistent CommandBar) completed and committed.
- Phase 14B completed as 14A (AI Bottom Sheet UI prototype, commit `f2170a7c`) + 14B (CommandBar Ask/TextField wiring, backend AI timeout 90s, timeout classified as retryable so Mock fallback engages, Flutter sheet timeout aligned to 90s). Live AI verified via OpenRouter (`openrouter/free`).
- Phase 15 (15A–15C) completed: context-aware AI + code hygiene baseline.
- Phase 16 completed 2026-08-21: Hive offline cache for offers + AI responses.
- Phase 17 completed 2026-08-21: real auth end-to-end (backend + Flutter), Home empty-state fix (demo+cache fallback, `npm run seed:home` dev seed), CommandBar layout constraints. Next = Phase 18, pending explicit instruction.

### Notes (addendum 2026-08-26) — post-Phase-17 AI chat overhaul (unnumbered iteration)
Executed across multiple sessions on top of Phase 17; no numbered phase was opened.
- AI launcher retired the floating morph window entirely (scrim/swipe-to-close era removed). `lib/app/widgets/ai_morph_control.dart` is now a bubble-only launcher that pushes `/ai-chat`.
- NEW full-screen chat page: `lib/features/ai/presentation/pages/ai_chat_page.dart`, top-level GoRoute outside ShellRoute with standard platform transitions (iOS edge-swipe-back preserved).
- Conversation model: `AiChatMessage` (user/assistant, fromCache) + `AiState.messages`; controller appends user msg instantly and assistant replies on success/error/empty; rolling cap 50 messages; 6h idle TTL with injectable clock (`expireIfIdle`). In-memory persistence semantics: backgrounding keeps the chat, app restart clears it.
- Chat UX: WhatsApp-style expanding input (1→4 lines), circular gradient send button, typing dots, per-bubble entrance animations, ⚡ cached badge, friendly error bubbles + retry, haptics on open/close/submit.
- Closing paths: header ✕ (right side), Android Back, iOS swipe-back, Escape (web/desktop).
- Fixed Hive disk-round-trip crash: `HiveOfflineCache` box retyped to `Box<Map>` with deep `convertHiveValue`; cache reads made best-effort in `AiController.submit` and `ai_bottom_sheet`. This also protected flight/hotel/car search caches.
- Tests: Flutter suite grew 242 → 262 passing (chat model/controller/page/bubble suites); analyze 0 errors. New test files: `test/features/ai/ai_chat_messages_test.dart`, `test/features/ai/presentation/pages/ai_chat_page_test.dart`, `test/core/storage/hive_offline_cache_test.dart`.
- Known issue logged: pre-existing `hotel_card.dart:34` Column overflow with demo data at small test viewports (unrelated to AI work).
- Next = Phase 18, still pending explicit instruction.

### Notes (addendum 2026-08-26 #2) — Card system redesign + audit (unnumbered iteration)
- All Home + Search cards brought to one luxury standard matching the search pages' visual language: gradient-scrim-over-image on Hotel/Package/Car, corner badge/rating pills, compact 200px pill FlightCard for horizontal containers, NEW generic `SectionContainerCard` (title + View All + horizontal child cards), search-result cards gained `CardImage` (`BaseOffer.imageUrl` already existed — no model change), `CardImage` gained `fallbackIcon` degraded-image support wired across all image cards, `CardPrice` gained a scrim-legible `color` override. FlightCard semantics hardened with `ExcludeSemantics`.
- Full audit written to `docs/card-system-audit.md` (inventory, issues, duplication, reuse map, gaps vs professional system).
- **Approved follow-up sub-phases (slot alongside/before Phase 18 per user sequencing):**
  - **24A Consolidation:** hotel search page adopts shared HotelResultCard; extract shared RatingPill/scrim primitives; remove triplicates.
  - **24B Interaction contract:** onTap/actionLabel plumbing through HomeCard → detail stubs; wire View All.
  - **24C Favorites:** FavoritesService + heart toggle (Hotel/Package) with local persistence.
  - **24D Polish:** intl price formatting, shared skeleton family, responsive breakpoints, RTL audit.
  - **24E QA:** golden tests per card + accessibility re-audit.
- Note: the original roadmap's "Phase 24 = Trusted Group Trips" is unchanged; the card work above is an unnumbered iteration to avoid renumbering.

### Notes (addendum 2026-08-26 #3) — Card system Stage 2: shared design system (committed)
Stage 1 (redesign + audit) is recorded in addendum #2. Stage 2 built ONLY the shared Card Design System — no feature card (HotelCard/FlightCard) was rebuilt and no universal card was created. Everything below is committed.
- **New `lib/core/widgets/cards/card_glass.dart` (`CardGlass`):** one reusable frosted-glass recipe (BackdropFilter + brightness-aware tint + hairline border) used by every on-image overlay — centralises glassmorphism "only where the current design fits it".
- **Shared `formatCardPrice()`** in `card_price.dart`; `CardPrice` and `CardPriceBlock` both call it (removes duplicated price-formatting logic, incl. the raw `$` formatting in the hotel page's private `_HotelCard`).
- **Theme/light-dark + responsive hardening across primitives:** `CardBadge` (new `CardBadgeVariant { tinted, glass }` + optional icon), `CardRating` (new `onImage` glass pill — the single impl the 3× rating-pill triplicate should adopt), `CardFeatureList` (`primaryContainer`/`onPrimaryContainer`, `onImage`), `CardFavorite` (theme-aware surface/foreground, `onImage` glass heart, added unused-import removal), `CardCancellation` (brightness-adjusted success), `CardImage` fallback (`surfaceContainerHighest`/`onSurfaceVariant`), `BaseCard` shadow brightness-aware + gained `semanticsLabel` with `button`/`enabled` semantics (pressed/disabled/loading intact).
- **No new packages, no API changes, no business-logic change, no deleted files.** Only `lib/core/widgets/cards/*` + `test/core/widgets/cards/*` were touched in Stage 2.
- **Tests:** `test/core/widgets/cards/card_system_test.dart` expanded (CardGlass, formatCardPrice, onImage variants, disabled opacity). Full suite: **293 Flutter tests pass / 6 skipped; `flutter analyze` 0 errors**.
- **Next (unchanged order):** card sub-phases **24A → 24E** (consolidate the hotel search `_HotelCard` onto `HotelResultCard`, interaction contract, favorites, polish, QA) — then Phase 18 still awaits an explicit instruction.
### Notes (addendum 2026-09-02) — Wave workstreams complete; how they map to old plans
The three Wave workstreams (W0–W3 above) were executed 2026-09-02 after Phase 17. Cross-reference for older plans so nothing reads as a contradiction:
- **Card sub-phases 24A–24E (historical plan):** superseded/absorbed by W2's card-system unification — `onFavorite`/`isFavorite` renamed everywhere, dead primitives deleted (price_display_strategy, recommendation_reason, badge_group, card_badge_helpers), skeleton colour tokenized, `DiscoveryProductCard` added for Home hotel/car/package items. The old 24A "hotel `_HotelCard` adoption" was overtaken by the full Wave-2 page rebuilds. No card favourites PERSISTENCE exists yet (heart is presentational) — that remains open work.
- **Phase 18 (memory cloud sync + analytics): still pending — nothing shipped.**
- **Phase 19 scope shift:** Bag PAGE + TripDetails v1 shipped in W0 (tabs, status chips, Continue planning strip on Home). The full Phase-19 vision (TripItem model, imports, readiness checklist, Wallet, Price Watch) is still pending; `lib/features/bag/domain/trip.dart` still only has `TripSummary` + `ItineraryStage` + `WatchItem` (unwired).
- **Phase 21 (roadmap Phase 24 Trusted Groups):** only the v1 mock Groups tab shipped in W0. Roles/join requests/polls/safety are NOT implemented.
- **Design-language caveat for card docs:** older card-system notes describe brightness-aware/dark variants — since W0 the app is LIGHT-ONLY; dark branches were removed. CardGlass/etc. now carry light defaults.

### Notes (addendum 2026-09-02) — Admin workstream (unnumbered, user-requested)
Executed as explicitly-approved admin workstream phases (not part of the numbered roadmap):
- **ADM-A1 complete:** backend Home content management. New: `roles.decorator.ts` (`@Roles`), `roles.guard.ts` (admin role gate behind JwtAuthGuard), `admin.dto.ts`, `AdminService` (sections/cards CRUD + reorder + audit log), `AdminController` (`/admin/home/*`, `/admin/audit-logs`), `scripts/seed-admin.js` (`npm run seed:admin`). Entities: `home_sections`/`home_cards` gained `publishAt` + `status` (draft|published).
- **ADM-B1 complete:** DB-driven provider switching. `Provider` entity gained `vertical/priority/isFallback/healthStatus/latencyMs/lastCheckedAt`; new `ProviderInstances` (key→instance map incl. disabled) + `RegistrySyncService` (seed defaults + sync registry from DB ordered by priority, legacy fallback when DB down); `ProviderRegistryImpl` gained `set*Providers` + `getProviderByKey`; `AdminProvidersController` (`/admin/providers/*`: status/priority/config/health-check/refresh-registry — runtime switching, no restart); `HomeService` publication-window filter (drafts/scheduled/expired hidden; legacy rows treated as live). `POST /offers/revalidate` and payments untouched.
- **ADM-A2 complete:** Flutter admin panel. New `lib/core/admin/` (`HttpAdminHomeService` — first implementation of the legacy `AdminHomeService` contract; `HttpAdminContentService` raw admin rows; `HttpAdminProviderService`; `AdminApiException`); new `lib/features/admin/` (AdminPage tabs: Home content + API providers; card editor sheet with live `HomeCard` preview; visibility/status/reorder/health-check controls; en+ar l10n keys); `/admin` root route (outside shell, like `/ai-chat`); Settings entry; `AuthUser.role` + `isAdmin`.
- **ADM-M complete:** memory sync (this addendum + 03_CURRENT_STATE checkpoint).
- **Validation:** backend tsc clean; jest 152 passed (was 129; +23 admin/publication tests, includes updated expired-fixture date in `home.schema.spec.ts`); `flutter analyze` 0 errors (104 pre-existing infos/warnings in unrelated files); `flutter test` 438 passed / 6 skipped (was 432/6; +6 admin service tests).

### Notes (addendum 2026-09-06) — Home & Platform workstream (M0 + H1, UNCOMMITTED)
Executed on top of everything above by the Home & Platform agent; spec = `MASTER_PLAN.md` (repo root):
- **Fake Home data purged from Postgres (user-approved transactional DELETE):** `home_sections` (4 rows: Recommended for you / Trending destinations / Tour packages / Experiences & stories) + their `home_cards` (10 rows) — both tables now 0 rows. Home is Nuitee-only by product decision (real sections return in Phase 7B). `backend/scripts/seed-home.js` kept intact (card system reserved). Do NOT run `npm run seed:home`.
- **Nuitee-only Home behavior (M0):** empty `/home/sections` feed is AUTHORITATIVE — the legacy `home|sections` cache is no longer resurrected on an empty feed; the per-audience v2 snapshot is dropped via new `HomeRepository.clearHomeSnapshot` (contract + `HomeRepositoryImpl` + test fakes) when the backend confirms the feed is empty. Empty feed → `developmentPreview`; Nuitee hotels arriving (`GET /home/recommended`) flip it to `success` with the rail as the only content. `loadRecommendedHotels` upgraded accordingly. Tests: home suites rewired (+3 Nuitee-only tests; round-trip fallback test moved to the failure path) — all green.
- **H1 — single skeleton rail + pull-to-refresh removal:** `RefreshIndicator` removed from `HomePage` and `HomeController.refresh()` removed (repository `refresh()` hook kept — contract). NEW `_SkeletonRecommendedRail` + `_SkeletonHotelCard` in `home_page.dart`: mirrors the real carousel EXACTLY (fixed "Recommended for You" title, 220px rail, 260px cards, 120px image, text shimmer rows) and renders only while `recommendedHotels.isEmpty && sections.isEmpty` — zero layout jump when Nuitee data lands. `_developmentPreviewSections()` KEPT intact (no-deletion rule). New widget test file `home_skeleton_rail_test.dart` (3 tests, controller pinned via provider override + inert repo). Retired the manual-refresh controller test (documented).
- **Validation at close:** flutter test **633 passed / ~6 skipped / 0 failed**; analyze 0 errors; tsc clean; jest 232/1 skipped. No commit performed.
- **Coordination:** US-2 (other workstream) was left untouched; two lint infos in its WIP test file reported only.

### Notes (addendum 2026-09-03) — R-4 personalization workstream (executed 2026-09-02 late, UNCOMMITTED; stabilized + documented by Phase 0 on 2026-09-03)
Executed after the Admin workstream, never committed and never documented until Phase 0. All verified by direct code inspection during the Phase-0 discovery audit:

- **R-4 backend modules (new, in `backend/src/modules/`):**
  - `geo/` — `GeoService` (ip-api.com, IP + optional GPS coords, cross-checked confidence high/medium/low, 24h cache, 4s timeout, silent null on failure) + `GeoController` (`GET /geo/country?lat&lng`; loopback IPs skipped; X-Forwarded-For honored).
  - `profile/` — `UserProfile` entity (`user_profiles`: preferences/derived jsonb, countryCode, countryConfidence, personalizationEnabled default true) + `ProfileService` (getOrCreate, updatePreferences merge, updateDerived engine-side, setCountry / setCountryIfMoreConfident low<medium<high) + `ProfileController` (`GET/PATCH /profile/me`, JWT-guarded).
  - `events/` — `UserEvent` entity (`user_events`: userId?, deviceId?, type, payload jsonb) + `EventsService.track` (saves row, folds into derived profile only for logged-in users: hotel_search→topDestinations/lastDestination/budget; hotel_view→lastViewedHotel; hotel_favorite→favoriteHotels (cap 20); trip_planned & booking_confirmed→upcomingDestination) + `EventsController` (`POST /events`, DTO allowlist of the 5 types).
  - `recommend/` — `RecommendedHotelService` (country from profile or query → per-country popular-city Nuitee scans from COUNTRY_CITIES (17 countries) → dedupe by providerHotelId → deterministic score `rating × (1+log10(reviews+1))` adjusted by budgetMax/preferredStars/amenities → optional AI re-rank of the SAME ids, prompt forbids inventing hotels → fallback = empty list, Flutter keeps seed content) + `RecommendedHotelsController` (`GET /home/recommended?limit`, optional JWT enrichment, guests get defaults). `RecommendModule` imports Nuitee/Profile/Ai modules.
- **R-4 Flutter:** `HomeRepository.getRecommendedHotels` + `HomeRepositoryImpl` parser (`/home/recommended`) + `HomeController.loadRecommendedHotels` (non-blocking, silent on failure) + Home "Recommended for You" `_RecommendedHotelsCarousel` (`home_page.dart`); `geolocator: ^13.0.2` dep + `ACCESS_FINE/COARSE_LOCATION` (Android) + `NSLocation*UsageDescription` (iOS).
- **AI mock/fallback removal (same workstream, deliberate):** deleted `backend/src/modules/ai/mock.ai.provider.ts`, `backend/test/ai.fallback.spec.ts`, `backend/test/nuitee.contract.spec.ts` (+ `NUITEE_FIXTURES` export from `nuitee.service.ts` — offline contract coverage lost, see 07), `lib/features/ai/application/ai_mock_providers.dart`, `lib/features/ai/data/mock_ai_*` (3 files). `ai.module.ts` now binds `OpenAiAiProvider` unconditionally (no MockAIProvider at boot without key; misconfig → 503 fast-fail). `ai.service.ts` rewritten: `AiAttemptRecord` lost `fallbackUsed`; `formatAiAttempt` renders provider/outcome/latencyMs/category/upstreamStatus only. `app.module.ts` also gained `envFilePath: ['.env', '../.env']`.
- **Phase 0 stabilization (2026-09-03, this checkpoint):** `backend/test/ai.observability.spec.ts` rewritten for the single-provider contract (removed scenario-3 fallback suite, fallbackUsed assertions, HTTP fallback expectations; 16/16 green); `test/features/home/home_controller_test.dart` FakeHomeRepo implements `getRecommendedHotels` + 2 new tests; `lib/features/ai/presentation/widgets/ai_bottom_sheet.dart` primary/fallback duplication removed (single `_service`); `backend/.env.example` fallback section replaced with removal note; stale `test/features/ai/ai_bottom_sheet_test.dart` deleted (imported deleted mocks — user-approved); stale `PROJECT_MEMORY.zip` snapshot deleted (user-approved; was an outdated copy of PROJECT_MEMORY at repo root).
- **Validation after Phase 0 (verified numbers):** `dart analyze lib test` 0 errors (107 infos/31 warnings pre-existing, unrelated); `flutter test` 437 passed / 6 skipped / 0 failed (net: −3 stale bottom-sheet tests, +2 recommended-hotels tests, −1 previously failing controller test now fixed); backend `tsc --noEmit` clean; `jest` 134 passed / 1 skipped / 0 failed (was 129 passed / 9 failed pre-fix: 9 obsolete fallback assertions).
- **Git state at Phase 0 close:** 4 unpushed local commits (admin workstream: f95cecf2, b41ae2f4, 7344acd2 + bf3335d1) + R-4 and Phase-0 changes all uncommitted in the working tree. No commit/push performed — awaiting explicit user instruction.

### Addendum 2026-10-17 — Stabilization (unnumbered; home-search pill + nav fix)
Executed 2026-10-16/17 on top of the documented 3D (2026-09-09) state; the memory files had not been updated for this work.
- **Repo was not under version control** (`.git` absent). Initialized `git` (branch `main`) + root `.gitignore`; first snapshot commit `6c3823e` (651 files). Excluded secrets/generated: `.env`, `backend/node_modules`, `build/`, `.dart_tool/`, `backend/test-nuitee.ts`, `wetravellers_offline_data/`.
- **Home smart AI search pill** (`home_ai_search_field.dart`): a genuine editable `TextField` with a rotating typewriter hint and a rotating aura border; trailing search/send icon and Enter share one submission path → pushes `/ai-chat` with the trimmed query via GoRouter `extra`; leading `auto_awesome` icon pushes `/smart-search`. `home_page.dart` also gained the TokiGo wordmark (Toki grey + pulsing red "Go"). Mic stays a disabled placeholder (voice lives in Universal Search, US-3).
- **Navigation-shell fix** (`go_router_config.dart`, `shell.dart`): removed the custom branch-level `navigatorKey` (a top-level `GlobalKey<NavigatorState>`) that produced "Duplicate GlobalKey detected in widget tree involving `_BranchNavigatorProxy` and `StatefulShellBranch`" during shell rebuilds.
- **Stabilization fixes:** 4 failing Flutter tests repaired — `test/navigation/go_router_shell_test.dart` (harness used non-absolute route paths → "Page Not Found"; page assertion corrected; back via `tester.pageBack()`), and `test/features/home/presentation/widgets/home_ai_search_field_test.dart` (Enter now tested through `testTextInput.receiveAction(TextInputAction.send)`; duplicate-prevention rewritten to the real contract — offstage pill + cleared field; Arabic test split from the sparkle-navigation test) — plus `backend/test/memory.spec.ts` made deterministic (tied `new Date()` `updatedAt` values).
- **Validation (verified 2026-10-17):** `flutter test` **777 passed / 6 skipped / 0 failed**; `dart analyze lib test` **0 errors / 0 warnings** (148 infos); backend `tsc --noEmit` clean; `npx jest` **282 passed / 1 skipped / 0 failed**.
- **New unimplemented requirement:** GO button / trip-start flow + travel/visa requirements + VISA INDEX (`Documents/زرار GO عند الضغط عليه.txt`). No phase assigned yet.
- **Commit:** `6c3823e` (initial snapshot). All work above is now tracked on `main`.
