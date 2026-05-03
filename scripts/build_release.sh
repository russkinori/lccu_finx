#!/usr/bin/env bash
# -------------------------------------------------------------------------
# build_release.sh — Produces obfuscated, minified release builds.
#
# OWASP M8/M9: --obfuscate renames Dart class/method names in the binary,
# making reverse engineering significantly harder. --split-debug-info moves
# the symbol map out of the binary to a separate directory kept off-device.
#
# Keep the generated build/debug-info/ directory PRIVATE (add to .gitignore).
# You need it to symbolicate crash reports (e.g. via `flutter symbolize`).
#
# Usage:
#   ./scripts/build_release.sh           # build both Android APK and iOS IPA
#   ./scripts/build_release.sh android   # Android only
#   ./scripts/build_release.sh ios       # iOS only
# -------------------------------------------------------------------------
set -euo pipefail

DEFINES_FILE="env.json"
DEBUG_INFO_DIR="build/debug-info"
mkdir -p "$DEBUG_INFO_DIR"

COMMON_FLAGS=(
  "--dart-define-from-file=$DEFINES_FILE"
  "--obfuscate"
  "--split-debug-info=$DEBUG_INFO_DIR"
)

TARGET="${1:-both}"

if [[ "$TARGET" == "android" || "$TARGET" == "both" ]]; then
  echo "→ Building Android release APK (obfuscated)..."
  flutter build apk --release "${COMMON_FLAGS[@]}"
  echo "✓ Android APK: build/app/outputs/flutter-apk/app-release.apk"
fi

if [[ "$TARGET" == "ios" || "$TARGET" == "both" ]]; then
  echo "→ Building iOS release IPA (obfuscated)..."
  flutter build ipa --release "${COMMON_FLAGS[@]}"
  echo "✓ iOS IPA: build/ios/ipa/"
fi

echo ""
echo "Debug symbols saved to: $DEBUG_INFO_DIR"
echo "Keep this directory PRIVATE — required for crash symbolication."
