#!/usr/bin/env bash
# -------------------------------------------------------------------------
# build_release.sh — Produces obfuscated, release-ready builds.
#
# Android:
#   Builds an Android App Bundle (.aab) for Google Play submission.
#
# iOS:
#   Builds an iOS IPA for App Store / TestFlight submission.
#
# OWASP M8/M9:
#   --obfuscate renames Dart class/method names in the compiled binary,
#   making reverse engineering harder.
#
#   --split-debug-info moves symbol information out of the binary into a
#   private directory. Keep this directory secure and do not commit it.
#
# Keep the generated build/debug-info/ directory PRIVATE.
# You need it to symbolicate crash reports, for example using:
#
#   flutter symbolize -i <stack_trace_file> -d build/debug-info/<symbols_file>
#
# Usage:
#   ./scripts/build_release.sh            # build Android AAB and iOS IPA
#   ./scripts/build_release.sh android    # Android AAB only
#   ./scripts/build_release.sh ios        # iOS IPA only
#   ./scripts/build_release.sh apk        # Android APK only, for local testing
#   ./scripts/build_release.sh both       # Android AAB and iOS IPA
# -------------------------------------------------------------------------

set -euo pipefail

DEFINES_FILE="env.json"
DEBUG_INFO_DIR="build/debug-info"
TARGET="${1:-both}"

mkdir -p "$DEBUG_INFO_DIR"

COMMON_FLAGS=(
  "--dart-define-from-file=$DEFINES_FILE"
  "--obfuscate"
  "--split-debug-info=$DEBUG_INFO_DIR"
)

check_defines_file() {
  if [[ ! -f "$DEFINES_FILE" ]]; then
    echo "✗ Missing $DEFINES_FILE"
    echo ""
    echo "Create $DEFINES_FILE in the project root before building."
    echo "Example:"
    echo '{'
    echo '  "SUPABASE_URL": "https://your-project.supabase.co",'
    echo '  "SUPABASE_ANON_KEY": "your-anon-key"'
    echo '}'
    exit 1
  fi
}

check_flutter_available() {
  if ! command -v flutter >/dev/null 2>&1; then
    echo "✗ Flutter is not available on PATH."
    echo "Install Flutter or ensure the flutter command is available."
    exit 1
  fi
}

build_android_aab() {
  echo "→ Building Android App Bundle for Google Play (obfuscated)..."
  flutter build appbundle --release "${COMMON_FLAGS[@]}"
  echo "✓ Android App Bundle: build/app/outputs/bundle/release/app-release.aab"
}

build_android_apk() {
  echo "→ Building Android release APK for local testing (obfuscated)..."
  flutter build apk --release "${COMMON_FLAGS[@]}"
  echo "✓ Android APK: build/app/outputs/flutter-apk/app-release.apk"
}

build_ios_ipa() {
  echo "→ Building iOS release IPA (obfuscated)..."
  flutter build ipa --release "${COMMON_FLAGS[@]}"
  echo "✓ iOS IPA: build/ios/ipa/"
}

check_flutter_available
check_defines_file

case "$TARGET" in
  android)
    build_android_aab
    ;;

  ios)
    build_ios_ipa
    ;;

  apk)
    build_android_apk
    ;;

  both)
    build_android_aab
    build_ios_ipa
    ;;

  *)
    echo "✗ Invalid target: $TARGET"
    echo ""
    echo "Usage:"
    echo "  ./scripts/build_release.sh            # build Android AAB and iOS IPA"
    echo "  ./scripts/build_release.sh android    # Android AAB only"
    echo "  ./scripts/build_release.sh ios        # iOS IPA only"
    echo "  ./scripts/build_release.sh apk        # Android APK only, for local testing"
    echo "  ./scripts/build_release.sh both       # Android AAB and iOS IPA"
    exit 1
    ;;
esac

echo ""
echo "Debug symbols saved to: $DEBUG_INFO_DIR"
echo "Keep this directory PRIVATE — required for crash symbolication."