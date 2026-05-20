#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUNDLE_ID="${BUNDLE_ID:-com.liangzhang.editor.mac}"
DEST_DIR="${DEST_DIR:-/tmp/editor-macos-headless-sync}"
APPEND_TEXT="${APPEND_TEXT:-}"
EXPECT_TEXT="${EXPECT_TEXT:-}"
PAGE_ID="${PAGE_ID:-}"
BUILD_MAC_APP="${BUILD_MAC_APP:-1}"
RUN_TIMEOUT_SECONDS="${RUN_TIMEOUT_SECONDS:-90}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-2}"
TERMINATE_EXISTING="${TERMINATE_EXISTING:-1}"
APP_PATH="${APP_PATH:-}"
APP_SUPPORT_DIR="${APP_SUPPORT_DIR:-$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Application Support}"
DATABASE_PATH="${DATABASE_PATH:-$APP_SUPPORT_DIR/Editor/editor.sqlite}"

sql_escape() {
  local value="$1"
  value="${value//\'/\'\'}"
  printf '%s' "$value"
}

database_scalar() {
  local sql="$1"
  if [[ ! -f "$DATABASE_PATH" ]]; then
    return 1
  fi
  sqlite3 "$DATABASE_PATH" "$sql"
}

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"
if [[ -n "$APPEND_TEXT" ]]; then
  printf '%s\n' "$APPEND_TEXT" > "$DEST_DIR/append-text.txt"
fi

if [[ "$BUILD_MAC_APP" == "1" ]]; then
  echo "== Build macOS Debug app =="
  xcodebuild build \
    -scheme EditorMac \
    -configuration Debug \
    -destination 'platform=macOS' \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration
fi

if [[ -z "$APP_PATH" ]]; then
  products_dir="$(xcodebuild -showBuildSettings \
    -scheme EditorMac \
    -configuration Debug \
    -destination 'platform=macOS' \
    | awk -F'= ' '/^[[:space:]]*BUILT_PRODUCTS_DIR = / { value=$2 } END { print value }')"
  APP_PATH="$products_dir/EditorMac.app"
fi
app_executable="$APP_PATH/Contents/MacOS/EditorMac"
if [[ ! -x "$app_executable" ]]; then
  echo "macOS app executable not found: $app_executable" >&2
  exit 2
fi

if [[ "$TERMINATE_EXISTING" == "1" ]]; then
  echo "== Terminate existing EditorMac processes =="
  existing_pids="$(pgrep -x EditorMac || true)"
  if [[ -n "$existing_pids" ]]; then
    printf '%s\n' "$existing_pids" | while IFS= read -r pid; do
      [[ -n "$pid" ]] || continue
      kill "$pid" >/dev/null 2>&1 || true
    done
    sleep 2
  fi
  pgrep -x EditorMac >/dev/null 2>&1 && {
    echo "Existing EditorMac process is still running after terminate request." >&2
    exit 1
  }
fi

start_rowid="0"
if [[ -f "$DATABASE_PATH" ]]; then
  start_rowid="$(sqlite3 "$DATABASE_PATH" "SELECT COALESCE(MAX(rowid), 0) FROM runtime_diagnostics;" 2>/dev/null || printf '0')"
fi

echo "== Launch macOS headless CloudKit sync diagnostic =="
launch_env=(
  "EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC=1"
  "OS_ACTIVITY_DT_MODE=1"
  "OS_ACTIVITY_MODE=enable"
)
if [[ -n "$APPEND_TEXT" ]]; then
  launch_env+=("EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC_APPEND_TEXT=$APPEND_TEXT")
fi
if [[ -n "$PAGE_ID" ]]; then
  launch_env+=("EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC_PAGE_ID=$PAGE_ID")
fi

(
  env "${launch_env[@]}" "$app_executable"
) >"$DEST_DIR/app-stdout.log" 2>"$DEST_DIR/app-stderr.log" &
app_pid=$!

cleanup() {
  if kill -0 "$app_pid" >/dev/null 2>&1; then
    kill "$app_pid" >/dev/null 2>&1 || true
    wait "$app_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

deadline=$((SECONDS + RUN_TIMEOUT_SECONDS))
diagnostic_event=""
while [[ "$SECONDS" -lt "$deadline" ]]; do
  if [[ -f "$DATABASE_PATH" ]]; then
    diagnostic_event="$(sqlite3 "$DATABASE_PATH" "
      SELECT event_name || '|' || payload_json || '|' || created_at
      FROM runtime_diagnostics
      WHERE rowid > $start_rowid
        AND event_name IN ('cloudkit_sync_diagnostic_completed', 'cloudkit_sync_diagnostic_failed')
      ORDER BY rowid DESC
      LIMIT 1;
    " 2>/dev/null || true)"
    if [[ -n "$diagnostic_event" ]]; then
      break
    fi
  fi

  if ! kill -0 "$app_pid" >/dev/null 2>&1; then
    break
  fi
  sleep "$POLL_INTERVAL_SECONDS"
done

echo "== Diagnostic event =="
if [[ -n "$diagnostic_event" ]]; then
  printf '%s\n' "$diagnostic_event"
else
  echo "No diagnostic event was recorded before timeout."
fi

echo "== SQLite sync summary =="
if [[ ! -f "$DATABASE_PATH" ]]; then
  echo "Database not found: $DATABASE_PATH" >&2
  exit 1
fi

sqlite3 "$DATABASE_PATH" <<'SQL'
SELECT 'schema_version', COALESCE(MAX(version), 0) FROM schema_migrations;
SELECT 'sync_changes', COUNT(*) FROM sync_changes;
SELECT 'sync_records', COUNT(*) FROM sync_records;
SELECT 'server_change_tokens', COUNT(*) FROM sync_server_change_tokens;
SELECT 'blocks', COUNT(*) FROM blocks;
SQL

echo "== Runtime diagnostics from this run =="
sqlite3 "$DATABASE_PATH" "
SELECT event_name, payload_json, created_at
FROM runtime_diagnostics
WHERE rowid > $start_rowid
ORDER BY rowid DESC;
"

echo "== Server change tokens =="
sqlite3 "$DATABASE_PATH" <<'SQL'
SELECT scope, LENGTH(token_base64), updated_at
FROM sync_server_change_tokens
ORDER BY scope;
SQL

if [[ -n "$APPEND_TEXT" ]]; then
  escaped_append="$(sql_escape "$APPEND_TEXT")"
  echo "== Appended block readback =="
  sqlite3 "$DATABASE_PATH" "
  SELECT id, SUBSTR(text_plain, 1, 160), sync_state, updated_at
  FROM blocks
  WHERE is_deleted = 0
    AND text_plain = '$escaped_append'
  ORDER BY updated_at DESC, rowid DESC
  LIMIT 10;
  "

  echo "== Appended block sync records =="
  sqlite3 "$DATABASE_PATH" "
  SELECT entity_type, entity_id, record_name, change_tag
  FROM sync_records
  WHERE entity_id IN (
    SELECT id
    FROM blocks
    WHERE is_deleted = 0
      AND text_plain = '$escaped_append'
  )
  ORDER BY entity_type, entity_id;
  "
fi

echo "== Recent blocks =="
sqlite3 "$DATABASE_PATH" <<'SQL'
SELECT id, SUBSTR(text_plain, 1, 120), sync_state, updated_at
FROM blocks
WHERE is_deleted = 0
ORDER BY updated_at DESC, rowid DESC
LIMIT 20;
SQL

if [[ "$diagnostic_event" == cloudkit_sync_diagnostic_failed* ]]; then
  echo "CloudKit diagnostic failed." >&2
  exit 1
fi

if [[ -z "$diagnostic_event" ]]; then
  exit 1
fi

if [[ -n "$APPEND_TEXT" ]]; then
  appended_count="$(database_scalar "SELECT COUNT(*) FROM blocks WHERE is_deleted = 0 AND text_plain = '$(sql_escape "$APPEND_TEXT")';")"
  if [[ "$appended_count" == "0" ]]; then
    echo "Expected appended text was not found in SQLite: $APPEND_TEXT" >&2
    exit 1
  fi
fi

if [[ -n "$EXPECT_TEXT" ]]; then
  escaped_expect="$(sql_escape "$EXPECT_TEXT")"
  echo "== Expected text readback =="
  sqlite3 "$DATABASE_PATH" "
  SELECT id, SUBSTR(text_plain, 1, 160), sync_state, updated_at
  FROM blocks
  WHERE is_deleted = 0
    AND text_plain = '$escaped_expect'
  ORDER BY updated_at DESC, rowid DESC
  LIMIT 10;
  "
  expected_count="$(database_scalar "SELECT COUNT(*) FROM blocks WHERE is_deleted = 0 AND text_plain = '$escaped_expect';")"
  if [[ "$expected_count" == "0" ]]; then
    echo "Expected text was not found in macOS SQLite: $EXPECT_TEXT" >&2
    exit 1
  fi
fi

echo "macOS headless diagnostic completed. Artifacts are in $DEST_DIR"
