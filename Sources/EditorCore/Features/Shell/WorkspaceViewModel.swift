import Foundation

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published private(set) var snapshot: WorkspaceSnapshot
    @Published private(set) var selectedWorkspaceID: String?
    @Published private(set) var selectedPageID: String?

    private let repository: PageRepository?

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

    private func apply(snapshot: WorkspaceSnapshot) {
        self.snapshot = snapshot
        selectedWorkspaceID = snapshot.selectedWorkspaceID
        selectedPageID = snapshot.selectedPageID
    }
}

