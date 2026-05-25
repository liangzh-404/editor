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
    func testBeginEditingPublishesOnlyFocusedBlockRenderingChange() {
        let session = EditorSession()
        var publishCount = 0
        let cancellable = session.objectWillChange.sink {
            publishCount += 1
        }

        session.beginEditing(blockID: "block-1", reason: .userTap)

        XCTAssertEqual(publishCount, 1)
        _ = cancellable
    }

    @MainActor
    func testDraftUpdatesMarkOnlyEditedBlockDirty() {
        let session = EditorSession()

        session.beginEditing(blockID: "block-1", reason: .userTap)
        session.updateDraft(blockID: "block-1", text: "Hello")

        XCTAssertEqual(session.draftText(for: "block-1"), "Hello")
        XCTAssertEqual(session.acceptedTextInputMirror(for: "block-1"), "Hello")
        XCTAssertEqual(session.dirtyBlockIDs, ["block-1"])
    }

    @MainActor
    func testDraftUpdatesDoNotPublishRenderingChanges() {
        let session = EditorSession()
        var publishCount = 0
        let cancellable = session.objectWillChange.sink {
            publishCount += 1
        }

        session.updateDraft(blockID: "block-1", text: "Hello")

        XCTAssertEqual(publishCount, 0)
        _ = cancellable
    }

    @MainActor
    func testCommitReturnsDraftAndClearsDirtyState() {
        let session = EditorSession()

        session.updateDraft(blockID: "block-1", text: "Committed")
        let committed = session.commitDraft(blockID: "block-1")

        XCTAssertEqual(committed, "Committed")
        XCTAssertNil(session.draftText(for: "block-1"))
        XCTAssertNil(session.acceptedTextInputMirror(for: "block-1"))
        XCTAssertFalse(session.dirtyBlockIDs.contains("block-1"))
    }

    @MainActor
    func testAcceptedTextInputMirrorSurvivesViewIdentityChangesUntilEditingEnds() {
        let session = EditorSession()

        session.updateAcceptedTextInputMirror(blockID: "block-1", text: "per")

        XCTAssertEqual(session.acceptedTextInputMirror(for: "block-1"), "per")

        session.endEditing(blockID: "block-1")

        XCTAssertNil(session.acceptedTextInputMirror(for: "block-1"))
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
    func testCursorMovementWithinFocusedBlockDoesNotPublishRenderingChanges() {
        let session = EditorSession()
        session.beginEditing(blockID: "block-1", reason: .userTap)
        session.updateSelection(blockID: "block-1", location: 3, length: 0)

        var publishCount = 0
        let cancellable = session.objectWillChange.sink {
            publishCount += 1
        }

        session.updateSelection(blockID: "block-1", location: 4, length: 0)

        XCTAssertEqual(session.textSelection?.location, 4)
        XCTAssertEqual(publishCount, 0)
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

    @MainActor
    func testCompositionUpdatesDoNotPublishRenderingChanges() {
        let session = EditorSession()
        var publishCount = 0
        let cancellable = session.objectWillChange.sink {
            publishCount += 1
        }

        session.updateComposition(blockID: "block-1", isComposing: true)
        session.updateComposition(blockID: "block-1", isComposing: false)

        XCTAssertEqual(publishCount, 0)
        _ = cancellable
    }
}
