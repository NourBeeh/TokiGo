# TokiGo — UI Refinement Phase: audit mapping (2026-11-11)

Baseline: branch `Main` @ `706ef11`, working tree dirty with 2 backend files
(`backend/src/modules/payments/payment.service.ts`, `backend/test/p4.persistence.spec.ts`)
that are NOT part of this phase and were not touched.

Baseline test suite: `flutter test` → **415 passed, 0 failed**.

## Requirement → existing implementation → defect → files → minimal solution

### 1. AI robot identity
- Existing: `assets/images/TOKI AI.png` (612×701, transparent) is used **only** in the
  AI chat welcome state (`ai_chat_page.dart:296`). `ChatBubble` renders text only.
  No robot beside replies, none while thinking (`TypingDots` only).
- Defect: no robot identity on assistant turns or during loading.
- Files: new `lib/core/widgets/ai_robot_avatar.dart`; `ai_chat_page.dart`
  (bubble + typing indicator + welcome reuse).
- Solution: one reusable small robot avatar widget (asset + breathing pulse),
  shown beside every assistant bubble, inside the thinking indicator, and reused
  in the welcome hero. User bubbles never get it.

### 2. Remove the blue
- Existing: `AppColors.brand` / `TokiGoColors.brand` = `#0064E0` in BOTH palettes;
  `brandLight` `#3D8BEC`, `brandDark` `#0051B3`, `brandContainer` `#E7F3FE`,
  `onBrandContainer` `#005A9E`, `ai` `#0064E0`, `info` `#0064E0`,
  `focusRing` `#1F0064E0` (light) / `#330A84FF` (dark), `ctaBarButton` `#0064E0`,
  the six `*Hue` tokens `#0064E0`, four `*Container` `#E7F3FE`, and the
  Instagram purple→red→orange ramp in `TokiGoGradients`.
- Consumers: `app_theme.dart` (ColorScheme.primary, buttons, indicator, focus ring),
  `app_colors.dart`, `tokigo_colors.dart`, `tokigo_gradients.dart`,
  `app_message_state.dart`, `ai_chat_page.dart`, `ask_assistant_card.dart`,
  `ai_mode_indicator.dart`, `ai_empty_state.dart`, `go_router_config.dart`,
  plus ~35 files that reference `tokigoColors.brand`.
- Defect: the blue accent still paints buttons, chips, selection states, FAB-style
  discs, focus rings and the user bubble gradient.
- Solution: repoint the tokens at a neutral ink system (no hue). `brand` becomes the
  active-canvas ink (`#111111` light / `#F5F5F5` dark) with matching container/on
  roles; `brandLight/brandDark` become ink steps; `ai` becomes ink; `info` becomes
  ink (semantic status colours are untouched); focus ring becomes ink-based; the
  six feature hues and their containers become neutral; the gradient ramp is retired
  to a neutral ink ramp. Every consumer resolves through the tokens, so a single
  token change covers the app.
- Tests to update (they pin the blue by design): `theme_token_consistency_test.dart`,
  `brand_wordmark_test.dart` (pins `brandRed` only — unchanged).

### 3. Home search box — floating, borderless
- Existing: `HomeAiSearchField` is already borderless with a halo
  (`home_ai_search_field.dart:140-148`) and pinned via `AppChrome` +
  `SliverPersistentHeader` (`home_page.dart:173-176`). `test/home_design_spec_test.dart`
  pins exactly this.
- Defect: **already implemented**. Remaining gap: the pinned chrome's `ColoredBox`
  paints a full-width opaque band behind the pill, so the "floating" pill sits on a
  solid stripe rather than genuinely floating over the feed.
- Solution: keep the pill borderless (no change), make the pinned band transparent
  so the feed scrolls under the pill and the halo alone carries the edge. Guarded by
  the existing `home_design_spec_test.dart` contract.

### 4. Card swiping — match Explore
- Existing reference: `CoverFlowCarousel` (`cover_flow_carousel.dart`) is the ONE
  3D pager — live-offset `Matrix4` (rotateY fan, uniform scale 0.48–1.0, slot offset,
  perspective 0.0018), `padEnds: true`, `AnimatedBuilder` per frame,
  reduced-motion fallback. `DestinationCoverFlowCarousel` (viewportFraction 0.9) and
  `HomeStaysCarousel` (0.8) both use it. `ExploreCitiesPage` itself is a grid, not a
  swiper.
- Defect: the two remaining Home rails do NOT use it:
  * `home_section.dart:299-318` — a plain leading-aligned `PageView` for
    car/package/deal rails;
  * `flight_recommendation_list.dart:109` — a plain `PageView`.
  `discover_badge_card.dart:132` is a photo gallery inside one card, not a card rail.
- Solution: route both remaining card rails through `CoverFlowCarousel`, reusing the
  same mechanics and the same card widgets; no second implementation is introduced.

### 5. Splash — sun/background colour match
- Existing: native splash only (no Flutter splash widget). Field colour
  `#111111` (`values-v31/styles.xml`, `drawable/background.png` 1×1 `#111111`).
  The artwork `splash.png` / `logo_splash_dark.png` is transparent, but the icon
  tile inside it is filled **pure black `#000000`** while the page field is `#111111`
  → a visible darker plate/halo around the mark.
- Defect: the icon tile's fill is not the page background colour.
- Solution: regenerate the splash masters with the icon tile filled `#111111`
  (`tool/branding/generate_splash.py`), keeping the icon's proportions and identity
  unchanged, then regenerate the Android drawables. The existing
  `test/brand_icon_splash_test.dart` pins the field/`#111111` and light==dark.

### 6. Home header — smooth scroll animation
- Existing: `SliverToBoxAdapter(_buildHeader)` scrolls away abruptly; the composer
  is pinned by a fixed-extent `_HomeComposerHeader`.
- Defect: no directional hide/show animation; the header simply disappears when its
  sliver leaves the viewport (pinned behaviour is fine and must be preserved).
- Solution: drive a small `AnimationController` from the feed's scroll direction
  (scroll direction stream), animating the header's height/opacity; keep the
  composer pinned and fully visible. Uses `AnimatedBuilder` + existing
  `CustomScrollView`; no new packages.

### 7. Theme — System default
- Existing: `ThemeModeController` defaults to `ThemeMode.system`
  (`theme_provider.dart:12`), `main.dart` reads the persisted mode with a System
  fallback, and `MaterialApp` wires `themeMode`. `theme_provider_test.dart` and
  `app_theme_wiring_test.dart` already pin System-by-default + platform follow +
  manual override persistence.
- Defect: **already implemented**; no first-launch Dark/Light forcing found.
- Solution: verify + add a fresh-install regression test that the first frame is
  System (no persisted value) in the real app wiring, and that the OS brightness
  change re-propagates. No behaviour change expected.

## Deliberately NOT changed
- Backend, payments, bookings, search logic, routing, iOS/Android back gestures.
- Semantic status colours (success/warning/danger/heart) — kept.
- `assets/images/TOKI AI.png` pixels (already transparent, correct).
- The Instagram gradient is retired only as a *colour* (blue/purple identity), not by
  deleting the token file.
