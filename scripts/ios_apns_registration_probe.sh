#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEVICE_ID="${DEVICE_ID:-70629899-4D65-52F9-9040-03C1FD0C697D}"
BUNDLE_ID="${BUNDLE_ID:-com.liangzhang.editor.ios}"
DEST_DIR="${DEST_DIR:-/tmp/editor-ios-apns-registration-probe}"
AUDIT_IOS_APNS_READBACK_DIR="${AUDIT_IOS_APNS_READBACK_DIR:-/tmp/editor-ios-apns-registration-probe/readback}"
BUILD_IOS_APP="${BUILD_IOS_APP:-1}"
INSTALL_IOS_APP="${INSTALL_IOS_APP:-1}"
RESET_IOS_APP="${RESET_IOS_APP:-0}"
APP_PATH="${APP_PATH:-}"
LAUNCH_TIMEOUT_SECONDS="${LAUNCH_TIMEOUT_SECONDS:-25}"
EXPECT_DIAGNOSTIC="${EXPECT_DIAGNOSTIC:-remote_notification_registration_succeeded}"
READBACK_SCRIPT="${READBACK_SCRIPT:-scripts/ios_sync_readback.sh}"

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

if [[ "$RESET_IOS_APP" == "1" && "$INSTALL_IOS_APP" != "1" ]]; then
  echo "RESET_IOS_APP=1 requires INSTALL_IOS_APP=1 so the app can be relaunched after data reset." >&2
  exit 2
fi

if [[ "$BUILD_IOS_APP" == "1" ]]; then
  echo "== Build iOS Debug app =="
  xcodebuild build \
    -scheme EditorIOS \
    -configuration Debug \
    -destination 'generic/platform=iOS' \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration
else
  echo "== Skip iOS build =="
fi

app_path="$APP_PATH"
if [[ "$INSTALL_IOS_APP" == "1" && -z "$app_path" ]]; then
  products_dir="$(xcodebuild -showBuildSettings \
    -scheme EditorIOS \
    -configuration Debug \
    -destination 'generic/platform=iOS' \
    | awk -F'= ' '/^[[:space:]]*BUILT_PRODUCTS_DIR = / { value=$2 } END { print value }')"
  app_path="$products_dir/EditorIOS.app"
fi

if [[ "$INSTALL_IOS_APP" == "1" && ! -d "$app_path" ]]; then
  echo "iOS app bundle not found at $app_path. Build first or pass APP_PATH." >&2
  exit 2
fi

if [[ "$RESET_IOS_APP" == "1" ]]; then
  echo "== Reset iOS app data =="
  xcrun devicectl device uninstall app \
    --device "$DEVICE_ID" \
    "$BUNDLE_ID" || true
fi

if [[ "$INSTALL_IOS_APP" == "1" ]]; then
  echo "== Install iOS app =="
  xcrun devicectl device install app \
    --device "$DEVICE_ID" \
    "$app_path"
else
  echo "== Skip iOS install =="
fi

echo "== Launch iOS app for APNs registration =="
set +e
xcrun devicectl device process --timeout "$LAUNCH_TIMEOUT_SECONDS" launch \
  --device "$DEVICE_ID" \
  --terminate-existing \
  --console "$BUNDLE_ID" 2>&1 | tee "$DEST_DIR/launch.log"
launch_status=${PIPESTATUS[0]}
set -e

if grep -Eq 'Locked|was not, or could not be, unlocked|could not be unlocked' "$DEST_DIR/launch.log"; then
  launch_was_locked=1
else
  launch_was_locked=0
fi

echo "== Read back APNs registration diagnostic =="
set +e
DEST_DIR="$DEST_DIR/readback" \
DEVICE_ID="$DEVICE_ID" \
BUNDLE_ID="$BUNDLE_ID" \
EXPECT_DIAGNOSTIC="$EXPECT_DIAGNOSTIC" \
"$READBACK_SCRIPT"
readback_status=$?
set -e

if [[ "$readback_status" -ne 0 ]]; then
  if [[ "$launch_was_locked" == "1" ]]; then
    echo "iOS launch was blocked by device lock state and APNs readback failed." >&2
  fi
  exit "$readback_status"
fi

probe_readback_dir="$DEST_DIR/readback"
if [[ -f "$probe_readback_dir/editor.sqlite" && "$probe_readback_dir" != "$AUDIT_IOS_APNS_READBACK_DIR" ]]; then
  rm -rf "$AUDIT_IOS_APNS_READBACK_DIR"
  mkdir -p "$AUDIT_IOS_APNS_READBACK_DIR"
  cp -R "$probe_readback_dir/." "$AUDIT_IOS_APNS_READBACK_DIR/"
  echo "Published iOS APNs readback for completion audit: $AUDIT_IOS_APNS_READBACK_DIR"
fi

if [[ "$launch_status" -ne 0 ]]; then
  if [[ "$launch_was_locked" == "1" ]]; then
    echo "Launch was blocked by device lock state, but SQLite readback contains $EXPECT_DIAGNOSTIC. Treating readback as authoritative." >&2
  else
    echo "Launch command exited with status $launch_status, but SQLite readback contains $EXPECT_DIAGNOSTIC. Treating readback as authoritative." >&2
  fi
fi

echo "iOS APNs registration probe completed. Artifacts are in $DEST_DIR"
