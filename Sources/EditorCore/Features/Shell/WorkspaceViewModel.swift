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
        let currentType = snapshot.blocks.first { $0.id == blockID }?.type ?? .paragraph
        let nextBlock = nextBlockState(currentType: currentType, text: text)

        if let repository {
            try repository.updateBlock(
                blockID: blockID,
                type: nextBlock.type,
                text: nextBlock.text
            )
        }

        snapshot = snapshot.replacingBlock(
            blockID: blockID,
            type: nextBlock.type,
            text: nextBlock.text
        )
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

    func appendParagraphBlockToCurrentPage() throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedPageID else {
            throw WorkspaceViewModelError.missingSelection
        }

        _ = try repository.appendBlock(
            pageID: selectedPageID,
            type: .paragraph,
            text: ""
        )
        try load()
    }

    func addParagraphBlockToCurrentPage() {
        do {
            try appendParagraphBlockToCurrentPage()
            EditorLog.input.debug("paragraph_block_added")
        } catch {
            EditorLog.input.error(
                "paragraph_block_add_failed error=\(String(describing: error), privacy: .public)"
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

    private func nextBlockState(currentType: BlockType, text: String) -> (type: BlockType, text: String) {
        if let transform = MarkdownTransformer.shortcutTransform(for: text) {
            EditorLog.markdown.debug(
                "markdown_shortcut type=\(transform.type.rawValue, privacy: .public)"
            )
            return (transform.type, transform.textPlain)
        }

        return (currentType, text)
    }
}

enum WorkspaceViewModelError: Error, Equatable {
    case missingRepository
    case missingSelection
}
