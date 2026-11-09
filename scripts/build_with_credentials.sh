#!/usr/bin/env bash
# Build BA BLAST GRAM after the owner's API keys were injected into the
# encrypted native store.
#
# The owner's api_id/api_hash are NEVER passed on the command line and
# never live in Dart code. They go into the native library first:
#   1. Owner gets api_id/api_hash from my.telegram.org (once).
#   2. Builder runs: dart scripts/make_keys.dart <api_id> <api_hash>
#   3. Builder pastes the output into BOTH files, replacing the
#      OWNER PLACEHOLDER block:
#        android/app/src/main/cpp/telegram_keys.cpp
#        ios/Runner/telegram_keys.c
#   4. Then run this script to build.
#
# Usage: ./scripts/build_with_credentials.sh [apk|appbundle|ios|web]
# Refuses to build a release while the placeholders are still in place.
set -euo pipefail

TARGET="${1:-apk}"
CPP="android/app/src/main/cpp/telegram_keys.cpp"

if grep -q "OWNER_PLACEHOLDER" "$CPP"; then
  echo "ERROR: Owner API keys are not in the native store yet." >&2
  echo "Run: dart scripts/make_keys.dart <api_id> <api_hash>" >&2
  echo "and paste the output into $CPP and ios/Runner/telegram_keys.c," >&2
  echo "replacing the OWNER PLACEHOLDER block. Then re-run this script." >&2
  exit 1
fi

case "$TARGET" in
  apk)       flutter build apk --release ;;
  appbundle) flutter build appbundle --release ;;
  ios)       flutter build ios --release ;;
  web)       flutter build web --release ;;
  *)
    echo "Usage: $0 [apk|appbundle|ios|web]" >&2
    exit 1
    ;;
esac
