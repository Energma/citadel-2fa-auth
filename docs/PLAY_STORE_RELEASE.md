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
./dev.sh aab   # release appbundle with config/prod.json → build/app/outputs/bundle/release/app-release.aab (~76 MB)
```
Upload the **.aab** (not the universal APK). Bump the `+N` build number in `pubspec.yaml` first: Play rejects
any versionCode it has already seen.

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

Play App Signing is on: Google re-signs what users install, and our key is only the **upload key**. A lost
upload key can be replaced by a reset in Play Console (Setup → App integrity). Export the new key's public cert with
`keytool -export -rfc -alias citadel -keystore ~/citadel-release.jks -file upload_certificate.pem` and submit that.

| Certificate | SHA-256 | Notes |
|---|---|---|
| Upload key, current (`~/citadel-release.jks`, created 2026-11-16) | `46:A2:FC:1A:09:E0:AC:E9:CD:2B:77:33:13:97:00:51:6B:FF:5D:F4:08:1B:93:83:65:59:23:4B:F4:C2:44:07` | Submitted for upload-key reset 2026-11-18; signs 1.0.2+5 onward |
| Upload key, previous (created 2026-08-20) | `09:8C:29:3A:90:4D:E5:C5:49:0F:7C:B6:C6:D9:F4:70:AD:C8:2E:19:FE:FF:54:AD:D9:D0:2B:09:79:5C:10:A6` | Private key not found; replaced by the reset |
| Google app-signing key (`deployment_cert.der`) | `E1:D3:49:4C:1F:7B:65:10:99:5F:1A:05:8E:45:B0:7C:9E:AB:C4:98:FC:14:0B:43:35:B5:EA:85:04:E2:D4:AB` | What installed apps are signed with |
