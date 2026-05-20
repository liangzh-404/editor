#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUNDLE_ID="${BUNDLE_ID:-com.liangzhang.editor.ios}"
SIM_ID="${SIM_ID:-}"
DEST_DIR="${DEST_DIR:-/tmp/editor-ios-simulator-silent-push}"
RESET_SIM_APP="${RESET_SIM_APP:-1}"
BUILD_SIM_APP="${BUILD_SIM_APP:-1}"
INSTALL_SIM_APP="${INSTALL_SIM_APP:-1}"
RUN_TIMEOUT_SECONDS="${RUN_TIMEOUT_SECONDS:-120}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-2}"
ALLOW_FAILED_RESULT="${ALLOW_FAILED_RESULT:-1}"
APP_PATH="${APP_PATH:-}"

if [[ -z "$SIM_ID" ]]; then
  SIM_ID="$(xcrun simctl list devices booted | awk -F'[()]' '/Booted/ { print $2; exit }')"
fi
if [[ -z "$SIM_ID" ]]; then
  echo "No booted iOS Simulator found. Boot one or pass SIM_ID=<device-udid>." >&2
  exit 2
fi

if [[ "$RESET_SIM_APP" == "1" && "$INSTALL_SIM_APP" != "1" ]]; then
  echo "RESET_SIM_APP=1 requires INSTALL_SIM_APP=1 so the app can be relaunched after data reset." >&2
  exit 2
fi

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

if [[ "$BUILD_SIM_APP" == "1" ]]; then
  echo "== Build iOS Simulator Debug app =="
  xcodebuild build \
    -scheme EditorIOS \
    -configuration Debug \
    -destination "id=$SIM_ID"
else
  echo "== Skip iOS Simulator build =="
fi

if [[ "$INSTALL_SIM_APP" == "1" && -z "$APP_PATH" ]]; then
  products_dir="$(xcodebuild -showBuildSettings \
    -scheme EditorIOS \
    -configuration Debug \
    -destination "id=$SIM_ID" \
    | awk -F'= ' '/^[[:space:]]*BUILT_PRODUCTS_DIR = / { value=$2 } END { print value }')"
  APP_PATH="$products_dir/EditorIOS.app"
fi
if [[ "$INSTALL_SIM_APP" == "1" && ! -d "$APP_PATH" ]]; then
  echo "iOS Simulator app not found: $APP_PATH" >&2
  exit 2
fi

if [[ "$RESET_SIM_APP" == "1" ]]; then
  echo "== Reset Simulator app data =="
  xcrun simctl uninstall "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
fi

if [[ "$INSTALL_SIM_APP" == "1" ]]; then
  echo "== Install Simulator app =="
  xcrun simctl install "$SIM_ID" "$APP_PATH"
else
  echo "== Skip iOS Simulator install =="
fi

container="$(xcrun simctl get_app_container "$SIM_ID" "$BUNDLE_ID" data)"
database="$container/Library/Application Support/Editor/editor.sqlite"
printf 'sim_id=%s\ncontainer=%s\ndatabase=%s\n' "$SIM_ID" "$container" "$database" >"$DEST_DIR/status.log"

baseline_rowid=0
if [[ -f "$database" ]]; then
  baseline_rowid="$(sqlite3 "$database" "
    SELECT COALESCE(MAX(rowid), 0)
    FROM runtime_diagnostics;
  " 2>/dev/null || echo 0)"
fi
baseline_rowid="${baseline_rowid:-0}"
printf 'baseline_runtime_diagnostic_rowid=%s\n' "$baseline_rowid" >>"$DEST_DIR/status.log"

payload="$DEST_DIR/silent-push.apns"
cat > "$payload" <<JSON
{
  "Simulator Target Bundle": "$BUNDLE_ID",
  "aps": {
    "content-available": 1
  },
  "editorDiagnostic": "silent-push"
}
JSON

echo "== Terminate Simulator app before push =="
xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "== Send simulated silent push =="
xcrun simctl push "$SIM_ID" "$BUNDLE_ID" "$payload" 2>&1 | tee "$DEST_DIR/push.log"

deadline=$((SECONDS + RUN_TIMEOUT_SECONDS))
diagnostic_event=""
while [[ "$SECONDS" -lt "$deadline" ]]; do
  if [[ -f "$database" ]]; then
    diagnostic_event="$(sqlite3 "$database" "
      SELECT rowid || '|' || event_name || '|' || payload_json || '|' || created_at
      FROM runtime_diagnostics
      WHERE rowid > $baseline_rowid
        AND event_name IN ('remote_notification_sync_completed', 'remote_notification_environment_failed')
      ORDER BY rowid DESC
      LIMIT 1;
    " 2>/dev/null || true)"
    if [[ -n "$diagnostic_event" ]]; then
      break
    fi
  fi
  sleep "$POLL_INTERVAL_SECONDS"
done

echo "== Silent push diagnostic event =="
if [[ -n "$diagnostic_event" ]]; then
  printf '%s\n' "$diagnostic_event"
else
  echo "No remote-notification diagnostic event was recorded before timeout."
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
SELECT rowid, event_name, payload_json, created_at
FROM runtime_diagnostics
ORDER BY rowid DESC
LIMIT 20;
SQL

echo "== Pending sync changes =="
sqlite3 "$DEST_DIR/editor.sqlite" <<'SQL'
SELECT entity_type, entity_id, change_type, attempt_count, COALESCE(last_error, ''), COALESCE(next_attempt_at, '')
FROM sync_changes
ORDER BY created_at, rowid
LIMIT 50;
SQL

if [[ -z "$diagnostic_event" ]]; then
  exit 1
fi

if [[ "$diagnostic_event" == *'"result":"failed"'* && "$ALLOW_FAILED_RESULT" != "1" ]]; then
  echo "Silent push handler ran but returned failed. See $DEST_DIR/editor.sqlite." >&2
  exit 1
fi

echo "iOS Simulator silent push diagnostic completed. Artifacts are in $DEST_DIR"
