#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  start)
    flutter run
    ;;
  get)
    flutter pub get
    ;;
  build)
    flutter pub run build_runner build --delete-conflicting-outputs
    ;;
  test)
    flutter test
    ;;
  clean)
    flutter clean
    flutter pub get
    ;;
  android)
    flutter build apk --debug
    ;;
  ios)
    flutter build ios --simulator --debug
    ;;
  *)
    echo "Usage: ./dev.sh {start|get|build|test|clean|android|ios}"
    exit 1
    ;;
esac
