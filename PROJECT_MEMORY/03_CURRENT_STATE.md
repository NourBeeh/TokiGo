# WeTravellers — CURRENT STATE

## 2026-10-17 — Stabilization checkpoint (AUTHORITATIVE)

- **No `git` repo existed** at project start. Initialized `git` (branch `main`) + root `.gitignore`; first snapshot commit `6c3823e` (651 files). Excluded: `.env`, `backend/node_modules`, `build/`, `.dart_tool/`, `backend/test-nuitee.ts`, Hive runtime data.
- **Verified baseline (2026-10-17):**
  - `flutter test` → **777 passed / 6 skipped / 0 failed**
  - `dart analyze lib test` → **0 errors / 0 warnings** (148 infos, pre-existing)
  - backend `npx tsc --noEmit` → **clean**
  - backend `npx jest` → **282 passed / 1 skipped / 0 failed**
- **Undocumented work found in the tree (2026-10-16 → 17, memory had stopped at 2026-09-09):**
  - Home smart AI search pill became a real editable `TextField` (typewriter hint, rotating aura border, Hero handoff) → submits to `/ai-chat`, leading sparkle opens `/smart-search` (`lib/features/home/presentation/widgets/home_ai_search_field.dart`).
  - TokiGo wordmark ("Toki" grey + pulsing red "Go") in the Home header (`home_page.dart`).
  - Navigation-shell fix: removed the custom branch `navigatorKey` that triggered "Duplicate GlobalKey (_BranchNavigatorProxy / StatefulShellBranch)" (`lib/app/router/go_router_config.dart`, `lib/app/shell.dart`).
  - Edits to `universal_search_page.dart`, `ai_chat_page.dart`; l10n regenerated (127 keys en/ar).
- **Stabilization fixes applied:**
  - `test/navigation/go_router_shell_test.dart` — harness routes now absolute (`/flights`, `/booking/review`, `/search`), page assertion `findsWidgets`, back via `tester.pageBack()`.
  - `test/features/home/presentation/widgets/home_ai_search_field_test.dart` — rewrote the Enter (keyboard send action), duplicate-prevention (offstage pill + cleared field), and Arabic-locale tests; split the sparkle→smart-search navigation into a router-backed test; removed the unused focus harness.
  - `backend/test/memory.spec.ts` — deterministic `updatedAt` timestamps (tied `new Date()` made the newest-first listing flaky).
- **New requirement (unimplemented — user 2026-10-17, `Documents/زرار GO عند الضغط عليه.txt`):** **GO button** starts/continues a trip — auto current country via geo → choose destination or ask AI for ideas → resume a saved/external trip, continue an existing hotel, or navigation-only with full service guidance; plus continuously updated travel/visa requirements and **VISA INDEX**. Not part of any phase yet.
- **Resume point:** per `MASTER_PLAN.md` the next pending phase is **US-5** (search personalization) → US-6 → PH-7 → 4A–4E, unless the user prioritizes the new GO-button / trip-start feature.

---

## Last known checkpoint (superseded — 2026-09-07)
**Home & Platform workstream M0–H3 complete; Universal Search US-2 in progress by the sibling agent; everything below was validated by direct runs.**

### Verified baseline (2026-09-07)
- `flutter test` **647 passed / ~6 skipped / 0 failed**
- `dart analyze lib test` **0 errors** (~138 infos/warnings pre-existing, mostly US-2 WIP files — reported, not fixed)
- Backend `tsc --noEmit` **clean**
- Backend `npx jest` **232 passed / 1 skipped / 0 failed**
- Postgres (`wetravellers-postgres` docker, PG16): `home_sections` 0 rows, `home_cards` 0 rows (fake seed purged 2026-09-06). **NEVER run `npm run seed:home`.**

### Workstream 1 — Home & Platform (COMPLETE for now; spec = `MASTER_PLAN.md`)
- **M0:** Nuitee-only Home — empty feed authoritative; legacy `home|sections` cache never resurrected; audience v2 snapshots dropped on empty feed (`HomeRepository.clearHomeSnapshot`); hotels arrival flips dev-preview → success.
- **H1:** pull-to-refresh REMOVED (`RefreshIndicator` + controller `refresh()`); `_SkeletonRecommendedRail`/`_SkeletonHotelCard` mirror the real rail geometry exactly (fixed title, 220px, 260px cards); `_developmentPreviewSections()` kept (no-deletion rule).
- **H2:** `HomeController.refreshPrices()` → `_runLiveValidation()` ONLY. `HomePage` = `ConsumerStatefulWidget` + `WidgetsBindingObserver` (resume) + GoRouter delegate listener (return to '/') — lazy hook via `GoRouter.maybeOf`, router ref saved for dispose. Tests: `h2_refresh_prices_test.dart`.
- **H3:** `lib/features/home/application/hotel_image_cache.dart` — LRU(30)/TTL(7d) byte cache on the shared OfflineCache box (`hotel_image|<url>` keys); `lib/features/home/presentation/widgets/cached_hotel_image.dart` — shimmer → shared per-URL fetch → store → decode with P2 `cacheWidth` (ResizeImage at display res); wired into `_HotelCard` + `hotelImageCacheProvider`. Tests: `h3_hotel_image_cache_test.dart` (11). **Test-env lesson: never `pumpAndSettle` under a live shimmer — fixed pump loops.**
- **NOT committed yet** (see Git below).

### Workstream 2 — Universal Search (sibling agent; spec = `UNIVERSAL SEARCH MASTER.txt`)
- US-0 ✅ (contract `docs/universal-search-ux-contract.md`), US-1 ✅ + US-1-Final ✅ (commit 794ebcb9, legacy v1 deleted — the single approved deletion).
- **US-2 ⏳ in progress uncommitted** (parser `_isNumericFragment`/budget/months; `StructuredTravelIntent` rooms/budget/minStars/amenities; gap chips `fillGap`; ~60 tests). Files owned by them: `lib/features/universal_search/**`, `lib/features/ai/{data,application,search_intent_parser,ai_chat_page,ai_visual_shell_page}`, `backend/src/modules/{ai,events,profile-edges}`, AI DTOs, `test/features/universal_search/**` + their AI test edits.
- **NAV (remove bottom nav → Home-centric buttons) is blocked until US-2 lands** (shared router).

### Memory Spine (backend, from 2C phases)
- `modules/memory/` + `user_memory.entity.ts` + `memory.dto.ts`: JWT-owned CRUD `/memory/me` (+ POST/PATCH/DELETE/clear). `POST /ai/chat` (`ai.conversation.controller.ts`): the ONLY surface where explicit memories reach the AI; selector/extraction failures swallowed; personalization-disabled → plain behavior. `POST /ai/rerank` + Flutter `ai_rerank_client.dart` (id-validated, optional).
- Flutter 2A: `lib/core/memory/` MemoryRepository + tests green. **2C-C1 (Flutter /ai/chat wiring) NOT started — next after NAV.**

### Repo-root documents (read order)
1. `MASTER_PLAN.md` — merged plan M0→10C + boundaries + PENDING DECISIONS (P1/P3-P6 open; P2 approved).
2. `محرك التوصيات.txt` — memory/AI/search/booking/trip track specs.
3. `UNIVERSAL SEARCH MASTER.txt` — search track specs (US-0→US-7).
4. `AGENTS.md` — project rules. 5. `PROJECT_MEMORY/` — this system.

### Git (at this checkpoint)
- 7 local commits ahead of origin/main (latest: 794ebcb9 universal-search legacy removal) + ALL M0–H3 work UNCOMMITTED in the tree alongside the sibling agent's US-2 WIP.
- Commit/push only on explicit user instruction; commits must be scoped per workstream.

### Standing warnings
- `backend/test-nuitee.ts` — never modify/delete/commit. `.env` never read/printed/committed.
- Do NOT run `npm run seed:home`.
- Security gap: `/api/duffel/create-booking` unguarded + `any[]` DTO — gate before any non-localhost exposure.

---

# Historical checkpoints (superseded — kept for reference)

## 2026-09-06 — project memory system refreshed
`PROJECT_MEMORY/` rewritten to the two-workstream state (see `04_PHASE_HISTORY.md` addendum 2026-09-06). Verified baseline then: 633/232.

## 2026-09-03 — Phase 0 stabilization (R-4 verified, AI single-provider)
Geo/Profile/Events/Recommend modules; AI mock/fallback deleted; Nuitee fixtures coverage lost (known debt). Baseline 437/134. Full detail: `04_PHASE_HISTORY.md`.

## 2026-09-02 — Admin workstream (4 unpushed commits: f95cecf2, b41ae2f4, 7344acd2, bf3335d1)
`/admin/home/*` CRUD + audit + publication windows; DB provider registry runtime switching; Flutter `/admin` panel. Full detail: `04_PHASE_HISTORY.md`.

## 2026-09-02 — Waves W0–W3
Light-only UI rebuild, real providers (Nuitee LIVE, Duffel revalidate, MarketContext EG/EGP), search/home rebuild, booking funnel + MockEgyptGateway payments.

## Earlier (2026-08-26 and before)
AI chat overhaul; card system Stage 2; Phases 1–17. See `04_PHASE_HISTORY.md`.
---
## Automatic Git Sync
- Branch: main
- Last sync before commit
- Repository status captured automatically

### Recent commits
```
794ebcb9 (HEAD -> main) chore(universal-search): remove legacy v1 search page
b4317d8d chore(phase0): stabilize single-provider tests and document r4
dd0b11e5 feat(personalization): geo profile events recommend modules and ai single-provider
f95cecf2 fix(admin): seed-admin camelCase columns + role in /auth/me
b41ae2f4 fix(providers): restore NuiteeService export dropped in ADM-B1 rewrite
7344acd2 feat(admin): admin panel - home content management + runtime provider switching
bf3335d1 feat(app): full UI rebuild, real travel providers, and booking/payment foundation (Waves 0-3)
66a80f94 (origin/main, origin/HEAD) feat(project): add automatic git sync and update state documentation
b7f3f985 feat(cards): shared card design system (Stage 2) + redesign, audit, and memory sync
bf6cc0ea feat(ai): full-screen AI chat page with conversation history and auto-expiry
```

### Pending status
```
 M PROJECT_MEMORY/01_MASTER_MEMORY.md
 M PROJECT_MEMORY/02_AGENT_MEMORY.md
 M PROJECT_MEMORY/03_CURRENT_STATE.md
 M PROJECT_MEMORY/04_PHASE_HISTORY.md
 M PROJECT_MEMORY/08_NEXT_STEPS.md
 M PROJECT_MEMORY/README.md
 M backend/src/app.module.ts
 M backend/src/common/dto/ai.dto.ts
 M backend/src/modules/ai/ai.controller.ts
 M backend/src/modules/ai/ai.module.ts
 M backend/src/modules/ai/ai.provider.ts
 M backend/src/modules/ai/ai.service.ts
 M backend/src/modules/ai/openai.ai.provider.ts
 M backend/src/modules/events/events.module.ts
 M backend/src/modules/events/events.service.ts
 M backend/src/modules/profile/profile.controller.ts
 M backend/src/modules/profile/profile.module.ts
 M lib/app/config/app_config.dart
M  lib/core/repositories/contracts/home_repository.dart
M  lib/core/repositories/impl/home_repository_impl.dart
 M lib/core/storage/hive_offline_cache.dart
 M lib/core/storage/offline_cache.dart
 M lib/features/ai/application/ai_providers.dart
 M lib/features/ai/data/ai_api_service.dart
 M lib/features/ai/domain/search_intent_parser.dart
 M lib/features/ai/presentation/pages/ai_chat_page.dart
 M lib/features/ai/presentation/pages/ai_visual_shell_page.dart
 M lib/features/bag/presentation/pages/trip_details_page.dart
 M lib/features/booking/presentation/pages/booking_confirmation_page.dart
A  lib/features/home/application/home_live_validation_service.dart
A  lib/features/home/application/home_personalization_orchestrator.dart
A  lib/features/home/application/hotel_image_cache.dart
A  lib/features/home/application/local_behavior_store.dart
A  lib/features/home/application/recommendation_service.dart
A  lib/features/home/domain/home_composer.dart
A  lib/features/home/domain/home_greeting.dart
A  lib/features/home/domain/personalization_context.dart
M  lib/features/home/presentation/home_controller.dart
M  lib/features/home/presentation/pages/home_page.dart
A  lib/features/home/presentation/widgets/cached_hotel_image.dart
M  lib/features/home/providers/home_providers.dart
 M lib/features/search/application/controllers/hotel_search_controller.dart
 M lib/features/search/application/providers/hotel_car_providers.dart
 M lib/features/search/presentation/pages/hotel_search_page.dart
 M lib/features/search/presentation/pages/offer_details_page.dart
 M lib/features/universal_search/application/universal_search_controller.dart
 M lib/features/universal_search/application/universal_search_state.dart
 M lib/features/universal_search/domain/structured_travel_intent.dart
 M lib/features/universal_search/presentation/pages/universal_search_page.dart
 M lib/features/universal_search/presentation/widgets/universal_search_widgets.dart
 M lib/shared/widgets/placeholder_page.dart
 M test/core/repositories/home_fallback_test.dart
 M test/features/ai/presentation/pages/ai_chat_page_test.dart
A  test/features/home/derived_preferences_test.dart
A  test/features/home/h2_refresh_prices_test.dart
A  test/features/home/h3_hotel_image_cache_test.dart
A  test/features/home/home_composer_test.dart
M  test/features/home/home_controller_test.dart
A  test/features/home/live_validation_test.dart
A  test/features/home/personalization_spine_test.dart
A  test/features/home/presentation/pages/home_skeleton_rail_test.dart
 M test/features/universal_search/universal_search_controller_test.dart
 M test/features/universal_search/universal_search_page_test.dart
?? AGENTS.md
?? MASTER_PLAN.md
?? "UNIVERSAL SEARCH MASTER.txt"
?? backend/src/common/dto/ai.rerank.dto.ts
?? backend/src/common/dto/memory.dto.ts
?? backend/src/database/entities/user_memory.entity.ts
?? backend/src/modules/ai/ai.conversation.controller.ts
?? backend/src/modules/ai/ai.conversation.module.ts
?? backend/src/modules/ai/ai.rerank.controller.ts
?? backend/src/modules/memory/
?? backend/test-nuitee.ts
?? backend/test/ai.chat.memory-context.spec.ts
?? backend/test/ai.rerank.spec.ts
?? backend/test/ai.suggest.spec.ts
?? backend/test/behavioral_memory.spec.ts
?? backend/test/conversation_memory.spec.ts
?? backend/test/memory.spec.ts
?? lib/core/ai/ai_rerank_client.dart
?? lib/core/events/
?? lib/core/geo/
?? lib/core/memory/
?? lib/core/profile/
?? test/core/memory/
?? test/features/ai/domain/
?? test/features/universal_search/structured_travel_intent_us2_test.dart
?? "\331\205\330\255\330\261\331\203 \330\247\331\204\330\252\331\210\330\265\331\212\330\247\330\252.txt"
```
---
## Automatic Git Sync
- Branch: main
- Last sync before commit
- Repository status captured automatically

### Recent commits
```
0f058e8b (HEAD -> main) feat(home): Nuitee-only Home — instant skeleton rail, price-only refresh, Hive image cache (M0-H3)
794ebcb9 chore(universal-search): remove legacy v1 search page
b4317d8d chore(phase0): stabilize single-provider tests and document r4
dd0b11e5 feat(personalization): geo profile events recommend modules and ai single-provider
f95cecf2 fix(admin): seed-admin camelCase columns + role in /auth/me
b41ae2f4 fix(providers): restore NuiteeService export dropped in ADM-B1 rewrite
7344acd2 feat(admin): admin panel - home content management + runtime provider switching
bf3335d1 feat(app): full UI rebuild, real travel providers, and booking/payment foundation (Waves 0-3)
66a80f94 (origin/main, origin/HEAD) feat(project): add automatic git sync and update state documentation
b7f3f985 feat(cards): shared card design system (Stage 2) + redesign, audit, and memory sync
```

### Pending status
```
A  AGENTS.md
A  MASTER_PLAN.md
A  "UNIVERSAL SEARCH MASTER.txt"
M  backend/src/app.module.ts
M  backend/src/common/dto/ai.dto.ts
A  backend/src/common/dto/ai.rerank.dto.ts
A  backend/src/common/dto/memory.dto.ts
A  backend/src/database/entities/user_memory.entity.ts
M  backend/src/modules/ai/ai.controller.ts
A  backend/src/modules/ai/ai.conversation.controller.ts
A  backend/src/modules/ai/ai.conversation.module.ts
M  backend/src/modules/ai/ai.module.ts
M  backend/src/modules/ai/ai.provider.ts
A  backend/src/modules/ai/ai.rerank.controller.ts
M  backend/src/modules/ai/ai.service.ts
M  backend/src/modules/ai/openai.ai.provider.ts
M  backend/src/modules/events/events.module.ts
M  backend/src/modules/events/events.service.ts
A  backend/src/modules/memory/behavioral_facts.ts
A  backend/src/modules/memory/behavioral_memory.service.ts
A  backend/src/modules/memory/conversation_facts.ts
A  backend/src/modules/memory/conversation_memory.service.ts
A  backend/src/modules/memory/derived_preference_profile.service.ts
A  backend/src/modules/memory/memory.controller.ts
A  backend/src/modules/memory/memory.module.ts
A  backend/src/modules/memory/memory.service.ts
A  backend/src/modules/memory/relevant_memory_selector.ts
M  backend/src/modules/profile/profile.controller.ts
M  backend/src/modules/profile/profile.module.ts
A  backend/test-nuitee.ts
A  backend/test/ai.chat.memory-context.spec.ts
A  backend/test/ai.rerank.spec.ts
A  backend/test/ai.suggest.spec.ts
A  backend/test/behavioral_memory.spec.ts
A  backend/test/conversation_memory.spec.ts
A  backend/test/memory.spec.ts
M  lib/app/config/app_config.dart
A  lib/core/ai/ai_rerank_client.dart
A  lib/core/events/events_tracker.dart
A  lib/core/geo/geo_client.dart
A  lib/core/memory/derived_preference_profile.dart
A  lib/core/memory/memory_model.dart
A  lib/core/memory/memory_repository.dart
A  lib/core/memory/memory_repository_impl.dart
A  lib/core/profile/profile_repository.dart
M  lib/core/storage/hive_offline_cache.dart
M  lib/core/storage/offline_cache.dart
M  lib/features/ai/application/ai_providers.dart
M  lib/features/ai/data/ai_api_service.dart
M  lib/features/ai/domain/search_intent_parser.dart
M  lib/features/ai/presentation/pages/ai_chat_page.dart
M  lib/features/ai/presentation/pages/ai_visual_shell_page.dart
M  lib/features/bag/presentation/pages/trip_details_page.dart
M  lib/features/booking/presentation/pages/booking_confirmation_page.dart
M  lib/features/search/application/controllers/hotel_search_controller.dart
M  lib/features/search/application/providers/hotel_car_providers.dart
M  lib/features/search/presentation/pages/hotel_search_page.dart
M  lib/features/search/presentation/pages/offer_details_page.dart
M  lib/features/universal_search/application/universal_search_controller.dart
M  lib/features/universal_search/application/universal_search_state.dart
M  lib/features/universal_search/domain/structured_travel_intent.dart
M  lib/features/universal_search/presentation/pages/universal_search_page.dart
M  lib/features/universal_search/presentation/widgets/universal_search_widgets.dart
M  lib/shared/widgets/placeholder_page.dart
A  test/core/memory/memory_repository_test.dart
M  test/core/repositories/home_fallback_test.dart
A  test/features/ai/domain/search_intent_parser_us2_test.dart
M  test/features/ai/presentation/pages/ai_chat_page_test.dart
A  test/features/universal_search/structured_travel_intent_us2_test.dart
M  test/features/universal_search/universal_search_controller_test.dart
M  test/features/universal_search/universal_search_page_test.dart
A  "\331\205\330\255\330\261\331\203 \330\247\331\204\330\252\331\210\330\265\331\212\330\247\330\252.txt"
```
---
## Automatic Git Sync
- Branch: main
- Last sync before commit
- Repository status captured automatically

### Recent commits
```
9a5793c2 (HEAD -> main, origin/main, origin/HEAD) feat(memory+search): memory spine backend, AI chat/rerank endpoints, and Universal Search US-2 work
0f058e8b feat(home): Nuitee-only Home — instant skeleton rail, price-only refresh, Hive image cache (M0-H3)
794ebcb9 chore(universal-search): remove legacy v1 search page
b4317d8d chore(phase0): stabilize single-provider tests and document r4
dd0b11e5 feat(personalization): geo profile events recommend modules and ai single-provider
f95cecf2 fix(admin): seed-admin camelCase columns + role in /auth/me
b41ae2f4 fix(providers): restore NuiteeService export dropped in ADM-B1 rewrite
7344acd2 feat(admin): admin panel - home content management + runtime provider switching
bf3335d1 feat(app): full UI rebuild, real travel providers, and booking/payment foundation (Waves 0-3)
66a80f94 feat(project): add automatic git sync and update state documentation
```

### Pending status
```
M  MASTER_PLAN.md
```
---
## Automatic Git Sync
- Branch: main
- Last sync before commit
- Repository status captured automatically

### Recent commits
```
6b08636b (HEAD -> main, origin/main, origin/HEAD) docs(plan): all pending decisions P1-P6 approved by owner — order finalized
9a5793c2 feat(memory+search): memory spine backend, AI chat/rerank endpoints, and Universal Search US-2 work
0f058e8b feat(home): Nuitee-only Home — instant skeleton rail, price-only refresh, Hive image cache (M0-H3)
794ebcb9 chore(universal-search): remove legacy v1 search page
b4317d8d chore(phase0): stabilize single-provider tests and document r4
dd0b11e5 feat(personalization): geo profile events recommend modules and ai single-provider
f95cecf2 fix(admin): seed-admin camelCase columns + role in /auth/me
b41ae2f4 fix(providers): restore NuiteeService export dropped in ADM-B1 rewrite
7344acd2 feat(admin): admin panel - home content management + runtime provider switching
bf3335d1 feat(app): full UI rebuild, real travel providers, and booking/payment foundation (Waves 0-3)
```

### Pending status
```
M  MASTER_PLAN.md
M  lib/app/router/go_router_config.dart
M  lib/app/shell.dart
A  lib/app/widgets/home_nav_buttons.dart
M  lib/features/home/presentation/pages/home_page.dart
M  test/app/full_app_smoke_test.dart
M  test/app/widgets/bottom_nav_branch_mapping_test.dart
M  test/features/home/presentation/pages/home_skeleton_rail_test.dart
```
---
## Automatic Git Sync
- Branch: main
- Last sync before commit
- Repository status captured automatically

### Recent commits
```
d72a93e5 (HEAD -> main, origin/main, origin/HEAD) feat(nav): Home-centric navigation — bottom bar removed, verticals as Home buttons
6b08636b docs(plan): all pending decisions P1-P6 approved by owner — order finalized
9a5793c2 feat(memory+search): memory spine backend, AI chat/rerank endpoints, and Universal Search US-2 work
0f058e8b feat(home): Nuitee-only Home — instant skeleton rail, price-only refresh, Hive image cache (M0-H3)
794ebcb9 chore(universal-search): remove legacy v1 search page
b4317d8d chore(phase0): stabilize single-provider tests and document r4
dd0b11e5 feat(personalization): geo profile events recommend modules and ai single-provider
f95cecf2 fix(admin): seed-admin camelCase columns + role in /auth/me
b41ae2f4 fix(providers): restore NuiteeService export dropped in ADM-B1 rewrite
7344acd2 feat(admin): admin panel - home content management + runtime provider switching
```

### Pending status
```
M  MASTER_PLAN.md
A  lib/features/ai/application/ai_chat_providers.dart
A  lib/features/ai/data/ai_chat_repository.dart
A  lib/features/ai/data/ai_chat_repository_impl.dart
A  test/features/ai/data/ai_chat_repository_test.dart
```
---
## Automatic Git Sync
- Branch: main
- Last sync before commit
- Repository status captured automatically

### Recent commits
```
89adc1a8 (HEAD -> main, origin/main, origin/HEAD) feat(ai): 2C-C1 — Flutter wiring for POST /ai/chat (conversation memory endpoint)
d72a93e5 feat(nav): Home-centric navigation — bottom bar removed, verticals as Home buttons
6b08636b docs(plan): all pending decisions P1-P6 approved by owner — order finalized
9a5793c2 feat(memory+search): memory spine backend, AI chat/rerank endpoints, and Universal Search US-2 work
0f058e8b feat(home): Nuitee-only Home — instant skeleton rail, price-only refresh, Hive image cache (M0-H3)
794ebcb9 chore(universal-search): remove legacy v1 search page
b4317d8d chore(phase0): stabilize single-provider tests and document r4
dd0b11e5 feat(personalization): geo profile events recommend modules and ai single-provider
f95cecf2 fix(admin): seed-admin camelCase columns + role in /auth/me
b41ae2f4 fix(providers): restore NuiteeService export dropped in ADM-B1 rewrite
```

### Pending status
```
M  MASTER_PLAN.md
A  "TOKI AI.png"
M  android/app/src/main/AndroidManifest.xml
M  backend/src/common/dto/hotel.search.dto.ts
M  backend/src/common/dto/memory.dto.ts
M  backend/src/modules/ai/ai.conversation.controller.ts
M  backend/src/modules/duffel/duffel.service.ts
M  backend/src/modules/home/home.controller.ts
M  backend/src/modules/home/home.module.ts
A  backend/src/modules/home/home.recommended.service.ts
M  backend/src/modules/memory/conversation_facts.ts
M  backend/src/modules/memory/memory.service.ts
A  backend/src/modules/nuitee/nuitee.flight.service.ts
M  backend/src/modules/nuitee/nuitee.service.ts
M  backend/src/modules/providers/providers.module.ts
M  backend/src/modules/providers/registry.sync.service.ts
M  backend/src/modules/providers/search.service.ts
A  backend/test/ai.context-hardening.spec.ts
A  backend/test/home.recommended.spec.ts
A  backend/test/hotel.search.dto.contract.spec.ts
A  backend/test/nuitee.adapter.dedup.spec.ts
A  backend/test/nuitee.details.3d.spec.ts
A  backend/test/search.aggregation.3b.spec.ts
M  ios/Runner/Info.plist
M  lib/app/config/app_config.dart
M  lib/app/router/go_router_config.dart
M  lib/app/widgets/home_nav_buttons.dart
M  lib/core/repositories/impl/hotel_repository_impl.dart
M  lib/core/theme/app_colors.dart
A  lib/features/ai/application/ai_chat_guest_only_cache.dart
A  lib/features/ai/application/ai_chat_page_providers.dart
A  lib/features/ai/application/ai_chat_service_adapter.dart
A  lib/features/ai/application/explicit_memory_controller.dart
A  lib/features/ai/application/memory_controls_providers.dart
A  lib/features/ai/domain/explicit_memory_view.dart
M  lib/features/ai/presentation/pages/ai_chat_page.dart
A  lib/features/ai/presentation/pages/ai_memory_page.dart
M  lib/features/ai/presentation/pages/ai_visual_shell_page.dart
M  lib/features/bag/presentation/pages/trip_details_page.dart
M  lib/features/booking/presentation/pages/booking_confirmation_page.dart
A  lib/features/home/application/hotel_image_memory_cache.dart
M  lib/features/home/presentation/home_controller.dart
M  lib/features/home/presentation/pages/home_page.dart
M  lib/features/home/presentation/widgets/cached_hotel_image.dart
M  lib/features/home/presentation/widgets/home_ai_search_field.dart
M  lib/features/home/providers/home_providers.dart
M  lib/features/search/application/controllers/car_search_controller.dart
M  lib/features/search/application/controllers/flight_search_controller.dart
M  lib/features/search/application/controllers/hotel_search_controller.dart
A  lib/features/search/application/search_results_processing.dart
M  lib/features/search/domain/search_filters.dart
M  lib/features/search/presentation/pages/car_search_page.dart
M  lib/features/search/presentation/pages/flight_search_page.dart
M  lib/features/search/presentation/pages/hotel_search_page.dart
M  lib/features/search/presentation/pages/offer_details_page.dart
M  lib/features/search/presentation/widgets/filter_panel.dart
M  lib/features/universal_search/application/universal_search_controller.dart
A  lib/features/universal_search/application/voice_search_controller.dart
A  lib/features/universal_search/application/voice_search_providers.dart
A  lib/features/universal_search/application/voice_search_state.dart
A  lib/features/universal_search/data/speech_to_text_voice_service.dart
M  lib/features/universal_search/domain/structured_travel_intent.dart
A  lib/features/universal_search/domain/voice_search_service.dart
M  lib/features/universal_search/presentation/pages/universal_search_page.dart
M  lib/features/universal_search/presentation/widgets/universal_search_widgets.dart
M  lib/l10n/app_ar.arb
M  lib/l10n/app_en.arb
M  lib/l10n/app_localizations.dart
M  lib/l10n/app_localizations_ar.dart
M  lib/l10n/app_localizations_en.dart
M  lib/shared/widgets/placeholder_page.dart
M  pubspec.lock
M  pubspec.yaml
A  test/app/home_nav_responsive_test.dart
A  test/features/ai/application/ai_chat_guest_only_cache_test.dart
A  test/features/ai/application/explicit_memory_controller_test.dart
A  test/features/ai/domain/explicit_memory_view_test.dart
M  test/features/ai/presentation/pages/ai_chat_page_test.dart
A  test/features/ai/presentation/pages/ai_memory_page_test.dart
A  test/features/home/cached_hotel_image_infinity_regression_test.dart
M  test/features/home/home_controller_test.dart
A  test/features/home/hotel_image_scroll_reload_regression_test.dart
M  test/features/home/presentation/pages/home_skeleton_rail_test.dart
A  test/features/home/presentation/widgets/ai_search_typewriter_test.dart
A  test/features/search/offer_details_3d_test.dart
A  test/features/search/search_foundation_3a_test.dart
A  test/features/search/search_results_processing_3c_test.dart
A  test/features/universal_search/ai_assistant_us4_test.dart
A  test/features/universal_search/application/voice_search_controller_test.dart
M  test/features/universal_search/universal_search_page_test.dart
?? session-20260908.json
```
