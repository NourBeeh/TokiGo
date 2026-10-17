# TokiGo — Master Execution Plan (MERGED v2)

> **نقطة الاستكمال في أي سيزون جديد:** اقرأ الملف ده كامل + AGENTS.md + الملفين الأصليين (`محرك التوصيات.txt`, `UNIVERSAL SEARCH MASTER.txt`) حسب المرحلة اللي هتنفذها + `git status --short`. نفّذ أول مرحلة PENDING حسب "الترتيب المتفق عليه" تحت. الملف ده مصدر الحقيقة الوحيد.
> **PENDING DECISIONS قسم في الآخر — عشان أي اقتراح جديد محتاج موافقة صريحة قبل التنفيذ.**

---

## Resume protocol (any new session)

1. Read THIS file fully → AGENTS.md → the source prompt file for the target phase (`محرك التوصيات.txt` = memory/booking/trip track, `UNIVERSAL SEARCH MASTER.txt` = search track).
2. `git status --short` — the working tree is SHARED with the Universal Search workstream (their US-2 work is uncommitted).
3. Execute the first PENDING phase in the "Agreed execution order". Confirm with the user first. Per-phase: implement → validate → report → STOP, wait for approval.
4. Update this file's status markers after each phase (this file IS the progress log).

## Status snapshot (2026-10-17 — latest)

- **App identity renamed to TokiGo** (`wetravellers`→`tokigo`; package `tokigo`, bundle `com.tokigo.tokigo`) — commit `1672b5fb` pushed to `origin/main`; re-validated green after the rename.
- **Local runtime ready:** `backend/.env` (gitignored) holds auto-generated JWT secrets + live keys — Nuitee, **Duffel** (the "second provider"), **OpenRouter AI** (`AI_BASE_URL=https://openrouter.ai/api/v1`, `AI_MODEL=openai/gpt-4o-mini`). Live-verified: `/ai/query`, `/ai/suggest`, `/home/recommended`. Backend + Flutter Linux desktop app running locally.
- Repo is now under `git` (branch `main`, first snapshot commit `6c3823e`); root `.gitignore` excludes secrets and build artifacts (`.env`, `backend/node_modules`, `build/`, `.dart_tool/`, `backend/test-nuitee.ts`).
- Verified green: Flutter **777 passed / 6 skipped / 0 failed** + `dart analyze` 0 errors/0 warnings; backend **`tsc --noEmit` clean** + **jest 282 passed / 1 skipped / 0 failed**.
- Completed through phase **3D** (2026-09-09) per the phase log below. Undocumented 2026-10-16/17 work (Home smart AI search pill, TokiGo wordmark, navigation-shell GlobalKey fix) is now recorded in `PROJECT_MEMORY/`.
- **First PENDING phase in the agreed order: US-5** (search personalization).
- **NEW unimplemented requirement (user 2026-10-17):** GO button / trip-start flow (auto current country via geo → choose destination or AI ideas → resume/continue/navigation-only) + continuously updated travel/visa requirements + **VISA INDEX** — no phase assigned yet, needs a decision before entering the order.

## Execution protocol (non-negotiable — from both source plans + AGENTS.md)

- Per phase: **implement → test → fix errors → report → STOP**. Never start the next phase without user approval.
- Validation: Flutter phases → `dart analyze lib test` + `flutter test` (0 failed, 0 analyzer errors); backend phases → `npx tsc --noEmit` + full Jest.
- No commit / push (US-1-FINAL was the single approved exception; already done). No file deletion without explicit approval. No package installation without approval. No destructive git.
- Never modify Home Ranking / Recommendation Engine / EventsTracker implementation / Product Card architecture / Booking architecture / Theme / SearchIntentParser behavior **unless the phase explicitly authorizes it**.
- No ML / vector DB / embeddings. Cache is never price/availability truth.
- If a defect is found in a file owned by the OTHER workstream (list below): **report it, do not fix without approval**.
- `backend/test-nuitee.ts`: never modify/delete/commit.
- Any NEW idea or change to an existing decision → **ask the user FIRST** (see PENDING DECISIONS).

## Workstream boundary — Universal Search agent (WIP) — DO NOT MODIFY until landed

Until the user confirms US-2 has landed and is committed:
- `lib/features/universal_search/**` (all)
- `lib/features/ai/data/ai_api_service.dart`, `application/ai_providers.dart`, `domain/search_intent_parser.dart`, `presentation/pages/ai_chat_page.dart`, `ai_visual_shell_page.dart`
- `backend/src/modules/ai/**`, `backend/src/common/dto/ai.dto.ts`, `backend/src/modules/events/**`, `backend/src/modules/profile/*` (their edits), `backend/src/app.module.ts` (their edits)
- `lib/app/config/app_config.dart`, `test/features/universal_search/**`, `test/features/ai/**` (their edits)
- STATUS VERIFIED 2026-09-06: US-0 ✅ (contract doc exists `docs/universal-search-ux-contract.md`) · US-1 ✅ + US-1-FINAL ✅ (commit 794ebcb9, zero legacy refs) · **US-2 ⏳ in progress uncommitted** (parser enhanced with `_isNumericFragment`/budget/months, `StructuredTravelIntent` extended with rooms/budget/minStars/amenities, gap-chip flow `fillGap`, 60+ tests added) — looks near-complete, awaiting their validation + report.

## Ground truth (verified in code 2026-09-06)

Backend done: Memory Spine 2A (`/memory/me`), 2B DerivedPreferenceProfile + ranking, 2C-A/B `POST /ai/chat` + selector + extraction. Flutter done: 2A MemoryRepository+tests; Universal Search US-0/US-1 (state machine, Hero container transform 320ms, query persistence, adapters → HomeItem, categories); Home is **Nuitee-only** (uncommitted: Postgres purged 4 sections+10 cards, empty feed authoritative, stale snapshots dropped, hotels flip preview→success; home/repo suites 137 passed; full `flutter test` interrupted → M0). Search infra: 3 vertical controllers (flight/hotel/car) cancellable; `/smart-search` root route; EventsTracker 5 event types.

---

# PHASES

## Track A — Home & Platform (this workstream) — ✅ approved direction

### M0 — Finish validation of Nuitee-only Home + record baseline — ✅ DONE (2026-09-06)
- `dart analyze lib test`: **0 errors** (137 infos — mostly inside US-2 WIP files, reported not fixed).
- `flutter test` full suite: **631 passed / ~6 skipped / 0 failed** (baseline was 568 pre-US-2 — the delta is the other agent's US-2 work, all green).
- Backend `npx tsc --noEmit`: **clean**.
- **NEW BASELINE: 631 passed.** US-2 WIP observations for the other agent (do not fix ourselves): unnecessary dart:async import + underscore local var in `universal_search_controller_test.dart`.

### H1 — Single skeleton rail + remove pull-to-refresh — ✅ DONE (2026-09-06) · UPDATED (2026-09-08)
- `home_page.dart`: removed `RefreshIndicator` wrapper (comment documents the H1 decision); added `_SkeletonRecommendedRail` + `_SkeletonHotelCard` — EXACT geometry of the real rail (same fixed title, 220px height, 260px cards, 120px image, text rows). Renders only when `recommendedHotels.isEmpty && sections.isEmpty` (Nuitee-only loading state); real rail/composed sections replace it with zero layout jump.
- `home_controller.dart`: `refresh()` removed (documented as H1 product decision; repository `refresh()` hook stays — it's the HomeRepository contract).
- `_developmentPreviewSections()` KEPT intact for future phases (no deletion).
- NEW test file `test/features/home/presentation/pages/home_skeleton_rail_test.dart` (3 tests: fixed title, ≥3 skeleton cards + zero RefreshIndicator, zero fake travel data). Controller pinned via `homeControllerProvider.overrideWith` + inert repo.
- Retired test: 'HomeController refresh triggers repo refresh' (documented in place).
- **VALIDATION: flutter test = 633 passed / ~6 skipped / 0 failed (baseline 631 → 633: +3 new, -1 retired). dart analyze = 0 errors.**
- **UPDATE 2026-09-08 (user-approved, part of the empty-home fix):** the "development preview" state (skeleton section HEADINGS with no data — Flight Recommendations/Hotels/Car Rentals/etc. with empty items) was RETIRED from the live flow: an empty feed now publishes `HomeStatus.empty` with zero sections, and the page renders the honest no-content state ("No recommendations right now" + Retry). The skeleton RAIL stays legitimate only as the in-flight placeholder while real hotels load. `_developmentPreviewSections()` itself is kept (no-deletion rule) but no longer called from `load()`; the `developmentPreview` enum value stays (legacy/serialization stability) and `loadRecommendedHotels` still upgrades it to success if a stale caller ever sets it. Skeleton-rail tests rewritten: loading body (ShimmerBox, no Cards), success+empty → rail with fixed title, and the NEW empty-state test (no section headings, retry visible, no rail). Pinned-state tests use never-completing Completer futures so async startup cannot overwrite the pinned state.

### H2 — Refresh = price/availability only — ✅ DONE (2026-09-06)
- `home_controller.dart`: NEW public `refreshPrices()` → routes through the existing `_runLiveValidation()` ONLY (no feed/hotel/image reload). All guards apply (one job per snapshot, content-on-screen, empty-sections no-op → Nuitee-only Home is a safe no-op until 7B sections return).
- `home_page.dart`: `HomePage` → `ConsumerStatefulWidget` with `WidgetsBindingObserver` (app resume → refreshPrices) + GoRouter delegate listener (returning to '/' from any sub-route/tab → refreshPrices). Router hook is LAZY via `GoRouter.maybeOf` in `didChangeDependencies` (test hosts without GoRouter stay valid); unhook in dispose uses the saved router reference (no ancestor lookup in dispose).
- NEW test `test/features/home/h2_refresh_prices_test.dart` (3 tests: revalidates WITHOUT feed/hotels re-fetch (delta-asserted), safe no-op on empty Nuitee-only Home, burst calls collapse into one job via in-flight guard). Spy service pattern over HomeLiveValidationService.
- **P2 APPROVED by user (2026-09-06):** ResizeImage/cacheWidth decode in H3 image cache + external packages allowed WITH per-case confirmation.
- **VALIDATION: flutter test = 636 passed / ~6 skipped / 0 failed (633 → 636: +3 H2 tests). dart analyze = 0 errors. Full-app smoke test green after router-hook fix.**

### H3 — Hotel image cache (Hive) — ✅ DONE (2026-09-07) · BUGFIXED (2026-09-08)
- `lib/features/home/application/hotel_image_cache.dart`: `HotelImageCache` — LRU (cap 30) + TTL (7 days) on top of the EXISTING shared `OfflineCache` box (keys `hotel_image|<url>`), no new Hive box, no packages. Best-effort everywhere (never throws); lazy TTL eviction on read + TTL/LRU sweep on write.
- `lib/features/home/presentation/widgets/cached_hotel_image.dart`: `CachedHotelImage` — shimmer placeholder (H1 primitive) on miss → fetch (shared per-URL `_inFlight`) → store → render; P2 approved decode `Image.memory(cacheWidth: displayWidth×dpr)`; network failure → neutral fallback icon, never throws.
- Wired: hotel card image in `home_page.dart` (rail) + `hotelImageCacheProvider` in `home_providers.dart`.
- Tests: `test/features/home/h3_hotel_image_cache_test.dart` (7 service + 4 widget).
  - **Fix during close-out:** widget tests were hanging forever ("did not complete" + "Bad state: Cannot add event while adding stream" on kill) — root cause: `_pngBytes()` used `PictureRecorder→toImage()→toByteData()`, real engine-async work the testWidgets FakeAsync zone cannot drive. Replaced with constant 1×1 PNG bytes (69B). Also updated 2 pre-P2 assertions to expect the `ResizeImage(MemoryImage)` shape.
- **BUGFIX 1 (user report 2026-09-08) — "Unsupported operation: Infinity or NaN toInt" + "BOTTOM OVERFLOWED BY 99796 PIXELS":** the Home card passes `width: double.infinity` (fill the card — correct); the P2 decode line multiplied that raw width by dpr and rounded → `Infinity.toInt()` the moment cached bytes arrived → the red ErrorWidget (full stack trace) rendered inside a 260px card → the huge overflow. Fix: the DECODE width now resolves from the layout constraints (`LayoutBuilder`), clamped 1–4096; fill behavior unchanged. Regression: `cached_hotel_image_infinity_regression_test.dart` (2) — reproduced the exact user error first (RED), then green.
- **BUGFIX 2 (user report 2026-09-08) — "images reload on every scroll" (same day):** TWO compounding causes. (a) `ListView` destroys off-screen cards and the card was stateless w.r.t. its image — scroll-back = fresh state = shimmer flash. (b) The disk (Hive) read is async, so even a warm disk cache still flashed the placeholder for a frame. Fix: (a) `_HotelCard` → `ConsumerStatefulWidget` + `AutomaticKeepAliveClientMixin` (state survives scroll; rail bounded at 40 items so memory is bounded); (b) NEW `HotelImageMemoryCache` (`hotel_image_memory_cache.dart`) — synchronous session fast-path in FRONT of the disk layer (same LRU-30/TTL-7d discipline, clock injectable for tests), wired via `hotelImageMemoryCacheProvider`; a re-mounted card renders its photo in the SAME frame. Disk stays the cold-start truth. Regression: `hotel_image_scroll_reload_regression_test.dart` (6: sync read/write, LRU eviction, TTL expiry, clear, and the second-mount-no-shimmer widget test).
- **VALIDATION after both fixes: flutter test = 752 passed / ~6 skipped / 0 failed (744 → 752). dart analyze = 0 errors. Backend untouched.**

### NAV — Remove bottom nav; Home-centric navigation — ✅ DONE (2026-09-07)
- NEW `lib/app/widgets/home_nav_buttons.dart`: `HomeNavButtons` — premium horizontal row of the 4 verticals (طيران/إقامات/سيارات/برامج سياحية, hue-tinted pills, 48px targets) + compact secondary row (Explore + Groups) — pushed routes to the EXISTING pages ('/flights','/hotels','/cars','/packages','/explore','/groups'). No new pages/controllers. l10n keys reused (searchFlights/…/exploreTitle/groupsTitle).
- `shell.dart`: `TokiGoShell` simplified — renders the navigation stack only; the floating pill + `_destinationFor`/`_goBranch` retired. `AppBottomNav` widget KEPT (no-deletion rule; its enum asserted intact in tests).
- `go_router_config.dart`: single Home branch — `/search` (+transfers), `/groups`, `/explore` moved from their own `StatefulShellBranch`es onto the Home branch as pushed routes (fade-through preserved). Retired branch keys kept (documented, analyzer-ignored warnings).
- `home_page.dart`: `HomeNavButtons` mounted under the AI search pill.
- Tests rewritten: `full_app_smoke_test.dart` (no pill; visits Flights/Explore/Groups via nav buttons + `router.go('/')` back), `bottom_nav_branch_mapping_test.dart` (shell renders no pill on roots; former tab pages pushable on Home branch; retired enum intact). H1 skeleton fake-data assertion updated (nav labels are navigation, not data).
- **VALIDATION: flutter test = 647 passed / ~6 skipped / 0 failed. dart analyze = 0 errors.**

## Track B — Universal Search (other agent's file, merged order)

### US-2 — Advanced intent + NLP — ✅ DONE (their report merged 2026-09-07)
- Landed in commits 9a5793c2/6b08636b (all US-2 files were included in the session's pushes; tree clean, 647/0 validated after).
- Their scope: StructuredTravelIntent typed fields (durationNights/passengers/rooms/budget band/minStars/amenities + IntentGap/missingFields per vertical + effectiveEndDate); parser enhancements (40+ city dictionary with Egyptian aliases, Arabic intervals, Indian-Arabic digits, numeric-fragment guards; two documented fixes: first-'من' + first-'إلى'); gap-chip flow (typed patches, never invents facts — no silent dates, vertical defaults only); AI resolution contract (LLM output NEVER controls navigation/providers — must compile to intent); validation (past dates/reversed ranges/32-40 dates/1-9 passengers/≤30 nights/≤5 rooms/≤5 stars; numbers never places); 5 follow-up chips now real (أرخص/أفخم actual bands, غير التواريخ → date gap, شخصين, قريب من المطار amenity). +66 tests, zero regression, boundaries respected (no Ranking/Events/Cards/Booking/Theme/backend changes).
- NAV unblocked on this landing — executed (below).

### US-3 — Voice search — ✅ DONE (2026-09-08)
- Package approved via P1: `speech_to_text ^7.4.0` + `RECORD_AUDIO` (Android) + mic/speech plist keys (iOS).
- `domain/voice_search_service.dart` — narrow testable boundary + `VoiceFailure` taxonomy (permissionDenied/microphoneUnavailable/recognitionUnavailable/network/emptyTranscription/cancelled/unknown); NEVER throws.
- `data/speech_to_text_voice_service.dart` — plugin wrapper: initialize==false split into permission-denied vs recognition-unavailable via hasPermission; partial results, dictation mode, 15s listen/1.2s pause; ar-EG for Arabic devices else device default; every plugin exception → typed failure.
- `application/voice_search_{state,controller,providers}.dart` — mic session state ONLY (idle/starting/listening/stopped); transcription NEVER stored — it flows through the page-assigned `onTranscription` bridge into the SAME `_inputController` → `onQueryChanged` (single intake, no parallel voice state); final chunk → stopped + caret restored; NO auto-submit; autoDispose route-scoped providers.
- Header's disabled 36px mic placeholder → live `_VoiceMicButton` (same 36px/placement/visual language): idle=mic, starting=mic_none, listening=stop_circle red + breathing pulse (`_MicPulse`). Semantics: voiceSearch/voiceStarting/voiceStop, button+enabled. 7 new l10n keys en/ar.
- Tests: `voice_search_controller_test.dart` (11: permission-denied no-crash, lifecycle, Arabic verbatim, English verbatim, empty-transcription, mid-session error, cancel resets, user stop, double-tap ignored, dismissFailure, taxonomy mapping) + 2 page-widget tests (mic tap degrades gracefully in recognizer-less env; listening state shows stop+pulse) — the old disabled-placeholder test REPLACED.
- **VALIDATION: flutter test = 704 passed / ~6 skipped / 0 failed (692 → 704: +12 net — the old placeholder test replaced by 2 new widget tests). dart analyze = 0 errors (136 infos/warnings pre-existing, all unrelated).**

### US-4 — AI assistant inside Universal Search — ✅ DONE (2026-09-08)
- **AI success path (existing seams, tightened):** narrative + real product sections land on AI_RESULT through `aiResultsReady` — the result keeps the edit-query affordance and the preserved query: a search answer, never a conversation turn (NO free-form chat loop).
- **AI failure → deterministic fallback (the core US-4 rule — "AI must never block search"):** `aiResultsFailed` now degrades instead of dead-ending. A place-bearing query (English or Arabic preposition: "in/at/في") is re-interpreted through the parser's OWN dictionary (`_lonePlaceIn` probes `'hotel in <place>'` — zero parallel interpretation logic) into a complete hotel intent that executes through the REAL controllers; a query with no honest signal lands on the empty state with the edit affordance — never a stuck spinner. The gaps flow is untouched (phase-guarded no-op off SEARCHING, no hijack of incomplete service queries).
- **AI timeout:** the page arms a 20s `Timer` on the AI-interpreting SEARCHING stretch (cancels the moment the phase resolves): a stalled provider degrades to the deterministic fallback instead of spinning forever. The full AI chat page keeps its own 90s budget — the search surface trades wait for actionability.
- **Safe structured context:** the AI sheet call now carries `AiQueryContext(route: 'smart-search')` ONLY — no tokens, credentials, private backend data, or personal fields reach the AI layer.
- **Comparison contract (spec: "Introduce only the contract needed… Full comparison may remain US-6"):** `FollowUpAction.compare` added to the vocabulary + a «قارن» chip renders with the other follow-ups; the action is deliberately a NO-OP on the intent/phase — the signal is the contract, US-6 builds the comparison view on it.
- **Files touched:** `universal_search_controller.dart` (fallback + compare case), `universal_search_page.dart` (safe context + timeout timer), `universal_search_widgets.dart` (compare chip), `structured_travel_intent.dart` (enum value). No Recommendation Engine / Ranking / backend changes.
- **Tests (`ai_assistant_us4_test.dart`, 10):** AI success lands narrative+phase; query preserved (no loop); place-bearing fallback executes a REAL hotel search (EN + AR canonical names); no-place fallback → empty state, no trap; gaps flow never hijacked; compare is contract-only (intent+phase untouched); cheaper/morePremium still patch bands; follow-up re-enters SEARCHING through real controllers; AI state carries no user/session data.
- **VALIDATION: flutter test = 714 passed / ~6 skipped / 0 failed (704 → 714: +10). dart analyze = 0 errors (136 infos/warnings pre-existing, all unrelated).**

### US-5 — Search personalization — PENDING
- Existing behavioral signals + profile context (EventsTracker, R-4 architecture untouched). Personalization may order/suggest — NEVER override explicit intent (Dubai wins over habitual Cairo). 2C rule: no explicit memory facts into DerivedPreferenceProfile/Home ranking (that's Phase 7's job, separately approved).

### US-6 — Compare + refinement — PENDING
- Contract-based comparison on structured fields (hotel/flight/car field lists in spec). Refinements patch intent or explicit SearchFilter → SEARCHING. Preserve query+refinement state on back.

### US-7 — Production hardening (Universal Search) — PENDING (placed after 7B — see order)
- Full audit: state machine, Hero handoff pixel-stability, keyboard (iOS/Android/desktop/web), back behavior, query persistence, suggestions debounce/cancellation, AI fallback, adapters, events, cache, accessibility, responsive, performance (rebuilds/leaks/timers).
- **PROPOSAL P5 (needs approval):** add Android 14 **predictive back** verification (`PopScope.canPop` ahead-of-time API — per docs.flutter.dev) to the audit checklist, since US-0 deferred it to US-2+.

## Track C — Memory & AI (from محرك التوصيات)

### 2C-C1 — Flutter wiring for `POST /ai/chat` — ✅ DONE (2026-09-07)
- NEW files ONLY (zero edits to `ai_api_service.dart`/`ai_providers.dart`/Universal Search):
  - `lib/features/ai/data/ai_chat_repository.dart` — `AiChatRepository` boundary + `AiChatValidationException` (maxPromptLength 4000 mirrored from backend AiChatDto).
  - `lib/features/ai/data/ai_chat_repository_impl.dart` — routing contract: token in SecureTokenStorage → `POST /ai/chat` with Bearer header; guest → existing memory-free `POST /ai/query` (unchanged). Prompt trimmed + empty/4001+ fails fast BEFORE any network call. Default 90s chat timeout. Response parsed via the EXISTING `AiResponse.fromMap`. Flutter does NOT extract memories / decide relevance / send raw transcripts — all server-side.
  - `lib/features/ai/application/ai_chat_providers.dart` — `aiChatRepositoryProvider` (own `aiChatApiClientProvider` — same per-library shape as home/booking; shared `secureTokenStorageProvider`).
- NEW test `test/features/ai/data/ai_chat_repository_test.dart` — 11 tests: serialization (prompt+context), trim, response parsing, 4000 limit (over fails without network / at-limit passes / empty fails fast), authenticated→/ai/chat+Bearer, guest→/ai/query no header, server error propagates as ApiError, malformed payload → empty-sections contract, default timeout applied.
- No UI built (per 2C-C1: UI is 2C-C2). `/ai/query` untouched. No Home/Ranking/cache changes.
- **VALIDATION: flutter test = 658 passed / ~6 skipped / 0 failed (647 → 658: +11). dart analyze = 0 errors.**

### 2C-C2 — Memory Controls + Chat UI — ✅ DONE (2026-09-08)
- **Chat wiring** (chat page ONLY — bottom sheet + AI-mode shell keep the legacy `aiControllerProvider`/`/ai/query` untouched):
  - `ai_chat_page_providers.dart` — NEW `aiChatControllerProvider`: the EXISTING `AiController` (cache/retry/idle-expiry/rolling-cap, zero duplicate state) driven by `AiChatServiceAdapter` → 2C-C1 `AiChatRepositoryImpl` (auth→`/ai/chat`, guest→`/ai/query`).
  - `ai_chat_service_adapter.dart` — bridges `AiChatRepository` into the existing `AiAssistantService` boundary; legacy content-generation methods fail loudly.
  - `ai_chat_guest_only_cache.dart` — identity-aware OfflineCache wrapper: GUEST turns read+write the shared cache; AUTHENTICATED turns bypass BOTH (anti-resurrection: a memory-enriched reply must never be replayed after a memory edit/clear/personalization toggle). Unreadable storage fails closed.
  - `ai_chat_page.dart` edited: watches `aiChatControllerProvider`; header gains the memory-controls entry button (semantic label, Premium Light, RTL-safe).
- **"What I Know About You"** — route `/ai-memory` (root-level, fade-through):
  - `explicit_memory_view.dart` — presentation model: vocabulary filter (ONLY preferred_destination/budget/travel_style; suffixed keys `preferred_destination:slug` handled; behavior/derived/foreign rows invisible), human-readable rendering (title/displayValue — never raw ids/source/confidence/JSON).
  - `ExplicitMemoryInput` — client-side validation mirroring backend `conversation_facts.ts` EXACTLY: destination ≤ 80 chars, budget finite numbers + min ≤ max + at least one bound, styles ≤ 60 items × 60 chars, split on `,` + `،`, trim, no empties. Fails BEFORE any network call.
  - `explicit_memory_controller.dart` — list (type=conversation, expired filtered), edit (updateMemory → optimistic in-place swap), delete, **clearAll = sequential deletes of the LISTED rows ONLY — `clearMyMemories()` (DELETE /memory/me) is NEVER called from this surface** (it would wipe behavioral/derived data — spec: حذف memory لا يعني حذف profile/behavioral). 404 mid-sweep = idempotent continue; real failure aborts with error + list intact. Load failure keeps previous list + inline error.
  - `ai_memory_page.dart` — guest → sign-in prompt (no memory surface); empty state + retry; kind-specific edit sheet (destination text / min+max budget / styles) with validation; delete + snackbar; clear-all with confirm dialog; Premium Light + RTL verified.
  - l10n: 17 new keys (en/ar), `flutter gen-l10n` regenerated.
- **Tests (34 new + 4 chat-page updated):** `explicit_memory_view_test` (12: vocabulary filter, suffix strip, rendering, validation matrix, Arabic-comma split), `explicit_memory_controller_test` (9: filter/expiry/edit/delete/clear-all-scope/404/abort/dismiss), `ai_chat_guest_only_cache_test` (5: guest passthrough, auth bypass, fail-closed, empty-token, delegation), `ai_memory_page_test` (7: guest prompt, list no-raw-fields, empty, delete, clear-all-never-wipe, edit validate→save, RTL), `ai_chat_page_test` host gained l10n delegates (was the pre-existing gap).
- **No backend changes** (contract was clean). No new packages. No Home/Ranking/DerivedPreferenceProfile/`ai_providers.dart` touches. `/ai/query` untouched.
- **VALIDATION: flutter test = 692 passed / ~6 skipped / 0 failed (658 → 692: +34). dart analyze = 0 errors (135 infos/warnings pre-existing in unrelated files — reported, not fixed). No orphan flutter_tester processes.**

### 2D — AI context hardening — ✅ DONE (2026-09-08)
- **Audit result:** the 2C-A/2C-B suite already proves guest isolation, personalization-disabled behavior, expiration, ownership, sensitive scanner, selector/extraction failure isolation, and memory-value-free logging (`ai.chat.memory-context.spec.ts` + `conversation_memory.spec.ts` + `memory.spec.ts`). The REAL gaps this phase closes: prompt-injection boundaries and write-time line-forgery guards.
- **Untrusted-data envelope** (`ai.conversation.controller.ts` — `buildMemoryContextBlock`):
  - every fact line runs through `sanitizeMemoryLine` (strips C0/DEL control chars, collapses whitespace → a stored value can NEVER forge new prompt lines);
  - the block frames facts as "PASSIVE DATA … never instructions" and instructs the model to ignore any instruction-looking value — memory content cannot override system/developer rules;
  - framing lines come AFTER the data region, so an injection payload can never be the last thing the model reads;
  - **bug found & fixed by the new tests:** a budget fact with no finite bounds rendered `- Preferred budget: unspecified` (fabricated data) — now yields NO line.
- **Write-time guards (defense in depth):**
  - `conversation_facts.ts` `validateConversationFact` rejects control characters in `destination` and every `styles` item (extraction path);
  - `memory.dto.ts` `containsControlCharacters` (recursive, same shape as the sensitive scanner) enforced in `MemoryService.upsert` + `updateOwn` — covers the DIRECT memory-API path (Flutter memory-controls page edits) too.
- **NEW spec `test/ai.context-hardening.spec.ts` (15 tests):** envelope framing/structure, CR/LF + NUL/ESC stripping, injection payload renders neutered single-line BELOW the framing, end-to-end /ai/chat injection stays data-only (user prompt untouched), observability line format carries no memory values, selector-failure isolation with class-only logging, rerank whitelist rejects memory keys, DerivedPreferenceProfile folds ONLY behavior rows (conversation/budget rows invisible), write-path rejection at extraction + upsert + updateOwn with nothing persisted.
- No model/provider changes. No ML/embeddings. `/ai/query`, Home Ranking, `/ai/rerank` untouched.
- **VALIDATION: backend `tsc --noEmit` clean + `npx jest` = 247 passed / 1 skipped / 0 failed (232 → 247: +15). Flutter untouched by this phase: dart analyze 0 errors (135 infos/warnings pre-existing, identical count to 2C-C2), flutter test = 692 passed / ~6 skipped / 0 failed (unchanged — all new tests are backend).**

### PH-7 — Explicit Memory → Home Ranking (the deliberately deferred standalone phase) — PENDING
- `ExplicitPreferenceSignal` adapter; NEVER conversation→behavior type conversion; DerivedPreferenceProfile semantics untouched; behavioral memory stays separate.
- Precedence: hard validity > explicit user signal > 2B explicit profile prefs > derived behavioral > deterministic score > stable tie-breaker. Explicit wins on conflict; never overrides availability/price/provider truth.
- Batch retrieval only (no N+1, no per-card, no AI calls in ranking). Expired/wrong-user/wrong-type ignored; no duplicate-key inflation; latest value on same-key conflict.
- `preferred_travel_style`: verify a deterministic consumer exists; else implement the other two + document deferral.
- Deliverables: explicit signal CONTRACT documented, signal PRIORITY separated from result ORDERING, integration point rationale, full regression, final report confirmations (2B intact, /ai/rerank whitelist unchanged, cache-first intact, no AI call in ranking, no ML/vector).

## Track D — Search backend & verticals (from محرك التوصيات; feeds US-5/US-6)

### 3A — Unified search foundation — ✅ DONE (2026-09-08)
- **Audit result:** the foundation already exists from Waves W0-W3 — models (`core/domain/models/search/`), Repository→UseCase→Controller for flight/hotel/car, Riverpod state, backend aggregation (`/search/{flights,hotels,cars}` with `Promise.allSettled` partial failure), loading/error/empty states, packages = mock surface (Phase 19B, per spec "حسب الـ backend الحالي فقط"), cars = `mock-car` provider (spec: "غير محسوم" — no provider invented). Two REAL gaps closed this phase:
- **Gap 1 — the hotel request contract was lossy:** `HotelRepositoryImpl` ignored `rooms/minRating/maxPrice/minPrice/amenities` (rooms was hard-coded to 1). Now: `buildSearchBody` (pure static, unit-tested) carries EVERY rich param verbatim; omitted ones stay out of the body; `setNextSearchExtras` (@visibleForTesting seed, interface kept backward-stable for all existing callers) + the controller seeds it before every call.
- **Gap 2 — no stale-response protection on the vertical controllers:** flight/hotel/car controllers now do request versioning — a new `search()` supersedes the in-flight one; late results from an older request are dropped at every await point (cache read + network). Universal Search already had its own versioning; the verticals were exposed.
- **No booking/payment/details UI/ranking/provider changes.** Providers unchanged: flights=Duffel ("Doville" in spec = the existing Duffel integration), hotels=Nuitee, cars=mock-car, packages=mock.
- **Tests (`search_foundation_3a_test.dart`, 8):** request-body contract (baseline/rich/omitted-params), extras seeding verbatim through the REAL impl, plain-repository interface stability, stale-response guard on hotel + flight + car (gated fake: first search stalls, second lands, first's late result is dropped — final state belongs to the newest search).
- **VALIDATION: flutter test = 722 passed / ~6 skipped / 0 failed (714 → 722: +8). dart analyze = 0 errors (137 infos pre-existing). Backend untouched but re-validated per AGENTS.md: tsc clean + jest 247 passed / 1 skipped / 0 failed (unchanged).**
### 3B — Provider aggregation — ✅ DONE (2026-09-08)
- **P0 fix first (user-approved):** 3A's Flutter hotel body (`rooms/minRating/maxPrice/minPrice/amenities`) was REJECTED by the backend ValidationPipe (`forbidNonWhitelisted`) — every hotel search returned HTTP 400. `HotelSearchDto` now declares all five fields (optional, null = unset, range-validated) — pinned by a real-pipe contract spec (`hotel.search.dto.contract.spec.ts`, 4 tests). The 3A report gap was real: it tested the Flutter side only.
- **Partial-failure classification fixed (spec point 12):** providers that RESOLVE with `success:false` (keyless/disabled adapters never throw) were counted as successes; `failures[]` was always empty. Now `success:false` → classified failure with providerId + error.
- **Per-provider timeout (spec point 12):** every fan-out call races a 20s budget (injectable for tests); a hung provider (e.g. Duffel SDK) resolves as a provider-attributed failure instead of blocking the search. Timeout/rejection errors carry `providerId` so failures never lose attribution.
- **Deterministic dedup (spec point 13):** canonical keys per vertical — flight: carrier|flightNumber|departureTime|origin|destination; hotel: providerHotelId else normalized name+city; car: supplier|location|category|title; unknown → provider+id. FIRST provider in registry order wins; same inputs always produce the same list; provider identity preserved verbatim (no merging).
- **Currency/price (O.6):** market display price via the existing PricingService enrichOffer on every offer; provider amount/currency untouched; malformed offers dropped, never invented.
- **Cache discipline (point 44):** cache is now applied to ALL verticals (was flights-only) with short TTL 120s; **partial-failure responses are never cached** (failing provider may recover); cached price ≠ booking truth stays enforced by expiry + /offers/revalidate.
- **User decisions implemented:** hotels = Nuitee-only — duffel-hotel's curated fake catalogue + mock-hotel + mock-flight are OUT of search in BOTH paths (DB-synced registry AND the DB-down legacy fallback; they stay registered for health checks). Flights = Duffel first + **`nuitee-flight` new adapter** (priority-2 fallback row, INACTIVE until admin enables it — admin-panel switching per user decision). The adapter implements the documented legs-based `POST /v3.0/flights/rates` contract (X-API-Key, journeys>offers, pricing.display.total; fixture-tested, no invented endpoints). Cars: deferred (user decision) — no changes.
- **Malformed provider responses:** non-array `data` now aggregates as empty instead of crashing.
- **DB:** `nuitee-flight` row seeded (flight, priority 2 — matches code DEFAULTS, INACTIVE until the admin enables it) via the admin provider panel (`PATCH /admin/providers/nuitee-flight/status {isActive:true}`), same key gate as hotels.
- **Files:** `hotel.search.dto.ts` (contract fix), `search.service.ts` (timeout/partial-failure/dedup/cache rewrite), `nuitee.flight.service.ts` (NEW), `providers.module.ts` + `registry.sync.service.ts` (registration + defaults), `search.aggregation.3b.spec.ts` (NEW, 15), `hotel.search.dto.contract.spec.ts` (NEW, 4).
- **VALIDATION: backend tsc clean; jest 266 passed / 1 skipped / 0 failed (247 → 266: +19, all new tests backend). Flutter untouched by this phase: dart analyze 0 errors (136 infos pre-existing); flutter test = 728 passed / ~6 skipped / 0 failed — the +6 over 3A's 722 comes from the OTHER workstream's parallel WIP files in the shared tree (home_nav_responsive_test.dart etc.), NOT from 3B.**
### 3C — Results + filters + sorting — ✅ DONE (2026-09-08)
- **Audit result:** the Card Engine (FlightSearchCard/HotelSearchCard/CarSearchCard/PackageSearchCard + loading skeletons) already exists and renders the offers — untouched, per spec. The REAL gaps: sorting compared raw PROVIDER amounts (wrong under mixed currencies — Duffel returns USD/EUR/GBP offers in one list), the hotels and cars pages had NO sort/filter UI at all, filtering was ad-hoc inline in the flights page only, and the FilterPanel was a price slider stub.
- **NEW `lib/features/search/application/search_results_processing.dart`** — the unified, deterministic post-processing layer for all verticals:
  - **Customer-total-aware comparisons (spec point 14):** price sorting/filtering uses `customerPrice.customerAmount` (the backend-quoted EGP total) when attached; falls back to the provider amount only when no quote exists. "Cheapest" is now truly the lowest customer total, never a fake cross-currency ranking; mixed-currency unquoted lists stay currency-grouped instead of falsely ranked.
  - **Deterministic + stable:** every comparator ends in an id tie-breaker — same inputs always produce the same order across rebuilds.
  - **"Recommended" = provider order:** an explicit no-op passthrough — the backend's deterministic registry order IS the recommendation; the client never invents one (no AI rerank — the /ai/rerank contract stays unused here as the spec allows).
  - **Provider-safe filters:** pure client-side post-filtering of the already-returned list — nothing re-requested, provider truth never altered. Per-vertical sets: flights (price window, max stops, airlines), hotels (price window, min rating, amenities ANY-match), cars (price window, min seats, transmission).
- **`SearchFilters`** gained `transmission` (cars) with `copyWith`/`isEmpty` updated.
- **`FilterPanel` upgraded** from a price-slider stub to the shared vertical-aware panel (optional sections: stops/airlines for flights, rating/amenities for hotels, seats/transmission for cars) — same visual language, Semantics labels preserved, Reset clears everything.
- **All 3 pages wired:** flights switched its inline ad-hoc filtering to the unified processor; hotels + cars gained the full SortChipsRow (Recommended/Cheapest/Top rated — duration/stops variants stay flights-only where meaningful) + Filters entry + the no-match empty state (filters that hide everything surface an explicit message, never a blank screen; the raw result list stays intact in state).
- **Files:** `search_results_processing.dart` (NEW), `search_filters.dart` (+transmission), `filter_panel.dart` (upgrade), `flight/hotel/car_search_page.dart` (wiring). `sort_utils.dart` KEPT as-is (no-deletion rule; its 2 legacy tests still pass).
- **Tests (`search_results_processing_3c_test.dart`, 16):** customer-total beats provider amount, provider fallback, determinism (id tie-breaker), priceHighLow mirrors priceLowHigh, per-vertical recommended passthrough, duration/stops/rating, every filter matrix per vertical, price filter uses customer total, transmission contract, copyWith merge.
- **VALIDATION: flutter test = 744 passed / ~6 skipped / 0 failed (728 → 744: +16). dart analyze = 0 errors. Backend untouched, re-validated per AGENTS.md: tsc clean + jest 266 passed / 1 skipped / 0 failed (unchanged).**

### SPEC v2.0 COVERAGE AUDIT — integrated 2026-09-08 (from TokiGo_Travel_Providers_Market_Payment_Implementation_Spec_v2.0.pdf)
Comparison of the full 52-point spec + V2.0 addendum against this plan. Most of the spec is already covered by existing phases (verified in code during 3B: provider interfaces/registry/admin switching/MarketContext/FX/PricingEngine/partial-failure all exist). The REAL gaps and where they are absorbed:
1. **Capability model (spec point 2)** → absorbed into 4A: before routing a booking/cancel, the provider's capability descriptor must be checked; unsupported operations return a domain capability error, not a 500. Test: provider lacking cancel cannot serve a cancellation workflow.
2. **Duffel deterministic test-route fixtures (spec point 22)** → absorbed into 4B: PVD→RAI (no flights), JFK→EWR (hold), LHR→DXB (connecting), LTN→STN + SEN→STN (payment scenarios incl. 3DS/insufficient funds); 200/202 async payment treated as recovery cases.
3. **Duffel Egypt payment path (spec O.2)** → absorbed into 4E: Egypt is NOT on Duffel Payments' supported-country list — checkout must route through the Egyptian PSP, TokiGo funds Duffel Balance via bank transfer; never wire Egypt checkout to Duffel Payments.
4. **Nuitee settlement strategy (spec O.3)** → absorbed into 4C: TokiGo-as-Merchant-of-Record (customer pays our PSP → book via ACC_CREDIT_CARD); Nuitee User Payment stays a config-gated alternative; CREDIT line excluded from MVP.
5. **Recovery matrix (spec O.9)** → absorbed into 4A (idempotency + revalidate cover payment-succeeded/booking-unknown etc.) and 8B (observability/reconciliation jobs).
6. **OPEN ITEM (needs user decision — NOT silently added):** the spec's Phase 7 depth — full ledger (double-entry, LedgerEntry sides CUSTOMER/PROVIDER/GATEWAY/WALLET/REFUND/FEE/FX), settlement accounts, reconciliation jobs with mismatch states, refund architecture (points 36-39 + O.8) — is BIGGER than 4E's "Payment + confirmation". Options: (a) extend 4E, (b) add a dedicated phase after 4D, (c) defer to 8B. Default if undecided: implement the 4E slice only (payment ledger entries for each booking/payment/refund) and leave settlement/reconciliation jobs as a documented deferral.
- Cars decision (spec point 30 + user 2026-09-08): mock-car stays behind the CarProvider interface; real vendor integration deferred until sandbox/book/cancel/Egypt/commercial evaluation — no car provider invented.
### 3D — Product details — ✅ DONE (2026-09-09)
- **Contract:** provider-verbatim detail fields per vertical on the unified `OfferDetailsPage`; ABSENT provider fields stay absent — nothing is ever invented. CTA still routes through `/booking/review` (revalidation before booking, spec point 8/44).
- **Backend (adapters carry the verbatim fields in `metadata`):**
  - `nuitee.service.ts` (hotels): `stars` (hotel meta), `boardName`, `taxesAndFees` {amount, currency, included, description} from `retailRate.taxesAndFees[0]` (LIVE-VERIFIED shape: amount=25.69 included=true), `cancellationPolicy` {refundableUntil, feeAmount, feeCurrency, timezone} = the LAST `cancelPolicyInfos` window verbatim (LIVE-VERIFIED: cancelTime 2026-10-13 07:00, amount 623.2 USD), `refundable` from refundableTag.
  - `nuitee.flight.service.ts`: `fareFamily`/`refundable`/`baggage` verbatim (was top-level-only, lost to Flutter).
  - `duffel.service.ts`: `baggage` when Duffel exposes it (absent stays absent).
  - `mock.car.provider.ts` already sent `mileagePolicy`/`cancellationPolicy`/`features` — no backend change needed (consumed now).
- **Flutter `offer_details_page.dart`:**
  - Summary card rows: Flight +Fare/Refundable · Hotel +Stars/Board · Car +Mileage.
  - Content sections: Flight Baggage · Hotel Taxes & fees + Cancellation policy (honest "Non-refundable rate" when no policy windows) · Car Cancellation policy + Features · Package Inclusions (check-list).
  - Sticky CTA gained the honest pricing note "Revalidated at booking" (spec point 44).
- **Tests:** NEW `backend/test/nuitee.details.3d.spec.ts` (4: hotel verbatim passthrough, hotel absent-stays-absent, flight verbatim, flight absent-stays-absent) + NEW `test/features/search/offer_details_3d_test.dart` (7 widget: per-vertical rendering, absent-fields-invent-nothing, CTA→review + pricing note).
- **VALIDATION: backend tsc clean; jest 282 passed / 1 skipped / 0 failed (278 → 282: +4). flutter test = 760 passed / ~6 skipped / 0 failed (753 → 760: +7). dart analyze = 0 errors (142 infos pre-existing).**

## Track E — Booking & payment

### 4A — Booking foundation — PENDING
- Domain model + status lifecycle + repos/use cases; `/bookings/prepare` `/bookings/revalidate` `/bookings`. Never trust Hive snapshot as final price; revalidate before commit; provider identity mandatory; **idempotency mandatory** (no double booking on retry); normalized errors; no payment yet.
### 4B — Flight booking (Doville only) — PENDING
- Search → Details → Revalidate → Passenger → Prepare → Booking → Status. Retry-safe, failure recovery. Tests: expired offer/price change/success/provider failure/duplicate/malformed.
### 4C — Hotel booking (Nuitee) — PENDING
- Search → Details → Room/Rate → Revalidate → Guest → Prepare → Booking → Confirmation. Respect cancellation policy/rate conditions/taxes/occupancy; provider reference.
### 4D — Car + package booking — PENDING
- Real provider only; else domain/contracts WITHOUT fake booking. No invented car provider, no fake inventory.
### 4E — Payment + confirmation — PENDING
- Approved Egyptian gateway ONLY. Intent/session, secure redirect/webview, **server-side verification**, webhook handling, idempotency, payment lifecycle, booking/payment consistency, confirmation screen + reference. NEVER store card/CVV, never log secrets, never trust client callback alone.

## Track F — Trip

### 5A — Unified Trip model — PENDING
- ONE active Trip; unified TripItem (flight/hotel/car/train/activity/transfer) with statuses (planned/booked/cancelled/completed) + provider reference. "+ Add to Trip". Booking confirmation can add items. No live tracking yet.
### 5B — Trip timeline + itinerary — PENDING
- Home/Trip entry: upcoming trip, next item, itinerary, dates, locations, references, actions. Built on TripItem. Premium RTL/LTR. No tracking/notifications/AI actions.
### 5C — Live trip tracking — PENDING
- Provider/status sync ONLY with a real source. Refresh strategy, timestamps, stale marking, graceful failure. UI: Live / Updated X ago / Unavailable. Never invent status.

## Track G — Notifications + Trip AI

### 6A — Notifications — PENDING
- Types: booking confirmation, payment status, trip reminder, schedule/status change, cancellation, travel alert. Backend model, ownership, read/unread, preferences, deep links, Flutter center. No spam/duplicates; no sensitive payload data.
### 6B — Contextual AI travel assistant (in Trip) — PENDING
- Understand current Trip, answer itinerary, suggest ordering, explain bookings — with authorization. AI never invents booking data/prices, never executes booking/payment, sensitive actions via backend contract. Minimal relevant trip context. Explicit memory stays AI-only.
### 6C — Post-booking AI — PENDING
- Trip preparation, reminders, packing, itinerary Qs, disruption explanation, alternatives. Real provider data for commercial recommendations. No auto booking/payment.

## Track H — Home intelligence final

### 7A — Home intelligence finalization — PENDING
- Review full stack (Profile/Behavior/Derived/Geo/Trip/Provider/Recommendation/AI/Cache). Home: cache-first → instant snapshot → background refresh → live validation → quiet update. 2B stays the ranking source.
### 7B — Deals / Discovery — 🔶 7B-SLICE DONE (2026-09-08, user-approved — real hotel rail source)
- **The root cause of the permanently-empty Home (user report 2026-09-08):** the Nuitee-only decision removed the fake sections AND relied on `GET /home/recommended` for the real rail — but the backend route NEVER EXISTED. Every Home open 404'd silently (`loadRecommendedHotels` swallows failures), so the old dev-preview skeleton headings stayed on screen forever. The Flutter side was already complete; the missing piece was the backend.
- **NEW `backend/src/modules/home/home.recommended.service.ts` + `GET /home/recommended?limit=N`:** real hotels from the EXISTING NuiteeService (searchHotels — real names/prices/images, nothing invented). Launch-market defaults (Cairo/EG, tomorrow→+3 nights, 2 guests/1 room) are configuration, not personalization (7A/PH-7 own that). `limit` clamped server-side (1..20). Provider failure or empty inventory → HONEST empty list, never fake hotels. Successful non-empty snapshots cached with a SHORT 5-min TTL (the Home opens constantly — the provider is never hammered); failures are NOT cached. Metadata carries providerId/providerRateId/providerHotelId/refundable/expiresAt for the tap-through + revalidation path. Cached price stays presentation-only (booking truth = /offers/revalidate, spec point 44).
- **Hive/offline unaffected (user question answered):** the Home snapshot mechanism is untouched — offline still renders the last good content; the disk stays the cold-start truth.
- **Files:** `home.recommended.service.ts` (NEW), `home.controller.ts` (+route), `home.module.ts` (+NuiteeModule/CacheModule imports), `test/home.recommended.spec.ts` (NEW, 8: verbatim mapping, failure→empty, empty-inventory, limit clamping both directions, short-TTL caching, failure-not-cached, cache short-circuit, non-number price dropped).
- **BUGFIX (user report 2026-09-09) — "same hotel appears TWICE at different prices":** TWO layers fixed. (a) Adapter root cause: `NuiteeService.searchHotels` emitted one offer PER ROOM TYPE (Standard/Deluxe/Suite as separate cards) though its own comment claimed "cheapest rate per hotel" — no dedup ever ran. Fix in `nuitee.service.ts`: exactly ONE offer per hotel (the cheapest available room, `providerRateId` of that room preserved for prebook), cheapest-first order. (b) Defense in depth in `home.recommended.service.ts`: dedup by `metadata.providerHotelId` (fallback offer id) BEFORE the limit slice — the rail can never show one hotel twice even if the adapter regresses. Room-level detail remains reachable via the provider on the details/prebook path (rateId survives). Regression: NEW `test/nuitee.adapter.dedup.spec.ts` (3: same-hotel 2 room types → 1 cheapest offer; distinct hotels keep their own; cheapest rate within one room type) + 1 new defense-in-depth case in `home.recommended.spec.ts` (duplicate providerHotelId never reaches the rail); the limit-clamp fixture now uses two DISTINCT hotels (the old fixture accidentally used the same providerHotelId twice — caught by the new guard).
- **Flutter side (same fix, honest empty):** `home_controller.dart` empty-feed branch now publishes `HomeStatus.empty` with ZERO sections (see the H1 update above for the full removal of the dev-preview) and `loadRecommendedHotels` upgrades `empty→success` when the real rail lands; `home_page.dart` gained the honest no-content state (icon + message + Retry). 3 existing controller tests updated to the new contract.
- **VALIDATION (after the dedup bugfix): backend tsc clean; jest 278 passed / 1 skipped / 0 failed (274 → 278: +4 — 3 adapter-dedup regressions + 1 defense-in-depth). flutter test = 753 passed / ~6 skipped / 0 failed (752 → 753: +3 new widget tests, -2 rewritten; unchanged by the dedup fix — backend-only). dart analyze = 0 errors.**
- Remaining 7B scope (other real sections: Deals/Destinations/Flights/Cars/Packages) stays PENDING as planned — this slice only closed the missing hotel-rail source.

## Track I — Ops, audits, release

### 8A — Admin operational hardening — PENDING (CRUD validation, authorization, audit trail, safe status changes, input sanitization; admin can never bypass provider truth)
### 8B — Provider health & observability — PENDING (health checks, timeout metrics, error classification, latency, status, correlation IDs; no sensitive logging)
### 9A — Security & reliability audit — PENDING (authz, IDOR, prompt injection, memory poisoning, webhook replay, booking/payment duplication, sensitive logging, malformed provider responses)
- **PROPOSAL P4 (needs approval):** structure the audit as an **OWASP MASVS** checklist (STORAGE/CRYPTO/AUTH/NETWORK/PLATFORM/CODE/RESILIENCE/PRIVACY categories) + regression test per finding.
### 9B — Performance & cache hardening — PENDING (no duplicate requests/AI calls, no N+1, instant Home preserved, background refresh never blocks first paint; measure before/after)
### 10A — Full E2E regression — PENDING (all journeys in spec; fix defects only)
- **PROPOSAL P3 (needs approval):** add an official `integration_test` suite (dev-dependency — needs approval) for the 16 journeys; runs on device/emulator.
### 10B — Production readiness audit — PENDING (env, secrets, migrations, indexes, CORS, rate limits, monitoring, webhooks, backups, Android/iOS release settings, RTL/LTR, accessibility, offline behavior; PASS/FAIL/BLOCKED checklist)
### 10C — Final release gate — PENDING (tsc+jest, analyze+test, git/diff review, no debug code/secrets/test endpoints; final counts + release-ready verdict)

---

# Agreed execution order (MERGED — dependencies resolved)

```
M0 → H1 → H2 → H3 → [US-2 lands (theirs) → validate+merge] → NAV
→ 2C-C1 → 2C-C2 → 2D
→ US-3 → US-4
→ 3A → 3B → 3C → 3D
→ US-5 → US-6
→ PH-7 (Explicit Memory → Home Ranking)
→ 4A → 4B → 4C → 4D → 4E
→ 5A → 5B → 5C
→ 6A → 6B → 6C
→ 7A → 7B
→ US-7 (search hardening — after all search work)
→ 8A → 8B → 9A → 9B → 10A → 10B → 10C
```

**Ordering rationale (flags for user review):**
1. NAV waits for US-2 landing (shared router; US contract requires root/branch nav intact).
2. US-3/US-4 before 3A-3D: US-3 (voice) is client-side; US-4 (AI assistant) rides the existing intent pipeline — both independent of backend aggregation.
3. US-5/US-6 AFTER 3A-3D: personalization & compare/refinement consume the unified search contracts.
4. PH-7 after US-5: US-5 explicitly defers memory→ranking to the approved phase — that IS PH-7.
5. US-7 after 7B: harden search only when all search-consuming phases are final.

# DECISIONS (ALL APPROVED by user 2026-09-07 — no longer pending)

| # | Proposal | Phase affected | Status |
|---|---|---|---|
| P1 | `speech_to_text` package for US-3 voice (community standard, Android/iOS/web, AR+EN) | US-3 | ✅ APPROVED — install when US-3 starts |
| P2 | `ResizeImage`/`cacheWidth` decode in H3 image cache (official Flutter guidance — big memory win, no package) | H1/H3 | ✅ APPROVED + IMPLEMENTED (H3) |
| P3 | Official `integration_test` dev-dependency for 10A E2E journeys | 10A | ✅ APPROVED — install when 10A starts |
| P4 | Structure 9A as OWASP MASVS category checklist | 9A | ✅ APPROVED |
| P5 | Android 14 predictive back (`PopScope.canPop`) verification in US-7 + 9B audits | US-7, 9B | ✅ APPROVED |
| P6 | The merged execution order (NAV after US-2; US-5/US-6 after 3A-3D) | All | ✅ APPROVED — order is final |

External packages are allowed with per-case confirmation (user policy 2026-09-06).

# Files changed by the Home/Platform workstream (uncommitted, 2026-09-06)

- `lib/core/repositories/contracts/home_repository.dart` — `clearHomeSnapshot` contract
- `lib/core/repositories/impl/home_repository_impl.dart` — empty feed authoritative; `clearHomeSnapshot`; `@override`
- `lib/features/home/presentation/home_controller.dart` — empty feed → preview + snapshot drop; hotels flip preview→success
- `test/features/home/home_controller_test.dart` (+3 Nuitee-only tests), `test/features/home/live_validation_test.dart`, `test/core/repositories/home_fallback_test.dart`
- **Postgres:** 10 cards + 4 fake sections DELETED (tables now 0 rows). `backend/scripts/seed-home.js` kept intact (card system reserved).
