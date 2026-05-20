#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUNDLE_ID="${BUNDLE_ID:-com.liangzhang.editor.mac}"
DEST_DIR="${DEST_DIR:-/tmp/editor-macos-cloudkit-runtime-probe}"
BUILD_MAC_APP="${BUILD_MAC_APP:-1}"
RUN_TIMEOUT_SECONDS="${RUN_TIMEOUT_SECONDS:-90}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-2}"
TERMINATE_EXISTING="${TERMINATE_EXISTING:-1}"
APP_PATH="${APP_PATH:-}"
APP_SUPPORT_DIR="${APP_SUPPORT_DIR:-$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Application Support}"
DATABASE_PATH="${DATABASE_PATH:-$APP_SUPPORT_DIR/Editor/editor.sqlite}"

database_scalar() {
  local sql="$1"
  if [[ ! -f "$DATABASE_PATH" ]]; then
    return 1
  fi
  sqlite3 "$DATABASE_PATH" "$sql"
}

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

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
fi

start_rowid="0"
if [[ -f "$DATABASE_PATH" ]]; then
  start_rowid="$(sqlite3 "$DATABASE_PATH" "SELECT COALESCE(MAX(rowid), 0) FROM runtime_diagnostics;" 2>/dev/null || printf '0')"
fi

echo "== Launch macOS CloudKit runtime probe diagnostic =="
(
  env \
    EDITOR_CLOUDKIT_RUNTIME_PROBE_DIAGNOSTIC=1 \
    OS_ACTIVITY_DT_MODE=1 \
    OS_ACTIVITY_MODE=enable \
    "$app_executable"
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
        AND event_name IN ('cloudkit_runtime_probe_completed', 'cloudkit_runtime_probe_failed')
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

echo "== Runtime probe event =="
if [[ -n "$diagnostic_event" ]]; then
  printf '%s\n' "$diagnostic_event"
else
  echo "No runtime probe event was recorded before timeout."
fi

echo "== SQLite sync summary =="
if [[ ! -f "$DATABASE_PATH" ]]; then
  echo "Database not found: $DATABASE_PATH" >&2
  exit 1
fi

sqlite3 "$DATABASE_PATH" <<'SQL'
SELECT 'schema_version', COALESCE(MAX(version), 0) FROM schema_migrations;
SELECT 'sync_changes', COUNT(*) FROM sync_changes;
SELECT 'runtime_diagnostics', COUNT(*) FROM runtime_diagnostics;
SQL

echo "== Runtime probe diagnostics from this run =="
sqlite3 "$DATABASE_PATH" "
SELECT event_name, payload_json, created_at
FROM runtime_diagnostics
WHERE rowid > $start_rowid
ORDER BY rowid DESC;
"

if [[ "$diagnostic_event" == cloudkit_runtime_probe_failed* ]]; then
  echo "CloudKit runtime probe failed." >&2
  exit 1
fi

if [[ -z "$diagnostic_event" ]]; then
  exit 1
fi

echo "macOS CloudKit runtime probe completed. Artifacts are in $DEST_DIR"
