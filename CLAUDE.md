# Citadel Auth — Development Guide

## Project Overview

Citadel Auth is a privacy-first 2FA authenticator built with Flutter. It generates TOTP/HOTP codes and stores all secrets locally in an encrypted SQLite database.

## Development Commands

Always use the `./dev.sh` helper script instead of running Flutter directly:

```bash
./dev.sh start             # Launch emulator + run app
./dev.sh get               # pub get
./dev.sh build             # build_runner code generation
./dev.sh build android     # build_runner, then build debug APK
./dev.sh build ios         # build_runner, then build debug iOS app (simulator)
./dev.sh build ios-device  # build_runner, then build unsigned release iOS app (device)
./dev.sh build ipa         # build_runner, then export a signed .ipa
./dev.sh test              # Run tests
./dev.sh clean             # Clean + re-get
./dev.sh android           # Build debug APK
./dev.sh ios               # Build debug iOS app (simulator)
./dev.sh ios-device        # Build unsigned release iOS app (device)
./dev.sh ipa               # Export a signed .ipa
```

`ios-device` builds `Runner.app` unsigned (`--no-codesign`) for real iPhone hardware, since the Xcode project has no `DEVELOPMENT_TEAM` configured. `ipa` runs `flutter build ipa --export-options-plist=ios/ExportOptions.plist` — this needs Energma's Apple Developer Team ID filled into that plist first (signing can't be skipped for an `.ipa` export the way it can for a plain `.app` build). See `docs/IOS_EXPORT.md` for the full signing setup and verification checklist.

The project uses FVM — all Flutter commands go through `fvm flutter`.

## Architecture

- **State management:** Riverpod (with riverpod_generator for codegen)
- **Database:** SQLCipher (encrypted SQLite), schema version 2
- **Encryption:** Argon2id key derivation → AES-256-GCM
- **Platform services:** `local_auth` for biometrics, `flutter_secure_storage` for keystore

### Key directories

- `lib/core/` — Models, providers, and crypto (OTP engine, vault encryption, import/export)
- `lib/data/` — Database layer and repositories
- `lib/platform/` — Platform service wrappers (biometrics, keystore)
- `lib/ui/` — Screens, widgets, and theme

### State flow

The app uses a vault state machine: `Uninitialized → Locked → Unlocked`. The `vaultProvider` in `lib/core/providers.dart` is the central state holder. Tokens are filtered by the active profile via `tokenListProvider`.

## Code Style

- Dart with Flutter lints (`flutter_lints`)
- Models use `json_serializable` — run `./dev.sh build` after changing model classes
- Riverpod providers use annotations (`@riverpod`) — also requires build_runner

## Important Patterns

- Token secrets are always encrypted at rest — never log or print them
- All database operations go through repository classes in `lib/data/repositories/`
- OTP code generation is in `lib/core/crypto/otp_engine.dart` — RFC 6238 (TOTP) and RFC 4226 (HOTP)
- Import/export supports multiple formats (Citadel, Aegis, 2FAS, Ente Auth) in `lib/core/crypto/import_export.dart`
- Profiles have color coding and sort order; groups organize tokens within profiles
- Auto-lock triggers on `AppLifecycleState.paused` with configurable timeout

## Testing

```bash
./dev.sh test
```

## Common Tasks

- **Add a new screen:** Create in `lib/ui/screens/`, add route in `main.dart`
- **Add a provider:** Add to `lib/core/providers.dart` with `@riverpod` annotation, then run `./dev.sh build`
- **Modify models:** Edit in `lib/core/models/`, run `./dev.sh build` for JSON serialization
- **Database schema change:** Update `lib/data/database/vault_database.dart`, increment version, add migration

## Commit policy

Never add AI/assistant attribution to commits or PRs — no `Co-Authored-By: Claude`,
no "Generated with Claude Code". Commits are authored by people. A `commit-msg` hook
in `.githooks/` strips these automatically; the repo sets `core.hooksPath=.githooks`.
After cloning, run `git config core.hooksPath .githooks` to enable it.
