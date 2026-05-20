#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUNDLE_ID="${BUNDLE_ID:-com.liangzhang.editor.ios}"
SIM_ID="${SIM_ID:-}"
DEST_DIR="${DEST_DIR:-/tmp/editor-ios-simulator-headless-sync}"
APPEND_TEXT="${APPEND_TEXT:-}"
PAGE_ID="${PAGE_ID:-}"
RESET_SIM_APP="${RESET_SIM_APP:-1}"
BUILD_SIM_APP="${BUILD_SIM_APP:-1}"
RUN_TIMEOUT_SECONDS="${RUN_TIMEOUT_SECONDS:-120}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-2}"
ALLOW_DIAGNOSTIC_FAILURE="${ALLOW_DIAGNOSTIC_FAILURE:-0}"
APP_PATH="${APP_PATH:-}"

if [[ -z "$SIM_ID" ]]; then
  SIM_ID="$(xcrun simctl list devices booted | awk -F'[()]' '/Booted/ { print $2; exit }')"
fi
if [[ -z "$SIM_ID" ]]; then
  echo "No booted iOS Simulator found. Boot one or pass SIM_ID=<device-udid>." >&2
  exit 2
fi

sql_escape() {
  local value="$1"
  value="${value//\'/\'\'}"
  printf '%s' "$value"
}

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"
if [[ -n "$APPEND_TEXT" ]]; then
  printf '%s\n' "$APPEND_TEXT" > "$DEST_DIR/append-text.txt"
fi

if [[ "$BUILD_SIM_APP" == "1" ]]; then
  echo "== Build iOS Simulator Debug app =="
  xcodebuild build \
    -scheme EditorIOS \
    -configuration Debug \
    -destination "id=$SIM_ID"
fi

if [[ -z "$APP_PATH" ]]; then
  products_dir="$(xcodebuild -showBuildSettings \
    -scheme EditorIOS \
    -configuration Debug \
    -destination "id=$SIM_ID" \
    | awk -F'= ' '/^[[:space:]]*BUILT_PRODUCTS_DIR = / { value=$2 } END { print value }')"
  APP_PATH="$products_dir/EditorIOS.app"
fi
if [[ ! -d "$APP_PATH" ]]; then
  echo "iOS Simulator app not found: $APP_PATH" >&2
  exit 2
fi

if [[ "$RESET_SIM_APP" == "1" ]]; then
  echo "== Reset Simulator app data =="
  xcrun simctl uninstall "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
fi

echo "== Install Simulator app =="
xcrun simctl install "$SIM_ID" "$APP_PATH"

launch_env=(
  "SIMCTL_CHILD_EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC=1"
  "SIMCTL_CHILD_OS_ACTIVITY_DT_MODE=1"
  "SIMCTL_CHILD_OS_ACTIVITY_MODE=enable"
)
if [[ -n "$APPEND_TEXT" ]]; then
  launch_env+=("SIMCTL_CHILD_EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC_APPEND_TEXT=$APPEND_TEXT")
fi
if [[ -n "$PAGE_ID" ]]; then
  launch_env+=("SIMCTL_CHILD_EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC_PAGE_ID=$PAGE_ID")
fi

echo "== Launch Simulator headless CloudKit sync diagnostic =="
set +e
env "${launch_env[@]}" \
  xcrun simctl launch --terminate-running-process "$SIM_ID" "$BUNDLE_ID" \
  >"$DEST_DIR/launch.log" 2>&1
launch_status=$?
set -e
cat "$DEST_DIR/launch.log"
if [[ "$launch_status" -ne 0 ]]; then
  echo "Simulator launch failed with status $launch_status. See $DEST_DIR/launch.log" >&2
  exit "$launch_status"
fi

container="$(xcrun simctl get_app_container "$SIM_ID" "$BUNDLE_ID" data)"
database="$container/Library/Application Support/Editor/editor.sqlite"
printf 'sim_id=%s\ncontainer=%s\ndatabase=%s\n' "$SIM_ID" "$container" "$database" >"$DEST_DIR/status.log"

deadline=$((SECONDS + RUN_TIMEOUT_SECONDS))
diagnostic_event=""
while [[ "$SECONDS" -lt "$deadline" ]]; do
  if [[ -f "$database" ]]; then
    diagnostic_event="$(sqlite3 "$database" "
      SELECT event_name || '|' || payload_json || '|' || created_at
      FROM runtime_diagnostics
      WHERE event_name IN ('cloudkit_sync_diagnostic_completed', 'cloudkit_sync_diagnostic_failed')
      ORDER BY rowid DESC
      LIMIT 1;
    " 2>/dev/null || true)"
    if [[ -n "$diagnostic_event" ]]; then
      break
    fi
  fi
  sleep "$POLL_INTERVAL_SECONDS"
done

echo "== Diagnostic event =="
if [[ -n "$diagnostic_event" ]]; then
  printf '%s\n' "$diagnostic_event"
else
  echo "No diagnostic event was recorded before timeout."
fi

if [[ ! -f "$database" ]]; then
  echo "Database not found: $database" >&2
  exit 1
fi
cp "$database" "$DEST_DIR/editor.sqlite"
for suffix in -wal -shm; do
  [[ -f "$database$suffix" ]] && cp "$database$suffix" "$DEST_DIR/editor.sqlite$suffix" || true
done

echo "== Simulator SQLite sync summary =="
sqlite3 "$DEST_DIR/editor.sqlite" <<'SQL'
SELECT 'schema_version', COALESCE(MAX(version), 0) FROM schema_migrations;
SELECT 'sync_changes', COUNT(*) FROM sync_changes;
SELECT 'sync_records', COUNT(*) FROM sync_records;
SELECT 'server_change_tokens', COUNT(*) FROM sync_server_change_tokens;
SELECT 'runtime_diagnostics', COUNT(*) FROM runtime_diagnostics;
SELECT 'blocks', COUNT(*) FROM blocks;
SQL

echo "== Runtime diagnostics =="
sqlite3 "$DEST_DIR/editor.sqlite" <<'SQL'
SELECT event_name, payload_json, created_at
FROM runtime_diagnostics
ORDER BY rowid DESC
LIMIT 20;
SQL

if [[ -n "$APPEND_TEXT" ]]; then
  escaped_append="$(sql_escape "$APPEND_TEXT")"
  echo "== Appended block readback =="
  sqlite3 "$DEST_DIR/editor.sqlite" "
  SELECT id, SUBSTR(text_plain, 1, 160), sync_state, updated_at
  FROM blocks
  WHERE is_deleted = 0
    AND text_plain = '$escaped_append'
  ORDER BY updated_at DESC, rowid DESC
  LIMIT 10;
  "
fi

echo "== Pending sync changes =="
sqlite3 "$DEST_DIR/editor.sqlite" <<'SQL'
SELECT entity_type, entity_id, change_type, attempt_count, COALESCE(last_error, ''), COALESCE(next_attempt_at, '')
FROM sync_changes
ORDER BY created_at, rowid
LIMIT 50;
SQL

echo "== Recent blocks =="
sqlite3 "$DEST_DIR/editor.sqlite" <<'SQL'
SELECT id, SUBSTR(text_plain, 1, 120), sync_state, updated_at
FROM blocks
WHERE is_deleted = 0
ORDER BY updated_at DESC, rowid DESC
LIMIT 20;
SQL

if [[ -z "$diagnostic_event" ]]; then
  exit 1
fi

if [[ "$diagnostic_event" == cloudkit_sync_diagnostic_failed* && "$ALLOW_DIAGNOSTIC_FAILURE" != "1" ]]; then
  echo "CloudKit diagnostic failed." >&2
  exit 1
fi

if [[ -n "$APPEND_TEXT" ]]; then
  appended_count="$(sqlite3 "$DEST_DIR/editor.sqlite" "SELECT COUNT(*) FROM blocks WHERE is_deleted = 0 AND text_plain = '$(sql_escape "$APPEND_TEXT")';")"
  if [[ "$appended_count" == "0" ]]; then
    echo "Expected appended text was not found in SQLite: $APPEND_TEXT" >&2
    exit 1
  fi
fi

echo "iOS Simulator headless diagnostic completed. Artifacts are in $DEST_DIR"
