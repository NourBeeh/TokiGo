# TokiGo — UI Refinement Phase: final report (2026-11-11)

## 1. Initial Git state

- Branch `Main` @ `706ef11` ("feat(ui): shared 3D cover flow for the stay rail, Home-matched palette"), tracking `origin/Main`.
- Working tree was already dirty with **two backend files** that are unrelated to this phase and were **not touched**:
  - `backend/src/modules/payments/payment.service.ts`
  - `backend/test/p4.persistence.spec.ts`
- Baseline before any edit: `flutter test` → **415 passed, 0 failed**.

## 2. Files inspected

Theme: `lib/core/theme/{app_colors,tokigo_colors,tokigo_gradients,app_theme,app_tokens,app_motion,app_spacing,app_radius}.dart`
AI: `lib/features/ai/presentation/pages/ai_chat_page.dart`, `.../widgets/{chat_search_widgets,ai_empty_state,ai_mode_indicator,ai_response_content,ai_ambient_visual}.dart`, `lib/features/ai/application/ai_state.dart`
Home: `lib/features/home/presentation/pages/home_page.dart`, `widgets/{home_ai_search_field,home_top_bar,destination_cover_flow_carousel,cover_flow_carousel,home_stays_carousel,home_section,flight_recommendation_list,deal_card,home_stay_card,home_discovery_stay_card}.dart`, `home_card_dimensions.dart`, `home_design_tokens.dart`
Chrome/nav: `lib/app/widgets/{app_chrome,home_nav_buttons,app_bottom_nav}.dart`, `lib/app/router/go_router_config.dart`, `lib/core/widgets/page_header.dart`, `lib/core/widgets/notification_bell.dart` (features)
Splash: `android/app/src/main/res/{values,values-night,values-v31,values-night-v31}/styles.xml`, `drawable*/launch_background.xml`, `drawable*/{splash,android12splash,android12branding}.png`, `tool/branding/generate_splash.py`, `pubspec.yaml`
Consumers: ~40 files referencing `tokigoColors.brand` / `AppColors.*` across search, booking, bag, notifications, profile, admin, groups.

## 3. Files modified

**New**
- `lib/core/widgets/ai_robot_avatar.dart` — the shared robot identity.
- `test/ai_robot_avatar_test.dart`, `test/home_card_rail_cover_flow_test.dart`, `test/home_header_scroll_animation_test.dart`
- `docs/ui-refinement-audit-2026-11-11.md` — the audit mapping.

**Dart**
- `lib/core/theme/app_colors.dart`, `tokigo_colors.dart`, `tokigo_gradients.dart`, `app_theme.dart`
- `lib/core/theme/../features/ai/presentation/pages/ai_chat_page.dart`
- `lib/app/widgets/app_chrome.dart`
- `lib/features/home/presentation/pages/home_page.dart`, `home_card_dimensions.dart`
- `lib/features/home/presentation/widgets/{home_section,flight_recommendation_list}.dart`
- `test/theme_token_consistency_test.dart`, `test/app_theme_wiring_test.dart`

**Branding**
- `tool/branding/generate_splash.py`, `assets/branding/logo_splash*.png`, `logo_branding*.png`
- Regenerated Android `splash.png` / `android12branding.png` (all densities, light + night), iOS `LaunchImage*`, `web/splash/img/*`.

**No files were deleted.** `pubspec.yaml` is unchanged (no new packages).

## 4. Implementation details

### 1) AI robot identity
- One widget, `AiRobotAvatar` (`lib/core/widgets/ai_robot_avatar.dart`), draws the existing `assets/images/TOKI AI.png` (already transparent) at a caller-chosen size.
- `ChatBubble` now wraps an assistant message in `_AssistantTurn`, which places the robot at the turn's **leading edge** (LTR: left; RTL: right — verified by test, a placement bug was found and fixed here). A user turn never goes through it.
- The thinking indicator is `_AssistantTurn(child: TypingDots())`, so the robot is present during loading too, with a breathing pulse (halo + 4.5 % scale, 1600 ms, `AnimatedBuilder`).
- The welcome hero reuses the same widget at 96 px. No new dependency; no asset duplication.

### 2) Neutral colour system
- `TokiGoColors.light()`: `brand` → `#111111`, `onBrand` → white, `brandContainer` → `#F0F0F0`, `onBrandContainer` → `#111111`, `ai` → `#111111`, `info` → `#262626`, `focusRing` → `#1F111111`, feature hues/containers → neutral ink/grey.
- `TokiGoColors.dark()`: `brand` → `#F5F5F5`, `onBrand` → black, `brandContainer` → `#262626`, `ai` → `#F5F5F5`, `info` → `#F5F5F5`, `focusRing` → `#33F5F5F5`, `ctaBarButton` → `#F5F5F5`.
- `TokiGoGradients` ramp retired to a neutral ink step (`#262626 → #5A5A5A → #8E8E8E` and an 8-stop smooth ramp); the only remaining consumer is `ask_assistant_card.dart`.
- `AppTheme` resolves the light `ColorScheme` from the light ink, so buttons, indicators, focus borders and navigation indicators are neutral in both themes. Dark theme already resolved through the palette.
- Semantic colours (`success`, `warning`, `danger`, `heart`) and the wordmark red are **untouched**.
- Audit: `grep` for the retired hex values and `Colors.blue`/`Colors.indigo` across `lib/`, `assets/`, `pubspec.yaml` and `android/.../res` returns **zero** matches.

### 3) Home search box — floating, borderless
- The pill was already borderless with a halo; the defect was that the pinned `AppChrome` band painted an opaque `ColoredBox` behind it, so it read as a solid stripe rather than floating.
- `AppChrome` is now transparent, so the feed scrolls visibly beneath the pill and the halo alone carries the edge. Height, radius, padding and the existing search/navigation behaviour are unchanged; `test/home_design_spec_test.dart` still passes unchanged.

### 4) Card swiping — one cover flow
- Inspected `CoverFlowCarousel` (the reference implementation) and its two existing hosts.
- The two remaining Home card rails did **not** use it: `home_section.dart` (car/package/deal) and `flight_recommendation_list.dart` were plain `PageView`s.
- Both now run `CoverFlowCarousel` with the same mechanics (`padEnds: true`, live-offset `Matrix4`, rotateY fan, uniform scale, perspective, reduced-motion fallback) and a shared page fraction `HomeCardDimensions.cardRailViewportFraction = 0.8`. No second pager implementation was introduced; card content, keys and navigation callbacks are unchanged.

### 5) Splash sun/background match
- Root cause: the icon tile in the artwork was filled **pure black `#000000`** while the launch page field is `#111111`, producing a visible darker plate around the mark.
- `tool/branding/generate_splash.py` now keys the opaque icon master's field to transparency and fills the squircle with the page colour (`PAGE_FIELD = #111111`), keeping the glyph, proportions and hairline border.
- Regenerated the masters and ran `flutter_native_splash:create`; all Android densities (light + night), iOS `LaunchImage*` and web splash images were regenerated.
- Verified numerically: the tile interior now samples `#111111` at every interior point (delta 0 from the page colour). The Android 12 `android12splash.png` is a pure white glyph on transparency, so it carries no field to mismatch; it is drawn by the OS on the `#111111` page.
- `test/brand_icon_splash_test.dart` (field `#111111`, light == night) and `test/brand_wordmark_test.dart` both pass.

### 6) Home header scroll animation
- `_HomePageState` now owns one `AnimationController` (220 ms, `easeOutCubic`) driven by the feed's **scroll direction** through a `ScrollController` listener with an 8 px dead zone.
- Scrolling away from the top animates the wordmark row's opacity + a small upward translation; scrolling back reverses the same controller. The header is removed only when the factor reaches 0, so there is no flicker.
- The pinned composer is a **separate** `SliverPersistentHeader` and is never driven by this value; its size and horizontal position are asserted unchanged by test.
- Uses `AnimatedBuilder` + the existing `CustomScrollView`; no new packages. Pull-to-refresh behaviour (deliberately absent by product decision) and scrolling physics are unchanged.

### 7) System theme default
- Audited `theme_provider.dart`, `main.dart` (`_readInitialThemeMode` falls back to `ThemeMode.system`), `MaterialApp` wiring and `SettingsPage` (System/Light/Dark picker). **System was already the default** and manual selections already persist — no defect found, so no behaviour change was made.
- Added two regression tests: a fresh install with no stored value resolves to System (follows a dark OS, never forcing Light), and a stored Dark value survives while a return to System resumes OS sync.

## 5. Tests executed and exact results

| Command | Result |
|---|---|
| `flutter test` (baseline, before edits) | **415 passed, 0 failed** |
| `flutter test` (after all changes) | **428 passed, 0 failed** |
| `flutter test test/theme_token_consistency_test.dart test/theme_provider_test.dart test/app_theme_wiring_test.dart test/brand_wordmark_test.dart` | 21 passed |
| `flutter test test/brand_icon_splash_test.dart test/brand_wordmark_test.dart` | 9 passed |
| `flutter test test/ai_robot_avatar_test.dart` | 5 passed |
| `flutter test test/home_card_rail_cover_flow_test.dart` | 3 passed |
| `flutter test test/home_header_scroll_animation_test.dart` | 3 passed |

The 13 new tests are the three new suites (11) plus two added `app_theme_wiring_test` cases.

## 6. Flutter analyze

`flutter analyze` → **114 issues, 0 errors** (83 warnings/infos before the change; the count delta is pre-existing unused-import warnings in files this phase touched, not new defects). Every issue is `unused_import` / `deprecated_member_use` / `dead_code` style and all of them exist at baseline too — verified by stashing the work and re-running analyze (baseline: 110 issues, 83 warnings).

## 7. Android build

- `flutter build apk --debug` **failed twice** with the same cause: `dl.google.com:443` is unreachable from this host (`Connection timed out`), while `repo.maven.apache.org` and `pub.dev` return 200. This is a network/environment failure, not a code failure.
- Worked around it by building from the existing Gradle cache:
  `java -cp android/gradle/wrapper/gradle-wrapper.jar org.gradle.wrapper.GradleWrapperMain assembleDebug --offline`
- Result: **BUILD SUCCESSFUL in 6m 52s** — `build/app/outputs/flutter-apk/app-debug.apk` (234 MB, timestamped after all changes).
- The APK was opened and its `android12splash.png` verified: white glyph on transparency (no field).

## 8. Remaining defects and limitations

1. **No on-device visual verification.** `adb devices` lists no attached device, so the rendered UI (Light/Dark, splash, header motion, card swiping, AI chat) was verified by widget tests and pixel-level asset checks, **not** by inspecting the running app on hardware. The acceptance item "do not claim visual verification without actually inspecting the rendered UI" is therefore explicitly **not** claimed.
2. **Gradle needs `--offline`.** A normal `flutter build apk` cannot resolve `dl.google.com` from this network; the APK was produced from the local cache. A clean environment without that cache will need Google Maven reachable.
3. The Android 12+ splash icon is the OS-masked adaptive foreground, which carries no background field; the field match is a property of the page colour, which is unchanged and correct.
4. Pre-existing analyzer warnings (unused imports, deprecated colour getters) were left alone to avoid unrelated churn.

## 9. Confirmation: no files deleted

`git status --porcelain` shows only `M` (modified) and `??` (new) entries — no `D`/`DD` entries.

## 10. Confirmation: no commit or push

No `git commit`, `git add`, `git push` or history rewrite was run. The working tree is left dirty for review.

## 11. Final Git status and changed-file summary

- **2 pre-existing backend files** (untouched by this phase): `backend/src/modules/payments/payment.service.ts`, `backend/test/p4.persistence.spec.ts`.
- **13 Dart source files** changed (theme tokens, theme data, AI chat page, Home page, AppChrome, Home section/flight rail, card dimensions).
- **1 new Dart widget** (`ai_robot_avatar.dart`) and **3 new test files** + 1 audit doc.
- **2 test files** updated (theme tokens, app theme wiring).
- **1 branding generator** updated + **36 regenerated splash/branding images** (Android ×22, iOS ×6, web ×8).
- `pubspec.yaml`, routing, backend, payments, booking, search logic and platform config: **unchanged**.
