import Foundation

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published private(set) var snapshot: WorkspaceSnapshot
    @Published private(set) var selectedWorkspaceID: String?
    @Published private(set) var selectedPageID: String?

    private let repository: PageRepository?
    private let attachmentRepository: AttachmentRepository?

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

    init(repository: PageRepository, attachmentRepository: AttachmentRepository? = nil) {
        self.repository = repository
        self.attachmentRepository = attachmentRepository
        snapshot = .empty
        selectedWorkspaceID = nil
        selectedPageID = nil
    }

    init(snapshot: WorkspaceSnapshot) {
        repository = nil
        attachmentRepository = nil
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

    func importAttachment(sourceURL: URL) throws {
        guard repository != nil, let attachmentRepository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedWorkspaceID, let selectedPageID else {
            throw WorkspaceViewModelError.missingSelection
        }

        _ = try attachmentRepository.importAttachment(
            sourceURL: sourceURL,
            workspaceID: selectedWorkspaceID,
            pageID: selectedPageID
        )
        try load()
    }

    func importAttachmentForCurrentPage(sourceURL: URL) {
        do {
            try importAttachment(sourceURL: sourceURL)
            EditorLog.attachment.debug("attachment_import_visible source=\(sourceURL.lastPathComponent, privacy: .public)")
        } catch {
            EditorLog.attachment.error(
                "attachment_import_failed source=\(sourceURL.lastPathComponent, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    private func apply(snapshot: WorkspaceSnapshot) {
        self.snapshot = snapshot
        selectedWorkspaceID = snapshot.selectedWorkspaceID
        selectedPageID = snapshot.selectedPageID
    }
}

enum WorkspaceViewModelError: Error, Equatable {
    case missingRepository
    case missingSelection
}
