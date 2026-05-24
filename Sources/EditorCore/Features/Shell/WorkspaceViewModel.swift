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
    case encrypted
    case tag(String)
    case search
    case archive
}

enum AttachmentPreviewGenerationStatus: Equatable, Sendable {
    case idle
    case generating
    case failed(String)
}

struct WorkspaceForegroundSyncSummary: Equatable, Sendable {
    let uploadSummary: SyncUploadSummary
    let fetchSummary: SyncFetchSummary
    let remainingLocalChangeCount: Int
}

struct SearchTransientHighlight: Equatable, Sendable {
    let id: UUID
    let blockID: String
    let attachmentID: String?
    let rects: [SearchResultHighlightRect]

    init(id: UUID = UUID(), blockID: String, attachmentID: String?, rects: [SearchResultHighlightRect]) {
        self.id = id
        self.blockID = blockID
        self.attachmentID = attachmentID
        self.rects = rects
    }
}

enum WorkspaceForegroundSyncResult: Sendable {
    case success(WorkspaceForegroundSyncSummary)
    case failure(String)
}

enum WorkspaceCloudKitAccountStatusRefreshResult: Sendable {
    case success(CloudKitAccountAvailability)
    case failure(String)
}

enum WorkspaceObsidianImportResult: Sendable {
    case success(ObsidianVaultImportSummary)
    case failure(String)
}

protocol WorkspaceSyncScheduling {
    func scheduleForegroundSync(
        operation: @escaping @Sendable () -> WorkspaceForegroundSyncResult,
        completion: @escaping @MainActor @Sendable (WorkspaceForegroundSyncResult) -> Void
    )
}

protocol WorkspaceObsidianImportScheduling {
    func scheduleObsidianImport(
        operation: @escaping @Sendable () -> WorkspaceObsidianImportResult,
        completion: @escaping @MainActor @Sendable (WorkspaceObsidianImportResult) -> Void
    )
}

protocol CloudKitAccountStatusScheduling {
    func scheduleAccountStatusRefresh(
        operation: @escaping @Sendable () -> WorkspaceCloudKitAccountStatusRefreshResult,
        completion: @escaping @MainActor @Sendable (WorkspaceCloudKitAccountStatusRefreshResult) -> Void
    )
}

final class BackgroundWorkspaceSyncScheduler: WorkspaceSyncScheduling {
    private let queue = DispatchQueue(label: "editor.foreground-sync", qos: .utility)

    func scheduleForegroundSync(
        operation: @escaping @Sendable () -> WorkspaceForegroundSyncResult,
        completion: @escaping @MainActor @Sendable (WorkspaceForegroundSyncResult) -> Void
    ) {
        queue.async {
            let result = operation()
            Task { @MainActor in
                completion(result)
            }
        }
    }
}

final class BackgroundWorkspaceObsidianImportScheduler: WorkspaceObsidianImportScheduling {
    private let queue = DispatchQueue(label: "editor.obsidian-import", qos: .utility)

    func scheduleObsidianImport(
        operation: @escaping @Sendable () -> WorkspaceObsidianImportResult,
        completion: @escaping @MainActor @Sendable (WorkspaceObsidianImportResult) -> Void
    ) {
        queue.async {
            let result = operation()
            Task { @MainActor in
                completion(result)
            }
        }
    }
}

final class BackgroundCloudKitAccountStatusScheduler: CloudKitAccountStatusScheduling {
    private let queue = DispatchQueue(label: "editor.cloudkit-account-status", qos: .utility)

    func scheduleAccountStatusRefresh(
        operation: @escaping @Sendable () -> WorkspaceCloudKitAccountStatusRefreshResult,
        completion: @escaping @MainActor @Sendable (WorkspaceCloudKitAccountStatusRefreshResult) -> Void
    ) {
        queue.async {
            let result = operation()
            Task { @MainActor in
                completion(result)
            }
        }
    }
}

private final class SyncChangeObservation: @unchecked Sendable {
    private let observer: NSObjectProtocol

    init(observer: NSObjectProtocol) {
        self.observer = observer
    }

    deinit {
        NotificationCenter.default.removeObserver(observer)
    }
}

private struct PageNavigationHistoryEntry: Equatable {
    let pageID: String
    let collection: WorkspaceCollection
}

enum WorkspacePageCreationFocus: Equatable, Sendable {
    case initialBlock
    case pageTitle
}

enum CompactPageNavigationResolver {
    static func initialPageID(
        selectedPageID: String?,
        availablePageIDs: [String]
    ) -> String? {
        if let selectedPageID {
            guard availablePageIDs.contains(selectedPageID) else {
                return nil
            }

            return selectedPageID
        }

        return availablePageIDs.first
    }
}

enum WorkspaceColdLaunchSelectionResolver {
    static let recentNoteInterval: TimeInterval = 3_600

    static func recentNotePageID(
        snapshot: WorkspaceSnapshot,
        now: Date,
        calendar: Calendar
    ) -> String? {
        let diaryPageIDs = Set(snapshot.diaryPages.map(\.pageID))
        return snapshot.pages.first { page in
            guard !diaryPageIDs.contains(page.id),
                  let updatedAtString = page.updatedAt,
                  let updatedAt = date(from: updatedAtString) else {
                return false
            }

            let age = now.timeIntervalSince(updatedAt)
            return age >= 0
                && age <= recentNoteInterval
                && calendar.isDate(updatedAt, inSameDayAs: now)
        }?.id
    }

    private static func date(from string: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: string) {
            return date
        }
        return ISO8601DateFormatter().date(from: string)
    }
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
    @Published private(set) var isSearchRefreshPending = false
    @Published private(set) var selectedPageBacklinks: [Backlink] = []
    @Published private(set) var selectedPageExternalLinks: [ExternalLink] = []
    @Published private(set) var selectedPageConflicts: [ConflictSnapshot] = []
    @Published private(set) var cloudKitAccountStatus: CloudKitAccountAvailability?
    @Published private(set) var syncStatusText = "同步空闲"
    @Published private(set) var pendingFocusBlockID: String?
    @Published private(set) var pendingFocusRequestID: UUID?
    @Published private(set) var pendingPageTitleFocusPageID: String?
    @Published private(set) var pendingCompactPageNavigationID: String?
    @Published private(set) var pendingCompactCollectionNavigation: WorkspaceCollection?
    @Published private(set) var pendingSearchHighlight: SearchTransientHighlight?
    @Published private(set) var canUndoTextEdit = false
    @Published private(set) var canRedoTextEdit = false
    @Published private(set) var canUndoPageArchive = false
    @Published private(set) var pageArchiveUndoExpirationDeadline: Date?
    @Published private(set) var attachmentPreviewGenerationStatuses: [String: AttachmentPreviewGenerationStatus] = [:]
    @Published private(set) var markdownImportStatusText: String?
    @Published private(set) var unlockedEncryptedPageIDs: Set<String> = []
    @Published private(set) var authenticatingEncryptedPageID: String?

    private static let encryptedPageAutoLockInterval: TimeInterval = 60
    private static let encryptedPageAutoLockIntervalNanoseconds: UInt64 = 60_000_000_000
    static let pageArchiveUndoVisibilityDuration: TimeInterval = 8

    private let repository: PageRepository?
    private let diaryRepository: DiaryRepository?
    private let tagRepository: TagRepository?
    private let attachmentRepository: AttachmentRepository?
    private let attachmentThumbnailScheduler: AttachmentThumbnailScheduling?
    private let attachmentTextRecognitionRepository: AttachmentTextRecognitionRepository?
    private let attachmentTextRecognitionScheduler: AttachmentTextRecognitionScheduling?
    private let imageTextRecognizer: ImageTextRecognizing?
    private let searchRepository: SearchRepository?
    private let backlinkRepository: BacklinkRepository?
    private let conflictRepository: ConflictRepository?
    private let obsidianImporter: ObsidianVaultImporting?
    private let obsidianImportScheduler: WorkspaceObsidianImportScheduling
    private let automaticallyResolveConflicts: Bool
    private let syncEngine: SyncEngine?
    private let syncScheduler: WorkspaceSyncScheduling
    private let cloudKitAccountMetadataService: CloudKitAccountMetadataService?
    private let cloudKitAccountStatusScheduler: CloudKitAccountStatusScheduling
    private let encryptedPageAuthenticator: EncryptedPageAuthenticating
    private let currentDateProvider: () -> Date
    private let diaryCalendar: Calendar
    private let searchDebounceNanoseconds: UInt64
    private let searchHighlightDurationNanoseconds: UInt64
    private var hasLoadedSnapshot = false
    private var didRequestInitialEditorFocus = false
    private var didRequestInitialCompactPageNavigation = false
    private let pageEditUndoHistoryLimit = 100
    private var pageEditUndoStack: [PageEditHistorySnapshot] = []
    private var pageEditRedoStack: [PageEditHistorySnapshot] = []
    private var pageArchiveUndoStack: [PageArchiveUndoSnapshot] = []
    private var pageNavigationBackStack: [PageNavigationHistoryEntry] = []
    private var pageNavigationForwardStack: [PageNavigationHistoryEntry] = []
    private var searchRestorationCollection: WorkspaceCollection?
    private var searchRefreshTask: Task<Void, Never>?
    private var searchHighlightClearTask: Task<Void, Never>?
    private var pendingTextRecognitionAttachmentIDs: Set<String> = []
    private var isLoadingPendingTextRecognitionAttachmentIDs = false
    private var isForegroundSyncRunning = false
    private var isForegroundSyncRerunPending = false
    private var isObsidianImportRunning = false
    private var shouldSyncAfterObsidianImport = false
    private var isCloudKitAccountStatusRefreshRunning = false
    private var nextForegroundSyncAttemptAt: Date?
    private var syncChangeObservation: SyncChangeObservation?
    private var encryptedPageLastOpenedAt: [String: Date] = [:]
    private var encryptedPageAutoLockTask: Task<Void, Never>?
    private var pageArchiveUndoExpirationTask: Task<Void, Never>?
    private var cachedDiaryPageIDs: Set<String> = []
    private static let foregroundSyncFailureCooldown: TimeInterval = 300
    private static let foregroundSyncPartialFailureCooldown: TimeInterval = 30

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
            .map(\.path)
    }

    var selectedPageTagIDs: [String] {
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
            .map(\.id)
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
        guard isPageContentVisible(pageID: selectedPageID) else {
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
            return snapshot.pages.filter { !snapshot.isEmptyDiaryPage($0.id) }
        case .diary:
            let diaryPageIDs = visibleDiaryPageIDs
            let diaryDatesByPageID = Dictionary(
                uniqueKeysWithValues: snapshot.diaryPages.map { ($0.pageID, $0.diaryDate) }
            )
            return snapshot.pages
                .filter { diaryPageIDs.contains($0.id) }
                .sorted { first, second in
                    (diaryDatesByPageID[first.id] ?? "") > (diaryDatesByPageID[second.id] ?? "")
                }
        case .allDocuments:
            let diaryPageIDs = diaryPageIDs
            return snapshot.pages.filter { !diaryPageIDs.contains($0.id) }
        case .favorites:
            return snapshot.favoritePages.filter { !snapshot.isEmptyDiaryPage($0.id) }
        case .encrypted:
            return snapshot.pages.filter { $0.isEncrypted && !snapshot.isEmptyDiaryPage($0.id) }
        case .tag(let tagID):
            guard !tagID.isEmpty else {
                return []
            }
            let visibleTagIDs = tagIDsIncludingDescendants(of: tagID)
            let pageIDs = Set(
                snapshot.pageTags
                    .filter { visibleTagIDs.contains($0.tagID) }
                    .map(\.pageID)
            )
            return snapshot.pages.filter { pageIDs.contains($0.id) && !snapshot.isEmptyDiaryPage($0.id) }
        case .search:
            return []
        case .archive:
            return snapshot.archivedPages
        }
    }

    var isSearchActive: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        attachmentTextRecognitionRepository: AttachmentTextRecognitionRepository? = nil,
        attachmentTextRecognitionScheduler: AttachmentTextRecognitionScheduling? = DispatchAttachmentTextRecognitionScheduler(),
        imageTextRecognizer: ImageTextRecognizing? = nil,
        searchRepository: SearchRepository? = nil,
        backlinkRepository: BacklinkRepository? = nil,
        conflictRepository: ConflictRepository? = nil,
        obsidianImporter: ObsidianVaultImporting? = nil,
        obsidianImportScheduler: WorkspaceObsidianImportScheduling = BackgroundWorkspaceObsidianImportScheduler(),
        automaticallyResolveConflicts: Bool = true,
        syncEngine: SyncEngine? = nil,
        syncScheduler: WorkspaceSyncScheduling = BackgroundWorkspaceSyncScheduler(),
        cloudKitAccountMetadataService: CloudKitAccountMetadataService? = nil,
        cloudKitAccountStatusScheduler: CloudKitAccountStatusScheduling = BackgroundCloudKitAccountStatusScheduler(),
        encryptedPageAuthenticator: EncryptedPageAuthenticating = SystemEncryptedPageAuthenticator(),
        currentDateProvider: @escaping () -> Date = Date.init,
        diaryCalendar: Calendar = .current,
        searchDebounceNanoseconds: UInt64 = 0,
        searchHighlightDurationNanoseconds: UInt64 = 1_600_000_000
    ) {
        self.repository = repository
        self.diaryRepository = diaryRepository
        self.tagRepository = tagRepository
        self.attachmentRepository = attachmentRepository
        self.attachmentThumbnailScheduler = attachmentThumbnailScheduler
        self.attachmentTextRecognitionRepository = attachmentTextRecognitionRepository
        self.attachmentTextRecognitionScheduler = attachmentTextRecognitionScheduler
        self.imageTextRecognizer = imageTextRecognizer
        self.searchRepository = searchRepository
        self.backlinkRepository = backlinkRepository
        self.conflictRepository = conflictRepository
        self.obsidianImporter = obsidianImporter
        self.obsidianImportScheduler = obsidianImportScheduler
        self.automaticallyResolveConflicts = automaticallyResolveConflicts
        self.syncEngine = syncEngine
        self.syncScheduler = syncScheduler
        self.cloudKitAccountMetadataService = cloudKitAccountMetadataService
        self.cloudKitAccountStatusScheduler = cloudKitAccountStatusScheduler
        self.encryptedPageAuthenticator = encryptedPageAuthenticator
        self.currentDateProvider = currentDateProvider
        self.diaryCalendar = diaryCalendar
        self.searchDebounceNanoseconds = searchDebounceNanoseconds
        self.searchHighlightDurationNanoseconds = searchHighlightDurationNanoseconds
        snapshot = .empty
        cachedDiaryPageIDs = []
        selectedWorkspaceID = nil
        selectedNotebookID = nil
        selectedPageID = nil
        selectedCollection = .recent
        activeDiaryEntry = nil
        pendingFocusBlockID = nil
        pendingFocusRequestID = nil
        pendingPageTitleFocusPageID = nil
        pendingCompactPageNavigationID = nil
        pendingCompactCollectionNavigation = nil
        pendingSearchHighlight = nil
        canUndoTextEdit = false
        canRedoTextEdit = false
        canUndoPageArchive = false
        pageArchiveUndoExpirationDeadline = nil
        attachmentPreviewGenerationStatuses = [:]
        unlockedEncryptedPageIDs = []
        authenticatingEncryptedPageID = nil
        encryptedPageLastOpenedAt = [:]
        encryptedPageAutoLockTask?.cancel()
        encryptedPageAutoLockTask = nil
        searchHighlightClearTask?.cancel()
        searchHighlightClearTask = nil
        startObservingSyncChangesIfNeeded()
    }

    init(snapshot: WorkspaceSnapshot) {
        repository = nil
        diaryRepository = nil
        tagRepository = nil
        attachmentRepository = nil
        attachmentThumbnailScheduler = nil
        attachmentTextRecognitionRepository = nil
        attachmentTextRecognitionScheduler = nil
        imageTextRecognizer = nil
        searchRepository = nil
        backlinkRepository = nil
        conflictRepository = nil
        obsidianImporter = nil
        obsidianImportScheduler = BackgroundWorkspaceObsidianImportScheduler()
        automaticallyResolveConflicts = true
        syncEngine = nil
        syncScheduler = BackgroundWorkspaceSyncScheduler()
        cloudKitAccountMetadataService = nil
        cloudKitAccountStatusScheduler = BackgroundCloudKitAccountStatusScheduler()
        encryptedPageAuthenticator = SystemEncryptedPageAuthenticator()
        currentDateProvider = Date.init
        diaryCalendar = .current
        searchDebounceNanoseconds = 0
        searchHighlightDurationNanoseconds = 1_600_000_000
        self.snapshot = snapshot
        cachedDiaryPageIDs = Set(snapshot.diaryPages.map(\.pageID))
        selectedWorkspaceID = snapshot.selectedWorkspaceID
        selectedNotebookID = snapshot.selectedNotebookID
        selectedPageID = snapshot.selectedPageID
        selectedCollection = snapshot.selectedPageID == nil ? .diary : .recent
        activeDiaryEntry = snapshot.activeDiaryEntry
        pendingFocusBlockID = nil
        pendingFocusRequestID = nil
        pendingPageTitleFocusPageID = nil
        pendingCompactPageNavigationID = nil
        pendingCompactCollectionNavigation = nil
        pendingSearchHighlight = nil
        canUndoTextEdit = false
        canRedoTextEdit = false
        canUndoPageArchive = false
        pageArchiveUndoExpirationDeadline = nil
        attachmentPreviewGenerationStatuses = [:]
        unlockedEncryptedPageIDs = []
        authenticatingEncryptedPageID = nil
        encryptedPageLastOpenedAt = [:]
        encryptedPageAutoLockTask = nil
        searchHighlightClearTask = nil
        requestInitialCompactPageNavigationIfNeeded(source: "snapshot")
    }

    func load() throws {
        guard let repository else {
            return
        }

        _ = try tagRepository?.repairDuplicateTags()
        let previousSelectedCollection = selectedCollection
        let previousSelectedPageID = selectedPageID
        let shouldRestorePreviousSelection = hasLoadedSnapshot
        let loadedSnapshot = try repository.loadWorkspaceSnapshot(blockPageIDs: [])
        apply(snapshot: loadedSnapshot)
        if shouldRestorePreviousSelection {
            if previousSelectedCollection == .diary {
                try openDailyDiaryPage(source: "load", recordHistory: false)
            } else {
                restoreSelectionAfterReload(
                    collection: previousSelectedCollection,
                    pageID: previousSelectedPageID
                )
            }
        } else {
            try selectColdLaunchDestination()
        }
        try hydrateBlocksForSelectedPageIfNeeded()
        hasLoadedSnapshot = true
        let shouldRebuildSearchIndex = try searchRepository?.needsFullRebuild() ?? false
        try refreshDerivedState(rebuildSearchIndex: shouldRebuildSearchIndex)
        // Avoid starting a large image OCR backlog on launch after vault imports.
        requestInitialEditorFocusIfNeeded(source: "load")
        requestInitialCompactPageNavigationIfNeeded(source: "load")
    }

    private func selectColdLaunchDestination() throws {
        if try selectExistingColdLaunchDiaryPage(source: "cold_launch") {
            return
        }

        guard let recentPageID = WorkspaceColdLaunchSelectionResolver.recentNotePageID(
            snapshot: snapshot,
            now: currentDateProvider(),
            calendar: diaryCalendar
        ) else {
            return
        }

        selectPage(id: recentPageID, collection: .recent, recordHistory: false)
        pendingCompactPageNavigationID = recentPageID
        EditorLog.render.debug(
            "compact_page_navigation_queued page_id=\(recentPageID, privacy: .public) source=cold_launch_recent"
        )
    }

    private func selectExistingColdLaunchDiaryPage(source: String) throws -> Bool {
        guard let diaryRepository,
              let selectedWorkspaceID,
              let page = try diaryRepository.existingDailyPage(
                workspaceID: selectedWorkspaceID,
                date: currentDateProvider(),
                calendar: diaryCalendar
              ) else {
            return false
        }
        selectedCollection = .diary
        selectedPageID = page.id
        selectedNotebookID = page.notebookID ?? selectedNotebookID
        refreshBacklinksForSelectedPage()
        refreshExternalLinksForSelectedPage()
        refreshConflictsForSelectedPage()
        requestFocusForInitialEmptyBlockIfNeeded(source: source)
        pendingCompactPageNavigationID = page.id
        EditorLog.render.debug(
            "compact_page_navigation_queued page_id=\(page.id, privacy: .public) source=cold_launch_diary"
        )
        return true
    }

    func refreshCloudKitAccountStatus() throws {
        guard let cloudKitAccountMetadataService else {
            return
        }

        cloudKitAccountStatus = try cloudKitAccountMetadataService.refreshAndStoreStatus()
    }

    func refreshCloudKitAccountStatusForUI() {
        guard let cloudKitAccountMetadataService else {
            return
        }

        guard !isCloudKitAccountStatusRefreshRunning else {
            EditorLog.sync.debug("cloudkit_account_status_skipped reason=already_running")
            return
        }

        isCloudKitAccountStatusRefreshRunning = true
        cloudKitAccountStatusScheduler.scheduleAccountStatusRefresh(
            operation: {
                Self.refreshCloudKitAccountStatus(service: cloudKitAccountMetadataService)
            },
            completion: { [weak self] result in
                self?.finishCloudKitAccountStatusRefresh(result)
            }
        )
    }

    nonisolated private static func refreshCloudKitAccountStatus(
        service: CloudKitAccountMetadataService
    ) -> WorkspaceCloudKitAccountStatusRefreshResult {
        do {
            return .success(try service.refreshAndStoreStatus())
        } catch {
            return .failure(String(describing: error))
        }
    }

    private func finishCloudKitAccountStatusRefresh(
        _ result: WorkspaceCloudKitAccountStatusRefreshResult
    ) {
        isCloudKitAccountStatusRefreshRunning = false
        switch result {
        case .success(let status):
            cloudKitAccountStatus = status
        case .failure(let errorDescription):
            cloudKitAccountStatus = .couldNotDetermine
            EditorLog.sync.error(
                "cloudkit_account_status_failed error=\(errorDescription, privacy: .public)"
            )
        }
    }

    func syncNow() {
        guard let syncEngine else {
            syncStatusText = "同步不可用"
            return
        }

        guard !isForegroundSyncRunning else {
            EditorLog.sync.debug("foreground_sync_skipped reason=already_running")
            return
        }

        isForegroundSyncRunning = true
        syncStatusText = "同步中..."
        syncScheduler.scheduleForegroundSync(
            operation: {
                Self.runForegroundSync(syncEngine: syncEngine)
            },
            completion: { [weak self] result in
                self?.finishForegroundSync(result)
            }
        )
    }

    func syncAfterActivation() {
        if cloudKitAccountMetadataService != nil {
            refreshCloudKitAccountStatusForUI()
        }

        scheduleForegroundSyncIfNeeded(reason: "activation")
    }

    func syncAfterForegroundInterval() {
        scheduleForegroundSyncIfNeeded(reason: "foreground_interval")
    }

    private func syncAfterLocalChange() {
        guard !isObsidianImportRunning else {
            shouldSyncAfterObsidianImport = true
            syncStatusText = "导入中，完成后同步"
            EditorLog.sync.debug("foreground_sync_deferred reason=obsidian_import_running")
            return
        }
        scheduleForegroundSyncIfNeeded(reason: "local_change")
    }

    private func scheduleForegroundSyncIfNeeded(reason: String) {
        guard syncEngine != nil else {
            return
        }
        if let nextForegroundSyncAttemptAt,
           nextForegroundSyncAttemptAt > currentDateProvider() {
            syncStatusText = "同步暂缓，稍后自动重试"
            EditorLog.sync.debug(
                "foreground_sync_skipped reason=failure_cooldown trigger=\(reason, privacy: .public) next_attempt_at=\(nextForegroundSyncAttemptAt.timeIntervalSince1970, privacy: .public)"
            )
            return
        }
        guard !isForegroundSyncRunning else {
            if reason == "local_change" {
                isForegroundSyncRerunPending = true
            }
            EditorLog.sync.debug(
                "foreground_sync_skipped reason=already_running trigger=\(reason, privacy: .public) rerun_pending=\(self.isForegroundSyncRerunPending, privacy: .public)"
            )
            return
        }

        isForegroundSyncRunning = true
        syncStatusText = "同步中..."
        let syncEngine = syncEngine!
        EditorLog.sync.debug(
            "foreground_sync_scheduled reason=\(reason, privacy: .public)"
        )
        recordForegroundSyncDiagnostic(
            eventName: "foreground_sync_scheduled",
            payload: ["reason": reason]
        )
        syncScheduler.scheduleForegroundSync(
            operation: {
                Self.runForegroundSync(syncEngine: syncEngine)
            },
            completion: { [weak self] result in
                self?.finishForegroundSync(result)
            }
        )
    }

    private func startObservingSyncChangesIfNeeded() {
        guard let repository, syncEngine != nil else {
            return
        }

        let observer = NotificationCenter.default.addObserver(
            forName: .editorSyncChangeEnqueued,
            object: repository.syncChangeNotificationObject,
            queue: nil
        ) { [weak self] _ in
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self?.syncAfterLocalChange()
                }
            } else {
                Task { @MainActor [weak self] in
                    self?.syncAfterLocalChange()
                }
            }
        }
        syncChangeObservation = SyncChangeObservation(observer: observer)
    }

    func selectPage(id: String) {
        selectPage(id: id, collection: defaultCollectionForOpeningPage(id: id), recordHistory: true)
    }

    func selectPageForUI(id pageID: String) async {
        guard await unlockEncryptedPageForUIIfNeeded(id: pageID) else {
            return
        }
        selectPage(id: pageID)
    }

    @discardableResult
    func unlockSelectedEncryptedPageForUI() async -> Bool {
        guard let selectedPageID else {
            return false
        }
        return await unlockEncryptedPageForUIIfNeeded(id: selectedPageID)
    }

    func isEncryptedPageUnlocked(_ pageID: String) -> Bool {
        guard snapshot.pages.contains(where: { $0.id == pageID && $0.isEncrypted }) else {
            return true
        }
        return unlockedEncryptedPageIDs.contains(pageID)
    }

    func isEncryptedPageLocked(_ pageID: String) -> Bool {
        !isEncryptedPageUnlocked(pageID)
    }

    func lockExpiredEncryptedPagesForUI() {
        lockExpiredEncryptedPages(now: currentDateProvider())
    }

    private func isPageContentVisible(pageID: String) -> Bool {
        isEncryptedPageUnlocked(pageID)
    }

    @discardableResult
    private func unlockEncryptedPageForUIIfNeeded(id pageID: String) async -> Bool {
        guard snapshot.pages.contains(where: { $0.id == pageID && $0.isEncrypted }) else {
            return true
        }
        guard !unlockedEncryptedPageIDs.contains(pageID) else {
            markEncryptedPageOpened(pageID)
            return true
        }
        guard authenticatingEncryptedPageID != pageID else {
            return false
        }

        authenticatingEncryptedPageID = pageID
        EditorLog.security.debug(
            "encrypted_page_unlock_requested page_id=\(pageID, privacy: .public)"
        )
        let didAuthenticate = await encryptedPageAuthenticator.authenticateForEncryptedPage()
        authenticatingEncryptedPageID = nil

        if didAuthenticate {
            unlockedEncryptedPageIDs.insert(pageID)
            markEncryptedPageOpened(pageID)
            EditorLog.security.debug(
                "encrypted_page_unlocked page_id=\(pageID, privacy: .public)"
            )
            return true
        }

        EditorLog.security.error(
            "encrypted_page_unlock_denied page_id=\(pageID, privacy: .public)"
        )
        return false
    }

    private func markEncryptedPageOpened(_ pageID: String) {
        guard snapshot.pages.contains(where: { $0.id == pageID && $0.isEncrypted }) else {
            return
        }

        encryptedPageLastOpenedAt[pageID] = currentDateProvider()
    }

    private func lockExpiredEncryptedPages(now: Date) {
        guard !unlockedEncryptedPageIDs.isEmpty else {
            return
        }

        let encryptedPageIDs = Set(snapshot.pages.filter(\.isEncrypted).map(\.id))
        let expiredPageIDs = unlockedEncryptedPageIDs.filter { pageID in
            guard encryptedPageIDs.contains(pageID) else {
                return true
            }
            guard selectedPageID != pageID else {
                return false
            }
            guard let lastOpenedAt = encryptedPageLastOpenedAt[pageID] else {
                return true
            }
            return now.timeIntervalSince(lastOpenedAt) >= Self.encryptedPageAutoLockInterval
        }

        for pageID in expiredPageIDs {
            unlockedEncryptedPageIDs.remove(pageID)
            encryptedPageLastOpenedAt.removeValue(forKey: pageID)
            EditorLog.security.debug(
                "encrypted_page_auto_locked page_id=\(pageID, privacy: .public)"
            )
        }
    }

    private func scheduleEncryptedPageAutoLockIfNeeded(leftPageID: String?) {
        guard let leftPageID,
              unlockedEncryptedPageIDs.contains(leftPageID),
              snapshot.pages.contains(where: { $0.id == leftPageID && $0.isEncrypted })
        else {
            return
        }

        encryptedPageAutoLockTask?.cancel()
        encryptedPageAutoLockTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.encryptedPageAutoLockIntervalNanoseconds)
            } catch {
                return
            }
            self?.lockExpiredEncryptedPagesForUI()
        }
    }

    private func selectPage(
        id: String,
        collection: WorkspaceCollection,
        recordHistory: Bool
    ) {
        let previousSelectedPageID = selectedPageID
        if recordHistory {
            recordNavigationHistoryBeforeOpening(pageID: id)
        }
        hydrateBlocksForPageIfNeededForUI(id)
        selectedPageID = id
        selectedCollection = collection
        selectedNotebookID = snapshot.pages.first { $0.id == id }?.notebookID ?? selectedNotebookID
        refreshBacklinksForSelectedPage()
        refreshExternalLinksForSelectedPage()
        refreshConflictsForSelectedPage()
        if previousSelectedPageID != id {
            scheduleEncryptedPageAutoLockIfNeeded(leftPageID: previousSelectedPageID)
        }
    }

    private var diaryPageIDs: Set<String> {
        cachedDiaryPageIDs
    }

    private var visibleDiaryPageIDs: Set<String> {
        diaryPageIDs.subtracting(snapshot.emptyDiaryPageIDs)
    }

    private func hydrateBlocksForSelectedPageIfNeeded() throws {
        guard let selectedPageID else {
            return
        }
        try hydrateBlocksForPageIfNeeded(selectedPageID)
    }

    private func hydrateBlocksForPageIfNeeded(_ pageID: String) throws {
        guard let repository,
              !snapshot.blocks.contains(where: { $0.pageID == pageID }) else {
            return
        }
        let blocks = try repository.loadBlocks(pageID: pageID)
        snapshot = snapshot.replacingBlocks(pageID: pageID, blocks: blocks)
    }

    private func hydrateBlocksForPageIfNeededForUI(_ pageID: String) {
        let startedAt = Date()
        let wasAlreadyHydrated = snapshot.blocks.contains { $0.pageID == pageID }
        do {
            try hydrateBlocksForPageIfNeeded(pageID)
            let durationMilliseconds = Self.millisecondsElapsed(since: startedAt)
            let blockCount = snapshot.blocks.filter { $0.pageID == pageID }.count
            EditorLog.render.debug(
                "page_blocks_hydrated page_id=\(pageID, privacy: .public) already_loaded=\(wasAlreadyHydrated, privacy: .public) blocks=\(blockCount, privacy: .public) duration_ms=\(durationMilliseconds, privacy: .public)"
            )
            if durationMilliseconds >= 100 {
                try? repository?.recordRuntimeDiagnostic(
                    eventName: "page_blocks_hydration_slow",
                    payload: [
                        "page_id": pageID,
                        "already_loaded": wasAlreadyHydrated,
                        "block_count": blockCount,
                        "duration_ms": durationMilliseconds
                    ]
                )
            }
        } catch {
            EditorLog.store.error(
                "page_blocks_hydration_failed page_id=\(pageID, privacy: .public) duration_ms=\(Self.millisecondsElapsed(since: startedAt), privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
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
        case .encrypted where snapshot.pages.contains(where: { $0.id == pageID && $0.isEncrypted }):
            return .encrypted
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

    func addTagToSelectedPageForUI(tagID: String) -> Bool {
        guard let selectedPageID else {
            return false
        }
        return assignTagsForUI(
            pageID: selectedPageID,
            transform: { $0.union([tagID]) },
            logAction: "page_tag_add"
        )
    }

    func removeTagFromSelectedPageForUI(tagID: String) -> Bool {
        guard let selectedPageID else {
            return false
        }
        return assignTagsForUI(
            pageID: selectedPageID,
            transform: { $0.subtracting([tagID]) },
            logAction: "page_tag_remove"
        )
    }

    func createAndAssignTagToSelectedPageForUI(name: String) -> Bool {
        guard let tagRepository,
              let selectedWorkspaceID else {
            return false
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return false
        }

        do {
            let tag = try findOrCreateTagPath(
                trimmedName,
                workspaceID: selectedWorkspaceID,
                tagRepository: tagRepository
            )
            return addTagToSelectedPageForUI(tagID: tag.id)
        } catch {
            EditorLog.input.error(
                "page_tag_create_failed name=\(trimmedName, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func assignTagToPagesForUI(pageIDs: [String], tagID: String) -> Bool {
        guard let tagRepository,
              !pageIDs.isEmpty else {
            return false
        }

        let validPageIDs = orderedUniquePageIDs(pageIDs).filter { pageID in
            snapshot.pages.contains { $0.id == pageID }
        }
        guard !validPageIDs.isEmpty else {
            return false
        }

        let previousSelectedCollection = selectedCollection
        let previousSelectedPageID = selectedPageID
        do {
            let assignments = try tagRepository.tagAssignments()
            for pageID in validPageIDs {
                var tagIDs = Set(assignments.filter { $0.pageID == pageID }.map(\.tagID))
                tagIDs.insert(tagID)
                try tagRepository.assignTags(pageID: pageID, tagIDs: sortedTagIDs(tagIDs))
            }
            if let repository {
                let loadedSnapshot = try repository.loadWorkspaceSnapshot()
                apply(snapshot: loadedSnapshot)
            }
            restoreSelectionAfterReload(collection: previousSelectedCollection, pageID: previousSelectedPageID)
            EditorLog.input.debug(
                "page_tag_batch_assigned tag_id=\(tagID, privacy: .public) count=\(validPageIDs.count, privacy: .public)"
            )
            return true
        } catch {
            restoreSelectionAfterReload(collection: previousSelectedCollection, pageID: previousSelectedPageID)
            EditorLog.input.error(
                "page_tag_batch_assign_failed tag_id=\(tagID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func deleteTagForUI(id tagID: String) -> Bool {
        guard let repository,
              let tagRepository else {
            return false
        }

        let removedTagIDs = tagIDsIncludingDescendants(of: tagID)
        guard !removedTagIDs.isEmpty else {
            return false
        }

        let previousSelectedCollection = selectedCollection
        let previousSelectedPageID = selectedPageID
        do {
            try tagRepository.deleteTag(id: tagID)
            let loadedSnapshot = try repository.loadWorkspaceSnapshot()
            apply(snapshot: loadedSnapshot)

            let nextCollection: WorkspaceCollection
            if case .tag(let selectedTagID) = previousSelectedCollection,
               removedTagIDs.contains(selectedTagID) {
                nextCollection = .allDocuments
            } else {
                nextCollection = previousSelectedCollection
            }
            restoreSelectionAfterReload(collection: nextCollection, pageID: previousSelectedPageID)
            refreshBacklinksForSelectedPage()
            refreshExternalLinksForSelectedPage()
            refreshConflictsForSelectedPage()
            EditorLog.input.debug(
                "tag_deleted tag_id=\(tagID, privacy: .public) removed_count=\(removedTagIDs.count, privacy: .public)"
            )
            return true
        } catch {
            restoreSelectionAfterReload(collection: previousSelectedCollection, pageID: previousSelectedPageID)
            EditorLog.input.error(
                "tag_delete_failed tag_id=\(tagID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func selectSearchResult(_ result: SearchResult) {
        guard let destinationPageID = result.destinationPageID else {
            EditorLog.render.debug(
                "search_result_selection_ignored entity_type=\(result.entityType, privacy: .public) entity_id=\(result.entityID, privacy: .public)"
            )
            return
        }

        let previousCollection = selectedCollection
        recordNavigationHistoryBeforeOpening(pageID: destinationPageID)
        selectedPageID = destinationPageID
        selectedNotebookID = snapshot.pages.first { $0.id == destinationPageID }?.notebookID ?? selectedNotebookID
        selectedCollection = previousCollection == .search ? .search : defaultCollectionForOpeningPage(id: destinationPageID)
        pendingCompactPageNavigationID = destinationPageID
        if let destinationBlockID = result.destinationBlockID {
            pendingFocusBlockID = destinationBlockID
            queueSearchHighlight(for: result, blockID: destinationBlockID)
        }
        refreshBacklinksForSelectedPage()
        refreshExternalLinksForSelectedPage()
        refreshConflictsForSelectedPage()
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
        requestBlockFocus(item.blockID)
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
            guard try openDailyDiaryPage(source: "shortcut_today", recordHistory: true) != nil else {
                return false
            }
            try focusBottomEmptyTextBlockForCurrentPage(source: "shortcut_today")
            return true
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
            let page = try createPageInSelectedWorkspace(
                title: "",
                initialFocus: .pageTitle
            )
            pendingCompactPageNavigationID = page.id
            pendingPageTitleFocusPageID = page.id
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

    func createDailyDiaryForCompactUI() -> String? {
        do {
            guard let page = try openDailyDiaryPage(source: "compact_daily_create", recordHistory: true) else {
                return nil
            }
            try focusBottomEmptyTextBlockForCurrentPage(source: "compact_daily_create")
            pendingCompactPageNavigationID = page.id
            EditorLog.render.debug(
                "compact_page_navigation_queued page_id=\(page.id, privacy: .public) source=compact_daily_create"
            )
            return page.id
        } catch {
            EditorLog.input.error(
                "compact_daily_create_failed error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    func openQuickSearchForUI() -> Bool {
        clearSearchForUI()
        selectedCollection = .allDocuments
        pendingCompactPageNavigationID = nil
        pendingCompactCollectionNavigation = .allDocuments
        EditorLog.render.debug("compact_collection_navigation_queued collection=all_documents source=quick_search")
        return true
    }

    func performHomeScreenQuickAction(_ action: EditorHomeScreenQuickAction) -> Bool {
        switch action {
        case .openDiary:
            return createDailyDiaryForCompactUI() != nil
        case .createNote:
            return createNewDocumentForCompactUI() != nil
        case .quickSearch:
            return openQuickSearchForUI()
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
        guard isPageContentVisible(pageID: pageID) else {
            return []
        }
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
            try performPageEdit(pageID: block.pageID, focusBlockID: blockID) {
                try repository?.updateCodeBlockLineWrapping(blockID: blockID, isWrapped: isWrapped)
                snapshot = snapshot.replacingCodeBlockLineWrapping(blockID: blockID, isWrapped: isWrapped)
            }
        } catch {
            EditorLog.render.error(
                "code_block_line_wrapping_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return
        }
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
            try performPageEdit(pageID: block.pageID, focusBlockID: blockID) {
                try repository?.updateToggleExpansion(blockID: blockID, isExpanded: isExpanded)
                snapshot = snapshot.replacingToggleExpansion(blockID: blockID, isExpanded: isExpanded)
            }
        } catch {
            EditorLog.render.error(
                "toggle_block_expansion_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return
        }
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
            pendingFocusRequestID = nil
        }
        return pendingFocusBlockID
    }

    private func requestBlockFocus(_ blockID: String) {
        pendingFocusBlockID = blockID
        pendingFocusRequestID = UUID()
    }

    @discardableResult
    func consumePendingPageTitleFocusPageID() -> String? {
        defer {
            pendingPageTitleFocusPageID = nil
        }
        return pendingPageTitleFocusPageID
    }

    @discardableResult
    func consumePendingCompactPageNavigationID() -> String? {
        defer {
            pendingCompactPageNavigationID = nil
        }
        return pendingCompactPageNavigationID
    }

    @discardableResult
    func consumePendingCompactCollectionNavigation() -> WorkspaceCollection? {
        defer {
            pendingCompactCollectionNavigation = nil
        }
        return pendingCompactCollectionNavigation
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
        let nextBlock = nextBlockState(currentType: currentType, text: text)
        guard !isNoOpBlockTextUpdate(currentBlock: currentBlock, nextBlock: nextBlock) else {
            return
        }
        let coalescingKey = makeTextEditUndoCoalescingKey(
            blockID: blockID,
            currentBlock: currentBlock,
            nextType: nextBlock.type,
            registerUndo: registerUndo
        )

        try performPageEdit(
            pageID: registerUndo ? currentBlock?.pageID ?? selectedPageID : nil,
            focusBlockID: blockID,
            coalescingKey: coalescingKey
        ) {
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
            if currentType != nextBlock.type {
                pendingFocusBlockID = blockID
                EditorLog.focus.debug(
                    "editor_focus_request_queued block_id=\(blockID, privacy: .public) source=markdown_shortcut"
                )
            }
            try syncInlineHashTagsIfNeeded(pageID: currentBlock?.pageID, text: nextBlock.text)
            try refreshDerivedState(rebuildSearchIndex: true, changedBlockID: blockID)
        }
    }

    func undoLastTextEdit() throws {
        guard let undoSnapshot = pageEditUndoStack.last else {
            return
        }

        try restorePageBlocks(pageID: undoSnapshot.pageID, blocks: undoSnapshot.beforeBlocks)
        _ = pageEditUndoStack.popLast()
        pageEditRedoStack.append(undoSnapshot)
        refreshPageEditUndoAvailability()
        pendingFocusBlockID = undoSnapshot.focusBlockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(undoSnapshot.focusBlockID ?? "none", privacy: .public) source=page_edit_undo"
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

    func redoLastTextEdit() throws {
        guard let redoSnapshot = pageEditRedoStack.last else {
            return
        }

        try restorePageBlocks(pageID: redoSnapshot.pageID, blocks: redoSnapshot.afterBlocks)
        _ = pageEditRedoStack.popLast()
        pageEditUndoStack.append(redoSnapshot)
        if pageEditUndoStack.count > pageEditUndoHistoryLimit {
            pageEditUndoStack.removeFirst(pageEditUndoStack.count - pageEditUndoHistoryLimit)
        }
        refreshPageEditUndoAvailability()
        pendingFocusBlockID = redoSnapshot.focusBlockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(redoSnapshot.focusBlockID ?? "none", privacy: .public) source=page_edit_redo"
        )
    }

    func redoLastTextEditForUI() {
        do {
            try redoLastTextEdit()
            EditorLog.input.debug("text_edit_redo_visible")
        } catch {
            EditorLog.input.error(
                "text_edit_redo_failed error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func changeBlockType(blockID: String, type: BlockType) throws {
        guard let block = snapshot.blocks.first(where: { $0.id == blockID }) else {
            throw PageRepositoryError.blockNotFound
        }

        try performPageEdit(pageID: block.pageID, focusBlockID: blockID) {
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
        }
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
        try performPageEdit(
            pageID: currentBlock.pageID,
            focusBlockID: blockID,
            coalescingKey: .blockContent(blockID: blockID, type: .table)
        ) {
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
        }
    }

    func updateTaskItemCompletion(blockID: String, isCompleted: Bool) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let block = snapshot.blocks.first(where: { $0.id == blockID }) else {
            throw PageRepositoryError.blockNotFound
        }

        try performPageEdit(pageID: block.pageID, focusBlockID: blockID) {
            try repository.updateTaskItemCompletion(blockID: blockID, isCompleted: isCompleted)
            snapshot = snapshot.replacingTaskItemCompletion(blockID: blockID, isCompleted: isCompleted)
            try refreshDerivedState(rebuildSearchIndex: false)
        }
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

    func updatePagePinned(id pageID: String, isPinned: Bool) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let previousCollection = selectedCollection
        let previousPageID = selectedPageID
        try repository.updatePagePinned(pageID: pageID, isPinned: isPinned)
        let loadedSnapshot = try repository.loadWorkspaceSnapshot()
        apply(snapshot: loadedSnapshot)
        restoreSelectionAfterReload(collection: previousCollection, pageID: previousPageID)
        try refreshDerivedState(rebuildSearchIndex: false)
    }

    func updatePageEncryption(id pageID: String, isEncrypted: Bool) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let previousCollection = selectedCollection
        let previousPageID = selectedPageID
        try repository.updatePageEncryption(pageID: pageID, isEncrypted: isEncrypted)
        let loadedSnapshot = try repository.loadWorkspaceSnapshot()
        apply(snapshot: loadedSnapshot)
        restoreSelectionAfterReload(collection: previousCollection, pageID: previousPageID)
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

        var block: BlockSnapshot?
        try performPageEdit(pageID: selectedPageID, focusBlockID: nil) {
            block = try repository.appendBlock(
                pageID: selectedPageID,
                type: .paragraph,
                text: ""
            )
            try load()
        }
        guard let block else {
            throw PageRepositoryError.blockNotFound
        }
        updateLastPageEditFocusBlockID(pageID: selectedPageID, focusBlockID: block.id)
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
        var block: BlockSnapshot?
        try performPageEdit(pageID: selectedPageID, focusBlockID: nil) {
            block = try repository.appendPageReferenceBlock(
                pageID: selectedPageID,
                targetPageID: targetPageID
            )
            try load()
            restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
        }
        guard let block else {
            throw PageRepositoryError.blockNotFound
        }
        updateLastPageEditFocusBlockID(pageID: selectedPageID, focusBlockID: block.id)
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
        var block: BlockSnapshot?
        try performPageEdit(pageID: selectedPageID, focusBlockID: nil) {
            block = try repository.appendBlockReferenceBlock(
                pageID: selectedPageID,
                targetBlockID: targetBlockID
            )
            try load()
            restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
        }
        guard let block else {
            throw PageRepositoryError.blockNotFound
        }
        updateLastPageEditFocusBlockID(pageID: selectedPageID, focusBlockID: block.id)
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
        notebookID: String? = nil,
        initialFocus: WorkspacePageCreationFocus = .initialBlock
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
            notebookID: notebookID ?? selectedNotebookID,
            isEncrypted: selectedCollection == .encrypted
        )
        try load()
        selectPage(id: page.id)
        switch initialFocus {
        case .initialBlock:
            requestFocusForInitialEmptyBlockIfNeeded(source: "page_create")
        case .pageTitle:
            pendingFocusBlockID = nil
            pendingPageTitleFocusPageID = page.id
            EditorLog.focus.debug(
                "editor_page_title_focus_queued page_id=\(page.id, privacy: .public) source=page_create"
            )
        }
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
        refreshPageArchiveUndoAvailability()
        guard let undoSnapshot = pageArchiveUndoStack.last else {
            return
        }
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        for pageID in undoSnapshot.pageIDs {
            try repository.restorePage(pageID: pageID)
        }
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

    func updatePagePinnedForUI(id pageID: String, isPinned: Bool) {
        do {
            try updatePagePinned(id: pageID, isPinned: isPinned)
            EditorLog.input.debug(
                "page_pinned_visible page_id=\(pageID, privacy: .public) is_pinned=\(isPinned, privacy: .public)"
            )
        } catch {
            EditorLog.input.error(
                "page_pinned_failed page_id=\(pageID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func updatePageEncryptionForUI(id pageID: String, isEncrypted: Bool) {
        do {
            try updatePageEncryption(id: pageID, isEncrypted: isEncrypted)
            unlockedEncryptedPageIDs.remove(pageID)
            encryptedPageLastOpenedAt.removeValue(forKey: pageID)
            EditorLog.input.debug(
                "page_encryption_visible page_id=\(pageID, privacy: .public) is_encrypted=\(isEncrypted, privacy: .public)"
            )
        } catch {
            EditorLog.input.error(
                "page_encryption_failed page_id=\(pageID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func archivePagesForUI(pageIDs: [String]) -> Bool {
        guard let repository,
              !pageIDs.isEmpty else {
            return false
        }

        let validPageIDs = orderedUniquePageIDs(pageIDs).filter { pageID in
            snapshot.pages.contains { $0.id == pageID }
        }
        guard !validPageIDs.isEmpty else {
            return false
        }

        let previousNotebookID = selectedNotebookID
        let previousPageID = selectedPageID
        do {
            for pageID in validPageIDs {
                try repository.archivePage(pageID: pageID)
            }
            try load()
            recordPageArchiveUndoSnapshot(
                pageIDs: validPageIDs,
                previousNotebookID: previousNotebookID,
                previousPageID: previousPageID
            )
            restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
            EditorLog.input.debug("page_archive_batch_visible count=\(validPageIDs.count, privacy: .public)")
            return true
        } catch {
            restoreSelection(previousNotebookID: previousNotebookID, previousPageID: previousPageID)
            EditorLog.input.error(
                "page_archive_batch_failed count=\(validPageIDs.count, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
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

    func expirePageArchiveUndoForUI() {
        refreshPageArchiveUndoAvailability()
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

        let pageID = snapshot.blocks.first(where: { $0.id == blockID })?.pageID
        try performPageEdit(pageID: pageID, focusBlockID: blockID) {
            try repository.moveBlock(blockID: blockID, toIndex: toIndex)
            try load()
        }
    }

    func moveBlocks(blockIDs: [String], toIndex: Int) throws {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let pageID = blockIDs.compactMap { blockID in
            snapshot.blocks.first(where: { $0.id == blockID })?.pageID
        }.first
        try performPageEdit(pageID: pageID, focusBlockID: blockIDs.first) {
            try repository.moveBlocks(blockIDs: blockIDs, toIndex: toIndex)
            try load()
        }
    }

    @discardableResult
    func updateBlockParent(blockID: String, parentBlockID: String?) throws -> Bool {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let pageID = snapshot.blocks.first(where: { $0.id == blockID })?.pageID
        var didUpdate = false
        try performPageEdit(pageID: pageID, focusBlockID: blockID) {
            didUpdate = try repository.updateBlockParent(blockID: blockID, parentBlockID: parentBlockID)
            guard didUpdate else {
                return
            }
            try load()
        }
        guard didUpdate else {
            return false
        }

        pendingFocusBlockID = blockID
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(blockID, privacy: .public) source=block_reparent"
        )
        return true
    }

    @discardableResult
    func insertParagraphBlock(after blockID: String) throws -> String {
        guard let repository else {
            throw WorkspaceViewModelError.missingRepository
        }

        let pageID = snapshot.blocks.first(where: { $0.id == blockID })?.pageID
        var block: BlockSnapshot?
        try performPageEdit(pageID: pageID, focusBlockID: nil) {
            block = try repository.insertParagraphBlock(after: blockID)
            try load()
        }
        guard let block else {
            throw PageRepositoryError.blockNotFound
        }
        if let pageID {
            updateLastPageEditFocusBlockID(pageID: pageID, focusBlockID: block.id)
        }
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

        let insertedBlockType = TextBlockSplitPolicy.insertedBlockType(after: block.type)
        var insertedBlock: BlockSnapshot?
        try performPageEdit(pageID: block.pageID, focusBlockID: nil) {
            try repository.updateBlock(
                blockID: blockID,
                type: block.type,
                text: leadingText,
                taskItemIsCompleted: block.taskItemIsCompleted,
                toggleIsExpanded: block.toggleIsExpanded,
                codeBlockLineWrapping: block.codeBlockLineWrapping
            )
            insertedBlock = try repository.insertParagraphBlock(after: blockID, text: trailingText)
            if let insertedBlock, insertedBlockType != .paragraph {
                try repository.updateBlock(
                    blockID: insertedBlock.id,
                    type: insertedBlockType,
                    text: trailingText,
                    taskItemIsCompleted: false
                )
            }
            try load()
        }
        guard let insertedBlock else {
            throw PageRepositoryError.blockNotFound
        }
        updateLastPageEditFocusBlockID(pageID: block.pageID, focusBlockID: insertedBlock.id)
        pendingFocusBlockID = insertedBlock.id
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(insertedBlock.id, privacy: .public) source=split_text_block"
        )
        return EditorTextSelection(blockID: insertedBlock.id, location: 0, length: 0)
    }

    @discardableResult
    func replaceTextAtSelection(
        selection: EditorTextSelection,
        replacementText: String
    ) throws -> EditorTextSelection? {
        guard let block = snapshot.blocks.first(where: { $0.id == selection.blockID && $0.type.isTextEditable }) else {
            return nil
        }

        let nsText = block.textPlain as NSString
        guard selection.location >= 0,
              selection.length >= 0,
              selection.location <= nsText.length,
              selection.length <= nsText.length - selection.location else {
            return nil
        }

        let selectedRange = NSRange(location: selection.location, length: selection.length)
        let updatedText = nsText.replacingCharacters(in: selectedRange, with: replacementText)
        try updateBlockText(blockID: selection.blockID, text: updatedText)

        return EditorTextSelection(
            blockID: selection.blockID,
            location: selection.location + (replacementText as NSString).length,
            length: 0
        )
    }

    @discardableResult
    func pasteTextAtSelection(
        selection: EditorTextSelection,
        pasteText: String
    ) throws -> EditorTextSelection? {
        guard let block = snapshot.blocks.first(where: { $0.id == selection.blockID && $0.type.isTextEditable }) else {
            return nil
        }

        let pastedLines = PastedTextBlockLineResolver.lines(from: pasteText)
        guard !pastedLines.isEmpty else {
            return nil
        }

        guard pastedLines.count > 1,
              BlockKeyboardShortcutResolver.insertsBlockAfter(
                  keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                  modifiers: [],
                  blockType: block.type
              ) else {
            return try replaceTextAtSelection(selection: selection, replacementText: pastedLines[0])
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
        let insertedBlockType = TextBlockSplitPolicy.insertedBlockType(after: block.type)
        let lastPastedLine = pastedLines[pastedLines.count - 1]
        let subsequentLines = Array(pastedLines.dropFirst())
        var lastInsertedBlock: BlockSnapshot?

        try performPageEdit(pageID: block.pageID, focusBlockID: nil) {
            try repository.updateBlock(
                blockID: block.id,
                type: block.type,
                text: leadingText + pastedLines[0],
                taskItemIsCompleted: block.taskItemIsCompleted,
                toggleIsExpanded: block.toggleIsExpanded,
                codeBlockLineWrapping: block.codeBlockLineWrapping
            )

            var anchorBlockID = block.id
            for (index, line) in subsequentLines.enumerated() {
                let isLastInsertedLine = index == subsequentLines.count - 1
                let insertedText = isLastInsertedLine ? line + trailingText : line
                let insertedBlock = try repository.insertParagraphBlock(after: anchorBlockID, text: insertedText)
                if insertedBlockType != .paragraph {
                    try repository.updateBlock(
                        blockID: insertedBlock.id,
                        type: insertedBlockType,
                        text: insertedText,
                        taskItemIsCompleted: false
                    )
                }
                anchorBlockID = insertedBlock.id
                lastInsertedBlock = insertedBlock
            }

            try load()
        }

        guard let lastInsertedBlock else {
            return nil
        }
        updateLastPageEditFocusBlockID(pageID: block.pageID, focusBlockID: lastInsertedBlock.id)
        pendingFocusBlockID = lastInsertedBlock.id
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(lastInsertedBlock.id, privacy: .public) source=paste_text_split"
        )
        return EditorTextSelection(
            blockID: lastInsertedBlock.id,
            location: (lastPastedLine as NSString).length,
            length: 0
        )
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
            try performPageEdit(pageID: currentBlock.pageID, focusBlockID: blockID) {
                try repository.updateBlock(
                    blockID: blockID,
                    type: .paragraph,
                    text: currentBlock.textPlain,
                    taskItemIsCompleted: false,
                    toggleIsExpanded: currentBlock.toggleIsExpanded,
                    codeBlockLineWrapping: currentBlock.codeBlockLineWrapping
                )
                try load()
            }
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
            var didOutdent = false
            try performPageEdit(pageID: currentBlock.pageID, focusBlockID: blockID) {
                didOutdent = try repository.outdentBlock(blockID: blockID)
                guard didOutdent else {
                    return
                }
                try load()
            }
            guard didOutdent else {
                return nil
            }
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
        try performPageEdit(pageID: currentBlock.pageID, focusBlockID: previousBlock.id) {
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
        }
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

        try performPageEdit(pageID: currentBlock.pageID, focusBlockID: currentBlock.id) {
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
        }
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

        let pageID = snapshot.blocks.first(where: { $0.id == blockID })?.pageID
        var didIndent = false
        try performPageEdit(pageID: pageID, focusBlockID: blockID) {
            didIndent = try repository.indentBlock(blockID: blockID)
            guard didIndent else {
                return
            }
            try load()
        }
        guard didIndent else {
            return false
        }

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

        let pageID = snapshot.blocks.first(where: { $0.id == blockID })?.pageID
        var didOutdent = false
        try performPageEdit(pageID: pageID, focusBlockID: blockID) {
            didOutdent = try repository.outdentBlock(blockID: blockID)
            guard didOutdent else {
                return
            }
            try load()
        }
        guard didOutdent else {
            return false
        }

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

        let pageID = snapshot.blocks.first(where: { $0.id == blockID })?.pageID
        try performPageEdit(pageID: pageID, focusBlockID: blockID) {
            try repository.deleteBlock(blockID: blockID)
            try load()
        }
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

    func updateBlockParentForUI(blockID: String, parentBlockID: String?) -> Bool {
        do {
            let didUpdate = try updateBlockParent(blockID: blockID, parentBlockID: parentBlockID)
            if didUpdate {
                EditorLog.store.debug(
                    "block_parent_update_visible block_id=\(blockID, privacy: .public) parent_block_id=\(parentBlockID ?? "root", privacy: .public)"
                )
            }
            return didUpdate
        } catch {
            EditorLog.store.error(
                "block_parent_update_failed block_id=\(blockID, privacy: .public) parent_block_id=\(parentBlockID ?? "root", privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
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

    func replaceTextAtSelectionForUI(
        selection: EditorTextSelection,
        replacementText: String
    ) -> EditorTextSelection? {
        do {
            let nextSelection = try replaceTextAtSelection(selection: selection, replacementText: replacementText)
            if nextSelection != nil {
                EditorLog.input.debug(
                    "text_replaced_at_selection block_id=\(selection.blockID, privacy: .public) location=\(selection.location, privacy: .public) length=\(selection.length, privacy: .public) replacement_length=\(replacementText.count, privacy: .public)"
                )
            }
            return nextSelection
        } catch {
            EditorLog.input.error(
                "text_replace_at_selection_failed block_id=\(selection.blockID, privacy: .public) location=\(selection.location, privacy: .public) length=\(selection.length, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    func pasteTextAtSelectionForUI(
        selection: EditorTextSelection,
        pasteText: String
    ) -> EditorTextSelection? {
        do {
            let nextSelection = try pasteTextAtSelection(selection: selection, pasteText: pasteText)
            if let nextSelection {
                EditorLog.input.debug(
                    "text_pasted_at_selection block_id=\(selection.blockID, privacy: .public) location=\(selection.location, privacy: .public) length=\(selection.length, privacy: .public) paste_length=\(pasteText.count, privacy: .public) focus_block_id=\(nextSelection.blockID, privacy: .public)"
                )
            }
            return nextSelection
        } catch {
            EditorLog.input.error(
                "text_paste_at_selection_failed block_id=\(selection.blockID, privacy: .public) location=\(selection.location, privacy: .public) length=\(selection.length, privacy: .public) error=\(String(describing: error), privacy: .public)"
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

            let pageID = uniqueBlockIDs.compactMap { blockID in
                snapshot.blocks.first(where: { $0.id == blockID })?.pageID
            }.first
            try performPageEdit(pageID: pageID, focusBlockID: uniqueBlockIDs.first) {
                for blockID in uniqueBlockIDs {
                    try repository.deleteBlock(blockID: blockID)
                }
                try load()
            }
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
            scheduleAttachmentTextRecognitionIfNeeded(attachmentID: result.attachment.id)
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
    func importObsidianVault(vaultURL: URL) throws -> ObsidianVaultImportSummary {
        guard let obsidianImporter else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let selectedWorkspaceID else {
            throw WorkspaceViewModelError.missingSelection
        }

        let summary = try obsidianImporter.importVault(
            vaultURL: vaultURL,
            workspaceID: selectedWorkspaceID
        )
        try load()
        markdownImportStatusText = Self.obsidianImportStatusText(summary: summary)
        return summary
    }

    func importObsidianVaultForCurrentWorkspace(sourceURL: URL) {
        guard let obsidianImporter else {
            EditorLog.markdown.error("obsidian_vault_import_failed reason=missing_importer")
            return
        }
        guard let selectedWorkspaceID else {
            EditorLog.markdown.error("obsidian_vault_import_failed reason=missing_workspace")
            return
        }
        guard !isObsidianImportRunning else {
            markdownImportStatusText = "Obsidian import already running"
            EditorLog.markdown.debug("obsidian_vault_import_skipped reason=already_running")
            return
        }

        isObsidianImportRunning = true
        shouldSyncAfterObsidianImport = false
        markdownImportStatusText = "Importing Obsidian vault..."
        EditorLog.markdown.debug(
            "obsidian_vault_import_scheduled source=\(sourceURL.lastPathComponent, privacy: .public)"
        )
        obsidianImportScheduler.scheduleObsidianImport(
            operation: {
                do {
                    return .success(
                        try obsidianImporter.importVaultInBatches(
                            vaultURL: sourceURL,
                            workspaceID: selectedWorkspaceID
                        )
                    )
                } catch {
                    return .failure(String(describing: error))
                }
            },
            completion: { [weak self] result in
                self?.finishObsidianVaultImport(sourceURL: sourceURL, result: result)
            }
        )
    }

    private func finishObsidianVaultImport(sourceURL: URL, result: WorkspaceObsidianImportResult) {
        isObsidianImportRunning = false
        switch result {
        case .success(let summary):
            do {
                try load()
                markdownImportStatusText = Self.obsidianImportStatusText(summary: summary)
                EditorLog.markdown.debug(
                    "obsidian_vault_imported source=\(sourceURL.lastPathComponent, privacy: .public) imported=\(summary.importedPageCount, privacy: .public) encrypted=\(summary.encryptedPageCount, privacy: .public) diary=\(summary.diaryPageCount, privacy: .public)"
                )
                if shouldSyncAfterObsidianImport || summary.importedPageCount > 0 || summary.importedAttachmentCount > 0 {
                    shouldSyncAfterObsidianImport = false
                    scheduleForegroundSyncIfNeeded(reason: "obsidian_import")
                }
            } catch {
                markdownImportStatusText = "Obsidian import completed, reload failed"
                EditorLog.markdown.error(
                    "obsidian_vault_import_reload_failed source=\(sourceURL.lastPathComponent, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        case .failure(let message):
            shouldSyncAfterObsidianImport = false
            markdownImportStatusText = "Obsidian import failed"
            EditorLog.markdown.error(
                "obsidian_vault_import_failed source=\(sourceURL.lastPathComponent, privacy: .public) error=\(message, privacy: .public)"
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

    func renameAttachmentImage(blockID: String, name: String) throws {
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayName.isEmpty,
              let block = snapshot.blocks.first(where: { $0.id == blockID }),
              block.type == .attachmentImage else {
            throw PageRepositoryError.blockNotFound
        }

        try performPageEdit(pageID: block.pageID, focusBlockID: blockID) {
            if let repository {
                try repository.updateBlock(
                    blockID: blockID,
                    type: .attachmentImage,
                    text: displayName,
                    attachmentDisplayWidth: block.attachmentDisplayWidth
                )
            }

            snapshot = snapshot.replacingBlock(
                blockID: blockID,
                type: .attachmentImage,
                text: displayName
            )
            try refreshDerivedState(rebuildSearchIndex: true, changedBlockID: blockID)
        }
    }

    func renameAttachmentImageForUI(blockID: String, name: String) {
        do {
            try renameAttachmentImage(blockID: blockID, name: name)
            EditorLog.attachment.debug("attachment_image_renamed block_id=\(blockID, privacy: .public)")
        } catch {
            EditorLog.attachment.error(
                "attachment_image_rename_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func updateAttachmentImageDisplayWidth(blockID: String, displayWidth: Double) throws {
        let normalizedDisplayWidth = max(1, displayWidth.rounded())
        guard let block = snapshot.blocks.first(where: { $0.id == blockID }),
              block.type == .attachmentImage else {
            throw PageRepositoryError.blockNotFound
        }

        try performPageEdit(pageID: block.pageID, focusBlockID: blockID) {
            if let repository {
                try repository.updateBlock(
                    blockID: blockID,
                    type: .attachmentImage,
                    text: block.textPlain,
                    attachmentDisplayWidth: normalizedDisplayWidth
                )
            }

            snapshot = snapshot.replacingAttachmentDisplayWidth(
                blockID: blockID,
                displayWidth: normalizedDisplayWidth
            )
            try refreshDerivedState(rebuildSearchIndex: false)
        }
    }

    func updateAttachmentImageDisplayWidthForUI(blockID: String, displayWidth: Double) {
        do {
            try updateAttachmentImageDisplayWidth(blockID: blockID, displayWidth: displayWidth)
            EditorLog.attachment.debug(
                "attachment_image_resized block_id=\(blockID, privacy: .public) width=\(displayWidth, privacy: .public)"
            )
        } catch {
            EditorLog.attachment.error(
                "attachment_image_resize_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func updateDrawingBlock(blockID: String, data: Data) throws {
        guard let attachmentRepository else {
            throw WorkspaceViewModelError.missingRepository
        }
        guard let block = snapshot.blocks.first(where: { $0.id == blockID }),
              block.type == .drawing,
              let attachmentID = block.attachmentID else {
            throw PageRepositoryError.blockNotFound
        }

        try attachmentRepository.updateDrawingAttachment(
            attachmentID: attachmentID,
            data: data
        )
        try load()
    }

    func updateDrawingBlockForUI(blockID: String, data: Data) {
        do {
            try updateDrawingBlock(blockID: blockID, data: data)
            EditorLog.attachment.debug(
                "drawing_block_updated block_id=\(blockID, privacy: .public) bytes=\(data.count, privacy: .public)"
            )
        } catch {
            EditorLog.attachment.error(
                "drawing_block_update_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
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
        guard isSearchActive else {
            clearSearchForUI()
            return
        }
        enterSearchModeIfNeeded()
        refreshSearchResults()
    }

    func clearSearchForUI() {
        searchRefreshTask?.cancel()
        searchRefreshTask = nil
        searchHighlightClearTask?.cancel()
        searchHighlightClearTask = nil
        isSearchRefreshPending = false
        searchQuery = ""
        searchResults = []
        pendingSearchHighlight = nil
        restoreCollectionAfterSearchIfNeeded()
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
            scheduleAttachmentTextRecognitionIfNeeded(attachmentID: result.attachment.id)
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

    private static func obsidianImportStatusText(summary: ObsidianVaultImportSummary) -> String {
        let skippedSuffix = summary.skippedPageCount > 0 ? ", skipped \(summary.skippedPageCount)" : ""
        let attachmentSuffix = summary.importedAttachmentCount > 0
            ? ", \(summary.importedAttachmentCount) attachments"
            : ""
        return "Imported \(summary.importedPageCount) Obsidian notes\(attachmentSuffix)\(skippedSuffix)"
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

    private func schedulePendingImageTextRecognition() {
        guard let attachmentTextRecognitionRepository,
              let attachmentTextRecognitionScheduler,
              imageTextRecognizer != nil,
              !isLoadingPendingTextRecognitionAttachmentIDs else {
            return
        }

        isLoadingPendingTextRecognitionAttachmentIDs = true
        attachmentTextRecognitionScheduler.schedulePendingTextRecognitionLookup(
            load: {
                try attachmentTextRecognitionRepository.pendingImageAttachmentIDs()
            },
            completion: { [weak self] result in
                guard let self else {
                    return
                }
                self.isLoadingPendingTextRecognitionAttachmentIDs = false
                switch result {
                case .success(let attachmentIDs):
                    for attachmentID in attachmentIDs {
                        self.scheduleAttachmentTextRecognitionIfNeeded(attachmentID: attachmentID)
                    }
                case .failure(let error):
                    EditorLog.attachment.error(
                        "attachment_text_recognition_pending_failed error=\(String(describing: error), privacy: .public)"
                    )
                }
            }
        )
    }

    private func scheduleAttachmentTextRecognitionIfNeeded(attachmentID: String) {
        guard let attachmentTextRecognitionRepository,
              let attachmentTextRecognitionScheduler,
              let imageTextRecognizer,
              !pendingTextRecognitionAttachmentIDs.contains(attachmentID) else {
            return
        }

        pendingTextRecognitionAttachmentIDs.insert(attachmentID)
        let searchRepository = searchRepository
        attachmentTextRecognitionScheduler.scheduleTextRecognition(
            attachmentID: attachmentID,
            recognize: {
                try attachmentTextRecognitionRepository.recognizeImageAttachmentIfNeeded(
                    attachmentID: attachmentID,
                    recognizer: imageTextRecognizer
                )
                try searchRepository?.updateAttachmentIndex(attachmentID: attachmentID)
            },
            completion: { [weak self] result in
                guard let self else {
                    return
                }
                self.pendingTextRecognitionAttachmentIDs.remove(attachmentID)
                switch result {
                case .success:
                    EditorLog.attachment.debug(
                        "attachment_text_recognition_indexed id=\(attachmentID, privacy: .public)"
                    )
                case .failure(let error):
                    EditorLog.attachment.error(
                        "attachment_text_recognition_failed id=\(attachmentID, privacy: .public) error=\(String(describing: error), privacy: .public)"
                    )
                }
                self.refreshSearchResults()
            }
        )
    }

    private func queueSearchHighlight(for result: SearchResult, blockID: String) {
        let transientHighlight = SearchTransientHighlight(
            blockID: blockID,
            attachmentID: result.highlight?.attachmentID,
            rects: result.highlight?.rects ?? []
        )
        pendingSearchHighlight = transientHighlight
        scheduleSearchHighlightClear(id: transientHighlight.id)
    }

    private func scheduleSearchHighlightClear(id: UUID) {
        searchHighlightClearTask?.cancel()
        searchHighlightClearTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: self?.searchHighlightDurationNanoseconds ?? 0)
            } catch {
                return
            }
            guard self?.pendingSearchHighlight?.id == id else {
                return
            }
            self?.pendingSearchHighlight = nil
        }
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
        cachedDiaryPageIDs = Set(snapshot.diaryPages.map(\.pageID))
        let encryptedPageIDs = Set(snapshot.pages.filter(\.isEncrypted).map(\.id))
        unlockedEncryptedPageIDs.formIntersection(encryptedPageIDs)
        encryptedPageLastOpenedAt = encryptedPageLastOpenedAt.filter { encryptedPageIDs.contains($0.key) }
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
        case .encrypted:
            return snapshot.pages.contains { $0.id == pageID && $0.isEncrypted }
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

        requestBlockFocus(block.id)
        EditorLog.focus.debug(
            "editor_focus_request_queued block_id=\(block.id, privacy: .public) source=\(source, privacy: .public)"
        )
    }

    private func focusBottomEmptyTextBlockForCurrentPage(source: String) throws {
        if let lastBlock = visibleBlocks.last,
           lastBlock.type.isTextEditable,
           lastBlock.type != .table,
           lastBlock.textPlain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            requestBlockFocus(lastBlock.id)
            EditorLog.focus.debug(
                "editor_focus_request_queued block_id=\(lastBlock.id, privacy: .public) source=\(source, privacy: .public)"
            )
            return
        }

        let block = try appendParagraphBlockToCurrentPage()
        requestBlockFocus(block.id)
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
              let pageID = CompactPageNavigationResolver.initialPageID(
                selectedPageID: selectedPageID,
                availablePageIDs: snapshot.pages.map(\.id)
              ) else {
            return
        }

        didRequestInitialCompactPageNavigation = true
        if selectedPageID == nil {
            selectPage(id: pageID, collection: .recent, recordHistory: false)
        }
        pendingCompactPageNavigationID = pageID
        EditorLog.render.debug(
            "compact_page_navigation_queued page_id=\(pageID, privacy: .public) source=\(source, privacy: .public)"
        )
    }

    nonisolated private static func runForegroundSync(syncEngine: SyncEngine) -> WorkspaceForegroundSyncResult {
        let syncStartedAt = Date()
        var subscriptionDurationMilliseconds = 0
        var uploadDurationMilliseconds = 0
        var fetchDurationMilliseconds = 0
        syncEngine.recordRuntimeDiagnostic(
            eventName: "foreground_sync_operation_started",
            payloadJSON: "{}"
        )
        do {
            do {
                let subscriptionStartedAt = Date()
                syncEngine.recordRuntimeDiagnostic(
                    eventName: "foreground_sync_subscription_started",
                    payloadJSON: "{}"
                )
                try syncEngine.ensureRemoteChangeSubscription()
                subscriptionDurationMilliseconds = millisecondsElapsed(since: subscriptionStartedAt)
                syncEngine.recordRuntimeDiagnostic(
                    eventName: "foreground_sync_subscription_completed",
                    payloadJSON: "{\"duration_ms\":\(subscriptionDurationMilliseconds)}"
                )
            } catch {
                subscriptionDurationMilliseconds = millisecondsElapsed(since: syncStartedAt)
                syncEngine.recordRuntimeDiagnostic(
                    eventName: "foreground_sync_subscription_failed",
                    payloadJSON: Self.diagnosticPayloadJSON([
                        "error": CloudKitErrorDiagnostic.describe(error),
                        "duration_ms": "\(subscriptionDurationMilliseconds)"
                    ])
                )
                EditorLog.sync.error(
                    "cloudkit_subscription_ensure_failed error=\(CloudKitErrorDiagnostic.describe(error), privacy: .public)"
                )
            }

            let uploadStartedAt = Date()
            syncEngine.recordRuntimeDiagnostic(
                eventName: "foreground_sync_upload_started",
                payloadJSON: "{}"
            )
            let uploadSummary = try syncEngine.uploadPendingChanges()
            uploadDurationMilliseconds = millisecondsElapsed(since: uploadStartedAt)
            syncEngine.recordRuntimeDiagnostic(
                eventName: "foreground_sync_upload_completed",
                payloadJSON: "{\"duration_ms\":\(uploadDurationMilliseconds),\"failed_count\":\(uploadSummary.failedCount),\"uploaded_count\":\(uploadSummary.uploadedCount)}"
            )
            let remainingLocalChanges = try syncEngine.pendingChangeCount()
            let onlyDeferredLocalChangesRemain = remainingLocalChanges > 0
                && uploadSummary.uploadedCount == 0
                && uploadSummary.failedCount == 0
            guard remainingLocalChanges == 0 || onlyDeferredLocalChangesRemain else {
                syncEngine.recordRuntimeDiagnostic(
                    eventName: "foreground_sync_fetch_skipped",
                    payloadJSON: "{\"pending_change_count\":\(remainingLocalChanges),\"reason\":\"local_backlog\"}"
                )
                return .success(
                    WorkspaceForegroundSyncSummary(
                        uploadSummary: uploadSummary,
                        fetchSummary: SyncFetchSummary(appliedCount: 0),
                        remainingLocalChangeCount: remainingLocalChanges
                    )
                )
            }
            if onlyDeferredLocalChangesRemain {
                syncEngine.recordRuntimeDiagnostic(
                    eventName: "foreground_sync_fetch_allowed",
                    payloadJSON: "{\"pending_change_count\":\(remainingLocalChanges),\"reason\":\"deferred_local_backlog\"}"
                )
            }

            let fetchStartedAt = Date()
            syncEngine.recordRuntimeDiagnostic(
                eventName: "foreground_sync_fetch_started",
                payloadJSON: "{}"
            )
            let fetchSummary = try syncEngine.fetchRemoteChanges()
            fetchDurationMilliseconds = millisecondsElapsed(since: fetchStartedAt)
            syncEngine.recordRuntimeDiagnostic(
                eventName: "foreground_sync_fetch_completed",
                payloadJSON: "{\"duration_ms\":\(fetchDurationMilliseconds),\"fetched_count\":\(fetchSummary.appliedCount),\"has_more_changes\":\(fetchSummary.hasMoreChanges)}"
            )
            EditorLog.sync.debug(
                "foreground_sync_completed subscription_ms=\(subscriptionDurationMilliseconds, privacy: .public) upload_ms=\(uploadDurationMilliseconds, privacy: .public) fetch_ms=\(fetchDurationMilliseconds, privacy: .public) total_ms=\(millisecondsElapsed(since: syncStartedAt), privacy: .public) uploaded=\(uploadSummary.uploadedCount, privacy: .public) failed_uploads=\(uploadSummary.failedCount, privacy: .public) fetched=\(fetchSummary.appliedCount, privacy: .public)"
            )
            return .success(
                WorkspaceForegroundSyncSummary(
                    uploadSummary: uploadSummary,
                    fetchSummary: fetchSummary,
                    remainingLocalChangeCount: remainingLocalChanges
                )
            )
        } catch {
            let errorDescription = CloudKitErrorDiagnostic.describe(error)
            syncEngine.recordRuntimeDiagnostic(
                eventName: "foreground_sync_operation_failed",
                payloadJSON: Self.diagnosticPayloadJSON(["error": errorDescription])
            )
            return .failure(errorDescription)
        }
    }

    nonisolated private static func millisecondsElapsed(since startDate: Date) -> Int {
        Int(Date().timeIntervalSince(startDate) * 1_000)
    }

    nonisolated private static func diagnosticPayloadJSON(_ values: [String: String]) -> String {
        let escapedValues = values
            .map { key, value in
                "\"\(escapeJSON(key))\":\"\(escapeJSON(value))\""
            }
            .sorted()
            .joined(separator: ",")
        return "{\(escapedValues)}"
    }

    nonisolated private static func escapeJSON(_ value: String) -> String {
        var escaped = ""
        for character in value {
            switch character {
            case "\"":
                escaped += "\\\""
            case "\\":
                escaped += "\\\\"
            case "\n":
                escaped += "\\n"
            case "\r":
                escaped += "\\r"
            case "\t":
                escaped += "\\t"
            default:
                escaped.append(character)
            }
        }
        return escaped
    }

    private func finishForegroundSync(_ result: WorkspaceForegroundSyncResult) {
        isForegroundSyncRunning = false
        let shouldRunPendingSync = shouldRunPendingForegroundSync(after: result)
        let shouldContinueBacklogDrain = shouldContinueForegroundBacklogDrain(after: result)
        let shouldContinueRemoteDrain = shouldContinueForegroundRemoteDrain(after: result)
        completeForegroundSync(result)
        let hasPendingLocalChangeRerun = isForegroundSyncRerunPending
        isForegroundSyncRerunPending = false

        guard hasPendingLocalChangeRerun || shouldContinueBacklogDrain || shouldContinueRemoteDrain else {
            return
        }

        guard shouldRunPendingSync else {
            return
        }

        scheduleForegroundSyncIfNeeded(
            reason: shouldContinueBacklogDrain ? "local_backlog" : (shouldContinueRemoteDrain ? "remote_backlog" : "pending_local_change")
        )
    }

    private func shouldRunPendingForegroundSync(after result: WorkspaceForegroundSyncResult) -> Bool {
        switch result {
        case .success(let summary):
            summary.uploadSummary.failedCount == 0
                || shouldContinueForegroundBacklogDrain(summary)
        case .failure:
            false
        }
    }

    private func shouldContinueForegroundBacklogDrain(after result: WorkspaceForegroundSyncResult) -> Bool {
        switch result {
        case .success(let summary):
            shouldContinueForegroundBacklogDrain(summary)
        case .failure:
            false
        }
    }

    private func shouldContinueForegroundBacklogDrain(_ summary: WorkspaceForegroundSyncSummary) -> Bool {
        summary.uploadSummary.uploadedCount > 0
            && summary.remainingLocalChangeCount > summary.uploadSummary.failedCount
    }

    private func shouldContinueForegroundRemoteDrain(after result: WorkspaceForegroundSyncResult) -> Bool {
        switch result {
        case .success(let summary):
            summary.uploadSummary.failedCount == 0
                && summary.remainingLocalChangeCount == 0
                && summary.fetchSummary.hasMoreChanges
        case .failure:
            false
        }
    }

    private func completeForegroundSync(_ result: WorkspaceForegroundSyncResult) {
        switch result {
        case .success(let summary):
            recordForegroundSyncDiagnostic(
                eventName: "foreground_sync_completed",
                payload: [
                    "uploaded_count": summary.uploadSummary.uploadedCount,
                    "failed_upload_count": summary.uploadSummary.failedCount,
                    "fetched_count": summary.fetchSummary.appliedCount,
                    "has_more_remote_changes": summary.fetchSummary.hasMoreChanges,
                    "remaining_local_change_count": summary.remainingLocalChangeCount
                ]
            )
            if shouldContinueForegroundBacklogDrain(summary) {
                syncStatusText = "继续同步，剩余 \(summary.remainingLocalChangeCount) 条本地变更"
                nextForegroundSyncAttemptAt = nil
            } else if summary.uploadSummary.failedCount > 0 {
                syncStatusText = "已安排同步重试"
                if shouldUsePartialFailureCooldown(for: summary) {
                    scheduleForegroundSyncPartialFailureCooldown()
                } else {
                    scheduleForegroundSyncFailureCooldown()
                }
            } else if summary.remainingLocalChangeCount > 0 {
                if summary.uploadSummary.uploadedCount > 0 {
                    syncStatusText = "继续同步，剩余 \(summary.remainingLocalChangeCount) 条本地变更"
                } else {
                    syncStatusText = "同步暂缓，稍后自动重试"
                }
                nextForegroundSyncAttemptAt = nil
            } else if summary.fetchSummary.hasMoreChanges {
                syncStatusText = "继续同步远端变更"
                nextForegroundSyncAttemptAt = nil
            } else if summary.fetchSummary.appliedCount > 0 {
                syncStatusText = "已同步 \(summary.fetchSummary.appliedCount) 条远端变更"
                nextForegroundSyncAttemptAt = nil
            } else {
                syncStatusText = "已同步 \(summary.uploadSummary.uploadedCount) 条变更"
                nextForegroundSyncAttemptAt = nil
            }

            if summary.fetchSummary.appliedCount > 0 {
                do {
                    try load()
                } catch {
                    syncStatusText = "同步失败"
                    scheduleForegroundSyncFailureCooldown()
                    EditorLog.sync.error(
                        "sync_now_failed error=\(CloudKitErrorDiagnostic.describe(error), privacy: .public)"
                    )
                }
            }
        case .failure(let errorDescription):
            recordForegroundSyncDiagnostic(
                eventName: "foreground_sync_failed",
                payload: ["error": errorDescription]
            )
            syncStatusText = "同步失败"
            scheduleForegroundSyncFailureCooldown()
            EditorLog.sync.error(
                "sync_now_failed error=\(errorDescription, privacy: .public)"
            )
        }
    }

    private func scheduleForegroundSyncFailureCooldown() {
        scheduleForegroundSyncCooldown(after: Self.foregroundSyncFailureCooldown)
    }

    private func scheduleForegroundSyncPartialFailureCooldown() {
        scheduleForegroundSyncCooldown(after: Self.foregroundSyncPartialFailureCooldown)
    }

    private func scheduleForegroundSyncCooldown(after interval: TimeInterval) {
        nextForegroundSyncAttemptAt = currentDateProvider()
            .addingTimeInterval(interval)
    }

    private func shouldUsePartialFailureCooldown(for summary: WorkspaceForegroundSyncSummary) -> Bool {
        summary.uploadSummary.uploadedCount > 0
            && summary.uploadSummary.failedCount > 0
            && summary.remainingLocalChangeCount > summary.uploadSummary.failedCount
    }

    private func recordForegroundSyncDiagnostic(eventName: String, payload: [String: Any]) {
        do {
            try repository?.recordRuntimeDiagnostic(
                eventName: eventName,
                payload: payload
            )
        } catch {
            EditorLog.sync.error(
                "foreground_sync_diagnostic_record_failed event_name=\(eventName, privacy: .public) error=\(String(describing: error), privacy: .public)"
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
            searchRefreshTask?.cancel()
            searchRefreshTask = nil
            isSearchRefreshPending = false
            searchResults = []
            return
        }

        let query = searchQuery
        guard searchDebounceNanoseconds > 0 else {
            refreshSearchResultsImmediately(query: query, searchRepository: searchRepository)
            return
        }

        searchRefreshTask?.cancel()
        isSearchRefreshPending = true
        searchRefreshTask = Task { [weak self, searchRepository, query, searchDebounceNanoseconds] in
            do {
                try await Task.sleep(nanoseconds: searchDebounceNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    try searchRepository.search(query)
                }
            }.value

            await MainActor.run { [weak self] in
                guard let self,
                      self.searchQuery == query,
                      !Task.isCancelled else {
                    return
                }
                self.isSearchRefreshPending = false
                switch result {
                case .success(let searchResults):
                    self.searchResults = searchResults
                case .failure(let error):
                    self.searchResults = []
                    EditorLog.render.error(
                        "search_failed query=\(self.searchQuery, privacy: .public) error=\(String(describing: error), privacy: .public)"
                    )
                }
            }
        }
    }

    private func refreshSearchResultsImmediately(query: String, searchRepository: SearchRepository) {
        do {
            searchResults = try searchRepository.search(query)
        } catch {
            searchResults = []
            EditorLog.render.error(
                "search_failed query=\(self.searchQuery, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    private func enterSearchModeIfNeeded() {
        if selectedCollection != .search {
            searchRestorationCollection = selectedCollection
        } else if searchRestorationCollection == nil {
            searchRestorationCollection = .allDocuments
        }
        selectedCollection = .search
    }

    private func restoreCollectionAfterSearchIfNeeded() {
        guard selectedCollection == .search else {
            searchRestorationCollection = nil
            return
        }
        let restoredCollection = searchRestorationCollection ?? .allDocuments
        searchRestorationCollection = nil
        selectedCollection = restoredCollection
        if let selectedPageID,
           !canRestoreSelection(pageID: selectedPageID, in: restoredCollection) {
            self.selectedPageID = visibleDocumentPages.first?.id
        }
        refreshBacklinksForSelectedPage()
        refreshExternalLinksForSelectedPage()
        refreshConflictsForSelectedPage()
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
            if automaticallyResolveConflicts {
                let resolved = try conflictRepository.resolveAutomatically(pageID: selectedPageID)
                selectedPageConflicts = []
                guard !resolved.isEmpty else {
                    return
                }
                try reloadSnapshotAfterAutomaticConflictMerge()
                EditorLog.sync.debug(
                    "sync_conflicts_auto_resolved page_id=\(selectedPageID, privacy: .public) count=\(resolved.count, privacy: .public)"
                )
                return
            }
            selectedPageConflicts = try conflictRepository.conflicts(pageID: selectedPageID)
        } catch {
            selectedPageConflicts = []
            EditorLog.sync.error(
                "conflicts_failed page_id=\(selectedPageID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    private func reloadSnapshotAfterAutomaticConflictMerge() throws {
        guard let repository else {
            return
        }

        let previousSelectedCollection = selectedCollection
        let previousSelectedPageID = selectedPageID
        let loadedSnapshot = try repository.loadWorkspaceSnapshot()
        apply(snapshot: loadedSnapshot)
        restoreSelectionAfterReload(
            collection: previousSelectedCollection,
            pageID: previousSelectedPageID
        )
        refreshSearchResults()
        refreshBacklinksForSelectedPage()
        refreshExternalLinksForSelectedPage()
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
        recordPageArchiveUndoSnapshot(
            pageIDs: [pageID],
            previousNotebookID: previousNotebookID,
            previousPageID: previousPageID
        )
    }

    private func recordPageArchiveUndoSnapshot(
        pageIDs: [String],
        previousNotebookID: String?,
        previousPageID: String?
    ) {
        let pageIDs = orderedUniquePageIDs(pageIDs)
        guard !pageIDs.isEmpty else {
            return
        }
        pageArchiveUndoStack.append(
            PageArchiveUndoSnapshot(
                pageIDs: pageIDs,
                previousNotebookID: previousNotebookID,
                previousPageID: previousPageID,
                createdAt: currentDateProvider()
            )
        )
        refreshPageArchiveUndoAvailability()
    }

    private func removePageArchiveUndoSnapshots(for pageID: String) {
        pageArchiveUndoStack.removeAll { $0.pageIDs.contains(pageID) }
        refreshPageArchiveUndoAvailability()
    }

    private func refreshPageArchiveUndoAvailability() {
        let now = currentDateProvider()
        pageArchiveUndoStack.removeAll { snapshot in
            now.timeIntervalSince(snapshot.createdAt) >= Self.pageArchiveUndoVisibilityDuration
        }
        canUndoPageArchive = !pageArchiveUndoStack.isEmpty
        pageArchiveUndoExpirationDeadline = pageArchiveUndoStack
            .map { $0.createdAt.addingTimeInterval(Self.pageArchiveUndoVisibilityDuration) }
            .max()
        schedulePageArchiveUndoExpirationIfNeeded()
    }

    private func schedulePageArchiveUndoExpirationIfNeeded() {
        pageArchiveUndoExpirationTask?.cancel()
        guard let pageArchiveUndoExpirationDeadline else {
            pageArchiveUndoExpirationTask = nil
            return
        }

        let delay = max(0, pageArchiveUndoExpirationDeadline.timeIntervalSince(currentDateProvider()))
        let nanoseconds = UInt64(delay * 1_000_000_000)
        pageArchiveUndoExpirationTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }
            self?.expirePageArchiveUndoForUI()
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
        refreshExternalLinksForSelectedPage()
        refreshConflictsForSelectedPage()
    }

    private func findOrCreateTagPath(
        _ rawPath: String,
        workspaceID: String,
        tagRepository: TagRepository
    ) throws -> TagSummary {
        let pathComponents = rawPath
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !pathComponents.isEmpty else {
            throw WorkspaceViewModelError.missingSelection
        }

        var existingTags = try tagRepository.tags(workspaceID: workspaceID)
        var parentTagID: String?
        var currentPath = ""
        var currentTag: TagSummary?

        for component in pathComponents {
            currentPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"
            if let existingTag = existingTags.first(where: { tag in
                tag.parentTagID == parentTagID &&
                    (tag.name.caseInsensitiveCompare(component) == .orderedSame ||
                        tag.path.caseInsensitiveCompare(currentPath) == .orderedSame)
            }) {
                currentTag = existingTag
                parentTagID = existingTag.id
            } else {
                let createdTag = try tagRepository.createTag(
                    workspaceID: workspaceID,
                    parentTagID: parentTagID,
                    name: component
                )
                existingTags = try tagRepository.tags(workspaceID: workspaceID)
                currentTag = createdTag
                parentTagID = createdTag.id
            }
        }

        guard let currentTag else {
            throw WorkspaceViewModelError.missingSelection
        }
        return currentTag
    }

    @discardableResult
    private func syncInlineHashTagsIfNeeded(pageID: String?, text: String) throws -> Bool {
        guard let pageID,
              let repository,
              let tagRepository else {
            return false
        }
        let tagNames = Self.inlineHashTagNames(in: text)
        guard !tagNames.isEmpty else {
            return false
        }
        guard let workspaceID = snapshot.pages.first(where: { $0.id == pageID })?.workspaceID ?? selectedWorkspaceID else {
            return false
        }

        var assignedTagIDs = Set(
            try tagRepository.tagAssignments()
                .filter { $0.pageID == pageID }
                .map(\.tagID)
        )
        var didChange = false
        for tagName in tagNames {
            let tag = try findOrCreateTagPath(tagName, workspaceID: workspaceID, tagRepository: tagRepository)
            didChange = assignedTagIDs.insert(tag.id).inserted || didChange
        }
        guard didChange else {
            return false
        }

        let previousSelectedPageID = selectedPageID
        let previousSelectedCollection = selectedCollection
        try tagRepository.assignTags(pageID: pageID, tagIDs: sortedTagIDs(assignedTagIDs))
        let loadedSnapshot = try repository.loadWorkspaceSnapshot()
        apply(snapshot: loadedSnapshot)
        restoreSelectionAfterReload(collection: previousSelectedCollection, pageID: previousSelectedPageID)
        EditorLog.input.debug(
            "inline_hash_tags_synced page_id=\(pageID, privacy: .public) count=\(tagNames.count, privacy: .public)"
        )
        return true
    }

    private static func inlineHashTagNames(in text: String) -> [String] {
        var names: [String] = []
        var seen: Set<String> = []
        var scanIndex = text.startIndex
        while scanIndex < text.endIndex,
              let hashIndex = text[scanIndex...].firstIndex(of: "#") {
            defer {
                scanIndex = text.index(after: hashIndex)
            }

            if hashIndex > text.startIndex {
                let previousIndex = text.index(before: hashIndex)
                guard text[previousIndex].isWhitespace else {
                    continue
                }
            }

            var endIndex = text.index(after: hashIndex)
            while endIndex < text.endIndex, !text[endIndex].isWhitespace {
                endIndex = text.index(after: endIndex)
            }
            guard endIndex < text.endIndex, text[endIndex].isWhitespace else {
                continue
            }

            let rawName = String(text[text.index(after: hashIndex)..<endIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawName.isEmpty,
                  rawName != "^",
                  !rawName.hasPrefix("#"),
                  !rawName.hasPrefix("[") else {
                continue
            }
            let key = rawName.lowercased()
            guard seen.insert(key).inserted else {
                continue
            }
            names.append(rawName)
        }
        return names
    }

    private func assignTagsForUI(
        pageID: String,
        transform: (Set<String>) -> Set<String>,
        logAction: String
    ) -> Bool {
        guard let repository,
              let tagRepository else {
            return false
        }

        let previousSelectedPageID = selectedPageID
        let previousSelectedCollection = selectedCollection
        do {
            let currentTagIDs = Set(
                try tagRepository.tagAssignments()
                    .filter { $0.pageID == pageID }
                    .map(\.tagID)
            )
            let nextTagIDs = transform(currentTagIDs)
            guard nextTagIDs != currentTagIDs else {
                return true
            }

            try tagRepository.assignTags(pageID: pageID, tagIDs: sortedTagIDs(nextTagIDs))
            let loadedSnapshot = try repository.loadWorkspaceSnapshot()
            apply(snapshot: loadedSnapshot)
            restoreSelectionAfterReload(collection: previousSelectedCollection, pageID: previousSelectedPageID)
            EditorLog.input.debug(
                "\(logAction, privacy: .public) page_id=\(pageID, privacy: .public) count=\(nextTagIDs.count, privacy: .public)"
            )
            return true
        } catch {
            restoreSelectionAfterReload(collection: previousSelectedCollection, pageID: previousSelectedPageID)
            EditorLog.input.error(
                "\(logAction, privacy: .public)_failed page_id=\(pageID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    private func sortedTagIDs(_ tagIDs: Set<String>) -> [String] {
        let knownTagIDs = snapshot.tags
            .filter { tagIDs.contains($0.id) }
            .map(\.id)
        let knownTagIDSet = Set(knownTagIDs)
        return knownTagIDs + tagIDs
            .filter { !knownTagIDSet.contains($0) }
            .sorted()
    }

    private func tagIDsIncludingDescendants(of tagID: String) -> Set<String> {
        guard snapshot.tags.contains(where: { $0.id == tagID }) else {
            return []
        }

        var result: Set<String> = [tagID]
        var pending = [tagID]
        while let current = pending.popLast() {
            let children = snapshot.tags
                .filter { $0.parentTagID == current }
                .map(\.id)
            for child in children where !result.contains(child) {
                result.insert(child)
                pending.append(child)
            }
        }
        return result
    }

    private func orderedUniquePageIDs(_ pageIDs: [String]) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for pageID in pageIDs where !seen.contains(pageID) {
            seen.insert(pageID)
            ordered.append(pageID)
        }
        return ordered
    }

    private func performPageEdit(
        pageID: String?,
        focusBlockID: String?,
        coalescingKey: PageEditCoalescingKey? = nil,
        edit: () throws -> Void
    ) throws {
        guard let pageID else {
            try edit()
            return
        }

        let beforeBlocks = pageBlocks(pageID: pageID)
        try edit()
        let afterBlocks = pageBlocks(pageID: pageID)
        guard beforeBlocks != afterBlocks else {
            return
        }

        recordPageEditUndoSnapshot(
            PageEditHistorySnapshot(
                pageID: pageID,
                beforeBlocks: beforeBlocks,
                afterBlocks: afterBlocks,
                focusBlockID: focusBlockID,
                coalescingKey: coalescingKey
            )
        )
    }

    private func pageBlocks(pageID: String) -> [BlockSnapshot] {
        snapshot.blocks.filter { $0.pageID == pageID }
    }

    private func restorePageBlocks(pageID: String, blocks: [BlockSnapshot]) throws {
        let previousSelectedCollection = selectedCollection
        let previousSelectedPageID = selectedPageID

        if let repository {
            try repository.replaceBlocks(pageID: pageID, blocks: blocks)
            let loadedSnapshot = try repository.loadWorkspaceSnapshot()
            apply(snapshot: loadedSnapshot)
            restoreSelectionAfterReload(
                collection: previousSelectedCollection,
                pageID: previousSelectedPageID
            )
        } else {
            snapshot = snapshot.replacingBlocks(pageID: pageID, blocks: blocks)
        }

        try refreshDerivedState(rebuildSearchIndex: true)
    }

    private func makeTextEditUndoCoalescingKey(
        blockID: String,
        currentBlock: BlockSnapshot?,
        nextType: BlockType,
        registerUndo: Bool
    ) -> PageEditCoalescingKey? {
        guard registerUndo,
              let currentBlock,
              currentBlock.type == nextType else {
            return nil
        }

        return .blockContent(blockID: blockID, type: currentBlock.type)
    }

    private func recordPageEditUndoSnapshot(_ undoSnapshot: PageEditHistorySnapshot) {
        if let coalescingKey = undoSnapshot.coalescingKey,
           let lastUndoSnapshot = pageEditUndoStack.last,
           lastUndoSnapshot.pageID == undoSnapshot.pageID,
           lastUndoSnapshot.coalescingKey == coalescingKey {
            if lastUndoSnapshot.beforeBlocks == undoSnapshot.afterBlocks {
                _ = pageEditUndoStack.popLast()
            } else {
                pageEditUndoStack[pageEditUndoStack.count - 1] = PageEditHistorySnapshot(
                    pageID: lastUndoSnapshot.pageID,
                    beforeBlocks: lastUndoSnapshot.beforeBlocks,
                    afterBlocks: undoSnapshot.afterBlocks,
                    focusBlockID: undoSnapshot.focusBlockID,
                    coalescingKey: coalescingKey
                )
            }
        } else {
            pageEditUndoStack.append(undoSnapshot)
            if pageEditUndoStack.count > pageEditUndoHistoryLimit {
                pageEditUndoStack.removeFirst(pageEditUndoStack.count - pageEditUndoHistoryLimit)
            }
        }

        pageEditRedoStack.removeAll()
        refreshPageEditUndoAvailability()
    }

    private func updateLastPageEditFocusBlockID(pageID: String, focusBlockID: String) {
        guard let lastUndoSnapshot = pageEditUndoStack.last,
              lastUndoSnapshot.pageID == pageID else {
            return
        }

        pageEditUndoStack[pageEditUndoStack.count - 1] = PageEditHistorySnapshot(
            pageID: lastUndoSnapshot.pageID,
            beforeBlocks: lastUndoSnapshot.beforeBlocks,
            afterBlocks: lastUndoSnapshot.afterBlocks,
            focusBlockID: focusBlockID,
            coalescingKey: lastUndoSnapshot.coalescingKey
        )
    }

    private func refreshPageEditUndoAvailability() {
        canUndoTextEdit = !pageEditUndoStack.isEmpty
        canRedoTextEdit = !pageEditRedoStack.isEmpty
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

    private func isNoOpBlockTextUpdate(
        currentBlock: BlockSnapshot?,
        nextBlock: (type: BlockType, text: String, taskItemIsCompleted: Bool?)
    ) -> Bool {
        guard let currentBlock,
              currentBlock.type == nextBlock.type,
              currentBlock.textPlain == nextBlock.text else {
            return false
        }

        guard let taskItemIsCompleted = nextBlock.taskItemIsCompleted else {
            return true
        }
        return currentBlock.taskItemIsCompleted == taskItemIsCompleted
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

enum PastedTextBlockLineResolver {
    static func lines(from text: String) -> [String] {
        text
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}

private extension BlockType {
    var stripsFormattingBeforeLineHeadMerge: Bool {
        switch self {
        case .heading1,
             .heading2,
             .heading3,
             .heading4,
             .heading5,
             .heading6,
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
             .attachmentFile,
             .drawing:
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
        case .heading4:
            return 4
        case .heading5:
            return 5
        case .heading6:
            return 6
        default:
            return nil
        }
    }
}

private struct PageEditHistorySnapshot {
    let pageID: String
    let beforeBlocks: [BlockSnapshot]
    let afterBlocks: [BlockSnapshot]
    let focusBlockID: String?
    let coalescingKey: PageEditCoalescingKey?
}

private enum PageEditCoalescingKey: Equatable {
    case blockContent(blockID: String, type: BlockType)
}

private struct PageArchiveUndoSnapshot {
    let pageIDs: [String]
    let previousNotebookID: String?
    let previousPageID: String?
    let createdAt: Date
}

enum WorkspaceViewModelError: Error, Equatable {
    case missingRepository
    case missingDiaryRepository
    case missingSelection
}
