import Foundation
import XCTest

final class EditorSessionTests: XCTestCase {
    @MainActor
    func testBeginEditingTracksFocusedBlockAndReason() {
        let session = EditorSession()

        session.beginEditing(blockID: "block-1", reason: .userTap)

        XCTAssertEqual(session.focusedBlockID, "block-1")
        XCTAssertEqual(session.lastFocusReason, .userTap)
    }

    @MainActor
    func testDraftUpdatesMarkOnlyEditedBlockDirty() {
        let session = EditorSession()

        session.beginEditing(blockID: "block-1", reason: .userTap)
        session.updateDraft(blockID: "block-1", text: "Hello")

        XCTAssertEqual(session.draftText(for: "block-1"), "Hello")
        XCTAssertEqual(session.dirtyBlockIDs, ["block-1"])
    }

    @MainActor
    func testCommitReturnsDraftAndClearsDirtyState() {
        let session = EditorSession()

        session.updateDraft(blockID: "block-1", text: "Committed")
        let committed = session.commitDraft(blockID: "block-1")

        XCTAssertEqual(committed, "Committed")
        XCTAssertNil(session.draftText(for: "block-1"))
        XCTAssertFalse(session.dirtyBlockIDs.contains("block-1"))
    }
}
