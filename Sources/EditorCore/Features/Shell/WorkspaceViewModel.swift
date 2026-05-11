import Foundation

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published private(set) var snapshot: WorkspaceSnapshot
    @Published private(set) var selectedWorkspaceID: String?
    @Published private(set) var selectedPageID: String?

    private let repository: PageRepository?

    var selectedPage: PageSummary? {
        guard let selectedPageID else {
            return nil
        }
        return snapshot.pages.first { $0.id == selectedPageID }
    }

    var visibleBlocks: [BlockSnapshot] {
        guard let selectedPageID else {
            return []
        }
        return snapshot.blocks.filter { $0.pageID == selectedPageID }
    }

    init(repository: PageRepository) {
        self.repository = repository
        snapshot = .empty
        selectedWorkspaceID = nil
        selectedPageID = nil
    }

    init(snapshot: WorkspaceSnapshot) {
        repository = nil
        self.snapshot = snapshot
        selectedWorkspaceID = snapshot.selectedWorkspaceID
        selectedPageID = snapshot.selectedPageID
    }

    func load() throws {
        guard let repository else {
            return
        }

        let loadedSnapshot = try repository.loadWorkspaceSnapshot()
        apply(snapshot: loadedSnapshot)
    }

    func selectPage(id: String) {
        selectedPageID = id
    }

    func updateBlockText(blockID: String, text: String) throws {
        if let repository {
            try repository.updateBlockText(blockID: blockID, text: text)
        }

        snapshot = snapshot.replacingBlockText(blockID: blockID, text: text)
    }

    func editBlockText(blockID: String, text: String) {
        do {
            try updateBlockText(blockID: blockID, text: text)
            EditorLog.input.debug(
                "block_edit_saved id=\(blockID, privacy: .public) length=\(text.count, privacy: .public)"
            )
        } catch {
            EditorLog.input.error(
                "block_edit_failed id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    private func apply(snapshot: WorkspaceSnapshot) {
        self.snapshot = snapshot
        selectedWorkspaceID = snapshot.selectedWorkspaceID
        selectedPageID = snapshot.selectedPageID
    }
}
