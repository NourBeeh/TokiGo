# TokiGo — NEXT STEPS

## Integrated delivery roadmap

> **CURRENT POSITION (2026-10-17 — latest):** App identity renamed to **TokiGo** (`wetravellers`→`tokigo`, package `tokigo`, bundle `com.tokigo.tokigo`) — commit `1672b5fb` pushed to `origin/main`; re-validated green (analyze 0 err/warn, Flutter 777 passed / 6 skipped, backend tsc clean, jest 282 passed / 1 skipped). Local `backend/.env` set up (auto JWT secrets) with user-filled live keys — Nuitee, **Duffel** (the "second provider"), and **OpenRouter** AI. AI mis-config (OpenAI base URL) fixed to OpenRouter and verified live (`/ai/query`, `/ai/suggest`); `GET /home/recommended` returns real Nuitee hotels. Backend + Linux desktop app running locally. **Next pending phase remains US-5** (search personalization) → US-6 → PH-7 → 4A–4E, UNLESS the user prioritizes the **GO-button / VISA INDEX** requirement.
>
> **CURRENT POSITION (2026-10-17 — stabilization):** repo re-initialized under `git` (`main`, first snapshot `6c3823e`, root `.gitignore` added). Verified green: **Flutter 777 passed / 6 skipped / 0 failed**, `dart analyze` **0 errors / 0 warnings**, backend **tsc clean**, **jest 282 passed / 1 skipped / 0 failed**. Undocumented Oct-16/17 work is now recorded (Home smart AI search pill, TokiGo wordmark, nav shell GlobalKey fix) — see `03_CURRENT_STATE.md` / `04_PHASE_HISTORY.md`. **Next pending phase per MASTER_PLAN is US-5 (search personalization) → US-6 → PH-7 → 4A–4E**, UNLESS the user prioritizes the new **GO-button / trip-start + visa-index** requirement (`Documents/زرار GO عند الضغط عليه.txt`, unimplemented, no phase yet).
>
> **Current position (historical, 2026-09-06): TWO parallel workstreams on one uncommitted tree. (1) Home & Platform: M0 (Nuitee-only validation) + H1 (skeleton rail + no pull-to-refresh) DONE; next H2 (price/availability-only refresh) → H3 (Hive image cache) → NAV (remove bottom nav, blocked until US-2 lands). (2) Universal Search: US-2 in progress by the other agent. Authoritative order + boundaries + pending decisions P1–P6: `MASTER_PLAN.md` (repo root). Verified baseline: Flutter 633 passed / analyze 0 errors / backend tsc clean / jest 232 passed. NOTHING committed — commit decision remains the first pending action whenever the user calls for it (must be scoped per workstream).**
> Merged execution order: M0 → H1 → H2 → H3 → [US-2 lands] → NAV → 2C-C1 (Flutter /ai/chat wiring) → 2C-C2 (Memory Controls UI) → 2D (AI context hardening) → US-3 (voice) → US-4 (AI assistant in search) → 3A–3D (unified search backend + results + details) → US-5 (search personalization) → US-6 (compare/refinement) → PH-7 (Explicit Memory → Home Ranking, standalone approved phase) → 4A–4E (booking + payment) → 5A–5C (unified Trip) → 6A–6C (notifications + trip AI) → 7A–7B (home intelligence; real Home sections return in 7B) → US-7 (search production hardening) → 8A–8B (admin + provider observability) → 9A–9B (security MASVS audit + performance) → 10A–10C (E2E regression + production readiness + release gate).

### PENDING DECISIONS (from MASTER_PLAN — user must approve before the phases can consume them)
- **P1** `speech_to_text` package for US-3 voice search (declined → defer US-3, keep disabled mic).
- **P2** `ResizeImage`/`cacheWidth` decode inside H3 image cache (official Flutter guidance; no package).
- **P3** official `integration_test` dev-dependency for 10A E2E journeys.
- **P4** structure the 9A security audit as an OWASP MASVS checklist.
- **P5** Android 14 predictive back (`PopScope.canPop`) verification in US-7/9B audits.
- **P6** confirm the merged execution order above (esp. NAV after US-2; US-5/US-6 after 3A–3D).

### FOLLOW-UP register (still open)

- **BLOCKER — Booking API mismatch (must be resolved in Phase 4A):** Flutter `BookingRepositoryImpl` calls `POST /bookings/prepare|revalidate|/bookings` which do not exist server-side; checkout uses a synthetic bookingId; confirmation fabricates the Bag entry. Phase 4A builds the backend bookings API (idempotency + revalidation mandatory) then rewires/keeps client calls. Details: `07_KNOWN_ISSUES.md`.
- **R-5 candidate (memory spine activation, folded into H2+/US-5):** Flutter event tracker (`POST /events` + deviceId), Flutter profile client (`/profile/me`), geo→profile write, optional-JWT guest events. Backend pieces exist; wiring is future work.
- **Coverage debt:** new widget tests for the simplified `AiSheetController`/`AiBottomSheetContent`; deterministic Nuitee mapping test (fixture coverage was deleted with `NUITEE_FIXTURES`; live-smoke remains).
- **Housekeeping:** dead `AI_FALLBACK_PROVIDER` line in `backend/.env`; orphaned `offer.entity.ts`; unused `sessions` table; `WatchItem`/`moveToPast`/`ItineraryStage` dead code — tidy only inside an approved phase.
- **Do NOT run `npm run seed:home`** — the fake Home data was deliberately purged (Nuitee-only Home); the script stays for the future real-content phases.

| Phase | Outcome | External need at this phase |
|---|---|---|
| M0–H3 | Nuitee-only Home validation, skeleton rail, no pull-to-refresh, price/availability refresh, Hive image cache | H2/H3 pending; H1 done |
| NAV | Remove bottom nav; Home-centric buttons (flights/hotels/cars/packages) + Groups into Home | Blocked until US-2 lands (shared router) |
| 2C-C1/C2, 2D | Flutter /ai/chat wiring, Memory Controls UI, AI context hardening | Backend live; P6 order confirmation |
| US-2 | Advanced intent + NLP (other agent, in progress) | None |
| US-3 | Voice search | P1 decision (package) |
| US-4 | AI assistant inside Universal Search | None |
| 3A–3D | Unified search foundation → provider aggregation → results/filters/sorting → product details | Cars provider unresolved (TBD); Doville (flights) + Nuitee (hotels) exist |
| US-5, US-6 | Search personalization (explicit intent always wins), compare + refinement | After 3A–3D; PH-7 handles memory→ranking separately |
| PH-7 | Explicit Memory → Home Ranking (standalone, regression-heavy) | Approved phase; travel-style consumer check first |
| 4A–4E | Booking foundation → flight → hotel → car/package → payment (Egyptian gateway, server verification, idempotency) | Real PSP (spec §K); booking DB tables (spec §49) |
| 5A–5C | Unified Trip model → timeline → live tracking (real sources only) | Provider status sources |
| 6A–6C | Notifications → contextual trip AI → post-booking AI | Push infra decision |
| 7A–7B | Home intelligence finalization; REAL Home sections return (no fake deals) | Real content sources |
| US-7 | Universal Search production hardening | After all search-consuming phases |
| 8A–8B | Admin hardening; provider health/observability | None |
| 9A–9B | Security audit (P4 MASVS?) + performance/cache hardening | P4 decision |
| 10A–10C | E2E regression (P3 integration_test?) → production readiness → release gate | P3 decision |

| Phase | Outcome | External need at this phase |
|---|---|---|
| 11B1 | Home schema contract fixed and tested | Complete — none |
| 11B2 | Re-run TypeScript build; fix only verified remaining errors, or close cleanly | Complete — none |
| 11C | Safe, consistent search errors for flights/hotels/cars | Complete — none |
| 12 | Home Marketplace: header, discovery hierarchy, reusable cards | Complete — none |
| 13 | Floating/Orbital Navigation plus persistent command-bar shell and manual search access | Complete — SUPERSEDED by Wave-0 attached bottom nav (Home/Search/AI-centre/Groups/Explore); FloatingNavigation/CommandBar deleted |
| 14 | AI Bottom Sheet (14A UI prototype) + CommandBar wiring/timeouts (14B) | Complete — live AI tested via OpenRouter; CommandBar since deleted (Wave 0) |
| 15 | Context-aware AI and Card Engine integration: current page, results, compare/explain/add-to-trip actions | Complete — none |
| 16 | Offline support foundation: Hive-backed cache for search results + AI responses (write-through on success, cached fallback on failure) | Complete — none |
| 17 | Auth: real identity — login/register/me (bcryptjs + JWT guard), profile/settings entry, persisted secure sessions | Complete — none |
| W0–W3 | Full-app UI rebuild (light-only design language, bottom nav, unified motion, l10n) + real providers (Nuitee LIVE, Duffel revalidation, MarketContext/FX/EGP) + search/home rebuild + booking funnel + mock EG payment gateway with ledger | Complete — see `01_MASTER_MEMORY.md` §12.5 for full detail |
| 24A–24E | Card system sub-phases | Absorbed/superseded by Wave 2 (unified `onFavorite`, dead primitives removed, `DiscoveryProductCard`, skeletons tokenized). STILL OPEN from 24C: **favorites persistence** (heart toggles are presentational only) |
| 18 | PROJECT_MEMORY cloud sync (auto-backup of memory files) + analytics foundation (AI query tracking) | SUPERSEDED as "next" — memory files are now maintained live in `PROJECT_MEMORY/` + `MASTER_PLAN.md`; cloud backup remains a valid future option |
| 19 | Real booking/payment foundation: matching backend booking API, confirmation, idempotency, Bag synchronization | Mostly covered by W1+W3 (revalidate endpoint, state machine, mock gateway, ledger). REMAINING: real Egyptian PSP onboarding (spec §K open questions), provider book wiring end-to-end (Duffel createOrder + Nuitee book from the funnel), booking persistence (DB tables per spec §49) |
| 20 | Unified Trip Bag: Trip/TripItem, internal+external additions, readiness checklist, Wallet, Price Watch | Database/API persistence; external import options are staged—manual entry first, then approved share/PDF/QR/calendar/email integrations; price watches require a valid offer-price source and scheduled server jobs. (Bag page + TripDetails v1 + Continue-planning shipped in W0) |
| 21 | Accessibility improvements (screen reader support, text scaling compliance) | Platform accessibility tooling audit; no new vendor required for the first pass |
| 22 | Live Travel Companion: Today, itinerary map, external navigation handoff, event-based notifications, Travel Mode | Map/directions/geocoding provider, user location permission, push-notification service, background-job capability; later flight-status/weather/local-service data sources as each feature is approved |
| 23 | Production readiness and launch | Separate dev/staging/prod environments, secret manager, restricted CORS, migrations/backups, observability, CI/CD, privacy policy/consent records, and security review. Per spec v2.0 §52: one market (EG) + one product canary first |
| 24 | Trusted Group Trips: discovery, membership, shared plans, ratings, safety | Requires identity/roles and the Phase-20 Trip model; push notifications, strict authorization/audit logging, and an approved identity-verification provider only when verification is activated. (v1 mock Groups tab shipped in W0) |

### Dynamic product flow after the roadmap

```text
Discover manually or with AI
  → compare/explain/filter in the current page
  → Add to trip or complete an in-app booking
  → one unified Trip Bag and readiness checklist
  → Today / Itinerary / Map / Wallet during travel
  → event-based AI guidance and high-signal notifications
```

### Dependency and privacy rules

- Do not add a Flutter package, provider SDK, map vendor, payment vendor, email/calendar integration, or background-location capability until its phase is approved and its security/cost/privacy implications are selected.
- AI never runs continuously in the background. A time, booking, provider, or opted-in location/geofence event causes a short evaluation only when it could produce a meaningful update.
- Location, notification, companion-status, document, and external-account access are optional, trip-scoped where possible, and have clear disable/revoke paths.
- Provider facts (price, availability, delay, route) are always distinguished from AI interpretation or recommendation.

## Unified UI system — implementation specification

### Product shell

- Use one mobile-first application shell across primary surfaces. The top header keeps the brand at left; Notifications and Profile are at right. Profile owns sign-in/create-account for guests, then account, settings, privacy, and session controls for members.
- Use one persistent bottom command bar. It provides natural-language AI input and an on-demand Floating/Orbital Navigation trigger. It is present on Home, search, Trip/Bag, and Group contexts, with a page-aware prompt rather than a separate AI destination.
- Limit primary navigation to 5–7 high-frequency destinations. Home, Search, Trips/Bag, and Groups are primary candidates; Flights/Hotels/Cars can be reached through Search and contextual shortcuts rather than forcing every service into the first navigation level.
- Preserve a clear visual distinction between a user action, a live provider fact, and AI advice. Never present AI output as confirmed booking, price, availability, or navigation data.

### Visual language and reusable UI

- Continue using the existing token/theme/card system. Build new features from reusable surfaces: AppHeader, CommandBar, OrbitalNavigation, SectionHeader, OfferCard actions, StatusChip, ReadinessItem, TimelineItem, MapPlaceCard, WalletCard, MemberAvatarStack, and BottomSheet states.
- Use progressive disclosure: Home favors discovery; search favors filters and results; Trip favors next action; Group favors shared decisions. Details live in sheets, detail pages, or expandable cards rather than on every screen.
- Design every feature with loading, empty, error, offline, permission-denied, and success states. Support accessibility labels, readable contrast, scalable text, Arabic/English layout, and compact/desktop adaptive layouts.

### Screen map

| Surface | Main UI | Contextual AI / action |
|---|---|---|
| Home Marketplace | Hero, curated sections, continue planning, notifications/profile header | Plan a trip, discover offers, resume session |
| Manual Search | Service tabs, structured form, filters, sortable offer cards | Help me choose; apply AI filters; compare selected offers |
| AI Sheet | Collapsed input, half results, full session/history | Explain, compare, alternatives, Use in manual search, Add to trip |
| Profile | Guest auth entry or user profile, settings, privacy, verification state | Manage preferences and travel identity |
| Trip/Bag | Today, Itinerary, Map, Wallet, Readiness, Price Watch | Add to trip, close gaps, directions, travel guidance |
| Travel Mode | Next action, route handoff, status, high-signal alerts | Add missing item, update plan, safety check-in |
| Groups | Discover/create group, member list, join requests, shared plan, polls | Group planning, vote summary, travel coordination |

### UI delivery by phase

1. **12:** Home Marketplace, AppHeader, shared section/card hierarchy, guest Profile entry visual.
2. **13:** Floating/Orbital Navigation and CommandBar shell; manual-search entry and contextual shortcuts.
3. **14:** AI Bottom Sheet visual states, starter prompts, session list, filter chips, safe response/error states.
4. **15:** AI actions on existing cards and manual results: explain, compare, alternatives, apply filters, add to trip.
5. **17:** Real login, profile, settings, privacy/consent, and verification-status UI.
6. **19:** Booking confirmation/review states and automatic visible sync into Trip/Bag.
7. **20:** Unified Trip UI, Add to trip menu, external-import review draft, Readiness checklist, Wallet, Price Watch.
8. **22:** Today/Travel Mode, Map place cards, directions handoff, event cards, notification action handling, permission education.
9. **24:** Group discovery/search, create flow, role/member UI, join request approval/rejection, shared itinerary, polls, check-ins, and trust/review states.

### Trusted Groups product rules

- A Group attaches to a shared Trip and reuses the same TripItem, Today, Itinerary, Map, and Wallet primitives. An item can be personal or shared; permissions determine who can view/edit it.
- Roles are Owner, Organizer/Admin, Member, and Viewer. Requests are pending until an authorized organizer accepts or rejects them; invite links are revocable and time limited.
- Show verification as clear levels (for example phone/email verified, identity verified) without exposing documents. Only allow behavioral reviews after verified shared-trip participation, and provide reporting, blocking, and moderation paths.
- During travel, groups use shared Today, polls, optional time-limited location/status sharing, check-ins, expense notes/split preparation, meeting points, and emergency/safety actions. Location sharing is never required and has a visible off switch.

---

## Product / UX Vision

### Unified AI + manual search

The product uses one persistent bottom command bar across its main screens. It provides both universal AI travel assistance and an on-demand Floating/Orbital Navigation entry point. AI is not a separate normal chat destination: it adds contextual natural-language search, filter extraction, comparisons, and explanation on top of the current page. Manual Flight/Hotel/Car search remains a first-class path for precision and control. AI filters can populate manual forms, and manually selected offers can be discussed with the assistant. The header holds app identity at left and Notifications + Profile at right; Profile owns login, account, and settings entry points.

### Interaction rules for Phases 12–15

- Show starter prompts before input, including trip planning, cheapest flight, weekend hotel, and continuing an existing trip.
- Convert natural-language intent into the appropriate scoped search or trip-planning action.
- Render extracted filters as editable chips and pair results with actions: Use in manual search, Show alternatives, Compare, and Save to trip.
- Make “Help me choose” available from manual-result pages; it opens the AI sheet over the current results.
- Cards can offer Explain why this fits, Cheaper alternatives, Compare, and Add to trip.
- Explain AI ranking criteria and clearly separate live search/provider facts from AI interpretation.
- Model sessions as named trips with context, filters, saved offers, and conversation history.
- In Bag, support itinerary summaries, booking-policy answers, reminders, and complementary recommendations.

### Future direction — Travel Companion and live trip operations

Bag becomes the live trip hub rather than a booking list:

| Surface | Purpose |
|---|---|
| Today | Next action, countdown, distance/ETA, departure guidance, and important alerts |
| Itinerary | Full booking/place timeline with addresses, map locations, and departure timing |
| Map | Opted-in user location, saved trip places, and external-map handoff for navigation |
| Wallet | Booking references, QR codes, selected documents, insurance, and offline essentials |

During a trip, contextual AI can use time, itinerary, optional location, traveler details, and budget to help with airport departure timing, delays, gate changes, check-in, route deviations, weather disruptions, nearby alternatives, and plan reordering. The system should generate high-signal travel events, not generic chat messages.

The Today/Travel command bar also provides a contextual **Add to trip** action. A user can immediately add a booking, transfer, activity, note, document, or planned offer without leaving the current screen. Its quick menu prioritizes the likely missing item for the current moment—such as airport transfer before arrival or return transport before departure—while retaining a generic Add item action. Dismissed or ignored notifications do not erase a gap: the related action stays in Today and Trip Readiness until the user completes it or marks it not needed.

Background behavior is event-driven: time, booking/provider updates, geofences, or optional location events trigger short evaluations and only useful notifications. Do not run AI continuously in the background. Travel Mode must be explicit and trip-scoped, with clear location permissions, a visible off switch, manual “I’m here” fallback, notification controls, and optional trusted-contact/safety check-ins. Local-service suggestions can include transfers, eSIM, pharmacies, ATMs, supermarkets, restaurants, and accessible/family-friendly options; clearly distinguish live provider facts from AI recommendations.

### Future direction — Unified Bag, external bookings, and trip readiness

Bag is one user-owned Trip with a unified list of TripItems, not separate internal and external trip experiences. The user sees one **Add to trip** action: search/book inside the app, add an unbooked internal offer, add an external booking manually, or import a draft from shared confirmation content/PDF, forwarded email, calendar, or a QR/booking code. In-app confirmations add themselves automatically. AI-extracted data is always reviewable before it becomes a confirmed item. Internally, an item tracks its source (`inAppConfirmed`, `inAppPlanned`, `externalImported`, or `manual`) and lifecycle (planned, needs review, confirmed, cancelled, completed), while the user experiences one coherent itinerary.

Add a Price Watch surface for target-price/price-drop tracking of unbooked offers, planned-trip alternatives, and only cancellable booked offers after policy checks. The current code has the `WatchItem` domain model but no controller, storage, backend, or UI yet.

Each trip shows a prioritized **Trip Readiness / Missing items** checklist rather than a meaningless percentage. It evaluates every TripItem together, identifies relevant gaps—such as missing accommodation, transfer, return leg, traveler information, check-in, document/insurance review, connectivity plan, or itinerary conflicts—and offers direct actions. Users can complete or mark an item not needed; it must inform and assist, never block or shame them. AI uses the unified trip to connect the gaps: for example, it can recommend an airport transfer for an externally booked hotel or ask the user to review an imported return flight.

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
