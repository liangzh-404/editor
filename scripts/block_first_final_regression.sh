#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

UNIT_TEST_ARGS=(
    "-only-testing:EditorTests/SchemaMigratorTests"
    "-only-testing:EditorTests/PageRepositoryTests"
    "-only-testing:EditorTests/TagRepositoryTests"
    "-only-testing:EditorTests/DiaryRepositoryTests"
    "-only-testing:EditorTests/SearchRepositoryTests"
    "-only-testing:EditorTests/WorkspaceViewModelTests"
    "-only-testing:EditorTests/NativeTextBlockEditorTests"
)

UI_TESTS=(
    "testLaunchStartsInBlankDiaryEditorForFastTyping"
    "testAllDocumentsListShowsPagesSortedByUpdatedTime"
    "testCommandRightBracketPromotesSelectedDiaryTextToPage"
    "testPageFavoriteToggleUpdatesSidebarAndRowState"
    "testMarkdownImportToolbarRendersAndExportsMultilineQuoteAndCalloutBlocks"
    "testMarkdownExportToolbarCapturesCurrentPageMarkdown"
    "testCommandKOpensInlineLinkPanelForSelection"
    "testCommandKUpdatesExistingInlineLinkUnderSelection"
    "testCommandKRemovesExistingInlineLinkUnderSelection"
)

usage() {
    cat <<EOF
Usage:
  scripts/block_first_final_regression.sh [all|non-ui|units|ui|builds|doctor|authorize|diff-check|help]

Actions:
  all         Run focused unit suite, app builds, diff check, then focused macOS UI suite.
  non-ui      Run focused unit suite, app builds, and diff check without macOS UI tests.
  units       Run the focused block-first unit suite.
  ui          Run macOS UI readiness doctor, build-for-testing, then focused UI rerun.
  builds      Build EditorMac for macOS arm64 and EditorIOS for iOS Simulator.
  doctor      Print macOS UI test readiness diagnostics.
  authorize   Run the local macOS UI Automation authorization prompt, then doctor.
  diff-check  Run git diff --check.
  help        Show this message.
EOF
}

run_units() {
    echo "== focused block-first unit suite =="
    xcodebuild -quiet test \
        -project Editor.xcodeproj \
        -scheme EditorTests \
        -destination 'platform=macOS,arch=arm64' \
        "${UNIT_TEST_ARGS[@]}"
}

run_ui() {
    echo "== macOS UI readiness =="
    scripts/mac_ui_test.sh doctor

    echo "== macOS UI build-for-testing =="
    scripts/mac_ui_test.sh build

    echo "== focused macOS UI suite =="
    scripts/mac_ui_test.sh rerun "${UI_TESTS[@]}"
}

run_builds() {
    echo "== EditorMac build =="
    xcodebuild -quiet build \
        -project Editor.xcodeproj \
        -scheme EditorMac \
        -destination 'platform=macOS,arch=arm64'

    echo "== EditorIOS build =="
    xcodebuild -quiet build \
        -project Editor.xcodeproj \
        -scheme EditorIOS \
        -destination 'generic/platform=iOS Simulator'
}

run_diff_check() {
    echo "== git diff --check =="
    git diff --check
}

run_non_ui() {
    run_units
    run_builds
    run_diff_check
}

ACTION="${1:-all}"

case "$ACTION" in
    all)
        run_non_ui
        run_ui
        ;;
    non-ui)
        run_non_ui
        ;;
    units)
        run_units
        ;;
    ui)
        run_ui
        ;;
    builds)
        run_builds
        ;;
    doctor)
        scripts/mac_ui_test.sh doctor
        ;;
    authorize)
        scripts/mac_ui_test.sh authorize
        ;;
    diff-check)
        run_diff_check
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
