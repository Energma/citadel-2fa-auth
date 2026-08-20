# Citadel Auth — Google Play Release Checklist

Status as of 2026-08-20. Refreshed after the applicationId rename and 1.0.0 version bump; original checklist dated 2026-06-17 on `release-prep-backup-import`.

## ✅ Done & verified in code/build

| Area | State | Evidence |
|---|---|---|
| Release signing | Real keystore, `.aab` signed with release cert (not debug) | `jarsigner -verify` → `CN=Citadel Auth, O=Energma`; gradle reads `android/key.properties` (gitignored) |
| Application ID | `com.energma.citadel2fa` | `android/app/build.gradle.kts` (`namespace` + `applicationId`); renamed from `com.citadelauth.citadel_auth` 2026-08-17. Old build stays installed as a separate app on any device that had it — not an in-place upgrade. |
| Target SDK | `targetSdk=36`, `compileSdk=36`, `minSdk=24` | Exceeds Play's API 35 minimum — re-verify with `aapt2 dump badging` on the next release APK/AAB since these resolve from the Flutter SDK's defaults and aren't pinned in this repo |
| Version | `versionName=1.0.0`, `versionCode=1` | `pubspec.yaml` (`1.0.0+1`) — bump `versionCode` for every upload |
| Permissions | `CAMERA`, `USE_BIOMETRIC`, `USE_FINGERPRINT` only | `aapt2 dump permissions` on release APK |
| Network | **None functionally reachable** — `INTERNET` / `ACCESS_NETWORK_STATE` stripped via manifest merger in the release build | matches "No cloud. No telemetry." One documented exception: `lib/ui/widgets/service_icon.dart` has a favicon-fetch fallback (`https://www.google.com/s2/favicons?domain=...`) for unrecognized token issuers. It's dead code at runtime in release builds (no INTERNET permission → request never leaves the device, silently falls back to a letter-avatar icon) but is present in source — see the Data Safety note below. |
| Data at rest | SQLCipher (AES-256) + Argon2id; `allowBackup=false`, `fullBackupContent=false` | prevents adb backup of the vault |
| Screen privacy | `FLAG_SECURE` (Android) + iOS snapshot overlay | blocks screenshots / recents preview |
| Code minification | R8 + ProGuard rules | `isMinifyEnabled = true` |
| Tests | 66 passing (OTP engine, crypto, import/export incl. encrypted backup, models, repositories) | `fvm flutter test` |

### Permission justifications (for the review form)
- **CAMERA** — scan otpauth QR codes to add 2FA tokens. Declared `uses-feature-not-required` so camera-less devices can still install.
- **USE_BIOMETRIC / USE_FINGERPRINT** — optional biometric unlock of the local vault.

### Data Safety form answers (no network = simple)
- Data collected: **None.** Data shared: **None.** No analytics, no accounts, no cloud.
- All token secrets stay on-device, encrypted. Backups are user-initiated local files (optionally password-encrypted).
- Reviewer note (optional free-text field): `service_icon.dart`'s favicon-fallback fetch is present in source but inert — the release manifest strips `INTERNET`/`ACCESS_NETWORK_STATE`, so the request never executes. If it did, it would only send a guessed domain derived from the issuer name typed by the user (e.g. `github.com`) to Google's favicon endpoint — never a token secret, account value, or any other vault content. Doesn't change the "no data collected/shared" answer.

## 🔧 Build the upload artifact
```bash
fvm flutter build appbundle   # produces app-release.aab (~61 MB; per-ABI split via .aab)
```
Upload the **.aab** (not the universal APK).

## 📱 Must verify on a real device before submitting
- [ ] **QR scanning works offline** — we stripped INTERNET; the bundled ML Kit model should scan without network. Confirm on a device with no connectivity.
- [ ] Biometric unlock enrol + unlock.
- [ ] First-run setup now **requires both master password and a PIN**; subsequent unlock is PIN-only.
- [ ] Import a `.citadel.enc` encrypted backup (decryption path added this cycle).

## 📋 Play Console steps (manual — outside the codebase)
- [ ] Create app, set name "Citadel Auth", category (Tools/Utility), contact details.
- [ ] **Support email**: placeholder `support@energma.co` used in `docs/store-assets/listing-copy.md` — **swap for the real address before submitting**.
- [ ] **Privacy policy URL**: https://www.energma.co/privacy-policy (already linked in-app).
- [ ] Complete **Data Safety** form (see answers above and `docs/store-assets/listing-copy.md`).
- [ ] **Content rating** questionnaire (Utility/Tools → likely Everyone) — answers drafted in `docs/store-assets/listing-copy.md`.
- [ ] Store listing assets (all in `docs/store-assets/`): icon-512.png, feature-graphic-1024x500.png, 4 screenshots (screenshot-1-home.png … screenshot-4-settings.png).
- [ ] Short/long description text: `docs/store-assets/listing-copy.md`.
- [ ] Target audience & content (not directed at children).
- [ ] Upload `.aab` to **Internal testing** track first; run the **pre-launch report** before production.

## ⚠️ Known non-blockers
- Master password is stored in secure storage (encrypted) to enable PIN-only unlock — documented tradeoff, not a leak.
- 3 `deprecated_member_use` lints remain (cosmetic).
- No widget/integration tests for the PIN re-key flow (needs an emulator/`integration_test`); the crypto and data layers are unit-tested.

## 🔑 Keystore — back this up offline
`~/citadel-release.jks` + its password are the ONLY way to publish updates. If lost, you can never update this app on Play again. Store both in a password manager / offline backup.
