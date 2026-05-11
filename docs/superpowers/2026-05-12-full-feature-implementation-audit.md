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
| editable text | page titles can now be edited through a plain title `TextField` and persisted through `PageRepository.updatePageTitle` / `WorkspaceViewModel.updateSelectedPageTitle`; paragraph text can be edited and persisted through `PageRepository.updateBlockText`; `NativeTextBlockEditor` wraps `NSTextView`/`UITextView` and exposes stable text-view accessibility identifiers; `EditorSession` tracks focus/drafts/dirty state; the canvas `+` button adds an editable empty paragraph block and requests native focus for it | Partial; still needs undo grouping, multi-block focus movement, composition testing, and successful UI automation on this machine |
| local-first | SQLite opens from Application Support and app can launch without network; macOS launch now avoids eager CloudKit container initialization when the process lacks CloudKit entitlements | Partial |
| attachment blocks | `AttachmentRepositoryTests`, `AttachmentRepository`, `WorkspaceViewModel.importAttachment`, and `EditorShellView` file importer cover local copy, metadata, attachment block insertion, reload, and basic row rendering | Partial; thumbnails, async preview work, deletion GC, and live CloudKit asset sync remain |
| Markdown | `MarkdownTransformerTests`, `MarkdownTransformer`, `PageRepositoryTests`, `WorkspaceViewModelTests`, `WorkspaceViewModel`, and `EditorShellView` cover core shortcut transforms, basic block export, parser import into block drafts, ordered-list/fenced-code/table/callout/toggle import, page-level Markdown import persistence, view-model import/export APIs, and macOS/iOS file import/export buttons backed by `FileDocument` | Partial; inline formatting preservation and TextKit-integrated shortcut handling remain |
| CloudKit sync | `SyncRepositoryTests`, `SyncEngineTests`, `SyncRepository`, `SyncEngine`, `CloudKitSyncAdapter`, and `CloudKitPrivateDatabaseAdapter` cover dirty queue upload through an adapter, local `sync_records` persistence, pending-change clearing, and mapping local workspace/page/block/attachment rows to CloudKit private-database records via a live saver boundary; `EditorCloudKit.entitlements` and `EditorIOS.entitlements` declare the private CloudKit container | Partial; no remote fetch loop, retry/backoff policy, app-integrated background trigger, or macOS target CloudKit entitlement because local Xcode has `No Accounts` for provisioning |
| native protection | `PlatformSecurityTests`, `EditorMac.entitlements`, `DataProtectionService`, `KeychainMetadataStore`, `CloudKitEntitlementInspector`, `CloudKitAccountMetadataService`, `WorkspaceViewModel`, and `EditorShellView` cover macOS app sandbox, user-selected file read entitlement, network-client entitlement for sync, native file-protection hook for local database/attachment paths, native Keychain round-trip storage for account/install metadata, entitlement-gated CloudKit account service creation, CloudKit account-status metadata persistence through a testable provider boundary, and app-visible iCloud account status with manual refresh | Partial; macOS target CloudKit private iCloud scope entitlement remains blocked by local Apple account/provisioning setup |
| three-column desktop navigation | `NavigationSplitView` shell | Partial |
| mobile collapsed navigation | compact `NavigationStack` shell | Partial |
| performance strategy | OSLog categories, local SQLite, FTS search, and `PageRepositoryTests.testLargePageImportLoadAndSearchIndexRemainUsable` cover import/load/search-index behavior for a 750-block page | Partial; no UI render instrumentation, scroll jank checks, or release-mode performance baseline yet |
| TextKit 2 wrappers | `NativeTextBlockEditor` uses AppKit/UIKit native text views; macOS runtime log check shows no `textkit2_unavailable` errors | Partial; needs richer sizing, selection persistence, and focused UI tests |
| editor session state | `EditorSessionTests` and `EditorSession` cover focused block, focus reason, draft text, dirty blocks, and commit clearing | Partial; undo scope, selection/caret metadata, composition state, and UI drag state remain |
| advanced blocks | typed Markdown-imported blocks include table, callout, toggle, code, list, task, quote, divider, attachments, plus `PageRepository.moveBlock` and `WorkspaceViewModel.moveBlock` for persistent block reorder with stable `order_key` values; `EditorShellView` exposes per-block move up/down controls; appending empty paragraph blocks is covered by repository and view-model tests | Partial; drag handles, keyboard reorder, nesting, structured table editing, and block menu remain |
| search/backlinks | `search_index` FTS5 table plus `SearchRepositoryTests`/`SearchRepository` cover page title, block text, and attachment filename search; `BacklinkRepositoryTests`/`BacklinkRepository` cover incremental `[[Page]]` backlink maintenance and stale link cleanup; `WorkspaceViewModelTests`/`WorkspaceViewModel` expose search results and selected-page backlinks; `EditorShellView` renders search results in the page column and a backlink panel in the editor | Partial; result navigation, ranking/snippets, backlinks with page titles, and richer link syntaxes remain |
| sync conflicts | `SyncMergeEngineTests`, `SyncMergeEngine`, and `ConflictRepository` cover same-block remote conflict preservation: local text remains and remote version is stored in `conflict_versions` | Partial; conflict UI and manual merge/recovery remain |
| verification | repository/view-model/platform/markdown/sync tests, title-editing regressions, entitlement-gated CloudKit startup regression, 750-block page regression, macOS/iOS app builds, and latest macOS app launch evidence | Partial; macOS UI automation test target exists but is blocked by local system authentication |

## Next Implementation Slice

The completed attachment slice proves:

1. Import copies a file into an app-managed attachments directory.
2. Attachment metadata is stored in SQLite.
3. An attachment block is inserted into the current page.
4. Reloading the repository returns the attachment block and metadata.
5. The app exposes an insertion command and renders image, video, and file attachment rows.

The next concrete gaps are CloudKit remote fetch/retry/background trigger, macOS CloudKit target entitlement once Xcode account/provisioning is available, inline Markdown preservation, result/backlink navigation polish, and richer advanced block interactions.
