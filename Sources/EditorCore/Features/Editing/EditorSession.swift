import Combine
import Foundation

enum EditorFocusReason: String, Equatable, Sendable {
    case userTap
    case keyboard
    case programmatic
}

struct EditorTextSelection: Equatable, Sendable {
    let blockID: String
    let location: Int
    let length: Int
}

@MainActor
final class EditorSession: ObservableObject {
    @Published private(set) var focusedBlockID: String?
    private(set) var lastFocusReason: EditorFocusReason?
    private(set) var dirtyBlockIDs: Set<String> = []
    private(set) var textSelection: EditorTextSelection?
    private(set) var composingBlockID: String?
    @Published private(set) var selectedBlockIDs: Set<String> = []

    private var draftTexts: [String: String] = [:]
    private var acceptedTextInputMirrors: [String: String] = [:]

    func beginEditing(blockID: String, reason: EditorFocusReason) {
        guard focusedBlockID != blockID || lastFocusReason != reason else {
            return
        }

        focusedBlockID = blockID
        lastFocusReason = reason
        EditorLog.focus.debug(
            "editor_focus_begin block_id=\(blockID, privacy: .public) reason=\(reason.rawValue, privacy: .public)"
        )
    }

    func selectBlocks(_ blockIDs: Set<String>) {
        guard selectedBlockIDs != blockIDs else {
            return
        }

        selectedBlockIDs = blockIDs
        EditorLog.selection.debug(
            "editor_block_selection_updated count=\(blockIDs.count, privacy: .public)"
        )
    }

    func clearBlockSelection() {
        guard !selectedBlockIDs.isEmpty else {
            return
        }
        selectedBlockIDs = []
        EditorLog.selection.debug("editor_block_selection_cleared")
    }

    func updateDraft(blockID: String, text: String) {
        guard draftTexts[blockID] != text || !dirtyBlockIDs.contains(blockID) else {
            return
        }

        clearBlockSelection()
        draftTexts[blockID] = text
        acceptedTextInputMirrors[blockID] = text
        dirtyBlockIDs.insert(blockID)
        EditorPerformanceTrace.point("draft_updated") {
            [
                "block_id": blockID,
                "text_length": "\(text.count)"
            ]
        }
        EditorLog.input.debug(
            "editor_draft_updated block_id=\(blockID, privacy: .public) length=\(text.count, privacy: .public)"
        )
    }

    func draftText(for blockID: String) -> String? {
        draftTexts[blockID]
    }

    func acceptedTextInputMirror(for blockID: String) -> String? {
        acceptedTextInputMirrors[blockID]
    }

    func updateAcceptedTextInputMirror(blockID: String, text: String) {
        acceptedTextInputMirrors[blockID] = text
    }

    func clearAcceptedTextInputMirror(blockID: String) {
        acceptedTextInputMirrors.removeValue(forKey: blockID)
    }

    func commitDraft(blockID: String) -> String? {
        guard draftTexts[blockID] != nil || dirtyBlockIDs.contains(blockID) else {
            return nil
        }

        let draft = draftTexts.removeValue(forKey: blockID)
        dirtyBlockIDs.remove(blockID)
        acceptedTextInputMirrors.removeValue(forKey: blockID)
        EditorLog.input.debug("editor_draft_committed block_id=\(blockID, privacy: .public)")
        return draft
    }

    @discardableResult
    func updateSelection(blockID: String, location: Int, length: Int) -> Bool {
        let nextSelection = EditorTextSelection(
            blockID: blockID,
            location: max(location, 0),
            length: max(length, 0)
        )
        guard textSelection != nextSelection else {
            return false
        }

        let previousSelection = textSelection
        if shouldPublishRenderingChange(from: previousSelection, to: nextSelection) {
            objectWillChange.send()
        }
        textSelection = nextSelection
        let selectionEventName = nextSelection.length == 0 ? "cursor_move_start" : "selection_start"
        let modelUpdatedEventName = nextSelection.length == 0 ? "cursor_model_updated" : "selection_model_updated"
        let paintedEventName = nextSelection.length == 0
            ? "cursor_next_runloop_painted"
            : "selection_next_runloop_painted"
        let metadata = [
            "block_id": blockID,
            "location": "\(nextSelection.location)",
            "length": "\(nextSelection.length)"
        ]
        EditorPerformanceTrace.point(selectionEventName, metadata: metadata)
        EditorPerformanceTrace.point(modelUpdatedEventName, metadata: metadata)
        EditorPerformanceTrace.nextRunLoopPoint(paintedEventName) {
            metadata
        }
        EditorLog.selection.debug(
            "editor_selection_updated block_id=\(blockID, privacy: .public) location=\(max(location, 0), privacy: .public) length=\(max(length, 0), privacy: .public)"
        )
        return true
    }

    private func shouldPublishRenderingChange(
        from previousSelection: EditorTextSelection?,
        to nextSelection: EditorTextSelection
    ) -> Bool {
        guard let previousSelection else {
            return nextSelection.length > 0
        }

        if previousSelection.blockID != nextSelection.blockID {
            return true
        }

        if previousSelection.length != nextSelection.length {
            return previousSelection.length > 0 || nextSelection.length > 0
        }

        return nextSelection.length > 0 && previousSelection.location != nextSelection.location
    }

    func updateComposition(blockID: String, isComposing: Bool) {
        if isComposing {
            guard composingBlockID != blockID else {
                return
            }
            composingBlockID = blockID
        } else if composingBlockID == blockID {
            composingBlockID = nil
        } else {
            return
        }
        EditorPerformanceTrace.point(isComposing ? "ime_composition_start" : "ime_composition_commit") {
            [
                "block_id": blockID,
                "is_composing": "\(isComposing)"
            ]
        }
        EditorLog.input.debug(
            "editor_composition_updated block_id=\(blockID, privacy: .public) is_composing=\(isComposing, privacy: .public)"
        )
    }

    func endEditing(blockID: String) {
        let publishesFocusChange = focusedBlockID == blockID
        if focusedBlockID == blockID {
            focusedBlockID = nil
        }
        if textSelection?.blockID == blockID {
            if !publishesFocusChange, (textSelection?.length ?? 0) > 0 {
                objectWillChange.send()
            }
            textSelection = nil
        }
        if composingBlockID == blockID {
            composingBlockID = nil
        }
        acceptedTextInputMirrors.removeValue(forKey: blockID)
        EditorLog.focus.debug("editor_focus_end block_id=\(blockID, privacy: .public)")
    }
}
