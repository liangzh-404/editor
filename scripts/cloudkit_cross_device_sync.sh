#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

timestamp="$(date -u +%Y%m%d%H%M%S)"

DEST_DIR="${DEST_DIR:-/tmp/editor-cloudkit-cross-device-sync}"
PAGE_ID="${PAGE_ID:-page-welcome}"
MAC_ORIGIN_TEXT="${MAC_ORIGIN_TEXT:-mac-cross-device-$timestamp}"
IOS_ORIGIN_TEXT="${IOS_ORIGIN_TEXT:-ios-cross-device-$timestamp}"
MAC_HEADLESS_SCRIPT="${MAC_HEADLESS_SCRIPT:-scripts/macos_headless_sync.sh}"
IOS_HEADLESS_SCRIPT="${IOS_HEADLESS_SCRIPT:-scripts/ios_headless_sync.sh}"
AUDIT_IOS_READBACK_DIR="${AUDIT_IOS_READBACK_DIR:-/tmp/editor-ios-headless-sync/readback}"
BUILD_MAC_APP="${BUILD_MAC_APP:-1}"
BUILD_IOS_APP="${BUILD_IOS_APP:-1}"
INSTALL_IOS_APP="${INSTALL_IOS_APP:-1}"
RESET_IOS_APP="${RESET_IOS_APP:-0}"
LAUNCH_ATTEMPTS="${LAUNCH_ATTEMPTS:-2}"
LAUNCH_RETRY_DELAY="${LAUNCH_RETRY_DELAY:-5}"
RUN_TIMEOUT_SECONDS="${RUN_TIMEOUT_SECONDS:-120}"

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"
printf '%s\n' "$MAC_ORIGIN_TEXT" > "$DEST_DIR/mac-origin-text.txt"
printf '%s\n' "$IOS_ORIGIN_TEXT" > "$DEST_DIR/ios-origin-text.txt"

echo "== Cross-device CloudKit sync verifier =="
echo "mac_origin_text=$MAC_ORIGIN_TEXT"
echo "ios_origin_text=$IOS_ORIGIN_TEXT"
echo "page_id=$PAGE_ID"

echo "== Step 1/3: macOS appends and uploads macOS-origin text =="
DEST_DIR="$DEST_DIR/macos-upload" \
APPEND_TEXT="$MAC_ORIGIN_TEXT" \
PAGE_ID="$PAGE_ID" \
BUILD_MAC_APP="$BUILD_MAC_APP" \
RUN_TIMEOUT_SECONDS="$RUN_TIMEOUT_SECONDS" \
"$MAC_HEADLESS_SCRIPT"

echo "== Step 2/3: iOS fetches macOS-origin text and uploads iOS-origin text =="
DEST_DIR="$DEST_DIR/ios-sync" \
APPEND_TEXT="$IOS_ORIGIN_TEXT" \
EXPECT_TEXT="$MAC_ORIGIN_TEXT" \
PAGE_ID="$PAGE_ID" \
RESET_IOS_APP="$RESET_IOS_APP" \
BUILD_IOS_APP="$BUILD_IOS_APP" \
INSTALL_IOS_APP="$INSTALL_IOS_APP" \
LAUNCH_ATTEMPTS="$LAUNCH_ATTEMPTS" \
LAUNCH_RETRY_DELAY="$LAUNCH_RETRY_DELAY" \
"$IOS_HEADLESS_SCRIPT"

ios_readback_dir="$DEST_DIR/ios-sync/readback"
if [[ -f "$ios_readback_dir/editor.sqlite" ]]; then
  rm -rf "$AUDIT_IOS_READBACK_DIR"
  mkdir -p "$AUDIT_IOS_READBACK_DIR"
  cp -R "$ios_readback_dir/." "$AUDIT_IOS_READBACK_DIR/"
  echo "Published iOS readback for completion audit: $AUDIT_IOS_READBACK_DIR"
fi

echo "== Step 3/3: macOS fetches iOS-origin text =="
DEST_DIR="$DEST_DIR/macos-fetch-ios" \
EXPECT_TEXT="$IOS_ORIGIN_TEXT" \
PAGE_ID="$PAGE_ID" \
BUILD_MAC_APP=0 \
RUN_TIMEOUT_SECONDS="$RUN_TIMEOUT_SECONDS" \
"$MAC_HEADLESS_SCRIPT"

touch "$DEST_DIR/completed.ok"
echo "Cross-device CloudKit sync verifier completed. Artifacts are in $DEST_DIR"
