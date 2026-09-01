#!/usr/bin/env bash
set -euo pipefail

android_build() { flutter build apk --debug; }
ios_build() { flutter build ios --simulator --debug; }
ios_device_build() { flutter build ios --release --no-codesign; }
ipa_build() { flutter build ipa --export-options-plist=ios/ExportOptions.plist; }

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
      "") ;;
      *)
        echo "Usage: ./dev.sh build [android|ios|ios-device|ipa]"
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
  *)
    echo "Usage: ./dev.sh {start|get|build [android|ios|ios-device|ipa]|test|clean|android|ios|ios-device|ipa}"
    exit 1
    ;;
esac
