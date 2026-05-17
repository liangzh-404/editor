import Foundation

struct PageOutlineItem: Identifiable, Equatable, Sendable {
    let blockID: String
    let title: String
    let level: Int

    var id: String {
        blockID
    }
}

enum WorkspaceCollection: Equatable, Hashable, Sendable {
    case recent
    case diary
    case allDocuments
    case favorites
    case tag(String)
    case search
    case archive
}

enum AttachmentPreviewGenerationStatus: Equatable, Sendable {
    case idle
    case generating
    case failed(String)
}

private struct PageNavigationHistoryEntry: Equatable {
    let pageID: String
    let collection: WorkspaceCollection
}

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published private(set) var snapshot: WorkspaceSnapshot
    @Published private(set) var selectedWorkspaceID: String?
    @Published private(set) var selectedNotebookID: String?
    @Published private(set) var selectedPageID: String?
    @Published private(set) var selectedCollection: WorkspaceCollection = .recent
    @Published private(set) var activeDiaryEntry: DiaryEntrySnapshot?
    @Published private(set) var searchQuery = ""
    @Published private(set) var searchResults: [SearchResult] = []
    @Published private(set) var selectedPageBacklinks: [Backlink] = []
    @Published private(set) var selectedPageExternalLinks: [ExternalLink] = []
    @Published private(set) var selectedPageConflicts: [ConflictSnapshot] = []
    @Published private(set) var cloudKitAccountStatus: CloudKitAccountAvailability?
    @Published private(set) var syncStatusText = "同步空闲"
    @Published private(set) var pendingFocusBlockID: String?
    @Published private(set) var pendingCompactPageNavigationID: String?
    @Published private(set) var canUndoTextEdit = false
    @Published private(set) var canUndoPageArchive = false
    @Published private(set) var attachmentPreviewGenerationStatuses: [String: AttachmentPreviewGenerationStatus] = [:]
    @Published private(set) var markdownImportStatusText: String?

    private let repository: PageRepository?
    private let diaryRepository: DiaryRepository?
    private let tagRepository: TagRepository?
    private let attachmentRepository: AttachmentRepository?
    private let attachmentThumbnailScheduler: AttachmentThumbnailScheduling?
    private let searchRepository: SearchRepository?
    private let backlinkRepository: BacklinkRepository?
    private let conflictRepository: ConflictRepository?
    private let syncEngine: SyncEngine?
    private let cloudKitAccountMetadataService: CloudKitAccountMetadataService?
    private let currentDateProvider: () -> Date
    private let diaryCalendar: Calendar
    private var hasLoadedSnapshot = false
    private var didRequestInitialEditorFocus = false
    private var didRequestInitialCompactPageNavigation = false
    private var textEditUndoStack: [TextEditUndoSnapshot] = []
    private var pageArchiveUndoStack: [PageArchiveUndoSnapshot] = []
    private var pageNavigationBackStack: [PageNavigationHistoryEntry] = []
    private var pageNavigationForwardStack: [PageNavigationHistoryEntry] = []

    var canNavigateBack: Bool {
        !pageNavigationBackStack.isEmpty || selectedPageParentLink != nil
    }

    var canNavigateForward: Bool {
        !pageNavigationForwardStack.isEmpty
    }

    var selectedPage: PageSummary? {
        guard let selectedPageID else {
            return nil
        }
        return snapshot.pages.first { $0.id == selectedPageID }
    }

    var selectedPageParentLink: PageParentLink? {
        guard let selectedPageID else {
            return nil
        }

        return snapshot.pageParentLinks.first { $0.childPageID == selectedPageID }
    }

    var selectedPageTagNames: [String] {
        guard let selectedPageID else {
            return []
        }
        let tagIDs = Set(
            snapshot.pageTags
                .filter { $0.pageID == selectedPageID }
                .map(\.tagID)
        )
        return snapshot.tags
            .filter { tagIDs.contains($0.id) }
            .map(\.name)
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

    var editorVisibleBlocks: [BlockSnapshot] {
        guard let selectedPageID else {
            return []
        }
        return editorVisibleBlocks(for: selectedPageID)
    }

    var visibleDocumentPages: [PageSummary] {
        switch selectedCollection {
        case .recent:
            return snapshot.pages
        case .diary:
            return snapshot.pages.filter { diaryPageIDs.contains($0.id) }
        case .allDocuments:
            return snapshot.pages.filter { !diaryPageIDs.contains($0.id) }
        case .favorites:
            return snapshot.favoritePages
        case .tag(let tagID):
            guard !tagID.isEmpty else {
                return []
            }
            let pageIDs = Set(
                snapshot.pageTags
                    .filter { $0.tagID == tagID }
                    .map(\.pageID)
            )
            return snapshot.pages.filter { pageIDs.contains($0.id) }
        case .search:
            return []
        case .archive:
            return snapshot.archivedPages
        }
    }

    var selectedPageOutline: [PageOutlineItem] {
        visibleBlocks.compactMap { block in
            let title = block.textPlain.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let level = block.type.headingLevel, !title.isEmpty else {
                return nil
            }

            return PageOutlineItem(blockID: block.id, title: title, level: level)
        }
    }

    var cloudKitAccountStatusText: String {
        switch cloudKitAccountStatus {
        case .available:
            return "iCloud 可用"
        case .noAccount:
            return "iCloud 未登录"
        case .restricted:
            return "iCloud 受限"
        case .couldNotDetermine:
            return "iCloud 状态未知"
        case .temporarilyUnavailable:
            return "iCloud 暂不可用"
        case nil:
            return "iCloud 未检查"
        }
    }

    init(
        repository: PageRepository,
        diaryRepository: DiaryRepository? = nil,
        tagRepository: TagRepository? = nil,
        attachmentRepository: AttachmentRepository? = nil,
        attachmentThumbnailScheduler: AttachmentThumbnailScheduling? = DispatchAttachmentThumbnailScheduler(),
        searchRepository: SearchRepository? = nil,
        backlinkRepository: BacklinkRepository? = nil,
        conflictRepository: ConflictRepository? = nil,
        syncEngine: SyncEngine? = nil,
        cloudKitAccountMetadataService: CloudKitAccountMetadataService? = nil,
        currentDateProvider: @escaping () -> Date = Date.init,
        diaryCalendar: Calendar = .current
    ) {
        self.repository = repository
        self.diaryRepository = diaryRepository
        self.tagRepository = tagRepository
        self.attachmentRepository = attachmentRepository
        self.attachmentThumbnailScheduler = attachmentThumbnailScheduler
        self.searchRepository = searchRepository
        self.backlinkRepository = backlinkRepository
        self.conflictRepository = conflictRepository
        self.syncEngine = syncEngine
        self.cloudKitAccountMetadataService = cloudKitAccountMetadataService
        self.currentDateProvider = currentDateProvider
        self.diaryCalendar = diaryCalendar
        snapshot = .empty
        selectedWorkspaceID = nil
        selectedNotebookID = nil
        selectedPageID = nil
        selectedCollection = .recent
        activeDiaryEntry = nil
        pendingFocusBlockID = nil
        pendingCompactPageNavigationID = nil
        canUndoTextEdit = false
        canUndoPageArchive = false
        attachmentPreviewGenerationStatuses = [:]
    }

    init(snapshot: WorkspaceSnapshot) {
        repository = nil
        diaryRepository = nil
        tagRepository = nil
        attachmentRepository = nil
        attachmentThumbnailScheduler = nil
        searchRepository = nil
        backlinkRepository = nil
        conflictRepository = nil
        syncEngine = nil
        cloudKitAccountMetadataService = nil
        currentDateProvider = Date.init
        diaryCalendar = .current
        self.snapshot = snapshot
        selectedWorkspaceID = snapshot.selectedWorkspaceID
        selectedNotebookID = snapshot.selectedNotebookID
        selectedPageID = snapshot.selectedPageID
        selectedCollection = snapshot.selectedPageID == nil ? .diary : .recent
        activeDiaryEntry = snapshot.activeDiaryEntry
        pendingFocusBlockID = nil
        pendingCompactPageNavigationID = nil
        canUndoTextEdit = false
        canUndoPageArchive = false
        attachmentPreviewGenerationStatuses = [:]
    }

    func load() throws {
        guard let repository else {
            return
        }

        let previousSelectedCollection = selectedCollection
        let previousSelectedPageID = selectedPageID
        let shouldRestorePreviousSelection = hasLoadedSnapshot
        let loadedSnapshot = try repository.loadWorkspaceSnapshot()
        let shouldOpenDiary = diaryRepository != nil
            && (previousSelectedCollection == .diary || loadedSnapshot.selectedPageID == nil)
        apply(snapshot: loadedSnapshot)
        if shouldOpenDiary {
            try openDailyDiaryPage(source: "load", recordHistory: false)
        } else if shouldRestorePreviousSelection {
            restoreSelectionAfterReload(
                collection: previousSelectedCollection,
                pageID: previousSelectedPageID
            )
        }
        hasLoadedSnapshot = true
        if try extractInlineHashTagsFromSnapshotIfNeeded() {
            let currentCollection = selectedCollection
            let currentPageID = selectedPageID
            let loadedSnapshot = try repository.loadWorkspaceSnapshot()
            apply(snapshot: loadedSnapshot)
            restoreSelectionAfterReload(collection: currentCollection, pageID: currentPageID)
        }
        try refreshDerivedState(rebuildSearchIndex: true)
        requestInitialEditorFocusIfNeeded(source: "load")
        requestInitialCompactPageNavigationIfNeeded(source: "load")
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
            syncStatusText = "同步不可用"
            return
        }

        ensureRemoteChangeSubscriptionForUI()

        do {
            let summary = try syncEngine.uploadPendingChanges()
            let fetchSummary = try syncEngine.fetchRemoteChanges()
            if summary.failedCount > 0 {
                syncStatusText = "已安排同步重试"
            } else if fetchSummary.appliedCount > 0 {
                syncStatusText = "已同步 \(fetchSummary.appliedCount) 条远端变更"
            } else {
                syncStatusText = "已同步 \(summary.uploadedCount) 条变更"
            }
            try load()
        } catch {
            syncStatusText = "同步失败"
            EditorLog.sync.error(
                "sync_now_failed error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func syncAfterActivation() {
        if cloudKitAccountMetadataService != nil {
            refreshCloudKitAccountStatusForUI()
        }

        guard syncEngine != nil else {
            return
        }
        syncNow()
    }

    func selectPage(id: String) {
        selectPage(id: id, collection: defaultCollectionForOpeningPage(id: id), recordHistory: true)
    }

    private func selectPage(
        id: String,
        collection: WorkspaceCollection,
        recordHistory: Bool
    ) {
        if recordHistory {
            recordNavigationHistoryBeforeOpening(pageID: id)
        }
        selectedPageID = id
        selectedCollection = collection
        selectedNotebookID = snapshot.pages.first { $0.id == id }?.notebookID ?? selectedNotebookID
        refreshBacklinksForSelectedPage()
        refreshExternalLinksForSelectedPage()
        refreshConflictsForSelectedPage()
    }

    private var diaryPageIDs: Set<String> {
        Set(snapshot.diaryPages.map(\.pageID))
    }

    private func defaultCollectionForOpeningPage(id pageID: String) -> WorkspaceCollection {
        switch selectedCollection {
        case .diary where diaryPageIDs.contains(pageID):
            return .diary
        case .recent where snapshot.pages.contains(where: { $0.id == pageID }):
            return .recent
        case .allDocuments where snapshot.pages.contains(where: { $0.id == pageID }) && !diaryPageIDs.contains(pageID):
            return .allDocuments
        case .favorites where snapshot.favoritePages.contains(where: { $0.id == pageID }):
            return .favorites
        case .tag(let tagID) where snapshot.pageTags.contains(where: { $0.pageID == pageID && $0.tagID == tagID }):
            return .tag(tagID)
        case .archive where snapshot.archivedPages.contains(where: { $0.id == pageID }):
            return .archive
        default:
            return .allDocuments
        }
    }

    func selectCollection(_ collection: WorkspaceCollection) {
        selectedCollection = collection
        if collection == .diary {
            do {
                try openDailyDiaryPage(source: "collection_select", recordHistory: true)
            } catch {
                selectedPageID = nil
                selectedPageBacklinks = []
                selectedPageExternalLinks = []
                selectedPageConflicts = []
                EditorLog.render.error(
                    "daily_page_open_failed error=\(String(describing: error), privacy: .public)"
                )
            }
        } else if let selectedPageID,
                  !canRestoreSelection(pageID: selectedPageID, in: collection) {
            self.selectedPageID = visibleDocumentPages.first?.id
            refreshBacklinksForSelectedPage()
            refreshExternalLinksForSelectedPage()
            refreshConflictsForSelectedPage()
        }
    }

    private func recordNavigationHistoryBeforeOpening(pageID destinationPageID: String) {
        guard let selectedPageID, selectedPageID != destinationPageID else {
            return
        }
        pageNavigationBackStack.append(
            PageNavigationHistoryEntry(pageID: selectedPageID, collection: selectedCollection)
        )
        pageNavigationForwardStack = []
    }

    func updateDiaryText(_ text: String) throws {
        guard let diaryRepository else {
            throw WorkspaceViewModelError.missingDiaryRepository
        }
        guard let activeDiaryEntry else {
            throw WorkspaceViewModelError.missingSelection
        }

        try diaryRepository.updateEntryText(entryID: activeDiaryEntry.id, text: text)
        self.activeDiaryEntry = DiaryEntrySnapshot(
            id: activeDiaryEntry.id,
            workspaceID: activeDiaryEntry.workspaceID,
            textPlain: text
        )
        selectedCollection = .diary
    }

    func promoteSelectedDiaryTextToPage(_ selectedText: String) throws {
        guard let diaryRepository else {
            throw WorkspaceViewModelError.missingDiaryRepository
        }
        guard let activeDiaryEntry else {
            throw WorkspaceViewModelError.missingSelection
        }

        let page = try diaryRepository.promoteTextToPage(
            entryID: activeDiaryEntry.id,
            selectedText: selectedText
        )
        try load()
        selectPage(id: page.id)
        requestFocusForInitialEmptyBlockIfNeeded(source: "diary_promote")
    }

    func assignTagsToSelectedPage(_ tagIDs: [String]) throws {
        guard let repository, let tagRepository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedPageID else {
            throw WorkspaceViewModelError.missingSelection
        }

        let previousSelectedPageID = selectedPageID
        let previousSelectedCollection = selectedCollection
        try tagRepository.assignTags(pageID: selectedPageID, tagIDs: tagIDs)
        let loadedSnapshot = try repository.loadWorkspaceSnapshot()
        apply(snapshot: loadedSnapshot)
        if snapshot.pages.contains(where: { $0.id == previousSelectedPageID }) {
            self.selectedPageID = previousSelectedPageID
        }
        selectedCollection = previousSelectedCollection
        refreshBacklinksForSelectedPage()
        refreshExternalLinksForSelectedPage()
        refreshConflictsForSelectedPage()
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

    func selectOutlineItem(_ item: PageOutlineItem) {
        pendingFocusBlockID = item.blockID
        pendingCompactPageNavigationID = selectedPageID
        EditorLog.focus.debug(
            "outline_item_selected block_id=\(item.blockID, privacy: .public)"
        )
    }

    func openPageReference(targetPageID: String) {
        selectPage(id: targetPageID)
        pendingCompactPageNavigationID = targetPageID
        EditorLog.render.debug("page_reference_opened target_page_id=\(targetPageID, privacy: .public)")
    }

    @discardableResult
    func openParentPageForCurrentPage() throws -> Bool {
        guard let parentLink = selectedPageParentLink else {
            return false
        }
        guard snapshot.pages.contains(where: { $0.id == parentLink.parentPageID }) else {
            return false
        }

        selectPage(id: parentLink.parentPageID, collection: .allDocuments, recordHistory: false)
        pendingFocusBlockID = parentLink.sourceBlockID
        pendingCompactPageNavigationID = parentLink.parentPageID
        EditorLog.render.debug(
            "parent_page_opened parent_page_id=\(parentLink.parentPageID, privacy: .public) child_page_id=\(parentLink.childPageID, privacy: .public)"
        )
        return true
    }

    func openParentPageForCurrentPageForUI() -> Bool {
        do {
            return try openParentPageForCurrentPage()
        } catch {
            EditorLog.render.error(
                "parent_page_open_failed error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func openTodayForUI() -> Bool {
        do {
            return try openDailyDiaryPage(source: "shortcut_today", recordHistory: true) != nil
        } catch {
            EditorLog.render.error(
                "daily_page_shortcut_open_failed error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func createNewDocumentForUI() -> Bool {
        do {
            _ = try createPageInSelectedWorkspace(title: "未命名")
            return true
        } catch {
            EditorLog.input.error(
                "new_document_shortcut_failed error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func createNewDocumentForCompactUI() -> String? {
        do {
            let page = try createPageInSelectedWorkspace(title: "未命名")
            pendingCompactPageNavigationID = page.id
            EditorLog.render.debug(
                "compact_page_navigation_queued page_id=\(page.id, privacy: .public) source=compact_new_document"
            )
            return page.id
        } catch {
            EditorLog.input.error(
                "compact_new_document_failed error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    func navigateBackForUI() -> Bool {
        do {
            return try navigateBack()
        } catch {
            EditorLog.render.error(
                "page_navigation_back_failed error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func navigateForwardForUI() -> Bool {
        navigateForward()
    }

    @discardableResult
    func navigateBack() throws -> Bool {
        if let currentPageID = selectedPageID,
           let currentParentLink = selectedPageParentLink {
            let currentEntry = PageNavigationHistoryEntry(
                pageID: currentPageID,
                collection: selectedCollection
            )
            let didOpenParent = try openParentPageForCurrentPage()
            if didOpenParent {
                if pageNavigationBackStack.last?.pageID == currentParentLink.parentPageID {
                    _ = pageNavigationBackStack.popLast()
                }
                pageNavigationForwardStack.append(currentEntry)
                return true
            }
        }

        while let previousEntry = pageNavigationBackStack.popLast() {
            guard canRestoreSelection(pageID: previousEntry.pageID, in: previousEntry.collection) else {
                continue
            }

            if let selectedPageID {
                pageNavigationForwardStack.append(
                    PageNavigationHistoryEntry(pageID: selectedPageID, collection: selectedCollection)
                )
            }
            selectPage(
                id: previousEntry.pageID,
                collection: previousEntry.collection,
                recordHistory: false
            )
            pendingCompactPageNavigationID = previousEntry.pageID
            return true
        }

        return try openParentPageForCurrentPage()
    }

    @discardableResult
    func navigateForward() -> Bool {
        while let nextEntry = pageNavigationForwardStack.popLast() {
            guard canRestoreSelection(pageID: nextEntry.pageID, in: nextEntry.collection) else {
                continue
            }

            if let selectedPageID {
                pageNavigationBackStack.append(
                    PageNavigationHistoryEntry(pageID: selectedPageID, collection: selectedCollection)
                )
            }
            selectPage(id: nextEntry.pageID, collection: nextEntry.collection, recordHistory: false)
            pendingCompactPageNavigationID = nextEntry.pageID
            return true
        }

        return false
    }

    func openBlockReference(targetPageID: String, targetBlockID: String) {
        selectPage(id: targetPageID)
        pendingFocusBlockID = targetBlockID
        pendingCompactPageNavigationID = targetPageID
        EditorLog.render.debug(
            "block_reference_opened target_page_id=\(targetPageID, privacy: .public) target_block_id=\(targetBlockID, privacy: .public)"
        )
    }

    func editorVisibleBlocks(for pageID: String) -> [BlockSnapshot] {
        let pageBlocks = snapshot.blocks.filter { $0.pageID == pageID }
        var hiddenBlockIDs: Set<String> = []
        var filteredBlocks: [BlockSnapshot] = []
        let blocksByID = Dictionary(uniqueKeysWithValues: pageBlocks.map { ($0.id, $0) })

        for block in pageBlocks {
            if let parentBlockID = block.parentBlockID,
               hiddenBlockIDs.contains(parentBlockID) || isCollapsedToggleBlock(blocksByID[parentBlockID]) {
                hiddenBlockIDs.insert(block.id)
                continue
            }

            filteredBlocks.append(block)
        }

        return filteredBlocks
    }

    func isToggleBlockExpanded(blockID: String) -> Bool {
        guard let block = snapshot.blocks.first(where: { $0.id == blockID && $0.type == .toggle }) else {
            return false
        }

        return block.toggleIsExpanded
    }

    func isCodeBlockLineWrappingEnabled(blockID: String) -> Bool {
        guard let block = snapshot.blocks.first(where: { $0.id == blockID && $0.type == .codeBlock }) else {
            return true
        }

        return block.codeBlockLineWrapping
    }

    func updateCodeBlockLineWrapping(blockID: String, isWrapped: Bool) {
        guard let block = snapshot.blocks.first(where: { $0.id == blockID && $0.type == .codeBlock }),
              block.codeBlockLineWrapping != isWrapped else {
            return
        }

        do {
            try repository?.updateCodeBlockLineWrapping(blockID: blockID, isWrapped: isWrapped)
        } catch {
            EditorLog.render.error(
                "code_block_line_wrapping_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return
        }
        snapshot = snapshot.replacingCodeBlockLineWrapping(blockID: blockID, isWrapped: isWrapped)
        pendingFocusBlockID = blockID
        EditorLog.render.debug(
            "code_block_line_wrapping_changed block_id=\(blockID, privacy: .public) wrapped=\(isWrapped, privacy: .public)"
        )
    }

    func toggleBlockExpansion(blockID: String) {
        guard let block = snapshot.blocks.first(where: { $0.id == blockID && $0.type == .toggle }) else {
            return
        }

        let isExpanded = !block.toggleIsExpanded
        do {
            try repository?.updateToggleExpansion(blockID: blockID, isExpanded: isExpanded)
        } catch {
            EditorLog.render.error(
                "toggle_block_expansion_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return
        }
        snapshot = snapshot.replacingToggleExpansion(blockID: blockID, isExpanded: isExpanded)
        pendingFocusBlockID = blockID
        EditorLog.render.debug(
            "toggle_block_expansion_changed block_id=\(blockID, privacy: .public) expanded=\(isExpanded, privacy: .public)"
        )
    }

    private func isCollapsedToggleBlock(_ block: BlockSnapshot?) -> Bool {
        block?.type == .toggle && block?.toggleIsExpanded == false
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
        try updateBlockText(blockID: blockID, text: text, registerUndo: true)
    }

    @discardableResult
    func insertMarkdownLink(blockID: String, label: String, url: String) throws -> Bool {
        guard let linkMarkdown = MarkdownInlineLinkComposer.markdown(label: label, url: url),
              let block = snapshot.blocks.first(where: { $0.id == blockID }),
              block.type.isTextEditable else {
            return false
        }

        let separator = block.textPlain.isEmpty || block.textPlain.last?.isWhitespace == true ? "" : " "
        try updateBlockText(blockID: blockID, text: "\(block.textPlain)\(separator)\(linkMarkdown)")
        pendingFocusBlockID = blockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(blockID, privacy: .public) source=inline_link_insert"
        )
        return true
    }

    @discardableResult
    func insertMarkdownLink(
        blockID: String,
        label: String,
        url: String,
        selection: EditorTextSelection
    ) throws -> EditorTextSelection? {
        guard selection.blockID == blockID,
              let block = snapshot.blocks.first(where: { $0.id == blockID }),
              block.type.isTextEditable,
              let linkResult = MarkdownInlineLinkInserter.apply(
                label: label,
                url: url,
                to: block.textPlain,
                selection: selection
              ) else {
            return nil
        }

        try updateBlockText(blockID: blockID, text: linkResult.text)
        pendingFocusBlockID = blockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(blockID, privacy: .public) source=inline_link_insert_selection"
        )
        return linkResult.selection
    }

    @discardableResult
    func removeMarkdownLink(blockID: String, selection: EditorTextSelection) throws -> EditorTextSelection? {
        guard selection.blockID == blockID,
              let block = snapshot.blocks.first(where: { $0.id == blockID }),
              block.type.isTextEditable,
              let linkTarget = MarkdownInlineLinkEditTarget.target(in: block.textPlain, selection: selection),
              let linkResult = MarkdownInlineLinkRemover.apply(to: block.textPlain, target: linkTarget) else {
            return nil
        }

        try updateBlockText(blockID: blockID, text: linkResult.text)
        pendingFocusBlockID = blockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(blockID, privacy: .public) source=inline_link_remove_selection"
        )
        return linkResult.selection
    }

    func insertMarkdownLinkForUI(blockID: String, label: String, url: String) -> Bool {
        do {
            let didInsert = try insertMarkdownLink(blockID: blockID, label: label, url: url)
            if didInsert {
                EditorLog.input.debug("markdown_inline_link_inserted block_id=\(blockID, privacy: .public)")
            }
            return didInsert
        } catch {
            EditorLog.input.error(
                "markdown_inline_link_insert_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func insertMarkdownLinkForUI(
        blockID: String,
        label: String,
        url: String,
        selection: EditorTextSelection
    ) -> EditorTextSelection? {
        do {
            let nextSelection = try insertMarkdownLink(
                blockID: blockID,
                label: label,
                url: url,
                selection: selection
            )
            if nextSelection != nil {
                EditorLog.input.debug("markdown_inline_link_inserted block_id=\(blockID, privacy: .public)")
            }
            return nextSelection
        } catch {
            EditorLog.input.error(
                "markdown_inline_link_insert_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    func removeMarkdownLinkForUI(blockID: String, selection: EditorTextSelection) -> EditorTextSelection? {
        do {
            let nextSelection = try removeMarkdownLink(blockID: blockID, selection: selection)
            if nextSelection != nil {
                EditorLog.input.debug("markdown_inline_link_removed block_id=\(blockID, privacy: .public)")
            }
            return nextSelection
        } catch {
            EditorLog.input.error(
                "markdown_inline_link_remove_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    @discardableResult
    func applyMarkdownInlineFormat(
        blockID: String,
        format: MarkdownInlineFormat,
        selection: EditorTextSelection
    ) throws -> EditorTextSelection? {
        guard selection.blockID == blockID,
              let block = snapshot.blocks.first(where: { $0.id == blockID }),
              block.type.isTextEditable,
              let formatResult = MarkdownInlineFormatter.applyResult(format, to: block.textPlain, selection: selection) else {
            return nil
        }

        try updateBlockText(blockID: blockID, text: formatResult.text)
        pendingFocusBlockID = blockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(blockID, privacy: .public) source=inline_markdown_format"
        )
        return formatResult.selection
    }

    func applyMarkdownInlineFormatForUI(
        blockID: String,
        format: MarkdownInlineFormat,
        selection: EditorTextSelection
    ) -> EditorTextSelection? {
        do {
            let nextSelection = try applyMarkdownInlineFormat(blockID: blockID, format: format, selection: selection)
            if nextSelection != nil {
                EditorLog.input.debug("markdown_inline_format_applied block_id=\(blockID, privacy: .public)")
            }
            return nextSelection
        } catch {
            EditorLog.input.error(
                "markdown_inline_format_apply_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    private func updateBlockText(blockID: String, text: String, registerUndo: Bool) throws {
        let currentBlock = snapshot.blocks.first { $0.id == blockID }
        let currentType = currentBlock?.type ?? .paragraph
        let tagExtraction = InlineHashTagExtractor.extract(from: text)
        let nextText = tagExtraction.tagNames.isEmpty ? text : tagExtraction.text
        let nextBlock = nextBlockState(currentType: currentType, text: nextText)
        let undoSnapshot = makeTextEditUndoSnapshot(
            blockID: blockID,
            currentBlock: currentBlock,
            nextType: nextBlock.type,
            nextText: nextBlock.text,
            registerUndo: registerUndo
        )

        if let repository {
            try repository.updateBlock(
                blockID: blockID,
                type: nextBlock.type,
                text: nextBlock.text,
                taskItemIsCompleted: nextBlock.taskItemIsCompleted
            )
        }

        snapshot = snapshot.replacingBlock(
            blockID: blockID,
            type: nextBlock.type,
            text: nextBlock.text
        )
        if let taskItemIsCompleted = nextBlock.taskItemIsCompleted {
            snapshot = snapshot.replacingTaskItemCompletion(
                blockID: blockID,
                isCompleted: taskItemIsCompleted
            )
        }
        if !tagExtraction.tagNames.isEmpty,
           let pageID = currentBlock?.pageID ?? selectedPageID {
            try assignInlineTags(tagExtraction.tagNames, to: pageID)
            if let repository {
                let previousSelectedCollection = selectedCollection
                let previousSelectedPageID = selectedPageID
                let loadedSnapshot = try repository.loadWorkspaceSnapshot()
                apply(snapshot: loadedSnapshot)
                restoreSelectionAfterReload(
                    collection: previousSelectedCollection,
                    pageID: previousSelectedPageID
                )
            }
            pendingFocusBlockID = blockID
            EditorLog.focus.debug(
                "editor_focus_request_queued block_id=\(blockID, privacy: .public) source=inline_tag_extract"
            )
        }
        if currentType != nextBlock.type {
            pendingFocusBlockID = blockID
            EditorLog.focus.debug(
                "editor_focus_request_queued block_id=\(blockID, privacy: .public) source=markdown_shortcut"
            )
        }
        try refreshDerivedState(rebuildSearchIndex: true, changedBlockID: blockID)

        if let undoSnapshot {
            recordTextEditUndoSnapshot(
                undoSnapshot,
                currentBlock: currentBlock,
                nextType: nextBlock.type
            )
            refreshTextEditUndoAvailability()
        }
    }

    func undoLastTextEdit() throws {
        guard let undoSnapshot = textEditUndoStack.last else {
            return
        }

        if let repository {
            try repository.updateBlock(
                blockID: undoSnapshot.blockID,
                type: undoSnapshot.previousType,
                text: undoSnapshot.previousText,
                tableRows: undoSnapshot.previousType == .table ? undoSnapshot.previousTableRows : nil
            )
        }

        snapshot = snapshot.replacingBlock(
            blockID: undoSnapshot.blockID,
            type: undoSnapshot.previousType,
            text: undoSnapshot.previousText
        )
        if undoSnapshot.previousType == .table {
            snapshot = snapshot.replacingTableRows(
                blockID: undoSnapshot.blockID,
                rows: undoSnapshot.previousTableRows,
                text: undoSnapshot.previousText
            )
        }
        try refreshDerivedState(rebuildSearchIndex: true, changedBlockID: undoSnapshot.blockID)
        _ = textEditUndoStack.popLast()
        refreshTextEditUndoAvailability()
        pendingFocusBlockID = undoSnapshot.blockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(undoSnapshot.blockID, privacy: .public) source=text_undo"
        )
    }

    func undoLastTextEditForUI() {
        do {
            try undoLastTextEdit()
            EditorLog.input.debug("text_edit_undo_visible")
        } catch {
            EditorLog.input.error(
                "text_edit_undo_failed error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func changeBlockType(blockID: String, type: BlockType) throws {
        guard let block = snapshot.blocks.first(where: { $0.id == blockID }) else {
            throw PageRepositoryError.blockNotFound
        }

        if let repository {
            try repository.updateBlock(
                blockID: blockID,
                type: type,
                text: block.textPlain
            )
        }

        snapshot = snapshot.replacingBlock(
            blockID: blockID,
            type: type,
            text: block.textPlain
        )
        try refreshDerivedState(rebuildSearchIndex: true, changedBlockID: blockID)
        pendingFocusBlockID = blockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(blockID, privacy: .public) source=block_type_change"
        )
    }

    func updateTableRows(blockID: String, rows: [[String]]) throws {
        guard let currentBlock = snapshot.blocks.first(where: { $0.id == blockID }),
              currentBlock.type == .table else {
            throw PageRepositoryError.blockNotFound
        }

        let table = MarkdownTableDocument(rows: rows)
        let undoSnapshot = makeTextEditUndoSnapshot(
            blockID: blockID,
            currentBlock: currentBlock,
            nextType: .table,
            nextText: table.markdown,
            registerUndo: true
        )

        if let repository {
            try repository.updateBlock(
                blockID: blockID,
                type: .table,
                text: table.markdown,
                tableRows: table.rows
            )
        }

        snapshot = snapshot.replacingTableRows(blockID: blockID, rows: table.rows, text: table.markdown)
        try refreshDerivedState(rebuildSearchIndex: true, changedBlockID: blockID)

        if let undoSnapshot {
            recordTextEditUndoSnapshot(
                undoSnapshot,
                currentBlock: currentBlock,
                nextType: .table
            )
            refreshTextEditUndoAvailability()
        }
    }

    func updateTaskItemCompletion(blockID: String, isCompleted: Bool) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        try repository.updateTaskItemCompletion(blockID: blockID, isCompleted: isCompleted)
        snapshot = snapshot.replacingTaskItemCompletion(blockID: blockID, isCompleted: isCompleted)
        try refreshDerivedState(rebuildSearchIndex: false)
        pendingFocusBlockID = blockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(blockID, privacy: .public) source=task_completion"
        )
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

    func updatePageFavorite(id pageID: String, isFavorite: Bool) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        try repository.updatePageFavorite(pageID: pageID, isFavorite: isFavorite)
        snapshot = snapshot.replacingPageFavorite(pageID: pageID, isFavorite: isFavorite)
        try refreshDerivedState(rebuildSearchIndex: false)
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

    func changeBlockTypeForUI(blockID: String, type: BlockType) {
        do {
            try changeBlockType(blockID: blockID, type: type)
            EditorLog.input.debug(
                "block_type_changed id=\(blockID, privacy: .public) type=\(type.rawValue, privacy: .public)"
            )
        } catch {
            EditorLog.input.error(
                "block_type_change_failed id=\(blockID, privacy: .public) type=\(type.rawValue, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func updateTableRowsForUI(blockID: String, rows: [[String]]) {
        do {
            try updateTableRows(blockID: blockID, rows: rows)
            EditorLog.input.debug("table_rows_updated block_id=\(blockID, privacy: .public)")
        } catch {
            EditorLog.input.error(
                "table_rows_update_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func updateTaskItemCompletionForUI(blockID: String, isCompleted: Bool) {
        do {
            try updateTaskItemCompletion(blockID: blockID, isCompleted: isCompleted)
            EditorLog.input.debug(
                "task_item_completion_updated block_id=\(blockID, privacy: .public) completed=\(isCompleted, privacy: .public)"
            )
        } catch {
            EditorLog.input.error(
                "task_item_completion_update_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
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
    func appendPageReferenceToCurrentPage(targetPageID: String) throws -> String {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedPageID else {
            throw WorkspaceViewModelError.missingSelection
        }

        let previousNotebookID = selectedNotebookID
        let previousPageID = self.selectedPageID
        let block = try repository.appendPageReferenceBlock(
            pageID: selectedPageID,
            targetPageID: targetPageID
        )
        try load()
        restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
        return block.id
    }

    func appendPageReferenceToCurrentPageForUI(targetPageID: String) {
        do {
            let blockID = try appendPageReferenceToCurrentPage(targetPageID: targetPageID)
            EditorLog.input.debug(
                "page_reference_inserted block_id=\(blockID, privacy: .public) target_page_id=\(targetPageID, privacy: .public)"
            )
        } catch {
            EditorLog.input.error(
                "page_reference_insert_failed target_page_id=\(targetPageID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    @discardableResult
    func convertTextBlockToPage(blockID: String) throws -> PageSummary {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let page = try repository.convertTextBlockToPage(blockID: blockID)
        try load()
        selectPage(id: page.id)
        requestFocusForInitialEmptyBlockIfNeeded(source: "block_to_page")
        return page
    }

    func convertTextBlockToPageForUI(blockID: String) {
        do {
            let page = try convertTextBlockToPage(blockID: blockID)
            EditorLog.input.debug(
                "block_converted_to_page block_id=\(blockID, privacy: .public) page_id=\(page.id, privacy: .public)"
            )
        } catch {
            EditorLog.input.error(
                "block_convert_to_page_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    @discardableResult
    func appendBlockReferenceToCurrentPage(targetBlockID: String) throws -> String {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedPageID else {
            throw WorkspaceViewModelError.missingSelection
        }

        let previousNotebookID = selectedNotebookID
        let previousPageID = self.selectedPageID
        let block = try repository.appendBlockReferenceBlock(
            pageID: selectedPageID,
            targetBlockID: targetBlockID
        )
        try load()
        restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
        return block.id
    }

    func appendBlockReferenceToCurrentPageForUI(targetBlockID: String) {
        do {
            let blockID = try appendBlockReferenceToCurrentPage(targetBlockID: targetBlockID)
            EditorLog.input.debug(
                "block_reference_inserted block_id=\(blockID, privacy: .public) target_block_id=\(targetBlockID, privacy: .public)"
            )
        } catch {
            EditorLog.input.error(
                "block_reference_insert_failed target_block_id=\(targetBlockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    @discardableResult
    func createPageInSelectedWorkspace(
        title: String = "未命名",
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
    func createNotebookInSelectedWorkspace(
        name: String = "新建笔记本",
        parentNotebookID: String? = nil
    ) throws -> NotebookSummary {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedWorkspaceID else {
            throw WorkspaceViewModelError.missingSelection
        }

        let notebook = try repository.createNotebook(
            workspaceID: selectedWorkspaceID,
            name: name,
            parentNotebookID: parentNotebookID
        )
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

    func updateNotebookParent(id notebookID: String, parentNotebookID: String?) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let previousNotebookID = selectedNotebookID
        let previousPageID = selectedPageID
        try repository.updateNotebookParent(
            notebookID: notebookID,
            parentNotebookID: parentNotebookID
        )
        try load()
        restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
    }

    @discardableResult
    func indentNotebook(id notebookID: String) throws -> Bool {
        guard let currentIndex = snapshot.notebooks.firstIndex(where: { $0.id == notebookID }),
              currentIndex > 0 else {
            return false
        }

        let parentNotebookID = snapshot.notebooks[currentIndex - 1].id
        try updateNotebookParent(id: notebookID, parentNotebookID: parentNotebookID)
        return true
    }

    @discardableResult
    func outdentNotebook(id notebookID: String) throws -> Bool {
        guard let notebook = snapshot.notebooks.first(where: { $0.id == notebookID }),
              let parentNotebookID = notebook.parentNotebookID else {
            return false
        }

        let grandparentNotebookID = snapshot.notebooks
            .first { $0.id == parentNotebookID }?
            .parentNotebookID
        try updateNotebookParent(id: notebookID, parentNotebookID: grandparentNotebookID)
        return true
    }

    func archiveSelectedPage() throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedPageID else {
            throw WorkspaceViewModelError.missingSelection
        }

        let previousNotebookID = self.selectedNotebookID
        let previousPageID = selectedPageID
        try repository.archivePage(pageID: selectedPageID)
        try load()
        recordPageArchiveUndoSnapshot(
            pageID: selectedPageID,
            previousNotebookID: previousNotebookID,
            previousPageID: previousPageID
        )
    }

    func restoreArchivedPage(id pageID: String) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        try repository.restorePage(pageID: pageID)
        try load()
        removePageArchiveUndoSnapshots(for: pageID)
        selectPage(id: pageID)
    }

    func permanentlyDeleteArchivedPage(id pageID: String) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        try repository.permanentlyDeleteArchivedPage(pageID: pageID)
        try load()
        removePageArchiveUndoSnapshots(for: pageID)
    }

    func undoLastPageArchive() throws {
        guard let undoSnapshot = pageArchiveUndoStack.last else {
            return
        }
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        try repository.restorePage(pageID: undoSnapshot.pageID)
        try load()
        _ = pageArchiveUndoStack.popLast()
        refreshPageArchiveUndoAvailability()
        restoreSelection(
            previousNotebookID: undoSnapshot.previousNotebookID,
            previousPageID: undoSnapshot.previousPageID
        )
    }

    func addParagraphBlockToCurrentPage() -> String? {
        do {
            let block = try appendParagraphBlockToCurrentPage()
            pendingFocusBlockID = block.id
            EditorLog.input.debug("paragraph_block_added")
            EditorLog.focus.debug(
                "editor_focus_request_queued block_id=\(block.id, privacy: .public) source=add_block"
            )
            return block.id
        } catch {
            EditorLog.input.error(
                "paragraph_block_add_failed error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    @discardableResult
    func focusEditorCanvas() throws -> String? {
        guard selectedPageID != nil else {
            return nil
        }

        if let lastBlock = visibleBlocks.last {
            guard lastBlock.type.isTextEditable && lastBlock.type != .table else {
                let block = try appendParagraphBlockToCurrentPage()
                pendingFocusBlockID = block.id
                EditorLog.focus.debug(
                    "editor_focus_request_queued block_id=\(block.id, privacy: .public) source=canvas_tap_created_after_non_text"
                )
                return block.id
            }

            pendingFocusBlockID = lastBlock.id
            EditorLog.focus.debug(
                "editor_focus_request_queued block_id=\(lastBlock.id, privacy: .public) source=canvas_tap"
            )
            return lastBlock.id
        }

        let block = try appendParagraphBlockToCurrentPage()
        pendingFocusBlockID = block.id
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(block.id, privacy: .public) source=canvas_tap_created_block"
        )
        return block.id
    }

    func focusEditorCanvasForUI() -> String? {
        do {
            return try focusEditorCanvas()
        } catch {
            EditorLog.focus.error(
                "editor_canvas_focus_failed error=\(String(describing: error), privacy: .public)"
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

    func addNotebookToSelectedWorkspace(parentNotebookID: String? = nil) -> String? {
        do {
            let notebook = try createNotebookInSelectedWorkspace(parentNotebookID: parentNotebookID)
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

    func updateNotebookParentForUI(id notebookID: String, parentNotebookID: String?) {
        do {
            try updateNotebookParent(id: notebookID, parentNotebookID: parentNotebookID)
            EditorLog.input.debug("notebook_parent_visible notebook_id=\(notebookID, privacy: .public)")
        } catch {
            EditorLog.input.error(
                "notebook_parent_failed notebook_id=\(notebookID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func indentNotebookForUI(id notebookID: String) -> Bool {
        do {
            let didIndent = try indentNotebook(id: notebookID)
            if didIndent {
                EditorLog.input.debug("notebook_indent_visible notebook_id=\(notebookID, privacy: .public)")
            }
            return didIndent
        } catch {
            EditorLog.input.error(
                "notebook_indent_failed notebook_id=\(notebookID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func outdentNotebookForUI(id notebookID: String) -> Bool {
        do {
            let didOutdent = try outdentNotebook(id: notebookID)
            if didOutdent {
                EditorLog.input.debug("notebook_outdent_visible notebook_id=\(notebookID, privacy: .public)")
            }
            return didOutdent
        } catch {
            EditorLog.input.error(
                "notebook_outdent_failed notebook_id=\(notebookID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func archivePageForUI(id pageID: String) {
        let previousSelection = selectedPageID
        do {
            if pageID == selectedPageID {
                try archiveSelectedPage()
            } else {
                try archiveBackgroundPage(id: pageID)
            }
            EditorLog.input.debug("page_archive_visible page_id=\(pageID, privacy: .public)")
        } catch {
            selectedPageID = previousSelection
            EditorLog.input.error(
                "page_archive_failed page_id=\(pageID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func updatePageFavoriteForUI(id pageID: String, isFavorite: Bool) {
        do {
            try updatePageFavorite(id: pageID, isFavorite: isFavorite)
            EditorLog.input.debug(
                "page_favorite_visible page_id=\(pageID, privacy: .public) is_favorite=\(isFavorite, privacy: .public)"
            )
        } catch {
            EditorLog.input.error(
                "page_favorite_failed page_id=\(pageID, privacy: .public) error=\(String(describing: error), privacy: .public)"
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

    func undoLastPageArchiveForUI() {
        do {
            try undoLastPageArchive()
            EditorLog.input.debug("page_archive_undo_visible")
        } catch {
            EditorLog.input.error(
                "page_archive_undo_failed error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func permanentlyDeleteArchivedPageForUI(id pageID: String) {
        do {
            try permanentlyDeleteArchivedPage(id: pageID)
            EditorLog.input.debug("page_delete_visible page_id=\(pageID, privacy: .public)")
        } catch {
            EditorLog.input.error(
                "page_delete_failed page_id=\(pageID, privacy: .public) error=\(String(describing: error), privacy: .public)"
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

    func moveBlocks(blockIDs: [String], toIndex: Int) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        try repository.moveBlocks(blockIDs: blockIDs, toIndex: toIndex)
        try load()
    }

    @discardableResult
    func insertParagraphBlock(after blockID: String) throws -> String {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let block = try repository.insertParagraphBlock(after: blockID)
        try load()
        pendingFocusBlockID = block.id
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(block.id, privacy: .public) source=insert_after"
        )
        return block.id
    }

    @discardableResult
    func splitTextBlockAtSelection(
        blockID: String,
        selection: EditorTextSelection
    ) throws -> EditorTextSelection? {
        guard selection.blockID == blockID,
              let block = snapshot.blocks.first(where: { $0.id == blockID && $0.type.isTextEditable }) else {
            return nil
        }

        let nsText = block.textPlain as NSString
        guard selection.location >= 0,
              selection.length >= 0,
              selection.location <= nsText.length,
              selection.length <= nsText.length - selection.location else {
            return nil
        }

        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let selectedRange = NSRange(location: selection.location, length: selection.length)
        let leadingText = nsText.substring(to: selectedRange.location)
        let trailingText = nsText.substring(from: NSMaxRange(selectedRange))

        try repository.updateBlock(
            blockID: blockID,
            type: block.type,
            text: leadingText,
            taskItemIsCompleted: block.taskItemIsCompleted,
            toggleIsExpanded: block.toggleIsExpanded,
            codeBlockLineWrapping: block.codeBlockLineWrapping
        )
        let insertedBlockType = TextBlockSplitPolicy.insertedBlockType(after: block.type)
        let insertedBlock = try repository.insertParagraphBlock(after: blockID, text: trailingText)
        if insertedBlockType != .paragraph {
            try repository.updateBlock(
                blockID: insertedBlock.id,
                type: insertedBlockType,
                text: trailingText,
                taskItemIsCompleted: false
            )
        }
        try load()
        pendingFocusBlockID = insertedBlock.id
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(insertedBlock.id, privacy: .public) source=split_text_block"
        )
        return EditorTextSelection(blockID: insertedBlock.id, location: 0, length: 0)
    }

    @discardableResult
    func mergeTextBlockWithPreviousAtSelection(
        blockID: String,
        selection: EditorTextSelection
    ) throws -> EditorTextSelection? {
        guard selection.blockID == blockID,
              selection.location == 0,
              selection.length == 0 else {
            return nil
        }

        if let currentBlock = snapshot.blocks.first(where: { $0.id == blockID }),
           currentBlock.type.isTextEditable,
           currentBlock.type.stripsFormattingBeforeLineHeadMerge {
            guard let repository else {
                throw WorkspaceViewModelError.missingRepository
            }
            try repository.updateBlock(
                blockID: blockID,
                type: .paragraph,
                text: currentBlock.textPlain,
                taskItemIsCompleted: false,
                toggleIsExpanded: currentBlock.toggleIsExpanded,
                codeBlockLineWrapping: currentBlock.codeBlockLineWrapping
            )
            try load()
            pendingFocusBlockID = blockID
            EditorLog.focus.debug(
                "editor_focus_request_queued block_id=\(blockID, privacy: .public) source=line_head_strip_block_type"
            )
            return EditorTextSelection(blockID: blockID, location: 0, length: 0)
        }

        if let currentBlock = snapshot.blocks.first(where: { $0.id == blockID }),
           currentBlock.type.isTextEditable,
           currentBlock.parentBlockID != nil {
            guard let repository else {
                throw WorkspaceViewModelError.missingRepository
            }
            let didOutdent = try repository.outdentBlock(blockID: blockID)
            guard didOutdent else {
                return nil
            }
            try load()
            pendingFocusBlockID = blockID
            EditorLog.focus.debug(
                "editor_focus_request_queued block_id=\(blockID, privacy: .public) source=empty_indented_backspace"
            )
            return EditorTextSelection(blockID: blockID, location: 0, length: 0)
        }

        let blocks = editorVisibleBlocks
        guard let currentIndex = blocks.firstIndex(where: { $0.id == blockID }),
              currentIndex > 0 else {
            return nil
        }

        let currentBlock = blocks[currentIndex]
        let previousBlock = blocks[currentIndex - 1]
        guard currentBlock.type.isTextEditable,
              previousBlock.type.isTextEditable else {
            return nil
        }

        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let focusLocation = (previousBlock.textPlain as NSString).length
        try repository.updateBlock(
            blockID: previousBlock.id,
            type: previousBlock.type,
            text: previousBlock.textPlain + currentBlock.textPlain,
            taskItemIsCompleted: previousBlock.taskItemIsCompleted,
            toggleIsExpanded: previousBlock.toggleIsExpanded,
            codeBlockLineWrapping: previousBlock.codeBlockLineWrapping
        )
        try repository.deleteBlock(blockID: blockID)
        try load()
        pendingFocusBlockID = previousBlock.id
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(previousBlock.id, privacy: .public) source=merge_text_block"
        )
        return EditorTextSelection(blockID: previousBlock.id, location: focusLocation, length: 0)
    }

    @discardableResult
    func mergeTextBlockWithNextAtSelection(
        blockID: String,
        selection: EditorTextSelection
    ) throws -> EditorTextSelection? {
        guard selection.blockID == blockID,
              selection.length == 0 else {
            return nil
        }

        let blocks = editorVisibleBlocks
        guard let currentIndex = blocks.firstIndex(where: { $0.id == blockID }),
              currentIndex < blocks.count - 1 else {
            return nil
        }

        let currentBlock = blocks[currentIndex]
        let nextBlock = blocks[currentIndex + 1]
        let focusLocation = (currentBlock.textPlain as NSString).length
        guard selection.location == focusLocation,
              currentBlock.type.isTextEditable,
              nextBlock.type.isTextEditable else {
            return nil
        }

        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        try repository.updateBlock(
            blockID: currentBlock.id,
            type: currentBlock.type,
            text: currentBlock.textPlain + nextBlock.textPlain,
            taskItemIsCompleted: currentBlock.taskItemIsCompleted,
            toggleIsExpanded: currentBlock.toggleIsExpanded,
            codeBlockLineWrapping: currentBlock.codeBlockLineWrapping
        )
        try repository.deleteBlock(blockID: nextBlock.id)
        try load()
        pendingFocusBlockID = currentBlock.id
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(currentBlock.id, privacy: .public) source=merge_next_text_block"
        )
        return EditorTextSelection(blockID: currentBlock.id, location: focusLocation, length: 0)
    }

    @discardableResult
    func moveBlockByKeyboard(
        blockID: String,
        direction: BlockKeyboardMoveDirection
    ) throws -> Bool {
        guard let currentIndex = visibleBlocks.firstIndex(where: { $0.id == blockID }) else {
            throw PageRepositoryError.blockNotFound
        }

        let targetIndex: Int
        switch direction {
        case .up:
            targetIndex = currentIndex - 1
        case .down:
            targetIndex = currentIndex + 1
        }

        guard visibleBlocks.indices.contains(targetIndex) else {
            return false
        }

        try moveBlock(blockID: blockID, toIndex: targetIndex)
        pendingFocusBlockID = blockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(blockID, privacy: .public) source=keyboard_reorder"
        )
        return true
    }

    @discardableResult
    func indentBlock(blockID: String) throws -> Bool {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let didIndent = try repository.indentBlock(blockID: blockID)
        guard didIndent else {
            return false
        }

        try load()
        pendingFocusBlockID = blockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(blockID, privacy: .public) source=block_indent"
        )
        return true
    }

    @discardableResult
    func outdentBlock(blockID: String) throws -> Bool {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let didOutdent = try repository.outdentBlock(blockID: blockID)
        guard didOutdent else {
            return false
        }

        try load()
        pendingFocusBlockID = blockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(blockID, privacy: .public) source=block_outdent"
        )
        return true
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

    func moveBlocksInCurrentPage(blockIDs: [String], toIndex: Int) {
        do {
            try moveBlocks(blockIDs: blockIDs, toIndex: toIndex)
        } catch {
            EditorLog.store.error(
                "blocks_move_failed block_ids=\(blockIDs.joined(separator: ","), privacy: .public) target_index=\(toIndex, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func insertParagraphBlockAfterForUI(blockID: String) -> Bool {
        do {
            let insertedBlockID = try insertParagraphBlock(after: blockID)
            EditorLog.input.debug(
                "paragraph_block_inserted_after block_id=\(insertedBlockID, privacy: .public) previous_block_id=\(blockID, privacy: .public)"
            )
            return true
        } catch {
            EditorLog.input.error(
                "paragraph_block_insert_after_failed previous_block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func splitTextBlockAtSelectionForUI(
        blockID: String,
        selection: EditorTextSelection
    ) -> EditorTextSelection? {
        do {
            let nextSelection = try splitTextBlockAtSelection(blockID: blockID, selection: selection)
            if let nextSelection {
                EditorLog.input.debug(
                    "text_block_split_at_selection previous_block_id=\(blockID, privacy: .public) inserted_block_id=\(nextSelection.blockID, privacy: .public) location=\(selection.location, privacy: .public) length=\(selection.length, privacy: .public)"
                )
            }
            return nextSelection
        } catch {
            EditorLog.input.error(
                "text_block_split_at_selection_failed previous_block_id=\(blockID, privacy: .public) location=\(selection.location, privacy: .public) length=\(selection.length, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    func mergeTextBlockWithPreviousAtSelectionForUI(
        blockID: String,
        selection: EditorTextSelection
    ) -> EditorTextSelection? {
        do {
            let nextSelection = try mergeTextBlockWithPreviousAtSelection(blockID: blockID, selection: selection)
            if let nextSelection {
                EditorLog.input.debug(
                    "text_block_merged_with_previous current_block_id=\(blockID, privacy: .public) previous_block_id=\(nextSelection.blockID, privacy: .public) location=\(selection.location, privacy: .public) length=\(selection.length, privacy: .public)"
                )
            }
            return nextSelection
        } catch {
            EditorLog.input.error(
                "text_block_merge_with_previous_failed current_block_id=\(blockID, privacy: .public) location=\(selection.location, privacy: .public) length=\(selection.length, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    func mergeTextBlockWithNextAtSelectionForUI(
        blockID: String,
        selection: EditorTextSelection
    ) -> EditorTextSelection? {
        do {
            let nextSelection = try mergeTextBlockWithNextAtSelection(blockID: blockID, selection: selection)
            if let nextSelection {
                EditorLog.input.debug(
                    "text_block_merged_with_next current_block_id=\(blockID, privacy: .public) next_focus_block_id=\(nextSelection.blockID, privacy: .public) location=\(selection.location, privacy: .public) length=\(selection.length, privacy: .public)"
                )
            }
            return nextSelection
        } catch {
            EditorLog.input.error(
                "text_block_merge_with_next_failed current_block_id=\(blockID, privacy: .public) location=\(selection.location, privacy: .public) length=\(selection.length, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    func moveBlockByKeyboardForUI(blockID: String, direction: BlockKeyboardMoveDirection) -> Bool {
        do {
            let didMove = try moveBlockByKeyboard(blockID: blockID, direction: direction)
            if didMove {
                EditorLog.store.debug(
                    "block_keyboard_move_visible block_id=\(blockID, privacy: .public) direction=\(String(describing: direction), privacy: .public)"
                )
            }
            return didMove
        } catch {
            EditorLog.store.error(
                "block_keyboard_move_failed block_id=\(blockID, privacy: .public) direction=\(String(describing: direction), privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func indentBlockForUI(blockID: String) -> Bool {
        do {
            let didIndent = try indentBlock(blockID: blockID)
            if didIndent {
                EditorLog.store.debug("block_indent_visible block_id=\(blockID, privacy: .public)")
            }
            return didIndent
        } catch {
            EditorLog.store.error(
                "block_indent_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func outdentBlockForUI(blockID: String) -> Bool {
        do {
            let didOutdent = try outdentBlock(blockID: blockID)
            if didOutdent {
                EditorLog.store.debug("block_outdent_visible block_id=\(blockID, privacy: .public)")
            }
            return didOutdent
        } catch {
            EditorLog.store.error(
                "block_outdent_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func acceptRemoteConflict(id conflictID: String) throws {
        guard let conflictRepository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let previousNotebookID = selectedNotebookID
        let previousPageID = selectedPageID
        let accepted = try conflictRepository.acceptRemoteVersion(conflictID: conflictID)
        try load()
        restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
        pendingFocusBlockID = accepted.blockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(accepted.blockID, privacy: .public) source=conflict_accept"
        )
    }

    func acceptRemoteConflictForUI(id conflictID: String) {
        do {
            try acceptRemoteConflict(id: conflictID)
            EditorLog.sync.debug("sync_conflict_remote_accepted conflict_id=\(conflictID, privacy: .public)")
        } catch {
            EditorLog.sync.error(
                "sync_conflict_accept_failed conflict_id=\(conflictID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func acceptAllRemoteConflictsForSelectedPage() throws {
        guard let conflictRepository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedPageID else {
            throw WorkspaceViewModelError.missingSelection
        }

        let previousNotebookID = selectedNotebookID
        let previousPageID = self.selectedPageID
        let accepted = try conflictRepository.acceptRemoteVersions(pageID: selectedPageID)
        try load()
        restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
        if let firstAccepted = accepted.first {
            pendingFocusBlockID = firstAccepted.blockID
            EditorLog.focus.debug(
                "editor_focus_request_queued block_id=\(firstAccepted.blockID, privacy: .public) source=conflict_accept_all"
            )
        }
    }

    func acceptAllRemoteConflictsForSelectedPageForUI() {
        do {
            try acceptAllRemoteConflictsForSelectedPage()
            EditorLog.sync.debug("sync_conflict_all_remote_accepted")
        } catch {
            EditorLog.sync.error(
                "sync_conflict_accept_all_failed error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func acceptLocalConflict(id conflictID: String) throws {
        guard let conflictRepository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let previousNotebookID = selectedNotebookID
        let previousPageID = selectedPageID
        let accepted = try conflictRepository.acceptLocalVersion(conflictID: conflictID)
        try load()
        restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
        pendingFocusBlockID = accepted.blockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(accepted.blockID, privacy: .public) source=conflict_accept_local"
        )
    }

    func acceptLocalConflictForUI(id conflictID: String) {
        do {
            try acceptLocalConflict(id: conflictID)
            EditorLog.sync.debug("sync_conflict_local_accepted conflict_id=\(conflictID, privacy: .public)")
        } catch {
            EditorLog.sync.error(
                "sync_conflict_accept_local_failed conflict_id=\(conflictID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func acceptAllLocalConflictsForSelectedPage() throws {
        guard let conflictRepository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedPageID else {
            throw WorkspaceViewModelError.missingSelection
        }

        let previousNotebookID = selectedNotebookID
        let previousPageID = self.selectedPageID
        let accepted = try conflictRepository.acceptLocalVersions(pageID: selectedPageID)
        try load()
        restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
        if let firstAccepted = accepted.first {
            pendingFocusBlockID = firstAccepted.blockID
            EditorLog.focus.debug(
                "editor_focus_request_queued block_id=\(firstAccepted.blockID, privacy: .public) source=conflict_accept_all_local"
            )
        }
    }

    func acceptAllLocalConflictsForSelectedPageForUI() {
        do {
            try acceptAllLocalConflictsForSelectedPage()
            EditorLog.sync.debug("sync_conflict_all_local_accepted")
        } catch {
            EditorLog.sync.error(
                "sync_conflict_accept_all_local_failed error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func resolveConflictManually(id conflictID: String, text: String) throws {
        guard let conflictRepository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let previousNotebookID = selectedNotebookID
        let previousPageID = selectedPageID
        let resolved = try conflictRepository.resolveManually(conflictID: conflictID, text: text)
        try load()
        restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
        pendingFocusBlockID = resolved.blockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(resolved.blockID, privacy: .public) source=conflict_manual_merge"
        )
    }

    func resolveConflictManuallyForUI(id conflictID: String, text: String) {
        do {
            try resolveConflictManually(id: conflictID, text: text)
            EditorLog.sync.debug("sync_conflict_manual_resolved conflict_id=\(conflictID, privacy: .public)")
        } catch {
            EditorLog.sync.error(
                "sync_conflict_manual_resolve_failed conflict_id=\(conflictID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func resolveAllManualConflictsForSelectedPage(mergedTextsByConflictID: [String: String]) throws {
        guard let conflictRepository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let merges = selectedPageConflicts.compactMap { conflict -> (conflictID: String, text: String)? in
            guard let text = mergedTextsByConflictID[conflict.id] else {
                return nil
            }
            return (conflict.id, text)
        }
        guard !merges.isEmpty else {
            return
        }

        let previousNotebookID = selectedNotebookID
        let previousPageID = selectedPageID
        let resolved = try conflictRepository.resolveManualConflicts(merges)
        try load()
        restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
        if let firstResolved = resolved.first {
            pendingFocusBlockID = firstResolved.blockID
            EditorLog.focus.debug(
                "editor_focus_request_queued block_id=\(firstResolved.blockID, privacy: .public) source=conflict_manual_merge_all"
            )
        }
    }

    func resolveAllManualConflictsForSelectedPageForUI(mergedTextsByConflictID: [String: String]) {
        do {
            try resolveAllManualConflictsForSelectedPage(mergedTextsByConflictID: mergedTextsByConflictID)
            EditorLog.sync.debug("sync_conflict_all_manual_resolved count=\(mergedTextsByConflictID.count, privacy: .public)")
        } catch {
            EditorLog.sync.error(
                "sync_conflict_manual_resolve_all_failed error=\(String(describing: error), privacy: .public)"
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

    @discardableResult
    func deleteBlocksFromCurrentPage(blockIDs: [String]) -> Bool {
        let uniqueBlockIDs = Array(Set(blockIDs))
        guard !uniqueBlockIDs.isEmpty else {
            return false
        }

        do {
            guard let repository else {
                throw WorkspaceViewModelError.missingRepository
            }

            for blockID in uniqueBlockIDs {
                try repository.deleteBlock(blockID: blockID)
            }
            try load()
            EditorLog.store.debug(
                "blocks_delete_visible block_ids=\(uniqueBlockIDs.joined(separator: ","), privacy: .public)"
            )
            return true
        } catch {
            EditorLog.store.error(
                "blocks_delete_failed block_ids=\(uniqueBlockIDs.joined(separator: ","), privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func exportCurrentPageMarkdown() -> String {
        MarkdownTransformer.export(blocks: visibleBlocks, attachments: snapshot.attachments)
    }

    func exportCurrentPageMarkdownPackage(to markdownURL: URL) throws {
        let markdown = exportCurrentPageMarkdown()
        let exportDirectory = markdownURL.deletingLastPathComponent()
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: exportDirectory,
            withIntermediateDirectories: true
        )
        try markdown.write(to: markdownURL, atomically: true, encoding: .utf8)

        for attachment in visibleAttachmentSnapshots() {
            let attachmentDirectory = exportDirectory
                .appendingPathComponent("Attachments", isDirectory: true)
                .appendingPathComponent(attachment.id, isDirectory: true)
            try fileManager.createDirectory(
                at: attachmentDirectory,
                withIntermediateDirectories: true
            )
            let destinationURL = attachmentDirectory.appendingPathComponent(attachment.originalFilename)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(
                at: URL(fileURLWithPath: attachment.localPath),
                to: destinationURL
            )
        }
    }

    func exportCurrentPageMarkdownPackageForUI(to markdownURL: URL) {
        do {
            try exportCurrentPageMarkdownPackage(to: markdownURL)
            EditorLog.markdown.debug(
                "markdown_package_exported destination=\(markdownURL.lastPathComponent, privacy: .public)"
            )
        } catch {
            EditorLog.markdown.error(
                "markdown_package_export_failed destination=\(markdownURL.lastPathComponent, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
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
        markdownImportStatusText = nil
    }

    func importMarkdownPackageToCurrentPage(markdownURL: URL) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedWorkspaceID, let selectedPageID else {
            throw WorkspaceViewModelError.missingSelection
        }

        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        let packageDirectory = markdownURL.deletingLastPathComponent()
        var importedAttachments: [AttachmentImportResult] = []
        var missingAttachmentNames: [String] = []
        try repository.importMarkdown(pageID: selectedPageID, markdown: markdown) { [attachmentRepository] draft in
            guard let relativePath = draft.attachmentRelativePath else {
                return nil
            }
            guard let attachmentRepository else {
                throw WorkspaceViewModelError.missingRepository
            }
            guard let sourceURL = Self.packageAttachmentSourceURL(
                packageDirectory: packageDirectory,
                relativePath: relativePath
            ) else {
                missingAttachmentNames.append(draft.textPlain)
                return nil
            }

            let result = try attachmentRepository.importAttachment(
                sourceURL: sourceURL,
                workspaceID: selectedWorkspaceID,
                pageID: selectedPageID,
                thumbnailPolicy: .deferred
            )
            importedAttachments.append(result)
            return result
        }
        try load()
        markdownImportStatusText = Self.markdownImportStatusText(missingAttachmentNames: missingAttachmentNames)
        for result in importedAttachments {
            scheduleMissingAttachmentThumbnail(attachmentID: result.attachment.id)
        }
    }

    func importMarkdownFileForCurrentPage(sourceURL: URL) {
        do {
            try importMarkdownPackageToCurrentPage(markdownURL: sourceURL)
            EditorLog.markdown.debug(
                "markdown_file_imported source=\(sourceURL.lastPathComponent, privacy: .public)"
            )
        } catch {
            EditorLog.markdown.error(
                "markdown_file_import_failed source=\(sourceURL.lastPathComponent, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    @discardableResult
    func importAttachment(
        sourceURL: URL,
        thumbnailPolicy: AttachmentThumbnailPolicy = .immediate
    ) throws -> AttachmentImportResult {
        guard repository != nil, let attachmentRepository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedWorkspaceID, let selectedPageID else {
            throw WorkspaceViewModelError.missingSelection
        }

        let result = try attachmentRepository.importAttachment(
            sourceURL: sourceURL,
            workspaceID: selectedWorkspaceID,
            pageID: selectedPageID,
            thumbnailPolicy: thumbnailPolicy
        )
        try load()
        return result
    }

    @discardableResult
    func generateMissingAttachmentThumbnail(attachmentID: String) throws -> String? {
        guard let attachmentRepository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let thumbnailPath = try attachmentRepository.generateMissingThumbnail(
            attachmentID: attachmentID
        )
        attachmentPreviewGenerationStatuses[attachmentID] = nil
        try load()
        return thumbnailPath
    }

    func attachmentPreviewGenerationStatus(attachmentID: String) -> AttachmentPreviewGenerationStatus {
        attachmentPreviewGenerationStatuses[attachmentID] ?? .idle
    }

    func retryAttachmentPreviewGeneration(attachmentID: String) {
        scheduleMissingAttachmentThumbnail(attachmentID: attachmentID)
    }

    @discardableResult
    func purgeUnreferencedAttachments() throws -> Int {
        guard let attachmentRepository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedWorkspaceID else {
            throw WorkspaceViewModelError.missingSelection
        }

        let purgedCount = try attachmentRepository.purgeUnreferencedAttachments(
            workspaceID: selectedWorkspaceID
        )
        try load()
        return purgedCount
    }

    func updateSearchQuery(_ query: String) {
        searchQuery = query
        refreshSearchResults()
    }

    @discardableResult
    func importAttachmentForCurrentPage(
        sourceURL: URL,
        afterBlockID: String? = nil
    ) -> AttachmentImportResult? {
        do {
            let result = try importAttachment(
                sourceURL: sourceURL,
                thumbnailPolicy: .deferred
            )
            if let afterBlockID {
                try moveImportedAttachmentBlock(result.block.id, afterBlockID: afterBlockID)
            }
            scheduleMissingAttachmentThumbnail(attachmentID: result.attachment.id)
            EditorLog.attachment.debug("attachment_import_visible source=\(sourceURL.lastPathComponent, privacy: .public)")
            return result
        } catch {
            EditorLog.attachment.error(
                "attachment_import_failed source=\(sourceURL.lastPathComponent, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    @discardableResult
    func importAttachmentsForCurrentPage(
        sourceURLs: [URL],
        afterBlockID: String
    ) -> Bool {
        guard !sourceURLs.isEmpty else {
            return false
        }

        var insertionAnchorBlockID = afterBlockID
        var didImportAttachment = false
        for sourceURL in sourceURLs {
            guard let result = importAttachmentForCurrentPage(
                sourceURL: sourceURL,
                afterBlockID: insertionAnchorBlockID
            ) else {
                continue
            }
            insertionAnchorBlockID = result.block.id
            didImportAttachment = true
        }
        return didImportAttachment
    }

    private func moveImportedAttachmentBlock(
        _ blockID: String,
        afterBlockID: String
    ) throws {
        guard blockID != afterBlockID else {
            return
        }

        let remainingBlocks = visibleBlocks.filter { $0.id != blockID }
        guard let anchorIndex = remainingBlocks.firstIndex(where: { $0.id == afterBlockID }) else {
            return
        }

        try moveBlock(blockID: blockID, toIndex: anchorIndex + 1)
    }

    private func visibleAttachmentSnapshots() -> [AttachmentSnapshot] {
        var attachmentIDs: Set<String> = []
        return visibleBlocks.compactMap { block in
            guard let attachment = snapshot.attachments.first(where: { $0.matches(block: block) }),
                  !attachmentIDs.contains(attachment.id) else {
                return nil
            }
            attachmentIDs.insert(attachment.id)
            return attachment
        }
    }

    private static func packageAttachmentSourceURL(
        packageDirectory: URL,
        relativePath: String
    ) -> URL? {
        let decodedPath = relativePath.removingPercentEncoding ?? relativePath
        let pathComponents = decodedPath.split(separator: "/", omittingEmptySubsequences: false)
        guard pathComponents.first == "Attachments",
              pathComponents.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            return nil
        }

        let sourceURL = pathComponents.reduce(packageDirectory) { partialURL, component in
            partialURL.appendingPathComponent(String(component))
        }
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return nil
        }
        return sourceURL
    }

    private static func markdownImportStatusText(missingAttachmentNames: [String]) -> String? {
        guard !missingAttachmentNames.isEmpty else {
            return nil
        }
        let uniqueNames = Array(Set(missingAttachmentNames)).sorted()
        if uniqueNames.count == 1 {
            return "Missing attachment: \(uniqueNames[0])"
        }
        return "Missing attachments: \(uniqueNames.joined(separator: ", "))"
    }

    private func scheduleMissingAttachmentThumbnail(attachmentID: String) {
        guard let attachmentRepository, let attachmentThumbnailScheduler else {
            return
        }

        attachmentPreviewGenerationStatuses[attachmentID] = .generating
        attachmentThumbnailScheduler.scheduleThumbnailGeneration(
            attachmentID: attachmentID,
            generate: {
                try attachmentRepository.generateMissingThumbnail(attachmentID: attachmentID)
            },
            completion: { [weak self] result in
                guard let self else {
                    return
                }

                switch result {
                case .success(let thumbnailPath):
                    self.attachmentPreviewGenerationStatuses[attachmentID] = nil
                    if thumbnailPath != nil {
                        EditorLog.attachment.debug(
                            "attachment_thumbnail_visible id=\(attachmentID, privacy: .public)"
                        )
                    }
                case .failure(let error):
                    self.attachmentPreviewGenerationStatuses[attachmentID] = .failed(String(describing: error))
                    EditorLog.attachment.error(
                        "attachment_thumbnail_failed id=\(attachmentID, privacy: .public) error=\(String(describing: error), privacy: .public)"
                    )
                }

                do {
                    try self.load()
                } catch {
                    EditorLog.attachment.error(
                        "attachment_thumbnail_refresh_failed id=\(attachmentID, privacy: .public) error=\(String(describing: error), privacy: .public)"
                    )
                }
            }
        )
    }

    func purgeUnreferencedAttachmentsForUI() {
        do {
            let purgedCount = try purgeUnreferencedAttachments()
            EditorLog.attachment.debug(
                "attachment_gc_visible count=\(purgedCount, privacy: .public)"
            )
        } catch {
            EditorLog.attachment.error(
                "attachment_gc_failed error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    private func apply(snapshot: WorkspaceSnapshot) {
        self.snapshot = snapshot
        selectedWorkspaceID = snapshot.selectedWorkspaceID
        selectedNotebookID = snapshot.selectedNotebookID
        selectedPageID = snapshot.selectedPageID
        selectedCollection = selectedPageID == nil ? .diary : .recent
        activeDiaryEntry = nil
    }

    @discardableResult
    private func openDailyDiaryPage(source: String, recordHistory: Bool = false) throws -> PageSummary? {
        guard let repository, let diaryRepository, let selectedWorkspaceID else {
            return nil
        }
        let previousPageID = selectedPageID
        let previousCollection = selectedCollection

        let page = try diaryRepository.openDailyPage(
            workspaceID: selectedWorkspaceID,
            date: currentDateProvider(),
            calendar: diaryCalendar
        )
        let loadedSnapshot = try repository.loadWorkspaceSnapshot()
        apply(snapshot: loadedSnapshot)
        if recordHistory,
           let previousPageID,
           previousPageID != page.id {
            pageNavigationBackStack.append(
                PageNavigationHistoryEntry(pageID: previousPageID, collection: previousCollection)
            )
            pageNavigationForwardStack = []
        }
        selectedCollection = .diary
        selectedPageID = page.id
        selectedNotebookID = page.notebookID ?? selectedNotebookID
        refreshBacklinksForSelectedPage()
        refreshExternalLinksForSelectedPage()
        refreshConflictsForSelectedPage()
        requestFocusForInitialEmptyBlockIfNeeded(source: source)
        return page
    }

    private func restoreSelectionAfterReload(collection: WorkspaceCollection, pageID: String?) {
        selectedCollection = collection
        if collection == .diary {
            return
        }

        guard let pageID, canRestoreSelection(pageID: pageID, in: collection) else {
            return
        }

        selectedPageID = pageID
    }

    private func canRestoreSelection(pageID: String, in collection: WorkspaceCollection) -> Bool {
        switch collection {
        case .diary:
            return diaryPageIDs.contains(pageID)
        case .archive:
            return snapshot.archivedPages.contains { $0.id == pageID }
        case .recent:
            return snapshot.pages.contains { $0.id == pageID }
        case .allDocuments:
            return snapshot.pages.contains { $0.id == pageID } && !diaryPageIDs.contains(pageID)
        case .favorites, .tag, .search:
            return snapshot.pages.contains { $0.id == pageID }
        }
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

    private func requestInitialEditorFocusIfNeeded(source: String) {
        guard !didRequestInitialEditorFocus,
              visibleBlocks.count == 1,
              let block = visibleBlocks.first,
              block.type.isTextEditable else {
            return
        }

        didRequestInitialEditorFocus = true
        pendingFocusBlockID = block.id
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(block.id, privacy: .public) source=\(source, privacy: .public)"
        )
    }

    private func requestInitialCompactPageNavigationIfNeeded(source: String) {
        guard !didRequestInitialCompactPageNavigation,
              let selectedPageID else {
            return
        }

        didRequestInitialCompactPageNavigation = true
        pendingCompactPageNavigationID = selectedPageID
        EditorLog.render.debug(
            "compact_page_navigation_queued page_id=\(selectedPageID, privacy: .public) source=\(source, privacy: .public)"
        )
    }

    private func ensureRemoteChangeSubscriptionForUI() {
        do {
            try syncEngine?.ensureRemoteChangeSubscription()
        } catch {
            EditorLog.sync.error(
                "cloudkit_subscription_ensure_failed error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    private func refreshDerivedState(
        rebuildSearchIndex: Bool,
        changedBlockID: String? = nil
    ) throws {
        if let changedBlockID {
            try searchRepository?.updateBlockIndex(blockID: changedBlockID)
        } else if rebuildSearchIndex {
            try searchRepository?.rebuildIndex()
        }
        refreshSearchResults()
        refreshBacklinksForSelectedPage()
        refreshExternalLinksForSelectedPage()
        refreshConflictsForSelectedPage()
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

    private func refreshExternalLinksForSelectedPage() {
        guard let selectedPageID, let backlinkRepository else {
            selectedPageExternalLinks = []
            return
        }

        do {
            selectedPageExternalLinks = try backlinkRepository.externalLinks(sourcePageID: selectedPageID)
        } catch {
            selectedPageExternalLinks = []
            EditorLog.render.error(
                "external_links_failed page_id=\(selectedPageID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    private func refreshConflictsForSelectedPage() {
        guard let selectedPageID, let conflictRepository else {
            selectedPageConflicts = []
            return
        }

        do {
            selectedPageConflicts = try conflictRepository.conflicts(pageID: selectedPageID)
        } catch {
            selectedPageConflicts = []
            EditorLog.sync.error(
                "conflicts_failed page_id=\(selectedPageID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    private func archiveBackgroundPage(id pageID: String) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let previousNotebookID = selectedNotebookID
        let previousPageID = selectedPageID
        try repository.archivePage(pageID: pageID)
        try load()
        restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
        recordPageArchiveUndoSnapshot(
            pageID: pageID,
            previousNotebookID: previousNotebookID,
            previousPageID: previousPageID
        )
    }

    private func recordPageArchiveUndoSnapshot(
        pageID: String,
        previousNotebookID: String?,
        previousPageID: String?
    ) {
        pageArchiveUndoStack.append(
            PageArchiveUndoSnapshot(
                pageID: pageID,
                previousNotebookID: previousNotebookID,
                previousPageID: previousPageID
            )
        )
        refreshPageArchiveUndoAvailability()
    }

    private func removePageArchiveUndoSnapshots(for pageID: String) {
        pageArchiveUndoStack.removeAll { $0.pageID == pageID }
        refreshPageArchiveUndoAvailability()
    }

    private func refreshPageArchiveUndoAvailability() {
        canUndoPageArchive = !pageArchiveUndoStack.isEmpty
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
        refreshExternalLinksForSelectedPage()
        refreshConflictsForSelectedPage()
    }

    private func assignInlineTags(_ tagNames: [String], to pageID: String) throws {
        guard !tagNames.isEmpty,
              let tagRepository,
              let selectedWorkspaceID else {
            return
        }

        var existingTags = try tagRepository.tags(workspaceID: selectedWorkspaceID)
        var assignedTagIDs = Set(
            try tagRepository.tagAssignments()
                .filter { $0.pageID == pageID }
                .map(\.tagID)
        )

        for tagName in tagNames {
            if let existingTag = existingTags.first(where: { $0.name.caseInsensitiveCompare(tagName) == .orderedSame }) {
                assignedTagIDs.insert(existingTag.id)
            } else {
                let createdTag = try tagRepository.createTag(workspaceID: selectedWorkspaceID, name: tagName)
                existingTags.append(createdTag)
                assignedTagIDs.insert(createdTag.id)
            }
        }

        try tagRepository.assignTags(pageID: pageID, tagIDs: Array(assignedTagIDs).sorted())
    }

    private func extractInlineHashTagsFromSnapshotIfNeeded() throws -> Bool {
        guard let repository, tagRepository != nil else {
            return false
        }

        var didExtractTags = false
        for block in snapshot.blocks where block.type.isTextEditable {
            let extraction = InlineHashTagExtractor.extract(from: block.textPlain)
            guard !extraction.tagNames.isEmpty else {
                continue
            }

            try repository.updateBlock(
                blockID: block.id,
                type: block.type,
                text: extraction.text,
                taskItemIsCompleted: block.taskItemIsCompleted,
                toggleIsExpanded: block.toggleIsExpanded,
                codeBlockLineWrapping: block.codeBlockLineWrapping
            )
            try assignInlineTags(extraction.tagNames, to: block.pageID)
            didExtractTags = true
        }

        return didExtractTags
    }

    private func makeTextEditUndoSnapshot(
        blockID: String,
        currentBlock: BlockSnapshot?,
        nextType: BlockType,
        nextText: String,
        registerUndo: Bool
    ) -> TextEditUndoSnapshot? {
        guard registerUndo,
              let currentBlock,
              currentBlock.type != nextType || currentBlock.textPlain != nextText else {
            return nil
        }

        return TextEditUndoSnapshot(
            blockID: blockID,
            previousType: currentBlock.type,
            previousText: currentBlock.textPlain,
            previousTableRows: currentBlock.tableRows
        )
    }

    private func recordTextEditUndoSnapshot(
        _ undoSnapshot: TextEditUndoSnapshot,
        currentBlock: BlockSnapshot?,
        nextType: BlockType
    ) {
        if let currentType = currentBlock?.type,
           let lastUndoSnapshot = textEditUndoStack.last,
           lastUndoSnapshot.blockID == undoSnapshot.blockID,
           lastUndoSnapshot.previousType == currentType,
           currentType == nextType {
            return
        }

        textEditUndoStack.append(undoSnapshot)
    }

    private func refreshTextEditUndoAvailability() {
        canUndoTextEdit = !textEditUndoStack.isEmpty
    }

    private func nextBlockState(
        currentType: BlockType,
        text: String
    ) -> (type: BlockType, text: String, taskItemIsCompleted: Bool?) {
        if let transform = MarkdownTransformer.shortcutTransform(for: text) {
            EditorLog.markdown.debug(
                "markdown_shortcut type=\(transform.type.rawValue, privacy: .public)"
            )
            return (
                transform.type,
                transform.textPlain,
                transform.type == .taskItem ? transform.taskItemIsCompleted : nil
            )
        }

        return (currentType, text, nil)
    }
}

enum TextBlockSplitPolicy {
    static func insertedBlockType(after type: BlockType) -> BlockType {
        switch type {
        case .unorderedListItem, .orderedListItem, .taskItem:
            return type
        default:
            return .paragraph
        }
    }
}

private extension BlockType {
    var stripsFormattingBeforeLineHeadMerge: Bool {
        switch self {
        case .heading1,
             .heading2,
             .heading3,
             .unorderedListItem,
             .orderedListItem,
             .taskItem,
             .quote,
             .callout,
             .toggle,
             .codeBlock:
            return true
        case .paragraph,
             .table,
             .divider,
             .pageReference,
             .blockReference,
             .attachmentImage,
             .attachmentVideo,
             .attachmentFile:
            return false
        }
    }

    var headingLevel: Int? {
        switch self {
        case .heading1:
            return 1
        case .heading2:
            return 2
        case .heading3:
            return 3
        default:
            return nil
        }
    }
}

private struct TextEditUndoSnapshot {
    let blockID: String
    let previousType: BlockType
    let previousText: String
    let previousTableRows: [[String]]
}

private struct PageArchiveUndoSnapshot {
    let pageID: String
    let previousNotebookID: String?
    let previousPageID: String?
}

enum WorkspaceViewModelError: Error, Equatable {
    case missingRepository
    case missingDiaryRepository
    case missingSelection
}
