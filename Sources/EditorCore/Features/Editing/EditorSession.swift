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
    @Published private(set) var lastFocusReason: EditorFocusReason?
    @Published private(set) var dirtyBlockIDs: Set<String> = []
    @Published private(set) var textSelection: EditorTextSelection?
    @Published private(set) var composingBlockID: String?
    @Published private(set) var selectedBlockIDs: Set<String> = []

    private var draftTexts: [String: String] = [:]

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
        dirtyBlockIDs.insert(blockID)
        EditorLog.input.debug(
            "editor_draft_updated block_id=\(blockID, privacy: .public) length=\(text.count, privacy: .public)"
        )
    }

    func draftText(for blockID: String) -> String? {
        draftTexts[blockID]
    }

    func commitDraft(blockID: String) -> String? {
        guard draftTexts[blockID] != nil || dirtyBlockIDs.contains(blockID) else {
            return nil
        }

        let draft = draftTexts.removeValue(forKey: blockID)
        dirtyBlockIDs.remove(blockID)
        EditorLog.input.debug("editor_draft_committed block_id=\(blockID, privacy: .public)")
        return draft
    }

    func updateSelection(blockID: String, location: Int, length: Int) {
        let nextSelection = EditorTextSelection(
            blockID: blockID,
            location: max(location, 0),
            length: max(length, 0)
        )
        guard textSelection != nextSelection else {
            return
        }

        textSelection = nextSelection
        EditorLog.selection.debug(
            "editor_selection_updated block_id=\(blockID, privacy: .public) location=\(max(location, 0), privacy: .public) length=\(max(length, 0), privacy: .public)"
        )
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
        EditorLog.input.debug(
            "editor_composition_updated block_id=\(blockID, privacy: .public) is_composing=\(isComposing, privacy: .public)"
        )
    }

    func endEditing(blockID: String) {
        if focusedBlockID == blockID {
            focusedBlockID = nil
        }
        if textSelection?.blockID == blockID {
            textSelection = nil
        }
        if composingBlockID == blockID {
            composingBlockID = nil
        }
        EditorLog.focus.debug("editor_focus_end block_id=\(blockID, privacy: .public)")
    }
}
