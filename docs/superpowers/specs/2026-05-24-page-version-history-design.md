# Page Version History Design

Date: 2026-05-24
Status: Design approved for planning

## Goal

Add cross-device note information and version history. The editor shows note created time, modified time, and the last 7 days of meaningful page changes from a new "笔记信息" entry in the upper-right page chrome. Version history is an extreme recovery path and must not slow the normal editing flow.

## User Experience

- The page toolbar adds an `info.circle` action labeled "笔记信息".
- The note information panel shows the selected page's created time and modified time.
- The same panel shows "版本历史" entries for snapshots captured within the last 7 days.
- Empty history is valid. If a page has not changed during the retention window, the panel shows no history rows.
- Selecting a history entry computes and displays a diff between that historical snapshot and the current page.
- First implementation is view-only: users can inspect history and diff, but cannot restore from history yet.
- Encrypted pages keep history protected. If a page is locked, history and diff are hidden until the page is unlocked.

## Data Model

Create a local `page_versions` table:

- `id`: stable version id.
- `page_id`: owning page id.
- `workspace_id`: owning workspace id for sync and filtering.
- `created_at`: when this historical snapshot was captured.
- `base_page_updated_at`: page `updated_at` before the triggering change.
- `page_title`: stored title from the captured version.
- `snapshot_json`: serialized page snapshot containing ordered blocks and their content payloads.
- `content_hash`: hash of title plus block snapshot, used to avoid duplicate versions.
- `sync_state`: same local/synced shape used by synced records where needed.

The serialized snapshot stores enough to diff against the current page:

- Page title.
- Ordered active blocks.
- For each block: id, parent id, order key, type, text, payload JSON, task/toggle/code/table/reference/attachment metadata already encoded in payload.

History stores snapshots, not operation logs. This is larger than an edit log, but it is much simpler and safer across offline devices, remote merge order, and conflict resolution.

## Capture Policy

When a real page-content change is about to be persisted, the repository attempts to capture the pre-change page state.

A new snapshot is created only when all are true:

- The page exists and content can be read.
- The page has changed since the last stored snapshot according to `content_hash`.
- The most recent retained version for that page is older than 5 minutes.
- The operation is not a no-op write.

If a change happens within 5 minutes of the last captured version, no new version is written. The next real change after the window can create the next version. This produces at most one version per page per 5-minute editing round.

Creation of a new page does not create a version row. The first version row appears only after the page has a meaningful change after creation.

## Retention

Only versions from the most recent 7 days are kept.

Retention runs opportunistically after capture and during sync maintenance. Local pruning enqueues remote deletes so every device converges on the same history window. If a device is offline, old local rows can remain until the next successful maintenance pass.

## Sync

Add a new CloudKit record type `PageVersionRecord` and a new sync entity type `pageVersion`.

Record fields:

- `entityID`
- `entityType`
- `syncGeneration`
- `pageID`
- `workspaceID`
- `createdAt`
- `basePageUpdatedAt`
- `pageTitle`
- `snapshotJSON`
- `contentHash`

Upload priority places `pageVersion` after page/block content records. History must never block the primary note state from syncing. Fetch applies `pageVersion` records independently after pages exist; records for missing pages are skipped and can be fetched again through normal remote-change flow.

Version IDs are unique, so concurrent devices can create independent versions without merge conflict. If two devices capture the same content hash in the same window, the local query can collapse duplicate display rows by `content_hash`, preserving the earliest `created_at`.

## Performance Guardrails

Version history must not affect the primary editing path in noticeable ways.

- No diff is computed during editing. Diff is computed lazily only when the user opens a history entry.
- No full-page snapshot is serialized for no-op writes.
- Capture first checks the latest version metadata using an indexed query before building a snapshot.
- Capture is bounded to one attempt per page per 5-minute window.
- Large-page snapshot serialization is allowed to skip if it exceeds a conservative block-count or payload-size threshold; the skipped event is logged as a runtime diagnostic instead of blocking input.
- The UI loads history rows as lightweight metadata first. Snapshot JSON is read only when the user selects a specific version.
- Version-history sync failures use the existing retry path and must not block page, block, attachment, or tag uploads.

## Components

- `PageVersionRepository`: owns schema access, capture gating, retention pruning, history metadata queries, snapshot loading, and diff input preparation.
- `PageRepository`: calls version capture before real page title and block/page-content mutations.
- `SyncRepository`: includes `pageVersion` in unsynced create detection, sync records, deletion cleanup, and legacy backlog repair if needed.
- `SyncEngine` and `CloudKitPrivateDatabaseAdapter`: upload, fetch, apply, and delete `PageVersionRecord`.
- `SyncMergeEngine`: applies remote page-version upserts and deletes without changing live page content.
- `WorkspaceViewModel`: exposes selected page info, loads version metadata on demand, and asks for a specific diff on selection.
- `EditorShellView`: adds the "笔记信息" entry, the info panel, version list, and diff detail view.

## Diff Model

The first implementation uses a text-oriented diff:

- Convert the current page and historical snapshot into a stable markdown-like text representation.
- Include title as the first line.
- Include block text in page order.
- Include non-text blocks as compact markers, such as attachment filename or block type.
- Compute line-level diff for display.

This keeps the first version useful while avoiding a complex block-structural diff. A richer block-aware diff can be added without changing the stored snapshot.

## Error Handling

- If a snapshot cannot be captured, the primary edit still proceeds.
- Capture failures log through `EditorLog.store` and may record a runtime diagnostic for repeated or large-page skips.
- If history loading fails, the info panel shows created and modified times plus an empty or error history state.
- If a remote page-version record references a missing page, sync logs and skips it instead of failing the entire fetch.
- If a page is encrypted and locked, history access is blocked until unlock.

## Testing

Repository tests:

- Captures the pre-change version before the first real edit.
- Does not capture for no-op writes.
- Coalesces changes within 5 minutes.
- Captures a new version after 5 minutes.
- Prunes versions older than 7 days and enqueues delete sync changes.
- Skips large pages without failing the edit path.

Sync tests:

- Uploads `pageVersion` records with deterministic record names.
- Fetches remote `PageVersionRecord` into `page_versions`.
- Deletes pruned versions remotely through existing delete flow.
- Prioritizes live page/block uploads before history uploads.
- Skips remote page-version records when the page is missing without aborting fetch.

View model and UI tests:

- Shows created and modified times for the selected page.
- Shows empty history for pages with no retained changes.
- Loads history lazily when the info panel opens.
- Computes diff only after selecting a history row.
- Keeps encrypted-page history hidden while locked.

## Out Of Scope

- Restoring a page from a historical version.
- Branching history, named versions, labels, or favorites.
- Operation-level edit logs.
- Full block-structural diff with move detection.
- Infinite retention beyond 7 days.
