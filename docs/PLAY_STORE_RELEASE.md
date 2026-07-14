# Citadel Auth — Google Play Release Checklist

Status as of 2026-06-17. Branch: `release-prep-backup-import`.

## ✅ Done & verified in code/build

| Area | State | Evidence |
|---|---|---|
| Release signing | Real keystore, `.aab` signed with release cert (not debug) | `jarsigner -verify` → `CN=Citadel Auth, O=Energma`; gradle reads `android/key.properties` (gitignored) |
| Target SDK | `targetSdk=36`, `compileSdk=36`, `minSdk=24` | Exceeds Play's API 35 minimum |
| Version | `versionName=0.2.0`, `versionCode=3` | `pubspec.yaml` (`0.2.0+3`) — bump `versionCode` for every upload |
| Permissions | `CAMERA`, `USE_BIOMETRIC`, `USE_FINGERPRINT` only | `aapt2 dump permissions` on release APK |
| Network | **None** — `INTERNET` / `ACCESS_NETWORK_STATE` stripped via manifest merger | matches "No cloud. No telemetry." |
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
- [ ] Create app, set name "Citadel Auth", category, contact details.
- [ ] **Privacy policy URL**: https://www.energma.co/privacy-policy (already linked in-app).
- [ ] Complete **Data Safety** form (see answers above).
- [ ] **Content rating** questionnaire (Utility/Tools → likely Everyone).
- [ ] Store listing assets: icon (512×512), feature graphic (1024×500), ≥2 phone screenshots.
- [ ] Target audience & content (not directed at children).
- [ ] Upload `.aab` to **Internal testing** track first; run the **pre-launch report** before production.

## ⚠️ Known non-blockers
- Master password is stored in secure storage (encrypted) to enable PIN-only unlock — documented tradeoff, not a leak.
- 3 `deprecated_member_use` lints remain (cosmetic).
- No widget/integration tests for the PIN re-key flow (needs an emulator/`integration_test`); the crypto and data layers are unit-tested.

## 🔑 Keystore — back this up offline
`~/citadel-release.jks` + its password are the ONLY way to publish updates. If lost, you can never update this app on Play again. Store both in a password manager / offline backup.
