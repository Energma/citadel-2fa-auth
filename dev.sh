#!/usr/bin/env bash
set -euo pipefail

# Use the project's pinned SDK from .fvmrc; plain `flutter` may be missing or the wrong version.
flutter() { fvm flutter "$@"; }

android_build() { flutter build apk --debug; }
# Play Store production bundle. Play only takes .aab; signing comes from android/key.properties (gitignored).
aab_build() { flutter build appbundle --release --dart-define-from-file=config/prod.json; }
# iOS testing builds (simulator, device, ipa-test) use config/demo.json so
# screenshots and screen recording work. Only `ipa` is production-locked.
ios_build() { flutter build ios --simulator --debug --dart-define-from-file=config/demo.json; }
ios_device_build() { flutter build ios --release --no-codesign --dart-define-from-file=config/demo.json; }
# `flutter build ipa` names the export after the Xcode product (e.g. Runner.ipa
# or "Citadel Auth.ipa"). Rename whatever it produced to a fixed, predictable name.
IPA_DIR="build/ios/ipa"
IPA_PROD_NAME="citadel-auth.ipa"
IPA_TEST_NAME="citadel_auth test.ipa"

rename_ipa() {
  local target="$1" found
  found=$(ls -t "$IPA_DIR"/*.ipa 2>/dev/null | head -n 1)
  if [ -z "$found" ]; then
    echo "No .ipa found in $IPA_DIR" >&2
    return 1
  fi
  if [ "$found" != "$IPA_DIR/$target" ]; then
    rm -f "$IPA_DIR/$target"
    mv "$found" "$IPA_DIR/$target"
  fi
  echo "IPA written to $IPA_DIR/$target"
}

ipa_build() { flutter build ipa --dart-define-from-file=config/prod.json --export-options-plist=ios/ExportOptions.plist && rename_ipa "$IPA_PROD_NAME"; }
ipa_test_build() { flutter build ipa --dart-define-from-file=config/demo.json --export-options-plist=ios/ExportOptions.plist && rename_ipa "$IPA_TEST_NAME"; }

case "${1:-}" in
  start)
    flutter run
    ;;
  get)
    flutter pub get
    ;;
  build)
    flutter pub run build_runner build --delete-conflicting-outputs
    case "${2:-}" in
      android)
        android_build
        ;;
      aab)
        aab_build
        ;;
      ios)
        ios_build
        ;;
      ios-device)
        ios_device_build
        ;;
      ipa)
        ipa_build
        ;;
      ipa-test)
        ipa_test_build
        ;;
      "") ;;
      *)
        echo "Usage: ./dev.sh build [android|aab|ios|ios-device|ipa|ipa-test]"
        exit 1
        ;;
    esac
    ;;
  test)
    flutter test
    ;;
  clean)
    flutter clean
    flutter pub get
    ;;
  android)
    android_build
    ;;
  aab)
    aab_build
    ;;
  ios)
    ios_build
    ;;
  ios-device)
    ios_device_build
    ;;
  ipa)
    ipa_build
    ;;
  ipa-test)
    ipa_test_build
    ;;
  *)
    echo "Usage: ./dev.sh {start|get|build [android|aab|ios|ios-device|ipa|ipa-test]|test|clean|android|aab|ios|ios-device|ipa|ipa-test}"
    exit 1
    ;;
esac
