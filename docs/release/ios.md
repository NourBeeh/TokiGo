# iOS build & run runbook

The iOS project is configured (`com.tokigo.tokigo`, iOS 15.0+, display name
"Toki Go"). Building and running it requires macOS with Xcode — Linux cannot
compile or sign iOS binaries. This document is the checklist for that Mac.

## 1. Prerequisites (Mac)

- macOS 14+ with Xcode 16+ (App Store, then `sudo xcodebuild -license accept`).
- Command line tools: `xcode-select --install`.
- Flutter **3.50.0** stable: `flutter --version`.
- CocoaPods: `sudo gem install cocoapods` (or Homebrew). Needed because two
  plugins (`flutter_secure_storage`, `path_provider_foundation`) do not ship a
  Swift Package yet; Flutter falls back to CocoaPods for those.

First checkout on the Mac:

```bash
flutter pub get
flutter run -d "iPhone 16"   # first run also creates ios/Podfile and installs Pods
```

Flutter creates `ios/Podfile` and runs `pod install` automatically on the first
macOS build because `flutter_secure_storage` and `path_provider_foundation` do
not ship a Swift Package yet. Afterwards you can open
`ios/Runner.xcworkspace` (always the workspace, never the `.xcodeproj`) or run
`cd ios && pod install` by hand.

## 2. Simulator run

```bash
flutter devices
flutter run -d "iPhone 16"
```

Notes:

- The backend defaults to `http://localhost:3000`. In the simulator `localhost`
  is the Mac, so start the backend locally and it works.
- Google Sign-In on iOS needs an iOS OAuth client ID and its reversed URL scheme.
  Both are already in `ios/Runner/Info.plist` and in
  `lib/core/auth/google_auth_config.dart` (`GOOGLE_IOS_CLIENT_ID`). Override at
  build time if you use another project:
  `--dart-define=GOOGLE_IOS_CLIENT_ID=<id>.apps.googleusercontent.com`
- Permissions requested: location (nearby departure airport), photo library
  (profile avatar), microphone + speech recognition (voice search). Usage
  strings are in `Info.plist`; `permission_handler_apple` maps them to its
  compile-time permission flags automatically through Swift Package Manager.

## 3. Physical device run

1. Connect the iPhone, trust it, enable Developer Mode
   (Settings → Privacy & Security → Developer Mode).
2. In Xcode: *Runner → Signing & Capabilities* → choose your Apple team, set a
   unique bundle identifier if needed (default `com.tokigo.tokigo`), then let
   Xcode create the provisioning profile.
3. `localhost` on the phone is the phone itself. Point the app at the Mac's LAN
   address:

```bash
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=http://192.168.1.3:3000 \
  --dart-define=ALLOW_INSECURE_LOCAL_API=true
```

`ALLOW_INSECURE_LOCAL_API` is required for plain HTTP and is accepted only for
private LAN addresses (`10.x`, `172.16–31.x`, `192.168.x`). Production builds
must use HTTPS; the API client refuses plaintext otherwise.

## 4. Release / TestFlight

```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://<production-host> \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id> \
  --dart-define=GOOGLE_IOS_CLIENT_ID=<ios-client-id>
```

- Signing must be configured in Xcode first (team + provisioning profile).
- App Store Connect: create the app record with bundle ID `com.tokigo.tokigo`,
  then upload `build/ios/ipa/*.ipa` with Transporter or `xcrun altool`.
- `ITSAppUsesNonExemptEncryption=false` is set in `Info.plist`, so the export
  compliance question is answered automatically (the app only uses standard
  HTTPS/TLS).

## 5. Unsigned builds (CI only)

`.github/workflows/ios-build.yml` (GitHub Actions, `macos-15`) and the
`ios-unsigned` workflow in `codemagic.yaml` run
`flutter build ios --release --no-codesign` and package
`build/ios/iphoneos/Runner.app` into `TokiGo-unsigned.ipa`.

An unsigned IPA cannot be installed on a stock iPhone. Use it for CI
verification only; for real devices push a signed build through Xcode /
TestFlight.

## 6. Troubleshooting

- `Podfile missing` / plugin not found: run `flutter pub get`, then a macOS
  `flutter run`/`flutter build ios` once so Flutter generates `ios/Podfile` and
  installs the pods, or run `cd ios && pod install` after the Podfile exists.
  Delete `ios/Podfile.lock` and `ios/Pods` if a plugin was removed.
- Stale native build after switching branches: `flutter clean && flutter pub get`
  then `cd ios && pod install`.
- Signing error `No profiles for 'com.tokigo.tokigo'`: pick the team in Xcode
  (per-developer setting; not committed) or change the bundle ID to one you own.
- Voice search silent: check microphone + speech recognition in
  Settings → Privacy, and that the iPhone is not in silent mode for the first
  recognition prompt.
