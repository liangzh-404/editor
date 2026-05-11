# Full Feature Implementation Audit

Date: 2026-05-12
Status: Incomplete

## Objective

Implement the approved editor architecture so the app supports the full requested feature set:

- macOS and iOS native editor
- clean white Craft-like block editing
- local-first storage
- image, video, and arbitrary file attachments
- Markdown shortcuts, import, and export
- CloudKit Private Database sync
- Apple-native protection: sandbox, file protection, Keychain metadata, private iCloud scope
- desktop three-column navigation and mobile collapsed navigation
- performance-first behavior and observability
- advanced blocks, backlinks, search, conflict handling, and large-page verification from the architecture plan

## Evidence Checklist

| Requirement | Current Evidence | Status |
| --- | --- | --- |
| macOS and iOS project | `project.yml`, `EditorMac`, `EditorIOS`, `EditorTests`; both app targets build | Implemented foundation |
| clean white shell | `EditorShellView.swift` renders white three-column/collapsed shell | Partial |
| block model | `blocks` table and `BlockSnapshot`; paragraph block persisted | Partial |
| editable text | paragraph text can be edited and persisted through `PageRepository.updateBlockText`; `NativeTextBlockEditor` wraps `NSTextView`/`UITextView`; `EditorSession` tracks focus/drafts/dirty state; `WorkspaceViewModel.appendParagraphBlockToCurrentPage` and the canvas `+` button add an editable empty paragraph block and request native focus for it | Partial; still needs undo grouping, multi-block focus movement, composition testing, and UI automation |
| local-first | SQLite opens from Application Support and app can launch without network | Partial |
| attachment blocks | `AttachmentRepositoryTests`, `AttachmentRepository`, `WorkspaceViewModel.importAttachment`, and `EditorShellView` file importer cover local copy, metadata, attachment block insertion, reload, and basic row rendering | Partial; thumbnails, async preview work, deletion GC, and live CloudKit asset sync remain |
| Markdown | `MarkdownTransformerTests`, `MarkdownTransformer`, `PageRepositoryTests`, `WorkspaceViewModelTests`, `WorkspaceViewModel`, and `EditorShellView` cover core shortcut transforms, basic block export, parser import into block drafts, page-level Markdown import persistence, view-model import/export APIs, and macOS/iOS file import/export buttons backed by `FileDocument` | Partial; tables, callout/toggle fallback syntax, richer import parsing, and TextKit-integrated shortcut handling remain |
| CloudKit sync | `SyncRepositoryTests`, `SyncEngineTests`, `SyncRepository`, `SyncEngine`, and `CloudKitSyncAdapter` cover dirty queue upload through an adapter, local `sync_records` persistence, and pending-change clearing | Partial; no live CloudKit adapter, remote fetch, retry policy, private database entitlement, or conflict merge yet |
| native protection | `PlatformSecurityTests`, `EditorMac.entitlements`, and `DataProtectionService` cover macOS app sandbox, user-selected file read entitlement, and native file-protection hook for local database/attachment paths | Partial; Keychain metadata and CloudKit private iCloud scope remain |
| three-column desktop navigation | `NavigationSplitView` shell | Partial |
| mobile collapsed navigation | compact `NavigationStack` shell | Partial |
| performance strategy | OSLog categories and local SQLite; no large-page checks | Partial |
| TextKit 2 wrappers | `NativeTextBlockEditor` uses AppKit/UIKit native text views; macOS runtime log check shows no `textkit2_unavailable` errors | Partial; needs richer sizing, selection persistence, and focused UI tests |
| editor session state | `EditorSessionTests` and `EditorSession` cover focused block, focus reason, draft text, dirty blocks, and commit clearing | Partial; undo scope, selection/caret metadata, composition state, and UI drag state remain |
| advanced blocks | typed Markdown-imported blocks plus `PageRepository.moveBlock` cover persistent block reorder with stable `order_key` values; appending empty paragraph blocks is covered by repository and view-model tests | Partial; UI drag handles, keyboard reorder, nesting, tables, callouts, toggles, and block menu remain |
| search/backlinks | `search_index` FTS5 table plus `SearchRepositoryTests`/`SearchRepository` cover page title, block text, and attachment filename search; `BacklinkRepositoryTests`/`BacklinkRepository` cover incremental `[[Page]]` backlink maintenance and stale link cleanup; `WorkspaceViewModelTests`/`WorkspaceViewModel` expose search results and selected-page backlinks; `EditorShellView` renders search results in the page column and a backlink panel in the editor | Partial; result navigation, ranking/snippets, backlinks with page titles, and richer link syntaxes remain |
| sync conflicts | `SyncMergeEngineTests`, `SyncMergeEngine`, and `ConflictRepository` cover same-block remote conflict preservation: local text remains and remote version is stored in `conflict_versions` | Partial; conflict UI and manual merge/recovery remain |
| verification | repository/view-model tests and app builds | Partial |

## Next Implementation Slice

The completed attachment slice proves:

1. Import copies a file into an app-managed attachments directory.
2. Attachment metadata is stored in SQLite.
3. An attachment block is inserted into the current page.
4. Reloading the repository returns the attachment block and metadata.
5. The app exposes an insertion command and renders image, video, and file attachment rows.

The next concrete gaps are live CloudKit adapter behavior, Keychain/iCloud account metadata, richer Markdown syntax coverage, result/backlink navigation polish, and advanced block UI interactions.
