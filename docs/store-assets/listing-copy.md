# Play Store Listing Copy — Citadel Auth

Drafted 2026-08-20. All feature claims verified against the codebase this session — see
`docs/PLAY_STORE_RELEASE.md` for the underlying facts. Nothing below describes a
not-yet-shipped feature (no widgets, no favorites/pinning, no cloud sync).

## Short description (≤80 chars)

```
Your privacy-first 2FA authenticator. Local, encrypted, offline.
```
Character count: 64/80.

## Long description (≤4000 chars)

```
Citadel Auth is a privacy-first two-factor authenticator. Every code is generated
on your device, every secret stays encrypted on your device, and the app never
connects to the internet — there's no account to create and nothing to sync.

FEATURES

• Standard TOTP and HOTP codes (RFC 6238 / RFC 4226), with SHA-1, SHA-256, or
  SHA-512 algorithms and configurable digits and time step per token.
• Add tokens by scanning a QR code, or enter details manually.
• Import your existing tokens from Aegis, 2FAS, Ente Auth, or plain otpauth://
  links, so switching authenticators doesn't mean starting over.
• Organize tokens into Profiles — separate spaces for, say, personal and work —
  and group tokens within each profile.
• Unlock with a PIN, your device's screen lock, or biometrics.
• Auto-lock after a configurable period of inactivity.
• Screenshot and screen-recording protection, so codes aren't captured by
  other apps.
• Search across your tokens.
• Light and dark themes.

PRIVACY BY CONSTRUCTION

• No account, no sign-up, no email required.
• No cloud sync, no backend, no telemetry, no analytics, no ads.
• The app requests no internet permission — it cannot phone home.
• Your vault is encrypted at rest with Argon2id key derivation and
  AES-256-GCM, stored in a SQLCipher-encrypted local database.
• Backups are files you create and control, optionally password-encrypted.

Citadel Auth is built for people who want their second factor to be exactly
that: a second factor, kept private, kept local, and kept simple.
```
Character count: 1,533/4000.

## Data Safety form

- **Data collected:** None.
- **Data shared:** None.
- **Data types:** N/A — app collects no user data.
- **Security practices:**
  - Data encrypted in transit: N/A (app makes no network requests in release builds).
  - Data encrypted at rest: Yes (SQLCipher + Argon2id/AES-256-GCM).
  - User can request data deletion: Yes, implicitly — uninstalling the app removes
    all local data; there is no server-side copy to delete.
- **Reviewer note (optional free-text field):**
  `lib/ui/widgets/service_icon.dart` contains a favicon-fallback fetch
  (`https://www.google.com/s2/favicons?domain=...`) used only as a visual fallback
  icon for unrecognized token issuers. It is inert in this release: the release
  AndroidManifest strips `INTERNET`/`ACCESS_NETWORK_STATE`, so the request never
  executes and the app falls back to a local letter-avatar icon. If it did execute,
  it would send only a guessed domain derived from the issuer name the user typed
  (e.g. "github.com") — never a token secret, account value, or other vault
  content. This does not change the "no data collected/shared" answer above.

## Content rating questionnaire

- Category: Utility / Tools.
- No user-generated content, no user-to-user communication.
- No ads, no in-app purchases.
- Not directed at children.
- Expected outcome: Everyone.

## Permissions declared (release build)

- **CAMERA** — used to scan QR codes when adding a token. Not required to use
  the app (manual entry is available); mark the camera feature as
  `android:required="false"` if not already.
- **USE_BIOMETRIC / USE_FINGERPRINT** — used only for optional biometric unlock
  of the local vault.
- No other permissions are present in the release manifest. `INTERNET` /
  `ACCESS_NETWORK_STATE` are explicitly stripped.

## Developer / support contact

- Support email: `support@energma.co` — **placeholder, replace with the real
  address before submitting** (per 2026-08-20 decision — no real support email
  existed anywhere in the repo).
- Website: https://energma.co
- Privacy policy: https://www.energma.co/privacy-policy (already linked in-app).
