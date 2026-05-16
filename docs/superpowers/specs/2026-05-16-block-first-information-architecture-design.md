# Block-First Information Architecture Design

Date: 2026-05-16
Status: Proposed for implementation planning

## Context

The current editor implementation grew from the original native architecture: a local-first block database, macOS three-column shell, iOS collapsed navigation, Notebook-grouped pages, search, backlinks, favorites, archive, and a rich native text editing surface.

The product direction is changing. The app should no longer feel like a folder or Notebook navigator with an editor attached. It should open into a fast, blank writing surface where text can be captured immediately, then promoted into structured documents only when the user decides it is worth keeping as a page.

This spec updates the information architecture while preserving the existing technical foundation where useful: SQLite remains the source of truth, blocks remain the editable unit, pages remain the durable document unit, search remains global, CloudKit sync remains record-based, and native text editing remains the primary interaction model.

## Decisions

- The main middle column is named **All Documents**, not Recents.
- All Documents is a document list that can be sorted by updated time, with newest updated items first by default.
- Notebooks stop being the primary organization model. They remain as a compatibility concept for existing data, while the user-facing organization moves to tags.
- Tags are the primary organization layer for documents. Tags support nested paths such as `Work/Project A`, but they are not folders and do not imply single ownership.
- A document can have multiple tags.
- Favorites remain a first-class way to pin important documents.
- The app opens into a fast diary writing surface: visually a blank white editor, immediately editable, with minimal chrome.
- Diary content is searchable, but it does not appear in All Documents and does not participate in normal tag aggregation.
- Only text can be promoted into a page in the first implementation of this new model.
- The first promotion shortcut is `Cmd+]`.
- Promoting selected diary text creates a new page. The new page then behaves like a normal document: it appears in All Documents, supports tags, can be favorited, participates in page search, and can be exported or linked.

## Goals

- Make first launch and day-to-day entry feel like opening a blank sheet and typing.
- Remove the mental overhead of deciding a Notebook, title, or document boundary before writing.
- Preserve a path from transient text to durable page without interrupting capture.
- Keep documents findable through All Documents, search, tags, and favorites.
- Keep diary writing useful as a daily capture lane without polluting the document list or tag views.
- Reuse the existing block editor, SQLite store, search, sync, favorites, and Markdown/export foundation wherever possible.

## Non-Goals

- Replacing the full local store or sync engine in one step.
- Supporting arbitrary block promotion in the first slice. Initial promotion is text-only.
- Building a multi-level folder replacement under another name.
- Making diary entries normal pages by default.
- Designing a full calendar or journaling analytics system.
- Removing existing Notebook data immediately. Compatibility stays in place while the primary UI moves away from Notebooks.

## Product Model

The app has three primary content states:

1. **Diary Text**
   - The default writing lane.
   - Opens as a blank, fast, white editor.
   - Optimized for immediate input.
   - Searchable globally.
   - Excluded from All Documents.
   - Excluded from normal tag aggregation.

2. **Document Page**
   - A durable page created intentionally.
   - Can be created directly or by promoting diary text.
   - Appears in All Documents.
   - Supports tags, favorite state, backlinks, attachments, Markdown import/export, archive, and sync.

3. **Tag View**
   - A filtered document view over pages.
   - Shows documents matching a tag path or descendant tag path.
   - Does not show diary text.

This split keeps capture cheap and document curation intentional.

## Desktop Shell

The macOS shell remains a three-region layout, but the meaning changes:

- Left rail:
  - Diary
  - All Documents
  - Favorites
  - Tags
  - Search
  - Archive

- Middle column:
  - Shows the selected collection.
  - For All Documents, lists document pages sorted by updated time by default.
  - Supports updated-time sorting first, with newest updated documents at the top.
  - For tag selection, lists documents with that tag.
  - For Favorites, lists favorite documents.
  - Diary does not use the middle list as the primary surface; selecting Diary should put focus directly into the diary editor.

- Editor column:
  - Diary selection opens the diary writing surface.
  - Document selection opens the page editor.
  - Promotion from diary text creates and opens the new page.

The first implementation keeps existing Notebook data loadable but hides Notebook navigation from the primary shell while the new shell becomes the visible default.

## Mobile Shell

The mobile model follows the same hierarchy with less chrome:

- Launch or Diary tab opens directly into the diary editor.
- A Documents tab or navigation destination shows All Documents.
- Tags and Favorites are filters over documents.
- Promotion from diary text works with hardware `Cmd+]` where available and an explicit toolbar/menu action for touch-first use.

The local simulator is currently unreliable for full iOS UI execution, so early mobile validation may be limited to build and shared view-model tests until simulator execution is stable again.

## Diary Behavior

Diary is the fastest path into writing:

- Opening the app makes a text insertion point available with minimal delay.
- The diary editor does not require title entry before text input.
- Empty diary state looks like a blank white page, not a dashboard.
- Diary text persists locally as the user writes.
- Diary text is included in search results with a diary-specific result type or scope marker.
- Diary text is excluded from All Documents and tag collections.
- Diary text can be selected and promoted into a page.

Promotion behavior:

1. User selects text in the diary editor.
2. User presses `Cmd+]`.
3. The app creates a new page with the selected text as its initial content.
4. The new page opens in the editor.
5. The new page appears in All Documents and can receive tags/favorite state.
6. The original diary text remains after promotion.

Preserving the original diary text is the first-version behavior. Delete-after-promotion is deferred until there is an explicit product preference.

## Tags

Tags replace Notebooks as the visible organization model.

Tag rules:

- Tags have names and optional parent tags.
- A nested tag is displayed as a path.
- Documents can have multiple tags.
- Tags are not exclusive; assigning a document to `Work/Project A` does not remove it from other tags.
- Tags apply to document pages in the first implementation.
- Diary text does not participate in normal tag aggregation.

The first implementation supports:

- Creating a tag.
- Creating a nested tag.
- Assigning one or more tags to a page.
- Filtering All Documents by tag.
- Showing favorite state independently from tags.

## All Documents

All Documents is the main document list.

Rules:

- It shows document pages, not diary text.
- It is sorted by updated time descending by default.
- It exposes updated-time sorting first; alternate sort modes are deferred.
- It includes pages created directly and pages promoted from diary text.
- It excludes archived pages.
- Favorite state is visible in the row or available through the row action.
- Tag chips or compact tag labels are visible when space allows.

All Documents feels like a working list, not a file browser.

## Search

Search spans both diary text and document pages, but result behavior differs:

- Document results open the page editor.
- Diary results open the diary editor at or near the matched text when possible.
- Diary results must be visibly marked as diary results so the user understands why they do not appear in All Documents.
- Search continues using local FTS infrastructure where possible.

## Data Model Direction

The existing database can evolve incrementally.

Storage additions:

- `tags`: tag identity, name, parent tag, order, created/updated timestamps.
- `page_tags`: many-to-many relation between pages and tags.
- `diary_entries`: diary text blocks or entries with created/updated timestamps and search metadata. A dedicated table enforces "searchable but not a document" semantics.
- `page_origin`: optional page metadata recording `promoted_from_diary_entry_id` for promoted pages.

Compatibility:

- Existing Notebook and page data continue loading.
- Existing pages appear in All Documents.
- Existing favorite pages appear in Favorites.
- Existing archived pages remain in Archive.
- Existing Notebook hierarchy can be hidden from the primary UI until an explicit migration story is needed.

## Keyboard And Commands

Required first command:

- `Cmd+]`: promote selected diary text into a new page.

Command behavior:

- If diary text selection is non-empty, promotion uses the selected text.
- If selection is empty, the command is disabled or shows a low-friction explanation.
- If focus is not in diary, the first version does not promote arbitrary page text. This keeps scope aligned with text-only diary promotion.

Touch or menu equivalent:

- The UI also exposes a Promote to Page action for non-hardware-keyboard use.

## Verification Strategy

The implementation plan is TDD and UI-observable.

Required test coverage:

- Repository migration creates tag and page-tag storage.
- Tags can be created, nested, assigned, and loaded.
- All Documents excludes diary text and archived pages.
- All Documents sorts by updated time descending by default.
- Favorite pages appear independently from tags.
- Diary text is searchable.
- Diary text does not appear in All Documents or tag-filtered document lists.
- Promoting selected diary text creates a page with the selected text.
- Promoted pages appear in All Documents and can receive tags/favorite state.
- `Cmd+]` routes from the focused diary text editor to promotion.
- macOS UI automation verifies launch-to-diary typing and text promotion to a page.

Nearby regression coverage:

- Existing page editing still works.
- Existing favorites still work.
- Existing search still finds pages and blocks.
- Existing archive still hides pages from active document lists.
- Existing Markdown export still works for promoted pages.

## Implementation Order

User-visible work comes before deeper performance work:

1. Introduce the new spec and update the implementation plan.
2. Add tag data model and document-list view-model state.
3. Add All Documents as the visible middle-column default, sorted by updated time.
4. Add diary storage and launch-to-diary editing.
5. Add diary search inclusion and document-list exclusion.
6. Add text-only diary promotion through `Cmd+]` and a visible command.
7. Add tag assignment/filtering UI for pages.
8. Hide or de-emphasize Notebook navigation from the primary shell.
9. Revisit performance once the user-visible information architecture is in place.

## Deferred Decisions

- Direct page creation remains available through a secondary command, but diary-first capture is the default.
- Delete-after-promotion is not included in the first version; promoted text remains in diary.
- Existing Notebooks are compatibility-only data in the first version and are not automatically migrated into tags.
