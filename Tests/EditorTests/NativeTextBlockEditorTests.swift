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

    @MainActor
    func testNativeTextBlockEditorAcceptsInactiveWindowFirstMouseOnMac() {
#if os(macOS)
        XCTAssertTrue(NativeTextBlockEditor.acceptsInactiveWindowFirstMouse)
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
}
