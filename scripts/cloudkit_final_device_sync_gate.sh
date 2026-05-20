#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEST_DIR="${DEST_DIR:-/tmp/editor-cloudkit-final-device-sync}"
WAIT_SCRIPT="${WAIT_SCRIPT:-scripts/wait_for_ios_unlock_and_run_cross_device_sync.sh}"
APNS_SCRIPT="${APNS_SCRIPT:-scripts/ios_apns_registration_probe.sh}"
AUDIT_SCRIPT="${AUDIT_SCRIPT:-scripts/cloudkit_sync_completion_audit.sh}"
AUDIT_IOS_READBACK_DIR="${AUDIT_IOS_READBACK_DIR:-/tmp/editor-ios-headless-sync/readback}"
AUDIT_IOS_APNS_READBACK_DIR="${AUDIT_IOS_APNS_READBACK_DIR:-/tmp/editor-ios-apns-registration-probe/readback}"

PAGE_ID="${PAGE_ID:-page-welcome}"
BUILD_MAC_APP="${BUILD_MAC_APP:-1}"
BUILD_IOS_APP="${BUILD_IOS_APP:-0}"
INSTALL_IOS_APP="${INSTALL_IOS_APP:-0}"
RESET_IOS_APP="${RESET_IOS_APP:-0}"
LAUNCH_ATTEMPTS="${LAUNCH_ATTEMPTS:-1}"
LAUNCH_RETRY_DELAY="${LAUNCH_RETRY_DELAY:-5}"
WAIT_TIMEOUT_SECONDS="${WAIT_TIMEOUT_SECONDS:-600}"
WAIT_INTERVAL_SECONDS="${WAIT_INTERVAL_SECONDS:-10}"
RUN_TIMEOUT_SECONDS="${RUN_TIMEOUT_SECONDS:-120}"
APNS_BUILD_IOS_APP="${APNS_BUILD_IOS_APP:-0}"
APNS_INSTALL_IOS_APP="${APNS_INSTALL_IOS_APP:-0}"
APNS_RESET_IOS_APP="${APNS_RESET_IOS_APP:-0}"
APNS_LAUNCH_TIMEOUT_SECONDS="${APNS_LAUNCH_TIMEOUT_SECONDS:-25}"
REQUIRE_PRODUCTION_SCHEMA="${REQUIRE_PRODUCTION_SCHEMA:-0}"

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

cross_wait_dir="$DEST_DIR/cross-device-wait"
cross_device_state_dir="$cross_wait_dir/cross-device"
apns_dir="$DEST_DIR/apns-registration"
audit_log="$DEST_DIR/completion-audit.log"

echo "== Final physical CloudKit sync gate =="
echo "dest_dir=$DEST_DIR"
echo "page_id=$PAGE_ID"
echo "build_mac_app=$BUILD_MAC_APP"
echo "build_ios_app=$BUILD_IOS_APP"
echo "install_ios_app=$INSTALL_IOS_APP"
echo "reset_ios_app=$RESET_IOS_APP"

echo "== Step 1/3: wait for iPhone and run cross-device sync verifier =="
DEST_DIR="$cross_wait_dir" \
PAGE_ID="$PAGE_ID" \
BUILD_MAC_APP="$BUILD_MAC_APP" \
BUILD_IOS_APP="$BUILD_IOS_APP" \
INSTALL_IOS_APP="$INSTALL_IOS_APP" \
RESET_IOS_APP="$RESET_IOS_APP" \
LAUNCH_ATTEMPTS="$LAUNCH_ATTEMPTS" \
LAUNCH_RETRY_DELAY="$LAUNCH_RETRY_DELAY" \
WAIT_TIMEOUT_SECONDS="$WAIT_TIMEOUT_SECONDS" \
WAIT_INTERVAL_SECONDS="$WAIT_INTERVAL_SECONDS" \
RUN_TIMEOUT_SECONDS="$RUN_TIMEOUT_SECONDS" \
AUDIT_IOS_READBACK_DIR="$AUDIT_IOS_READBACK_DIR" \
"$WAIT_SCRIPT"

if [[ ! -f "$cross_device_state_dir/completed.ok" ]]; then
  echo "Cross-device verifier did not publish completed.ok at $cross_device_state_dir." >&2
  exit 1
fi

echo "== Step 2/3: run normal-launch iOS APNs registration probe =="
DEST_DIR="$apns_dir" \
BUILD_IOS_APP="$APNS_BUILD_IOS_APP" \
INSTALL_IOS_APP="$APNS_INSTALL_IOS_APP" \
RESET_IOS_APP="$APNS_RESET_IOS_APP" \
LAUNCH_TIMEOUT_SECONDS="$APNS_LAUNCH_TIMEOUT_SECONDS" \
AUDIT_IOS_APNS_READBACK_DIR="$AUDIT_IOS_APNS_READBACK_DIR" \
"$APNS_SCRIPT"

echo "== Step 3/3: run completion audit over published evidence =="
CROSS_DEVICE_STATE_DIR="$cross_device_state_dir" \
IOS_READBACK_DIR="$AUDIT_IOS_READBACK_DIR" \
IOS_APNS_READBACK_DIR="$AUDIT_IOS_APNS_READBACK_DIR" \
REQUIRE_PRODUCTION_SCHEMA="$REQUIRE_PRODUCTION_SCHEMA" \
"$AUDIT_SCRIPT" | tee "$audit_log"
audit_status=${PIPESTATUS[0]}

if [[ "$audit_status" -ne 0 ]]; then
  echo "Completion audit failed. See $audit_log" >&2
  exit "$audit_status"
fi

echo "Final physical CloudKit sync gate completed. Artifacts are in $DEST_DIR"
