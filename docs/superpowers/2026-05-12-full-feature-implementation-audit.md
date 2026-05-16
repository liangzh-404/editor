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
| macOS and iOS project | `project.yml`, `EditorMac`, `EditorIOS`, `EditorTests`, `EditorMacUITests`, and `EditorIOSUITests`; both app targets build; iOS UI test target now build-for-testing compiles; macOS startup now falls back to the SwiftUI File > New Window menu action when the app is running with no visible keyable window | Implemented foundation |
| clean white shell | `EditorShellView.swift` renders white three-column/collapsed shell | Partial |
| block model | `notebooks`, `pages`, and `blocks` tables plus `NotebookSummary`, `PageSummary`, and `BlockSnapshot`; paragraph blocks persist; `PageRepository.createNotebook` creates local Notebook groups and child Notebook groups; `PageRepository.loadWorkspaceSnapshot` now returns Notebooks in depth-first hierarchy order; `PageRepository.updateNotebookName` renames notebooks and queues notebook sync updates; `PageRepository.moveNotebook` persists stable notebook `order_key` values and queues changed notebooks; `PageRepository.createPage` creates a new page at the end of the target Notebook with an empty editable paragraph and queues page/block sync changes; `PageRepository.archivePage` hides archived pages and queues a page archive sync change; `WorkspaceViewModel.archivePageForUI` keeps the current editor selection when archiving a background page from the list; `WorkspaceViewModel.undoLastPageArchive` restores the most recently archived page and preserves the appropriate pre-archive selection; `PageRepository.restorePage` returns archived pages to the visible list and queues a page restore sync change; `PageRepository.permanentlyDeleteArchivedPage` hard-deletes archived pages, cascades page blocks, removes related links, and queues a page delete tombstone in the same local transaction; `PageRepository.indentBlock` and `PageRepository.outdentBlock` update `parent_block_id` for nested block structure and queue block sync updates; `PageRepository.deleteBlock` soft-deletes blocks, removes source backlinks, and queues a block delete sync change; workspace snapshots now load notebooks, visible pages, archived pages, and non-deleted blocks for all visible pages so page selection can show the selected page body | Partial |
| block-first information architecture | Schema version 18 adds `tags`, `page_tags`, `diary_entries`, and `pages.origin`; `WorkspaceSnapshot` carries tags, page-tag assignments, and active diary text; `WorkspaceViewModel` launches in diary mode, exposes Diary / All Documents / Favorites / Tags / Search / Archive collection state, and keeps existing Notebook data loadable behind the visible route; `EditorShellView` replaces the visible Notebook-first shell with the block-first rail and All Documents middle column | Implemented user-visible slice |
| editable text | page titles can now be edited through a plain title `TextField` and persisted through `PageRepository.updatePageTitle` / `WorkspaceViewModel.updateSelectedPageTitle`; paragraph text can be edited and persisted through `PageRepository.updateBlockText`; `NativeTextBlockEditor` wraps `NSTextView`/`UITextView`, exposes stable text-view accessibility identifiers, and shows a lightweight placeholder for empty unfocused blocks; macOS native text mouse-down now explicitly makes the `NSTextView` first responder and logs `editor_native_text_mouse_down`; `EditorSession` tracks focus/drafts/dirty state, selected caret range, and active marked-text composition block; AppKit/UIKit text delegates write selection and composition changes back to the session; `WorkspaceViewModel` now keeps a text-edit undo stack, groups sequential same-block same-type text edits, exposes an enabled-state flag and UI command, restores prior block text/type, and refocuses the restored block; the canvas `+` button adds an editable empty paragraph block and requests native focus for it; creating a new page now queues focus for its initial empty paragraph block; clicking anywhere on a text block row requests native focus through a simultaneous tap gesture so it does not steal the native text click; Return splits the current editable text block at the native caret/selection, keeps leading text in the original block, moves trailing text into a focused paragraph block, and still supports the end-of-block next paragraph flow; Backspace at the start of a text block merges into the previous editor-visible editable block, while Forward Delete at the end merges the next editor-visible editable block, and both restore the caret at the join point; Tab / Shift-Tab in native text views route to block indent/outdent for hardware keyboard editing; boundary Up/Down arrows move focus across adjacent editable blocks at text boundaries; toolbar bold, italic, and inline-code actions apply Markdown wrappers to the current native text selection or insert placeholders at the focused block caret, then restore the selection inside the inserted Markdown markers; inline link insertion uses a persistent toolbar panel that keeps its captured text target while editing label/URL fields; native Cmd-K opens that same panel for the current text selection and pre-fills it when the selection is already inside an inline Markdown link; multiline pasted text now expands the native text block wrapper instead of clipping inside a fixed-height view; `EditorMacEditingUITests` now verifies direct TextView typing, row-click typing, Return-to-next-block typing, Return-at-caret split/focus typing, Backspace-at-start merge/focus typing, Forward-Delete-at-end merge/focus typing, boundary-arrow cross-block typing, multiline paste sizing, toolbar Add-to-next-block typing, bold/italic/code toolbar placeholder replacement, selected-range inline-link panel replacement, Cmd-K selected-range inline-link insertion, and Cmd-K existing-link update in a sandbox-compatible app data directory | Partial; still needs IME UI automation and broader editing UI automation |
| local-first | SQLite opens from Application Support and app can launch without network; macOS launch now avoids eager CloudKit container initialization when the process lacks CloudKit entitlements | Partial |
| attachment blocks | `AttachmentRepositoryTests`, `AttachmentRepository`, `AttachmentThumbnailScheduling`, `AttachmentPreviewState`, `WorkspaceViewModel.importAttachment`, and `EditorShellView` file importer cover local copy, metadata, attachment block insertion, reload, image/video thumbnail generation and persistence, thumbnail-backed image/video attachment rows, pending preview state/UI for deferred image/video thumbnails, basic file row rendering, deleting an attachment block reference while retaining attachment metadata/files, explicit unreferenced-attachment GC for metadata/files, deferred thumbnail generation for UI imports, missing-thumbnail generation, background preview scheduling with snapshot refresh, and macOS attachment-toolbar UI automation that imports a fixture through the real toolbar button and verifies the rendered attachment row | Partial; live CloudKit asset sync and richer preview failure/retry states remain |
| Markdown | `MarkdownTransformerTests`, `MarkdownTransformer`, `PageRepositoryTests`, `WorkspaceViewModelTests`, `WorkspaceViewModel`, and `EditorShellView` cover core shortcut transforms, H1/H2/H3 Markdown shortcut/import/export mapping, basic block export, parser import into block drafts, ordered-list/fenced-code/table/callout/toggle import, completed and incomplete task item import/export, soft-wrapped paragraph import that preserves inline Markdown markers, Markdown inline link composition, Markdown inline link insertion at the current native text selection, existing inline Markdown link target detection and replacement from the current native selection, Markdown inline bold/italic/code/strikethrough formatting from native text selections, same-format toggle-off for selected content already wrapped in Markdown markers or for a fully selected Markdown span including markers, post-format selection placement inside inserted markers, native Cmd-B/Cmd-I inline bold/italic formatting shortcuts, native Cmd-E inline-code formatting shortcut, native Cmd-Shift-X inline strikethrough formatting shortcut, native Cmd-K inline-link panel shortcut, inline Markdown style scanning for bold/italic/strikethrough/code/link-label ranges plus optional syntax-marker ranges while avoiding style markers inside code spans, native attributed inline Markdown rendering in editable text blocks with dimmed Markdown delimiters/link suffix syntax, page-level Markdown import persistence, view-model import/export APIs, inline Markdown link insertion into text blocks, macOS bold/italic/code/strikethrough toolbar UI automation, macOS Cmd-B selected-text format/toggle UI automation, macOS Cmd-E selected-text inline-code UI automation, macOS Cmd-Shift-X selected-text UI automation, macOS Cmd-K selected-text inline-link UI automation, selected-range inline link panel UI automation, macOS Markdown import/export toolbar UI automation, and macOS/iOS file import/export buttons backed by `FileDocument` | Partial; richer inline editing UI and broader TextKit shortcut handling remain |
| CloudKit sync | `SyncRepositoryTests`, `SyncEngineTests`, `SchemaMigratorTests`, `WorkspaceViewModelTests`, `SyncRepository`, `SyncEngine`, `CloudKitSyncAdapter`, `CloudKitRemoteChangeFetching`, and `CloudKitPrivateDatabaseAdapter` cover dirty queue upload through an adapter, local `sync_records` persistence, pending-change clearing, delete uploads clearing stale `sync_records`, retry metadata in `sync_changes`, failure recording with exponential backoff, skipping deferred changes until `next_attempt_at`, continuing later uploads after one failed change, server-change-token storage in `sync_server_change_tokens`, fetch-time reuse and persistence of the private-database token, remote workspace/notebook/page/attachment/block mapping from CloudKit records, applying fetched remote workspace/notebook/page/attachment/block changes through `SyncMergeEngine`, remote block soft-delete records, CloudKit deleted record IDs for notebook/page/attachment/block, remote page deletion as archive/hide, remote notebook deletion as group removal while preserving pages, remote attachment deletion as metadata removal plus attachment-block hiding, remote `CKAsset` download into the local attachments directory, foreground/activation sync scheduling through `scenePhase`, silent private-database push subscription creation through `CloudKitPrivateDatabaseSubscriptionEnsurer`, activation/manual sync subscription ensuring through `SyncEngine`, generated iOS `UIBackgroundModes = remote-notification`, iOS remote-notification delegate completion through `RemoteNotificationSyncHandler` and `EditorIOSAppDelegate`, refreshing visible blocks after manual or activation sync, app-visible manual sync status, mapping local workspace/notebook/page/block/attachment rows to CloudKit private-database records via a live saver boundary, CloudKit record deletion through a live deleter boundary for local delete tombstones, token-aware record-change fetcher handoff, `CKServerChangeToken` secure archiving/unarchiving, and a live `CKFetchRecordZoneChangesOperation` boundary for default-zone delta fetches; `EditorCloudKit.entitlements` and `EditorIOS.entitlements` declare the private CloudKit container | Partial; no live iCloud entitlement validation of the zone-delta/silent-push path, no on-device silent-push delivery proof, and no macOS target CloudKit entitlement because local Xcode has `No Accounts` for provisioning |
| native protection | `PlatformSecurityTests`, `EditorMac.entitlements`, `DataProtectionService`, `KeychainMetadataStore`, `CloudKitEntitlementInspector`, `CloudKitAccountMetadataService`, `WorkspaceViewModel`, `AppEnvironment`, and `EditorShellView` cover macOS app sandbox, user-selected file read entitlement, network-client entitlement for sync, native file-protection hook for local database/attachment paths, native Keychain round-trip storage for account/install metadata, entitlement-gated CloudKit account/status service creation, entitlement-gated CloudKit sync-engine creation, CloudKit account-status metadata persistence through a testable provider boundary, and app-visible iCloud account status with manual refresh | Partial; macOS target CloudKit private iCloud scope entitlement remains blocked by local Apple account/provisioning setup |
| three-column desktop navigation | `NavigationSplitView` shell, selectable depth-first Notebook-grouped page list, editable Notebook headers, Notebook move up/down controls with semantic labels and availability values, Notebook indent/outdent controls with semantic labels and availability values, Notebook-level child-Notebook creation and page creation controls with semantic labels and availability values, context-menu page archive action that preserves the current editor when archiving a background page, page-list `Undo Archive` action, Archive section with restore and permanent-delete buttons, New Notebook action, and a heading-derived Outline panel whose H1/H2/H3 rows expose semantic heading labels/levels and can request focus for the selected heading block | Partial |
| block-first desktop navigation | Desktop navigation now presents Diary, All Documents, Favorites, Tags, Search, and Archive as the primary visible collections; All Documents uses `WorkspaceSnapshot.pages` sorted by `updated_at DESC`; Favorites remains connected to page favorite state; tag filters show normal pages assigned to the selected tag and exclude diary text; page rows expose compact tag chips and semantic tag accessibility values | Implemented user-visible slice |
| mobile collapsed navigation | compact `NavigationStack` shell, depth-first Notebook-grouped page list, editable Notebook headers, Notebook move up/down controls, Notebook indent/outdent controls, Notebook-level child-Notebook creation, Notebook-level `+` buttons for creating a new editable page, context-menu page archive action, page-list `Undo Archive` action, Archive section with restore and permanent-delete buttons, New Notebook action, compact page-route pushes for search-result/backlink selection, and stable compact workspace/page accessibility identifiers for UI automation | Partial; compact UI execution is blocked locally by Simulator `CoreLocationMigrator` data migration, but the iOS UI test target compiles |
| performance strategy | OSLog categories, local SQLite, FTS search, and `PageRepositoryTests.testLargePageImportLoadAndSearchIndexRemainUsable` cover import/load/search-index behavior for a 750-block page; text edits now route through `SearchRepository.updateBlockIndex` so a single-block edit replaces only that block's FTS row instead of rebuilding the full search index; `EditorCanvasView` now uses a lazy block stack and logs `editor_canvas_rendered` metrics with page, block, attachment, backlink, conflict, and large-page state; `EditorCanvasScrollMetricsTracker` records visible/peak visible counts, first/last visible block index, current/peak visible index span, scroll lifetime milliseconds, and block appear/disappear churn for scroll observability, then logs `editor_canvas_scroll_visible` with the runtime summary; `SQLiteDatabase.withImmediateTransaction` centralizes repository transaction commit/rollback handling and logs `transaction_committed` / `transaction_rolled_back` with labels and duration milliseconds; `EditorCanvasRenderMetrics` / `EditorCanvasRenderPolicy` / `EditorCanvasScrollMetrics` have focused regression coverage; `EditorCanvasView` exposes a DEBUG-only `editor.scroll-metrics-test-output` probe outside the lazy stack so UI automation can read runtime scroll metrics after the canvas has moved; `EditorMacEditingUITests.testLargePageScrollLoadsDistantBlocks` seeds a 760-block page, drives the editor scroll view through `editor.canvas-scroll`, verifies an offscreen block is realized by the lazy stack, and verifies the runtime metrics reached the distant visible block index; `scripts/perf_baseline.sh` runs the large-page repository check, scroll-metrics baseline, and macOS app build in Release configuration | Partial; deeper performance optimization and Instruments/signpost analysis are intentionally sequenced after user-facing feature/UI/UX work |
| TextKit 2 wrappers | `NativeTextBlockEditor` uses AppKit/UIKit native text views; empty text blocks have a visible placeholder affordance; native text wrappers suppress delegate forwarding while applying model text so programmatic SwiftUI updates do not re-enter editor persistence; focus requests can carry a validated `EditorTextSelection` so AppKit/UIKit restore a requested range or safely fall back to the text end; supported editable blocks apply temporary AppKit/UIKit text-storage attributes for bold/italic/strikethrough/code/link-label inline Markdown plus secondary-color Markdown syntax markers without changing the raw Markdown text; code blocks and tables opt out of inline styling; code blocks can disable native line wrapping through the block payload state; AppKit/UIKit wrappers measure native content height after model updates and user edits, then feed that height back into the SwiftUI wrapper so multiline text expands the block; same-block focus scheduling preserves an already queued selection-bearing toolbar focus request instead of overwriting it with a block-end focus request; macOS runtime log check shows no `Publishing changes`, `textkit2_unavailable`, or `CKException` entries after fresh launch; macOS mouse-down instrumentation exposes direct evidence for native text clicks; macOS `NSTextView` and iOS `UITextView` now route Cmd-Option-Up/Down external-keyboard shortcuts into block reorder commands, Tab / Shift-Tab into block indent/outdent commands, unmodified Return into selection-bearing block split requests, unmodified Backspace/Delete at text start into selection-bearing merge-with-previous requests, unmodified Forward Delete at text end into selection-bearing merge-with-next requests, unmodified boundary Up/Down into adjacent editable block focus requests, Cmd-B/Cmd-I/Cmd-E/Cmd-Shift-X into selection-bearing Markdown inline format requests, and Cmd-K into a selection-bearing inline-link panel request; macOS UI automation verifies an eight-line paste increases the native text-view frame height | Partial; needs more focused UI tests |
| editor session state | `EditorSessionTests` and `EditorSession` cover focused block, focus reason, draft text, dirty blocks, commit clearing, selected caret range, and active composition block clearing; `WorkspaceViewModelTests` cover basic block text undo, sequential same-block same-type text undo grouping, and Markdown-shortcut type undo through the local repository path | Partial; IME UI automation and UI drag state remain |
| advanced blocks | typed Markdown-imported blocks include table, callout, toggle, code, list, task, quote, divider, attachments, structured `pageReference` blocks, and structured `blockReference` blocks; `PageRepository.moveBlock` and `WorkspaceViewModel.moveBlock` persist block reorder with stable `order_key` values; `WorkspaceViewModel.moveBlockByKeyboard` supports focused block reorder while preserving focus on the moved block; `WorkspaceViewModel.indentBlock` and `WorkspaceViewModel.outdentBlock` support nested block parent changes while preserving focus on the edited block; native text views expose Tab / Shift-Tab keyboard routes for block nesting; `WorkspaceViewModel.changeBlockType` preserves block text while changing type through the existing `updateBlock` sync path; `PageRepository.updateTaskItemCompletion` stores task completion in block payload JSON, queues sync, and `EditorShellView` exposes visible task-block chrome with an embedded checkbox-style task toggle plus semantic completed/incomplete accessibility label and value; `PageRepository.updateToggleExpansion` stores toggle expansion in block payload JSON, queues sync, and `WorkspaceViewModel.editorVisibleBlocks` hides descendants of collapsed toggle blocks without removing them from the page data set; `EditorShellView` exposes a toggle expansion button with semantic expanded/collapsed accessibility label and value; `PageRepository.updateCodeBlockLineWrapping` stores code-block line wrapping in block payload JSON, queues sync, and `EditorShellView` exposes a code-wrap toggle with semantic line-wrap accessibility label/value that feeds the native text editor; `PageRepository.appendPageReferenceBlock` stores `target_page_id` in block payload and `WorkspaceViewModel.appendPageReferenceToCurrentPage` inserts a target-page reference without changing the source-page selection; `PageRepository.appendBlockReferenceBlock` stores `target_page_id` plus `target_block_id`, and `WorkspaceViewModel.openBlockReference` navigates to the target page and requests focus for the target block; `EditorShellView` exposes per-block move up/down/indent/outdent/delete controls with semantic labels and availability values, block drag handles with row/end drop targets plus current-type accessibility values, visible table-block chrome with structured table-cell editing backed by Markdown table text, table row/column append and remove controls with semantic labels plus live table-dimension accessibility values, visible task-block chrome that preserves native text editing, visible callout chrome that preserves native text editing, visible code-block chrome with an embedded wrap control that preserves native text editing, visible toggle-block chrome with an embedded expansion control that preserves native text editing and exposes expanded/collapsed state, semantic page-reference rows with page-target chrome, semantic block-reference rows with block-target chrome, insert-page-reference and insert-block-reference menus, renders nested blocks with stable leading indentation from `parentBlockID`, and exposes a text block type menu for paragraph, heading, lists, task, quote, code, divider, table, callout, and toggle with the current type in its accessibility value; appending, deleting, moving, keyboard moving, drag target resolution, table parsing/cell update/row append/column append/row removal/column removal, macOS block-action semantic UI state, macOS table-control semantic UI state, macOS table block type menu conversion/editability, macOS toggle block type menu conversion/editability, macOS code block type menu conversion/editability, macOS callout block type menu conversion/editability, macOS divider block type menu conversion, indenting, outdenting, keyboard indentation resolving, persisted toggle collapse/expand, explicit type changes, task completion, macOS task-toggle semantic UI state, macOS task block type menu conversion/editability, macOS toggle-expansion semantic UI state, code-block line wrapping, macOS code-wrap semantic UI state, page-reference creation/export, block-reference creation/export, macOS reference-row semantic UI state, and macOS reference-row click navigation/focus are covered by repository/view-model/Markdown/native-editor/UI tests | Partial; richer advanced block UI polish remains |
| search/backlinks | `search_index` FTS5 table plus `SearchRepositoryTests`/`SearchRepository` cover page title, block text, diary text, attachment filename search, title-prioritized ranking, contextual FTS snippets, destination page IDs for page/block/attachment results, and diary-specific search result IDs that do not resolve into normal document pages; attachment result navigation resolves the owning page through the attachment block payload; `BacklinkRepositoryTests`/`BacklinkRepository` cover incremental `[[Page]]` backlink maintenance, stale link cleanup, source page titles, structured page-reference backlinks from `target_page_id`, structured block-reference backlinks from `target_page_id` plus `target_block_id`, and Markdown external link extraction into `target_url`; `WorkspaceViewModelTests`/`WorkspaceViewModel` expose search results, selected-page backlinks, selected-page external links, search-result selection, backlink selection, page-reference opening, block-reference opening with target block focus, inline Markdown link insertion that refreshes selected-page external links, selected-range inline Markdown link insertion that returns label focus selection, existing inline Markdown link updates that refresh selected-page external links, compact navigation intents, diary search inclusion, and diary exclusion from document/tag result lists; `EditorShellView` renders clickable search results in the page column, clickable backlink rows in the editor, clickable external link rows in the editor through `openURL`, clickable page-reference rows, clickable block-reference rows with type-specific accessibility identifiers, an inline Markdown link insertion/update popover that targets the current native text selection when available, and compact route pushes for selected search/backlink/page-reference/block-reference pages; macOS UI automation verifies inserting page and block reference rows through the toolbar menus | Partial; richer inline link editing UI remains |
| sync conflicts | `SyncMergeEngineTests`, `WorkspaceViewModelTests`, `SyncMergeEngine`, `ConflictRepository`, `WorkspaceViewModel`, and `EditorShellView` cover same-block remote conflict preservation, selected-page conflict listing with local/remote text, an app-visible side-by-side conflict panel, line-level added/removed/unchanged diff highlighting, accepting a remote conflict version, accepting all current-page remote conflict versions as a batch, applying the remote text to the local block, clearing that block's pending local sync change, accepting the local conflict version, accepting all current-page local conflict versions as a batch, preserving local block text and pending local sync changes for local acceptance, manually applying merged text, seeding the manual merge editor from either local or remote text without resolving the conflict, panel-level batch seeding of all current-page manual merge drafts from local or remote text, pruning stale manual merge drafts after conflict rows disappear, batch-applying all current-page manual merge drafts, clearing conflict rows after merge, preserving exactly one pending local block update for manual merges, refreshing backlinks/search state, and refocusing the resolved block | Partial; deeper multi-conflict workflow polish remains |
| verification | repository/view-model/platform/markdown/sync tests, notebook schema/rename/reorder/nesting/depth-first-order repository/view-model regressions, page archive/background-archive-selection/archive-undo/restore/permanent-delete regressions, delete tombstone and CloudKit record-delete regressions, block delete/backlink cleanup regressions, keyboard block reorder and shortcut-resolver regressions, boundary-arrow focus resolver regressions, inline-format keyboard resolver regressions, inline-link keyboard resolver regression, block indent/outdent regressions, conflict listing, remote-acceptance, local-acceptance, side-by-side/manual-merge/batch-manual-merge/merge-draft-seeding/batch-merge-draft-seeding regressions, text undo, sequential text-undo grouping, and Markdown-shortcut undo regressions, editor selection/composition session regressions, native text model-update guard and focus-selection regressions, remote page/notebook/attachment/block deletion regressions, remote block delete/backlink cleanup regressions, explicit block-type-change regression, attachment image/video thumbnail regressions, attachment-reference delete and unreferenced-GC regressions, CloudKit asset-download regression, CloudKit silent-subscription creation regression, activation subscription-ensure regression, generated iOS remote-notification background-mode regression, title-editing regressions, page-creation and initial-empty-block focus regressions, native text placeholder and code-line-wrap configuration regressions, H1/H2/H3 Markdown import/export/shortcut and Outline-level regressions, macOS notebook-action/task-toggle/toggle-expansion/code-wrap/block-action/table-control/outline semantic states, macOS direct-text, row-click, Return-insert, Return-at-caret split/focus typing, multiline paste sizing, boundary-arrow cross-block focus, Cmd-B selected-text inline formatting/content-only toggle-off/fully-selected Markdown-span toggle-off, Cmd-E selected-text inline-code formatting, Cmd-Shift-X selected-text strikethrough formatting, Cmd-K selected-text inline-link insertion, Cmd-K existing-inline-link update, toolbar-Add, toolbar bold/italic/code/strikethrough placeholder replacement, selected-range inline-link panel replacement, outline click-to-heading-focus UI automation, conflict merge-draft toolbar UI automation, conflict batch merge-draft toolbar UI automation, page/block reference toolbar-menu insertion, reference-row semantic UI state, reference-row click navigation and focus, Markdown import/export toolbar automation, attachment toolbar import automation, large-page runtime scroll UI regression, inline-link insertion, selected-range inline-link insertion, existing inline-link update, inline bold/italic/code/strikethrough formatting, inline Markdown toggle-off, inline Markdown style scanner, inline Markdown syntax-marker scanner, and native attributed inline styling regressions, compact search/backlink/navigation-intent regressions, foreground activation sync regression, soft-wrapped inline Markdown import regression, inline Markdown link composer regression, inline Markdown post-format selection regression, code-block line-wrap persistence regression, sync retry/backoff regressions, server-change-token regressions, token-aware CloudKit fetcher regression, remote workspace/notebook/page/attachment/block fetch regressions, app-level manual sync regression, entitlement-gated CloudKit startup regression, search ranking/snippet/backlink/attachment-result navigation regressions, page-reference creation/export regressions, block-reference creation/export regressions, 750-block page regression, canvas render metric regression, canvas scroll metric regression, Release large-page/scroll-metrics/macOS-build baseline script, macOS/iOS app builds, iOS UI test target build-for-testing compile, latest macOS app launch evidence, SwiftUI runtime issue log check, CKException log check, and TextKit availability log check | Partial; broader UI automation coverage remains |

## Recent Favorite Page Navigation Fix

- Schema version 7 adds `pages.is_favorite`, and `PageSummary` / `WorkspaceSnapshot.favoritePages` expose the state without mixing archived pages into the active favorites list.
- `PageRepository.updatePageFavorite` persists favorite changes, queues page sync updates, and preserves favorite state while a page is archived and later restored.
- `WorkspaceViewModel.updatePageFavorite` refreshes visible state without changing the current editor selection.
- Desktop and compact page rows expose Add/Remove Favorites context-menu actions; desktop page rows now also expose a direct star toggle, desktop sidebar renders favorited pages as selectable rows, and page rows expose a semantic `Favorite` / `Not favorite` accessibility value.
- CloudKit page records now upload and fetch `isFavorite` through `PageRecord` / `RemotePageChange`.
- Regression coverage: `testUpdatePageFavoritePersistsReloadsAndQueuesSyncChange`, `testArchivedFavoritePageHidesFromFavoritesUntilRestored`, `testUpdatePageFavoriteRefreshesSnapshotAndKeepsSelection`, `testCloudKitPrivateDatabaseAdapterMapsPageFavoriteToRecord`, `testCloudKitPrivateDatabaseAdapterMapsRemoteRecordsToChangeSet`, `testFetchRemoteChangesAppliesWorkspaceNotebookPageAttachmentAndBlockChanges`, `testFavoritePageAppearsInSidebarAndPageRowState`, and `testPageFavoriteToggleUpdatesSidebarAndRowState`.

## Recent Strikethrough Inline Markdown Fix

- `MarkdownInlineStyleScanner` now recognizes `~~strikethrough~~` content outside code spans and leaves literal `~~` markers inside inline code styled only as code.
- AppKit and UIKit native text wrappers apply a temporary strikethrough attribute for those inline Markdown content ranges without changing the raw Markdown text.
- `EditorCanvasView` exposes a strikethrough toolbar button that uses the same selection-preserving inline formatter path as bold, italic, and code.
- `MarkdownInlineFormatKeyboardResolver`, macOS `NSTextView`, and iOS `UITextView` now route Cmd-Shift-X into the same selection-preserving strikethrough formatter path.
- Regression coverage: `testMarkdownInlineStyleScannerFindsStrikethroughRangeOutsideCodeSpan`, `testMarkdownInlineFormatKeyboardResolverHandlesBoldItalicStrikethroughAndCodeShortcutsOnly`, `testStrikethroughToolbarInsertsPlaceholderAndKeepsTypingInEditor`, and `testCommandShiftXFormatsSelectionAndKeepsSelectionInEditor`.

## Recent Inline Markdown Syntax Marker Polish

- `MarkdownInlineStyleScanner.runs(in:includingSyntaxMarkers:)` keeps the default content-only inline style runs for existing callers while allowing native renderers to request Markdown syntax-marker ranges.
- AppKit and UIKit native text wrappers dim Markdown delimiters, code backticks, and inline-link bracket/URL syntax with secondary label color while preserving the raw Markdown text.
- Regression coverage: `testMarkdownInlineStyleScannerCanIncludeSyntaxMarkerRangesForRenderingPolish` plus the focused `MarkdownTransformerTests` / `NativeTextBlockEditorTests` run.

## Recent Inline Markdown Toggle Polish

- `MarkdownInlineFormatter` now treats same-format commands as toggles when the selected content is already surrounded by matching Markdown markers, or when the selection itself includes the full Markdown span.
- The toggle paths remove the surrounding markers and keep the original content selected, so typing immediately replaces plain text instead of producing nested marker runs such as `****text****`.
- Marker detection ignores longer adjacent runs, so single-marker formats do not accidentally peel one character off a stronger marker pair.
- Regression coverage: `testMarkdownInlineFormatterTogglesOffExistingMarkersAroundSelection`, `testMarkdownInlineFormatterTogglesOffSelectedTextIncludingMarkers`, `testCommandBTogglesOffExistingBoldMarkersAndKeepsSelectionInEditor`, and `testCommandBTogglesOffFullySelectedBoldMarkdownSpan`.

## Recent Inline Link Editing Fix

- `MarkdownInlineLinkEditTarget` detects the existing inline Markdown link around the current selection, ignores image links and inline-code literals, and returns the full replacement range with prefilled label/URL values.
- `EditorCanvasView` reuses the existing inline-link popover for updates: Cmd-K inside an existing link pre-fills the panel, changes the confirm label to `Update Link`, and replaces the whole original link while keeping the new label selected.
- Regression coverage: `testMarkdownInlineLinkEditTargetFindsExistingLinkAroundSelection`, `testMarkdownInlineLinkEditTargetIgnoresImagesAndCodeSpans`, `testUpdateExistingMarkdownLinkAtSelectionRefreshesExternalLinksAndReturnsLabelSelection`, and `testCommandKUpdatesExistingInlineLinkUnderSelection`.

## Recent Conflict Merge Draft Polish

- `ConflictMergeDrafts` centralizes manual conflict draft state, defaulting unresolved conflicts to local text, allowing local/remote draft seeding, and pruning draft entries when conflict rows disappear.
- `ConflictPanel` exposes `Edit Local` and `Edit Remote` actions that copy either side into the manual merge editor without resolving the conflict row.
- The macOS conflict row now preserves child accessibility identifiers so UI automation can target the merge editor and draft buttons directly.
- Regression coverage: `testConflictMergeDraftsSeedLocalRemoteAndPruneRemovedConflicts` and `testConflictDraftButtonsSeedManualMergeEditor`.

## Recent Conflict Batch Draft Polish

- `ConflictMergeDrafts` can now seed every current-page manual merge draft from local or remote text in one call.
- `ConflictPanel` exposes `Draft All Local` and `Draft All Remote` actions that fill all visible manual merge editors without accepting or resolving the conflict rows.
- DEBUG UI seeding can create multiple conflict rows via `EDITOR_UI_TEST_CONFLICT_COUNT`, giving macOS UI automation a stable two-conflict workflow.
- Regression coverage: `testConflictMergeDraftsCanSeedEveryDraftFromLocalOrRemoteText` and `testConflictDraftAllButtonsSeedEveryManualMergeEditor`.

## Recent Toolbar Import Export Automation Fix

- `EditorCanvasView` routes Markdown import, Markdown export, and attachment import toolbar buttons through DEBUG-only UI-test fixture overrides when matching environment keys are present, preserving the normal file panel paths otherwise.
- Markdown export capture derives text from the currently rendered canvas blocks, so UI automation can verify the visible page Markdown without stopping at the system save panel.
- Regression coverage: `testMarkdownImportToolbarImportsFixtureFile`, `testMarkdownExportToolbarCapturesCurrentPageMarkdown`, and `testAttachmentToolbarImportsFixtureAndRendersAttachmentRow`.

## Recent Inline Link Keyboard Fix

- `MarkdownInlineLinkKeyboardResolver` maps exact Cmd-K native text shortcuts to inline-link insertion without stealing Cmd-Option or unrelated shortcuts.
- AppKit `NSTextView` and UIKit hardware-keyboard commands now pass the live native selected range into the existing inline-link panel path.
- macOS also installs a scoped local key monitor because SwiftUI commands and focused values do not reliably receive Cmd-K while a wrapped `NSTextView` owns first responder focus.
- Regression coverage: `testMarkdownInlineLinkKeyboardResolverHandlesCommandKOnly` and `testCommandKOpensInlineLinkPanelForSelection`.

## Recent Inline Format Keyboard Fix

- `MarkdownInlineFormatKeyboardResolver` maps exact Cmd-B/Cmd-I/Cmd-E/Cmd-Shift-X native text shortcuts to Markdown bold/italic/code/strikethrough formatting without stealing Cmd-Option or unrelated shortcuts.
- AppKit `NSTextView` and UIKit hardware-keyboard commands now pass the live native selected range into the existing inline-format view-model path.
- `EditorCanvasView` schedules a selection-bearing focus request after keyboard formatting so typing replaces the selected formatted text.
- Regression coverage: `testMarkdownInlineFormatKeyboardResolverHandlesBoldItalicStrikethroughAndCodeShortcutsOnly`, `testCommandBFormatsSelectionAndKeepsSelectionInEditor`, `testCommandEFormatsSelectionAsInlineCodeAndKeepsSelectionInEditor`, and `testCommandShiftXFormatsSelectionAndKeepsSelectionInEditor`.

## Recent Return Split Editing Polish

- `WorkspaceViewModel.splitTextBlockAtSelection` splits editable block text using the native UTF-16 selection range, preserving leading text in the current block and moving trailing text into the inserted paragraph block.
- AppKit `NSTextView` and UIKit `UITextView` Return handling now pass the live selected range into the split path instead of blindly appending an empty paragraph.
- `EditorCanvasView` schedules the inserted block with a selection-bearing focus request at location `0`, so typing continues before the moved trailing text.
- Regression coverage: `testSplitTextBlockAtSelectionMovesTrailingTextIntoFocusedInsertedBlock` and `testReturnSplitsTextBlockAtCaretAndFocusesInsertedRemainder`.

## Recent Backspace Merge Editing Polish

- `WorkspaceViewModel.mergeTextBlockWithPreviousAtSelection` merges a text block into the previous editor-visible editable block only when the caret is collapsed at location `0`.
- AppKit `NSTextView` and UIKit `UITextView` Backspace/Delete handling now pass the live selected range into the merge path and fall back to normal deletion when the merge preconditions are not met.
- `EditorCanvasView` schedules the previous block with a selection-bearing focus request at the original join point, so typing continues between the preserved leading and moved trailing text.
- Regression coverage: `testMergeTextBlockAtStartMovesTextIntoPreviousBlockAndFocusesJoinPoint`, `testMergeTextBlockAtStartUsesPreviousEditorVisibleBlock`, and `testBackspaceAtStartMergesTextBlockWithPreviousBlock`.

## Recent Forward Delete Merge Editing Polish

- `WorkspaceViewModel.mergeTextBlockWithNextAtSelection` merges the next editor-visible editable block into the current text block only when the caret is collapsed at the current text end.
- AppKit `NSTextView` Forward Delete and UIKit hardware-keyboard delete commands pass the live selected range into the merge path and fall back to normal in-block deletion when the merge preconditions are not met.
- `EditorCanvasView` schedules the current block with a selection-bearing focus request at the original join point, so typing continues before the moved next-block text.
- Regression coverage: `testMergeTextBlockAtEndMovesNextTextIntoCurrentBlockAndFocusesJoinPoint` and `testForwardDeleteAtEndMergesTextBlockWithNextBlock`.

## Recent Boundary Arrow Focus Fix

- `BlockKeyboardFocusResolver` only requests cross-block focus when the caret is collapsed at a text boundary: Up at the start, or Down at the UTF-16 text end.
- `NativeTextBlockEditor` routes the same resolver through AppKit `keyDown` and UIKit hardware-keyboard `pressesBegan`.
- `EditorCanvasView` converts boundary arrow requests into selection-bearing block focus requests, placing previous-block focus at the target text end and next-block focus at the target text start.
- Regression coverage: `testBlockKeyboardFocusResolverMovesOnlyAtTextBoundaries`, `testBlockKeyboardFocusResolverTargetsAdjacentEditableBlocks`, and `testBoundaryArrowKeysMoveFocusBetweenTextBlocks`.

## Recent Native Text Sizing Fix

- `NativeTextBlockEditor` now measures AppKit/UIKit text content height and applies that measured height to the SwiftUI wrapper.
- Multiline pasted or model-driven text grows the block instead of staying trapped inside the previous fixed-height native text view.
- Regression coverage: `testPastedMultilineTextExpandsNativeTextViewHeight` plus the focused `NativeTextBlockEditorTests` run.

## Recent Task Toggle Accessibility Polish

- The task block completion button now exposes semantic accessibility labels instead of SF Symbol names.
- The same button exposes `Incomplete` and `Completed` accessibility values as the task state changes.
- Regression coverage: `testTaskBlockToggleExposesAndUpdatesCompletionState`.

## Recent Divider Block Type Menu Polish

- The visible block type menu now exposes `Divider`, matching the divider support that already exists in Markdown shortcuts, import/export, persistence, and rendering.
- Converting an editable text block to `Divider` removes the native text view and renders the existing divider row while the block drag handle reports the updated type.
- Regression coverage: `testBlockTypeMenuCanConvertTextBlockToDivider`.

## Recent Callout Block UI Polish

- Converting an editable text block to `Callout` now renders visible callout chrome with a semantic callout container.
- The callout row keeps the native text editor addressable and editable, so writing-flow shortcuts and text input still use the same editor path.
- Regression coverage: `testCalloutBlockTypeRendersCalloutChromeAndKeepsTextEditable`.

## Recent Task Block UI Polish

- Converting an editable text block to `Task` now renders visible task-block chrome with the completion control embedded in the row.
- The task block keeps the native text editor addressable and editable, preserves the existing task-toggle identifier, and reports completed/incomplete state on the block chrome.
- Regression coverage: `testTaskBlockTypeRendersTaskChromeAndKeepsTextEditable`.

## Recent Table Block UI Polish

- Converting an editable text block to `Table` now renders visible table-block chrome with a semantic container and live row/column dimensions.
- The table block keeps structured cells editable, keeps the existing row/column controls addressable, and updates block-level dimensions after table shape changes.
- Regression coverage: `testTableBlockTypeRendersTableChromeAndKeepsCellsEditable`.

## Recent Code Block UI Polish

- Converting an editable text block to `Code` now renders visible code-block chrome with a semantic container.
- The code block keeps the native monospaced text editor addressable and editable, and the line-wrap control now sits inside the code-block container while preserving its existing accessibility identifier and state.
- Regression coverage: `testCodeBlockTypeRendersCodeChromeAndKeepsTextEditable`.

## Recent Toggle Block UI Polish

- Converting an editable text block to `Toggle` now renders visible toggle-block chrome with a semantic container.
- The toggle block keeps the native text editor addressable and editable, keeps the existing expansion button identifier, and reports expanded/collapsed state on the block chrome.
- Regression coverage: `testToggleBlockTypeRendersToggleChromeAndKeepsTextEditable`.

## Recent Reference Block UI Polish

- Page-reference and block-reference rows now render as clearer target cards with type labels, stable title/snippet text, and a stroked clickable surface.
- The rows expose semantic accessibility labels and action values so automation and assistive tech can distinguish page navigation from block navigation.
- Regression coverage: `testReferenceRowsExposeSemanticChrome`.

## Recent Reference Navigation UI Polish

- Clicking a page-reference row now has UI coverage proving the editor navigates to the target page and the page list exposes the selected target row state.
- Clicking a block-reference row now has UI coverage proving the editor navigates to the target page and transfers keyboard focus into the referenced block.
- Regression coverage: `testPageReferenceRowClickNavigatesToTargetPageAndMarksSelection` and `testBlockReferenceRowClickNavigatesAndFocusesTargetBlock`.

## Recent Advanced Block Accessibility Polish

- Toggle expansion and code line-wrap controls now expose semantic accessibility labels instead of SF Symbol names.
- Their accessibility values report `Expanded` / `Collapsed` and `Line wrap enabled` / `Line wrap disabled` as the state changes.
- Regression coverage: `testToggleBlockButtonExposesAndUpdatesExpansionState` and `testCodeBlockWrapButtonExposesAndUpdatesLineWrapState`.

## Recent Table Control Accessibility Polish

- Table add/remove row/column controls now expose semantic accessibility labels instead of relying on SF Symbol names.
- The controls report current table dimensions through accessibility values as rows and columns are added or removed.
- The table editor no longer duplicates the outer block-row accessibility identifier, so its child controls remain individually addressable.
- Regression coverage: `testTableControlsExposeSemanticLabelsAndDimensions`.

## Recent Block Action Accessibility Polish

- Per-block drag/type/move/indent/delete controls now expose semantic accessibility labels instead of relying on SF Symbol names.
- The drag handle and type menu expose the current block type through accessibility values.
- Move and nesting controls report `Available` / `Unavailable` values so disabled actions have an inspectable state.
- Regression coverage: `testBlockActionControlsExposeSemanticLabelsAndAvailability`.

## Recent Notebook Navigation Accessibility Polish

- Notebook move, indent, outdent, child-Notebook, and page-creation controls now expose semantic accessibility labels instead of relying on SF Symbol names.
- Notebook action controls report `Available` / `Unavailable` values so disabled navigation actions have an inspectable state.
- Regression coverage: `testNotebookActionControlsExposeSemanticLabelsAndAvailability`.

## Recent Outline Panel UI Polish

- Outline rows now remain individually addressable inside the Outline panel accessibility container.
- Each Outline row exposes a semantic `Outline heading ...` label and `Level ...` value instead of relying only on visible row text.
- macOS UI automation imports a Markdown heading, verifies the Outline row semantics, clicks it, and confirms keyboard focus moves to the corresponding native heading text view.
- Regression coverage: `testOutlinePanelExposesHeadingLevelAndFocusesHeading`.

## Recent Multi-Level Heading Outline Fix

- `BlockType` now includes second- and third-level heading blocks alongside the existing first-level heading block.
- Markdown shortcuts, import, and export map `#`, `##`, and `###` to H1/H2/H3 blocks without falling back to paragraphs.
- The selected-page Outline includes H1/H2/H3 items with their real heading levels, and the desktop Outline UI verifies Level 1/2/3 rows from imported Markdown.
- Native AppKit/UIKit text wrappers and the block type menu expose distinct Heading 1/2/3 editing affordances.
- Regression coverage: `testShortcutTransformsCoreMarkdownMarkers`, `testImportMarkdownIntoBlockDrafts`, `testExportBlocksToMarkdown`, `testSelectedPageOutlineTracksHeadingBlocksAndSelectionFocus`, and `testOutlinePanelExposesHeadingLevelAndFocusesHeading`.

## Recent Editing Fix

- `WorkspaceViewModel.focusEditorCanvas` now makes a blank canvas tap focus the last editable block, or creates and focuses a new paragraph when the page has no editable blocks.
- `EditorShellView` exposes a blank editable canvas region below the current block list, so the page body is not a dead white area.
- macOS `EditorNSTextView` accepts first mouse clicks from an inactive window and logs `editor_native_text_mouse_focus` with the first-responder result.
- Regression coverage: `testFocusEditorCanvasRequestsExistingEditableBlock`, `testFocusEditorCanvasCreatesParagraphWhenPageHasNoEditableBlocks`, and `testNativeTextBlockEditorAcceptsInactiveWindowFirstMouseOnMac`.

## Recent Sync Fix

- `RemoteNotificationSyncHandler` maps silent-push work to `.newData`, `.noData`, or `.failed` after ensuring the CloudKit subscription, uploading pending local changes, and fetching remote changes.
- iOS `EditorIOSAppDelegate` now handles `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` and returns the mapped `UIBackgroundFetchResult`.
- Regression coverage: `testRemoteNotificationSyncHandlerReturnsNewDataWhenRemoteChangesApply`, `testRemoteNotificationSyncHandlerReturnsNoDataWithoutSyncEngine`, and `testRemoteNotificationSyncHandlerReturnsFailedWhenSyncThrows`.

## Recent Drag Reorder Fix

- `BlockDragReorderResolver` defines row drop and end-region drop target indexes without changing the existing repository reorder contract.
- The block handle is now draggable, block rows accept drops before their destination row, and the canvas edit region accepts drops to the end of the page.
- Regression coverage: `testBlockDragReorderResolverMovesBeforeDestinationBlock` and `testBlockDragReorderResolverMovesToEndRegion`.

## Recent Table Editing Fix

- `MarkdownTableDocument` parses Markdown table text into editable rows without the separator line, normalizes column counts, and writes cell edits back to Markdown table syntax.
- `StructuredTableBlockEditor` renders `BlockType.table` as a grid of cell `TextField`s instead of a raw Markdown text block, with add/remove row and add/remove column controls.
- Regression coverage: `testMarkdownTableDocumentParsesRowsWithoutSeparator`, `testMarkdownTableDocumentUpdatesCellAndExportsMarkdownTable`, `testMarkdownTableDocumentAppendsRowAndColumn`, and `testMarkdownTableDocumentRemovesRowAndColumnButKeepsMinimumCell`.

## Recent Conflict Diff Fix

- `ConflictTextDiff` produces line-level `unchanged`, `removed`, and `added` segments while preserving common leading and trailing context.
- `ConflictPanel` renders those segments with compact red/green highlighting before the manual merge editor.
- Regression coverage: `testConflictTextDiffHighlightsChangedMiddleLine` and `testConflictTextDiffHighlightsAddedTrailingLine`.

## Recent Conflict Batch Fix

- `ConflictRepository.acceptRemoteVersions(pageID:)` accepts all remote conflict versions for a page while skipping duplicate block IDs safely.
- `WorkspaceViewModel.acceptAllRemoteConflictsForSelectedPage` refreshes the page and clears all accepted conflicts through the existing sync cleanup path.
- `ConflictPanel` exposes a `Use All Remote` batch action.
- Regression coverage: `testAcceptAllRemoteConflictsForSelectedPageRefreshesAllBlocks`.

## Recent Conflict Local Acceptance Fix

- `ConflictRepository.acceptLocalVersion` clears a remote conflict while preserving the local block text and ensuring the local block update remains queued for sync.
- `WorkspaceViewModel.acceptAllLocalConflictsForSelectedPage` batch-accepts current-page local versions and refocuses the first resolved block.
- `ConflictPanel` exposes per-conflict `Use Local` and batch `Use All Local` actions.
- Regression coverage: `testAcceptLocalConflictKeepsLocalTextAndPendingUpdate` and `testAcceptAllLocalConflictsForSelectedPageKeepsLocalBlocks`.

## Recent Manual Merge Batch Fix

- `ConflictRepository.resolveManualConflicts` applies current-page manual merge drafts through the existing single-conflict merge path.
- `WorkspaceViewModel.resolveAllManualConflictsForSelectedPage` reloads local state, clears resolved conflict rows, and requests focus for the first resolved block.
- `ConflictPanel` now keeps merge drafts at the panel level and exposes an `Apply All Merged` batch action.
- Regression coverage: `testResolveAllManualConflictsForSelectedPageAppliesMergedTexts`.

## Recent Text Undo Fix

- `WorkspaceViewModel` records the previous block type/text before a text edit or Markdown shortcut transform.
- Sequential same-block same-type text edits now coalesce into one undo entry, preserving the original pre-edit text while keeping Markdown shortcut type changes separately undoable.
- `undoLastTextEdit` writes the previous block state through the repository, refreshes derived state, updates undo availability, and requests focus for the restored block.
- `EditorCanvasView` exposes an `Undo text edit` toolbar command with accessibility identifier `editor.undo-text-edit`.
- Regression coverage: `testUndoLastTextEditRestoresPreviousBlockTextAndKeepsFocus`, `testUndoLastTextEditCoalescesSequentialPlainTextEditsForSameBlock`, and `testUndoLastTextEditRestoresBlockTypeAfterMarkdownShortcut`.

## Recent Selection And Composition Fix

- `EditorSession` now tracks `EditorTextSelection` with block id, caret location, and selection length.
- `EditorSession` tracks the currently composing marked-text block and clears it when composition or editing ends.
- Repeated identical selection updates no longer publish duplicate object changes.
- macOS `NSTextViewDelegate` and iOS `UITextViewDelegate` update session selection and composition state on edit begin, text change, and selection change.
- Regression coverage: `testSelectionUpdatesTrackBlockAndCaretRange`, `testRepeatedSelectionUpdateDoesNotRepublishUnchangedSelection`, and `testCompositionStateTracksCurrentBlockAndClearsWhenFinished`.

## Recent Native Text Runtime Fix

- `NativeTextModelUpdateGuard` suppresses AppKit/UIKit text delegate forwarding while SwiftUI applies model text into native text views.
- `EditorShellView` defers the initial workspace load by one task yield so the first snapshot publication does not run inside the initial view update.
- Fresh macOS launch log check for PID `97933` returned no `Publishing changes`, `textkit2_unavailable`, `CKException`, or `app_startup_failed` entries.
- Regression coverage: `testNativeTextModelUpdateGuardSuppressesProgrammaticTextChangeForwarding`.

## Recent Render Instrumentation Fix

- `EditorCanvasView` uses a lazy block stack for the page body.
- `EditorCanvasRenderMetrics` summarizes page, block, attachment, backlink, conflict, and large-page state.
- `EditorCanvasView` logs `editor_canvas_rendered` on appear and render-metric changes.
- Regression coverage: `testEditorCanvasRenderMetricsSummarizeRenderWorkload`.

## Recent Store Transaction Timing Fix

- `SQLiteDatabase.withImmediateTransaction` wraps `BEGIN IMMEDIATE TRANSACTION`, `COMMIT`, and rollback handling in one path.
- The wrapper logs `transaction_committed` and `transaction_rolled_back` with a stable label and elapsed duration in milliseconds through the `store.transaction` OSLog category.
- Page, attachment GC, conflict resolution, and remote-deletion merge write paths now use the wrapper instead of local hand-written transaction blocks.
- Regression cases added: `testImmediateTransactionCommitsOperation` and `testImmediateTransactionRollsBackFailedOperation`.
- Verification note: these new regression cases have not been executed yet because automated validation is currently paused.

## Recent Incremental Search Index Fix

- `SearchRepository.updateBlockIndex(blockID:)` deletes and recreates only the changed block's FTS row inside a labeled immediate transaction.
- `WorkspaceViewModel` now uses block-level index updates for text edits, text undo, and block-type changes, while preserving full rebuilds for page-title and broader snapshot refresh paths.
- Regression case added: `testUpdateBlockIndexReplacesOnlyChangedBlockEntry`.
- Verification note: this new regression case has not been executed yet because automated validation is currently paused.

## Recent Scroll Metrics Baseline

- `EditorCanvasScrollMetricsTracker` records visible block count and peak visible block count per page.
- `EditorCanvasView` logs `editor_canvas_scroll_visible` as block rows appear and disappear in the lazy stack.
- `scripts/perf_baseline.sh` now includes the scroll-metrics regression in Release mode.
- Regression coverage: `testEditorCanvasScrollMetricsTrackVisibleBlocksAndLargePageState`.

## Recent Runtime Scroll UI Baseline

- `EDITOR_UI_TEST_LARGE_PAGE_BLOCK_COUNT` seeds isolated UI-test workspaces with a stable-id 760-block page through the local repository path.
- `EditorCanvasView` exposes `editor.canvas-scroll` so UI automation can drive the editor scroll view without raw coordinates.
- `EditorMacEditingUITests.testLargePageScrollLoadsDistantBlocks` verifies the first large-page block renders, scrolls the canvas, and verifies a distant offscreen block is realized by the lazy stack.
- Input-method guard: current source was checked as `com.apple.keylayout.US` before the focused macOS UI test, full macOS UI suite, and macOS unit test run.
- Regression coverage: `testLargePageScrollLoadsDistantBlocks`.

## Recent Runtime Scroll Capture Polish

- `EditorCanvasScrollMetricsTracker` now records the first and last visible block index, current visible index span, and peak visible index span in addition to visible block counts.
- `editor_canvas_scroll_visible` logs a reusable runtime summary with page id, block count, visible counts, visible index window, index span, peak span, and large-page state.
- `EditorCanvasView` exposes a DEBUG-only `editor.scroll-metrics-test-output` overlay probe outside the lazy stack so macOS UI automation can read scroll metrics after the visible content has moved.
- `EditorMacEditingUITests.testLargePageScrollLoadsDistantBlocks` now verifies the seeded 760-block page is marked as large and that the captured visible index window reaches at least block 80 after real scrolling.
- Regression coverage: `testEditorCanvasScrollMetricsCaptureVisibleIndexWindow`, `testEditorCanvasScrollMetricsTrackVisibleBlocksAndLargePageState`, and `testLargePageScrollLoadsDistantBlocks`.

## Recent Scroll Lifecycle Profiling Polish

- `EditorCanvasScrollMetricsTracker` now timestamps each metrics reset and visible block appear/disappear event, exposing `scroll_lifetime_ms` in the shared runtime summary.
- The same metrics now count block appearances, disappearances, and combined visible-block churn so large-page logs can distinguish a stable viewport from high lazy-stack turnover.
- The lifecycle clock remains injectable in unit tests and defaults to `DispatchTime.now().uptimeNanoseconds` in app runtime.
- Regression coverage: `testEditorCanvasScrollMetricsCaptureLifecycleChurnSummary` plus the focused scroll metrics run.

## Recent Release Performance Baseline

- `scripts/perf_baseline.sh` runs `PageRepositoryTests.testLargePageImportLoadAndSearchIndexRemainUsable` and `NativeTextBlockEditorTests.testEditorCanvasScrollMetricsTrackVisibleBlocksAndLargePageState` in Release configuration.
- The same script builds the macOS app in Release configuration so the large-page baseline is tied to an optimized app build.
- Latest local run completed the Release large-page repository baseline, Release scroll-metrics baseline, and Release macOS build baseline.

## Recent Page Reference Fix

- `BlockType.pageReference` represents a structured nested-page reference instead of relying only on inline `[[Page]]` text.
- `BlockSnapshot` carries `pageReferenceTargetPageID`, loaded from `payload_json.target_page_id`.
- `PageRepository.appendPageReferenceBlock` inserts a typed reference block, stores the target page id, queues sync, and maintains backlinks through `BacklinkRepository`.
- `WorkspaceViewModel.appendPageReferenceToCurrentPage` inserts references without moving the current page selection; `openPageReference` navigates to the target page.
- `EditorShellView` exposes an insert-page-reference menu and renders clickable page-reference rows.
- Markdown export renders page-reference blocks as `[[Title]]`.
- Regression coverage: `testAppendPageReferenceBlockCreatesTypedBlockAndBacklink`, `testAppendPageReferenceToCurrentPageKeepsSelectionAndRefreshesBacklinks`, and `testExportPageReferenceBlockAsWikiLink`.

## Recent Block Reference Fix

- `BlockType.blockReference` represents a structured reference to a specific target block.
- `BlockSnapshot` carries `blockReferenceTargetBlockID`, loaded from `payload_json.target_block_id`, while reusing `pageReferenceTargetPageID` for the owning target page.
- `PageRepository.appendBlockReferenceBlock` inserts a typed reference block, stores target page/block ids, queues sync, and maintains backlinks with `target_block_id`.
- `WorkspaceViewModel.appendBlockReferenceToCurrentPage` inserts block references without moving the source selection; `openBlockReference` navigates to the target page and requests focus for the target block.
- `EditorShellView` exposes an insert-block-reference menu and renders clickable block-reference rows.
- Markdown export renders block-reference blocks as `[[#Title]]`.
- Regression coverage: `testAppendBlockReferenceBlockCreatesTypedBlockAndBlockBacklink`, `testAppendBlockReferenceAndOpenItFocusesTargetBlock`, and `testExportBlockReferenceBlockAsWikiBlockLink`.

## Recent Reference Menu UI Automation

- `EDITOR_UI_TEST_REFERENCE_TARGETS` seeds isolated macOS UI-test workspaces with a target page titled `Reference Target` and a target paragraph block titled `Reference target block`.
- `BlockRowView` now exposes `editor.page-reference.<id>` and `editor.block-reference.<id>` on typed reference rows instead of masking them behind the generic `editor.block.<id>` identifier.
- `EditorMacEditingUITests.testReferenceMenusInsertPageAndBlockReferenceRows` opens the toolbar page-reference and block-reference menus, selects the seeded targets, and verifies typed reference rows appear.
- Regression coverage: `testReferenceMenusInsertPageAndBlockReferenceRows` plus the full `EditorMacUITests` suite.

## Recent Outline Panel Fix

- `WorkspaceViewModel.selectedPageOutline` derives the current page outline from non-empty heading blocks without adding persistence state.
- `WorkspaceViewModel.selectOutlineItem` requests focus for the selected heading block and emits the compact navigation intent for mobile.
- `EditorShellView` renders a compact `Outline` panel before backlinks/conflicts with stable row accessibility identifiers.
- Regression coverage: `testSelectedPageOutlineTracksHeadingBlocksAndSelectionFocus`.

## Recent Task Item Completion Fix

- `BlockSnapshot` now carries task completion state for task-item blocks.
- `MarkdownTransformer` imports `- [x]` / `- [X]` as completed task items, exports completed tasks back to `- [x]`, and recognizes `- [x] ` / `- [X] ` as completed task shortcuts.
- `PageRepository.updateTaskItemCompletion` stores completion in block payload JSON, queues a block sync update, and preserves the task text.
- `WorkspaceViewModel.updateTaskItemCompletion` refreshes visible task state and requests focus for the changed task block.
- `EditorShellView` renders task-item blocks with a checkbox-style toggle beside the native text editor.
- Regression coverage: `testShortcutTransformsCoreMarkdownMarkers`, `testCompletedTaskMarkdownShortcutUpdatesBlockCompletion`, `testImportMarkdownSupportsCompletedTaskItems`, `testExportCompletedTaskItemToMarkdown`, `testImportMarkdownPersistsTaskItemCompletionState`, `testUpdateTaskItemCompletionPersistsAndQueuesSyncChange`, and `testUpdateTaskItemCompletionRefreshesVisibleBlockAndKeepsFocus`.

## Recent Toggle Collapse Fix

- `BlockSnapshot` now carries toggle expansion state for toggle blocks.
- `PageRepository.updateToggleExpansion` stores expansion in block payload JSON, queues a block sync update, and preserves the toggle text.
- `WorkspaceViewModel.editorVisibleBlocks` hides descendants of collapsed toggle blocks while preserving the full page block list in `visibleBlocks`.
- `WorkspaceViewModel.toggleBlockExpansion` persists expansion state and requests focus for the toggle block.
- `EditorShellView` feeds the canvas with `editorVisibleBlocks` and renders a chevron expansion control for toggle blocks.
- Regression coverage: `testUpdateToggleExpansionPersistsAndQueuesSyncChange` and `testCollapsedToggleHidesDescendantBlocksFromEditorCanvasOnly`.

## Recent Code Block Line Wrap Fix

- `BlockSnapshot` now carries code-block line-wrap state loaded from block payload JSON, defaulting to wrapped for older payloads.
- `PageRepository.updateCodeBlockLineWrapping` stores `line_wrapping`, queues a block sync update, and preserves code text.
- `WorkspaceViewModel.updateCodeBlockLineWrapping` refreshes the visible block and requests focus for the edited code block.
- `EditorShellView` exposes a per-code-block wrap toggle, and `NativeTextBlockEditor` feeds the setting into AppKit/UIKit text-container wrapping behavior.
- Regression coverage: `testUpdateCodeBlockLineWrappingPersistsAndQueuesSyncChange`, `testUpdateCodeBlockLineWrappingRefreshesVisibleBlockAndKeepsFocus`, and `testNativeTextBlockEditorKeepsLineWrappingConfiguration`.

## Recent External Link Index Fix

- Schema version 6 adds `links.target_url` so Markdown external links can be indexed separately from page/block backlinks.
- `BacklinkRepository` extracts `[label](scheme://target)` Markdown links, stores their URL and label, and exposes `externalLinks(sourcePageID:)`.
- `ExternalLink.destinationURL` filters stored targets to valid scheme-backed URLs before UI open actions.
- `WorkspaceViewModel` refreshes selected-page external links alongside backlinks.
- `EditorShellView` renders an `External Links` panel in the editor context area and opens rows through SwiftUI `openURL`.
- Regression coverage: `testLinksTableTracksExternalTargets`, `testBlockUpdateMaintainsExternalMarkdownLinksForSourcePage`, `testExternalLinkDestinationURLRequiresScheme`, `testExternalMarkdownLinksIgnoreImagesAndLocalTargets`, and `testSelectedPageExternalLinksRefreshAfterBlockEdit`.

## Recent Inline Link Insertion Fix

- `MarkdownInlineLinkComposer` builds `[label](url)` inline Markdown links from trimmed labels and scheme-backed URLs.
- `WorkspaceViewModel.insertMarkdownLink` appends an inline Markdown link to a text block, refreshes derived external-link state, records normal text undo, and refocuses the edited block.
- `MarkdownInlineLinkInserter` replaces the current native text selection with `[label](url)` and returns the label range inside the inserted Markdown.
- `WorkspaceViewModel.insertMarkdownLink(...selection:)` updates through the same text-edit path, refreshes external links, and returns the next label selection.
- `EditorShellView` exposes an inline link insertion panel from the editor toolbar, targeting the current native text selection when available, with the old focused-block append behavior preserved as fallback.
- Regression coverage: `testMarkdownInlineLinkComposerTrimsLabelAndRequiresSchemeURL`, `testMarkdownInlineLinkInserterReplacesSelectionAndSelectsLabel`, `testMarkdownInlineLinkInserterRejectsInvalidSelectionOrURL`, `testInsertMarkdownLinkIntoTextBlockRefreshesExternalLinksAndFocus`, `testInsertMarkdownLinkAtSelectionRefreshesExternalLinksAndReturnsLabelSelection`, and `testInlineLinkPanelReplacesSelectionAndKeepsLabelSelected`.

## Recent Inline Link Panel Fix

- `EditorCanvasView` captures the inline-link target when the toolbar link button opens the panel, so clicking into the label/URL fields does not lose the native text selection target.
- The link form is now a persistent inline editor panel under the toolbar rather than a transient popover, avoiding AppKit/SwiftUI popover dismissal while filling fields.
- Regression coverage: `testInlineLinkPanelReplacesSelectionAndKeepsLabelSelected`.

## Recent Inline Formatting Fix

- `MarkdownInlineFormatter` applies bold, italic, and inline-code Markdown wrappers using the same UTF-16 `NSRange` coordinates produced by native AppKit/UIKit text views.
- `MarkdownInlineFormatter.applyResult` returns the next selected range inside the inserted markers, including placeholder selection for empty ranges.
- `WorkspaceViewModel.applyMarkdownInlineFormat` updates editable blocks through the existing text-edit path, preserving undo behavior and returning the next focus selection.
- `EditorShellView` exposes toolbar bold, italic, and code buttons that target the current native text selection, or insert a small placeholder at the focused editable block when there is no selection; the resulting `BlockFocusRequest` carries the post-format selection.
- `NativeTextBlockEditor` validates requested focus selections and applies them on AppKit/UIKit focus, falling back to the text end for stale or out-of-range selections.
- Regression coverage: `testMarkdownInlineFormatterWrapsSelectionUsingTextViewRange`, `testMarkdownInlineFormatterReturnsSelectionInsideInsertedMarkers`, `testMarkdownInlineFormatterInsertsPlaceholderAtEmptySelection`, `testMarkdownInlineFormatterSelectsPlaceholderAfterEmptySelection`, `testMarkdownInlineFormatterRejectsInvalidSelectionRange`, `testApplyMarkdownInlineFormatWrapsSelectionAndQueuesFocus`, `testApplyMarkdownInlineItalicFormatWrapsSelectionAndQueuesFocus`, `testApplyMarkdownInlineFormatRejectsMismatchedSelectionBlock`, `testNativeTextFocusSelectionUsesValidRequestedSelectionRange`, and `testNativeTextFocusSelectionFallsBackToTextEndForInvalidSelection`.

## Recent Inline Markdown Styling Fix

- `MarkdownInlineStyleScanner` finds bold, italic, inline-code, and Markdown link-label UTF-16 ranges while ignoring markers inside code spans.
- `NativeTextBlockEditor` applies temporary AppKit/UIKit text-storage attributes for bold/italic/code/link-label styling in supported editable blocks without changing the raw Markdown text.
- Code blocks and tables opt out of inline Markdown styling so literal Markdown remains unstyled there.
- Regression coverage: `testMarkdownInlineStyleScannerFindsBoldCodeAndLinkLabelRanges`, `testMarkdownInlineStyleScannerFindsItalicRange`, `testMarkdownInlineStyleScannerDoesNotStyleMarkersInsideCodeSpan`, `testNativeTextBlockEditorKeepsBlockIdentityAndInitialText`, `testNativeTextBlockEditorKeepsLineWrappingConfiguration`, and `testNativeTextModelUpdateGuardSuppressesProgrammaticTextChangeForwarding`.

## Recent Toolbar Focus Selection Fix

- `EditorCanvasView.schedulePendingFocusIfNeeded` now preserves an existing same-block `BlockFocusRequest` that carries a toolbar-created selection, instead of replacing it with a block-end focus request from `WorkspaceViewModel.pendingFocusBlockID`.
- This keeps the inserted inline-format placeholder selected after toolbar actions, so immediate typing replaces the placeholder inside the Markdown markers.
- Regression coverage: `testBoldToolbarInsertsPlaceholderAndKeepsTypingInEditor`, `testItalicToolbarInsertsPlaceholderAndKeepsTypingInEditor`, and `testCodeToolbarInsertsPlaceholderAndKeepsTypingInEditor` plus the full `EditorMacUITests` editing flow.

## Recent macOS Editing UI Fix

- `EditorMacAppDelegate` now falls back to the SwiftUI File > New Window menu item when the app is running with no visible keyable window, fixing a launch state where UI tests saw only the menu bar and no editor window.
- `EditorMacEditingUITests` now uses a per-run directory under the tested app sandbox container instead of the UI test runner container.
- UI test setup and teardown terminate residual `com.liangzhang.editor.mac` processes before and after each test, including a second wait after force termination, so a manually launched or background app does not mask or block the test-owned launch.
- Text block rows expose the row as `editor.block.<id>` while preserving the internal native text view as `editor.text.<id>`.
- `WorkspaceViewModel.addParagraphBlockToCurrentPage` now queues focus for the inserted toolbar `+` paragraph block.
- `testClickingBlockRowFocusesEditorForTyping` now waits for native text keyboard focus before sending global text input, turning row-focus regressions into an explicit focus assertion instead of a low-signal event synthesis timeout.
- Regression coverage: `testWelcomeBlockAcceptsTypedText`, `testClickingBlockRowFocusesEditorForTyping`, `testReturnCreatesNextBlockAndKeepsTypingInEditor`, `testAddParagraphBlockForUIQueuesFocusOnInsertedBlock`, `testAddButtonCreatesNextBlockAndKeepsTypingInEditor`, `testBoldToolbarInsertsPlaceholderAndKeepsTypingInEditor`, `testItalicToolbarInsertsPlaceholderAndKeepsTypingInEditor`, `testCodeToolbarInsertsPlaceholderAndKeepsTypingInEditor`, `testInlineLinkPanelReplacesSelectionAndKeepsLabelSelected`, and `testLargePageScrollLoadsDistantBlocks`.

## Recent iOS UI Automation Attempt

- `EditorIOSUITests` now exists as a generated iOS UI test target and scheme.
- `EditorIOSEditingUITests.testIPhoneWelcomeBlockAcceptsTypedText` drives the compact route into the welcome page, taps the native iOS text view, and types text through XCTest.
- Compact workspace and page rows now expose stable accessibility identifiers for the UI path.
- Compile coverage: `xcodebuild -quiet build-for-testing -project Editor.xcodeproj -scheme EditorIOSUITests -destination 'generic/platform=iOS Simulator'`.
- Runtime blocker: local iPhone 17 Simulators repeatedly remain non-terminal in `xcrun simctl bootstatus`, waiting on `com.apple.locationd.migrator (CoreLocationMigrator.migrator)`, and XCTest never reaches `XCTRunner`.
- Latest retry on existing `iPhone 17 Pro` booted but the UI test launch hung until interruption, then Xcode reported `NSMachErrorDomain Code=-308 (ipc/mig server died)` while launching `EditorIOSUITests.xctrunner`.
- A freshly created `EditorUITest-iPhone17` simulator reproduced the system blocker: bootstatus remained non-terminal for more than two minutes and was still waiting on `CoreLocationMigrator.migrator`; the temporary simulator was shut down and deleted after evidence capture.

## Recent Nested Notebook Polish

- `PageRepository.loadWorkspaceSnapshot` now returns Notebook groups in depth-first order so child Notebooks render directly under their parent instead of after all root Notebooks.
- `WorkspaceViewModel.createNotebookInSelectedWorkspace` accepts an optional parent Notebook and keeps the new child Notebook selected after reload.
- Desktop and compact Notebook headers expose a child-Notebook creation button with a stable accessibility identifier.
- Regression coverage: `testLoadWorkspaceSnapshotOrdersNestedNotebooksDepthFirst` and `testCreateChildNotebookRefreshesSnapshotAndKeepsHierarchyOrder`.

## Recent Archive Selection Polish

- Page-list archive actions now keep the currently open page selected when archiving a different background page.
- Archiving the currently selected page still falls back to the remaining visible page.
- Regression coverage: `testArchivePageForUIKeepsCurrentSelectionWhenArchivingBackgroundPage` plus the existing selected-archive, restore, and permanent-delete archive regressions.

## Recent Archive Undo Polish

- `WorkspaceViewModel` now records archive undo snapshots with the archived page and pre-archive selection.
- `undoLastPageArchive` restores the most recently archived page; background-page undo keeps the current editor selection, while selected-page undo returns to the restored page.
- Desktop and compact page lists expose an `Undo Archive` action with accessibility identifier `editor.undo-page-archive`.
- Regression coverage: `testUndoLastPageArchiveRestoresBackgroundPageWithoutChangingCurrentSelection` and `testUndoLastPageArchiveRestoresSelectedArchivedPageAndSelection`.

## Recent Keyboard Indentation Polish

- `BlockKeyboardShortcutResolver` now maps Tab to block indent and Shift-Tab to block outdent while ignoring modified Tab combinations.
- macOS `NSTextView` and iOS `UITextView` route those hardware-keyboard commands into the existing block nesting actions.
- Regression coverage: `testBlockKeyboardShortcutResolverHandlesTabIndentAndShiftTabOutdent` plus the existing native-editor shortcut resolver tests.

## Recent UI Automation Loop Speedup

- `scripts/mac_ui_test.sh` provides a fast macOS UI verification loop with a stable arm64 destination and cached `build-for-testing` output under `EDITOR_UI_TEST_DERIVED_DATA` or the system temp directory.
- The default `run` action rebuilds only when Swift/project inputs are newer than the cached `.xctestrun`; `rerun` forces `test-without-building` for the tightest repeat loop while tuning UI behavior.
- Timing evidence on `testWelcomeBlockAcceptsTypedText`: ordinary `xcodebuild test` baseline `real 11.25s`; cached script reruns `real 8.20s` to `8.94s`; default cache build `real 27.46s` once before repeated runs.
- Recommended UI loop: `scripts/mac_ui_test.sh build` after source edits, then `scripts/mac_ui_test.sh rerun <testName>` while iterating on the exact UI scenario.

## Recent Block-First Information Architecture

- Schema/model foundations now include nested tags, page-tag assignments, active diary entries, and page origin while keeping existing Notebook/page/archive/favorite data loadable.
- All Documents replaces the visible Notebook-first page list in the middle column and uses `updated_at DESC` ordering for normal document pages.
- Launching macOS starts in the diary collection with a blank native editor surface for immediate typing, instead of requiring the user to choose a page first.
- Diary text persists locally and is indexed for search, while remaining excluded from All Documents and tag-filtered document lists.
- Selected diary text can be promoted into a normal page through `Cmd+]` or the visible Promote to Page action; the promoted page then participates in tags, favorite, search, and Markdown export.
- Tag support covers creation, nesting, assignment to pages, tag-filtered document lists, sidebar tag selection, and compact page-row tag chips.
- Favorites remain visible and editable from the block-first shell, including the sidebar shortcut and row-level favorite state.
- Regression coverage includes schema/model tests, tag repository tests, diary repository tests, search repository tests, All Documents ordering, diary-first view-model launch, diary promotion, tag assignment/filtering, launch-to-type UI automation, All Documents ordering UI automation, `Cmd+]` promotion UI automation, favorite sidebar/row UI automation, tag-chip UI automation, and Markdown export UI automation.

## Recent Final Regression Sweep

- Focused block-first unit suite passed on macOS arm64: `SchemaMigratorTests`, `PageRepositoryTests`, `TagRepositoryTests`, `DiaryRepositoryTests`, `SearchRepositoryTests`, `WorkspaceViewModelTests`, and `NativeTextBlockEditorTests`; `xcodebuild` reported testing completed in 8.610s.
- `scripts/mac_ui_test.sh build` completed successfully for `EditorMacUITests`.
- The focused macOS UI rerun did not reach any business test case because local macOS authorization blocked UIAutomation setup. Four attempts failed at runner initialization with `Timed out while enabling automation mode`; `xcresulttool` summaries reported 0 passed tests and 1 runner initialization failure.
- System evidence for the UI blocker: `osascript` reported `System Events` UI elements disabled, `DevToolsSecurity -status` reported Developer mode disabled, `/var/db/com.apple.dt.automationmode/automation-enabled` did not exist, and unified logs showed `Writer daemon requires authentication to enable automation mode` before the runner timeout.
- App build gates passed: `EditorMac` built for `platform=macOS,arch=arm64`, and `EditorIOS` built for `generic/platform=iOS Simulator`.

## Recent macOS UI Automation Preflight

- `scripts/mac_ui_test.sh` now checks `DevToolsSecurity -status` before `test` and `rerun` actions so missing local UI Automation authorization fails fast instead of waiting for an 80s runner initialization timeout.
- `scripts/mac_ui_test.sh doctor` reports the macOS UI test environment without launching xcodebuild, including project, scheme, destination, DerivedData, cached `.xctestrun`, Developer Tools status, System Events UI-elements status, `_developer` membership, `system.privilege.taskport` group/authentication state, the Automation Mode state file, and `testmanagerd` PIDs.
- `scripts/mac_ui_test.sh authorize` provides a single local approval entrypoint around `/usr/sbin/DevToolsSecurity -enable`, then reruns `doctor`; `EDITOR_UI_TEST_AUTHORIZE_DRY_RUN=1` prints the command without opening the system authorization prompt, and `EDITOR_UI_TEST_AUTHORIZE_TIMEOUT_SECONDS` bounds how long the script waits for local approval before exiting 65 with a recovery hint.
- The preflight prints the required local authorization command, `/usr/sbin/DevToolsSecurity -enable`, and can be bypassed with `EDITOR_UI_TEST_SKIP_AUTOMATION_PREFLIGHT=1` when intentionally letting `xcodebuild` try to prompt.
- Verification: `bash -n scripts/mac_ui_test.sh` passed, unauthorized `scripts/mac_ui_test.sh doctor` exited 65 with actionable diagnostics and no xcodebuild launch, unauthorized `scripts/mac_ui_test.sh rerun testLaunchStartsInBlankDiaryEditorForFastTyping` exited 65 with the preflight message, `scripts/mac_ui_test.sh help` shows the `doctor`, `authorize`, bypass, dry-run, and authorize-timeout entries, `EDITOR_UI_TEST_AUTHORIZE_DRY_RUN=1 scripts/mac_ui_test.sh authorize` prints the approval command without executing it, `EDITOR_UI_TEST_AUTHORIZE_TIMEOUT_SECONDS=1 scripts/mac_ui_test.sh authorize` exits 65 with the built-in local-approval timeout message, `EDITOR_UI_TEST_SKIP_AUTOMATION_PREFLIGHT=1` bypassed the preflight and entered the xcodebuild path until an external 3s timeout, and `scripts/mac_ui_test.sh build` still passes. Latest `doctor` output shows `liangzhang` is already in `_developer`, `system.privilege.taskport` is scoped to `_developer`, and `taskport requires authentication: true`.
- Latest authorization attempt: bounded `timeout 20s /usr/sbin/DevToolsSecurity -enable` did not complete; `scripts/mac_ui_test.sh doctor` still reports Developer mode disabled, System Events UI elements disabled, and the Automation Mode state file missing.

## Recent Manual Block-First UI Observation

- Because macOS UIAutomation remains blocked by local authentication, the focused XCUITest suite still cannot enter business test cases; this manual pass is supplemental evidence and does not replace the required `scripts/mac_ui_test.sh rerun ...` pass.
- Launching the built Debug `EditorMac.app` with an app-container `EDITOR_APP_SUPPORT_DIR` showed `Diary` selected in the rail, exposed `editor.diary.text`, and accepted typed text with the accessibility value `Captured immediately`.
- Selecting `Welcome` from All Documents exposed the page title `Welcome`, block text `Start writing in blocks.`, and row value `Not favorite, No tags`.
- Clicking the page-row star changed the row value to `Favorite` and added a `Welcome` entry under Favorites.
- Launching with `EDITOR_UI_TEST_MARKDOWN_EXPORT_CAPTURE=1`, selecting `Welcome`, and clicking `editor.export-markdown` produced `editor.markdown-export-test-output` containing `Start writing in blocks.`.
- Typing `Promote this text` in the diary, selecting it with `Command-A`, and pressing `Command-]` created and selected a normal page titled `Promote this text`, with the same text in the first editor block.

## Recent Attachment Preview Scheduling

- `AttachmentRepository.importAttachment` now accepts a thumbnail policy, keeping existing immediate thumbnail generation as the default while allowing UI-facing imports to persist the attachment and block before preview generation runs.
- `AttachmentRepository.generateMissingThumbnail` generates and persists a missing image/video thumbnail later, returning existing thumbnails without regenerating them and leaving generic files without previews.
- `AttachmentPreviewState` now distinguishes generated thumbnails from pending image/video previews and unavailable generic files; deferred image/video imports no longer fall back to loading the original local file as a preview.
- `AttachmentBlockRow` shows a compact pending preview affordance and exposes `Image, generating preview` / `Video, generating preview` through the row state until background thumbnail generation refreshes the snapshot.
- `AttachmentThumbnailScheduling` gives UI imports an injectable background thumbnail path; the default `DispatchAttachmentThumbnailScheduler` runs generation on a utility queue and returns completion on the main actor.
- `WorkspaceViewModel.importAttachmentForCurrentPage` uses the deferred thumbnail policy so UI imports can refresh visible blocks and attachment metadata without waiting on image/video preview work, then schedules missing preview generation and reloads the snapshot when the thumbnail is ready.
- Regression coverage: `testAttachmentPreviewStateShowsPendingForMediaWithoutThumbnail`, `testImportImageCanDeferThumbnailAndGenerateItLater`, `testUIAttachmentImportDefersThumbnailAndCanGeneratePreviewLater`, `testUIAttachmentImportSchedulesBackgroundThumbnailGeneration`, plus the focused `AttachmentRepositoryTests`, `WorkspaceViewModelTests`, `SearchRepositoryTests`, and `SyncRepositoryTests` attachment run reporting 1.798s. Latest `scripts/block_first_final_regression.sh non-ui` also passed with focused unit tests reporting 8.188s, then `EditorMac` build, `EditorIOS` build, and `git diff --check`.

## Recent Block-First Final Regression Runner

- `scripts/block_first_final_regression.sh` now wraps the Task 10 final sweep into reusable actions: `non-ui`, `units`, `ui`, `builds`, `doctor`, `diff-check`, and `all`.
- The `ui` action runs `scripts/mac_ui_test.sh doctor` before `build`/`rerun`, so an unauthorized Mac fails fast with the UIAutomation diagnostic instead of entering the XCUITest runner timeout.
- The `non-ui` action runs the focused unit suite, macOS/iOS app builds, and `git diff --check`, allowing the non-UI gates to be refreshed while UIAutomation is still blocked by local authentication.
- The `all` action runs those non-UI gates first, then runs the focused macOS UI suite last, so a locally unauthorized Mac still leaves fresh unit/build/diff evidence before stopping at the UIAutomation doctor.
- The `authorize` action delegates to `scripts/mac_ui_test.sh authorize` so the final regression runner also has a single recovery command before rerunning `ui` or `all`.
- Verification: `bash -n scripts/block_first_final_regression.sh`, `help`, and `diff-check` passed; `ui` exited 65 at the expected local authorization doctor; `units` passed with xcodebuild reporting 9.035s; `builds` passed for both `EditorMac` macOS arm64 and `EditorIOS` generic iOS Simulator; `non-ui` passed end-to-end with focused unit tests reporting 8.654s, then `EditorMac` build, `EditorIOS` build, and `git diff --check`; latest unauthorized `all` run completed the focused unit suite with xcodebuild reporting 8.026s, then `EditorMac` build, `EditorIOS` build, and `git diff --check` before exiting 65 at the expected UIAutomation doctor; `EDITOR_UI_TEST_AUTHORIZE_DRY_RUN=1 scripts/block_first_final_regression.sh authorize` prints the local approval command without executing it; `EDITOR_UI_TEST_AUTHORIZE_TIMEOUT_SECONDS=1 scripts/block_first_final_regression.sh authorize` delegates the bounded wait and exits 65 with the local-approval timeout message; latest `non-ui` after adding bounded `authorize` passed with focused unit tests reporting 8.433s, then `EditorMac` build, `EditorIOS` build, and `git diff --check`.

## Next Implementation Slice

The block-first UI/UX path in `docs/superpowers/specs/2026-05-16-block-first-information-architecture-design.md` has landed through `docs/superpowers/plans/2026-05-16-block-first-information-architecture.md`. The next concrete gaps should stay in this order:

1. Enable UI Automation on this Mac with local authentication through `scripts/block_first_final_regression.sh authorize`, then run `scripts/block_first_final_regression.sh ui` or `scripts/block_first_final_regression.sh all` to finish the focused macOS UI suite for launch-to-diary typing, All Documents ordering, diary promotion, favorite state, and Markdown export.
2. Use any UI failure evidence to make targeted fixes without broad refactors.
3. Resume deeper performance optimization only after the final block-first UI regression pass is green.
