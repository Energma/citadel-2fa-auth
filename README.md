# Citadel Auth

**Privacy-first 2FA authenticator. Your secrets stay on your device.**

Citadel Auth is an offline-first two-factor authentication app built with Flutter. There are no accounts, no cloud sync, and no telemetry — the Android build ships with the `INTERNET` permission removed, so the app is structurally incapable of making a network request.

Current version: `0.2.1+4`

## Features

### Authentication codes
- **TOTP** (time-based) — RFC 6238
- **HOTP** (counter-based) — RFC 4226
- Selectable algorithm: SHA-1, SHA-256, SHA-512
- Selectable digits: 6, 7, or 8
- Selectable period: 30s, 60s, or 90s

> Steam Guard is **not** supported. Steam uses a non-standard 5-character alphabet; importing a Steam secret would produce ordinary numeric codes that do not work.

### Adding tokens
- QR code scanning
- Manual entry
- `otpauth://` URI import

### Security
- **Vault database:** encrypted at the file level with **SQLCipher**, keyed by a passphrase derived from your master password (and PIN, if you set one). SQLCipher applies its own PBKDF2-HMAC-SHA512 key derivation.
- **Encrypted backups:** export files are encrypted separately with **Argon2id** (64 MB, 3 iterations) → **AES-256-GCM**. This is the backup format only; it is not what protects the vault database.
- Master password, minimum 8 characters.
- Unlock with the **phone's screen lock** (fingerprint, face, PIN, or pattern) or with an optional **6-digit app PIN** that is mixed into the encryption key.
- Auto-lock: immediately, 1, 5, 15, 30 minutes, or 1 hour.
- Screenshots and screen recording are blocked, and app contents are hidden in the recent-apps switcher.
- Destructive actions (deleting a token, deleting a profile, exporting) require the master password.

#### What is stored, and where

Being precise here matters more than sounding impressive:

- Token secrets live only inside the SQLCipher database.
- To let you unlock with a fingerprint instead of retyping your master password on every launch, the app stores the master password **and** the vault key in platform secure storage (Android Keystore via `EncryptedSharedPreferences`; iOS Keychain). They are encrypted at rest, but they **are stored and are recoverable by the app**.
- Consequently the master password is *not* "unrecoverable by design." That is the deliberate trade for not having to retype it on every open. If you need the stronger property, the vault key would have to be wrapped separately by the password and by a biometric-bound keystore key — that is not what the app does today.
- The app PIN itself is never stored. Whether it decrypts the vault *is* the check.

### Organization
- **Profiles** — separate contexts (Personal, Work, …) with color coding
- **Groups** — categories inside a profile; empty groups still show, so the structure is visible
- Pin tokens to the top
- Tag tokens
- Search across all tokens

### Import & export
- **Export:** Citadel JSON, `otpauth://` URI list, or an encrypted backup (Argon2id + AES-256-GCM). Backups are written to the device; there is no share sheet.
- **Import:** Citadel Auth, Aegis Authenticator, 2FAS Authenticator, Ente Auth, and plain `otpauth://` URI lists.

### Appearance
- Material 3, light and dark themes
- **Personal Theme** — pick an accent color (8 presets or a custom hue). Buttons, chips, and highlights follow it; foreground colors are contrast-picked so light accents stay readable.
- Live countdown rings, swipe actions, one-tap copy

## Getting started

### Prerequisites
- [Flutter](https://flutter.dev/) 3.41+ (Dart SDK `^3.11.1`)
- [FVM](https://fvm.app/) — the project pins its Flutter version
- Android SDK

### Setup

```bash
git clone <repo-url>
cd citadel
fvm install
./dev.sh get
git config core.hooksPath .githooks   # enables the commit-msg hook
```

### Development

Use `./dev.sh` rather than calling Flutter directly:

```bash
./dev.sh start   # launch the emulator and run the app
./dev.sh get     # pub get
./dev.sh build   # build_runner code generation
./dev.sh test    # run tests
./dev.sh clean   # clean + re-fetch
```

### Build profiles

Security is on by default. A build with no flags behaves exactly like a production build, so a release can never accidentally ship with security relaxed.

```bash
./dev.sh release prod   # default — screenshots blocked
./dev.sh release demo   # screenshots allowed, for marketing capture
```

The demo profile exists because production builds set `FLAG_SECURE`, which makes every screenshot and screen recording come out black. If you need to capture the app, you must build with `demo`.

## Architecture

```
lib/
├── main.dart                     # entry point; applies screenshot protection
├── core/
│   ├── config/app_config.dart    # build-time flags (DEMO_MODE, ALLOW_SCREENSHOTS)
│   ├── providers.dart            # Riverpod state
│   ├── models/                   # Token, Profile, TokenGroup
│   └── crypto/
│       ├── otp_engine.dart       # TOTP/HOTP (RFC 6238 / 4226)
│       ├── vault_encryption.dart # Argon2id + AES-256-GCM (backup files)
│       └── import_export.dart    # multi-format import/export
├── data/
│   ├── database/vault_database.dart   # SQLCipher, schema v3
│   └── repositories/                  # token + profile CRUD
├── platform/
│   ├── biometric_service.dart    # local_auth wrapper
│   └── keystore_service.dart     # flutter_secure_storage wrapper
└── ui/
    ├── screens/
    ├── widgets/
    └── theme/
```

### Tech stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter |
| State | Riverpod |
| Vault database | SQLCipher (encrypted SQLite) |
| Backup encryption | Argon2id → AES-256-GCM |
| Biometrics | local_auth |
| Secure storage | flutter_secure_storage |
| QR scanning | mobile_scanner |

### App flow

```
Launch
  ├── First run  → Setup      (master password + phone screen lock or 6-digit PIN)
  └── Returning  → Lock       (device credential prompt, or PIN, or master password)
       └── Unlocked → Home    (tokens, grouped by profile)
            └── Backgrounded → auto-lock once the timeout elapses
```

Auto-lock is evaluated when the app returns to the foreground: the time spent in the background is compared against the timeout. The database stays open while the app is backgrounded.

## Known limitations

- No Steam Guard.
- The master password is stored in platform secure storage (see [What is stored, and where](#what-is-stored-and-where)).
- Auto-lock is checked on resume rather than enforced the moment the app is backgrounded.
- The security layer is not fully separated from the UI: auto-lock policy lives in `home_screen.dart`, and backup encryption is called directly from `settings_screen.dart`.
- Group category icons are not implemented; see `salvage/` for a partial widget awaiting the rest of the feature.

## License

Licensed under the **Apache License, Version 2.0** — see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).

Apache-2.0 was chosen over GPL-3.0 because Citadel is distributed on the Apple App Store, whose terms impose usage restrictions that GPL-3.0 forbids. It also carries an explicit patent grant.

```
Copyright 2026 Energma

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```

---

Built by [Energma](https://energma.co)
