import Combine
import Foundation

enum EditorFocusReason: String, Equatable, Sendable {
    case userTap
    case keyboard
    case programmatic
}

@MainActor
final class EditorSession: ObservableObject {
    @Published private(set) var focusedBlockID: String?
    @Published private(set) var lastFocusReason: EditorFocusReason?
    @Published private(set) var dirtyBlockIDs: Set<String> = []

    private var draftTexts: [String: String] = [:]

    func beginEditing(blockID: String, reason: EditorFocusReason) {
        focusedBlockID = blockID
        lastFocusReason = reason
        EditorLog.focus.debug(
            "editor_focus_begin block_id=\(blockID, privacy: .public) reason=\(reason.rawValue, privacy: .public)"
        )
    }

    func updateDraft(blockID: String, text: String) {
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
        let draft = draftTexts.removeValue(forKey: blockID)
        dirtyBlockIDs.remove(blockID)
        EditorLog.input.debug("editor_draft_committed block_id=\(blockID, privacy: .public)")
        return draft
    }

    func endEditing(blockID: String) {
        if focusedBlockID == blockID {
            focusedBlockID = nil
        }
        EditorLog.focus.debug("editor_focus_end block_id=\(blockID, privacy: .public)")
    }
}
