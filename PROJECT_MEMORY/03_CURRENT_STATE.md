# 03 — Current State

Last updated: 2026-11-05 (session: Home UX + app icon pass)

## Build / verification

- `flutter analyze`: 0 errors (95 pre-existing warnings, all in untouched files).
- `flutter test`: 230 passed, 0 failed.
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
- The row is **six** tiles: Flights, Stays, Cars Rental, Activities, Groups,
  Trips. `HomeAction` gained `activities` and `groups`; Activities opens the
  packages/tour search, Groups opens the existing Groups page.
- Tile height 88 → **68** (still ≥44dp tap target).
- Light-mode Home accent is Action Ink `#111111` (`HomeDesignTokens.accent`),
  not red; pressed surface is neutral `#F5F5F5`. Dark mode unchanged.
- The "Use your location…" card was removed from Home, together with
  `LocationPermissionCard` and `locationPromptDismissedProvider`.
  Location ("when in use" only) is now requested from the Onboarding
  Permissions step via `requestLocationAccess(ref)`; a denial never blocks.
- Empty/offline states are centred in the feed's remaining viewport
  (`SliverFillRemaining` + `_CenteredFeedState`) and scroll only if the
  content genuinely cannot fit.

## App icon (this pass)

- Master artwork: `assets/icon/app_icon.svg` (1024x1024, full-bleed).
- Generator: `tool/branding/generate_app_icon.py` (fontTools → outlines) and
  `tool/branding/render_svg.js` (npm `@resvg/resvg-js`; `npm install` in
  `tool/branding`). The generator now self-checks: non-empty "Go" outlines,
  everything inside the viewBox, a cap-height floor for 29pt legibility, and
  the adaptive safe-zone diagonal.
- Brand red `#FF2D2D` (= `AppColors.brandRed`, sampled from the "Go" of
  `assets/branding/logo_wordmark.png`); umbrella + "Go" white `#FFFFFF`;
  "Go" is Manrope ExtraBold (wght 800) converted to SVG paths, tracking
  −0.012em (matches `AppWordmark`).
- Exports: `app_icon_1024.png` (iOS, opaque, "Go" cap = 30.9% of the canvas),
  `app_icon_adaptive_foreground_1024.png` (group inside the central 66% safe
  zone, diagonal 658 ≤ 676, "Go" cap = 20.5%),
  `app_icon_adaptive_monochrome_1024.png` (transparent background, white
  artwork, for Android 13+ themed icons).
- `flutter_launcher_icons` regenerated every `mipmap-*`/`drawable-*` icon and
  `ios/Runner/Assets.xcassets/AppIcon.appiconset`. The stale
  `drawable-night/ic_launcher_foreground.png` was removed.
- Display name is now "Toki Go" everywhere: iOS `CFBundleDisplayName` and
  Android `android:label`.
- Verified by pixel analysis: every final asset has exactly two white blobs in
  its lower half (the `G` and the `o`), and no white touches the outer edge
  (nothing clipped). "Go" reads at 29px and 60px.

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
