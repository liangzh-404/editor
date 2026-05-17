#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DESTINATION="platform=macOS,arch=arm64"
LARGE_PAGE_TEST="EditorTests/PageRepositoryTests/testLargePageImportLoadAndSearchIndexRemainUsable"
SCROLL_METRICS_TEST="EditorTests/NativeTextBlockEditorTests/testEditorCanvasScrollMetricsTrackVisibleBlocksAndLargePageState"

echo "== Release large-page repository baseline =="
xcodebuild -quiet test \
  -project Editor.xcodeproj \
  -scheme EditorTests \
  -configuration Release \
  -destination "$DESTINATION" \
  -only-testing:"$LARGE_PAGE_TEST"

echo "== Release scroll metrics baseline =="
xcodebuild -quiet test \
  -project Editor.xcodeproj \
  -scheme EditorTests \
  -configuration Release \
  -destination "$DESTINATION" \
  -only-testing:"$SCROLL_METRICS_TEST"

echo "== Release macOS build baseline =="
xcodebuild -quiet build \
  -project Editor.xcodeproj \
  -scheme EditorMac \
  -configuration Release \
  -destination "$DESTINATION"

echo "Release performance baseline completed."
