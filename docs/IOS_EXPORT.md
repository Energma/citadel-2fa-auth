# Citadel Auth — iOS Export

Status as of 2026-07-17. Branch: `EI-44-citadel-make-ios-build`. Tracks `EI-45`.

## ✅ Done & verified in code

| Area | State | Evidence |
|---|---|---|
| iOS project scaffold | `ios/Runner.xcodeproj`, `Podfile`, `Podfile.lock` generated and building | `flutter build ios` succeeds |
| Bundle identifier | `com.citadelauth.citadelAuth` | `ios/Runner.xcodeproj/project.pbxproj` |
| Simulator build | `./dev.sh ios` / `./dev.sh build ios` → debug `.app` for the simulator | `flutter build ios --simulator --debug` |
| Unsigned device build | `./dev.sh ios-device` / `./dev.sh build ios-device` → release `.app` for real device architecture, unsigned | `flutter build ios --release --no-codesign` |
| IPA export command | `./dev.sh ipa` / `./dev.sh build ipa` → wraps `flutter build ipa` with `ios/ExportOptions.plist` | see below — **will not succeed until signing is configured**, see ⚠️ below |

## ⚠️ Blocked: signing

`ios/Runner.xcodeproj` has `CODE_SIGN_STYLE = Automatic` but **no `DEVELOPMENT_TEAM` set**. Archiving an `.ipa` (unlike a plain `.app` build) always requires a valid signing identity — there's no `--no-codesign` equivalent for the export step. This is out of reach in this environment: it needs Energma's actual Apple Developer Program membership, which isn't available here.

To finish this once someone has access to Energma's Apple Developer account:
1. Open `ios/Runner.xcworkspace` in Xcode (not `.xcodeproj` — CocoaPods requires the workspace).
2. Select the `Runner` target → **Signing & Capabilities** → sign in with the Energma Apple ID and pick the Energma **Team**.
3. Xcode will create/download a development (or ad-hoc) provisioning profile for `com.citadelauth.citadelAuth` automatically under `Automatic` signing.
4. Copy the Team ID (Xcode → Account → Membership Details, or `xcodebuild -showBuildSettings | grep DEVELOPMENT_TEAM` once configured) into `ios/ExportOptions.plist`'s `teamID` field, replacing `REPLACE_WITH_ENERGMA_TEAM_ID`.
5. For ad-hoc distribution (install directly on specific iPhones without TestFlight), register each test device's UDID in the Apple Developer portal first, then change `ExportOptions.plist`'s `method` from `development` to `ad-hoc`.
6. Run `./dev.sh build ipa` — this runs codegen, then `flutter build ipa --export-options-plist=ios/ExportOptions.plist`, producing `build/ios/ipa/citadel_auth.ipa`.

## 📱 Must verify on a real device once signing works
- [ ] Install the `.ipa` via Xcode (Window → Devices and Simulators → drag the `.ipa`) or Apple Configurator.
- [ ] App launches without crashing.
- [ ] Core Citadel flows work: add a token (QR + manual entry), generate TOTP/HOTP codes, biometric/PIN unlock, encrypted backup import/export.
- [ ] No platform-specific crashes (watch for `local_auth`/`flutter_secure_storage` iOS-only code paths).

Per `EI-45`'s notes, App Store submission and TestFlight are explicitly **out of scope** for this story — a signed ad-hoc/development `.ipa` that installs and runs is the bar.

## 🤖 CI automation — deliberately deferred
There is no CI pipeline for this project yet (no `.github/workflows`, no other CI config). Wiring the iOS export into CI now would mean standing up a whole macOS CI pipeline (and securely storing Energma's signing certificate + provisioning profile as CI secrets) just for this one story. That's a separate, larger effort — revisit once the project has CI for anything else. Until then, the export stays a documented manual process via `./dev.sh build ipa`.

## Known gaps
- `ExportOptions.plist`'s `teamID` is a placeholder (`REPLACE_WITH_ENERGMA_TEAM_ID`) — must be filled in with the real Energma Team ID before `./dev.sh build ipa` can succeed.
- No physical-device verification has been done from this environment (no iPhone / signing access here).
