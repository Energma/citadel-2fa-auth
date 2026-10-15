# Citadel Auth — iOS Export

Updated for `EI-51` (signed production build). Earlier work: `EI-44` / `EI-45`.

## ✅ Done & verified in code

| Area | State | Evidence |
|---|---|---|
| iOS project scaffold | `ios/Runner.xcodeproj`, `Podfile`, `Podfile.lock` generated and building | `flutter build ios` succeeds |
| Bundle identifier | `com.energma.citadel2fa` | `ios/Runner.xcodeproj/project.pbxproj` |
| Simulator build | `./dev.sh ios` / `./dev.sh build ios` → debug `.app` for the simulator | `flutter build ios --simulator --debug` |
| Unsigned device build | `./dev.sh ios-device` / `./dev.sh build ios-device` → release `.app` for real device architecture, unsigned | `flutter build ios --release --no-codesign` |
| IPA export command | `./dev.sh ipa` / `./dev.sh build ipa` → wraps `flutter build ipa` with `config/prod.json` and `ios/ExportOptions.plist` | see "Production build" below |

## Production build (EI-51)

| Setting | Value |
|---|---|
| Bundle identifier | `com.energma.citadel2fa` (same as Android; was `com.citadelauth.citadelAuth`) |
| Team ID | `3MJ855B7PM` (`DEVELOPMENT_TEAM` in `project.pbxproj`, `teamID` in `ios/ExportOptions.plist`) |
| Export method | `app-store-connect` |
| Signing | Automatic (Xcode manages certificate + provisioning profile) |
| Security flags | `config/prod.json` — screenshots and screen recording blocked, app-switcher snapshot hidden |

`./dev.sh ipa` / `./dev.sh build ipa` runs `flutter build ipa --dart-define-from-file=config/prod.json --export-options-plist=ios/ExportOptions.plist` and writes `build/ios/ipa/*.ipa`. Everything else matches the dev build.

### One-time setup
1. In Xcode → Settings → Accounts, sign in with the Energma Apple Developer account (the account must have a role that can create certificates and profiles).
2. Confirm `com.energma.citadel2fa` is available: Apple Developer portal → Certificates, Identifiers & Profiles → Identifiers. Automatic signing registers it on the first archive if it is free; if another team owns it, the archive fails with a "bundle identifier is not available" error and a different ID is needed.
3. For uploads, create an app record with this bundle ID in App Store Connect.
4. Run `./dev.sh ipa`, then upload the `.ipa` via Transporter or `xcrun altool`.

The old bundle ID was never shipped, so there is no upgrade path to preserve. Any dev build with the old ID installs as a separate app.

## 📱 Must verify on a real device
- [ ] Install via TestFlight (or Xcode) — app launches without crashing.
- [ ] Screenshots are blocked/blacked out, screen recording shows no app content, and the app-switcher thumbnail is hidden.
- [ ] Core Citadel flows work: add a token (QR + manual entry), generate TOTP/HOTP codes, biometric/PIN unlock, encrypted backup import/export.
- [ ] No platform-specific crashes (watch for `local_auth`/`flutter_secure_storage` iOS-only code paths).

## 🤖 CI automation — deliberately deferred
There is no CI pipeline for this project yet (no `.github/workflows`, no other CI config). Wiring the iOS export into CI now would mean standing up a whole macOS CI pipeline (and securely storing Energma's signing certificate + provisioning profile as CI secrets) just for this one story. That's a separate, larger effort — revisit once the project has CI for anything else. Until then, the export stays a documented manual process via `./dev.sh build ipa`.

## Known gaps
- No physical-device verification has been done from the dev environment; see the checklist above.
