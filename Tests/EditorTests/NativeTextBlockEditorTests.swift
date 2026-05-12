import Foundation
import XCTest

final class NativeTextBlockEditorTests: XCTestCase {
    @MainActor
    func testNativeTextBlockEditorKeepsBlockIdentityAndInitialText() {
        let session = EditorSession()
        let editor = NativeTextBlockEditor(
            blockID: "block-1",
            text: "Hello",
            blockType: .paragraph,
            session: session,
            onTextChange: { _ in }
        )

        XCTAssertEqual(editor.blockID, "block-1")
        XCTAssertEqual(editor.text, "Hello")
        XCTAssertEqual(editor.blockType, .paragraph)
    }

    @MainActor
    func testNativeTextBlockEditorKeepsLineWrappingConfiguration() {
        let session = EditorSession()
        let editor = NativeTextBlockEditor(
            blockID: "block-1",
            text: "let value = 1",
            blockType: .codeBlock,
            session: session,
            lineWrapping: false,
            onTextChange: { _ in }
        )

        XCTAssertFalse(editor.lineWrapping)
    }

    @MainActor
    func testNativeTextBlockEditorShowsPlaceholderForEmptyUnfocusedBlock() {
        let session = EditorSession()
        let editor = NativeTextBlockEditor(
            blockID: "block-1",
            text: "",
            blockType: .paragraph,
            session: session,
            onTextChange: { _ in }
        )

        XCTAssertTrue(editor.showsPlaceholder)

        session.beginEditing(blockID: "block-1", reason: .programmatic)
        let focusedEditor = NativeTextBlockEditor(
            blockID: "block-1",
            text: "",
            blockType: .paragraph,
            session: session,
            onTextChange: { _ in }
        )
        XCTAssertFalse(focusedEditor.showsPlaceholder)

        let editorWithText = NativeTextBlockEditor(
            blockID: "block-1",
            text: "Already editable",
            blockType: .paragraph,
            session: session,
            onTextChange: { _ in }
        )
        XCTAssertFalse(editorWithText.showsPlaceholder)
    }

    func testNativeFocusRequestStateRetriesUntilFocusSucceeds() {
        let requestID = UUID()
        var state = NativeTextFocusRequestState()

        XCTAssertEqual(state.beginScheduling(requestID), requestID)
        state.finish(requestID: requestID, didFocus: false)

        XCTAssertEqual(state.beginScheduling(requestID), requestID)
        state.finish(requestID: requestID, didFocus: true)

        XCTAssertNil(state.beginScheduling(requestID))
    }

    func testNativeTextModelUpdateGuardSuppressesProgrammaticTextChangeForwarding() {
        var guardState = NativeTextModelUpdateGuard()

        XCTAssertTrue(guardState.shouldForwardTextChange)

        guardState.beginApplyingModelText()
        XCTAssertFalse(guardState.shouldForwardTextChange)

        guardState.finishApplyingModelText()
        XCTAssertTrue(guardState.shouldForwardTextChange)
    }

    func testNativeTextFocusSelectionUsesValidRequestedSelectionRange() {
        let range = NativeTextFocusSelection.range(
            from: EditorTextSelection(blockID: "block-1", location: 3, length: 2),
            blockID: "block-1",
            text: "Hello"
        )

        XCTAssertEqual(range, NSRange(location: 3, length: 2))
    }

    func testNativeTextFocusSelectionFallsBackToTextEndForInvalidSelection() {
        XCTAssertEqual(
            NativeTextFocusSelection.range(
                from: EditorTextSelection(blockID: "other", location: 1, length: 1),
                blockID: "block-1",
                text: "Hi 🧠"
            ),
            NSRange(location: ("Hi 🧠" as NSString).length, length: 0)
        )
        XCTAssertEqual(
            NativeTextFocusSelection.range(
                from: EditorTextSelection(blockID: "block-1", location: 20, length: 1),
                blockID: "block-1",
                text: "Short"
            ),
            NSRange(location: 5, length: 0)
        )
    }

    @MainActor
    func testNativeTextBlockEditorAcceptsInactiveWindowFirstMouseOnMac() {
#if os(macOS)
        XCTAssertTrue(NativeTextBlockEditor.acceptsInactiveWindowFirstMouse)
#endif
    }

    func testNativeTextMouseFocusPolicyMakesWindowKeyBeforeFocusingTextViewOnMac() {
#if os(macOS)
        XCTAssertTrue(NativeTextMouseFocusPolicy.makesWindowKeyBeforeFirstResponder)
#endif
    }

    func testMacWindowVisibilityPolicyRequestsMainWindowWhenNoneVisible() {
#if os(macOS)
        XCTAssertTrue(MacWindowVisibilityPolicy.shouldRequestMainWindow(hasVisibleWindows: false))
        XCTAssertFalse(MacWindowVisibilityPolicy.shouldRequestMainWindow(hasVisibleWindows: true))
#endif
    }

    func testBlockKeyboardShortcutResolverHandlesCommandOptionArrowsOnly() {
        XCTAssertEqual(
            BlockKeyboardShortcutResolver.moveDirection(
                keyCode: BlockKeyboardShortcutResolver.upArrowKeyCode,
                modifiers: [.command, .option]
            ),
            .up
        )
        XCTAssertEqual(
            BlockKeyboardShortcutResolver.moveDirection(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [.command, .option]
            ),
            .down
        )
        XCTAssertNil(
            BlockKeyboardShortcutResolver.moveDirection(
                keyCode: BlockKeyboardShortcutResolver.upArrowKeyCode,
                modifiers: [.command]
            )
        )
        XCTAssertNil(
            BlockKeyboardShortcutResolver.moveDirection(
                keyCode: 0,
                modifiers: [.command, .option]
            )
        )
    }

    func testBlockKeyboardShortcutResolverHandlesReturnAsInsertBlockOnlyWithoutModifiers() {
        XCTAssertTrue(
            BlockKeyboardShortcutResolver.insertsBlockAfter(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: []
            )
        )
        XCTAssertFalse(
            BlockKeyboardShortcutResolver.insertsBlockAfter(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: [.shift]
            )
        )
        XCTAssertFalse(
            BlockKeyboardShortcutResolver.insertsBlockAfter(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: [.command]
            )
        )
    }

    func testBlockKeyboardShortcutResolverHandlesTabIndentAndShiftTabOutdent() {
        XCTAssertEqual(
            BlockKeyboardShortcutResolver.indentationDirection(
                keyCode: BlockKeyboardShortcutResolver.tabKeyCode,
                modifiers: []
            ),
            .indent
        )
        XCTAssertEqual(
            BlockKeyboardShortcutResolver.indentationDirection(
                keyCode: BlockKeyboardShortcutResolver.tabKeyCode,
                modifiers: [.shift]
            ),
            .outdent
        )
        XCTAssertNil(
            BlockKeyboardShortcutResolver.indentationDirection(
                keyCode: BlockKeyboardShortcutResolver.tabKeyCode,
                modifiers: [.command]
            )
        )
        XCTAssertNil(
            BlockKeyboardShortcutResolver.indentationDirection(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: []
            )
        )
    }

    func testBlockDragReorderResolverMovesBeforeDestinationBlock() {
        let visibleBlockIDs = ["a", "b", "c"]

        XCTAssertEqual(
            BlockDragReorderResolver.targetIndex(
                draggedBlockID: "a",
                destinationBlockID: "c",
                visibleBlockIDs: visibleBlockIDs
            ),
            1
        )
        XCTAssertEqual(
            BlockDragReorderResolver.targetIndex(
                draggedBlockID: "c",
                destinationBlockID: "a",
                visibleBlockIDs: visibleBlockIDs
            ),
            0
        )
        XCTAssertNil(
            BlockDragReorderResolver.targetIndex(
                draggedBlockID: "b",
                destinationBlockID: "c",
                visibleBlockIDs: visibleBlockIDs
            )
        )
    }

    func testNotebookHierarchyComputesNestingAndSiblingMovePositions() {
        let notebooks = [
            NotebookSummary(id: "root-a", workspaceID: "workspace", name: "Root A"),
            NotebookSummary(id: "parent", workspaceID: "workspace", name: "Parent"),
            NotebookSummary(
                id: "child-a",
                workspaceID: "workspace",
                parentNotebookID: "parent",
                name: "Child A"
            ),
            NotebookSummary(
                id: "child-b",
                workspaceID: "workspace",
                parentNotebookID: "parent",
                name: "Child B"
            ),
            NotebookSummary(id: "root-b", workspaceID: "workspace", name: "Root B")
        ]

        XCTAssertEqual(
            NotebookHierarchy.nestingLevel(for: notebooks[2], in: notebooks),
            1
        )
        XCTAssertFalse(NotebookHierarchy.canMoveUp(notebook: notebooks[2], in: notebooks))
        XCTAssertTrue(NotebookHierarchy.canMoveDown(notebook: notebooks[2], in: notebooks))
        XCTAssertEqual(
            NotebookHierarchy.siblingTargetIndex(
                for: notebooks[3],
                direction: .up,
                in: notebooks
            ),
            0
        )
        XCTAssertEqual(
            NotebookHierarchy.siblingTargetIndex(
                for: notebooks[1],
                direction: .down,
                in: notebooks
            ),
            2
        )
    }

    func testBlockDragReorderResolverMovesToEndRegion() {
        let visibleBlockIDs = ["a", "b", "c"]

        XCTAssertEqual(
            BlockDragReorderResolver.endTargetIndex(
                draggedBlockID: "a",
                visibleBlockIDs: visibleBlockIDs
            ),
            2
        )
        XCTAssertNil(
            BlockDragReorderResolver.endTargetIndex(
                draggedBlockID: "c",
                visibleBlockIDs: visibleBlockIDs
            )
        )
    }

    func testEditorCanvasRenderMetricsSummarizeRenderWorkload() {
        let metrics = EditorCanvasRenderMetrics(
            pageID: "page-1",
            blockCount: 1_000,
            attachmentCount: 3,
            backlinkCount: 2,
            conflictCount: 1
        )

        XCTAssertEqual(metrics.pageID, "page-1")
        XCTAssertEqual(metrics.blockCount, 1_000)
        XCTAssertEqual(metrics.attachmentCount, 3)
        XCTAssertEqual(metrics.backlinkCount, 2)
        XCTAssertEqual(metrics.conflictCount, 1)
        XCTAssertTrue(metrics.isLargePage)
        XCTAssertTrue(EditorCanvasRenderPolicy.usesLazyBlockStack)
    }

    func testEditorCanvasScrollMetricsTrackVisibleBlocksAndLargePageState() {
        var tracker = EditorCanvasScrollMetricsTracker(pageID: "page-1", blockCount: 1_000)

        tracker.blockAppeared("a")
        tracker.blockAppeared("b")
        tracker.blockAppeared("b")
        tracker.blockDisappeared("a")

        XCTAssertEqual(
            tracker.metrics,
            EditorCanvasScrollMetrics(
                pageID: "page-1",
                blockCount: 1_000,
                visibleBlockCount: 1,
                peakVisibleBlockCount: 2
            )
        )
        XCTAssertTrue(tracker.metrics.isLargePage)
    }
}
