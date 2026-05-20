#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEST_DIR="${DEST_DIR:-/tmp/editor-ios-unlock-cross-device-sync}"
IOS_READY_SCRIPT="${IOS_READY_SCRIPT:-scripts/ios_headless_sync.sh}"
CROSS_DEVICE_SCRIPT="${CROSS_DEVICE_SCRIPT:-scripts/cloudkit_cross_device_sync.sh}"
WAIT_TIMEOUT_SECONDS="${WAIT_TIMEOUT_SECONDS:-600}"
WAIT_INTERVAL_SECONDS="${WAIT_INTERVAL_SECONDS:-10}"
PAGE_ID="${PAGE_ID:-page-welcome}"
BUILD_IOS_APP="${BUILD_IOS_APP:-0}"
INSTALL_IOS_APP="${INSTALL_IOS_APP:-0}"
RESET_IOS_APP="${RESET_IOS_APP:-0}"
LAUNCH_ATTEMPTS="${LAUNCH_ATTEMPTS:-1}"
LAUNCH_RETRY_DELAY="${LAUNCH_RETRY_DELAY:-5}"
BUILD_MAC_APP="${BUILD_MAC_APP:-1}"
RUN_TIMEOUT_SECONDS="${RUN_TIMEOUT_SECONDS:-120}"

is_retryable_readiness_failure() {
  local log_file="$1"
  grep -Eq \
    'Locked|was not, or could not be, unlocked|could not be unlocked|Network Unavailable|Network Failure|NSURLErrorDomain:-1009|NSURLErrorDomain:-1005' \
    "$log_file"
}

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

echo "== Wait for iOS unlock, then run cross-device CloudKit verifier =="
echo "timeout_seconds=$WAIT_TIMEOUT_SECONDS"
echo "interval_seconds=$WAIT_INTERVAL_SECONDS"

deadline=$((SECONDS + WAIT_TIMEOUT_SECONDS))
attempt=0
while true; do
  attempt=$((attempt + 1))
  attempt_dir="$DEST_DIR/ios-ready-attempt-$attempt"
  attempt_log="$DEST_DIR/ios-ready-attempt-$attempt.log"
  mkdir -p "$attempt_dir"
  echo "== iOS readiness attempt $attempt =="

  set +e
  DEST_DIR="$attempt_dir" \
  PAGE_ID="$PAGE_ID" \
  BUILD_IOS_APP="$BUILD_IOS_APP" \
  INSTALL_IOS_APP="$INSTALL_IOS_APP" \
  RESET_IOS_APP="$RESET_IOS_APP" \
  LAUNCH_ATTEMPTS="$LAUNCH_ATTEMPTS" \
  LAUNCH_RETRY_DELAY="$LAUNCH_RETRY_DELAY" \
  "$IOS_READY_SCRIPT" >"$attempt_log" 2>&1
  ready_status=$?
  set -e

  cat "$attempt_log"

  if [[ "$ready_status" -eq 0 ]]; then
    echo "iOS readiness probe completed."
    break
  fi

  if ! is_retryable_readiness_failure "$attempt_log"; then
    echo "iOS readiness probe failed for a non-retryable reason. See $attempt_log" >&2
    exit "$ready_status"
  fi

  if [[ "$SECONDS" -ge "$deadline" ]]; then
    echo "Timed out waiting for iOS unlock after ${WAIT_TIMEOUT_SECONDS}s." >&2
    exit "$ready_status"
  fi

  echo "iOS readiness probe hit a retryable lock/network state; retrying in ${WAIT_INTERVAL_SECONDS}s."
  sleep "$WAIT_INTERVAL_SECONDS"
done

echo "== Run cross-device CloudKit verifier =="
DEST_DIR="$DEST_DIR/cross-device" \
PAGE_ID="$PAGE_ID" \
BUILD_MAC_APP="$BUILD_MAC_APP" \
BUILD_IOS_APP="$BUILD_IOS_APP" \
INSTALL_IOS_APP="$INSTALL_IOS_APP" \
RESET_IOS_APP="$RESET_IOS_APP" \
LAUNCH_ATTEMPTS="$LAUNCH_ATTEMPTS" \
LAUNCH_RETRY_DELAY="$LAUNCH_RETRY_DELAY" \
RUN_TIMEOUT_SECONDS="$RUN_TIMEOUT_SECONDS" \
"$CROSS_DEVICE_SCRIPT"

echo "Unlock wait and cross-device verifier completed. Artifacts are in $DEST_DIR"
