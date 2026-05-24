# Page Version History Implementation Plan

## Goal

Add synchronized per-page version history with a "笔记信息" affordance in the editor chrome.

## Tasks

1. Add red tests for the SQLite schema and local capture policy.
   - `page_versions` stores page snapshots for changed pages only.
   - Repeated edits inside five minutes do not create another version.
   - Edits after five minutes create a new version.
2. Implement `PageVersionRepository`.
   - Do a cheap latest-version lookup before reading page blocks.
   - Capture pre-change snapshots only when content really changes.
   - Keep only versions from the last seven days.
3. Add red/green tests for sync.
   - Pending page versions upload as `PageVersionRecord`.
   - Remote `PageVersionRecord` upserts locally.
4. Wire version capture into page mutation paths.
   - Start with title, block text/type, block insert, move, delete, replace.
   - Preserve no-op behavior for unchanged edits.
5. Add editor access UI.
   - Right/top "笔记信息" button.
   - Show created time, modified time, last-seven-days versions, and diff to current.
6. Verify.
   - Focused repository/schema/sync tests.
   - Build/test `EditorTests` target enough to prove compilation across UI changes.
