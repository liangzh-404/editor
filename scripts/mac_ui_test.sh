#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="${EDITOR_UI_TEST_PROJECT:-Editor.xcodeproj}"
SCHEME="${EDITOR_UI_TEST_SCHEME:-EditorMacUITests}"
TEST_TARGET="${EDITOR_UI_TEST_TARGET:-EditorMacUITests}"
DEFAULT_TEST_CLASS="${EDITOR_UI_TEST_CLASS:-EditorMacEditingUITests}"
DESTINATION="${EDITOR_UI_TEST_DESTINATION:-platform=macOS,arch=arm64}"
DERIVED_DATA_PATH="${EDITOR_UI_TEST_DERIVED_DATA:-${TMPDIR:-/tmp}/editor-mac-ui-tests-derived-data}"

usage() {
    cat <<EOF
Usage:
  scripts/mac_ui_test.sh [run] [test-name ...] [-- xcodebuild-args ...]
  scripts/mac_ui_test.sh rerun [test-name ...] [-- xcodebuild-args ...]
  scripts/mac_ui_test.sh build
  scripts/mac_ui_test.sh doctor
  scripts/mac_ui_test.sh test [test-name ...] [-- xcodebuild-args ...]
  scripts/mac_ui_test.sh clean

Examples:
  scripts/mac_ui_test.sh testWelcomeBlockAcceptsTypedText
  scripts/mac_ui_test.sh build
  scripts/mac_ui_test.sh rerun testWelcomeBlockAcceptsTypedText
  scripts/mac_ui_test.sh run EditorMacEditingUITests/testWelcomeBlockAcceptsTypedText

Environment:
  EDITOR_UI_TEST_DERIVED_DATA   Override the cached DerivedData path.
  EDITOR_UI_TEST_DESTINATION    Override the xcodebuild destination.
  EDITOR_UI_TEST_VERBOSE=1      Show full xcodebuild output.
  EDITOR_UI_TEST_SKIP_AUTOMATION_PREFLIGHT=1
                                  Skip the macOS UI Automation authorization preflight.
EOF
}

ACTION="run"
if [[ $# -gt 0 ]]; then
    case "$1" in
        run|rerun|build|doctor|test|clean|help|-h|--help)
            ACTION="$1"
            shift
            ;;
    esac
fi

if [[ "$ACTION" == "help" || "$ACTION" == "-h" || "$ACTION" == "--help" ]]; then
    usage
    exit 0
fi

TEST_SELECTORS=()
XCODEBUILD_ARGS=()
COLLECT_XCODEBUILD_ARGS=0
for argument in "$@"; do
    if [[ "$argument" == "--" ]]; then
        COLLECT_XCODEBUILD_ARGS=1
        continue
    fi

    if [[ "$COLLECT_XCODEBUILD_ARGS" -eq 1 ]]; then
        XCODEBUILD_ARGS+=("$argument")
    else
        TEST_SELECTORS+=("$argument")
    fi
done

xcodebuild_base_args=()
if [[ "${EDITOR_UI_TEST_VERBOSE:-0}" != "1" ]]; then
    xcodebuild_base_args+=("-quiet")
fi
xcodebuild_base_args+=(
    "-project" "$PROJECT"
    "-scheme" "$SCHEME"
    "-destination" "$DESTINATION"
    "-derivedDataPath" "$DERIVED_DATA_PATH"
)

normalize_test_selector() {
    local selector="$1"
    if [[ "$selector" == "$TEST_TARGET/"* ]]; then
        printf '%s\n' "$selector"
    elif [[ "$selector" == */* ]]; then
        printf '%s\n' "$TEST_TARGET/$selector"
    elif [[ "$selector" == test* ]]; then
        printf '%s\n' "$TEST_TARGET/$DEFAULT_TEST_CLASS/$selector"
    else
        printf '%s\n' "$TEST_TARGET/$selector"
    fi
}

only_testing_args=()
if ((${#TEST_SELECTORS[@]})); then
    for selector in "${TEST_SELECTORS[@]}"; do
        only_testing_args+=("-only-testing:$(normalize_test_selector "$selector")")
    done
fi

xctestrun_path() {
    find "$DERIVED_DATA_PATH/Build/Products" \
        -maxdepth 1 \
        -name "${SCHEME}_*.xctestrun" \
        -print 2>/dev/null | head -n 1 || true
}

build_inputs_newer_than() {
    local reference_file="$1"
    local changed_input
    changed_input="$(
        find Sources Tests Editor.xcodeproj project.yml \
            -type f \
            \( -name "*.swift" -o -name "*.xcscheme" -o -name "project.pbxproj" -o -name "project.yml" \) \
            -newer "$reference_file" \
            -print 2>/dev/null | head -n 1 || true
    )"
    [[ -n "$changed_input" ]]
}

run_build_for_testing() {
    mkdir -p "$DERIVED_DATA_PATH"
    echo "== build-for-testing: $SCHEME ($DESTINATION) =="
    run_xcodebuild build-for-testing
}

ensure_ui_automation_authorized() {
    if [[ "${EDITOR_UI_TEST_SKIP_AUTOMATION_PREFLIGHT:-0}" == "1" ]]; then
        return
    fi

    local devtools_status
    if ! devtools_status="$(/usr/sbin/DevToolsSecurity -status 2>&1)"; then
        echo "Unable to read macOS Developer Tools security status:" >&2
        echo "$devtools_status" >&2
        echo "Set EDITOR_UI_TEST_SKIP_AUTOMATION_PREFLIGHT=1 to bypass this preflight." >&2
        exit 65
    fi

    if [[ "$devtools_status" == *"currently enabled"* ]]; then
        return
    fi

    cat >&2 <<EOF
macOS UI Automation is not authorized for this user.

$devtools_status

UI tests will time out while enabling automation mode until this Mac is
authorized. Run the following command locally and approve the system prompt:

  /usr/sbin/DevToolsSecurity -enable

Then rerun this script. To intentionally let xcodebuild attempt the prompt,
set EDITOR_UI_TEST_SKIP_AUTOMATION_PREFLIGHT=1.
EOF
    exit 65
}

run_doctor() {
    local status=0

    echo "== macOS UI test diagnostics =="
    echo "Project: $PROJECT"
    echo "Scheme: $SCHEME"
    echo "Destination: $DESTINATION"
    echo "DerivedData: $DERIVED_DATA_PATH"

    local cached_xctestrun
    cached_xctestrun="$(xctestrun_path)"
    if [[ -n "$cached_xctestrun" ]]; then
        echo "Cached xctestrun: $cached_xctestrun"
    else
        echo "Cached xctestrun: missing"
    fi

    local devtools_status
    if devtools_status="$(/usr/sbin/DevToolsSecurity -status 2>&1)"; then
        echo "Developer Tools security: $devtools_status"
        if [[ "$devtools_status" != *"currently enabled"* ]]; then
            status=65
        fi
    else
        echo "Developer Tools security: unavailable"
        echo "$devtools_status"
        status=65
    fi

    local system_events_enabled
    if system_events_enabled="$(osascript -e 'tell application "System Events" to get UI elements enabled' 2>&1)"; then
        echo "System Events UI elements enabled: $system_events_enabled"
        if [[ "$system_events_enabled" != "true" ]]; then
            status=65
        fi
    else
        echo "System Events UI elements enabled: unavailable"
        echo "$system_events_enabled"
        status=65
    fi

    if [[ -e /var/db/com.apple.dt.automationmode/automation-enabled ]]; then
        echo "Automation mode state file: present"
    else
        echo "Automation mode state file: missing"
    fi

    local testmanager_pids
    testmanager_pids="$(pgrep -x testmanagerd 2>/dev/null || true)"
    testmanager_pids="$(printf '%s\n' "$testmanager_pids" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    if [[ -n "$testmanager_pids" ]]; then
        echo "testmanagerd pid(s): $testmanager_pids"
    else
        echo "testmanagerd pid(s): none"
    fi

    if [[ "$status" -ne 0 ]]; then
        cat <<EOF

macOS UI Automation is not ready. Run the following command locally and approve
the system prompt, then rerun this doctor command:

  /usr/sbin/DevToolsSecurity -enable
EOF
    else
        echo
        echo "macOS UI Automation preflight is ready."
    fi

    return "$status"
}

ensure_build_for_testing() {
    local cached_xctestrun
    cached_xctestrun="$(xctestrun_path)"

    if [[ -z "$cached_xctestrun" ]]; then
        echo "== no cached xctestrun; building once =="
        run_build_for_testing
        return
    fi

    if build_inputs_newer_than "$cached_xctestrun"; then
        echo "== cached xctestrun is stale; rebuilding =="
        run_build_for_testing
        return
    fi

    echo "== reusing cached xctestrun: $cached_xctestrun =="
}

run_test_without_building() {
    ensure_ui_automation_authorized

    local args=("test-without-building")
    if ((${#only_testing_args[@]})); then
        args+=("${only_testing_args[@]}")
    fi
    run_xcodebuild "${args[@]}"
}

run_standard_test() {
    ensure_ui_automation_authorized

    local args=("test")
    if ((${#only_testing_args[@]})); then
        args+=("${only_testing_args[@]}")
    fi
    run_xcodebuild "${args[@]}"
}

run_xcodebuild() {
    local args=("${xcodebuild_base_args[@]}" "$@")
    if ((${#XCODEBUILD_ARGS[@]})); then
        args+=("${XCODEBUILD_ARGS[@]}")
    fi
    xcodebuild "${args[@]}"
}

case "$ACTION" in
    build)
        run_build_for_testing
        ;;
    doctor)
        run_doctor
        ;;
    run)
        ensure_build_for_testing
        run_test_without_building
        ;;
    rerun)
        run_test_without_building
        ;;
    test)
        run_standard_test
        ;;
    clean)
        rm -rf "$DERIVED_DATA_PATH"
        echo "Removed $DERIVED_DATA_PATH"
        ;;
    *)
        usage
        exit 2
        ;;
esac
