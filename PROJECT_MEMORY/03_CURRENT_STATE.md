# 03 — Current State

Last updated: 2026-11-06 (session: Home restored — Home-off / resume mode removed)

## Build / verification

- `flutter analyze`: 0 errors.
- `flutter test`: all green (233 tests).

## HOME IS THE ONLY SURFACE (2026-11)

The temporary Home-off mode (Task 11–14) has been removed at the owner's
request. The app opens on Home again and Home is the only top-level surface.

- `AppConfig.homeEnabled` and `AppConfig.showResumeButton` are gone. The
  router's `initialLocation` is `/`, and every fallback (`AppBackButton`,
  City, onboarding completion, the hotel "Discover more" hand-off, booking
  confirmation) goes to `/`.
- Deleted with the mode: `ResumeTopBar`, `ResumeTopBarScope`, `ResumeButton`,
  `lib/app/providers/resume_providers.dart`,
  `lib/core/navigation/resume_destination.dart`,
  `lib/core/storage/resume_destination_store.dart`, and their four test files
  (`resume_top_bar_test`, `resume_shell_test`, `resume_router_test`,
  `resume_destination_test`).
- `TokiGoShell` only hosts the navigation stack again — no pinned chrome and
  no page header is hidden (`AppPageHeader.visible` was removed).
- The Groups route still honours `AppConfig.groupsEnabled`; when disabled it
  redirects to `/`.
- Deep links still win: `GoRouter.initialLocation` is only a fallback
  (`overridePlatformDefaultLocation` stays false).

## Build / verification (device)

- Android: no device connected and no AVD available on this machine, so the
  launcher icon could not be confirmed on a device/simulator. The generated
  resources were verified directly instead (see "App icon" below).
- iOS: cannot be built on this Windows host (no Xcode). The unsigned IPA is
  produced by `.github/workflows/ios-build.yml`.

## Home screen (this pass)

- The quick-action row is **pinned at the top**, directly under the header
  (wordmark + notification bell + profile). The AI composer stays pinned at
  the bottom. The feed scrolls between them.
- Nothing in the pinned chrome moves, resizes or animates on scroll: the
  composer's `compact` state, `_composerCompact`, `_onScrollNotification` and
  `kHomeCompactSearchHint` were removed. The search field is fixed at 56dp.
- The row is **five** tiles: Flights, Stays, Cars Rental, Activities, Groups.
  The **Trips tile is gone** (owner decision, 2026-11) — My Trips stays
  reachable from Profile and the `/bag` route. `HomeAction.trips` and its
  in-page branch are deliberately KEPT so the selected-state persistence and
  the `home-trips-content` contract keep working. `HomeAction` also has
  `activities` and `groups`; Activities opens the packages/tour search, Groups
  opens the existing Groups page.
- Tile height 88 → **68** (still ≥44dp tap target).
- Light-mode Home accent is Action Ink `#111111` (`HomeDesignTokens.accent`),
  not red; pressed surface is neutral `#F5F5F5`. Dark mode unchanged.
- The "Use your location…" card was removed from Home, together with
  `LocationPermissionCard` and `locationPromptDismissedProvider`.
  Location ("when in use" only) is now requested from the Onboarding
  Permissions step via `requestLocationAccess(ref)`; a denial never blocks.
- Empty/offline states are centred in the feed's remaining viewport
  (`SliverFillRemaining` + `_CenteredFeedState`), between the pinned
  quick-action row and the pill. `_CenteredFeedState` is `Padding(bottom:
  reserve) + Center` — intrinsics-safe. It used to be a `LayoutBuilder`, which
  `RenderSliverFillRemaining.performLayout` cannot query (it always asks its
  child for `getMaxIntrinsicHeight`), so every debug build of the empty/offline
  state threw "LayoutBuilder does not support returning intrinsic dimensions".

## Floating AI composer (this pass)

- Home's body is a `Stack`: the bottom layer is `Column(_buildTopArea,
  Expanded(feed))`, the top layer is `Positioned(left: 0, right: 0, bottom: 0)`
  with ONLY the pill — horizontal padding `AppSpacing.lg`, bottom padding 12
  plus the bottom safe-area inset. The old full-width `ColoredBox` +
  `SafeArea` `_buildBottomComposerArea` is gone, so nothing paints a solid bar
  behind the pill and there is no dead band above it.
- The pill floats on its own halo: `HomeDesignTokens.composerShadowOf(context)`
  (blur 20, offset y 4 — ink 10% in light, black 35% in dark). The field's
  `boxShadow` is no longer an empty const list.
- The pill's footprint is reserved **once**, inside each scrollable:
  `HomePage.composerReserve(context)` = pill height 56 + 12 margin + bottom
  safe-area inset (68 on a device with no inset). The `Expanded` wrapper has
  no padding any more.
  - Dashboard: a trailing `SliverToBoxAdapter(SizedBox(height: reserve))`.
  - Empty/offline: `SliverFillRemaining` is NOT padded (a `SliverPadding`
    around it does not shrink the fill — only its "before" padding is
    subtracted); `_CenteredFeedState.reserveBottom` subtracts it instead.
  - Embedded pages (flights, stays, cars, packages, groups, bag) take a new
    `bottomPadding` parameter and reserve it in their own scrollable, so their
    own canvas fills the reserve and their last field is never hidden.
- Keyboard: the `Scaffold` resizes its body (`resizeToAvoidBottomInset`
  defaults to true), so the `bottom: 0` pill rides up with the keyboard.
  Measured: with a 320px inset the feed ends at 524 and the pill's bottom is
  512 — fully visible, never covered.
- Measured (390x844, no inset): pill `LTRB(16, 776, 374, 832)`, feed
  `LTRB(0, 138, 390, 844)`, reserve exactly 68. Scrolled to the bottom the
  stays rail ends at y=740, i.e. 36px above the pill. Empty state: message
  `LTRB(0, 138, 390, 776)`, centred between the row and the pill.

## App icon (this pass)

- Master artwork: `assets/icon/app_icon.svg` (1024x1024, full-bleed).
- **The icon is the parasol ALONE** (owner decision, 2026-11): a single white
  beach umbrella centred on the brand-red canvas, no wordmark. The "Go"
  lettering was removed — at 29pt a second line of type under the mark stops
  reading. The wordmark stays in `assets/branding/` and on the splash.
- Generator: `tool/branding/generate_app_icon.py` (pure geometry, no font
  dependency any more) and `tool/branding/render_svg.js` (npm
  `@resvg/resvg-js`; `npm install` in `tool/branding`). The generator
  self-checks: non-empty outlines, everything inside the viewBox, a
  canvas-coverage floor for 29pt legibility, and the adaptive safe-zone
  diagonal.
- Brand red `#FF2D2D` (= `AppColors.brandRed`, sampled from the "Go" of
  `assets/branding/logo_wordmark.png`); parasol white `#FFFFFF`.
- Exports: `app_icon_1024.png` (iOS, opaque, mark = 41.8% of the canvas
  bbox), `app_icon_adaptive_foreground_1024.png` (mark inside the central 66%
  safe zone, diagonal 673 ≤ 676, bbox = 20.9%),
  `app_icon_adaptive_monochrome_1024.png` (transparent background, white
  artwork, for Android 13+ themed icons).
- `flutter_launcher_icons` regenerated every `mipmap-*`/`drawable-*` icon and
  `ios/Runner/Assets.xcassets/AppIcon.appiconset`. The stale
  `drawable-night/ic_launcher_foreground.png` was removed.
- Display name is "Toki Go" everywhere: iOS `CFBundleDisplayName` and
  Android `android:label`.
- Verified by pixel analysis (`scripts/verify_brand_assets.py`): every final
  asset carries a connected white parasol covering a meaningful share of the
  canvas, painted backgrounds are exactly `#FF2D2D`, and no white touches the
  outer edge (nothing clipped).
- `assets/branding/app_icon*.png` / `icon_foreground*.png` are ORPHANED
  leftovers from an older identity (`#111111` canvas, cyan `#00D2D2` mark);
  nothing references them.

## iOS Local Network prompt (investigated)

- Root cause: Flutter's **debug/profile** builds start the Dart VM Service and
  advertise it over multicast DNS (`_dartVmService._tcp`). iOS 14+ treats that
  as local-network use and shows the prompt. Release builds do not start the
  VM service, so they never show it. Documented by Flutter: "This affects
  debug and profile builds only and won't appear in release builds."
- The app has no `NSBonjourServices` / `NSLocalNetworkUsageDescription` keys
  (correct for release), and no network-scanning package.
- Caveat: a physical-device **release** build pointed at a private LAN IP over
  HTTP (`--dart-define=API_BASE_URL=http://192.168.x.x:3000` +
  `ALLOW_INSECURE_LOCAL_API=true`) does trigger the prompt, because iOS treats
  a LAN destination as local-network use. A production HTTPS build does not.

## Open / deferred

- H-12 certificate pinning, M-10 session revocation, M-11 email verification +
  captcha (unchanged from the security phase).
- Onboarding location request is untested on a real device (no device here).
