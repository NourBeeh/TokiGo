# 03 — Current State

Last updated: 2026-11-06 (session: Home UX + app icon, floating composer, Home disabled by flag, navigation cleanup)

## Build / verification

- `flutter analyze`: 0 errors.
- `flutter test`: all green (260 + tests; see the resume sections below).

## HOME IS DISABLED BY FLAG (Task 11, 2026-11)

`AppConfig.homeEnabled = false` (`lib/app/config/app_config.dart`). **Why:** the
owner wants the app to reopen on the traveller's last visited section instead of
re-rendering the Home feed, and to keep every service one tap away without
Home. Nothing is deleted — `HomePage`, `home_controller` and the Home providers
are untouched; only the router reads the flag. Flipping it back to `true`
restores Home exactly as it was.

- **Resume target** = the saved browse location when it is still valid, else
  `/flights` (`resolveResumeTarget` in `lib/core/navigation/resume_destination.dart`).
- **Persisted** by `ResumeDestinationStore` (`lib/core/storage/resume_destination_store.dart`)
  in the same Hive `tokigo_settings` box as the onboarding flag, written
  debounced (1s) from a `router.routerDelegate` listener, and **cleared on
  logout**.
- **Allowlist** (`kSavableResumePaths`): `/flights`, `/hotels`, `/cars`,
  `/packages`, `/groups`, `/bag`. The booking funnel, offer details,
  onboarding, auth, notifications, Profile, Wishlist and anything with a
  short-lived id are never saved or restored. Profile and Wishlist behave
  like Notifications: reachable from the header, never a cold-start target.
- **Top bar paths** (`kTopBarPaths`): the same six service paths, kept as a
  SEPARATE set because the bar is chrome for the service surfaces while the
  resume allowlist also decides what a cold start may reopen on. Profile and
  Wishlist are standalone pages — they keep their own header and back button,
  so they must never grow a top bar.
- **Pinned replacement**: `ResumeTopBar` (`lib/app/widgets/resume_top_bar.dart`)
  — the shared `HomeTopBar` (wordmark, bell, profile) above the quick-action
  row — rendered by `TokiGoShell` on the six service paths (`kTopBarPaths`).
  The resume button is **unpinned** (`AppConfig.showResumeButton = false`, owner
  decision 2026-11): the bar keeps only those two rows, so it reserves no
  height for a button it does not draw. `ResumeButton`, `ResumeDestinationStore`
  and the restore-on-launch logic all stay in place — flip the flag back to
  `true` to re-attach it. `HomeActionBar` is unchanged and still the tile
  inventory.
- **Deep links still win**: `GoRouter.initialLocation` is only a fallback
  (`overridePlatformDefaultLocation` is false), so a platform deep link
  overrides the restore.
- Restore is unit-tested (`resolveResumeTarget`, the allowlist, the store
  round-trip) and the button has widget tests
  (`test/resume_destination_test.dart`, `test/resume_top_bar_test.dart`).

### Regressions fixed (Task 12)

- **Bell + profile are reachable again.** `_HomeTopBar` was extracted into the
  shared `HomeTopBar` (`lib/features/home/presentation/widgets/home_top_bar.dart`)
  and `ResumeTopBar` now renders it above the quick-action row — wordmark,
  `AnimatedNotificationBell` and the avatar, same sizes and behaviour. Both
  hosts render it exactly once.
- **No double header.** `ResumeTopBarScope` (an `InheritedWidget` the shell
  wraps the navigation stack in) tells the top-level browse pages that the bar
  replaced their own header; `AppPageHeader.visible` hides it there. Flights,
  Stays, Cars, Activities (`SearchScaffold`), Groups and Bag pass it. Every
  other page — including pushed detail routes — keeps its header and back
  button.
- **No colour seam.** The bar paints `context.tokigoColors.background`, the
  same token `SearchScaffold`'s Scaffold uses; the hardcoded Home beige
  (`#FAF8F5`) is gone. Light and dark both resolve through the theme, and the
  bar's `ColoredBox` sits outside its `SafeArea`, so the status-bar area is the
  same colour too.
- **Safe query strings survive.** `sanitizeResumeLocation` keeps only the
  per-route allowlisted parameters (`kResumeQueryAllowlist`): `/bag?section=likes`
  restores as `/bag?section=likes`, while `/bag?id=123` and `/flights?tab=radar`
  collapse to the bare path. `router.state.uri` (not `matchedLocation`) is what
  gets saved, and `currentLocationProvider` carries the full URI so the button's
  selected state still matches.
- **Router-level restore tests** (`test/resume_router_test.dart`): no saved
  value, a valid saved value, a stale/unknown path, `/profile` while signed out,
  a platform deep link overriding the restore, `homeEnabled: true` returning to
  Home, and logout clearing the saved value.
- Two robustness fixes found while testing: `AuthController._restore` and
  `OnboardingController._load` no longer write state after disposal, and
  `OnboardingController.pinned` lets tests pin the gate deterministically.

### Resume button unpinned (Task 13, 2026-11)

`AppConfig.showResumeButton = false`: `ResumeTopBar` now renders only the
`HomeTopBar` row and the `HomeActionBar` row, and reserves nothing for the
button (`if (AppConfig.showResumeButton) ...[SizedBox, ResumeButton]`). The
button widget itself stays in `resume_top_bar.dart`, and
`ResumeDestinationStore` plus the restore-on-launch logic are untouched — the
app still reopens on the last visited page. `test/resume_top_bar_test.dart`
asserts the button is absent from the bar, that the bar's height equals its two
rows plus their own padding in light **and** dark, and that no gap is left where
the button used to be; the button's own navigation test now renders it
standalone.

### Navigation cleanup (Task 14, 2026-11)

- **Re-tap is a no-op, never Home.** `ResumeTopBar._openAction` returns early
  when the current router path already equals the target path (no `go`, no
  `push`, no rebuild; the tile's own haptic feedback still fires). The active
  service is passed to `HomeActionBar` as `selectedAction`, derived from the
  router location via `HomeAction.fromPath`, so the current tile shows its
  selected state.
- **No path lands on '/' while Home is off.** `homeRoute()` (in
  `lib/core/navigation/resume_destination.dart`) returns '/' only when
  `AppConfig.homeEnabled` is true, otherwise `kDefaultResumePath`. Audited and
  fixed: `AppBackButton`/`AppPageHeader` fallback defaults (now nullable →
  `homeRoute()`), the auth-success redirect and the Groups redirect (both →
  the saved resume target), the City "not found" fallback, and the hotel
  results "Discover more" hand-off. The legacy in-page Home switcher
  (`HomePage._selectAction`) is dormant, marked with a comment, and kept.
- **Profile and Wishlist are standalone.** Removed from
  `kSavableResumePaths`; the shell's top bar now keys off the separate
  `kTopBarPaths` (the six service paths only). They keep their own header and
  back button, and the shell no longer strips their status-bar inset.
- **Groups has no back button as a top-level page.** The header stays hidden
  through `ResumeTopBarScope`; the dead redirect to '/' is gone (a disabled
  Groups route now redirects to the resume target).
- **System Back on a top-level service page exits.** `context.go` replaces the
  root, so `router.canPop()` is false there; Back never loops to Home or to
  another service.
- Tests: `test/resume_top_bar_test.dart` (re-tap no-op + no Home, selected
  state, cannot-pop), `test/resume_shell_test.dart` (top bar only on the six
  service paths, Groups back button, status-bar inset),
  `test/resume_destination_test.dart` (allowlist, `kTopBarPaths`, `homeRoute`),
  `test/resume_router_test.dart` (Profile/Wishlist never restored).

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
