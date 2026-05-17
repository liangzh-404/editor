# Craft-Like Daily Page Block Editor Realignment

Date: 2026-05-17
Status: Design for user review before implementation

## Purpose

This document is the execution source of truth for the next editor UX slice. It supersedes the 2026-05-16 block-first information architecture plan for Diary, `Cmd+]`, page hierarchy, and toolbar/block UX.

The goal is a Chinese, Craft-like native editor where every writing surface is a page made of blocks. Diary is not a separate plain-text lane. Diary creates one normal page per day, with a diary-derived name, and that page otherwise behaves like every other page: it appears in All Documents, supports tags, favorites, archive, search, sync, and can contain child pages.

## Observed Craft Behaviors

Observed live in Craft on 2026-05-17:

- The document body is a sequence of editable block rows, not one large text area.
- The default canvas is visually quiet: title, blocks, whitespace, and low-emphasis contextual controls.
- No permanent formatting toolbar dominates the page body. Formatting and insertion live in menu commands, keyboard shortcuts, slash commands, and contextual block controls.
- Markdown-style input transforms blocks immediately:
  - `# ` becomes a heading block.
  - `- ` becomes an unordered list block.
  - `1. ` becomes an ordered list block and Return continues numbering.
  - `- [ ]` becomes a task block.
- `Tab` / `Shift+Tab` change block nesting level in-place.
- `Cmd+Option+Up/Down` moves the selected block while preserving row selection.
- `Cmd+]` turns the current block into a page and opens that page.
- `Cmd+[` returns to the previous/parent page.
- Returning to the parent shows the created page as a block in the original page.
- The slash command surface is categorized around block types and actions, including text styles, lists, actions, decoration, color, indent, and alignment.

## Product Contract

### Language

- All user-visible product copy should be Chinese by default.
- English may remain only for system-owned macOS menu labels that are not app-controlled, developer-only identifiers, or imported user content.
- Required visible names include `日记`, `全部文档`, `收藏`, `标签`, `搜索`, `归档`, `未命名`, `按 "/" 快速操作`, `变成...`, `页面`.

### Page Model

- `pages` remains the durable document table.
- Every page appears in `全部文档` unless archived.
- Pages can have tags, favorite state, search results, backlinks, attachments, sync state, and Markdown import/export.
- A page can also be displayed as a child page inside another page through a page-reference block and a parent-child relation.
- Child pages are not hidden from the global document list.
- Page references and child-page relations are related but distinct:
  - A page reference block points at a page.
  - A child-page relation says that page should appear as a structured child of the current page.
  - The first implementation creates both when converting a text block to a page.

### Diary Model

- Selecting `日记` opens today's daily diary page.
- If today's diary page does not exist, the app creates it on demand.
- A daily diary page is a normal page plus diary metadata.
- Daily diary pages appear in `全部文档`, search, tags, favorites, archive, and sync like normal pages.
- The diary page title is generated from the user's local date and weekday by default, for example `2026年5月16日 星期六`.
- Creating tomorrow's diary opens or creates a separate page with that date's title.
- The old `diary_entries` plain-text model is compatibility/migration input only, not the target editing model.

Default implementation decisions unless changed before coding:

- Daily diary titles are system-generated with the pattern `yyyy年M月d日 EEEE`, using Chinese weekday names, and are not user-renamed in the first slice.
- Daily diary pages are included in All Documents and tag filters.
- No automatic `日记` tag is created in the first slice; diary-ness is stored as page metadata.

### Block Model

- Every content row is a block.
- Blocks are selected, focused, moved, nested, transformed, deleted, and converted through one shared command model.
- Empty paragraph blocks show `按 "/" 快速操作`.
- Block rows show light hover/focus selection, a small drag handle, and compact contextual actions.
- Persistent vertical per-block tool stacks are not the target UI.
- A selected row should look like one calm unit; controls should not visually overpower the text.

### Page Conversion

- `Cmd+]` and `变成... > 页面` convert the current block into a child page.
- The source block text becomes the new page title.
- The original row becomes a page-reference block pointing to the new page.
- The new page opens immediately after conversion.
- The child page appears in the parent page and also in `全部文档`.
- Tags/favorite/archive/search/sync work on the new page like any other page.
- If the converted block has nested child blocks, those child blocks move into the new page in their current order.
- Empty block conversion creates `未命名页面` and opens it.

### Navigation

- `Cmd+]` converts current block to child page and opens it.
- `Cmd+[` returns to the previous page in navigation history. If the current page has a parent relation and no history, it opens the parent page.
- Clicking a page-reference block opens the target page.
- Returning to the parent preserves or restores focus near the child page reference when possible.

### Markdown Shortcuts

Typing Markdown prefixes at the start of a text block should immediately transform the block:

- `# ` -> H1
- `## ` -> H2
- `### ` -> H3
- `- `, `* `, `+ ` -> unordered list
- `1. ` and continuing numbers -> ordered list
- `- [ ] ` -> incomplete task
- `- [x] ` / `- [X] ` -> completed task
- `> ` -> quote
- Three backticks followed by a space -> code block

The transform removes the prefix, preserves the remaining typed content, and keeps the caret in the same block.

### Slash Commands

`/` is the main discovery surface for block actions.

Minimum first slice:

- Root categories: `文本样式`, `列表`, `动作`, `缩进`, `插入`.
- Text style actions: `正文`, `标题`, `中标题`, `小标题`, `说明`.
- List actions: `无序列表`, `编号列表`, `待办列表`.
- Action entries: `变成页面`, `删除`, `复制区块链接`.
- Insert entries: `页面引用`, `附件`, `分割线`.
- Keyboard support: Up/Down selection, Return execute, Escape close.

### Drag And Keyboard Movement

- Dragging a block handle reorders blocks with a visible drop indicator.
- Dragging across nested blocks should show whether the result is sibling or child placement.
- Dragging near the top/bottom of the scroll view autoscrolls.
- `Cmd+Option+Up/Down` moves the focused block up/down and preserves focus.
- Move commands and drag use the same repository order update path.

### Visual Target

- The editor should feel quiet, readable, and block-native.
- No page-level format toolbar should sit above the document body by default.
- Table and special-block controls appear only when selected/focused or through contextual menus.
- Cards, decorative effects, or complex page previews are deferred. The first page-reference row should be simple and clean.

## Current Gaps

- `DiaryEditorView` still uses `PlatformDiaryTextEditor` / `editor.diary.text`, which is the wrong target surface.
- Existing `diary_entries` storage treats diary as plain text outside normal pages.
- Existing `Cmd+]` promotion is tied to selected diary text rather than the focused block command context.
- Existing page conversion creates a normal page and replaces a text block with a page reference, but it does not yet persist an explicit child-page relation or move nested children.
- `PageSummary` and the page list do not expose diary metadata or parent-child page relation metadata.
- The block row UI has started moving toward contextual controls, but drag feedback, slash menu, and special-block control quieting remain incomplete.
- Older docs still describe Diary text as searchable but excluded from All Documents; that is no longer correct.

## Proposed Architecture

### Storage

Add two metadata tables while keeping `pages` as the document source of truth:

```sql
CREATE TABLE IF NOT EXISTS diary_pages (
    page_id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    diary_date TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE (workspace_id, diary_date),
    FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS page_parent_links (
    parent_page_id TEXT NOT NULL,
    child_page_id TEXT NOT NULL,
    source_block_id TEXT NOT NULL,
    order_key TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (parent_page_id, child_page_id),
    UNIQUE (source_block_id),
    FOREIGN KEY (parent_page_id) REFERENCES pages(id) ON DELETE CASCADE,
    FOREIGN KEY (child_page_id) REFERENCES pages(id) ON DELETE CASCADE,
    FOREIGN KEY (source_block_id) REFERENCES blocks(id) ON DELETE CASCADE
);
```

Compatibility:

- Existing `diary_entries` rows are read once and migrated into a daily diary page for the current date, or preserved for a later manual migration if content is ambiguous.
- `page_origin` can remain for historical provenance, but new child-page behavior should use `page_parent_links`.

### Command Routing

Introduce a single editor command layer:

- `EditorCommand`: enum of editor actions such as convert to page, move block, indent, outdent, change type, open slash menu, delete block, copy block link.
- `EditorCommandContext`: focused page, focused block, text selection, selected block IDs, route/source, and availability.
- `EditorCommandDispatcher`: executes commands through `WorkspaceViewModel`.

Surfaces using the dispatcher:

- macOS menu bar.
- Keyboard handlers in native text views.
- Slash command palette.
- Block contextual menu.
- Page action menu.

### Daily Diary Flow

1. User selects `日记`.
2. `WorkspaceViewModel.openTodayDiary()` asks the repository for today's diary page.
3. If missing, repository creates a normal page titled from local date, creates an initial empty paragraph block, and records `diary_pages`.
4. The page opens in the same `EditorCanvasView` as normal pages.
5. The page appears in `全部文档` and can be tagged/favorited/archived.

### Convert Block To Page Flow

1. User focuses a block.
2. User triggers `Cmd+]` or `变成... > 页面`.
3. Dispatcher validates the current block.
4. Repository creates a normal page.
5. Repository creates the child relation in `page_parent_links`.
6. Repository moves nested child blocks under the new page when applicable.
7. Source block becomes a `pageReference` block pointing at the new page.
8. Search/backlinks/sync records update in the same transaction.
9. View model opens the new page and pushes the parent page into navigation history.

## Implementation Sequence

### Phase 0: Baseline And Guardrails

Files:

- `docs/superpowers/specs/2026-05-17-craft-like-block-editor-realignment.md`
- `docs/superpowers/specs/2026-05-16-block-first-information-architecture-design.md`
- `docs/superpowers/plans/2026-05-16-block-first-information-architecture.md`
- `docs/superpowers/2026-05-12-full-feature-implementation-audit.md`

Work:

- Mark superseded Diary/plain-text assumptions in historical docs.
- Keep this document as the active source of truth.
- Capture current app UI before code work.
- Add high-signal logs around focus/block command execution if behavior is not directly observable in UI tests.

Acceptance:

- A future agent opening old docs sees a superseded notice before any wrong Diary instructions.
- No implementation begins until this spec is approved.

### Phase 1: Data Model For Daily Diary Pages And Child Pages

Files:

- `Sources/EditorCore/Store/SchemaMigrator.swift`
- `Sources/EditorCore/Models/EditorModels.swift`
- `Sources/EditorCore/Store/PageRepository.swift`
- `Sources/EditorCore/Store/DiaryRepository.swift`
- `Tests/EditorTests/SchemaMigratorTests.swift`
- `Tests/EditorTests/PageRepositoryTests.swift`
- `Tests/EditorTests/DiaryRepositoryTests.swift`

Work:

- Add `diary_pages`.
- Add `page_parent_links`.
- Extend snapshots with diary page metadata and child-page relation data.
- Replace plain-text active diary loading with today diary page loading.
- Keep old `diary_entries` tests only as compatibility/migration tests.

Acceptance:

- Migration creates `diary_pages` and `page_parent_links`.
- Creating today's diary returns a normal `PageSummary`.
- Calling create/open today twice returns the same page.
- Today's diary page appears in normal page loading and tag/favorite-capable paths.
- A child page relation can be created and reloaded.

### Phase 2: Diary Uses The Normal Block Canvas

Files:

- `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`
- `Sources/EditorCore/Features/Shell/EditorShellView.swift`
- `Sources/EditorApp/AppEnvironment.swift`
- `Tests/EditorTests/WorkspaceViewModelTests.swift`
- `Tests/EditorMacUITests/EditorMacEditingUITests.swift`

Work:

- `日记` collection opens today's diary page through the normal page editor.
- Remove the primary `editor.diary.text` surface from the default route.
- Preserve launch-to-type behavior by focusing the first empty block in today's diary page.
- Show the diary page in `全部文档`.

Acceptance:

- Fresh launch opens today's diary page as block rows.
- UI test cannot find `editor.diary.text` as the primary visible editor.
- Typing immediately enters the first diary block.
- Today's diary page row appears in `全部文档`.
- The diary page can be favorited and tagged through existing page affordances.

### Phase 3: Command Dispatcher And `Cmd+]`

Files:

- Create `Sources/EditorCore/Features/Commands/EditorCommand.swift`
- Modify `Sources/EditorCore/Features/Editing/NativeTextBlockEditor.swift`
- Modify `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`
- Modify `Sources/EditorCore/Features/Shell/EditorShellView.swift`
- Modify `Sources/EditorApp/EditorApp.swift`
- Test `Tests/EditorTests/NativeTextBlockEditorTests.swift`
- Test `Tests/EditorTests/WorkspaceViewModelTests.swift`
- Test `Tests/EditorMacUITests/EditorMacEditingUITests.swift`

Work:

- Route `Cmd+]` through focused block context, not diary text selection.
- Convert focused block to child page.
- Route `Cmd+[` to navigation history or parent page.
- Keep `变成... > 页面` and menu bar command on the same command path.

Acceptance:

- In any page, focusing a text block and pressing `Cmd+]` creates a child page.
- The new page opens immediately.
- Returning with `Cmd+[` shows the parent page and page-reference block.
- The new page appears in `全部文档`.
- The child page can receive tags and favorite state.
- Empty block `Cmd+]` creates `未命名页面`.

### Phase 4: Nested Child Block Migration On Page Conversion

Files:

- `Sources/EditorCore/Store/PageRepository.swift`
- `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`
- `Tests/EditorTests/PageRepositoryTests.swift`
- `Tests/EditorTests/WorkspaceViewModelTests.swift`

Work:

- When converting a block with nested descendants, move descendants into the new page.
- Normalize moved block parent IDs so the new page root is valid.
- Preserve order and block content.
- Keep source row as a page reference.

Acceptance:

- Parent page no longer shows moved descendants under the page-reference row.
- New child page shows the moved descendants in order.
- Backlinks/search/sync records reflect changed page ownership.

### Phase 5: Markdown Shortcut Transforms

Files:

- Create `Sources/EditorCore/Features/Editing/BlockMarkdownShortcutResolver.swift`
- Modify `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`
- Modify `Sources/EditorCore/Features/Editing/NativeTextBlockEditor.swift`
- Test `Tests/EditorTests/NativeTextBlockEditorTests.swift`
- Test `Tests/EditorTests/WorkspaceViewModelTests.swift`
- Test `Tests/EditorMacUITests/EditorMacEditingUITests.swift`

Work:

- Detect supported prefixes at block start.
- Convert the current block type and remove the trigger prefix.
- Preserve remaining content and caret position.
- Avoid firing inside code blocks or mid-line text.

Acceptance:

- `# `, `## `, `### ` create heading blocks.
- `- `, `1. `, `- [ ] `, `> `, and code fence prefixes create the expected block types.
- Ordered lists continue numbering on Return.
- Undo restores prior text/type.
- IME composition does not trigger partial transforms.

### Phase 6: Block Selection, Drag, And Keyboard Move Polish

Files:

- `Sources/EditorCore/Features/Shell/EditorShellView.swift`
- `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`
- `Sources/EditorCore/Features/Editing/NativeTextBlockEditor.swift`
- `Tests/EditorTests/WorkspaceViewModelTests.swift`
- `Tests/EditorMacUITests/EditorMacEditingUITests.swift`

Work:

- Introduce explicit selected block state.
- Unify hover, focus, selected, drag source, and drop target visuals.
- Add visible drop indicator.
- Add autoscroll while dragging.
- Keep `Cmd+Option+Up/Down` and drag on the same move path.

Acceptance:

- Dragging a block shows a clear insertion line.
- Drop persists after reload.
- Keyboard move and mouse drag produce the same final order.
- Focus remains on the moved block after keyboard move.
- Block controls stay visually quiet when the row is not active.

### Phase 7: Slash Command Palette

Files:

- Create `Sources/EditorCore/Features/Commands/SlashCommandPalette.swift`
- Modify `Sources/EditorCore/Features/Shell/EditorShellView.swift`
- Modify `Sources/EditorCore/Features/Editing/NativeTextBlockEditor.swift`
- Test `Tests/EditorTests/WorkspaceViewModelTests.swift`
- Test `Tests/EditorMacUITests/EditorMacEditingUITests.swift`

Work:

- Show slash palette when typing `/` in an empty or command-eligible block.
- Support category list, search, keyboard navigation, execution, Escape cancel.
- Route all actions through `EditorCommandDispatcher`.

Acceptance:

- Empty block shows `按 "/" 快速操作`.
- Typing `/` opens the palette.
- Selecting `标题` changes the block to heading.
- Selecting `变成页面` creates and opens a child page.
- Escape closes the palette without changing text.

### Phase 8: Visual Quieting And Chinese Cleanup

Files:

- `Sources/EditorCore/Features/Shell/EditorShellView.swift`
- `Sources/EditorCore/Features/Editing/NativeTextBlockEditor.swift`
- `Sources/EditorApp/EditorApp.swift`
- `Tests/EditorMacUITests/EditorMacEditingUITests.swift`

Work:

- Remove remaining toolbar-first visible affordances from the default canvas.
- Hide table and special-block controls until selection/focus.
- Localize app-owned menu items, help text, accessibility labels, and default seed content.
- Keep developer accessibility identifiers stable.

Acceptance:

- Default page canvas has no permanent formatting toolbar.
- Table controls appear only when table block is active.
- App-owned labels visible to users are Chinese.
- UI tests use stable identifiers, not English labels.

### Phase 9: Regression Gate

Files:

- `scripts/block_first_final_regression.sh`
- `Tests/EditorMacUITests/EditorMacEditingUITests.swift`
- `Tests/EditorTests/*`

Work:

- Update regression script to match the new Diary/page/block expectations.
- Keep nearby editing regressions: typing, Return split, Backspace/Forward Delete merge, boundary arrows, Tab nesting, inline Markdown formatting, import/export, search, tags, favorites, archive.
- Add UI smoke for today's diary page, block-to-page, markdown shortcuts, slash, drag, and Chinese labels.

Acceptance:

- Focused unit tests pass.
- Focused macOS UI tests pass.
- macOS build passes.
- iOS build or build-for-testing passes.
- Final report includes exact command output summary.

## Out Of Scope For This Slice

- Full Craft visual parity.
- Collaboration.
- Complex card rendering or decorative page previews.
- Calendar analytics.
- Automatic tag suggestions.
- Removing Markdown import/export.
- Replacing the whole sync engine.

## Open Decisions Before Implementation

These have default answers above, but should be explicitly confirmed if the defaults feel wrong:

1. Daily diary title editability: default is system-generated date title, not manually renamed in v1.
2. Child page parentage: default is one canonical parent relation created by `Cmd+]`, while ordinary page references can still point to the same page elsewhere.
3. Automatic diary tag: default is no automatic `日记` tag; diary identity is metadata, user tags remain user-controlled.

## Definition Of Done

The slice is complete only when:

- `日记` opens today's normal page, not a raw text editor.
- Today's diary page appears in `全部文档`.
- Today's diary page can be tagged, favorited, searched, archived, and synced through normal page paths.
- Focusing any editable block and pressing `Cmd+]` creates a child page, opens it, and leaves a page reference in the parent.
- The child page appears in `全部文档`.
- `Cmd+[` returns to the parent/history page.
- Markdown shortcut transforms work in live editing, not only import.
- Drag reorder has visible feedback and persists.
- Slash command palette covers the first command set.
- Default editor visuals are quiet and block-native.
- App-owned UI copy is Chinese.
- Focused unit/UI/build verification has been run and reported with evidence.
