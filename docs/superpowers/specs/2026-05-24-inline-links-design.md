# Inline Links Design

## Goal

Improve link behavior in the editor so text blocks support useful inline links:

- Internal wiki-style links can search pages and blocks, bind to a stable target, and jump to that target when clicked.
- External links inside text can open through the system browser.
- `Cmd+[` returns to the source document and source position after following an internal link. `Cmd+]` moves forward again with the same target anchor behavior.

The visible text should stay readable and portable. Internal links remain visible as `[[Page Title]]` or `[[Page Title#Block Summary]]`, while the app stores the selected target page or block ID separately so renamed pages and changed block text do not break existing links.

## Existing Context

The project already has most of the surrounding pieces:

- `BacklinkRepository` maintains `[[...]]` backlinks and external Markdown links in the `links` table.
- `MarkdownInlineStyleScanner` styles Markdown links and autolinks in native text views.
- `WorkspaceViewModel` can open page reference rows, block reference rows, search results, backlinks, and page-level back/forward navigation.
- `EditorCanvasView` already scrolls to `pendingFocusBlockID`.
- Page reference and block reference rows remain separate block types and should not be replaced by this feature.

The missing pieces are inline internal-link target binding, native text hit testing for link clicks, external inline-link opening, and navigation history entries that preserve a block/selection anchor instead of only a page and collection.

## Scope

In scope:

- Current workspace internal links only.
- Internal links to any page.
- Internal links to any visible or stored block on any non-archived page the user can open.
- Search-backed insertion after typing `[[` and from a page action command.
- Click/tap handling for internal wiki links and external Markdown/autolinks.
- Back/forward history that restores page, collection, source block, and a best-effort text selection.
- Focused unit tests plus at least one macOS UI flow for insertion, click navigation, and `Cmd+[` return.

Out of scope for this pass:

- Cross-workspace links.
- Remote/shared public links.
- New rich preview cards.
- Replacing page-reference or block-reference block rows.
- Semantic search changes beyond reusing current search results.

## Data Model

Reuse the existing `links` table as the canonical link index, with a small extension for stable inline internal links.

Add optional columns if missing:

- `source_range_location INTEGER`
- `source_range_length INTEGER`
- `link_kind TEXT NOT NULL DEFAULT 'inline'`

`target_page_id`, `target_block_id`, `target_url`, and `link_text` already model the important destination fields. Existing rows from page-reference and block-reference blocks can keep `link_kind = 'block_reference'` when rebuilt. External Markdown links keep `target_url`.

The source range is not trusted as permanent truth. It is useful for native hit testing and diagnostics, but each block text edit rebuilds that block's link rows from the latest text and embedded target metadata.

For stable internal targets, store a compact JSON payload inside the text block payload alongside existing block payload fields:

```json
{
  "inline_links": [
    {
      "label": "Specs",
      "target_page_id": "page-specs",
      "target_block_id": null
    },
    {
      "label": "Specs#API contract",
      "target_page_id": "page-specs",
      "target_block_id": "block-api-contract"
    }
  ]
}
```

The visible Markdown remains normal text. The payload metadata binds matching visible labels to stable targets. When the user manually types `[[Specs]]`, the repository resolves the title once and records the resolved target. When the user selects from search, the inserted text and payload target are created together.

## Parsing

Add a unified inline link parser used by the repository, native text styling, and click handling:

- `[[Page]]` produces an internal page candidate.
- `[[Page#Block]]` produces an internal block candidate.
- `[Label](https://example.com)` produces an external Markdown link.
- `<https://example.com>` and plain `https://example.com` produce external autolinks.
- Image Markdown links are ignored for inline open behavior.
- Inline code spans and code blocks do not activate links.

Resolution rules:

- Stable payload metadata wins when its label matches the visible wiki link text.
- If no metadata exists, resolve `[[Page]]` by page title using the current earliest-created matching-page behavior.
- If no metadata exists, resolve `[[Page#Block]]` by page title plus block text summary when possible.
- If resolution fails, keep the visible text and backlink text, but do not expose an active jump target.
- A URL without a scheme is not treated as an external clickable link.

## Editing Interaction

Internal link insertion has two entry points:

- Typing `[[` opens a compact internal-link search chooser near the current text block.
- The page action menu adds "Internal Link" for the current editable text selection or caret.

The chooser searches the current `SearchRepository` results and presents mixed page/block rows:

- Page rows insert `[[Page Title]]`.
- Block rows insert `[[Page Title#Block Summary]]`.
- If text is selected, the selected text becomes the visible label when it is non-empty; the stable target still comes from the chosen row.

External links continue to use the existing `Cmd+K` Markdown link panel.

Typing and IME composition must remain stable:

- Do not open the chooser while native text has marked text.
- Do not restyle or reset selection during composition.
- Reuse existing native text selection preservation when applying inline styles.

## Click And Tap Behavior

Native text views expose a link activation callback with:

- source block ID
- clicked character range
- resolved internal destination or external URL
- current text selection if available

For internal links:

1. Record navigation history with page, collection, source block ID, and source selection/anchor.
2. Select the target page.
3. If a target block exists, queue `pendingFocusBlockID` and scroll to that block.
4. On compact iOS, queue compact page navigation to the target page.

For external links:

1. Validate the URL has a scheme.
2. Call the platform `openURL` boundary.
3. Do not change `selectedPageID`, navigation history, or text focus.

Unavailable internal targets should not crash or move the user. They should log the failure and leave the current selection alone.

## Navigation History

Extend `PageNavigationHistoryEntry` to carry an optional anchor:

- `pageID`
- `collection`
- `blockID`
- `selection`

Following an inline internal link records the current anchor. Opening a search result, page reference row, block reference row, parent page, or existing page-list navigation can also populate a block anchor when one is known, but they do not need new UI.

`navigateBack()` restores the previous entry by:

1. Selecting the stored page and collection without recording new history.
2. Hydrating the page if needed.
3. Queuing `pendingFocusBlockID` when the block still exists and is visible.
4. Restoring the stored text selection when it is still valid.
5. Falling back to page-only restoration when the block or selection no longer exists.

`navigateForward()` mirrors the same behavior for the forward stack.

This preserves the current parent-page behavior: if a current page has a parent link and no explicit history entry is available, `Cmd+[` can still open the parent and focus the source page-reference block.

## Error Handling

- Deleted or archived target page: keep text, skip jump, log `inline_internal_link_open_failed reason=target_page_unavailable`.
- Deleted target block: open the target page if available, but log `reason=target_block_unavailable`.
- Locked encrypted target: reuse the existing encrypted-page unlock path. If unlock is refused, remain on the current page.
- Duplicate page titles: chooser selection is stable. Manually typed links bind to the first matching page and stay stable afterward.
- Payload/text mismatch after edits: rebuild links from visible text and keep only payload entries that still match visible wiki labels.

## Tests

Unit tests:

- Parser finds `[[Page]]`, `[[Page#Block]]`, Markdown links, autolinks, and ignores code/image spans.
- Repository rebuild stores stable `target_page_id` and `target_block_id` for inline internal links.
- A page rename does not break an existing stable inline link.
- Manually typed `[[Page]]` resolves once and creates a backlink.
- External links still refresh `selectedPageExternalLinks`.
- Invalid URL text does not become an external clickable target.

View-model tests:

- Opening an inline page link selects the target page and records source anchor.
- Opening an inline block link selects the target page and queues `pendingFocusBlockID`.
- `navigateBack()` after an inline link restores the source page and source block.
- `navigateForward()` restores the target page and target block.
- External inline link opening uses the URL opener and does not change selected page.

UI tests:

- macOS: type `[[`, select a page result, verify inserted wiki text.
- macOS: click an inline internal link, verify target page selection.
- macOS: press `Cmd+[`, verify source page and source block are restored.
- macOS: click an external Markdown link, verify the app asks to open the URL without changing document selection.
- iOS focused smoke: tap an existing inline internal link and verify page navigation plus target block scroll/focus when accessible.

Regression checks:

- Existing Markdown inline link insert/edit/remove tests.
- Existing page-reference and block-reference row click tests.
- Existing search-result selection tests.
- Existing parent-page `Cmd+[` tests.
- Existing native text focus/selection and inline Markdown style tests.
- Existing list/task/toggle chrome alignment tests remain untouched.

## Implementation Notes

Keep the first implementation narrow:

1. Add parser and tests.
2. Extend repository/link rebuilding and tests.
3. Extend view-model navigation anchors and tests.
4. Add native text link hit testing and callback wiring.
5. Add insertion chooser using current search results.
6. Add macOS UI coverage, then iOS smoke coverage.

Avoid broad shell refactors. The natural seams are `MarkdownTransformer.swift` for parsing helpers, `BacklinkRepository.swift` and `PageRepository.swift` for link indexing, `WorkspaceViewModel.swift` for navigation anchors, `NativeTextBlockEditor.swift` for native text hit testing/styling, and `EditorShellView.swift` for chooser and callback wiring.
