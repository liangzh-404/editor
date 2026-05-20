#!/usr/bin/env bash
set -euo pipefail

DEVICE_ID="${DEVICE_ID:-70629899-4D65-52F9-9040-03C1FD0C697D}"
BUNDLE_ID="${BUNDLE_ID:-com.liangzhang.editor.ios}"
DEST_DIR="${DEST_DIR:-/tmp/editor-ios-sync-readback}"
EXPECT_TEXT="${EXPECT_TEXT:-}"
EXPECT_DIAGNOSTIC="${EXPECT_DIAGNOSTIC:-}"
APP_DB_SUBPATH="Library/Application Support/Editor/editor.sqlite"
APP_SYNC_GENERATION_SUBPATH="Library/Application Support/Editor/.sync-generation"

sql_escape() {
  local value="$1"
  value="${value//\'/\'\'}"
  printf '%s' "$value"
}

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

echo "== Device lock state =="
xcrun devicectl device info lockState --device "$DEVICE_ID"

echo "== Copy iOS editor database =="
set +e
copy_output="$(xcrun devicectl device copy from \
  --device "$DEVICE_ID" \
  --domain-type appDataContainer \
  --domain-identifier "$BUNDLE_ID" \
  --source "$APP_DB_SUBPATH" \
  --destination "$DEST_DIR/editor.sqlite" 2>&1)"
copy_status=$?
set -e
printf '%s\n' "$copy_output"

if [[ "$copy_status" -ne 0 ]]; then
  echo "No iOS editor database was copied. The latest app may be installed but not launched yet." >&2
  exit "$copy_status"
fi

for suffix in -wal -shm; do
  xcrun devicectl device copy from \
    --device "$DEVICE_ID" \
    --domain-type appDataContainer \
    --domain-identifier "$BUNDLE_ID" \
    --source "$APP_DB_SUBPATH$suffix" \
    --destination "$DEST_DIR/editor.sqlite$suffix" >/dev/null 2>&1 || true
done

xcrun devicectl device copy from \
  --device "$DEVICE_ID" \
  --domain-type appDataContainer \
  --domain-identifier "$BUNDLE_ID" \
  --source "$APP_SYNC_GENERATION_SUBPATH" \
  --destination "$DEST_DIR/.sync-generation" >/dev/null 2>&1 || true

echo "== Sync generation =="
if [[ -f "$DEST_DIR/.sync-generation" ]]; then
  tr -d '\r\n' <"$DEST_DIR/.sync-generation"
  printf '\n'
else
  echo "sync generation marker was not copied from $APP_SYNC_GENERATION_SUBPATH"
fi

database="$DEST_DIR/editor.sqlite"

echo "== SQLite sync summary =="
sqlite3 "$database" <<'SQL'
SELECT 'schema_version', COALESCE(MAX(version), 0) FROM schema_migrations;
SELECT 'sync_changes', COUNT(*) FROM sync_changes;
SELECT 'sync_records', COUNT(*) FROM sync_records;
SELECT 'server_change_tokens', COUNT(*) FROM sync_server_change_tokens;
SELECT 'blocks', COUNT(*) FROM blocks;
SQL

echo "== Server change tokens =="
sqlite3 "$database" <<'SQL'
SELECT scope, LENGTH(token_base64), updated_at
FROM sync_server_change_tokens
ORDER BY scope;
SQL

echo "== Pending sync changes =="
sqlite3 "$database" <<'SQL'
SELECT entity_type, entity_id, change_type, attempt_count, COALESCE(last_error, ''), COALESCE(next_attempt_at, '')
FROM sync_changes
ORDER BY created_at, rowid
LIMIT 50;
SQL

runtime_table_count="$(sqlite3 "$database" "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'runtime_diagnostics';")"
if [[ "$runtime_table_count" == "1" ]]; then
  echo "== Runtime diagnostics =="
  sqlite3 "$database" <<'SQL'
SELECT event_name, payload_json, created_at
FROM runtime_diagnostics
ORDER BY created_at DESC, rowid DESC
LIMIT 20;
SQL
else
  echo "== Runtime diagnostics =="
  echo "runtime_diagnostics table is missing; launch the latest app once to migrate the store to schema 11."
fi

echo "== Recent blocks =="
sqlite3 "$database" <<'SQL'
SELECT id, SUBSTR(text_plain, 1, 120), sync_state, updated_at
FROM blocks
WHERE is_deleted = 0
ORDER BY updated_at DESC, rowid DESC
LIMIT 20;
SQL

if [[ -n "$EXPECT_TEXT" ]]; then
  escaped_expect="$(sql_escape "$EXPECT_TEXT")"
  echo "== Expected text readback =="
  sqlite3 "$database" "
  SELECT id, SUBSTR(text_plain, 1, 160), sync_state, updated_at
  FROM blocks
  WHERE is_deleted = 0
    AND text_plain = '$escaped_expect'
  ORDER BY updated_at DESC, rowid DESC
  LIMIT 10;
  "
  expected_count="$(sqlite3 "$database" "SELECT COUNT(*) FROM blocks WHERE is_deleted = 0 AND text_plain = '$escaped_expect';")"
  if [[ "$expected_count" == "0" ]]; then
    echo "Expected text was not found in iOS SQLite readback: $EXPECT_TEXT" >&2
    exit 1
  fi
fi

if [[ -n "$EXPECT_DIAGNOSTIC" ]]; then
  if [[ "$runtime_table_count" != "1" ]]; then
    echo "Expected runtime diagnostic could not be checked because runtime_diagnostics is missing: $EXPECT_DIAGNOSTIC" >&2
    exit 1
  fi

  escaped_diagnostic="$(sql_escape "$EXPECT_DIAGNOSTIC")"
  echo "== Expected runtime diagnostic readback =="
  sqlite3 "$database" "
  SELECT event_name, payload_json, created_at
  FROM runtime_diagnostics
  WHERE event_name = '$escaped_diagnostic'
  ORDER BY created_at DESC, rowid DESC
  LIMIT 10;
  "
  diagnostic_count="$(sqlite3 "$database" "SELECT COUNT(*) FROM runtime_diagnostics WHERE event_name = '$escaped_diagnostic';")"
  if [[ "$diagnostic_count" == "0" ]]; then
    echo "Expected runtime diagnostic was not found in iOS SQLite readback: $EXPECT_DIAGNOSTIC" >&2
    exit 1
  fi
fi

echo "Database copied to $database"
