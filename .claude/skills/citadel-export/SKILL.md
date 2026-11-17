---
name: citadel-export
description: Build and export Citadel Auth Android builds (signed APK + AAB) to ~/Downloads. Use whenever the user asks for an Android export, a dev/development/test build, a prod/production/release/Play Store build, "APK and etc", "all exports", or a build with screenshots/screen recording enabled or disabled.
---

# Citadel Android export

Two kinds of export. **By default make both** (one dev, one prod) unless the user asks for just one.
Each kind ships **both an APK and an AAB**.

| Kind | Config | Screenshots / screen recording | Folder |
|---|---|---|---|
| **Dev** (development, test, demo, marketing, "enable pictures/videos") | `config/demo.json` (`DEMO_MODE=true`) | **Enabled** | `~/Downloads/CITADEL-<DD-MM-YYYY>-<V>-dev/` |
| **Prod** (production, release, Play Store) | `config/prod.json` (`DEMO_MODE=false`) | **Disabled** (blocked, recents blurred) | `~/Downloads/CITADEL-<DD-MM-YYYY>-<V>/` |

- `<DD-MM-YYYY>` is today's build date, e.g. `17-11-2026`.
- `<V>` is the full `version:` from `pubspec.yaml`, e.g. `1.0.1+4`.
- Example: `~/Downloads/CITADEL-17-11-2026-1.0.1+4/` and `~/Downloads/CITADEL-17-11-2026-1.0.1+4-dev/`.
- Never mix dev and prod files in one folder. If today's folder already exists, look at it before overwriting.

`lib/core/config/app_config.dart` is the source of truth: `ALLOW_SCREENSHOTS` defaults to `DEMO_MODE`, and a build with no flags behaves like prod. `DEMO_MODE` currently only controls screen capture; there is no mock/seed data in the app. If that changes, recheck what each export ships.

## Steps

1. **Preflight**
   - `git status -sb` and `git log -1 --oneline`: tell the user which commit is built and whether uncommitted changes go into it. For an untracked `.dart` file, `grep` for imports to check whether it ends up in the build.
   - Signing key must exist at the path in `android/key.properties` (`~/citadel-release.jks`). If it's missing, stop and tell the user. Don't fall back to debug signing, and never print the key passwords.
2. **Build** one kind at a time: both kinds write to the same `build/` output paths, so copy the files out (step 3) before building the next kind. Both are signed with the release key via `android/key.properties`.
   ```bash
   CFG=config/prod.json   # prod
   CFG=config/demo.json   # dev
   fvm flutter build apk --release --dart-define-from-file=$CFG
   fvm flutter build appbundle --release --dart-define-from-file=$CFG
   ```
   Don't add a separate `--dart-define=ALLOW_SCREENSHOTS=...`; let the config file decide.
3. **Copy and name** with the folder's prefix `P=CITADEL-<DD-MM-YYYY>-<V>`:
   - prod: `$P-release.apk`, `$P-release.aab`
   - dev: `$P-dev.apk`, `$P-dev.aab`
   - Sources: `build/app/outputs/flutter-apk/app-release.apk` and `build/app/outputs/bundle/release/app-release.aab`.
   - Then, inside each folder, `sha256sum *.apk *.aab > SHA256SUMS.txt`.
   - Put only these files in the folder. **No `.zip`/`.tar.gz` and no debug APKs**: testers' phones open archives in a PDF/WPS viewer instead of installing them.
4. **Verify** each folder. The system `java` isn't on PATH, so use Android Studio's JDK:
   ```bash
   export JAVA_HOME=/opt/android-studio/jbr PATH=/opt/android-studio/jbr/bin:$PATH
   B=$(ls -d ~/Android/Sdk/build-tools/* | sort -V | tail -1)
   $B/apksigner verify --print-certs <apk>   # expect CN=Citadel Auth, O=Energma, C=RS
   jarsigner -verify <aab> 2>&1 | grep -iE "verified|unsigned"   # expect "jar verified."
   $B/aapt2 dump badging <apk> | grep ^package
   ```
   **Screen capture check**: the screen-protector call is compiled out when screenshots are allowed.
   ```bash
   unzip -p <apk> lib/arm64-v8a/libapp.so | strings -a | grep -cE "preventScreenshotOn|protectDataLeakageWithBlur"
   ```
   - dev → must be `0` (capture enabled)
   - prod → must be `>0` (capture blocked)

   A wrong result means the wrong config was used. Delete the export and rebuild.
5. **Report**: both folders, file names, sizes, commit, version, signer and the capture-check results. Point out what wasn't checked on a device.

## Running an export on the emulator (when asked)
- AVD is `Citadel_Test`. Launch it detached so it survives the shell exiting, otherwise it dies and the install is lost:
  `setsid nohup ~/Android/Sdk/emulator/emulator -avd Citadel_Test >/dev/null 2>&1 < /dev/null &`
- `adb` is `~/Android/Sdk/platform-tools/adb`. Wait for `getprop sys.boot_completed` = 1, then `adb install -r <dev apk>` and `adb shell am start -n com.energma.citadel2fa/.MainActivity`.
- If install fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, a build signed with a different key is installed. Uninstalling wipes that app's vault, so **ask the user first**.
- `com.citadelauth.citadel_auth` (the one with the Flutter icon) is an old package, not the current app.

## Sending builds to testers
- Send the `.apk` file itself, never a zipped copy.
- Prod AAB goes to Play Console; the dev APK is for side-loading on phones.
- If a phone already has a build signed with a different key, it must be uninstalled first (wipes that vault).
- Some messengers mangle `+` in file names. If a transfer breaks, rename the file to use `-` (e.g. `1.0.1-4`).

## Reminders for prod exports
- The version code must be higher than anything already uploaded to Play. Compare with the previous export folders in `~/Downloads`; ask if unsure.
- Remind the user to keep an offline backup of `~/citadel-release.jks` and its password.
- Store assets live in `docs/store-assets/`; flag them if they're out of date with the logo.

## Don't
- Don't ship a dev export to the Play Store; its screen capture is enabled.
- Don't uninstall the app on the user's emulator or device without asking; that wipes the vault.
