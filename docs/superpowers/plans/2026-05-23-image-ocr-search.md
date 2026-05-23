# Image OCR Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reuse iOS/macOS native OCR to make image text searchable, then route selected image-search results to the matching note block with a short highlight on desktop and mobile.

**Architecture:** Store OCR output as local derived data keyed by `attachment_id` and `content_hash`, then fold recognized text into the existing FTS-backed `SearchRepository`. `WorkspaceViewModel` owns background OCR scheduling, search-result navigation, and transient highlight state; `EditorShellView` renders the highlight through the existing shared block row and image row path.

**Tech Stack:** Swift, SwiftUI, XCTest, SQLite/FTS5, Apple Vision `VNRecognizeTextRequest`, existing `EditorTests` and `EditorIOS`/`EditorMac` schemes.

---

### Task 1: OCR Result Storage And Search Index

**Files:**
- Modify: `Sources/EditorCore/Store/SchemaMigrator.swift`
- Create: `Sources/EditorCore/Store/AttachmentTextRecognitionRepository.swift`
- Modify: `Sources/EditorCore/Store/SearchRepository.swift`
- Test: `Tests/EditorTests/SearchRepositoryTests.swift`
- Test: `Tests/EditorTests/SchemaMigratorTests.swift`

- [ ] Add failing schema and search tests for `attachment_text_recognition`.
- [ ] Verify red with focused `xcodebuild test`.
- [ ] Add the OCR table, repository, and FTS integration.
- [ ] Verify green with the same focused tests.

### Task 2: OCR Scheduling And Native Vision Adapter

**Files:**
- Create: `Sources/EditorCore/Store/AttachmentTextRecognitionScheduler.swift`
- Create: `Sources/EditorCore/Store/VisionImageTextRecognizer.swift`
- Modify: `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`
- Modify: `Sources/EditorApp/AppEnvironment.swift`
- Test: `Tests/EditorTests/WorkspaceViewModelTests.swift`

- [ ] Add failing tests that image import schedules OCR and refreshes search when OCR completes.
- [ ] Verify red with focused `WorkspaceViewModelTests`.
- [ ] Wire repository, recognizer, scheduler, and app environment injection.
- [ ] Verify green with focused `WorkspaceViewModelTests`.

### Task 3: Result Navigation And Transient Highlight

**Files:**
- Modify: `Sources/EditorCore/Store/SearchRepository.swift`
- Modify: `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`
- Modify: `Sources/EditorCore/Features/Shell/EditorShellView.swift`
- Test: `Tests/EditorTests/WorkspaceViewModelTests.swift`
- Test: `Tests/EditorTests/EditorBlockChromeTests.swift`

- [ ] Add failing tests that OCR attachment results carry a destination block and selecting them queues block focus plus highlight.
- [ ] Verify red with focused tests.
- [ ] Add transient highlight state and shared iOS/macOS rendering on block/image rows.
- [ ] Verify green with focused tests.

### Task 4: Verification

**Files:**
- All touched files.

- [ ] Run focused search/OCR/view-model/chrome tests.
- [ ] Run `git diff --check`.
- [ ] Build `EditorMac`.
- [ ] Build `EditorIOS` for simulator.
- [ ] Report remaining risk, especially real-device OCR behavior if no physical-device launch is available.
