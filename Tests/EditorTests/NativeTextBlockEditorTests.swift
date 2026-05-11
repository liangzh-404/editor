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
}
