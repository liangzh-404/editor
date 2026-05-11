import Foundation

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published private(set) var snapshot: WorkspaceSnapshot
    @Published private(set) var selectedWorkspaceID: String?
    @Published private(set) var selectedNotebookID: String?
    @Published private(set) var selectedPageID: String?
    @Published private(set) var searchQuery = ""
    @Published private(set) var searchResults: [SearchResult] = []
    @Published private(set) var selectedPageBacklinks: [Backlink] = []
    @Published private(set) var cloudKitAccountStatus: CloudKitAccountAvailability?
    @Published private(set) var syncStatusText = "Sync Idle"
    @Published private(set) var pendingFocusBlockID: String?
    @Published private(set) var pendingCompactPageNavigationID: String?

    private let repository: PageRepository?
    private let attachmentRepository: AttachmentRepository?
    private let searchRepository: SearchRepository?
    private let backlinkRepository: BacklinkRepository?
    private let syncEngine: SyncEngine?
    private let cloudKitAccountMetadataService: CloudKitAccountMetadataService?

    var selectedPage: PageSummary? {
        guard let selectedPageID else {
            return nil
        }
        return snapshot.pages.first { $0.id == selectedPageID }
    }

    var selectedNotebook: NotebookSummary? {
        guard let selectedNotebookID else {
            return nil
        }
        return snapshot.notebooks.first { $0.id == selectedNotebookID }
    }

    var visibleBlocks: [BlockSnapshot] {
        guard let selectedPageID else {
            return []
        }
        return snapshot.blocks.filter { $0.pageID == selectedPageID }
    }

    var cloudKitAccountStatusText: String {
        switch cloudKitAccountStatus {
        case .available:
            return "iCloud Available"
        case .noAccount:
            return "iCloud No Account"
        case .restricted:
            return "iCloud Restricted"
        case .couldNotDetermine:
            return "iCloud Unknown"
        case .temporarilyUnavailable:
            return "iCloud Unavailable"
        case nil:
            return "iCloud Not Checked"
        }
    }

    init(
        repository: PageRepository,
        attachmentRepository: AttachmentRepository? = nil,
        searchRepository: SearchRepository? = nil,
        backlinkRepository: BacklinkRepository? = nil,
        syncEngine: SyncEngine? = nil,
        cloudKitAccountMetadataService: CloudKitAccountMetadataService? = nil
    ) {
        self.repository = repository
        self.attachmentRepository = attachmentRepository
        self.searchRepository = searchRepository
        self.backlinkRepository = backlinkRepository
        self.syncEngine = syncEngine
        self.cloudKitAccountMetadataService = cloudKitAccountMetadataService
        snapshot = .empty
        selectedWorkspaceID = nil
        selectedNotebookID = nil
        selectedPageID = nil
        pendingFocusBlockID = nil
        pendingCompactPageNavigationID = nil
    }

    init(snapshot: WorkspaceSnapshot) {
        repository = nil
        attachmentRepository = nil
        searchRepository = nil
        backlinkRepository = nil
        syncEngine = nil
        cloudKitAccountMetadataService = nil
        self.snapshot = snapshot
        selectedWorkspaceID = snapshot.selectedWorkspaceID
        selectedNotebookID = snapshot.selectedNotebookID
        selectedPageID = snapshot.selectedPageID
        pendingFocusBlockID = nil
        pendingCompactPageNavigationID = nil
    }

    func load() throws {
        guard let repository else {
            return
        }

        let loadedSnapshot = try repository.loadWorkspaceSnapshot()
        apply(snapshot: loadedSnapshot)
        try refreshDerivedState(rebuildSearchIndex: true)
    }

    func refreshCloudKitAccountStatus() throws {
        guard let cloudKitAccountMetadataService else {
            return
        }

        cloudKitAccountStatus = try cloudKitAccountMetadataService.refreshAndStoreStatus()
    }

    func refreshCloudKitAccountStatusForUI() {
        do {
            try refreshCloudKitAccountStatus()
        } catch {
            cloudKitAccountStatus = .couldNotDetermine
            EditorLog.sync.error(
                "cloudkit_account_status_failed error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func syncNow() {
        guard let syncEngine else {
            syncStatusText = "Sync Unavailable"
            return
        }

        do {
            let summary = try syncEngine.uploadPendingChanges()
            let fetchSummary = try syncEngine.fetchRemoteChanges()
            if summary.failedCount > 0 {
                syncStatusText = "Sync Retry Scheduled"
            } else if fetchSummary.appliedCount > 0 {
                syncStatusText = "Synced \(fetchSummary.appliedCount) remote \(fetchSummary.appliedCount == 1 ? "change" : "changes")"
            } else {
                syncStatusText = "Synced \(summary.uploadedCount) \(summary.uploadedCount == 1 ? "change" : "changes")"
            }
            try load()
        } catch {
            syncStatusText = "Sync Failed"
            EditorLog.sync.error(
                "sync_now_failed error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func selectPage(id: String) {
        selectedPageID = id
        selectedNotebookID = snapshot.pages.first { $0.id == id }?.notebookID ?? selectedNotebookID
        refreshBacklinksForSelectedPage()
    }

    func selectSearchResult(_ result: SearchResult) {
        guard let destinationPageID = result.destinationPageID else {
            EditorLog.render.debug(
                "search_result_selection_ignored entity_type=\(result.entityType, privacy: .public) entity_id=\(result.entityID, privacy: .public)"
            )
            return
        }

        selectPage(id: destinationPageID)
        pendingCompactPageNavigationID = destinationPageID
        EditorLog.render.debug(
            "search_result_selected page_id=\(destinationPageID, privacy: .public) entity_type=\(result.entityType, privacy: .public)"
        )
    }

    func selectBacklink(_ backlink: Backlink) {
        selectPage(id: backlink.sourcePageID)
        pendingCompactPageNavigationID = backlink.sourcePageID
        EditorLog.render.debug(
            "backlink_selected source_page_id=\(backlink.sourcePageID, privacy: .public)"
        )
    }

    @discardableResult
    func consumePendingFocusBlockID() -> String? {
        defer {
            pendingFocusBlockID = nil
        }
        return pendingFocusBlockID
    }

    @discardableResult
    func consumePendingCompactPageNavigationID() -> String? {
        defer {
            pendingCompactPageNavigationID = nil
        }
        return pendingCompactPageNavigationID
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
        try refreshDerivedState(rebuildSearchIndex: true)
    }

    func updateSelectedPageTitle(_ title: String) throws {
        guard let selectedPageID else {
            throw WorkspaceViewModelError.missingSelection
        }

        if let repository {
            try repository.updatePageTitle(pageID: selectedPageID, title: title)
        }

        snapshot = snapshot.replacingPageTitle(pageID: selectedPageID, title: title)
        try refreshDerivedState(rebuildSearchIndex: true)
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

    func editSelectedPageTitle(_ title: String) {
        do {
            try updateSelectedPageTitle(title)
            EditorLog.input.debug(
                "page_title_edit_saved length=\(title.count, privacy: .public)"
            )
        } catch {
            EditorLog.input.error(
                "page_title_edit_failed error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    @discardableResult
    func appendParagraphBlockToCurrentPage() throws -> BlockSnapshot {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedPageID else {
            throw WorkspaceViewModelError.missingSelection
        }

        let block = try repository.appendBlock(
            pageID: selectedPageID,
            type: .paragraph,
            text: ""
        )
        try load()
        return block
    }

    @discardableResult
    func createPageInSelectedWorkspace(
        title: String = "Untitled",
        notebookID: String? = nil
    ) throws -> PageSummary {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedWorkspaceID else {
            throw WorkspaceViewModelError.missingSelection
        }

        let page = try repository.createPage(
            workspaceID: selectedWorkspaceID,
            title: title,
            notebookID: notebookID ?? selectedNotebookID
        )
        try load()
        selectPage(id: page.id)
        requestFocusForInitialEmptyBlockIfNeeded(source: "page_create")
        return page
    }

    @discardableResult
    func createNotebookInSelectedWorkspace(name: String = "New Notebook") throws -> NotebookSummary {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedWorkspaceID else {
            throw WorkspaceViewModelError.missingSelection
        }

        let notebook = try repository.createNotebook(workspaceID: selectedWorkspaceID, name: name)
        try load()
        selectedNotebookID = notebook.id
        return notebook
    }

    func selectNotebook(id notebookID: String) {
        guard snapshot.notebooks.contains(where: { $0.id == notebookID }) else {
            return
        }

        selectedNotebookID = notebookID
    }

    func renameNotebook(id notebookID: String, name: String) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let previousNotebookID = selectedNotebookID
        let previousPageID = selectedPageID
        try repository.updateNotebookName(notebookID: notebookID, name: name)
        snapshot = snapshot.replacingNotebookName(notebookID: notebookID, name: name)
        restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
    }

    func moveNotebook(id notebookID: String, toIndex: Int) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let previousNotebookID = selectedNotebookID
        let previousPageID = selectedPageID
        try repository.moveNotebook(notebookID: notebookID, toIndex: toIndex)
        try load()
        restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
    }

    func archiveSelectedPage() throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedPageID else {
            throw WorkspaceViewModelError.missingSelection
        }

        try repository.archivePage(pageID: selectedPageID)
        try load()
    }

    func restoreArchivedPage(id pageID: String) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        try repository.restorePage(pageID: pageID)
        try load()
        selectPage(id: pageID)
    }

    func addParagraphBlockToCurrentPage() -> String? {
        do {
            let block = try appendParagraphBlockToCurrentPage()
            EditorLog.input.debug("paragraph_block_added")
            return block.id
        } catch {
            EditorLog.input.error(
                "paragraph_block_add_failed error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    func addPageToSelectedWorkspace(notebookID: String? = nil) -> String? {
        do {
            let page = try createPageInSelectedWorkspace(notebookID: notebookID)
            EditorLog.input.debug("page_added page_id=\(page.id, privacy: .public)")
            return page.id
        } catch {
            EditorLog.input.error(
                "page_add_failed error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    func addNotebookToSelectedWorkspace() -> String? {
        do {
            let notebook = try createNotebookInSelectedWorkspace()
            EditorLog.input.debug("notebook_added notebook_id=\(notebook.id, privacy: .public)")
            return notebook.id
        } catch {
            EditorLog.input.error(
                "notebook_add_failed error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    func renameNotebookForUI(id notebookID: String, name: String) {
        do {
            try renameNotebook(id: notebookID, name: name)
            EditorLog.input.debug("notebook_rename_visible notebook_id=\(notebookID, privacy: .public)")
        } catch {
            EditorLog.input.error(
                "notebook_rename_failed notebook_id=\(notebookID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func moveNotebookForUI(id notebookID: String, toIndex: Int) {
        do {
            try moveNotebook(id: notebookID, toIndex: toIndex)
            EditorLog.input.debug("notebook_move_visible notebook_id=\(notebookID, privacy: .public) target_index=\(toIndex, privacy: .public)")
        } catch {
            EditorLog.input.error(
                "notebook_move_failed notebook_id=\(notebookID, privacy: .public) target_index=\(toIndex, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func archivePageForUI(id pageID: String) {
        let previousSelection = selectedPageID
        selectedPageID = pageID
        do {
            try archiveSelectedPage()
            EditorLog.input.debug("page_archive_visible page_id=\(pageID, privacy: .public)")
        } catch {
            selectedPageID = previousSelection
            EditorLog.input.error(
                "page_archive_failed page_id=\(pageID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func restoreArchivedPageForUI(id pageID: String) {
        do {
            try restoreArchivedPage(id: pageID)
            EditorLog.input.debug("page_restore_visible page_id=\(pageID, privacy: .public)")
        } catch {
            EditorLog.input.error(
                "page_restore_failed page_id=\(pageID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func moveBlock(blockID: String, toIndex: Int) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        try repository.moveBlock(blockID: blockID, toIndex: toIndex)
        try load()
    }

    func deleteBlock(blockID: String) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        try repository.deleteBlock(blockID: blockID)
        try load()
    }

    func moveBlockInCurrentPage(blockID: String, toIndex: Int) {
        do {
            try moveBlock(blockID: blockID, toIndex: toIndex)
        } catch {
            EditorLog.store.error(
                "block_move_failed block_id=\(blockID, privacy: .public) target_index=\(toIndex, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func deleteBlockFromCurrentPage(blockID: String) {
        do {
            try deleteBlock(blockID: blockID)
            EditorLog.store.debug("block_delete_visible block_id=\(blockID, privacy: .public)")
        } catch {
            EditorLog.store.error(
                "block_delete_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func exportCurrentPageMarkdown() -> String {
        MarkdownTransformer.export(blocks: visibleBlocks)
    }

    func importMarkdownToCurrentPage(_ markdown: String) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedPageID else {
            throw WorkspaceViewModelError.missingSelection
        }

        try repository.importMarkdown(pageID: selectedPageID, markdown: markdown)
        try load()
    }

    func importMarkdownFileForCurrentPage(sourceURL: URL) {
        do {
            let markdown = try String(contentsOf: sourceURL, encoding: .utf8)
            try importMarkdownToCurrentPage(markdown)
            EditorLog.markdown.debug(
                "markdown_file_imported source=\(sourceURL.lastPathComponent, privacy: .public)"
            )
        } catch {
            EditorLog.markdown.error(
                "markdown_file_import_failed source=\(sourceURL.lastPathComponent, privacy: .public) error=\(String(describing: error), privacy: .public)"
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

    func updateSearchQuery(_ query: String) {
        searchQuery = query
        refreshSearchResults()
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
        selectedNotebookID = snapshot.selectedNotebookID
        selectedPageID = snapshot.selectedPageID
    }

    private func requestFocusForInitialEmptyBlockIfNeeded(source: String) {
        guard visibleBlocks.count == 1,
              let block = visibleBlocks.first,
              block.type.isTextEditable,
              block.textPlain.isEmpty else {
            return
        }

        pendingFocusBlockID = block.id
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(block.id, privacy: .public) source=\(source, privacy: .public)"
        )
    }

    private func refreshDerivedState(rebuildSearchIndex: Bool) throws {
        if rebuildSearchIndex {
            try searchRepository?.rebuildIndex()
        }
        refreshSearchResults()
        refreshBacklinksForSelectedPage()
    }

    private func refreshSearchResults() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let searchRepository else {
            searchResults = []
            return
        }

        do {
            searchResults = try searchRepository.search(searchQuery)
        } catch {
            searchResults = []
            EditorLog.render.error(
                "search_failed query=\(self.searchQuery, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    private func refreshBacklinksForSelectedPage() {
        guard let selectedPageID, let backlinkRepository else {
            selectedPageBacklinks = []
            return
        }

        do {
            selectedPageBacklinks = try backlinkRepository.backlinks(targetPageID: selectedPageID)
        } catch {
            selectedPageBacklinks = []
            EditorLog.render.error(
                "backlinks_failed page_id=\(selectedPageID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    private func restoreSelection(previousNotebookID: String?, previousPageID: String?) {
        if let previousNotebookID,
           snapshot.notebooks.contains(where: { $0.id == previousNotebookID }) {
            selectedNotebookID = previousNotebookID
        }

        if let previousPageID,
           snapshot.pages.contains(where: { $0.id == previousPageID }) {
            selectedPageID = previousPageID
        }
        refreshBacklinksForSelectedPage()
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
