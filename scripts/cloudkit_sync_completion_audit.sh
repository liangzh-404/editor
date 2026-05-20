#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MAC_BUNDLE_ID="${MAC_BUNDLE_ID:-com.liangzhang.editor.mac}"
MAC_DATABASE_PATH="${MAC_DATABASE_PATH:-$HOME/Library/Containers/$MAC_BUNDLE_ID/Data/Library/Application Support/Editor/editor.sqlite}"
MAC_SYNC_GENERATION_MARKER_PATH="${MAC_SYNC_GENERATION_MARKER_PATH:-$(dirname "$MAC_DATABASE_PATH")/.sync-generation}"
IOS_READBACK_DIR="${IOS_READBACK_DIR:-/tmp/editor-ios-headless-sync/readback}"
IOS_APNS_READBACK_DIR="${IOS_APNS_READBACK_DIR:-/tmp/editor-ios-apns-registration-probe/readback}"
IOS_SYNC_GENERATION_MARKER_PATH="${IOS_SYNC_GENERATION_MARKER_PATH:-$IOS_READBACK_DIR/.sync-generation}"
CROSS_DEVICE_STATE_DIR="${CROSS_DEVICE_STATE_DIR:-/tmp/editor-cloudkit-cross-device-sync}"
if [[ -z "${MAC_EXPECT_TEXT+x}" && -f "$CROSS_DEVICE_STATE_DIR/completed.ok" && -f "$CROSS_DEVICE_STATE_DIR/mac-origin-text.txt" ]]; then
  MAC_EXPECT_TEXT="$(<"$CROSS_DEVICE_STATE_DIR/mac-origin-text.txt")"
else
  MAC_EXPECT_TEXT="${MAC_EXPECT_TEXT:-}"
fi
if [[ -z "${IOS_EXPECT_TEXT+x}" && -f "$CROSS_DEVICE_STATE_DIR/completed.ok" && -f "$CROSS_DEVICE_STATE_DIR/ios-origin-text.txt" ]]; then
  IOS_EXPECT_TEXT="$(<"$CROSS_DEVICE_STATE_DIR/ios-origin-text.txt")"
else
  IOS_EXPECT_TEXT="${IOS_EXPECT_TEXT:-}"
fi
REQUIRED_IOS_DIAGNOSTIC="${REQUIRED_IOS_DIAGNOSTIC:-remote_notification_registration_succeeded}"
REQUIRED_IOS_REMOTE_NOTIFICATION_SYNC_DIAGNOSTIC="${REQUIRED_IOS_REMOTE_NOTIFICATION_SYNC_DIAGNOSTIC:-remote_notification_sync_completed}"
EXPECTED_SYNC_GENERATION="${EXPECTED_SYNC_GENERATION:-editor-cloudkit-v2}"
CHECK_CLOUDKIT_SCHEMA="${CHECK_CLOUDKIT_SCHEMA:-1}"
CLOUDKIT_TEAM_ID="${CLOUDKIT_TEAM_ID:-H52N5N7WQ7}"
CLOUDKIT_CONTAINER_ID="${CLOUDKIT_CONTAINER_ID:-iCloud.com.liangzhang.editor.sync}"
CLOUDKIT_SCHEMA_ENVIRONMENTS="${CLOUDKIT_SCHEMA_ENVIRONMENTS:-development production}"
CLOUDKIT_SCHEMA_FILE="${CLOUDKIT_SCHEMA_FILE:-docs/cloudkit/editor-cloudkit-schema.ckdb}"
CLOUDKIT_REQUIRED_RECORD_TYPES="${CLOUDKIT_REQUIRED_RECORD_TYPES:-WorkspaceRecord NotebookRecord PageRecord AttachmentRecord BlockRecord EditorRuntimeProbeRecord}"
REQUIRE_PRODUCTION_SCHEMA="${REQUIRE_PRODUCTION_SCHEMA:-0}"
CHECK_SIGNED_PRODUCTS="${CHECK_SIGNED_PRODUCTS:-1}"
MAC_APP_PATH="${MAC_APP_PATH:-}"
IOS_APP_PATH="${IOS_APP_PATH:-}"
status=0

pass() {
  printf 'PASS|%s|%s\n' "$1" "$2"
}

fail() {
  printf 'FAIL|%s|%s\n' "$1" "$2"
  status=1
}

skip() {
  printf 'SKIP|%s|%s\n' "$1" "$2"
}

warn() {
  printf 'WARN|%s|%s\n' "$1" "$2"
}

schema_fail() {
  local environment="$1"
  local code="$2"
  local message="$3"
  if [[ "$environment" == "production" && "$REQUIRE_PRODUCTION_SCHEMA" != "1" ]]; then
    warn "$code" "$message; set REQUIRE_PRODUCTION_SCHEMA=1 to make this a release gate"
  else
    fail "$code" "$message"
  fi
}

file_contains() {
  local file="$1"
  local pattern="$2"
  [[ -f "$file" ]] && grep -Fq "$pattern" "$file"
}

build_product_path() {
  local scheme="$1"
  local destination="$2"
  local product_name="$3"

  local products_dir
  products_dir="$(xcodebuild -showBuildSettings \
    -scheme "$scheme" \
    -configuration Debug \
    -destination "$destination" \
    2>/dev/null \
    | awk -F'= ' '/^[[:space:]]*BUILT_PRODUCTS_DIR = / { value=$2 } END { print value }')"

  if [[ -n "$products_dir" ]]; then
    printf '%s/%s\n' "$products_dir" "$product_name"
  fi
}

signed_entitlements_file() {
  local app_path="$1"
  local output_file="$2"

  [[ -d "$app_path" ]] || return 1
  codesign -d --entitlements :- "$app_path" >"$output_file" 2>/dev/null
}

entitlements_contains() {
  local entitlements_file="$1"
  local pattern="$2"
  grep -Fq "$pattern" "$entitlements_file"
}

sqlite_scalar() {
  local database="$1"
  local sql="$2"
  sqlite3 "$database" "$sql"
}

latest_apns_registration_diagnostic() {
  local database="$1"
  sqlite3 "$database" "
    SELECT event_name || ' payload=' || payload_json || ' created_at=' || created_at
    FROM runtime_diagnostics
    WHERE event_name IN (
      'remote_notification_registration_succeeded',
      'remote_notification_registration_failed'
    )
    ORDER BY created_at DESC, rowid DESC
    LIMIT 1;
  "
}

latest_remote_notification_sync_diagnostic() {
  local database="$1"
  sqlite3 "$database" "
    SELECT event_name || ' payload=' || payload_json || ' created_at=' || created_at
    FROM runtime_diagnostics
    WHERE event_name = 'remote_notification_sync_completed'
    ORDER BY created_at DESC, rowid DESC
    LIMIT 1;
  "
}

schema_contains_record_type() {
  local schema_file="$1"
  local record_type="$2"
  grep -Fq "RECORD TYPE $record_type (" "$schema_file"
}

schema_field_signature() {
  local schema_file="$1"
  local record_type="$2"
  awk -v record_type="$record_type" '
    $0 ~ "^[[:space:]]*RECORD TYPE " record_type " \\(" {
      in_record_type = 1
      next
    }
    in_record_type && $0 ~ "^[[:space:]]*\\);" {
      exit
    }
    in_record_type {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/,[[:space:]]*$/, "", line)
      if (line == "" || line ~ /^GRANT /) {
        next
      }
      split(line, parts, /[[:space:]]+/)
      field_name = parts[1]
      field_type = parts[2]
      gsub(/"/, "", field_name)
      if (field_name ~ /^___/) {
        next
      }
      print field_name ":" field_type
    }
  ' "$schema_file" | sort
}

assert_sync_generation_marker() {
  local code="$1"
  local marker_path="$2"
  local platform_name="$3"

  if [[ ! -f "$marker_path" ]]; then
    fail "$code" "$platform_name sync generation marker not found at $marker_path"
    return
  fi

  local actual_generation
  actual_generation="$(tr -d '\r\n' <"$marker_path")"
  if [[ "$actual_generation" == "$EXPECTED_SYNC_GENERATION" ]]; then
    pass "$code" "$platform_name sync generation marker is $actual_generation"
  else
    fail "$code" "$platform_name sync generation marker is $actual_generation; expected $EXPECTED_SYNC_GENERATION"
  fi
}

assert_schema_fields_match() {
  local environment="$1"
  local schema_file="$2"
  local record_type="$3"

  if [[ ! -f "$CLOUDKIT_SCHEMA_FILE" ]]; then
    fail "cloudkit_schema:source" "schema source file not found at $CLOUDKIT_SCHEMA_FILE"
    return
  fi

  local expected_fields
  local actual_fields
  expected_fields="$(schema_field_signature "$CLOUDKIT_SCHEMA_FILE" "$record_type")"
  actual_fields="$(schema_field_signature "$schema_file" "$record_type")"

  if [[ "$expected_fields" == "$actual_fields" ]]; then
    pass "cloudkit_schema:$environment:$record_type:fields" "$environment schema fields match source for $record_type"
    return
  fi

  local missing_count
  local extra_count
  missing_count="$(comm -23 <(printf '%s\n' "$expected_fields") <(printf '%s\n' "$actual_fields") | sed '/^$/d' | wc -l | tr -d ' ')"
  extra_count="$(comm -13 <(printf '%s\n' "$expected_fields") <(printf '%s\n' "$actual_fields") | sed '/^$/d' | wc -l | tr -d ' ')"
  schema_fail "$environment" \
    "cloudkit_schema:$environment:$record_type:fields" \
    "$environment schema fields differ from source for $record_type missing=$missing_count extra=$extra_count"
}

echo "== CloudKit sync completion audit =="

if file_contains Sources/EditorCore/Store/SyncEngine.swift 'iCloud.com.liangzhang.editor.sync'; then
  pass "explicit_container" "CloudKit code references iCloud.com.liangzhang.editor.sync"
else
  fail "explicit_container" "CloudKit code does not reference the expected explicit container"
fi

if file_contains Sources/EditorCore/Store/SyncEngine.swift 'CKContainer(identifier: containerIdentifier)'; then
  pass "no_default_container" "CloudKit runtime uses CKContainer(identifier:)"
else
  fail "no_default_container" "CloudKit runtime does not show CKContainer(identifier:)"
fi

if file_contains Sources/EditorApp/EditorIOS.entitlements 'iCloud.com.liangzhang.editor.sync' &&
   file_contains Sources/EditorApp/EditorMac.entitlements 'iCloud.com.liangzhang.editor.sync'; then
  pass "source_entitlements" "iOS and macOS source entitlements declare the sync container"
else
  fail "source_entitlements" "iOS or macOS source entitlements are missing the sync container"
fi

if file_contains Sources/EditorApp/EditorMac.entitlements 'com.apple.security.network.client'; then
  pass "mac_network_entitlement" "macOS source entitlements include network client"
else
  fail "mac_network_entitlement" "macOS source entitlements are missing network client"
fi

if file_contains Sources/EditorApp/EditorIOS-Info.plist 'remote-notification'; then
  pass "ios_background_mode" "iOS Info.plist declares remote-notification background mode"
else
  fail "ios_background_mode" "iOS Info.plist is missing remote-notification background mode"
fi

if [[ "$CHECK_SIGNED_PRODUCTS" == "1" ]]; then
  signed_tmpdir="$(mktemp -d /tmp/editor-signed-entitlements-audit.XXXXXX)"
  if [[ -z "$MAC_APP_PATH" ]]; then
    MAC_APP_PATH="$(build_product_path EditorMac 'platform=macOS' EditorMac.app)"
  fi
  if [[ -z "$IOS_APP_PATH" ]]; then
    IOS_APP_PATH="$(build_product_path EditorIOS 'generic/platform=iOS' EditorIOS.app)"
  fi

  mac_entitlements="$signed_tmpdir/mac-entitlements.plist"
  if signed_entitlements_file "$MAC_APP_PATH" "$mac_entitlements"; then
    if entitlements_contains "$mac_entitlements" "$CLOUDKIT_CONTAINER_ID" &&
       entitlements_contains "$mac_entitlements" "CloudKit"; then
      pass "signed_mac_cloudkit_entitlements" "signed macOS app declares CloudKit container $CLOUDKIT_CONTAINER_ID"
    else
      fail "signed_mac_cloudkit_entitlements" "signed macOS app is missing CloudKit container $CLOUDKIT_CONTAINER_ID"
    fi

    if entitlements_contains "$mac_entitlements" "com.apple.security.app-sandbox" &&
       entitlements_contains "$mac_entitlements" "com.apple.security.network.client"; then
      pass "signed_mac_sandbox_network" "signed macOS app includes sandbox and network client"
    else
      fail "signed_mac_sandbox_network" "signed macOS app is missing sandbox or network client entitlement"
    fi

    if entitlements_contains "$mac_entitlements" "Development"; then
      pass "signed_mac_cloudkit_environment" "signed macOS app uses Development CloudKit environment"
    else
      fail "signed_mac_cloudkit_environment" "signed macOS app does not declare Development CloudKit environment"
    fi
  else
    fail "signed_mac_product" "signed macOS app entitlements not readable at $MAC_APP_PATH"
  fi

  ios_entitlements="$signed_tmpdir/ios-entitlements.plist"
  if signed_entitlements_file "$IOS_APP_PATH" "$ios_entitlements"; then
    if entitlements_contains "$ios_entitlements" "$CLOUDKIT_CONTAINER_ID" &&
       entitlements_contains "$ios_entitlements" "CloudKit"; then
      pass "signed_ios_cloudkit_entitlements" "signed iOS app declares CloudKit container $CLOUDKIT_CONTAINER_ID"
    else
      fail "signed_ios_cloudkit_entitlements" "signed iOS app is missing CloudKit container $CLOUDKIT_CONTAINER_ID"
    fi

    if entitlements_contains "$ios_entitlements" "aps-environment" &&
       entitlements_contains "$ios_entitlements" "development"; then
      pass "signed_ios_aps_environment" "signed iOS app declares development APNs environment"
    else
      fail "signed_ios_aps_environment" "signed iOS app is missing development APNs environment"
    fi

    if entitlements_contains "$ios_entitlements" "Development"; then
      pass "signed_ios_cloudkit_environment" "signed iOS app uses Development CloudKit environment"
    else
      fail "signed_ios_cloudkit_environment" "signed iOS app does not declare Development CloudKit environment"
    fi
  else
    fail "signed_ios_product" "signed iOS app entitlements not readable at $IOS_APP_PATH"
  fi
  rm -rf "$signed_tmpdir"
else
  skip "signed_products" "CHECK_SIGNED_PRODUCTS=$CHECK_SIGNED_PRODUCTS"
fi

for script in \
  scripts/macos_cloudkit_runtime_probe.sh \
  scripts/ios_headless_sync.sh \
  scripts/ios_sync_readback.sh \
  scripts/macos_headless_sync.sh \
  scripts/cloudkit_cross_device_sync.sh \
  scripts/wait_for_ios_unlock_and_run_cross_device_sync.sh \
  scripts/cloudkit_final_device_sync_gate.sh \
  scripts/ios_apns_registration_probe.sh
do
  if [[ -x "$script" ]]; then
    pass "script:$script" "script exists and is executable"
  else
    fail "script:$script" "script is missing or not executable"
  fi
done

if [[ "$CHECK_CLOUDKIT_SCHEMA" == "1" ]]; then
  if ! command -v xcrun >/dev/null 2>&1; then
    fail "cloudkit_schema:xcrun" "xcrun not found; cannot export CloudKit schema"
  else
    schema_tmpdir="$(mktemp -d /tmp/editor-cloudkit-schema-audit.XXXXXX)"
    for environment in $CLOUDKIT_SCHEMA_ENVIRONMENTS; do
      schema_file="$schema_tmpdir/$environment.ckdb"
      if xcrun cktool export-schema \
        --team-id "$CLOUDKIT_TEAM_ID" \
        --container-id "$CLOUDKIT_CONTAINER_ID" \
        --environment "$environment" \
        --output-file "$schema_file" >/dev/null 2>&1
      then
        pass "cloudkit_schema:$environment:export" "exported $CLOUDKIT_CONTAINER_ID $environment schema"
        for record_type in $CLOUDKIT_REQUIRED_RECORD_TYPES; do
          if schema_contains_record_type "$schema_file" "$record_type"; then
            pass "cloudkit_schema:$environment:$record_type" "$environment schema contains $record_type"
            assert_schema_fields_match "$environment" "$schema_file" "$record_type"
          else
            schema_fail "$environment" \
              "cloudkit_schema:$environment:$record_type" \
              "$environment schema is missing $record_type"
          fi
        done
      else
        schema_fail "$environment" \
          "cloudkit_schema:$environment:export" \
          "cktool export-schema failed for $CLOUDKIT_CONTAINER_ID $environment"
      fi
    done
    rm -rf "$schema_tmpdir"
  fi
else
  skip "cloudkit_schema" "CHECK_CLOUDKIT_SCHEMA=$CHECK_CLOUDKIT_SCHEMA"
fi

if [[ -f "$MAC_DATABASE_PATH" ]]; then
  assert_sync_generation_marker "mac_sync_generation" "$MAC_SYNC_GENERATION_MARKER_PATH" "macOS"

  mac_pending="$(sqlite_scalar "$MAC_DATABASE_PATH" 'SELECT COUNT(*) FROM sync_changes;')"
  if [[ "$mac_pending" == "0" ]]; then
    pass "mac_pending_changes" "macOS sync_changes=0"
  else
    fail "mac_pending_changes" "macOS sync_changes=$mac_pending"
  fi

  if [[ -n "$MAC_EXPECT_TEXT" ]]; then
    escaped_mac_text="${MAC_EXPECT_TEXT//\'/\'\'}"
    mac_text_count="$(sqlite_scalar "$MAC_DATABASE_PATH" "SELECT COUNT(*) FROM blocks WHERE is_deleted = 0 AND text_plain = '$escaped_mac_text';")"
    if [[ "$mac_text_count" != "0" ]]; then
      pass "mac_origin_seed" "macOS DB contains $MAC_EXPECT_TEXT"
    else
      fail "mac_origin_seed" "macOS DB does not contain $MAC_EXPECT_TEXT"
    fi
  else
    skip "mac_origin_seed" "MAC_EXPECT_TEXT not provided"
  fi

  if [[ -n "$IOS_EXPECT_TEXT" ]]; then
    escaped_ios_origin_text="${IOS_EXPECT_TEXT//\'/\'\'}"
    ios_origin_on_mac_count="$(sqlite_scalar "$MAC_DATABASE_PATH" "SELECT COUNT(*) FROM blocks WHERE is_deleted = 0 AND text_plain = '$escaped_ios_origin_text';")"
    if [[ "$ios_origin_on_mac_count" != "0" ]]; then
      pass "ios_origin_on_mac" "macOS DB contains iOS-origin text $IOS_EXPECT_TEXT"
    else
      fail "ios_origin_on_mac" "macOS DB does not contain iOS-origin text $IOS_EXPECT_TEXT"
    fi
  else
    skip "ios_origin_on_mac" "IOS_EXPECT_TEXT not provided"
  fi
else
  fail "mac_database" "macOS database not found at $MAC_DATABASE_PATH"
fi

ios_database="$IOS_READBACK_DIR/editor.sqlite"
if [[ -f "$ios_database" ]]; then
  pass "ios_readback_database" "iOS readback database exists at $ios_database"
  assert_sync_generation_marker "ios_sync_generation" "$IOS_SYNC_GENERATION_MARKER_PATH" "iOS readback"

  if [[ -n "$MAC_EXPECT_TEXT" ]]; then
    escaped_mac_origin_text="${MAC_EXPECT_TEXT//\'/\'\'}"
    mac_origin_on_ios_count="$(sqlite_scalar "$ios_database" "SELECT COUNT(*) FROM blocks WHERE is_deleted = 0 AND text_plain = '$escaped_mac_origin_text';")"
    if [[ "$mac_origin_on_ios_count" != "0" ]]; then
      pass "mac_origin_on_ios" "iOS readback contains macOS-origin text $MAC_EXPECT_TEXT"
    else
      fail "mac_origin_on_ios" "iOS readback does not contain macOS-origin text $MAC_EXPECT_TEXT"
    fi
  else
    skip "mac_origin_on_ios" "MAC_EXPECT_TEXT not provided"
  fi

  if [[ -n "$IOS_EXPECT_TEXT" ]]; then
    escaped_ios_text="${IOS_EXPECT_TEXT//\'/\'\'}"
    ios_text_count="$(sqlite_scalar "$ios_database" "SELECT COUNT(*) FROM blocks WHERE is_deleted = 0 AND text_plain = '$escaped_ios_text';")"
    if [[ "$ios_text_count" != "0" ]]; then
      pass "ios_origin_on_ios" "iOS readback contains iOS-origin text $IOS_EXPECT_TEXT"
    else
      fail "ios_origin_on_ios" "iOS readback does not contain iOS-origin text $IOS_EXPECT_TEXT"
    fi
  else
    skip "ios_origin_on_ios" "IOS_EXPECT_TEXT not provided"
  fi

  runtime_table_count="$(sqlite_scalar "$ios_database" "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'runtime_diagnostics';")"
  if [[ "$runtime_table_count" == "1" ]]; then
    pass "ios_runtime_diagnostics" "iOS sync readback has runtime_diagnostics"
  else
    fail "ios_runtime_diagnostics" "iOS sync readback database has no runtime_diagnostics table"
  fi
else
  fail "ios_readback_database" "iOS readback database not found at $ios_database"
fi

ios_diagnostic_database="$IOS_APNS_READBACK_DIR/editor.sqlite"
if [[ -f "$ios_diagnostic_database" ]]; then
  pass "ios_apns_readback_database" "iOS APNs readback database exists at $ios_diagnostic_database"
elif [[ -f "$ios_database" ]]; then
  ios_diagnostic_database="$ios_database"
  warn "ios_apns_readback_database" "iOS APNs readback not found at $IOS_APNS_READBACK_DIR/editor.sqlite; falling back to $ios_database"
else
  fail "ios_apns_readback_database" "iOS APNs readback database not found at $IOS_APNS_READBACK_DIR/editor.sqlite"
fi

if [[ -f "$ios_diagnostic_database" ]]; then
  diagnostic_runtime_table_count="$(sqlite_scalar "$ios_diagnostic_database" "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'runtime_diagnostics';")"
  if [[ "$diagnostic_runtime_table_count" == "1" ]]; then
    escaped_diag="${REQUIRED_IOS_DIAGNOSTIC//\'/\'\'}"
    diag_count="$(sqlite_scalar "$ios_diagnostic_database" "SELECT COUNT(*) FROM runtime_diagnostics WHERE event_name = '$escaped_diag';")"
    if [[ "$diag_count" != "0" ]]; then
      pass "ios_required_diagnostic" "iOS APNs readback contains $REQUIRED_IOS_DIAGNOSTIC"
    else
      latest_diagnostic="$(latest_apns_registration_diagnostic "$ios_diagnostic_database")"
      if [[ -n "$latest_diagnostic" ]]; then
        fail "ios_required_diagnostic" "iOS APNs readback does not contain $REQUIRED_IOS_DIAGNOSTIC; latest_diagnostic=$latest_diagnostic"
      else
        fail "ios_required_diagnostic" "iOS APNs readback does not contain $REQUIRED_IOS_DIAGNOSTIC; no remote_notification_registration_* diagnostics found"
      fi
    fi

    escaped_remote_sync_diag="${REQUIRED_IOS_REMOTE_NOTIFICATION_SYNC_DIAGNOSTIC//\'/\'\'}"
    remote_sync_diag_count="$(sqlite_scalar "$ios_diagnostic_database" "SELECT COUNT(*) FROM runtime_diagnostics WHERE event_name = '$escaped_remote_sync_diag';")"
    if [[ "$remote_sync_diag_count" != "0" ]]; then
      latest_remote_sync_diagnostic="$(latest_remote_notification_sync_diagnostic "$ios_diagnostic_database")"
      pass "ios_remote_notification_sync" "iOS APNs readback contains $REQUIRED_IOS_REMOTE_NOTIFICATION_SYNC_DIAGNOSTIC; latest_diagnostic=$latest_remote_sync_diagnostic"
    else
      fail "ios_remote_notification_sync" "iOS APNs readback does not contain $REQUIRED_IOS_REMOTE_NOTIFICATION_SYNC_DIAGNOSTIC"
    fi
  else
    fail "ios_apns_runtime_diagnostics" "iOS APNs readback database has no runtime_diagnostics table"
  fi
fi

if file_contains docs/superpowers/specs/2026-05-20-cloudkit-sync-readiness.md 'The full CloudKit sync objective is not complete until all of these are proven:'; then
  pass "readiness_completion_gate" "readiness document records the completion gates"
else
  fail "readiness_completion_gate" "readiness document is missing the completion gate section"
fi

exit "$status"
