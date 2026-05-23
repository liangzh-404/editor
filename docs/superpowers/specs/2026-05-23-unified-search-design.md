# Unified Search Design

## Goal

Replace the separate Search collection with a single search field at the top of the middle document column. When the query is non-empty, search results replace the current document list. Clearing the query restores the previous document list.

## User Experience

- Desktop keeps the middle-column search field above the document list.
- iOS document-list screens show the same search field at the top of the list, so search is not a separate library item.
- The sidebar/library no longer exposes a standalone Search row.
- Typing a query enters search mode and records the collection that should be restored later.
- Pressing the clear button, deleting the query, or clearing from UI restores the previous collection.
- Search result rows show title, snippet, content type, and match kind when useful.

## Search Ranking

Search returns a single mixed result list. The user does not switch modes.

Ranking tiers:

1. Exact matches: exact title, title prefix, exact filename, and exact phrase body matches.
2. Full-text matches: SQLite FTS5 BM25 results with title priority and contextual snippets.
3. Fuzzy matches: trigram/substring and lightweight typo-tolerant matches for partial words, filenames, and Chinese substrings.
4. Semantic matches: provider-backed semantic candidates merged after exact and full-text matches.

Duplicate candidates collapse by entity type and entity id, preserving the strongest tier.

## Performance

- Search refreshes are debounced from text input.
- Query execution runs off the main actor and ignores stale results.
- The index remains incremental for block edits.
- The repository keeps SQLite FTS5 as the primary large-vault path.
- Fuzzy and semantic candidates are bounded by result limits so importing an Obsidian vault does not turn every keystroke into a full in-memory scan.

## Implementation Boundaries

- `SearchRepository` owns ranking, match kinds, deduplication, and provider merging.
- `WorkspaceViewModel` owns search activation/restoration and debounced execution state.
- `EditorShellView` owns desktop and iOS presentation.
- Existing archive/tag/favorite/encrypted behavior remains unchanged.

## Verification

- Unit tests prove ranking tier order, fuzzy recall, semantic provider recall, search restore behavior, and removal of standalone search navigation items.
- Focused app tests or build checks verify desktop and iOS targets still compile.
- Existing large-page search baseline remains part of regression coverage.
