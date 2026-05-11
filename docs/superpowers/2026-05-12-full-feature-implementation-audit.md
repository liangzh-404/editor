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
| editable text | paragraph text can be edited and persisted through `PageRepository.updateBlockText`; `NativeTextBlockEditor` wraps `NSTextView`/`UITextView` and `EditorSession` tracks focus/drafts/dirty state | Partial; still needs undo grouping, multi-block focus movement, composition testing, and UI automation |
| local-first | SQLite opens from Application Support and app can launch without network | Partial |
| attachment blocks | `AttachmentRepositoryTests`, `AttachmentRepository`, `WorkspaceViewModel.importAttachment`, and `EditorShellView` file importer cover local copy, metadata, attachment block insertion, reload, and basic row rendering | Partial; thumbnails, async preview work, deletion GC, and live CloudKit asset sync remain |
| Markdown | `MarkdownTransformerTests`, `MarkdownTransformer`, and `WorkspaceViewModel.updateBlockText` cover core shortcut transforms and basic block export | Partial; import UI, file export, tables, callout/toggle fallback syntax, and TextKit-integrated shortcut handling remain |
| CloudKit sync | `SyncRepositoryTests`, `SyncRepository`, block edits, and attachment imports now enqueue local dirty changes | Partial; no CloudKit adapter, remote fetch, retry, change-tag persistence, or conflict merge yet |
| native protection | `PlatformSecurityTests`, `EditorMac.entitlements`, and `DataProtectionService` cover macOS app sandbox, user-selected file read entitlement, and native file-protection hook for local database/attachment paths | Partial; Keychain metadata and CloudKit private iCloud scope remain |
| three-column desktop navigation | `NavigationSplitView` shell | Partial |
| mobile collapsed navigation | compact `NavigationStack` shell | Partial |
| performance strategy | OSLog categories and local SQLite; no large-page checks | Partial |
| TextKit 2 wrappers | `NativeTextBlockEditor` uses AppKit/UIKit native text views; macOS runtime log check shows no `textkit2_unavailable` errors | Partial; needs richer sizing, selection persistence, and focused UI tests |
| editor session state | `EditorSessionTests` and `EditorSession` cover focused block, focus reason, draft text, dirty blocks, and commit clearing | Partial; undo scope, selection/caret metadata, composition state, and drag reorder state remain |
| advanced blocks | paragraph only | Missing implementation |
| search/backlinks | `search_index` FTS5 table plus `SearchRepositoryTests` and `SearchRepository` cover page title, block text, and attachment filename search | Partial; backlinks table maintenance and UI search views remain |
| sync conflicts | `conflict_versions` table exists only | Missing implementation |
| verification | repository/view-model tests and app builds | Partial |

## Next Implementation Slice

The completed attachment slice proves:

1. Import copies a file into an app-managed attachments directory.
2. Attachment metadata is stored in SQLite.
3. An attachment block is inserted into the current page.
4. Reloading the repository returns the attachment block and metadata.
5. The app exposes an insertion command and renders image, video, and file attachment rows.

The next concrete gaps are adding Markdown import/export UI, backlink maintenance, CloudKit adapter behavior, Keychain/iCloud account metadata, and advanced block interactions.
