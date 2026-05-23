# iOS Attachments And Drawing Block Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add iOS slash-command insertion for images/files and a native SwiftUI drawing block on iOS and macOS.

**Architecture:** Reuse the existing attachment import, storage, thumbnail, search, and sync path for binary drawing data. Add a dedicated `drawing` block type so drawings behave like independent blocks while their editable `.drawing` payload is kept as a managed attachment asset.

**Tech Stack:** Swift, SwiftUI Canvas/Gestures, UIKit/AppKit shell integration, XcodeGen project, XCTest/XCUITest.

---

### Task 1: Command And Model Tests

**Files:**
- Modify: `Tests/EditorTests/MarkdownTransformerTests.swift`
- Modify: `Tests/EditorTests/AttachmentRepositoryTests.swift`
- Modify: `Tests/EditorTests/WorkspaceViewModelTests.swift`

- [x] Add tests proving `/图片`, `/文件`, and `/画板` resolve to distinct commands.
- [x] Add tests proving an imported drawing persists a `.drawing` block with an editable managed attachment file.
- [x] Add tests proving the view model can create a drawing block after the focused text block.

### Task 2: Storage And Command Implementation

**Files:**
- Modify: `Sources/EditorCore/Models/EditorModels.swift`
- Modify: `Sources/EditorCore/Features/Markdown/MarkdownTransformer.swift`
- Modify: `Sources/EditorCore/Store/AttachmentRepository.swift`
- Modify: `Sources/EditorCore/Store/PageRepository.swift`
- Modify: `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`

- [x] Add `BlockType.drawing` as non-text-editable and attachment-backed.
- [x] Add `AttachmentKind.drawing` classified by `com.apple.drawing` and `.drawing` extensions.
- [x] Add repository entry points for creating and updating drawing data while reusing attachment sync records.
- [x] Add view-model APIs to persist drawing edits.

### Task 3: Shell And Native Drawing UI

**Files:**
- Modify: `Sources/EditorCore/Features/Shell/EditorShellView.swift`
- Modify: `Tests/EditorTests/EditorBlockChromeTests.swift`
- Modify: `Tests/EditorIOSUITests/EditorIOSEditingUITests.swift`
- Modify: `Tests/EditorMacUITests/EditorMacEditingUITests.swift`

- [x] Enable slash-command attachment items and route them to file/photo import on iOS.
- [x] Add a `DrawingBlockRow` backed by SwiftUI Canvas/Gestures so drawing is editable on both iOS and macOS.
- [x] Add accessibility identifiers for inserted drawing blocks and clear action.
- [x] Verify nearby row chrome regressions: attachment rows, slash menu, and existing attachment insertion.

### Verification

- [x] `xcodebuild test -scheme EditorTests -destination 'platform=macOS' -only-testing:EditorTests/MarkdownTransformerTests/testSlashCommandResolverMatchesAttachmentAndDrawingCommands -only-testing:EditorTests/AttachmentRepositoryTests/testImportDrawingPersistsEditableDrawingBlock -only-testing:EditorTests/WorkspaceViewModelTests/testDrawingImportCanInsertAfterFocusedTextBlockAndRemainEditable`
- [x] `xcodebuild test -scheme EditorTests -destination 'platform=macOS' -only-testing:EditorTests/AttachmentRepositoryTests ...`
- [x] `xcodebuild build -scheme EditorIOS -destination 'generic/platform=iOS Simulator'`
- [x] `xcodebuild build -scheme EditorMac -destination 'platform=macOS'`
- [ ] Focused iOS/macOS UI automation for slash command and drawing-row gestures.
