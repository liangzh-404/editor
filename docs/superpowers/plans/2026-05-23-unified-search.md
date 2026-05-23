# Unified Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single-entry, fast, mixed-mode search experience for desktop and iOS.

**Architecture:** Keep SQLite FTS5 as the primary index. Add match-kind ranking and bounded fuzzy/semantic candidate merging in `SearchRepository`, then let `WorkspaceViewModel` manage debounced background refresh and collection restoration. Remove standalone search navigation rows from desktop and compact iOS models.

**Tech Stack:** Swift 6, SwiftUI, SQLite FTS5, XCTest, existing EditorCore repository/view-model tests.

---

### Task 1: Search Result Semantics And Ranking

**Files:**
- Modify: `Sources/EditorCore/Store/SearchRepository.swift`
- Test: `Tests/EditorTests/SearchRepositoryTests.swift`

- [ ] Add `SearchMatchKind` with exact, fullText, fuzzy, and semantic cases.
- [ ] Extend `SearchResult` with `matchKind`.
- [ ] Add tests for exact-before-full-text, fuzzy typo/substring recall, and semantic provider recall.
- [ ] Implement deduplicated candidate merging in ranked tier order.

### Task 2: Search Activation And Performance State

**Files:**
- Modify: `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`
- Test: `Tests/EditorTests/WorkspaceViewModelTests.swift`

- [ ] Add search active/restoration state to the view model.
- [ ] Add debounced background search execution with stale-result cancellation.
- [ ] Add tests for non-empty query entering search mode, clear restoring the previous collection, and current block edits refreshing search results.

### Task 3: Remove Standalone Search Navigation

**Files:**
- Modify: `Sources/EditorCore/Features/Shell/EditorShellView.swift`
- Test: `Tests/EditorTests/EditorBlockChromeTests.swift`

- [ ] Remove desktop sidebar Search utility item.
- [ ] Remove iOS compact library Search item.
- [ ] Update route planner tests so search is no longer a user-visible collection route.

### Task 4: Unified Desktop And iOS Presentation

**Files:**
- Modify: `Sources/EditorCore/Features/Shell/EditorShellView.swift`
- Test: `Tests/EditorTests/EditorBlockChromeTests.swift`

- [ ] Make desktop clear button call the restore-aware clear path.
- [ ] Add an iOS top search field above compact collection lists.
- [ ] Render search results in place of page rows whenever the query is non-empty.
- [ ] Keep archive/tag/favorite/encrypted rows unchanged when search is inactive.

### Task 5: Verification

**Commands:**
- `xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/SearchRepositoryTests`
- `xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/WorkspaceViewModelTests`
- `xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/EditorBlockChromeTests`
- `xcodebuild -quiet build -project Editor.xcodeproj -scheme EditorIOS -destination 'generic/platform=iOS Simulator'`
- `xcodebuild -quiet build -project Editor.xcodeproj -scheme EditorMac -destination 'platform=macOS,arch=arm64'`
