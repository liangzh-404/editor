import Combine
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

    @MainActor
    func testSelectionUpdatesTrackBlockAndCaretRange() {
        let session = EditorSession()

        session.updateSelection(blockID: "block-1", location: 3, length: 2)

        XCTAssertEqual(
            session.textSelection,
            EditorTextSelection(blockID: "block-1", location: 3, length: 2)
        )
    }

    @MainActor
    func testRepeatedSelectionUpdateDoesNotRepublishUnchangedSelection() {
        let session = EditorSession()
        var publishCount = 0
        let cancellable = session.objectWillChange.sink {
            publishCount += 1
        }

        session.updateSelection(blockID: "block-1", location: 3, length: 2)
        session.updateSelection(blockID: "block-1", location: 3, length: 2)

        XCTAssertEqual(publishCount, 1)
        _ = cancellable
    }

    @MainActor
    func testCompositionStateTracksCurrentBlockAndClearsWhenFinished() {
        let session = EditorSession()

        session.updateComposition(blockID: "block-1", isComposing: true)

        XCTAssertEqual(session.composingBlockID, "block-1")

        session.updateComposition(blockID: "block-1", isComposing: false)

        XCTAssertNil(session.composingBlockID)
    }
}
