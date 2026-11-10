#!/usr/bin/env bash
set -euo pipefail

# Use the project's pinned SDK from .fvmrc; plain `flutter` may be missing or the wrong version.
flutter() { fvm flutter "$@"; }

android_build() { flutter build apk --debug; }
# iOS testing builds (simulator, device, ipa-test) use config/demo.json so
# screenshots and screen recording work. Only `ipa` is production-locked.
ios_build() { flutter build ios --simulator --debug --dart-define-from-file=config/demo.json; }
ios_device_build() { flutter build ios --release --no-codesign --dart-define-from-file=config/demo.json; }
ipa_build() { flutter build ipa --dart-define-from-file=config/prod.json --export-options-plist=ios/ExportOptions.plist; }
ipa_test_build() { flutter build ipa --dart-define-from-file=config/demo.json --export-options-plist=ios/ExportOptions.plist; }

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
        echo "Usage: ./dev.sh build [android|ios|ios-device|ipa|ipa-test]"
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
    echo "Usage: ./dev.sh {start|get|build [android|ios|ios-device|ipa|ipa-test]|test|clean|android|ios|ios-device|ipa|ipa-test}"
    exit 1
    ;;
esac
