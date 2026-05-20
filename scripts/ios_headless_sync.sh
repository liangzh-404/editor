#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEVICE_ID="${DEVICE_ID:-70629899-4D65-52F9-9040-03C1FD0C697D}"
BUNDLE_ID="${BUNDLE_ID:-com.liangzhang.editor.ios}"
DEST_DIR="${DEST_DIR:-/tmp/editor-ios-headless-sync}"
APPEND_TEXT="${APPEND_TEXT:-}"
EXPECT_TEXT="${EXPECT_TEXT:-}"
PAGE_ID="${PAGE_ID:-}"
RESET_IOS_APP="${RESET_IOS_APP:-0}"
BUILD_IOS_APP="${BUILD_IOS_APP:-1}"
INSTALL_IOS_APP="${INSTALL_IOS_APP:-1}"
APP_PATH="${APP_PATH:-}"
LAUNCH_ATTEMPTS="${LAUNCH_ATTEMPTS:-1}"
LAUNCH_RETRY_DELAY="${LAUNCH_RETRY_DELAY:-5}"

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"
if [[ -n "$APPEND_TEXT" ]]; then
  printf '%s\n' "$APPEND_TEXT" > "$DEST_DIR/append-text.txt"
fi

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

launch_env='{"EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC":"1","OS_ACTIVITY_DT_MODE":"1","OS_ACTIVITY_MODE":"enable"}'
if [[ -n "$APPEND_TEXT" || -n "$PAGE_ID" ]]; then
  launch_env='{"EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC":"1","OS_ACTIVITY_DT_MODE":"1","OS_ACTIVITY_MODE":"enable"'
  if [[ -n "$APPEND_TEXT" ]]; then
    launch_env="$launch_env,\"EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC_APPEND_TEXT\":\"$(json_escape "$APPEND_TEXT")\""
  fi
  if [[ -n "$PAGE_ID" ]]; then
    launch_env="$launch_env,\"EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC_PAGE_ID\":\"$(json_escape "$PAGE_ID")\""
  fi
  launch_env="$launch_env}"
fi
launch_env="${LAUNCH_ENV_JSON:-$launch_env}"

echo "== Launch headless CloudKit sync diagnostic =="
: > "$DEST_DIR/headless-launch.log"
launch_status=1
for ((attempt = 1; attempt <= LAUNCH_ATTEMPTS; attempt++)); do
  attempt_log="$DEST_DIR/headless-launch-attempt-$attempt.log"
  echo "-- launch attempt $attempt/$LAUNCH_ATTEMPTS --" | tee -a "$DEST_DIR/headless-launch.log"
  set +e
  xcrun devicectl device process --timeout 35 launch \
    --device "$DEVICE_ID" \
    --terminate-existing \
    --environment-variables "$launch_env" \
    --console "$BUNDLE_ID" 2>&1 | tee "$attempt_log"
  launch_status=${PIPESTATUS[0]}
  set -e
  cat "$attempt_log" >> "$DEST_DIR/headless-launch.log"

  if [[ "$launch_status" -eq 0 ]]; then
    break
  fi

  if [[ "$attempt" -lt "$LAUNCH_ATTEMPTS" ]] && grep -Eq 'Locked|could not be, or could not be, unlocked|could not be unlocked' "$attempt_log"; then
    echo "Device appears locked; retrying in ${LAUNCH_RETRY_DELAY}s. Unlock the iPhone to let the diagnostic launch." | tee -a "$DEST_DIR/headless-launch.log"
    sleep "$LAUNCH_RETRY_DELAY"
    continue
  fi

  break
done

echo "== Read back iOS SQLite state =="
set +e
DEST_DIR="$DEST_DIR/readback" DEVICE_ID="$DEVICE_ID" BUNDLE_ID="$BUNDLE_ID" \
  EXPECT_TEXT="$EXPECT_TEXT" \
  scripts/ios_sync_readback.sh | tee "$DEST_DIR/readback.log"
readback_status=${PIPESTATUS[0]}
set -e

if [[ "$readback_status" -ne 0 ]]; then
  echo "Readback failed with status $readback_status. See $DEST_DIR/readback.log" >&2
  exit "$readback_status"
fi

readback_database="$DEST_DIR/readback/editor.sqlite"
latest_sync_diagnostic="$(sqlite3 "$readback_database" "
  SELECT event_name
  FROM runtime_diagnostics
  WHERE event_name IN ('cloudkit_sync_diagnostic_completed', 'cloudkit_sync_diagnostic_failed')
  ORDER BY created_at DESC, rowid DESC
  LIMIT 1;
" 2>/dev/null || true)"

if [[ "$latest_sync_diagnostic" == "cloudkit_sync_diagnostic_failed" ]]; then
  echo "Latest headless diagnostic recorded a failure. See $DEST_DIR/readback.log" >&2
  exit 1
fi

if [[ "$latest_sync_diagnostic" != "cloudkit_sync_diagnostic_completed" ]]; then
  echo "Headless diagnostic completion was not found in SQLite readback. See $DEST_DIR/readback.log" >&2
  exit 1
fi

if [[ -n "$APPEND_TEXT" ]] && ! grep -Fq "$APPEND_TEXT" "$DEST_DIR/readback.log"; then
  echo "Expected appended text was not found in SQLite readback: $APPEND_TEXT" >&2
  exit 1
fi

if [[ "$launch_status" -ne 0 ]]; then
  echo "Launch command exited with status $launch_status, but SQLite readback contains a completed diagnostic. Treating readback as authoritative." >&2
fi

echo "Headless diagnostic and readback completed. Artifacts are in $DEST_DIR"
