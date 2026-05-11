# Editor Architecture Design

Date: 2026-05-12
Status: Approved for implementation planning

## Context

This repository starts as an empty Git repository for a new native editor app that must support macOS and iOS. The product direction is a clean white, Craft-like block editor with local-first behavior, attachment support, Markdown support, CloudKit sync, Apple-platform native data protection, desktop three-column navigation, and mobile-first performance.

The agreed architecture favors a long-term native foundation while keeping implementation incremental. The full product surface is designed here, but the build plan must ship it through milestones so each layer is verifiable before the next one depends on it.

## Decisions

- Data model: block database is the source of truth. Markdown is an input, import, and export format.
- Security: use Apple platform protection first: App Sandbox, File Protection, Keychain for secrets, and CloudKit Private Database. End-to-end content encryption is out of scope for the first implementation plan.
- Editing scope: include high-level block capabilities in the architecture: tables, toggles, callouts, nested pages, drag reorder, and backlinks.
- Local storage: SQLite with custom repository and sync layers.
- Layout: macOS uses a persistent three-column layout similar to Obsidian Notebook Navigator. iOS and iPadOS collapse the same information architecture into mobile navigation.
- Editor core: native TextKit 2 wrapped in SwiftUI block shells.
- Sync conflict model: block-level revisions and conflict history. Do not use whole-document conflict copies as the primary model.

## Goals

- Build a native macOS and iOS editor that opens and edits local content without network dependency.
- Keep the visual style white, quiet, and work-focused, with contextual block tools instead of heavy chrome.
- Make the editor fast on mobile and resilient on large pages.
- Store documents as structured blocks so high-level editing, attachments, backlinks, and block-level sync are first-class.
- Keep CloudKit as a sync layer, not the primary database.
- Use platform-native security primitives for the first version.
- Make focus, cursor, scroll, keyboard, and input latency observable from the beginning.

## Non-Goals For The First Implementation Plan

- Real-time multiplayer collaboration.
- End-to-end encrypted content sync.
- Plugin architecture.
- Web publishing.
- Windows or Android support.
- Markdown-file-first storage compatible with arbitrary Obsidian folders.

## Architecture Overview

The system is split into six long-term modules:

1. UI Shell
   - macOS: three persistent columns for spaces/library, page list, and editor.
   - iOS/iPadOS: the same hierarchy collapses into stack navigation, drawers, or sheets.
   - The editor is the primary surface; tools appear only when relevant.

2. Editor Core
   - TextKit 2 handles native text editing inside text-capable blocks.
   - SwiftUI owns the block shell, layout, toolbars, hover state, drag handles, and non-text block rendering.
   - A centralized editor session coordinates focus, selection, composition, undo, dirty state, and markdown transforms.

3. Local Store
   - SQLite is the only local write source of truth.
   - Repositories expose snapshots and transactions to the UI.
   - Full-text search, attachments, backlinks, revisions, and sync metadata live in local tables.

4. Sync Engine
   - CloudKit Private Database stores workspace, page, block, and attachment records.
   - Local edits enqueue sync changes and never wait for network completion.
   - Remote changes merge into SQLite transactions, then the UI refreshes from local snapshots.

5. Platform Security
   - App Sandbox constrains file access.
   - File Protection applies to local database and attachment storage where supported.
   - Keychain stores required secrets and install/account metadata only.
   - CloudKit Private Database scopes synced data to the user's iCloud account.

6. Verification And Observability
   - Repository, migration, Markdown, sync, and UI tests cover the main flows.
   - OSLog and signposts capture focus transitions, text input latency, markdown transforms, render cost, scroll jumps, and sync transactions.

## UI Shell

The desktop layout is a three-column navigator:

- Column 1: spaces, workspace sections, favorites, archive, and high-level navigation.
- Column 2: page list, notebooks, search results, backlinks, and filtered views.
- Column 3: editor canvas for the current page.

The mobile layout uses the same hierarchy but collapses it:

- Level 1: spaces and notebook navigation.
- Level 2: page list and search.
- Level 3: editor.
- Contextual panels expose block tools, page metadata, outline, backlinks, and attachment details.

The UI should avoid nested card-heavy composition. Repeated items can use compact rows or low-radius cards only when they represent discrete content. The editor canvas should feel white, calm, and direct, with block handles and insertion controls appearing on hover, focus, or explicit command.

## Editor Core

The block tree is the structural source of truth for a page. Each block has:

- `id`
- `page_id`
- `parent_block_id`
- `order_key`
- `type`
- `payload_json`
- `text_plain`
- `revision`
- `created_at`
- `updated_at`

Text-capable blocks include paragraph, heading, list item, task item, quote, and code block. These use TextKit 2 via platform wrappers around `NSTextView` and `UITextView`, not SwiftUI `TextEditor`.

SwiftUI owns:

- Block selection and hover state.
- Drag handles and insertion affordances.
- Attachment previews.
- Toggle expansion.
- Callout styling.
- Table containers.
- Page reference blocks.
- Layout virtualization boundaries.

`EditorSession` owns cross-block editing state:

- `focusedBlockID`
- selection and caret metadata
- input composition state
- undo transaction scope
- pending Markdown transform
- drag reorder state
- dirty state and local transaction scope

This state must not be scattered across per-block local SwiftUI state because focus, keyboard, cursor, and scroll bugs need a single observable path.

Markdown is not the persisted truth. Markdown shortcuts such as `# `, `- `, `> `, task markers, code fences, and dividers transform into block type or style changes. Markdown import parses content into a block tree. Markdown export renders the block tree into Markdown.

Tables are structured blocks, not Markdown strings. Rows, columns, and cells have dedicated payload structure. Markdown table syntax is only an import/export representation.

Nested pages are page references. A page reference block points to another page instead of embedding a full page tree inside the current page.

## Local Store

SQLite is the local source of truth. The UI never writes SQL directly. All writes flow through repositories, and all visible state comes from local snapshots.

Core tables:

- `workspaces`: local and iCloud workspace metadata.
- `pages`: page title, hierarchy, order, archive state, favorite state, and sync metadata.
- `blocks`: block tree, payload, plain text, revision, deletion flag, and sync state.
- `attachments`: local file path, original filename, UTType, file size, hash, thumbnail path, and asset sync state.
- `links`: page and block references used for backlinks.
- `sync_changes`: local dirty queue for uploads.
- `sync_records`: CloudKit record name and change tag mapping.
- `conflict_versions`: block-level remote or historical versions retained during conflict resolution.

Repository boundaries:

- `PageRepository`: page hierarchy, page metadata, recent pages, archive/favorite state.
- `BlockRepository`: block loading, insertion, deletion, movement, revision updates, and editor snapshots.
- `AttachmentRepository`: file import, manifest updates, thumbnail references, and garbage-collection candidates.
- `SearchRepository`: FTS queries and snippet generation.
- `SyncRepository`: dirty queue reads, change state updates, conflict persistence, and CloudKit mapping.

SQLite opening and migration must be explicit. If migration fails, the app must preserve the old database file and surface a recoverable error. It must not silently recreate an empty database over user data.

## CloudKit Sync

CloudKit is a synchronization layer over SQLite, not a replacement database. The app remains editable offline and syncs later.

Record types:

- `WorkspaceRecord`
- `PageRecord`
- `BlockRecord`
- `AttachmentRecord`

`BlockRecord` contains structure fields, payload data, plain text as needed for local reconstruction, revision, deletion marker, and parent/order metadata. `AttachmentRecord` stores metadata plus a `CKAsset` for the file content. Attachment metadata remains in SQLite even when the binary asset is pending upload.

The sync flow is:

1. User edits blocks or attachments.
2. Repository writes a SQLite transaction and appends `sync_changes`.
3. Sync engine reads dirty changes in the background.
4. CloudKit upload succeeds or fails.
5. On success, `sync_records` stores record name and change tag.
6. Remote changes are fetched and merged into SQLite.
7. UI refreshes from repository snapshots.

Conflict handling:

- Different blocks changed concurrently can merge automatically into the same page.
- The same block changed concurrently creates a block-level conflict.
- Local active edits are not overwritten by remote changes.
- The default resolution keeps local content and stores the remote version in `conflict_versions`.
- The UI can later show conflict history and allow recovery or manual merge.

## Attachments

The first architecture supports image, video, and arbitrary file attachment blocks.

Import rules:

- Imported files are copied into the app sandbox under an attachment-managed directory such as `Attachments/<workspace>/<hash-or-uuid>/`.
- The app must not depend on the original external path after import.
- Security-scoped bookmarks are used for explicit import and export flows when needed.

Stored metadata:

- original filename
- UTType
- byte size
- content hash
- local file path
- thumbnail path
- preview metadata
- referenced block/page identifiers
- CloudKit asset state

Images and videos generate local thumbnails asynchronously. Large previews and video metadata reads must not block the editor main thread. Deleting an attachment block removes the reference first; unreferenced files are cleaned by a later safe garbage-collection pass.

## Markdown

Markdown support has three roles:

1. Shortcut input while editing.
2. Import into block tree.
3. Export from block tree.

Supported shortcut transforms:

- headings
- unordered and ordered lists
- task lists
- quotes
- code blocks
- dividers

Markdown import parses known structures into typed blocks. Unknown or unsupported syntax must be preserved as raw/code content so import avoids data loss.

Markdown export renders:

- text blocks as standard Markdown
- tables as Markdown tables
- attachments as relative links with copied assets
- page references as links
- callouts and toggles using stable fallback syntax such as blockquote or HTML comment metadata

## Search And Backlinks

SQLite FTS indexes:

- page titles
- `blocks.text_plain`
- attachment filenames

Backlinks are maintained incrementally through repository transactions. The app should not repeatedly scan all content to answer backlink queries. The `links` table tracks Markdown links, page reference blocks, and block reference blocks.

First implementation search is local. CloudKit syncs source data but is not used as a remote search service.

## Platform Security

The first version uses Apple native protection rather than custom end-to-end encryption.

Security boundaries:

- App Sandbox limits file access.
- File Protection is applied to database and attachment storage where supported.
- Keychain stores account/install secrets and any required feature keys.
- CloudKit Private Database stores synced data under the user's iCloud account.

The architecture keeps a future extension point for content encryption by isolating serialization at repository and sync boundaries, but E2EE is not part of the first implementation plan.

## Performance Strategy

The editor must be built around local responsiveness:

- App launch opens the last local workspace without waiting for CloudKit.
- Large pages load visible blocks and a nearby buffer, not the entire rendered document.
- Text input in one block must not trigger a full-page block tree recompute.
- Text layout caches are invalidated at block granularity.
- Attachment thumbnail generation runs off the main thread.
- Sync runs in the background and does not block editing.
- Repository transactions emit timing logs so slow paths can be identified.

Initial performance targets:

- Opening a 1,000-block page renders only the visible window and buffer.
- Plain text typing stays local and avoids full page reloads.
- Attachment import can show pending/processing state while thumbnails are generated.
- Sync retries and conflicts are visible but do not interrupt editing.

## Observability

The app should include named OSLog categories from the start:

- `editor.focus`
- `editor.selection`
- `editor.input`
- `editor.markdown`
- `editor.render`
- `editor.scroll`
- `store.transaction`
- `sync.cloudkit`
- `attachment.preview`

Focus, cursor, shortcut input, keyboard, scroll, and performance bugs must be made observable before production fixes are attempted. Logs should capture block IDs, page IDs, transition reasons, durations, and result status without logging sensitive document content.

## Testing Strategy

Test layers:

- SQLite migration tests for every schema version.
- Repository tests for page creation, block insertion, movement, deletion, attachment references, backlink updates, and dirty queue behavior.
- Markdown tests for shortcuts, import, export, and unknown syntax preservation.
- Sync tests using a CloudKit adapter protocol so upload queues, change tags, retries, conflicts, and offline behavior are testable without live CloudKit.
- UI tests for macOS three-column navigation, iOS collapsed navigation, creating pages, editing text, inserting attachments, and focus movement.
- Performance checks for large pages, text input, scroll, attachment thumbnail generation, and sync background work.

For UI, focus, cursor, scroll, shortcut-input, keyboard, or performance bugs, the required workflow is:

1. Reproduce or make the issue observable.
2. Add temporary high-signal instrumentation if reproduction is ambiguous.
3. Make the smallest targeted fix.
4. Verify the exact original scenario.
5. Run a nearby regression check.
6. Report evidence instead of confidence.

## Milestones

M1: Foundation

- Create the shared macOS/iOS SwiftUI project.
- Build the three-column desktop shell and collapsed mobile navigation.
- Add SQLite schema, migrations, repositories, and local workspace creation.
- Display a local page with a basic block list.

M2: Native Text Editing

- Add TextKit 2 wrappers for text blocks.
- Add editor session state for focus, selection, composition, undo scope, and dirty state.
- Add Markdown shortcut transforms for core text blocks.
- Add interaction instrumentation for focus, input, render, and scroll.

M3: Attachments

- Add image, video, and file attachment blocks.
- Copy imports into sandbox-managed storage.
- Store attachment manifests in SQLite.
- Generate thumbnails asynchronously.
- Verify restart persistence.

M4: Advanced Blocks

- Add tables, toggles, callouts, nested page references, drag reorder, and backlinks maintenance.
- Keep block order stable after drag operations.
- Keep table data structured rather than Markdown-string based.

M5: CloudKit Sync

- Add CloudKit Private Database adapter.
- Map local workspaces, pages, blocks, and attachments to records.
- Implement dirty queue upload, remote fetch, change tag persistence, offline retry, and block-level conflict history.
- Verify same-block conflict does not lose local edits.

M6: Search And Performance

- Add FTS search over titles, block plain text, and attachment filenames.
- Add backlink views.
- Run large-page performance checks.
- Tune rendering, transaction, and sync hotspots based on logs.

## Acceptance Criteria

- M1 builds on macOS and iOS and can create/open a local workspace, page, and visible block list.
- M2 can enter text, transform Markdown shortcuts, move focus between blocks, and perform basic undo without losing input.
- M3 can insert image, video, and file attachments, then relaunch with attachment blocks still visible.
- M4 can create and edit advanced blocks, and drag reorder persists correctly.
- M5 can edit offline, sync after connectivity returns, and preserve local content when the same block conflicts remotely.
- M6 can search content and attachment filenames, show backlinks, and complete a large-page performance baseline.

## Implementation Planning Notes

The implementation plan should not attempt all milestones in one patch. Each milestone should have its own focused tests and verification commands. The first build should prioritize project structure, schema, repository boundaries, and a visible local editor shell before adding CloudKit or advanced block UX.

