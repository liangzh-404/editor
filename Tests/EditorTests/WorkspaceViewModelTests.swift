import Foundation
import CloudKit
import SwiftUI
import XCTest

final class WorkspaceViewModelTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    @MainActor
    func testLoadExposesRepositorySnapshotSelectionAndBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        XCTAssertEqual(viewModel.snapshot.workspaces.count, 1)
        XCTAssertEqual(viewModel.snapshot.pages.count, 1)
        XCTAssertEqual(viewModel.snapshot.blocks.count, 1)
        XCTAssertEqual(viewModel.selectedWorkspaceID, viewModel.snapshot.workspaces.first?.id)
        XCTAssertEqual(viewModel.selectedPageID, viewModel.snapshot.pages.first?.id)
        XCTAssertEqual(viewModel.selectedPage?.title, "欢迎")
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["开始用块写作。"])
    }

    @MainActor
    func testLoadHydratesOnlySelectedPageBlocksOnColdLaunch() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let secondPage = try repository.createPage(workspaceID: workspaceID, title: "Fresh")

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        XCTAssertEqual(viewModel.selectedPageID, secondPage.id)
        XCTAssertEqual(Set(viewModel.snapshot.blocks.map(\.pageID)), [secondPage.id])
        XCTAssertEqual(viewModel.visibleBlocks.map(\.pageID), [secondPage.id])
    }

    @MainActor
    func testColdLaunchOpensExistingTodayDiaryAndQueuesCompactEditorNavigation() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let diaryRepository = DiaryRepository(database: database)
        _ = try diaryRepository.openDailyPage(
            workspaceID: "workspace-local",
            date: Self.date(year: 2026, month: 5, day: 16),
            calendar: Self.gregorianCalendar
        )
        let viewModel = WorkspaceViewModel(
            repository: repository,
            diaryRepository: diaryRepository,
            currentDateProvider: { Self.date(year: 2026, month: 5, day: 16) },
            diaryCalendar: Self.gregorianCalendar
        )

        try viewModel.load()

        XCTAssertEqual(viewModel.selectedCollection, .diary)
        XCTAssertNil(viewModel.activeDiaryEntry)
        XCTAssertEqual(viewModel.selectedPage?.title, "2026年5月16日 星期六")
        XCTAssertEqual(viewModel.visibleBlocks.map(\.type), [.paragraph])
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), [""])
        XCTAssertEqual(viewModel.visibleDocumentPages.map(\.id), [viewModel.selectedPageID])
        XCTAssertEqual(viewModel.pendingCompactPageNavigationID, viewModel.selectedPageID)
        XCTAssertEqual(viewModel.pendingFocusBlockID, viewModel.visibleBlocks.first?.id)
    }

    @MainActor
    func testColdLaunchWithMissingTodayDiaryFallsBackToRecentWithoutCreatingDiaryPage() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        try insertPage(
            database: database,
            id: "page-fresh",
            workspaceID: workspaceID,
            title: "一小时内笔记",
            createdAt: Self.isoString(year: 2026, month: 5, day: 16, hour: 10, minute: 0),
            updatedAt: Self.isoString(year: 2026, month: 5, day: 16, hour: 10, minute: 0)
        )
        let viewModel = WorkspaceViewModel(
            repository: repository,
            diaryRepository: DiaryRepository(database: database),
            currentDateProvider: { Self.date(year: 2026, month: 5, day: 16, hour: 10, minute: 30) },
            diaryCalendar: Self.gregorianCalendar
        )

        try viewModel.load()

        XCTAssertEqual(viewModel.selectedCollection, .recent)
        XCTAssertEqual(viewModel.selectedPageID, "page-fresh")
        XCTAssertEqual(
            try database.queryInt("SELECT COUNT(*) FROM diary_pages WHERE diary_date = '2026-05-16'"),
            0
        )
    }

    @MainActor
    func testColdLaunchFallsBackToTodayRecentNoteWithinOneHourWhenDiaryIsUnavailable() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let now = Self.date(year: 2026, month: 5, day: 16, hour: 10, minute: 30)
        let oldPageID = try XCTUnwrap(snapshot.selectedPageID)
        try updatePageTimestamps(
            database: database,
            pageID: oldPageID,
            createdAt: Self.isoString(year: 2026, month: 5, day: 15, hour: 8, minute: 0),
            updatedAt: Self.isoString(year: 2026, month: 5, day: 15, hour: 8, minute: 0)
        )
        try insertPage(
            database: database,
            id: "page-yesterday",
            workspaceID: workspaceID,
            title: "昨天笔记",
            createdAt: Self.isoString(year: 2026, month: 5, day: 15, hour: 23, minute: 50),
            updatedAt: Self.isoString(year: 2026, month: 5, day: 15, hour: 23, minute: 50)
        )
        try insertPage(
            database: database,
            id: "page-fresh",
            workspaceID: workspaceID,
            title: "一小时内笔记",
            createdAt: Self.isoString(year: 2026, month: 5, day: 16, hour: 10, minute: 0),
            updatedAt: Self.isoString(year: 2026, month: 5, day: 16, hour: 10, minute: 0)
        )
        let viewModel = WorkspaceViewModel(
            repository: repository,
            currentDateProvider: { now },
            diaryCalendar: Self.gregorianCalendar
        )

        try viewModel.load()

        XCTAssertEqual(viewModel.selectedCollection, .recent)
        XCTAssertEqual(viewModel.selectedPageID, "page-fresh")
        XCTAssertEqual(viewModel.pendingCompactPageNavigationID, "page-fresh")
    }

    @MainActor
    func testLoadQueuesCompactInitialPageNavigationForEditableFirstScreen() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        XCTAssertEqual(viewModel.selectedCollection, .recent)
        XCTAssertEqual(viewModel.pendingCompactPageNavigationID, viewModel.selectedPageID)
        XCTAssertEqual(viewModel.consumePendingCompactPageNavigationID(), viewModel.selectedPageID)
        XCTAssertNil(viewModel.pendingCompactPageNavigationID)
        XCTAssertEqual(viewModel.pendingFocusBlockID, viewModel.visibleBlocks.first?.id)
    }

    @MainActor
    func testSnapshotInitializerQueuesCompactNavigationToFirstPageWhenSelectionIsMissing() {
        let workspaceID = "workspace-local"
        let notebookID = "notebook-local"
        let firstPageID = "recent-page"
        let snapshot = WorkspaceSnapshot(
            workspaces: [
                WorkspaceSummary(id: workspaceID, name: "本地空间")
            ],
            notebooks: [
                NotebookSummary(id: notebookID, workspaceID: workspaceID, name: "默认")
            ],
            pages: [
                PageSummary(id: firstPageID, workspaceID: workspaceID, notebookID: notebookID, title: "最近页面"),
                PageSummary(id: "older-page", workspaceID: workspaceID, notebookID: notebookID, title: "旧页面")
            ],
            blocks: [
                BlockSnapshot(
                    id: "first-block",
                    pageID: firstPageID,
                    parentBlockID: nil,
                    orderKey: "000001",
                    type: .paragraph,
                    textPlain: ""
                )
            ],
            attachments: [],
            selectedWorkspaceID: workspaceID,
            selectedNotebookID: notebookID,
            selectedPageID: nil
        )

        let viewModel = WorkspaceViewModel(snapshot: snapshot)

        XCTAssertEqual(
            CompactPageNavigationResolver.initialPageID(
                selectedPageID: nil,
                availablePageIDs: snapshot.pages.map(\.id)
            ),
            firstPageID
        )
        XCTAssertEqual(viewModel.selectedCollection, .recent)
        XCTAssertEqual(viewModel.selectedPageID, firstPageID)
        XCTAssertEqual(viewModel.pendingCompactPageNavigationID, firstPageID)
        XCTAssertEqual(viewModel.visibleBlocks.map(\.id), ["first-block"])
    }

    @MainActor
    func testCreateNewDocumentForCompactUISelectsAndQueuesNavigationToEditablePage() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        _ = viewModel.consumePendingCompactPageNavigationID()

        let newPageID = try XCTUnwrap(viewModel.createNewDocumentForCompactUI())

        XCTAssertEqual(viewModel.selectedPageID, newPageID)
        XCTAssertEqual(viewModel.selectedPage?.title, "")
        XCTAssertEqual(PageTitleDisplayPolicy.listTitle(for: viewModel.selectedPage?.title ?? ""), "未命名")
        XCTAssertEqual(viewModel.pendingCompactPageNavigationID, newPageID)
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), [""])
        XCTAssertNil(viewModel.pendingFocusBlockID)
        XCTAssertEqual(viewModel.pendingPageTitleFocusPageID, newPageID)
    }

    @MainActor
    func testHomeScreenDiaryQuickActionOpensTodayDiary() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            diaryRepository: DiaryRepository(database: database),
            currentDateProvider: { Self.date(year: 2026, month: 5, day: 16) },
            diaryCalendar: Self.gregorianCalendar
        )
        try viewModel.load()
        viewModel.selectCollection(.allDocuments)

        XCTAssertTrue(viewModel.performHomeScreenQuickAction(.openDiary))

        XCTAssertEqual(viewModel.selectedCollection, .diary)
        XCTAssertEqual(viewModel.selectedPage?.title, "2026年5月16日 星期六")
        XCTAssertEqual(viewModel.pendingCompactPageNavigationID, viewModel.selectedPageID)
    }

    @MainActor
    func testHomeScreenCreateNoteQuickActionCreatesNoteAndFocusesTitle() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        XCTAssertTrue(viewModel.performHomeScreenQuickAction(.createNote))

        let pageID = try XCTUnwrap(viewModel.selectedPageID)
        XCTAssertEqual(viewModel.selectedPage?.title, "")
        XCTAssertEqual(PageTitleDisplayPolicy.listTitle(for: viewModel.selectedPage?.title ?? ""), "未命名")
        XCTAssertEqual(viewModel.pendingCompactPageNavigationID, pageID)
        XCTAssertEqual(viewModel.pendingPageTitleFocusPageID, pageID)
    }

    @MainActor
    func testHomeScreenQuickSearchActionQueuesCompactDocumentListNavigation() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        XCTAssertTrue(viewModel.performHomeScreenQuickAction(.quickSearch))

        XCTAssertEqual(viewModel.selectedCollection, .allDocuments)
        XCTAssertEqual(viewModel.pendingCompactCollectionNavigation, .allDocuments)
        XCTAssertEqual(viewModel.consumePendingCompactCollectionNavigation(), .allDocuments)
        XCTAssertNil(viewModel.pendingCompactCollectionNavigation)
    }

    @MainActor
    func testSelectingDiaryRestoresDailyPageAndAllDocumentsExcludesIt() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let welcomePageID = try XCTUnwrap(snapshot.selectedPageID)
        let viewModel = WorkspaceViewModel(
            repository: repository,
            diaryRepository: DiaryRepository(database: database),
            currentDateProvider: { Self.date(year: 2026, month: 5, day: 16) },
            diaryCalendar: Self.gregorianCalendar
        )
        try viewModel.load()
        viewModel.selectCollection(.diary)
        let diaryPageID = try XCTUnwrap(viewModel.selectedPageID)
        let diaryBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.updateBlockText(blockID: diaryBlockID, text: "今天记录")
        viewModel.selectPage(id: welcomePageID)
        viewModel.selectCollection(.diary)

        XCTAssertEqual(viewModel.selectedCollection, .diary)
        XCTAssertEqual(viewModel.selectedPageID, diaryPageID)
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["今天记录"])
        XCTAssertEqual(viewModel.visibleDocumentPages.map(\.id), [diaryPageID])

        viewModel.selectCollection(.allDocuments)

        XCTAssertFalse(viewModel.visibleDocumentPages.contains { $0.id == diaryPageID })
        XCTAssertTrue(viewModel.visibleDocumentPages.contains { $0.id == welcomePageID })
        XCTAssertEqual(viewModel.selectedPageID, welcomePageID)
    }

    @MainActor
    func testDiaryCollectionOrdersPagesByDiaryDateDescending() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let diaryRepository = DiaryRepository(database: database)
        let olderDay = try diaryRepository.openDailyPage(
            workspaceID: workspaceID,
            date: Self.date(year: 2026, month: 5, day: 16),
            calendar: Self.gregorianCalendar
        )
        let newerDay = try diaryRepository.openDailyPage(
            workspaceID: workspaceID,
            date: Self.date(year: 2026, month: 5, day: 17),
            calendar: Self.gregorianCalendar
        )
        let olderBlockID = try XCTUnwrap(
            try repository.loadWorkspaceSnapshot()
                .blocks
                .first { $0.pageID == olderDay.id }?
                .id
        )
        try repository.updateBlockText(blockID: olderBlockID, text: "旧日记后来编辑")
        let viewModel = WorkspaceViewModel(
            repository: repository,
            diaryRepository: diaryRepository,
            currentDateProvider: { Self.date(year: 2026, month: 5, day: 17) },
            diaryCalendar: Self.gregorianCalendar
        )
        try viewModel.load()

        viewModel.selectCollection(.diary)

        XCTAssertEqual(viewModel.visibleDocumentPages.map(\.id).prefix(2), [newerDay.id, olderDay.id])
    }

    @MainActor
    func testEncryptedCollectionShowsOnlyEncryptedPagesAndKeepsAllDocumentsVisible() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let cipher = EncryptedNoteCipher(
            metadataStore: KeychainMetadataStore(service: "com.liangzhang.editor.tests.\(UUID().uuidString)")
        )
        let repository = PageRepository(database: database, encryptedNoteCipher: cipher)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let publicPageID = try XCTUnwrap(snapshot.selectedPageID)
        let encryptedPage = try repository.createPage(
            workspaceID: workspaceID,
            title: "加密计划",
            isEncrypted: true
        )
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        viewModel.selectCollection(.encrypted)

        XCTAssertEqual(viewModel.visibleDocumentPages.map(\.id), [encryptedPage.id])
        XCTAssertEqual(viewModel.selectedCollection, .encrypted)
        XCTAssertEqual(viewModel.selectedPageID, encryptedPage.id)

        viewModel.selectCollection(.allDocuments)

        XCTAssertTrue(viewModel.visibleDocumentPages.contains { $0.id == publicPageID })
        XCTAssertTrue(viewModel.visibleDocumentPages.contains { $0.id == encryptedPage.id })
    }

    @MainActor
    func testSelectingEncryptedPageForUIRequiresAuthenticationBeforeRevealingBlocks() async throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let cipher = EncryptedNoteCipher(
            metadataStore: KeychainMetadataStore(service: "com.liangzhang.editor.tests.\(UUID().uuidString)")
        )
        let repository = PageRepository(database: database, encryptedNoteCipher: cipher)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let publicPageID = try XCTUnwrap(snapshot.selectedPageID)
        let encryptedPage = try repository.createPage(
            workspaceID: workspaceID,
            title: "加密计划",
            isEncrypted: true
        )
        let snapshotAfterCreate = try repository.loadWorkspaceSnapshot()
        let encryptedBlockID = try XCTUnwrap(
            snapshotAfterCreate.blocks.first { $0.pageID == encryptedPage.id }?.id
        )
        try repository.updateBlockText(blockID: encryptedBlockID, text: "指纹后才显示")
        let authenticator = RecordingEncryptedPageAuthenticator(results: [false, true])
        let viewModel = WorkspaceViewModel(
            repository: repository,
            encryptedPageAuthenticator: authenticator
        )
        try viewModel.load()
        viewModel.selectPage(id: publicPageID)

        await viewModel.selectPageForUI(id: encryptedPage.id)

        XCTAssertEqual(authenticator.requestCount, 1)
        XCTAssertEqual(viewModel.selectedPageID, publicPageID)
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["开始用块写作。"])
        XCTAssertFalse(viewModel.isEncryptedPageUnlocked(encryptedPage.id))

        await viewModel.selectPageForUI(id: encryptedPage.id)

        XCTAssertEqual(authenticator.requestCount, 2)
        XCTAssertEqual(viewModel.selectedPageID, encryptedPage.id)
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["指纹后才显示"])
        XCTAssertTrue(viewModel.isEncryptedPageUnlocked(encryptedPage.id))
    }

    @MainActor
    func testUnlockedEncryptedPageAutoLocksAfterOneMinuteAway() async throws {
        var currentDate = Self.date(year: 2026, month: 5, day: 21)
        let database = try migratedDatabase()
        defer { database.close() }
        let cipher = EncryptedNoteCipher(
            metadataStore: KeychainMetadataStore(service: "com.liangzhang.editor.tests.\(UUID().uuidString)")
        )
        let repository = PageRepository(database: database, encryptedNoteCipher: cipher)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let publicPageID = try XCTUnwrap(snapshot.selectedPageID)
        let encryptedPage = try repository.createPage(
            workspaceID: workspaceID,
            title: "一分钟后重锁",
            isEncrypted: true
        )
        let authenticator = RecordingEncryptedPageAuthenticator(results: [true, true])
        let viewModel = WorkspaceViewModel(
            repository: repository,
            encryptedPageAuthenticator: authenticator,
            currentDateProvider: { currentDate }
        )
        try viewModel.load()

        await viewModel.selectPageForUI(id: encryptedPage.id)
        XCTAssertTrue(viewModel.isEncryptedPageUnlocked(encryptedPage.id))

        await viewModel.selectPageForUI(id: publicPageID)
        currentDate = currentDate.addingTimeInterval(59)
        viewModel.lockExpiredEncryptedPagesForUI()
        XCTAssertTrue(viewModel.isEncryptedPageUnlocked(encryptedPage.id))

        currentDate = currentDate.addingTimeInterval(1)
        viewModel.lockExpiredEncryptedPagesForUI()

        XCTAssertFalse(viewModel.isEncryptedPageUnlocked(encryptedPage.id))
        await viewModel.selectPageForUI(id: encryptedPage.id)
        XCTAssertEqual(authenticator.requestCount, 2)
    }

    @MainActor
    func testUnlockedEncryptedPageStaysUnlockedWhileOpenPastAutoLockInterval() async throws {
        var currentDate = Self.date(year: 2026, month: 5, day: 21)
        let database = try migratedDatabase()
        defer { database.close() }
        let cipher = EncryptedNoteCipher(
            metadataStore: KeychainMetadataStore(service: "com.liangzhang.editor.tests.\(UUID().uuidString)")
        )
        let repository = PageRepository(database: database, encryptedNoteCipher: cipher)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let encryptedPage = try repository.createPage(
            workspaceID: workspaceID,
            title: "打开时不重锁",
            isEncrypted: true
        )
        let authenticator = RecordingEncryptedPageAuthenticator(results: [true])
        let viewModel = WorkspaceViewModel(
            repository: repository,
            encryptedPageAuthenticator: authenticator,
            currentDateProvider: { currentDate }
        )
        try viewModel.load()

        await viewModel.selectPageForUI(id: encryptedPage.id)
        currentDate = currentDate.addingTimeInterval(120)
        viewModel.lockExpiredEncryptedPagesForUI()

        XCTAssertTrue(viewModel.isEncryptedPageUnlocked(encryptedPage.id))
        XCTAssertEqual(authenticator.requestCount, 1)
    }

    @MainActor
    func testOpenParentPageForCurrentPageUsesRecordedPageParentLink() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let parentPageID = try XCTUnwrap(snapshot.selectedPageID)
        let sourceBlockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        try viewModel.updateBlockText(blockID: sourceBlockID, text: "子页面标题")

        let childPage = try viewModel.convertTextBlockToPage(blockID: sourceBlockID)

        XCTAssertEqual(viewModel.selectedPageID, childPage.id)
        XCTAssertEqual(viewModel.selectedPageParentLink?.parentPageID, parentPageID)

        let didOpenParent = try viewModel.openParentPageForCurrentPage()

        XCTAssertTrue(didOpenParent)
        XCTAssertEqual(viewModel.selectedPageID, parentPageID)
        XCTAssertEqual(viewModel.pendingFocusBlockID, sourceBlockID)
    }

    @MainActor
    func testNavigateBackFromChildPageFocusesRecordedSourceBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let parentPageID = try XCTUnwrap(snapshot.selectedPageID)
        let sourceBlockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        try viewModel.updateBlockText(blockID: sourceBlockID, text: "子页面标题")

        let childPage = try viewModel.convertTextBlockToPage(blockID: sourceBlockID)
        XCTAssertEqual(viewModel.selectedPageID, childPage.id)

        XCTAssertTrue(try viewModel.navigateBack())

        XCTAssertEqual(viewModel.selectedPageID, parentPageID)
        XCTAssertEqual(viewModel.pendingFocusBlockID, sourceBlockID)
    }

    @MainActor
    func testOpenTodayForUISelectsDailyPageAndNavigateBackReturnsToPreviousPage() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let welcomePageID = try XCTUnwrap(snapshot.selectedPageID)
        let viewModel = WorkspaceViewModel(
            repository: repository,
            diaryRepository: DiaryRepository(database: database),
            currentDateProvider: { Self.date(year: 2026, month: 5, day: 16) },
            diaryCalendar: Self.gregorianCalendar
        )
        try viewModel.load()
        viewModel.selectCollection(.recent)
        viewModel.selectPage(id: welcomePageID)

        XCTAssertTrue(viewModel.openTodayForUI())
        XCTAssertEqual(viewModel.selectedCollection, .diary)
        XCTAssertEqual(viewModel.selectedPage?.title, "2026年5月16日 星期六")
        XCTAssertTrue(viewModel.canNavigateBack)

        XCTAssertTrue(viewModel.navigateBackForUI())
        XCTAssertEqual(viewModel.selectedPageID, welcomePageID)
        XCTAssertEqual(viewModel.selectedCollection, .recent)
        XCTAssertTrue(viewModel.canNavigateForward)

        XCTAssertTrue(viewModel.navigateForwardForUI())
        XCTAssertEqual(viewModel.selectedPage?.title, "2026年5月16日 星期六")
    }

    @MainActor
    func testOpenTodayForUIAppendsAndFocusesBottomEmptyLineWhenDailyPageEndsWithText() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let welcomePageID = try XCTUnwrap(snapshot.selectedPageID)
        let viewModel = WorkspaceViewModel(
            repository: repository,
            diaryRepository: DiaryRepository(database: database),
            currentDateProvider: { Self.date(year: 2026, month: 5, day: 16) },
            diaryCalendar: Self.gregorianCalendar
        )
        try viewModel.load()
        viewModel.selectCollection(.diary)
        let diaryBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        try viewModel.updateBlockText(blockID: diaryBlockID, text: "上午记录")
        viewModel.selectPage(id: welcomePageID)

        XCTAssertTrue(viewModel.openTodayForUI())

        XCTAssertEqual(viewModel.selectedCollection, .diary)
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["上午记录", ""])
        XCTAssertEqual(viewModel.pendingFocusBlockID, viewModel.visibleBlocks.last?.id)
    }

    @MainActor
    func testOpenTodayForUIFocusesExistingBottomEmptyLineWithoutAppendingAnotherOne() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let welcomePageID = try XCTUnwrap(snapshot.selectedPageID)
        let viewModel = WorkspaceViewModel(
            repository: repository,
            diaryRepository: DiaryRepository(database: database),
            currentDateProvider: { Self.date(year: 2026, month: 5, day: 16) },
            diaryCalendar: Self.gregorianCalendar
        )
        try viewModel.load()
        viewModel.selectCollection(.diary)
        let diaryBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        try viewModel.updateBlockText(blockID: diaryBlockID, text: "上午记录")
        let existingEmptyBlock = try viewModel.appendParagraphBlockToCurrentPage()
        viewModel.selectPage(id: welcomePageID)

        XCTAssertTrue(viewModel.openTodayForUI())

        XCTAssertEqual(viewModel.selectedCollection, .diary)
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["上午记录", ""])
        XCTAssertEqual(viewModel.visibleBlocks.last?.id, existingEmptyBlock.id)
        XCTAssertEqual(viewModel.pendingFocusBlockID, existingEmptyBlock.id)
    }

    @MainActor
    func testOpenTodayForUIRefreshesFocusRequestWhenAlreadyOnBottomEmptyLine() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            diaryRepository: DiaryRepository(database: database),
            currentDateProvider: { Self.date(year: 2026, month: 5, day: 16) },
            diaryCalendar: Self.gregorianCalendar
        )
        try viewModel.load()
        viewModel.selectCollection(.diary)
        let diaryBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        try viewModel.updateBlockText(blockID: diaryBlockID, text: "上午记录")
        let existingEmptyBlock = try viewModel.appendParagraphBlockToCurrentPage()

        XCTAssertTrue(viewModel.openTodayForUI())
        let firstRequestID = try XCTUnwrap(viewModel.pendingFocusRequestID)

        XCTAssertTrue(viewModel.openTodayForUI())

        XCTAssertEqual(viewModel.pendingFocusBlockID, existingEmptyBlock.id)
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["上午记录", ""])
        XCTAssertNotEqual(viewModel.pendingFocusRequestID, firstRequestID)
    }

    @MainActor
    func testNewDocumentForUICreatesUntitledPageAndCanNavigateBack() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let welcomePageID = try XCTUnwrap(snapshot.selectedPageID)
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        viewModel.selectPage(id: welcomePageID)

        XCTAssertTrue(viewModel.createNewDocumentForUI())
        XCTAssertEqual(viewModel.selectedPage?.title, "未命名")
        XCTAssertTrue(viewModel.canNavigateBack)

        XCTAssertTrue(viewModel.navigateBackForUI())
        XCTAssertEqual(viewModel.selectedPageID, welcomePageID)
    }

    @MainActor
    func testCompactNewDocumentQueuesPageNavigationAndTitleFocus() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        let pageID = try XCTUnwrap(viewModel.createNewDocumentForCompactUI())

        XCTAssertEqual(viewModel.selectedPageID, pageID)
        XCTAssertEqual(viewModel.selectedPage?.title, "")
        XCTAssertEqual(PageTitleDisplayPolicy.listTitle(for: viewModel.selectedPage?.title ?? ""), "未命名")
        XCTAssertEqual(viewModel.pendingCompactPageNavigationID, pageID)
        XCTAssertEqual(viewModel.pendingPageTitleFocusPageID, pageID)
        XCTAssertNil(viewModel.pendingFocusBlockID)
        XCTAssertEqual(viewModel.consumePendingPageTitleFocusPageID(), pageID)
        XCTAssertNil(viewModel.pendingPageTitleFocusPageID)
    }

    @MainActor
    func testCompactDailyCreateQueuesNavigationAndBottomEmptyLineFocus() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            diaryRepository: DiaryRepository(database: database),
            currentDateProvider: { Self.date(year: 2026, month: 5, day: 16) },
            diaryCalendar: Self.gregorianCalendar
        )
        try viewModel.load()
        viewModel.selectCollection(.diary)
        let firstDiaryBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        try viewModel.updateBlockText(blockID: firstDiaryBlockID, text: "上午记录")
        viewModel.selectCollection(.allDocuments)

        let pageID = try XCTUnwrap(viewModel.createDailyDiaryForCompactUI())

        XCTAssertEqual(viewModel.selectedPageID, pageID)
        XCTAssertEqual(viewModel.selectedCollection, .diary)
        XCTAssertEqual(viewModel.selectedPage?.title, "2026年5月16日 星期六")
        XCTAssertEqual(viewModel.pendingCompactPageNavigationID, pageID)
        XCTAssertNil(viewModel.pendingPageTitleFocusPageID)
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["上午记录", ""])
        XCTAssertEqual(viewModel.pendingFocusBlockID, viewModel.visibleBlocks.last?.id)
    }

    @MainActor
    func testAssignTagToSelectedPageFiltersAllDocumentsByTag() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let tagRepository = TagRepository(database: database)
        let tag = try tagRepository.createTag(workspaceID: workspaceID, name: "Writing")
        let viewModel = WorkspaceViewModel(repository: repository, tagRepository: tagRepository)
        try viewModel.load()
        viewModel.selectPage(id: pageID)

        try viewModel.assignTagsToSelectedPage([tag.id])
        viewModel.selectCollection(.tag(tag.id))

        XCTAssertEqual(viewModel.visibleDocumentPages.map(\.id), [pageID])
    }

    @MainActor
    func testSelectingParentTagIncludesPagesAssignedToChildTags() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let tagRepository = TagRepository(database: database)
        let parent = try tagRepository.createTag(workspaceID: workspaceID, name: "Work")
        let child = try tagRepository.createTag(workspaceID: workspaceID, parentTagID: parent.id, name: "PL")
        try tagRepository.assignTags(pageID: pageID, tagIDs: [child.id])
        let viewModel = WorkspaceViewModel(repository: repository, tagRepository: tagRepository)
        try viewModel.load()

        viewModel.selectCollection(.tag(parent.id))

        XCTAssertEqual(viewModel.visibleDocumentPages.map(\.id), [pageID])
    }

    @MainActor
    func testAddAndRemoveTagsOnSelectedPagePreservesOtherTags() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let tagRepository = TagRepository(database: database)
        let keep = try tagRepository.createTag(workspaceID: workspaceID, name: "Keep")
        let remove = try tagRepository.createTag(workspaceID: workspaceID, name: "Remove")
        let viewModel = WorkspaceViewModel(repository: repository, tagRepository: tagRepository)
        try viewModel.load()
        viewModel.selectPage(id: pageID)

        XCTAssertTrue(viewModel.addTagToSelectedPageForUI(tagID: keep.id))
        XCTAssertTrue(viewModel.addTagToSelectedPageForUI(tagID: remove.id))
        XCTAssertEqual(Set(viewModel.selectedPageTagIDs), [keep.id, remove.id])

        XCTAssertTrue(viewModel.removeTagFromSelectedPageForUI(tagID: remove.id))

        XCTAssertEqual(viewModel.selectedPageTagIDs, [keep.id])
        XCTAssertEqual(viewModel.selectedPageTagNames, ["Keep"])
    }

    @MainActor
    func testCreateAndAssignTagToSelectedPageTrimsNameAndReusesExistingTag() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let tagRepository = TagRepository(database: database)
        let existing = try tagRepository.createTag(workspaceID: workspaceID, name: "Writing")
        let viewModel = WorkspaceViewModel(repository: repository, tagRepository: tagRepository)
        try viewModel.load()
        viewModel.selectPage(id: pageID)

        XCTAssertTrue(viewModel.createAndAssignTagToSelectedPageForUI(name: " writing "))

        XCTAssertEqual(viewModel.selectedPageTagIDs, [existing.id])
        XCTAssertEqual(viewModel.snapshot.tags.map(\.name), ["Writing"])
    }

    @MainActor
    func testCreateAndAssignTagToSelectedPageCreatesSlashDelimitedTagPath() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let tagRepository = TagRepository(database: database)
        let viewModel = WorkspaceViewModel(repository: repository, tagRepository: tagRepository)
        try viewModel.load()
        viewModel.selectPage(id: pageID)

        XCTAssertTrue(viewModel.createAndAssignTagToSelectedPageForUI(name: " Work / PL "))

        XCTAssertEqual(viewModel.snapshot.tags.map(\.path), ["Work", "Work/PL"])
        XCTAssertEqual(viewModel.selectedPageTagNames, ["Work/PL"])
        XCTAssertEqual(viewModel.selectedPageTagIDs, [try XCTUnwrap(viewModel.snapshot.tags.last?.id)])
    }

    @MainActor
    func testDeleteTagForUIRemovesNestedAssignmentsAndLeavesCurrentPageVisible() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let tagRepository = TagRepository(database: database)
        let parent = try tagRepository.createTag(workspaceID: workspaceID, name: "Work")
        let child = try tagRepository.createTag(workspaceID: workspaceID, parentTagID: parent.id, name: "PL")
        try tagRepository.assignTags(pageID: pageID, tagIDs: [child.id])
        let viewModel = WorkspaceViewModel(repository: repository, tagRepository: tagRepository)
        try viewModel.load()
        viewModel.selectCollection(.tag(parent.id))

        XCTAssertTrue(viewModel.deleteTagForUI(id: parent.id))

        XCTAssertEqual(viewModel.snapshot.tags, [])
        XCTAssertEqual(viewModel.snapshot.pageTags, [])
        XCTAssertEqual(viewModel.selectedCollection, .allDocuments)
        XCTAssertEqual(viewModel.selectedPageID, pageID)
    }

    @MainActor
    func testAssignTagToPagesForUIDragAddsTagToEveryDroppedPage() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let firstPageID = try XCTUnwrap(snapshot.selectedPageID)
        let secondPage = try repository.createPage(workspaceID: workspaceID, title: "Second")
        let tagRepository = TagRepository(database: database)
        let tag = try tagRepository.createTag(workspaceID: workspaceID, name: "Batch")
        let viewModel = WorkspaceViewModel(repository: repository, tagRepository: tagRepository)
        try viewModel.load()

        XCTAssertTrue(viewModel.assignTagToPagesForUI(pageIDs: [secondPage.id, firstPageID], tagID: tag.id))

        let assignments = Set(viewModel.snapshot.pageTags.filter { $0.tagID == tag.id }.map(\.pageID))
        XCTAssertEqual(assignments, [firstPageID, secondPage.id])
    }

    @MainActor
    func testArchivePagesForUIDragArchivesEveryDroppedPage() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let firstPageID = try XCTUnwrap(snapshot.selectedPageID)
        let secondPage = try repository.createPage(workspaceID: workspaceID, title: "Second")
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        XCTAssertTrue(viewModel.archivePagesForUI(pageIDs: [firstPageID, secondPage.id]))

        XCTAssertEqual(Set(viewModel.snapshot.archivedPages.map(\.id)), [firstPageID, secondPage.id])
        XCTAssertTrue(viewModel.snapshot.pages.isEmpty)
    }

    @MainActor
    func testArchivePagesForUIRecordsSingleBatchUndoRestoringEveryArchivedPage() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let firstPageID = try XCTUnwrap(snapshot.selectedPageID)
        let secondPage = try repository.createPage(workspaceID: workspaceID, title: "Second")
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        XCTAssertTrue(viewModel.archivePagesForUI(pageIDs: [firstPageID, secondPage.id]))
        XCTAssertTrue(viewModel.canUndoPageArchive)

        try viewModel.undoLastPageArchive()

        XCTAssertEqual(viewModel.snapshot.archivedPages, [])
        XCTAssertEqual(Set(viewModel.snapshot.pages.map(\.id)), [firstPageID, secondPage.id])
        XCTAssertFalse(viewModel.canUndoPageArchive)
    }

    @MainActor
    func testPageArchiveUndoExpiresAfterVisibilityDuration() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        var now = Self.date(year: 2026, month: 5, day: 22)
        let viewModel = WorkspaceViewModel(
            repository: repository,
            currentDateProvider: { now }
        )
        try viewModel.load()
        let scratchPage = try viewModel.createPageInSelectedWorkspace(title: "Scratch")

        viewModel.archivePageForUI(id: scratchPage.id)
        XCTAssertTrue(viewModel.canUndoPageArchive)
        XCTAssertEqual(
            viewModel.pageArchiveUndoExpirationDeadline,
            now.addingTimeInterval(WorkspaceViewModel.pageArchiveUndoVisibilityDuration)
        )

        now = now.addingTimeInterval(WorkspaceViewModel.pageArchiveUndoVisibilityDuration + 0.1)
        viewModel.expirePageArchiveUndoForUI()

        XCTAssertFalse(viewModel.canUndoPageArchive)
        XCTAssertNil(viewModel.pageArchiveUndoExpirationDeadline)
        try viewModel.undoLastPageArchive()
        XCTAssertEqual(viewModel.snapshot.archivedPages.map(\.title), ["Scratch"])
    }

    @MainActor
    func testLoadRequestsFocusForInitialEditableBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let initialBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        XCTAssertEqual(viewModel.pendingFocusBlockID, initialBlockID)
    }

    @MainActor
    func testFocusEditorCanvasRequestsExistingEditableBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let initialBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        XCTAssertEqual(viewModel.consumePendingFocusBlockID(), initialBlockID)

        let focusedBlockID = try viewModel.focusEditorCanvas()

        XCTAssertEqual(focusedBlockID, initialBlockID)
        XCTAssertEqual(viewModel.pendingFocusBlockID, initialBlockID)
    }

    @MainActor
    func testFocusEditorCanvasCreatesParagraphWhenPageHasNoEditableBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let initialBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        try viewModel.deleteBlock(blockID: initialBlockID)
        XCTAssertEqual(viewModel.visibleBlocks, [])

        let focusedBlockID = try viewModel.focusEditorCanvas()

        XCTAssertEqual(viewModel.visibleBlocks.count, 1)
        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .paragraph)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "")
        XCTAssertEqual(viewModel.pendingFocusBlockID, focusedBlockID)
    }

    @MainActor
    func testFocusEditorCanvasForUICreatesParagraphWhenPageHasNoEditableBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let initialBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        try viewModel.deleteBlock(blockID: initialBlockID)
        XCTAssertEqual(viewModel.visibleBlocks, [])

        let focusedBlockID = viewModel.focusEditorCanvasForUI()

        XCTAssertEqual(viewModel.visibleBlocks.count, 1)
        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .paragraph)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "")
        XCTAssertEqual(viewModel.pendingFocusBlockID, focusedBlockID)
    }

    @MainActor
    func testFocusEditorCanvasCreatesParagraphAfterTrailingNonEditableBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let targetPage = try repository.createPage(workspaceID: workspaceID, title: "Specs")

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        viewModel.selectPage(id: sourcePageID)
        _ = try viewModel.appendPageReferenceToCurrentPage(targetPageID: targetPage.id)
        XCTAssertEqual(viewModel.visibleBlocks.last?.type, .pageReference)

        let focusedBlockID = try viewModel.focusEditorCanvas()

        let focusedBlock = try XCTUnwrap(viewModel.visibleBlocks.last)
        XCTAssertEqual(focusedBlock.id, focusedBlockID)
        XCTAssertEqual(focusedBlock.type, .paragraph)
        XCTAssertEqual(focusedBlock.textPlain, "")
        XCTAssertEqual(viewModel.pendingFocusBlockID, focusedBlockID)
    }

    @MainActor
    func testUpdateBlockTextRefreshesVisibleBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.updateBlockText(blockID: blockID, text: "Editable now")

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Editable now"])
    }

    @MainActor
    func testMarkdownShortcutWithTrailingTextUpdatesBlockAndKeepsFocus() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.updateBlockText(blockID: blockID, text: "- 已有内容")

        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .unorderedListItem)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "已有内容")
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)

        try viewModel.updateBlockText(blockID: blockID, text: "1. 第二项")

        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .orderedListItem)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "第二项")
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
    }

    @MainActor
    func testUndoLastTextEditRestoresPreviousBlockTextAndKeepsFocus() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        XCTAssertFalse(viewModel.canUndoTextEdit)

        try viewModel.updateBlockText(blockID: blockID, text: "First edit")

        XCTAssertTrue(viewModel.canUndoTextEdit)

        try viewModel.undoLastTextEdit()

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "开始用块写作。")
        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .paragraph)
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
        XCTAssertFalse(viewModel.canUndoTextEdit)
        XCTAssertTrue(
            try SyncRepository(database: database).pendingChanges().contains(
                SyncChange(entityType: "block", entityID: blockID, changeType: "update")
            )
        )
    }

    @MainActor
    func testUndoLastTextEditCoalescesSequentialPlainTextEditsForSameBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        try viewModel.updateBlockText(blockID: blockID, text: "First edit")
        try viewModel.updateBlockText(blockID: blockID, text: "Second edit")

        try viewModel.undoLastTextEdit()

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "开始用块写作。")
        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .paragraph)
        XCTAssertFalse(viewModel.canUndoTextEdit)
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
    }

    @MainActor
    func testRedoLastTextEditRestoresUndoneTextEditAndClearsOnNewEdit() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        XCTAssertFalse(viewModel.canRedoTextEdit)

        try viewModel.updateBlockText(blockID: blockID, text: "First edit")
        try viewModel.undoLastTextEdit()

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "开始用块写作。")
        XCTAssertTrue(viewModel.canRedoTextEdit)

        try viewModel.redoLastTextEdit()

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "First edit")
        XCTAssertFalse(viewModel.canRedoTextEdit)

        try viewModel.undoLastTextEdit()
        try viewModel.updateBlockText(blockID: blockID, text: "Second edit")

        XCTAssertFalse(viewModel.canRedoTextEdit)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Second edit")
    }

    @MainActor
    func testUndoRedoRestoresSplitBlockShape() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        try viewModel.updateBlockText(blockID: blockID, text: "AlphaBeta")
        let splitSelection = EditorTextSelection(
            blockID: blockID,
            location: ("Alpha" as NSString).length,
            length: 0
        )
        let insertedSelection = try XCTUnwrap(
            try viewModel.splitTextBlockAtSelection(blockID: blockID, selection: splitSelection)
        )

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Alpha", "Beta"])
        XCTAssertEqual(viewModel.pendingFocusBlockID, insertedSelection.blockID)

        try viewModel.undoLastTextEdit()

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["AlphaBeta"])
        XCTAssertEqual(viewModel.visibleBlocks.first?.id, blockID)
        XCTAssertEqual(viewModel.pendingFocusBlockID, insertedSelection.blockID)
        XCTAssertTrue(viewModel.canRedoTextEdit)

        try viewModel.redoLastTextEdit()

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Alpha", "Beta"])
        XCTAssertEqual(viewModel.visibleBlocks.last?.id, insertedSelection.blockID)
    }

    @MainActor
    func testReplaceTextAtSelectionUpdatesTargetBlockAndReturnsNextCaret() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        try viewModel.updateBlockText(blockID: blockID, text: "Alpha")

        let nextSelection = try XCTUnwrap(
            try viewModel.replaceTextAtSelection(
                selection: EditorTextSelection(
                    blockID: blockID,
                    location: ("Alpha" as NSString).length,
                    length: 0
                ),
                replacementText: "Beta"
            )
        )

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "AlphaBeta")
        XCTAssertEqual(nextSelection, EditorTextSelection(blockID: blockID, location: ("AlphaBeta" as NSString).length, length: 0))
    }

    @MainActor
    func testPasteMultilineTextAtSelectionCreatesOneBlockPerLine() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        try viewModel.updateBlockText(blockID: blockID, text: "Prefix Tail")

        let nextSelection = try XCTUnwrap(
            try viewModel.pasteTextAtSelection(
                selection: EditorTextSelection(
                    blockID: blockID,
                    location: ("Prefix " as NSString).length,
                    length: 0
                ),
                pasteText: "One\nTwo\nThree"
            )
        )

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Prefix One", "Two", "ThreeTail"])
        XCTAssertEqual(nextSelection.blockID, viewModel.visibleBlocks[2].id)
        XCTAssertEqual(nextSelection.location, ("Three" as NSString).length)
        XCTAssertEqual(viewModel.pendingFocusBlockID, viewModel.visibleBlocks[2].id)
    }

    @MainActor
    func testPageEditUndoHistoryKeepsMostRecentOneHundredOperations() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        for index in 0..<101 {
            try viewModel.changeBlockType(blockID: blockID, type: index.isMultiple(of: 2) ? .heading1 : .heading2)
        }

        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .heading1)
        XCTAssertTrue(viewModel.canUndoTextEdit)

        for _ in 0..<100 {
            try viewModel.undoLastTextEdit()
        }

        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .heading1)
        XCTAssertFalse(viewModel.canUndoTextEdit)
        XCTAssertTrue(viewModel.canRedoTextEdit)
    }

    @MainActor
    func testUpdateSelectedPageTitleRefreshesSnapshotAndSearchResults() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(
            repository: repository,
            searchRepository: SearchRepository(database: database)
        )
        try viewModel.load()

        try viewModel.updateSelectedPageTitle("Editable Title")
        viewModel.updateSearchQuery("Editable")

        XCTAssertEqual(viewModel.selectedPage?.title, "Editable Title")
        XCTAssertEqual(viewModel.searchResults.first?.entityType, "page")
        XCTAssertEqual(viewModel.searchResults.first?.snippet, "Editable Title")
    }

    @MainActor
    func testSearchQueryEntersSearchModeAndClearRestoresPreviousCollection() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(
            repository: repository,
            searchRepository: SearchRepository(database: database)
        )
        try viewModel.load()
        viewModel.selectCollection(.allDocuments)

        viewModel.updateSearchQuery("welcome")

        XCTAssertTrue(viewModel.isSearchActive)
        XCTAssertEqual(viewModel.selectedCollection, .search)

        viewModel.clearSearchForUI()

        XCTAssertFalse(viewModel.isSearchActive)
        XCTAssertEqual(viewModel.searchQuery, "")
        XCTAssertEqual(viewModel.searchResults, [])
        XCTAssertEqual(viewModel.selectedCollection, .allDocuments)
    }

    @MainActor
    func testSelectingImageTextSearchResultQueuesTargetBlockAndHighlight() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        _ = viewModel.consumePendingFocusBlockID()

        viewModel.selectSearchResult(
            SearchResult(
                entityType: "attachment",
                entityID: "attachment-whiteboard",
                title: "whiteboard.png",
                snippet: "Launch budget Q4",
                destinationPageID: pageID,
                destinationBlockID: blockID,
                highlight: SearchResultHighlight(
                    blockID: blockID,
                    attachmentID: "attachment-whiteboard",
                    rects: [
                        SearchResultHighlightRect(x: 0.12, y: 0.20, width: 0.34, height: 0.08)
                    ]
                )
            )
        )

        XCTAssertEqual(viewModel.selectedPageID, pageID)
        XCTAssertEqual(viewModel.pendingCompactPageNavigationID, pageID)
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
        XCTAssertEqual(viewModel.pendingSearchHighlight?.blockID, blockID)
        XCTAssertEqual(viewModel.pendingSearchHighlight?.attachmentID, "attachment-whiteboard")
        XCTAssertEqual(viewModel.pendingSearchHighlight?.rects.first?.x, 0.12)
    }

    @MainActor
    func testSearchResultHighlightClearsAfterConfiguredDuration() async throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let viewModel = WorkspaceViewModel(
            repository: repository,
            searchHighlightDurationNanoseconds: 1_000_000
        )
        try viewModel.load()

        viewModel.selectSearchResult(
            SearchResult(
                entityType: "attachment",
                entityID: "attachment-whiteboard",
                title: "whiteboard.png",
                snippet: "Launch budget Q4",
                destinationPageID: pageID,
                destinationBlockID: blockID,
                highlight: SearchResultHighlight(
                    blockID: blockID,
                    attachmentID: "attachment-whiteboard",
                    rects: [
                        SearchResultHighlightRect(x: 0.12, y: 0.20, width: 0.34, height: 0.08)
                    ]
                )
            )
        )
        XCTAssertNotNil(viewModel.pendingSearchHighlight)

        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertNil(viewModel.pendingSearchHighlight)
    }

    @MainActor
    func testUIAttachmentImportSchedulesBackgroundImageTextRecognitionAndRefreshesSearch() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        _ = try pageRepository.bootstrapWorkspaceIfNeeded()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let textRecognitionScheduler = CapturingAttachmentTextRecognitionScheduler()
        let sourceURL = try makeSourceFile(name: "whiteboard.png", data: Self.onePixelPNGData)
        let viewModel = WorkspaceViewModel(
            repository: pageRepository,
            attachmentRepository: attachmentRepository,
            attachmentThumbnailScheduler: nil,
            attachmentTextRecognitionRepository: AttachmentTextRecognitionRepository(database: database),
            attachmentTextRecognitionScheduler: textRecognitionScheduler,
            imageTextRecognizer: StaticImageTextRecognizer(
                observations: [
                    AttachmentRecognizedTextObservation(
                        text: "kanban launch board",
                        confidence: 0.93,
                        boundingBox: AttachmentRecognizedTextBoundingBox(
                            x: 0.18,
                            y: 0.22,
                            width: 0.31,
                            height: 0.09
                        )
                    )
                ]
            ),
            searchRepository: SearchRepository(database: database)
        )
        try viewModel.load()

        let importResult = try XCTUnwrap(viewModel.importAttachmentForCurrentPage(sourceURL: sourceURL))
        viewModel.updateSearchQuery("kanban")

        XCTAssertEqual(textRecognitionScheduler.scheduledAttachmentIDs, [importResult.attachment.id])
        XCTAssertFalse(viewModel.searchResults.contains { $0.entityID == importResult.attachment.id })

        try textRecognitionScheduler.runScheduledTextRecognition(at: 0)

        let searchResult = try XCTUnwrap(viewModel.searchResults.first { $0.entityID == importResult.attachment.id })
        XCTAssertEqual(searchResult.destinationBlockID, importResult.block.id)
        XCTAssertEqual(searchResult.highlight?.rects.first?.x, 0.18)
    }

    @MainActor
    func testLoadDoesNotScheduleBulkPendingImageTextRecognition() async throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        _ = try pageRepository.bootstrapWorkspaceIfNeeded()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        _ = try attachmentRepository.importAttachment(
            sourceURL: try makeSourceFile(name: "imported-vault-image.png", data: Self.onePixelPNGData),
            workspaceID: "workspace-local",
            pageID: "page-welcome",
            thumbnailPolicy: .deferred
        )
        let textRecognitionRepository = AttachmentTextRecognitionRepository(database: database)
        XCTAssertEqual(try textRecognitionRepository.pendingImageAttachmentIDs().count, 1)

        let textRecognitionScheduler = CapturingAttachmentTextRecognitionScheduler()
        let viewModel = WorkspaceViewModel(
            repository: pageRepository,
            attachmentRepository: attachmentRepository,
            attachmentThumbnailScheduler: nil,
            attachmentTextRecognitionRepository: textRecognitionRepository,
            attachmentTextRecognitionScheduler: textRecognitionScheduler,
            imageTextRecognizer: StaticImageTextRecognizer(observations: []),
            searchRepository: SearchRepository(database: database)
        )

        try viewModel.load()
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(textRecognitionScheduler.scheduledAttachmentIDs, [])
    }

    @MainActor
    func testImportAttachmentRefreshesVisibleBlocksAndAttachmentMetadata() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        _ = try pageRepository.bootstrapWorkspaceIfNeeded()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let sourceURL = try makeSourceFile(name: "screen.png", contents: "png-data")

        let viewModel = WorkspaceViewModel(
            repository: pageRepository,
            attachmentRepository: attachmentRepository,
            attachmentThumbnailScheduler: nil
        )
        try viewModel.load()
        try viewModel.importAttachment(sourceURL: sourceURL)

        XCTAssertEqual(viewModel.visibleBlocks.last?.type, .attachmentImage)
        XCTAssertEqual(viewModel.snapshot.attachments.map(\.originalFilename), ["screen.png"])
    }

    @MainActor
    func testUIAttachmentImportDefersThumbnailAndCanGeneratePreviewLater() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        _ = try pageRepository.bootstrapWorkspaceIfNeeded()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let sourceURL = try makeSourceFile(name: "screen.png", data: Self.onePixelPNGData)

        let viewModel = WorkspaceViewModel(
            repository: pageRepository,
            attachmentRepository: attachmentRepository,
            attachmentThumbnailScheduler: nil
        )
        try viewModel.load()

        viewModel.importAttachmentForCurrentPage(sourceURL: sourceURL)
        let importedAttachmentID = try XCTUnwrap(viewModel.snapshot.attachments.first?.id)

        XCTAssertEqual(viewModel.visibleBlocks.last?.type, .attachmentImage)
        XCTAssertNil(viewModel.snapshot.attachments.first?.thumbnailPath)

        let thumbnailPath = try XCTUnwrap(
            try viewModel.generateMissingAttachmentThumbnail(attachmentID: importedAttachmentID)
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbnailPath))
        XCTAssertEqual(viewModel.snapshot.attachments.first?.thumbnailPath, thumbnailPath)
    }

    @MainActor
    func testAttachmentImageRenamePersistsDisplayNameAndShowsCaption() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        _ = try pageRepository.bootstrapWorkspaceIfNeeded()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let sourceURL = try makeSourceFile(name: "screen.png", data: Self.onePixelPNGData)

        let viewModel = WorkspaceViewModel(
            repository: pageRepository,
            attachmentRepository: attachmentRepository,
            attachmentThumbnailScheduler: nil
        )
        try viewModel.load()
        let result = try XCTUnwrap(viewModel.importAttachmentForCurrentPage(sourceURL: sourceURL))

        XCTAssertFalse(
            AttachmentImageCaptionVisibilityPolicy.isVisible(
                blockText: try XCTUnwrap(viewModel.visibleBlocks.last?.textPlain),
                originalFilename: viewModel.snapshot.attachments.first?.originalFilename
            )
        )

        try viewModel.renameAttachmentImage(blockID: result.block.id, name: "Product sketch")

        let renamedBlock = try XCTUnwrap(viewModel.visibleBlocks.last)
        XCTAssertEqual(renamedBlock.textPlain, "Product sketch")
        XCTAssertEqual(renamedBlock.attachmentID, result.attachment.id)
        XCTAssertTrue(
            AttachmentImageCaptionVisibilityPolicy.isVisible(
                blockText: renamedBlock.textPlain,
                originalFilename: viewModel.snapshot.attachments.first?.originalFilename
            )
        )

        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()
        let reloadedBlock = try XCTUnwrap(reloadedSnapshot.blocks.first { $0.id == result.block.id })
        XCTAssertEqual(reloadedBlock.textPlain, "Product sketch")
        XCTAssertEqual(reloadedBlock.attachmentID, result.attachment.id)
    }

    @MainActor
    func testDrawingImportCanInsertAfterFocusedTextBlockAndRemainEditable() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        _ = try pageRepository.bootstrapWorkspaceIfNeeded()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let sourceURL = try makeSourceFile(name: "concept.drawing", data: Data("drawing-v1".utf8))

        let viewModel = WorkspaceViewModel(
            repository: pageRepository,
            attachmentRepository: attachmentRepository,
            attachmentThumbnailScheduler: nil
        )
        try viewModel.load()
        let anchorBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        let result = try XCTUnwrap(
            viewModel.importAttachmentForCurrentPage(sourceURL: sourceURL, afterBlockID: anchorBlockID)
        )

        XCTAssertEqual(result.block.type.rawValue, "drawing")
        XCTAssertEqual(viewModel.visibleBlocks.map(\.id).prefix(2), [anchorBlockID, result.block.id])
        XCTAssertEqual(viewModel.visibleBlocks[1].attachmentID, result.attachment.id)

        try viewModel.updateDrawingBlock(blockID: result.block.id, data: Data("drawing-v2".utf8))

        let updatedAttachment = try XCTUnwrap(viewModel.snapshot.attachments.first { $0.id == result.attachment.id })
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: updatedAttachment.localPath)), Data("drawing-v2".utf8))
        XCTAssertEqual(viewModel.visibleBlocks[1].type.rawValue, "drawing")
    }

    @MainActor
    func testAttachmentImageResizePersistsDisplayWidthWithoutChangingName() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        _ = try pageRepository.bootstrapWorkspaceIfNeeded()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let sourceURL = try makeSourceFile(name: "screen.png", data: Self.onePixelPNGData)

        let viewModel = WorkspaceViewModel(
            repository: pageRepository,
            attachmentRepository: attachmentRepository,
            attachmentThumbnailScheduler: nil
        )
        try viewModel.load()
        let result = try XCTUnwrap(viewModel.importAttachmentForCurrentPage(sourceURL: sourceURL))

        try viewModel.updateAttachmentImageDisplayWidth(blockID: result.block.id, displayWidth: 360)

        let resizedBlock = try XCTUnwrap(viewModel.visibleBlocks.last)
        XCTAssertEqual(resizedBlock.textPlain, "screen.png")
        XCTAssertEqual(resizedBlock.attachmentID, result.attachment.id)
        XCTAssertEqual(resizedBlock.attachmentDisplayWidth, 360)

        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()
        let reloadedBlock = try XCTUnwrap(reloadedSnapshot.blocks.first { $0.id == result.block.id })
        XCTAssertEqual(reloadedBlock.textPlain, "screen.png")
        XCTAssertEqual(reloadedBlock.attachmentID, result.attachment.id)
        XCTAssertEqual(reloadedBlock.attachmentDisplayWidth, 360)
    }

    @MainActor
    func testUIAttachmentPasteInsertsAfterSourceBlockInsteadOfAppendingToEnd() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try pageRepository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                First
                Second
                """
        )
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let sourceURL = try makeSourceFile(name: "screen.png", data: Self.onePixelPNGData)

        let viewModel = WorkspaceViewModel(
            repository: pageRepository,
            attachmentRepository: attachmentRepository,
            attachmentThumbnailScheduler: nil
        )
        try viewModel.load()
        let firstBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        let result = try XCTUnwrap(
            viewModel.importAttachmentForCurrentPage(sourceURL: sourceURL, afterBlockID: firstBlockID)
        )

        XCTAssertEqual(viewModel.visibleBlocks.map(\.type), [.paragraph, .attachmentImage, .paragraph])
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["First", "screen.png", "Second"])
        XCTAssertEqual(viewModel.visibleBlocks[1].id, result.block.id)
    }

    @MainActor
    func testUIAttachmentBatchPastePreservesSourceOrderAfterSourceBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try pageRepository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                First
                Second
                """
        )
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let firstSourceURL = try makeSourceFile(name: "one.png", data: Self.onePixelPNGData)
        let secondSourceURL = try makeSourceFile(name: "two.png", data: Self.onePixelPNGData)

        let viewModel = WorkspaceViewModel(
            repository: pageRepository,
            attachmentRepository: attachmentRepository,
            attachmentThumbnailScheduler: nil
        )
        try viewModel.load()
        let firstBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        XCTAssertTrue(
            viewModel.importAttachmentsForCurrentPage(
                sourceURLs: [firstSourceURL, secondSourceURL],
                afterBlockID: firstBlockID
            )
        )

        XCTAssertEqual(
            viewModel.visibleBlocks.map(\.textPlain),
            ["First", "one.png", "two.png", "Second"]
        )
        XCTAssertEqual(
            viewModel.visibleBlocks.map(\.type),
            [.paragraph, .attachmentImage, .attachmentImage, .paragraph]
        )
    }

    @MainActor
    func testUIAttachmentImportSchedulesBackgroundThumbnailGeneration() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        _ = try pageRepository.bootstrapWorkspaceIfNeeded()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let thumbnailScheduler = CapturingAttachmentThumbnailScheduler()
        let sourceURL = try makeSourceFile(name: "screen.png", data: Self.onePixelPNGData)

        let viewModel = WorkspaceViewModel(
            repository: pageRepository,
            attachmentRepository: attachmentRepository,
            attachmentThumbnailScheduler: thumbnailScheduler
        )
        try viewModel.load()

        viewModel.importAttachmentForCurrentPage(sourceURL: sourceURL)
        let importedAttachmentID = try XCTUnwrap(viewModel.snapshot.attachments.first?.id)

        XCTAssertEqual(thumbnailScheduler.scheduledAttachmentIDs, [importedAttachmentID])
        XCTAssertNil(viewModel.snapshot.attachments.first?.thumbnailPath)

        try thumbnailScheduler.runScheduledThumbnailGeneration(at: 0)

        XCTAssertNotNil(viewModel.snapshot.attachments.first?.thumbnailPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(viewModel.snapshot.attachments.first?.thumbnailPath)))
    }

    @MainActor
    func testAttachmentPreviewFailureCanBeRetried() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        _ = try pageRepository.bootstrapWorkspaceIfNeeded()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let thumbnailScheduler = CapturingAttachmentThumbnailScheduler()
        let sourceURL = try makeSourceFile(name: "screen.png", data: Self.onePixelPNGData)

        let viewModel = WorkspaceViewModel(
            repository: pageRepository,
            attachmentRepository: attachmentRepository,
            attachmentThumbnailScheduler: thumbnailScheduler
        )
        try viewModel.load()

        viewModel.importAttachmentForCurrentPage(sourceURL: sourceURL)
        let importedAttachmentID = try XCTUnwrap(viewModel.snapshot.attachments.first?.id)

        XCTAssertEqual(
            viewModel.attachmentPreviewGenerationStatus(attachmentID: importedAttachmentID),
            .generating
        )

        thumbnailScheduler.completeScheduledThumbnailGeneration(
            at: 0,
            with: .failure(WorkspaceViewModelTestError.thumbnailGenerationFailed)
        )

        XCTAssertEqual(
            viewModel.attachmentPreviewGenerationStatus(attachmentID: importedAttachmentID),
            .failed("thumbnailGenerationFailed")
        )

        viewModel.retryAttachmentPreviewGeneration(attachmentID: importedAttachmentID)

        XCTAssertEqual(thumbnailScheduler.scheduledAttachmentIDs, [
            importedAttachmentID,
            importedAttachmentID
        ])
        XCTAssertEqual(
            viewModel.attachmentPreviewGenerationStatus(attachmentID: importedAttachmentID),
            .generating
        )

        try thumbnailScheduler.runScheduledThumbnailGeneration(at: 1)

        XCTAssertEqual(
            viewModel.attachmentPreviewGenerationStatus(attachmentID: importedAttachmentID),
            .idle
        )
        XCTAssertNotNil(viewModel.snapshot.attachments.first?.thumbnailPath)
    }

    @MainActor
    func testPurgeUnreferencedAttachmentsRefreshesSnapshot() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        _ = try pageRepository.bootstrapWorkspaceIfNeeded()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let sourceURL = try makeSourceFile(name: "brief.txt", contents: "local attachment")
        let viewModel = WorkspaceViewModel(
            repository: pageRepository,
            attachmentRepository: attachmentRepository
        )
        try viewModel.load()
        try viewModel.importAttachment(sourceURL: sourceURL)
        let attachmentBlockID = try XCTUnwrap(viewModel.visibleBlocks.last?.id)
        try viewModel.deleteBlock(blockID: attachmentBlockID)

        let purgedCount = try viewModel.purgeUnreferencedAttachments()

        XCTAssertEqual(purgedCount, 1)
        XCTAssertEqual(viewModel.snapshot.attachments, [])
    }

    @MainActor
    func testMarkdownHeadingShortcutUpdatesBlockTypeAndText() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.updateBlockText(blockID: blockID, text: "# ")

        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .heading1)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "")
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        XCTAssertEqual(reloadedSnapshot.blocks.first?.type, .heading1)
        XCTAssertEqual(reloadedSnapshot.blocks.first?.textPlain, "")
    }

    @MainActor
    func testUpdateBlockTextSkipsNoOpSnapshotPublish() throws {
        let snapshot = WorkspaceSnapshot(
            workspaces: [
                WorkspaceSummary(id: "workspace", name: "Workspace")
            ],
            notebooks: [
                NotebookSummary(id: "notebook", workspaceID: "workspace", name: "Notebook")
            ],
            pages: [
                PageSummary(id: "page", workspaceID: "workspace", notebookID: "notebook", title: "Page")
            ],
            blocks: [
                BlockSnapshot(
                    id: "block",
                    pageID: "page",
                    parentBlockID: nil,
                    orderKey: "a",
                    type: .paragraph,
                    textPlain: "Same text"
                )
            ],
            attachments: [],
            selectedWorkspaceID: "workspace",
            selectedNotebookID: "notebook",
            selectedPageID: "page"
        )
        let viewModel = WorkspaceViewModel(snapshot: snapshot)
        var publishCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            publishCount += 1
        }

        try viewModel.updateBlockText(blockID: "block", text: "Same text")

        XCTAssertEqual(publishCount, 0)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Same text")
        _ = cancellable
    }

    @MainActor
    func testUndoLastTextEditRestoresBlockTypeAfterMarkdownShortcut() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.updateBlockText(blockID: blockID, text: "# ")

        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .heading1)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "")

        try viewModel.undoLastTextEdit()

        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .paragraph)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "开始用块写作。")
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
    }

    @MainActor
    func testCompletedTaskMarkdownShortcutUpdatesBlockCompletion() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.updateBlockText(blockID: blockID, text: "- [x] ")

        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .taskItem)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "")
        XCTAssertEqual(viewModel.visibleBlocks.first?.taskItemIsCompleted, true)
    }

    @MainActor
    func testOrderedListMarkdownShortcutAcceptsContinuingNumbers() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.updateBlockText(blockID: blockID, text: "2. ")

        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .orderedListItem)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "")
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        XCTAssertEqual(reloadedSnapshot.blocks.first?.type, .orderedListItem)
        XCTAssertEqual(reloadedSnapshot.blocks.first?.textPlain, "")
    }

    @MainActor
    func testMarkdownListShortcutPreservesExistingTrailingText() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.updateBlockText(blockID: blockID, text: "- fea")

        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .unorderedListItem)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "fea")

        try viewModel.changeBlockType(blockID: blockID, type: .paragraph)
        try viewModel.updateBlockText(blockID: blockID, text: "1. ordered")

        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .orderedListItem)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "ordered")
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
    }

    @MainActor
    func testAsteriskTaskMarkdownShortcutUpdatesBlockCompletion() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.updateBlockText(blockID: blockID, text: "* [X] ")

        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .taskItem)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "")
        XCTAssertEqual(viewModel.visibleBlocks.first?.taskItemIsCompleted, true)

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        XCTAssertEqual(reloadedSnapshot.blocks.first?.type, .taskItem)
        XCTAssertEqual(reloadedSnapshot.blocks.first?.textPlain, "")
        XCTAssertEqual(reloadedSnapshot.blocks.first?.taskItemIsCompleted, true)
    }

    @MainActor
    func testChangeBlockTypeRefreshesVisibleBlockAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.changeBlockType(blockID: blockID, type: .quote)

        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .quote)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "开始用块写作。")
        XCTAssertTrue(
            try SyncRepository(database: database).pendingChanges().contains(
                SyncChange(entityType: "block", entityID: blockID, changeType: "update")
            )
        )
    }

    @MainActor
    func testUpdateTaskItemCompletionRefreshesVisibleBlockAndKeepsFocus() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let taskBlock = try repository.appendBlock(pageID: pageID, type: .taskItem, text: "Ship")

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        try viewModel.updateTaskItemCompletion(blockID: taskBlock.id, isCompleted: true)

        let reloadedTask = try XCTUnwrap(viewModel.visibleBlocks.first { $0.id == taskBlock.id })
        XCTAssertTrue(reloadedTask.taskItemIsCompleted)
        XCTAssertEqual(viewModel.pendingFocusBlockID, taskBlock.id)
    }

    @MainActor
    func testAppendParagraphBlockRefreshesVisibleBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        try viewModel.appendParagraphBlockToCurrentPage()

        XCTAssertEqual(viewModel.visibleBlocks.map(\.type), [.paragraph, .paragraph])
        XCTAssertEqual(viewModel.visibleBlocks.last?.textPlain, "")
    }

    @MainActor
    func testAddParagraphBlockForUIQueuesFocusOnInsertedBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        let insertedBlockID = try XCTUnwrap(viewModel.addParagraphBlockToCurrentPage())

        XCTAssertEqual(viewModel.visibleBlocks.last?.id, insertedBlockID)
        XCTAssertEqual(viewModel.pendingFocusBlockID, insertedBlockID)
    }

    @MainActor
    func testAppendPageReferenceToCurrentPageKeepsSelectionAndRefreshesBacklinks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let targetPage = try repository.createPage(workspaceID: workspaceID, title: "Specs")
        let viewModel = WorkspaceViewModel(
            repository: repository,
            backlinkRepository: BacklinkRepository(database: database)
        )
        try viewModel.load()
        viewModel.selectPage(id: sourcePageID)

        let blockID = try viewModel.appendPageReferenceToCurrentPage(targetPageID: targetPage.id)

        XCTAssertEqual(viewModel.selectedPageID, sourcePageID)
        let pageReferenceBlock = try XCTUnwrap(viewModel.visibleBlocks.first { $0.id == blockID })
        XCTAssertEqual(pageReferenceBlock.type, .pageReference)
        XCTAssertEqual(pageReferenceBlock.textPlain, "Specs")
        XCTAssertEqual(pageReferenceBlock.pageReferenceTargetPageID, targetPage.id)

        viewModel.selectPage(id: targetPage.id)
        XCTAssertEqual(
            viewModel.selectedPageBacklinks,
            [
                Backlink(
                    sourcePageID: sourcePageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: blockID,
                    targetPageID: targetPage.id,
                    targetBlockID: nil,
                    linkText: "Specs"
                )
            ]
        )
    }

    @MainActor
    func testConvertTextBlockToPageSelectsNewPageAndLeavesSourceReference() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "项目计划")
        let viewModel = WorkspaceViewModel(
            repository: repository,
            backlinkRepository: BacklinkRepository(database: database)
        )
        try viewModel.load()
        viewModel.selectPage(id: sourcePageID)

        let createdPage = try viewModel.convertTextBlockToPage(blockID: blockID)
        let sourceBlock = try XCTUnwrap(viewModel.snapshot.blocks.first { $0.id == blockID })

        XCTAssertEqual(createdPage.title, "项目计划")
        XCTAssertEqual(viewModel.selectedPageID, createdPage.id)
        XCTAssertEqual(viewModel.selectedCollection, .recent)
        XCTAssertEqual(sourceBlock.type, .pageReference)
        XCTAssertEqual(sourceBlock.pageReferenceTargetPageID, createdPage.id)
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), [""])
    }

    @MainActor
    func testEditingConvertedListBlockKeepsInlineChildPageTargetInMemory() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let sourceBlock = try repository.appendBlock(
            pageID: sourcePageID,
            type: .orderedListItem,
            text: "列表子页面"
        )
        let viewModel = WorkspaceViewModel(
            repository: repository,
            backlinkRepository: BacklinkRepository(database: database)
        )
        try viewModel.load()
        viewModel.selectPage(id: sourcePageID)
        let createdPage = try viewModel.convertTextBlockToPage(blockID: sourceBlock.id)
        XCTAssertTrue(try viewModel.navigateBack())

        try viewModel.updateBlockText(blockID: sourceBlock.id, text: "列表子页面更新")
        let reloadedSourceBlock = try XCTUnwrap(
            viewModel.snapshot.blocks.first { $0.id == sourceBlock.id }
        )

        XCTAssertEqual(reloadedSourceBlock.type, .orderedListItem)
        XCTAssertEqual(reloadedSourceBlock.textPlain, "列表子页面更新")
        XCTAssertEqual(reloadedSourceBlock.pageReferenceTargetPageID, createdPage.id)
    }

    @MainActor
    func testAppendBlockReferenceAndOpenItFocusesTargetBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let targetPage = try repository.createPage(workspaceID: workspaceID, title: "Specs")
        let targetBlock = try repository.appendBlock(
            pageID: targetPage.id,
            type: .paragraph,
            text: "API contract"
        )
        let viewModel = WorkspaceViewModel(
            repository: repository,
            backlinkRepository: BacklinkRepository(database: database)
        )
        try viewModel.load()
        viewModel.selectPage(id: sourcePageID)

        let blockID = try viewModel.appendBlockReferenceToCurrentPage(targetBlockID: targetBlock.id)

        XCTAssertEqual(viewModel.selectedPageID, sourcePageID)
        let blockReference = try XCTUnwrap(viewModel.visibleBlocks.first { $0.id == blockID })
        XCTAssertEqual(blockReference.type, .blockReference)
        XCTAssertEqual(blockReference.pageReferenceTargetPageID, targetPage.id)
        XCTAssertEqual(blockReference.blockReferenceTargetBlockID, targetBlock.id)

        viewModel.openBlockReference(targetPageID: targetPage.id, targetBlockID: targetBlock.id)

        XCTAssertEqual(viewModel.selectedPageID, targetPage.id)
        XCTAssertEqual(viewModel.pendingFocusBlockID, targetBlock.id)
    }

    @MainActor
    func testCreatePageSelectsNewEmptyPage() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        let createdPage = try viewModel.createPageInSelectedWorkspace(title: "未命名")

        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["未命名", "欢迎"])
        XCTAssertEqual(viewModel.selectedPageID, createdPage.id)
        XCTAssertEqual(viewModel.selectedPage?.title, "未命名")
        XCTAssertEqual(viewModel.visibleBlocks.map(\.type), [.paragraph])
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), [""])
    }

    @MainActor
    func testCreateNotebookRefreshesSnapshot() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        let notebook = try viewModel.createNotebookInSelectedWorkspace(name: "Projects")

        XCTAssertEqual(viewModel.snapshot.notebooks.map(\.name), ["笔记本", "Projects"])
        XCTAssertEqual(viewModel.snapshot.notebooks.last, notebook)
    }

    @MainActor
    func testCreateChildNotebookRefreshesSnapshotAndKeepsHierarchyOrder() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        let parent = try viewModel.createNotebookInSelectedWorkspace(name: "Projects")
        _ = try viewModel.createNotebookInSelectedWorkspace(name: "Areas")
        let child = try viewModel.createNotebookInSelectedWorkspace(
            name: "Client A",
            parentNotebookID: parent.id
        )

        XCTAssertEqual(viewModel.snapshot.notebooks.map(\.name), ["笔记本", "Projects", "Client A", "Areas"])
        XCTAssertEqual(
            viewModel.snapshot.notebooks.first { $0.id == child.id }?.parentNotebookID,
            parent.id
        )
        XCTAssertEqual(viewModel.selectedNotebookID, child.id)
    }

    @MainActor
    func testRenameNotebookRefreshesSnapshotAndKeepsSelection() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let notebookID = try XCTUnwrap(viewModel.selectedNotebookID)

        try viewModel.renameNotebook(id: notebookID, name: "Projects")

        XCTAssertEqual(viewModel.snapshot.notebooks.first?.name, "Projects")
        XCTAssertEqual(viewModel.selectedNotebookID, notebookID)
    }

    @MainActor
    func testMoveNotebookRefreshesSnapshotAndKeepsSelection() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let workspaceID = try XCTUnwrap(viewModel.selectedWorkspaceID)
        _ = try repository.createNotebook(workspaceID: workspaceID, name: "Projects")
        let areas = try repository.createNotebook(workspaceID: workspaceID, name: "Areas")
        try viewModel.load()
        viewModel.selectNotebook(id: areas.id)

        try viewModel.moveNotebook(id: areas.id, toIndex: 0)

        XCTAssertEqual(viewModel.snapshot.notebooks.map(\.name), ["Areas", "笔记本", "Projects"])
        XCTAssertEqual(viewModel.selectedNotebookID, areas.id)
    }

    @MainActor
    func testNestAndOutdentNotebookRefreshesSnapshotAndKeepsSelection() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let workspaceID = try XCTUnwrap(viewModel.selectedWorkspaceID)
        let parent = try repository.createNotebook(workspaceID: workspaceID, name: "Projects")
        let child = try repository.createNotebook(workspaceID: workspaceID, name: "Client A")
        try viewModel.load()
        viewModel.selectNotebook(id: child.id)

        try viewModel.updateNotebookParent(id: child.id, parentNotebookID: parent.id)

        XCTAssertEqual(
            viewModel.snapshot.notebooks.first { $0.id == child.id }?.parentNotebookID,
            parent.id
        )
        XCTAssertEqual(viewModel.selectedNotebookID, child.id)

        try viewModel.updateNotebookParent(id: child.id, parentNotebookID: nil)

        XCTAssertNil(viewModel.snapshot.notebooks.first { $0.id == child.id }?.parentNotebookID)
        XCTAssertEqual(viewModel.selectedNotebookID, child.id)
    }

    @MainActor
    func testIndentAndOutdentNotebookForUIUsePreviousSiblingAndKeepSelection() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let workspaceID = try XCTUnwrap(viewModel.selectedWorkspaceID)
        let parent = try repository.createNotebook(workspaceID: workspaceID, name: "Projects")
        let child = try repository.createNotebook(workspaceID: workspaceID, name: "Client A")
        try viewModel.load()
        viewModel.selectNotebook(id: child.id)

        XCTAssertTrue(viewModel.indentNotebookForUI(id: child.id))
        XCTAssertEqual(
            viewModel.snapshot.notebooks.first { $0.id == child.id }?.parentNotebookID,
            parent.id
        )
        XCTAssertEqual(viewModel.selectedNotebookID, child.id)

        XCTAssertTrue(viewModel.outdentNotebookForUI(id: child.id))
        XCTAssertNil(viewModel.snapshot.notebooks.first { $0.id == child.id }?.parentNotebookID)
        XCTAssertEqual(viewModel.selectedNotebookID, child.id)
    }

    @MainActor
    func testArchiveSelectedPageHidesPageAndSelectsRemainingPage() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let page = try viewModel.createPageInSelectedWorkspace(title: "Scratch")
        XCTAssertEqual(viewModel.selectedPageID, page.id)

        try viewModel.archiveSelectedPage()

        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["欢迎"])
        XCTAssertEqual(viewModel.selectedPage?.title, "欢迎")
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["开始用块写作。"])
    }

    @MainActor
    func testArchivePageForUIKeepsCurrentSelectionWhenArchivingBackgroundPage() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let currentPage = try viewModel.createPageInSelectedWorkspace(title: "Current")
        let scratchPage = try viewModel.createPageInSelectedWorkspace(title: "Scratch")
        viewModel.selectPage(id: currentPage.id)

        viewModel.archivePageForUI(id: scratchPage.id)

        XCTAssertEqual(viewModel.snapshot.archivedPages.map(\.title), ["Scratch"])
        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["Current", "欢迎"])
        XCTAssertEqual(viewModel.selectedPageID, currentPage.id)
        XCTAssertEqual(viewModel.selectedPage?.title, "Current")
    }

    @MainActor
    func testUpdatePageFavoriteRefreshesSnapshotAndKeepsSelection() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let scratchPage = try viewModel.createPageInSelectedWorkspace(title: "Scratch")

        try viewModel.updatePageFavorite(id: scratchPage.id, isFavorite: true)

        XCTAssertEqual(viewModel.selectedPageID, scratchPage.id)
        XCTAssertEqual(viewModel.selectedPage?.isFavorite, true)
        XCTAssertEqual(viewModel.snapshot.favoritePages.map(\.title), ["Scratch"])

        try viewModel.updatePageFavorite(id: scratchPage.id, isFavorite: false)

        XCTAssertEqual(viewModel.selectedPageID, scratchPage.id)
        XCTAssertEqual(viewModel.selectedPage?.isFavorite, false)
        XCTAssertEqual(viewModel.snapshot.favoritePages, [])
    }

    @MainActor
    func testUpdatePagePinnedRefreshesSnapshotAndKeepsSelection() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let scratchPage = try viewModel.createPageInSelectedWorkspace(title: "Scratch")

        try viewModel.updatePagePinned(id: scratchPage.id, isPinned: true)

        XCTAssertEqual(viewModel.selectedPageID, scratchPage.id)
        XCTAssertEqual(viewModel.selectedPage?.isPinned, true)
        XCTAssertEqual(viewModel.snapshot.pages.first?.id, scratchPage.id)

        try viewModel.updatePagePinned(id: scratchPage.id, isPinned: false)

        XCTAssertEqual(viewModel.selectedPageID, scratchPage.id)
        XCTAssertEqual(viewModel.selectedPage?.isPinned, false)
    }

    @MainActor
    func testUndoLastPageArchiveRestoresBackgroundPageWithoutChangingCurrentSelection() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let currentPage = try viewModel.createPageInSelectedWorkspace(title: "Current")
        let scratchPage = try viewModel.createPageInSelectedWorkspace(title: "Scratch")
        viewModel.selectPage(id: currentPage.id)
        XCTAssertFalse(viewModel.canUndoPageArchive)

        viewModel.archivePageForUI(id: scratchPage.id)

        XCTAssertTrue(viewModel.canUndoPageArchive)
        try viewModel.undoLastPageArchive()

        XCTAssertEqual(viewModel.snapshot.archivedPages, [])
        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["Scratch", "Current", "欢迎"])
        XCTAssertEqual(viewModel.selectedPageID, currentPage.id)
        XCTAssertFalse(viewModel.canUndoPageArchive)
    }

    @MainActor
    func testUndoLastPageArchiveRestoresSelectedArchivedPageAndSelection() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let scratchPage = try viewModel.createPageInSelectedWorkspace(title: "Scratch")

        viewModel.archivePageForUI(id: scratchPage.id)

        XCTAssertEqual(viewModel.selectedPage?.title, "欢迎")
        XCTAssertTrue(viewModel.canUndoPageArchive)

        try viewModel.undoLastPageArchive()

        XCTAssertEqual(viewModel.snapshot.archivedPages, [])
        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["Scratch", "欢迎"])
        XCTAssertEqual(viewModel.selectedPageID, scratchPage.id)
        XCTAssertEqual(viewModel.selectedPage?.title, "Scratch")
        XCTAssertFalse(viewModel.canUndoPageArchive)
    }

    @MainActor
    func testRestoreArchivedPageRefreshesSnapshotAndSelectsRestoredPage() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let page = try viewModel.createPageInSelectedWorkspace(title: "Scratch")
        try viewModel.archiveSelectedPage()

        XCTAssertEqual(viewModel.snapshot.archivedPages.map(\.title), ["Scratch"])

        try viewModel.restoreArchivedPage(id: page.id)

        XCTAssertEqual(viewModel.snapshot.archivedPages, [])
        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["Scratch", "欢迎"])
        XCTAssertEqual(viewModel.selectedPageID, page.id)
        XCTAssertEqual(viewModel.selectedPage?.title, "Scratch")
    }

    @MainActor
    func testPermanentlyDeleteArchivedPageRefreshesSnapshotAndKeepsVisibleSelection() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let page = try viewModel.createPageInSelectedWorkspace(title: "Scratch")
        try viewModel.archiveSelectedPage()

        try viewModel.permanentlyDeleteArchivedPage(id: page.id)

        XCTAssertEqual(viewModel.snapshot.archivedPages, [])
        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["欢迎"])
        XCTAssertEqual(viewModel.selectedPage?.title, "欢迎")
    }

    @MainActor
    func testCreatePageRequestsFocusForInitialEmptyBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        _ = try viewModel.createPageInSelectedWorkspace(title: "未命名")
        let initialBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        XCTAssertEqual(viewModel.pendingFocusBlockID, initialBlockID)
        XCTAssertEqual(viewModel.consumePendingFocusBlockID(), initialBlockID)
        XCTAssertNil(viewModel.pendingFocusBlockID)
    }

    @MainActor
    func testExportCurrentPageMarkdownUsesVisibleBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                # Title

                Body
                """
        )

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        XCTAssertEqual(
            viewModel.exportCurrentPageMarkdown(),
            """
            # Title

            Body
            """
        )
    }

    @MainActor
    func testExportCurrentPageMarkdownUsesAttachmentRelativePath() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let viewModel = WorkspaceViewModel(
            repository: repository,
            attachmentRepository: attachmentRepository
        )
        try viewModel.load()

        let result = try viewModel.importAttachment(
            sourceURL: makeSourceFile(name: "brief.txt", contents: "local attachment")
        )

        XCTAssertEqual(
            viewModel.exportCurrentPageMarkdown(),
            """
            开始用块写作。

            [brief.txt](Attachments/\(result.attachment.id)/brief.txt)
            """
        )
    }

    @MainActor
    func testExportCurrentPageMarkdownPackageWritesMarkdownAndCopiesAttachments() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let viewModel = WorkspaceViewModel(
            repository: repository,
            attachmentRepository: attachmentRepository
        )
        try viewModel.load()
        let result = try viewModel.importAttachment(
            sourceURL: makeSourceFile(name: "brief.txt", contents: "local attachment")
        )
        let exportDirectory = makeTemporaryDirectory()
        let markdownURL = exportDirectory.appendingPathComponent("欢迎.md")

        try viewModel.exportCurrentPageMarkdownPackage(to: markdownURL)

        XCTAssertEqual(
            try String(contentsOf: markdownURL, encoding: .utf8),
            """
            开始用块写作。

            [brief.txt](Attachments/\(result.attachment.id)/brief.txt)
            """
        )
        let copiedAttachmentURL = exportDirectory
            .appendingPathComponent("Attachments", isDirectory: true)
            .appendingPathComponent(result.attachment.id, isDirectory: true)
            .appendingPathComponent("brief.txt")
        XCTAssertEqual(
            try String(contentsOf: copiedAttachmentURL, encoding: .utf8),
            "local attachment"
        )
    }

    @MainActor
    func testImportMarkdownPackageCopiesAttachmentsAndRestoresAttachmentBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let attachmentsDirectory = makeTemporaryDirectory()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: attachmentsDirectory
        )
        let viewModel = WorkspaceViewModel(
            repository: repository,
            attachmentRepository: attachmentRepository,
            attachmentThumbnailScheduler: nil
        )
        try viewModel.load()
        let packageDirectory = makeTemporaryDirectory()
        let packageAttachmentDirectory = packageDirectory
            .appendingPathComponent("Attachments", isDirectory: true)
            .appendingPathComponent("source-attachment", isDirectory: true)
        try FileManager.default.createDirectory(
            at: packageAttachmentDirectory,
            withIntermediateDirectories: true
        )
        try "packaged attachment".write(
            to: packageAttachmentDirectory.appendingPathComponent("brief.txt"),
            atomically: true,
            encoding: .utf8
        )
        let markdownURL = packageDirectory.appendingPathComponent("欢迎.md")
        try """
        Imported intro

        [brief.txt](Attachments/source-attachment/brief.txt)
        """.write(to: markdownURL, atomically: true, encoding: .utf8)

        try viewModel.importMarkdownPackageToCurrentPage(markdownURL: markdownURL)

        XCTAssertEqual(viewModel.visibleBlocks.map(\.type), [.paragraph, .attachmentFile])
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Imported intro", "brief.txt"])
        let attachmentBlock = try XCTUnwrap(viewModel.visibleBlocks.last)
        let importedAttachment = try XCTUnwrap(viewModel.snapshot.attachments.first)
        XCTAssertEqual(attachmentBlock.attachmentID, importedAttachment.id)
        XCTAssertTrue(importedAttachment.localPath.hasPrefix(attachmentsDirectory.path))
        XCTAssertEqual(
            try String(contentsOfFile: importedAttachment.localPath, encoding: .utf8),
            "packaged attachment"
        )
    }

    @MainActor
    func testPlainMarkdownImportPreservesAttachmentPackageLinksWithoutImporter() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        try viewModel.importMarkdownToCurrentPage(
            """
            Imported intro

            [brief.txt](Attachments/source-attachment/brief.txt)
            """
        )

        XCTAssertEqual(viewModel.visibleBlocks.map(\.type), [.paragraph, .paragraph])
        XCTAssertEqual(
            viewModel.visibleBlocks.map(\.textPlain),
            [
                "Imported intro",
                "[brief.txt](Attachments/source-attachment/brief.txt)"
            ]
        )
        XCTAssertEqual(viewModel.snapshot.attachments, [])
    }

    @MainActor
    func testImportMarkdownPackagePreservesMissingAttachmentLinksAsText() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let viewModel = WorkspaceViewModel(
            repository: repository,
            attachmentRepository: attachmentRepository
        )
        try viewModel.load()
        let packageDirectory = makeTemporaryDirectory()
        let markdownURL = packageDirectory.appendingPathComponent("欢迎.md")
        try """
        Imported intro

        [missing.txt](Attachments/source-attachment/missing.txt)
        """.write(to: markdownURL, atomically: true, encoding: .utf8)

        try viewModel.importMarkdownPackageToCurrentPage(markdownURL: markdownURL)

        XCTAssertEqual(viewModel.visibleBlocks.map(\.type), [.paragraph, .paragraph])
        XCTAssertEqual(
            viewModel.visibleBlocks.map(\.textPlain),
            [
                "Imported intro",
                "[missing.txt](Attachments/source-attachment/missing.txt)"
            ]
        )
        XCTAssertEqual(viewModel.snapshot.attachments, [])
        XCTAssertEqual(viewModel.markdownImportStatusText, "Missing attachment: missing.txt")
    }

    @MainActor
    func testPlainMarkdownImportClearsPreviousMarkdownImportStatus() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let viewModel = WorkspaceViewModel(
            repository: repository,
            attachmentRepository: attachmentRepository
        )
        try viewModel.load()
        let packageDirectory = makeTemporaryDirectory()
        let markdownURL = packageDirectory.appendingPathComponent("欢迎.md")
        try "[missing.txt](Attachments/source-attachment/missing.txt)"
            .write(to: markdownURL, atomically: true, encoding: .utf8)
        try viewModel.importMarkdownPackageToCurrentPage(markdownURL: markdownURL)
        XCTAssertEqual(viewModel.markdownImportStatusText, "Missing attachment: missing.txt")

        try viewModel.importMarkdownToCurrentPage("Plain import")

        XCTAssertNil(viewModel.markdownImportStatusText)
    }

    @MainActor
    func testObsidianVaultImportSchedulesBackgroundWorkAndReportsCompletion() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let importer = RecordingObsidianVaultImporter(
            summary: ObsidianVaultImportSummary(
                markdownFileCount: 5,
                importedPageCount: 2,
                skippedPageCount: 3,
                encryptedPageCount: 0,
                diaryPageCount: 1,
                importedAttachmentCount: 1,
                ignoredNonMarkdownFileCount: 0,
                diaryPatterns: [:]
            )
        )
        let scheduler = DeferredObsidianImportScheduler()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            obsidianImporter: importer,
            obsidianImportScheduler: scheduler
        )
        try viewModel.load()
        let vaultURL = makeTemporaryDirectory()

        viewModel.importObsidianVaultForCurrentWorkspace(sourceURL: vaultURL)

        XCTAssertEqual(scheduler.scheduledOperationCount, 1)
        XCTAssertEqual(importer.importedVaultURLs, [])
        XCTAssertEqual(viewModel.markdownImportStatusText, "Importing Obsidian vault...")

        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(importer.importedVaultURLs, [vaultURL])
        XCTAssertEqual(viewModel.markdownImportStatusText, "Imported 2 Obsidian notes, 1 attachments, skipped 3")
    }

    @MainActor
    func testImportMarkdownToCurrentPageRefreshesVisibleBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        try viewModel.importMarkdownToCurrentPage(
            """
            # Imported

            - Item
            """
        )

        XCTAssertEqual(viewModel.visibleBlocks.map(\.type), [.heading1, .unorderedListItem])
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Imported", "Item"])
    }

    @MainActor
    func testImportMarkdownToCurrentPagePreservesRecentPageRoute() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let viewModel = WorkspaceViewModel(
            repository: repository,
            diaryRepository: DiaryRepository(database: database)
        )
        try viewModel.load()
        viewModel.selectCollection(.recent)
        viewModel.selectPage(id: pageID)

        try viewModel.importMarkdownToCurrentPage(
            """
            # Imported

            Body
            """
        )

        XCTAssertEqual(viewModel.selectedCollection, .recent)
        XCTAssertEqual(viewModel.selectedPageID, pageID)
        XCTAssertEqual(viewModel.visibleBlocks.map(\.type), [.heading1, .paragraph])
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Imported", "Body"])
    }

    @MainActor
    func testSelectedPageOutlineTracksHeadingBlocksAndSelectionFocus() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        try viewModel.importMarkdownToCurrentPage(
            """
            # Overview

            ## Plan

            Body

            ### Details
            """
        )

        XCTAssertEqual(viewModel.selectedPageOutline.map(\.title), ["Overview", "Plan", "Details"])
        XCTAssertEqual(viewModel.selectedPageOutline.map(\.level), [1, 2, 3])

        let overviewItem = try XCTUnwrap(viewModel.selectedPageOutline.first)
        viewModel.selectOutlineItem(overviewItem)

        XCTAssertEqual(viewModel.pendingFocusBlockID, overviewItem.blockID)
        let firstRequestID = try XCTUnwrap(viewModel.pendingFocusRequestID)
        viewModel.selectOutlineItem(overviewItem)
        XCTAssertNotEqual(viewModel.pendingFocusRequestID, firstRequestID)
        XCTAssertEqual(viewModel.pendingCompactPageNavigationID, viewModel.selectedPageID)
    }

    @MainActor
    func testSearchQueryRefreshesResultsFromCurrentBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(
            repository: repository,
            searchRepository: SearchRepository(database: database)
        )
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        try viewModel.updateBlockText(blockID: blockID, text: "Alpha searchable block")

        viewModel.updateSearchQuery("Alpha")

        XCTAssertEqual(viewModel.searchResults.map(\.snippet), ["Alpha searchable block"])
    }

    @MainActor
    func testSearchQueryCanDebounceRepositoryRefreshForLargeVaultInput() async throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(
            repository: repository,
            searchRepository: SearchRepository(database: database),
            searchDebounceNanoseconds: 30_000_000
        )
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        try viewModel.updateBlockText(blockID: blockID, text: "Alpha searchable block")

        viewModel.updateSearchQuery("Alpha")

        XCTAssertTrue(viewModel.isSearchRefreshPending)
        XCTAssertEqual(viewModel.searchResults, [])

        try await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertFalse(viewModel.isSearchRefreshPending)
        XCTAssertEqual(viewModel.searchResults.map(\.snippet), ["Alpha searchable block"])
    }

    @MainActor
    func testSelectSearchResultDisplaysDestinationPageWithoutLeavingSearchCollection() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let secondPageID = "page-second"
        try insertPage(
            database: database,
            id: secondPageID,
            workspaceID: workspaceID,
            title: "Second"
        )

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        viewModel.selectCollection(.search)

        viewModel.selectSearchResult(
            SearchResult(
                entityType: "page",
                entityID: secondPageID,
                title: "Second",
                snippet: "Second",
                destinationPageID: secondPageID
            )
        )

        XCTAssertEqual(viewModel.selectedPageID, secondPageID)
        XCTAssertEqual(viewModel.selectedPage?.title, "Second")
        XCTAssertEqual(viewModel.selectedCollection, .search)
        XCTAssertEqual(viewModel.pendingCompactPageNavigationID, secondPageID)
        XCTAssertEqual(viewModel.consumePendingCompactPageNavigationID(), secondPageID)
        XCTAssertNil(viewModel.pendingCompactPageNavigationID)
    }

    @MainActor
    func testSelectedPageBacklinksRefreshAfterBlockEdit() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(
            repository: repository,
            backlinkRepository: BacklinkRepository(database: database)
        )
        try viewModel.load()
        let pageID = try XCTUnwrap(viewModel.selectedPageID)
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.updateBlockText(blockID: blockID, text: "See [[欢迎]]")

        XCTAssertEqual(
            viewModel.selectedPageBacklinks,
            [
                Backlink(
                    sourcePageID: pageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: blockID,
                    targetPageID: pageID,
                    targetBlockID: nil,
                    linkText: "欢迎"
                )
            ]
        )
    }

    @MainActor
    func testSelectedPageExternalLinksRefreshAfterBlockEdit() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(
            repository: repository,
            backlinkRepository: BacklinkRepository(database: database)
        )
        try viewModel.load()
        let pageID = try XCTUnwrap(viewModel.selectedPageID)
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.updateBlockText(blockID: blockID, text: "Read [Swift](https://swift.org)")

        XCTAssertEqual(
            viewModel.selectedPageExternalLinks,
            [
                ExternalLink(
                    sourcePageID: pageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: blockID,
                    targetURL: "https://swift.org",
                    linkText: "Swift"
                )
            ]
        )
    }

    @MainActor
    func testInsertMarkdownLinkIntoTextBlockRefreshesExternalLinksAndFocus() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(
            repository: repository,
            backlinkRepository: BacklinkRepository(database: database)
        )
        try viewModel.load()
        let pageID = try XCTUnwrap(viewModel.selectedPageID)
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        XCTAssertTrue(
            try viewModel.insertMarkdownLink(
                blockID: blockID,
                label: "Swift",
                url: "https://swift.org"
            )
        )

        XCTAssertEqual(
            viewModel.visibleBlocks.first?.textPlain,
            "开始用块写作。 [Swift](https://swift.org)"
        )
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
        XCTAssertEqual(
            viewModel.selectedPageExternalLinks,
            [
                ExternalLink(
                    sourcePageID: pageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: blockID,
                    targetURL: "https://swift.org",
                    linkText: "Swift"
                )
            ]
        )
    }

    @MainActor
    func testInsertMarkdownLinkAtSelectionRefreshesExternalLinksAndReturnsLabelSelection() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(
            repository: repository,
            backlinkRepository: BacklinkRepository(database: database)
        )
        try viewModel.load()
        let pageID = try XCTUnwrap(viewModel.selectedPageID)
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        let nextSelection = try XCTUnwrap(
            try viewModel.insertMarkdownLink(
                blockID: blockID,
                label: "Swift",
                url: "https://swift.org",
                selection: EditorTextSelection(blockID: blockID, location: 3, length: 1)
            )
        )

        XCTAssertEqual(
            viewModel.visibleBlocks.first?.textPlain,
            "开始用[Swift](https://swift.org)写作。"
        )
        XCTAssertEqual(nextSelection, EditorTextSelection(blockID: blockID, location: 4, length: 5))
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
        XCTAssertEqual(
            viewModel.selectedPageExternalLinks,
            [
                ExternalLink(
                    sourcePageID: pageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: blockID,
                    targetURL: "https://swift.org",
                    linkText: "Swift"
                )
            ]
        )
    }

    @MainActor
    func testUpdateExistingMarkdownLinkAtSelectionRefreshesExternalLinksAndReturnsLabelSelection() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(
            repository: repository,
            backlinkRepository: BacklinkRepository(database: database)
        )
        try viewModel.load()
        let pageID = try XCTUnwrap(viewModel.selectedPageID)
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        try viewModel.updateBlockText(
            blockID: blockID,
            text: "Read [Swift](https://swift.org) today"
        )

        let editTarget = try XCTUnwrap(
            MarkdownInlineLinkEditTarget.target(
                in: try XCTUnwrap(viewModel.visibleBlocks.first?.textPlain),
                selection: EditorTextSelection(
                    blockID: blockID,
                    location: ("Read [Swift](https://swift" as NSString).length,
                    length: 0
                )
            )
        )

        let nextSelection = try XCTUnwrap(
            try viewModel.insertMarkdownLink(
                blockID: blockID,
                label: "Apple Docs",
                url: "https://developer.apple.com",
                selection: editTarget.replacementSelection
            )
        )

        XCTAssertEqual(
            viewModel.visibleBlocks.first?.textPlain,
            "Read [Apple Docs](https://developer.apple.com) today"
        )
        XCTAssertEqual(nextSelection, EditorTextSelection(blockID: blockID, location: 6, length: 10))
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
        XCTAssertEqual(
            viewModel.selectedPageExternalLinks,
            [
                ExternalLink(
                    sourcePageID: pageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: blockID,
                    targetURL: "https://developer.apple.com",
                    linkText: "Apple Docs"
                )
            ]
        )
    }

    @MainActor
    func testUpdateTableRowsPersistsStructuredPayloadAndMarkdownExportText() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(
            repository: repository,
            backlinkRepository: BacklinkRepository(database: database)
        )
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.changeBlockType(blockID: blockID, type: .table)
        try viewModel.updateTableRows(
            blockID: blockID,
            rows: [["Name", "Status"], ["Editor", "Draft"]]
        )

        XCTAssertEqual(viewModel.visibleBlocks.first?.tableRows, [["Name", "Status"], ["Editor", "Draft"]])
        XCTAssertEqual(
            viewModel.visibleBlocks.first?.textPlain,
            """
            | Name | Status |
            | --- | --- |
            | Editor | Draft |
            """
        )

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        XCTAssertEqual(reloadedSnapshot.blocks.first?.tableRows, [["Name", "Status"], ["Editor", "Draft"]])
    }

    @MainActor
    func testUndoLastTextEditRestoresPreviousStructuredTableRows() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let initialRows = [["Name", "Status"], ["Editor", "Draft"]]
        let initialTable = MarkdownTableDocument(rows: initialRows)
        try repository.updateBlock(
            blockID: blockID,
            type: .table,
            text: initialTable.markdown,
            tableRows: initialRows
        )

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        try viewModel.updateTableRows(
            blockID: blockID,
            rows: [["Name", "Status"], ["Editor", "Ready"]]
        )
        try viewModel.undoLastTextEdit()

        XCTAssertEqual(viewModel.visibleBlocks.first?.tableRows, initialRows)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, initialTable.markdown)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        XCTAssertEqual(reloadedSnapshot.blocks.first?.tableRows, initialRows)
    }

    @MainActor
    func testRemoveExistingMarkdownLinkAtSelectionRefreshesExternalLinksAndReturnsLabelSelection() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(
            repository: repository,
            backlinkRepository: BacklinkRepository(database: database)
        )
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        try viewModel.updateBlockText(
            blockID: blockID,
            text: "Read [Swift](https://swift.org) today"
        )
        XCTAssertEqual(viewModel.selectedPageExternalLinks.count, 1)

        let nextSelection = try XCTUnwrap(
            try viewModel.removeMarkdownLink(
                blockID: blockID,
                selection: EditorTextSelection(
                    blockID: blockID,
                    location: ("Read [Swift](https://swift" as NSString).length,
                    length: 0
                )
            )
        )

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Read Swift today")
        XCTAssertEqual(nextSelection, EditorTextSelection(blockID: blockID, location: 5, length: 5))
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
        XCTAssertTrue(viewModel.selectedPageExternalLinks.isEmpty)
    }

    @MainActor
    func testApplyMarkdownInlineFormatWrapsSelectionAndQueuesFocus() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        let nextSelection = try XCTUnwrap(
            try viewModel.applyMarkdownInlineFormat(
                blockID: blockID,
                format: .bold,
                selection: EditorTextSelection(blockID: blockID, location: 3, length: 1)
            )
        )

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "开始用**块**写作。")
        XCTAssertEqual(nextSelection, EditorTextSelection(blockID: blockID, location: 5, length: 1))
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
        XCTAssertTrue(viewModel.canUndoTextEdit)

        try viewModel.undoLastTextEdit()
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "开始用块写作。")
    }

    @MainActor
    func testApplyMarkdownInlineItalicFormatWrapsSelectionAndQueuesFocus() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        let nextSelection = try XCTUnwrap(
            try viewModel.applyMarkdownInlineFormat(
                blockID: blockID,
                format: .italic,
                selection: EditorTextSelection(blockID: blockID, location: 3, length: 1)
            )
        )

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "开始用*块*写作。")
        XCTAssertEqual(nextSelection, EditorTextSelection(blockID: blockID, location: 4, length: 1))
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
        XCTAssertTrue(viewModel.canUndoTextEdit)
    }

    @MainActor
    func testApplyMarkdownInlineFormatRejectsMismatchedSelectionBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        XCTAssertNil(
            try viewModel.applyMarkdownInlineFormat(
                blockID: blockID,
                format: .code,
                selection: EditorTextSelection(blockID: "other-block", location: 0, length: 5)
            )
        )
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "开始用块写作。")
        XCTAssertFalse(viewModel.canUndoTextEdit)
    }

    @MainActor
    func testSelectedPageConflictsAutoResolveOnLoad() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "Local edit")
        try storeConflict(database: database, blockID: blockID, text: "Remote edit")

        let viewModel = WorkspaceViewModel(
            repository: repository,
            conflictRepository: ConflictRepository(database: database)
        )
        try viewModel.load()

        XCTAssertEqual(pageID, viewModel.selectedPageID)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Local edit\nRemote edit")
        XCTAssertEqual(viewModel.selectedPageConflicts, [])
        XCTAssertEqual(try ConflictRepository(database: database).conflicts(blockID: blockID), [])
        XCTAssertTrue(
            try SyncRepository(database: database).pendingChanges().contains(
                SyncChange(entityType: "block", entityID: blockID, changeType: "update")
            )
        )
    }

    @MainActor
    func testAcceptAllRemoteConflictsForSelectedPageRefreshesAllBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let firstBlockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let secondBlock = try repository.appendBlock(
            pageID: pageID,
            type: .paragraph,
            text: "Second"
        )
        try repository.updateBlockText(blockID: firstBlockID, text: "Local one")
        try repository.updateBlockText(blockID: secondBlock.id, text: "Local two")
        try storeConflict(database: database, blockID: firstBlockID, text: "Remote one")
        try storeConflict(database: database, blockID: secondBlock.id, text: "Remote two")

        let viewModel = WorkspaceViewModel(
            repository: repository,
            conflictRepository: ConflictRepository(database: database),
            automaticallyResolveConflicts: false
        )
        try viewModel.load()
        XCTAssertEqual(viewModel.selectedPageConflicts.count, 2)

        try viewModel.acceptAllRemoteConflictsForSelectedPage()

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Remote one", "Remote two"])
        XCTAssertEqual(viewModel.selectedPageConflicts, [])
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges(), [])
    }

    @MainActor
    func testAcceptAllLocalConflictsForSelectedPageKeepsLocalBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let firstBlockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let secondBlock = try repository.appendBlock(
            pageID: pageID,
            type: .paragraph,
            text: "Second"
        )
        try repository.updateBlockText(blockID: firstBlockID, text: "Local one")
        try repository.updateBlockText(blockID: secondBlock.id, text: "Local two")
        try storeConflict(database: database, blockID: firstBlockID, text: "Remote one")
        try storeConflict(database: database, blockID: secondBlock.id, text: "Remote two")

        let viewModel = WorkspaceViewModel(
            repository: repository,
            conflictRepository: ConflictRepository(database: database),
            automaticallyResolveConflicts: false
        )
        try viewModel.load()
        XCTAssertEqual(viewModel.selectedPageConflicts.count, 2)

        try viewModel.acceptAllLocalConflictsForSelectedPage()

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Local one", "Local two"])
        XCTAssertEqual(viewModel.selectedPageConflicts, [])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().filter { $0.changeType == "update" }.count,
            3
        )
        XCTAssertEqual(viewModel.pendingFocusBlockID, firstBlockID)
    }

    @MainActor
    func testManualConflictMergeRefreshesBlockAndKeepsPendingSync() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "Local edit")
        try storeConflict(database: database, blockID: blockID, text: "Remote edit")

        let viewModel = WorkspaceViewModel(
            repository: repository,
            conflictRepository: ConflictRepository(database: database),
            automaticallyResolveConflicts: false
        )
        try viewModel.load()
        let conflict = try XCTUnwrap(viewModel.selectedPageConflicts.first)

        XCTAssertEqual(conflict.localTextPlain, "Local edit")
        XCTAssertEqual(conflict.remoteTextPlain, "Remote edit")

        try viewModel.resolveConflictManually(id: conflict.id, text: "Merged edit")

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Merged edit")
        XCTAssertEqual(viewModel.selectedPageConflicts, [])
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
        XCTAssertTrue(
            try SyncRepository(database: database).pendingChanges().contains(
                SyncChange(entityType: "block", entityID: blockID, changeType: "update")
            )
        )
    }

    @MainActor
    func testResolveAllManualConflictsForSelectedPageAppliesMergedTexts() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let firstBlockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let secondBlock = try repository.appendBlock(
            pageID: pageID,
            type: .paragraph,
            text: "Second"
        )
        try repository.updateBlockText(blockID: firstBlockID, text: "Local one")
        try repository.updateBlockText(blockID: secondBlock.id, text: "Local two")
        try storeConflict(database: database, blockID: firstBlockID, text: "Remote one")
        try storeConflict(database: database, blockID: secondBlock.id, text: "Remote two")

        let viewModel = WorkspaceViewModel(
            repository: repository,
            conflictRepository: ConflictRepository(database: database),
            automaticallyResolveConflicts: false
        )
        try viewModel.load()
        let conflicts = viewModel.selectedPageConflicts
        XCTAssertEqual(conflicts.count, 2)

        try viewModel.resolveAllManualConflictsForSelectedPage(
            mergedTextsByConflictID: Dictionary(
                uniqueKeysWithValues: conflicts.map { conflict in
                    (conflict.id, "Merged \(conflict.blockID == firstBlockID ? "one" : "two")")
                }
            )
        )

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Merged one", "Merged two"])
        XCTAssertEqual(viewModel.selectedPageConflicts, [])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().filter { $0.changeType == "update" }.count,
            3
        )
        XCTAssertEqual(viewModel.pendingFocusBlockID, firstBlockID)
    }

    @MainActor
    func testSelectBacklinkNavigatesToSourcePage() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let secondPageID = "page-second"
        try insertPage(
            database: database,
            id: secondPageID,
            workspaceID: workspaceID,
            title: "Second"
        )
        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        viewModel.selectPage(id: secondPageID)

        viewModel.selectBacklink(
            Backlink(
                sourcePageID: snapshot.selectedPageID ?? "",
                sourcePageTitle: "欢迎",
                sourceBlockID: snapshot.blocks.first?.id,
                targetPageID: secondPageID,
                targetBlockID: nil,
                linkText: "Second"
            )
        )

        XCTAssertEqual(viewModel.selectedPageID, snapshot.selectedPageID)
        XCTAssertEqual(viewModel.selectedPage?.title, "欢迎")
        XCTAssertEqual(viewModel.pendingCompactPageNavigationID, snapshot.selectedPageID)
    }

    @MainActor
    func testMoveVisibleBlockRefreshesOrder() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                First
                Second
                Third
                """
        )

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let thirdBlockID = try XCTUnwrap(viewModel.visibleBlocks.last?.id)

        try viewModel.moveBlock(blockID: thirdBlockID, toIndex: 0)

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Third", "First", "Second"])
    }

    @MainActor
    func testKeyboardMoveBlockReordersAndKeepsFocusOnMovedBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                First
                Second
                Third
                """
        )

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let secondBlockID = try XCTUnwrap(viewModel.visibleBlocks.dropFirst().first?.id)

        XCTAssertTrue(try viewModel.moveBlockByKeyboard(blockID: secondBlockID, direction: .up))

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Second", "First", "Third"])
        XCTAssertEqual(viewModel.pendingFocusBlockID, secondBlockID)
    }

    @MainActor
    func testKeyboardMoveBlockIgnoresBoundaryMoves() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                First
                Second
                """
        )

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let firstBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        XCTAssertFalse(try viewModel.moveBlockByKeyboard(blockID: firstBlockID, direction: .up))

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["First", "Second"])
        XCTAssertNil(viewModel.pendingFocusBlockID)
    }

    @MainActor
    func testInsertParagraphBlockAfterVisibleBlockKeepsFocusOnInsertedBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                First
                Second
                """
        )

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let firstBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        let insertedBlockID = try viewModel.insertParagraphBlock(after: firstBlockID)

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["First", "", "Second"])
        XCTAssertEqual(viewModel.pendingFocusBlockID, insertedBlockID)
    }

    @MainActor
    func testDeleteBlocksFromCurrentPageRemovesSelectedBlocksAndReloadsView() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                First
                Second
                Third
                """
        )

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let firstBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        let thirdBlockID = try XCTUnwrap(viewModel.visibleBlocks.last?.id)

        XCTAssertTrue(viewModel.deleteBlocksFromCurrentPage(blockIDs: [firstBlockID, thirdBlockID]))

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Second"])
    }

    @MainActor
    func testSplitTextBlockAtSelectionMovesTrailingTextIntoFocusedInsertedBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(pageID: pageID, markdown: "Alpha[Swift](https://swift.org)")

        let viewModel = WorkspaceViewModel(
            repository: repository,
            backlinkRepository: BacklinkRepository(database: database)
        )
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        let nextSelection = try viewModel.splitTextBlockAtSelection(
            blockID: blockID,
            selection: EditorTextSelection(blockID: blockID, location: 5, length: 0)
        )

        let insertedBlock = try XCTUnwrap(viewModel.visibleBlocks.dropFirst().first)
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Alpha", "[Swift](https://swift.org)"])
        XCTAssertEqual(viewModel.pendingFocusBlockID, insertedBlock.id)
        XCTAssertEqual(
            nextSelection,
            EditorTextSelection(blockID: insertedBlock.id, location: 0, length: 0)
        )
        XCTAssertEqual(
            viewModel.selectedPageExternalLinks,
            [
                ExternalLink(
                    sourcePageID: pageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: insertedBlock.id,
                    targetURL: "https://swift.org",
                    linkText: "Swift"
                )
            ]
        )
    }

    @MainActor
    func testSplitListBlockAtEndInheritsListTypeAndFocusesInsertedBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(pageID: pageID, markdown: "- 买咖啡")

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        let nextSelection = try viewModel.splitTextBlockAtSelection(
            blockID: blockID,
            selection: EditorTextSelection(blockID: blockID, location: 3, length: 0)
        )

        let insertedBlock = try XCTUnwrap(viewModel.visibleBlocks.dropFirst().first)
        XCTAssertEqual(viewModel.visibleBlocks.map(\.type), [.unorderedListItem, .unorderedListItem])
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["买咖啡", ""])
        XCTAssertEqual(viewModel.pendingFocusBlockID, insertedBlock.id)
        XCTAssertEqual(nextSelection, EditorTextSelection(blockID: insertedBlock.id, location: 0, length: 0))
    }

    @MainActor
    func testBackspaceAtStartOfEmptyIndentedBlockOutdentsInsteadOfMerging() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(pageID: pageID, markdown: "父块")
        _ = try repository.appendBlock(pageID: pageID, type: .paragraph, text: "")

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let parentBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        let childBlockID = try XCTUnwrap(viewModel.visibleBlocks.dropFirst().first?.id)
        XCTAssertTrue(try viewModel.indentBlock(blockID: childBlockID))

        let nextSelection = try viewModel.mergeTextBlockWithPreviousAtSelection(
            blockID: childBlockID,
            selection: EditorTextSelection(blockID: childBlockID, location: 0, length: 0)
        )

        XCTAssertEqual(viewModel.visibleBlocks.map(\.id), [parentBlockID, childBlockID])
        XCTAssertNil(viewModel.visibleBlocks.first { $0.id == childBlockID }?.parentBlockID)
        XCTAssertEqual(viewModel.pendingFocusBlockID, childBlockID)
        XCTAssertEqual(nextSelection, EditorTextSelection(blockID: childBlockID, location: 0, length: 0))
    }

    @MainActor
    func testBackspaceAtStartOfTypedHeadingStripsBlockTypeBeforeMerging() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(pageID: pageID, markdown: "上一个块\n\n标题文本")

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let headingBlockID = try XCTUnwrap(viewModel.visibleBlocks.dropFirst().first?.id)
        try viewModel.changeBlockType(blockID: headingBlockID, type: .heading1)

        let nextSelection = try viewModel.mergeTextBlockWithPreviousAtSelection(
            blockID: headingBlockID,
            selection: EditorTextSelection(blockID: headingBlockID, location: 0, length: 0)
        )

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["上一个块", "标题文本"])
        XCTAssertEqual(viewModel.visibleBlocks.map(\.type), [.paragraph, .paragraph])
        XCTAssertEqual(viewModel.pendingFocusBlockID, headingBlockID)
        XCTAssertEqual(nextSelection, EditorTextSelection(blockID: headingBlockID, location: 0, length: 0))
    }

    @MainActor
    func testBackspaceAtStartOfIndentedTextOutdentsBeforeMerging() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(pageID: pageID, markdown: "父块\n\n子块")

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let parentBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        let childBlockID = try XCTUnwrap(viewModel.visibleBlocks.dropFirst().first?.id)
        XCTAssertTrue(try viewModel.indentBlock(blockID: childBlockID))

        let nextSelection = try viewModel.mergeTextBlockWithPreviousAtSelection(
            blockID: childBlockID,
            selection: EditorTextSelection(blockID: childBlockID, location: 0, length: 0)
        )

        XCTAssertEqual(viewModel.visibleBlocks.map(\.id), [parentBlockID, childBlockID])
        XCTAssertNil(viewModel.visibleBlocks.first { $0.id == childBlockID }?.parentBlockID)
        XCTAssertEqual(viewModel.visibleBlocks.first { $0.id == childBlockID }?.textPlain, "子块")
        XCTAssertEqual(viewModel.pendingFocusBlockID, childBlockID)
        XCTAssertEqual(nextSelection, EditorTextSelection(blockID: childBlockID, location: 0, length: 0))
    }

    @MainActor
    func testMergeTextBlockAtStartMovesTextIntoPreviousBlockAndFocusesJoinPoint() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(pageID: pageID, markdown: "Alpha\n\n[Swift](https://swift.org)")

        let viewModel = WorkspaceViewModel(
            repository: repository,
            backlinkRepository: BacklinkRepository(database: database)
        )
        try viewModel.load()
        let firstBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        let secondBlockID = try XCTUnwrap(viewModel.visibleBlocks.dropFirst().first?.id)

        let nextSelection = try viewModel.mergeTextBlockWithPreviousAtSelection(
            blockID: secondBlockID,
            selection: EditorTextSelection(blockID: secondBlockID, location: 0, length: 0)
        )

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Alpha[Swift](https://swift.org)"])
        XCTAssertEqual(viewModel.pendingFocusBlockID, firstBlockID)
        XCTAssertEqual(
            nextSelection,
            EditorTextSelection(blockID: firstBlockID, location: 5, length: 0)
        )
        XCTAssertEqual(
            viewModel.selectedPageExternalLinks,
            [
                ExternalLink(
                    sourcePageID: pageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: firstBlockID,
                    targetURL: "https://swift.org",
                    linkText: "Swift"
                )
            ]
        )
    }

    @MainActor
    func testMergeTextBlockAtEndMovesNextTextIntoCurrentBlockAndFocusesJoinPoint() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(pageID: pageID, markdown: "Alpha\n\n[Swift](https://swift.org)")

        let viewModel = WorkspaceViewModel(
            repository: repository,
            backlinkRepository: BacklinkRepository(database: database)
        )
        try viewModel.load()
        let firstBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        let secondBlockID = try XCTUnwrap(viewModel.visibleBlocks.dropFirst().first?.id)

        let nextSelection = try viewModel.mergeTextBlockWithNextAtSelection(
            blockID: firstBlockID,
            selection: EditorTextSelection(blockID: firstBlockID, location: 5, length: 0)
        )

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Alpha[Swift](https://swift.org)"])
        XCTAssertNil(viewModel.visibleBlocks.first { $0.id == secondBlockID })
        XCTAssertEqual(viewModel.pendingFocusBlockID, firstBlockID)
        XCTAssertEqual(
            nextSelection,
            EditorTextSelection(blockID: firstBlockID, location: 5, length: 0)
        )
        XCTAssertEqual(
            viewModel.selectedPageExternalLinks,
            [
                ExternalLink(
                    sourcePageID: pageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: firstBlockID,
                    targetURL: "https://swift.org",
                    linkText: "Swift"
                )
            ]
        )
    }

    @MainActor
    func testMergeTextBlockAtStartUsesPreviousEditorVisibleBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                Toggle
                Child
                Outside
                """
        )

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let toggleBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        let childBlockID = try XCTUnwrap(viewModel.visibleBlocks.dropFirst().first?.id)
        let outsideBlockID = try XCTUnwrap(viewModel.visibleBlocks.dropFirst(2).first?.id)
        try viewModel.changeBlockType(blockID: toggleBlockID, type: .toggle)
        XCTAssertTrue(try viewModel.indentBlock(blockID: childBlockID))
        viewModel.toggleBlockExpansion(blockID: toggleBlockID)
        XCTAssertEqual(viewModel.editorVisibleBlocks.map(\.textPlain), ["Toggle", "Outside"])

        let nextSelection = try viewModel.mergeTextBlockWithPreviousAtSelection(
            blockID: outsideBlockID,
            selection: EditorTextSelection(blockID: outsideBlockID, location: 0, length: 0)
        )

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["ToggleOutside", "Child"])
        XCTAssertEqual(viewModel.editorVisibleBlocks.map(\.textPlain), ["ToggleOutside"])
        XCTAssertEqual(viewModel.pendingFocusBlockID, toggleBlockID)
        XCTAssertEqual(
            nextSelection,
            EditorTextSelection(blockID: toggleBlockID, location: 6, length: 0)
        )
    }

    @MainActor
    func testIndentVisibleBlockRefreshesParentAndKeepsFocusOnIndentedBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                First
                Second
                """
        )

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let firstBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        let secondBlockID = try XCTUnwrap(viewModel.visibleBlocks.dropFirst().first?.id)

        XCTAssertTrue(try viewModel.indentBlock(blockID: secondBlockID))

        XCTAssertEqual(viewModel.visibleBlocks.first { $0.id == secondBlockID }?.parentBlockID, firstBlockID)
        XCTAssertEqual(viewModel.pendingFocusBlockID, secondBlockID)
    }

    @MainActor
    func testChangeBlockTypeKeepsFocusOnConvertedBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.changeBlockType(blockID: blockID, type: .unorderedListItem)

        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .unorderedListItem)
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
    }

    @MainActor
    func testHashTagTextWithTrailingSpaceCreatesAndAssignsPageTag() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let tagRepository = TagRepository(database: database)
        let viewModel = WorkspaceViewModel(repository: repository, tagRepository: tagRepository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.updateBlockText(blockID: blockID, text: "开饭了 #生活 #abc")

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "开饭了 #生活 #abc")
        XCTAssertEqual(viewModel.snapshot.tags.map(\.name), ["生活"])
        XCTAssertEqual(viewModel.selectedPageTagNames, ["生活"])
        XCTAssertEqual(viewModel.snapshot.pageTags.filter { $0.pageID == pageID }.count, 1)
    }

    @MainActor
    func testHashTagTextDoesNotCreateTagUntilTrailingSpaceCommitsToken() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let tagRepository = TagRepository(database: database)
        let viewModel = WorkspaceViewModel(repository: repository, tagRepository: tagRepository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.updateBlockText(blockID: blockID, text: "开饭了 #生活")

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "开饭了 #生活")
        XCTAssertTrue(viewModel.snapshot.tags.isEmpty)
        XCTAssertTrue(viewModel.selectedPageTagNames.isEmpty)
    }

    @MainActor
    func testLoadKeepsExistingHashTagBlocksAsBodyText() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(pageID: pageID, markdown: "#abc")
        let tagRepository = TagRepository(database: database)

        let viewModel = WorkspaceViewModel(repository: repository, tagRepository: tagRepository)
        try viewModel.load()

        XCTAssertEqual(viewModel.snapshot.tags, [])
        XCTAssertEqual(viewModel.selectedPageTagNames, [])
    }

    @MainActor
    func testOutdentVisibleBlockRefreshesParentAndKeepsFocusOnOutdentedBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                First
                Second
                """
        )

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let secondBlockID = try XCTUnwrap(viewModel.visibleBlocks.dropFirst().first?.id)
        _ = try viewModel.indentBlock(blockID: secondBlockID)

        XCTAssertTrue(try viewModel.outdentBlock(blockID: secondBlockID))

        XCTAssertNil(viewModel.visibleBlocks.first { $0.id == secondBlockID }?.parentBlockID)
        XCTAssertEqual(viewModel.pendingFocusBlockID, secondBlockID)
    }

    @MainActor
    func testCollapsedToggleHidesDescendantBlocksFromEditorCanvasOnly() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                Toggle
                Child
                Outside
                """
        )

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let toggleBlockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)
        let childBlockID = try XCTUnwrap(viewModel.visibleBlocks.dropFirst().first?.id)
        try viewModel.changeBlockType(blockID: toggleBlockID, type: .toggle)
        XCTAssertTrue(try viewModel.indentBlock(blockID: childBlockID))

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Toggle", "Child", "Outside"])
        XCTAssertEqual(viewModel.editorVisibleBlocks.map(\.textPlain), ["Toggle", "Child", "Outside"])
        XCTAssertTrue(viewModel.isToggleBlockExpanded(blockID: toggleBlockID))

        viewModel.toggleBlockExpansion(blockID: toggleBlockID)

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Toggle", "Child", "Outside"])
        XCTAssertEqual(viewModel.editorVisibleBlocks.map(\.textPlain), ["Toggle", "Outside"])
        XCTAssertFalse(viewModel.isToggleBlockExpanded(blockID: toggleBlockID))
        XCTAssertEqual(viewModel.pendingFocusBlockID, toggleBlockID)

        let reloadedViewModel = WorkspaceViewModel(repository: repository)
        try reloadedViewModel.load()
        XCTAssertFalse(reloadedViewModel.isToggleBlockExpanded(blockID: toggleBlockID))
        XCTAssertEqual(reloadedViewModel.editorVisibleBlocks.map(\.textPlain), ["Toggle", "Outside"])

        viewModel.toggleBlockExpansion(blockID: toggleBlockID)

        XCTAssertEqual(viewModel.editorVisibleBlocks.map(\.textPlain), ["Toggle", "Child", "Outside"])
        XCTAssertTrue(viewModel.isToggleBlockExpanded(blockID: toggleBlockID))
    }

    @MainActor
    func testUpdateCodeBlockLineWrappingRefreshesVisibleBlockAndKeepsFocus() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let block = try repository.appendBlock(pageID: pageID, type: .codeBlock, text: "let value = 1")

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        XCTAssertTrue(viewModel.isCodeBlockLineWrappingEnabled(blockID: block.id))

        viewModel.updateCodeBlockLineWrapping(blockID: block.id, isWrapped: false)

        let reloadedBlock = try XCTUnwrap(viewModel.visibleBlocks.first { $0.id == block.id })
        XCTAssertFalse(reloadedBlock.codeBlockLineWrapping)
        XCTAssertFalse(viewModel.isCodeBlockLineWrappingEnabled(blockID: block.id))
        XCTAssertEqual(viewModel.pendingFocusBlockID, block.id)
    }

    @MainActor
    func testDeleteVisibleBlockRefreshesVisibleBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.deleteBlock(blockID: blockID)

        XCTAssertEqual(viewModel.visibleBlocks, [])
    }

    @MainActor
    func testRefreshCloudKitAccountStatusStoresVisibleStatus() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let keychainStore = KeychainMetadataStore(service: "com.liangzhang.editor.tests.\(UUID().uuidString)")
        defer {
            try? keychainStore.removeValue(for: CloudKitAccountMetadataService.accountStatusKey)
        }
        let viewModel = WorkspaceViewModel(
            repository: repository,
            cloudKitAccountMetadataService: CloudKitAccountMetadataService(
                provider: WorkspaceStaticCloudKitAccountStatusProvider(status: .available),
                metadataStore: keychainStore
            )
        )
        try viewModel.load()

        try viewModel.refreshCloudKitAccountStatus()

        XCTAssertEqual(viewModel.cloudKitAccountStatus, .available)
        XCTAssertEqual(viewModel.cloudKitAccountStatusText, "iCloud 可用")
    }

    @MainActor
    func testSyncNowUploadsPendingChangesAndUpdatesVisibleStatus() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "Sync from UI")
        let syncRepository = SyncRepository(database: database)
        let scheduler = DeferredWorkspaceSyncScheduler()

        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: syncRepository,
                adapter: RecordingCloudKitSyncAdapter()
            ),
            syncScheduler: scheduler
        )
        try viewModel.load()

        viewModel.syncNow()
        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(try syncRepository.pendingChanges(), [])
        XCTAssertEqual(viewModel.syncStatusText, "已同步 2 条变更")
    }

    @MainActor
    func testSyncAfterActivationUploadsPendingChangesWhenEngineIsAvailable() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "Foreground sync")
        let syncRepository = SyncRepository(database: database)
        let scheduler = DeferredWorkspaceSyncScheduler()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: syncRepository,
                adapter: RecordingCloudKitSyncAdapter()
            ),
            syncScheduler: scheduler
        )
        try viewModel.load()

        viewModel.syncAfterActivation()

        XCTAssertEqual(scheduler.scheduledOperationCount, 1)
        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(try syncRepository.pendingChanges(), [])
        XCTAssertEqual(viewModel.syncStatusText, "已同步 2 条变更")
    }

    @MainActor
    func testSyncAfterActivationSchedulesCloudKitAccountStatusRefreshOffMainActor() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let keychainStore = KeychainMetadataStore(service: "com.liangzhang.editor.tests.\(UUID().uuidString)")
        defer {
            try? keychainStore.removeValue(for: CloudKitAccountMetadataService.accountStatusKey)
        }
        let provider = CountingCloudKitAccountStatusProvider(status: .available)
        let accountStatusScheduler = DeferredCloudKitAccountStatusScheduler()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            cloudKitAccountMetadataService: CloudKitAccountMetadataService(
                provider: provider,
                metadataStore: keychainStore
            ),
            cloudKitAccountStatusScheduler: accountStatusScheduler
        )
        try viewModel.load()

        viewModel.syncAfterActivation()

        XCTAssertEqual(provider.callCount, 0)
        XCTAssertEqual(accountStatusScheduler.scheduledOperationCount, 1)
        XCTAssertEqual(viewModel.cloudKitAccountStatusText, "iCloud 未检查")

        try accountStatusScheduler.runNextScheduledOperation()

        XCTAssertEqual(provider.callCount, 1)
        XCTAssertEqual(viewModel.cloudKitAccountStatus, .available)
        XCTAssertEqual(viewModel.cloudKitAccountStatusText, "iCloud 可用")
    }

    @MainActor
    func testLocalSyncChangeSchedulesAutomaticForegroundSyncWithoutManualAction() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let syncRepository = SyncRepository(database: database)
        let scheduler = DeferredWorkspaceSyncScheduler()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: syncRepository,
                adapter: RecordingCloudKitSyncAdapter()
            ),
            syncScheduler: scheduler
        )
        try viewModel.load()

        try viewModel.updateBlockText(blockID: blockID, text: "Automatic sync from edit")

        XCTAssertEqual(scheduler.scheduledOperationCount, 1)
        XCTAssertEqual(try syncRepository.pendingChanges().count, 2)
        XCTAssertEqual(viewModel.syncStatusText, "同步中...")

        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(try syncRepository.pendingChanges(), [])
        XCTAssertEqual(viewModel.syncStatusText, "已同步 2 条变更")
    }

    @MainActor
    func testSyncAfterActivationEnsuresRemoteChangeSubscriptionWhenEngineIsAvailable() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let subscriptionEnsurer = RecordingCloudKitSubscriptionEnsurer()
        let scheduler = DeferredWorkspaceSyncScheduler()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: SyncRepository(database: database),
                adapter: RecordingCloudKitSyncAdapter(),
                subscriptionEnsurer: subscriptionEnsurer
            ),
            syncScheduler: scheduler
        )
        try viewModel.load()

        viewModel.syncAfterActivation()

        XCTAssertEqual(scheduler.scheduledOperationCount, 1)
        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(subscriptionEnsurer.ensureCallCount, 1)
    }

    @MainActor
    func testSyncAfterActivationSchedulesForegroundSyncWithoutRunningItInline() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "Foreground queued sync")
        let syncRepository = SyncRepository(database: database)
        let scheduler = DeferredWorkspaceSyncScheduler()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: syncRepository,
                adapter: RecordingCloudKitSyncAdapter()
            ),
            syncScheduler: scheduler
        )
        try viewModel.load()

        viewModel.syncAfterActivation()

        XCTAssertEqual(scheduler.scheduledOperationCount, 1)
        XCTAssertEqual(try syncRepository.pendingChanges().count, 2)
        XCTAssertEqual(viewModel.syncStatusText, "同步中...")

        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(try syncRepository.pendingChanges(), [])
        XCTAssertEqual(viewModel.syncStatusText, "已同步 2 条变更")
    }

    @MainActor
    func testSyncAfterActivationRecordsForegroundSyncDiagnostics() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "Foreground diagnostic sync")
        let scheduler = DeferredWorkspaceSyncScheduler()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: SyncRepository(database: database),
                adapter: RecordingCloudKitSyncAdapter()
            ),
            syncScheduler: scheduler
        )
        try viewModel.load()

        viewModel.syncAfterActivation()
        try scheduler.runNextScheduledOperation()

        let events = try RuntimeDiagnosticRepository(database: database).recentEvents(limit: 10)
        XCTAssertTrue(events.contains { event in
            event.eventName == "foreground_sync_scheduled"
                && event.payloadJSON.contains(#""reason":"activation""#)
        })
        XCTAssertTrue(events.contains { event in
            event.eventName == "foreground_sync_completed"
                && event.payloadJSON.contains(#""uploaded_count":2"#)
        })
    }

    @MainActor
    func testSyncNowSchedulesForegroundSyncWithoutRunningItInline() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "Manual queued sync")
        let syncRepository = SyncRepository(database: database)
        let scheduler = DeferredWorkspaceSyncScheduler()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: syncRepository,
                adapter: RecordingCloudKitSyncAdapter()
            ),
            syncScheduler: scheduler
        )
        try viewModel.load()

        viewModel.syncNow()

        XCTAssertEqual(scheduler.scheduledOperationCount, 1)
        XCTAssertEqual(try syncRepository.pendingChanges().count, 2)
        XCTAssertEqual(viewModel.syncStatusText, "同步中...")

        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(try syncRepository.pendingChanges(), [])
        XCTAssertEqual(viewModel.syncStatusText, "已同步 2 条变更")
    }

    @MainActor
    func testSyncAfterActivationIgnoresDuplicateRequestsWhileForegroundSyncIsRunning() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "Foreground duplicate sync")
        let scheduler = DeferredWorkspaceSyncScheduler()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: SyncRepository(database: database),
                adapter: RecordingCloudKitSyncAdapter()
            ),
            syncScheduler: scheduler
        )
        try viewModel.load()

        viewModel.syncAfterActivation()
        viewModel.syncAfterActivation()

        XCTAssertEqual(scheduler.scheduledOperationCount, 1)
    }

    @MainActor
    func testLocalSyncChangeDuringRunningSyncSchedulesFollowUpAfterCurrentRunCompletes() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let scheduler = DeferredWorkspaceSyncScheduler()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: SyncRepository(database: database),
                adapter: RecordingCloudKitSyncAdapter()
            ),
            syncScheduler: scheduler
        )
        try viewModel.load()

        viewModel.syncAfterActivation()
        try viewModel.updateBlockText(blockID: blockID, text: "Follow-up sync after in-flight edit")

        XCTAssertEqual(scheduler.scheduledOperationCount, 1)

        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(scheduler.scheduledOperationCount, 1)

        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(scheduler.scheduledOperationCount, 0)
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges(), [])
    }

    @MainActor
    func testForegroundSyncUploadsPendingLocalChangesBeforeFetchingRemoteChanges() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "Upload before fetch")
        let recorder = ForegroundSyncCallRecorder()
        let scheduler = DeferredWorkspaceSyncScheduler()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: SyncRepository(database: database),
                adapter: OrderedForegroundSyncAdapter(recorder: recorder),
                remoteChangeFetcher: OrderedForegroundSyncFetcher(recorder: recorder),
                mergeEngine: SyncMergeEngine(database: database),
                subscriptionEnsurer: OrderedForegroundSyncSubscriptionEnsurer(recorder: recorder)
            ),
            syncScheduler: scheduler
        )
        try viewModel.load()

        viewModel.syncAfterActivation()
        try scheduler.runNextScheduledOperation()

        let firstUploadIndex = try XCTUnwrap(recorder.calls.firstIndex {
            if case .upload = $0 {
                return true
            }
            return false
        })
        let fetchIndex = try XCTUnwrap(recorder.calls.firstIndex(of: .fetch))
        XCTAssertLessThan(firstUploadIndex, fetchIndex)
        XCTAssertEqual(recorder.calls.first, .ensureSubscription)
    }

    @MainActor
    func testForegroundSyncSkipsFetchWhenUploadLimitLeavesLocalBacklog() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let syncRepository = SyncRepository(database: database)
        try syncRepository.enqueue(entityType: "tag", entityID: "tag-one", changeType: "create")
        try syncRepository.enqueue(entityType: "tag", entityID: "tag-two", changeType: "create")
        let recorder = ForegroundSyncCallRecorder()
        let scheduler = DeferredWorkspaceSyncScheduler()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: syncRepository,
                adapter: OrderedForegroundSyncAdapter(recorder: recorder),
                remoteChangeFetcher: OrderedForegroundSyncFetcher(recorder: recorder),
                mergeEngine: SyncMergeEngine(database: database),
                subscriptionEnsurer: OrderedForegroundSyncSubscriptionEnsurer(recorder: recorder),
                maximumUploadsPerRun: 1
            ),
            syncScheduler: scheduler
        )
        try viewModel.load()

        viewModel.syncAfterActivation()
        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(recorder.calls, [
            .ensureSubscription,
            .upload(SyncChange(entityType: "tag", entityID: "tag-one", changeType: "create"))
        ])
        XCTAssertEqual(try syncRepository.pendingChanges(), [
            SyncChange(entityType: "tag", entityID: "tag-two", changeType: "create")
        ])
        let events = try RuntimeDiagnosticRepository(database: database).recentEvents(limit: 10)
        XCTAssertTrue(events.contains { event in
            event.eventName == "foreground_sync_fetch_skipped"
                && event.payloadJSON.contains("\"reason\":\"local_backlog\"")
        })
    }

    @MainActor
    func testForegroundSyncContinuesDrainingLocalBacklogWithoutWaitingForPollingInterval() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let syncRepository = SyncRepository(database: database)
        try syncRepository.enqueue(entityType: "tag", entityID: "tag-one", changeType: "create")
        try syncRepository.enqueue(entityType: "tag", entityID: "tag-two", changeType: "create")
        let recorder = ForegroundSyncCallRecorder()
        let scheduler = DeferredWorkspaceSyncScheduler()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: syncRepository,
                adapter: OrderedForegroundSyncAdapter(recorder: recorder),
                remoteChangeFetcher: OrderedForegroundSyncFetcher(recorder: recorder),
                mergeEngine: SyncMergeEngine(database: database),
                subscriptionEnsurer: OrderedForegroundSyncSubscriptionEnsurer(recorder: recorder),
                maximumUploadsPerRun: 1
            ),
            syncScheduler: scheduler
        )
        try viewModel.load()

        viewModel.syncAfterActivation()
        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(scheduler.scheduledOperationCount, 1)
        XCTAssertEqual(try syncRepository.pendingChanges(), [
            SyncChange(entityType: "tag", entityID: "tag-two", changeType: "create")
        ])

        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(scheduler.scheduledOperationCount, 0)
        XCTAssertEqual(try syncRepository.pendingChanges(), [])
        XCTAssertEqual(recorder.calls, [
            .ensureSubscription,
            .upload(SyncChange(entityType: "tag", entityID: "tag-one", changeType: "create")),
            .ensureSubscription,
            .upload(SyncChange(entityType: "tag", entityID: "tag-two", changeType: "create")),
            .fetch
        ])
    }

    @MainActor
    func testForegroundSyncContinuesDrainingRemoteBacklogWithoutWaitingForPollingInterval() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let recorder = ForegroundSyncCallRecorder()
        let scheduler = DeferredWorkspaceSyncScheduler()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: SyncRepository(database: database),
                adapter: OrderedForegroundSyncAdapter(recorder: recorder),
                remoteChangeFetcher: OrderedForegroundSyncFetcher(
                    recorder: recorder,
                    hasMoreChangesSequence: [true, false]
                ),
                mergeEngine: SyncMergeEngine(database: database),
                subscriptionEnsurer: OrderedForegroundSyncSubscriptionEnsurer(recorder: recorder)
            ),
            syncScheduler: scheduler
        )
        try viewModel.load()

        viewModel.syncAfterActivation()
        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(scheduler.scheduledOperationCount, 1)

        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(scheduler.scheduledOperationCount, 0)
        XCTAssertEqual(recorder.calls, [
            .ensureSubscription,
            .fetch,
            .ensureSubscription,
            .fetch
        ])
    }

    @MainActor
    func testForegroundSyncDoesNotSpinWhenOnlyDeferredLocalBacklogRemains() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let syncRepository = SyncRepository(database: database)
        let deferredChange = SyncChange(entityType: "tag", entityID: "tag-one", changeType: "create")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try syncRepository.enqueue(
            entityType: deferredChange.entityType,
            entityID: deferredChange.entityID,
            changeType: deferredChange.changeType
        )
        try syncRepository.recordFailure(
            change: deferredChange,
            errorDescription: "retry later",
            nextAttemptAt: now.addingTimeInterval(300)
        )
        let recorder = ForegroundSyncCallRecorder()
        let scheduler = DeferredWorkspaceSyncScheduler()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: syncRepository,
                adapter: OrderedForegroundSyncAdapter(recorder: recorder),
                remoteChangeFetcher: OrderedForegroundSyncFetcher(recorder: recorder),
                mergeEngine: SyncMergeEngine(database: database),
                subscriptionEnsurer: OrderedForegroundSyncSubscriptionEnsurer(recorder: recorder),
                maximumUploadsPerRun: 1,
                now: { now }
            ),
            syncScheduler: scheduler
        )
        try viewModel.load()

        viewModel.syncAfterActivation()
        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(scheduler.scheduledOperationCount, 0)
        XCTAssertEqual(try syncRepository.pendingChanges(), [deferredChange])
        XCTAssertEqual(recorder.calls, [.ensureSubscription])
        XCTAssertEqual(viewModel.syncStatusText, "同步暂缓，稍后自动重试")
    }

    @MainActor
    func testSyncAfterActivationSkipsDuringFailureCooldownAndRetriesAfterward() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let scheduler = DeferredWorkspaceSyncScheduler()
        var currentDate = Date(timeIntervalSince1970: 1_000)
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: SyncRepository(database: database),
                adapter: RecordingCloudKitSyncAdapter(),
                remoteChangeFetcher: FailingWorkspaceRemoteChangeFetcher(),
                mergeEngine: SyncMergeEngine(database: database)
            ),
            syncScheduler: scheduler,
            currentDateProvider: { currentDate }
        )
        try viewModel.load()

        viewModel.syncAfterActivation()
        XCTAssertEqual(scheduler.scheduledOperationCount, 1)
        try scheduler.runNextScheduledOperation()
        XCTAssertEqual(viewModel.syncStatusText, "同步失败")

        viewModel.syncAfterActivation()

        XCTAssertEqual(scheduler.scheduledOperationCount, 0)
        XCTAssertEqual(viewModel.syncStatusText, "同步暂缓，稍后自动重试")

        currentDate = Date(timeIntervalSince1970: 1_301)
        viewModel.syncAfterActivation()

        XCTAssertEqual(scheduler.scheduledOperationCount, 1)
    }

    @MainActor
    func testPartialForegroundUploadFailureRetriesBacklogAfterShortCooldown() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let syncRepository = SyncRepository(database: database)
        let failingChange = SyncChange(entityType: "tag", entityID: "tag-one", changeType: "create")
        let uploadedChange = SyncChange(entityType: "tag", entityID: "tag-two", changeType: "create")
        let queuedChange = SyncChange(entityType: "tag", entityID: "tag-three", changeType: "create")
        for change in [failingChange, uploadedChange, queuedChange] {
            try syncRepository.enqueue(
                entityType: change.entityType,
                entityID: change.entityID,
                changeType: change.changeType
            )
        }
        let recorder = ForegroundSyncCallRecorder()
        let scheduler = DeferredWorkspaceSyncScheduler()
        var currentDate = Date(timeIntervalSince1970: 2_000)
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: syncRepository,
                adapter: PartiallyFailingForegroundSyncAdapter(
                    recorder: recorder,
                    failingChange: failingChange
                ),
                remoteChangeFetcher: OrderedForegroundSyncFetcher(recorder: recorder),
                mergeEngine: SyncMergeEngine(database: database),
                subscriptionEnsurer: OrderedForegroundSyncSubscriptionEnsurer(recorder: recorder),
                maximumUploadsPerRun: 2,
                now: { currentDate }
            ),
            syncScheduler: scheduler,
            currentDateProvider: { currentDate }
        )
        try viewModel.load()

        viewModel.syncAfterActivation()
        try scheduler.runNextScheduledOperation()
        XCTAssertEqual(scheduler.scheduledOperationCount, 0)

        currentDate = Date(timeIntervalSince1970: 2_029)
        viewModel.syncAfterForegroundInterval()
        XCTAssertEqual(scheduler.scheduledOperationCount, 0)

        currentDate = Date(timeIntervalSince1970: 2_031)
        viewModel.syncAfterForegroundInterval()
        XCTAssertEqual(scheduler.scheduledOperationCount, 1)

        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(recorder.calls, [
            .ensureSubscription,
            .upload(failingChange),
            .upload(uploadedChange),
            .ensureSubscription,
            .upload(failingChange),
            .upload(queuedChange)
        ])
        XCTAssertEqual(try syncRepository.pendingChanges(), [failingChange])
    }

    func testForegroundSyncActivationPolicySyncsOnInitialAndLaterActivePhasesOnly() {
        let policy = ForegroundSyncActivationPolicy()

        XCTAssertTrue(policy.shouldSync(for: .active))
        XCTAssertFalse(policy.shouldSync(for: .inactive))
        XCTAssertFalse(policy.shouldSync(for: .background))
        XCTAssertTrue(policy.shouldSync(for: .active))
        XCTAssertEqual(
            ForegroundSyncActivationPolicy.foregroundPollingIntervalNanoseconds,
            30_000_000_000
        )
    }

    @MainActor
    func testSyncNowFetchesRemoteChangesAndRefreshesVisibleBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let syncRepository = SyncRepository(database: database)
        let scheduler = DeferredWorkspaceSyncScheduler()

        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: syncRepository,
                adapter: RecordingCloudKitSyncAdapter(),
                remoteChangeFetcher: StaticRemoteBlockChangeFetcher(
                    changes: [
                        RemoteBlockChange(
                            blockID: blockID,
                            pageID: pageID,
                            type: .paragraph,
                            textPlain: "Fetched into UI",
                            payloadJSON: "{\"text\":\"Fetched into UI\"}",
                            revision: 4
                        )
                    ]
                ),
                mergeEngine: SyncMergeEngine(database: database)
            ),
            syncScheduler: scheduler
        )
        try viewModel.load()

        viewModel.syncNow()
        try scheduler.runNextScheduledOperation()

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Fetched into UI")
        XCTAssertEqual(viewModel.syncStatusText, "已同步 1 条远端变更")
    }

    private func migratedDatabase() throws -> SQLiteDatabase {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        try SchemaMigrator.migrate(database: database)
        return database
    }

    private func temporaryDatabasePath() -> String {
        makeTemporaryDirectory().appendingPathComponent("editor.sqlite").path
    }

    private static var gregorianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        gregorianCalendar.date(
            from: DateComponents(
                calendar: gregorianCalendar,
                timeZone: gregorianCalendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }

    private static func isoString(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date(year: year, month: month, day: day, hour: hour, minute: minute))
    }

    private func makeSourceFile(name: String, contents: String) throws -> URL {
        let directory = makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent(name)
        try contents.data(using: .utf8)?.write(to: fileURL)
        return fileURL
    }

    private func makeSourceFile(name: String, data: Data) throws -> URL {
        let directory = makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent(name)
        try data.write(to: fileURL)
        return fileURL
    }

    private func insertPage(
        database: SQLiteDatabase,
        id: String,
        workspaceID: String,
        title: String,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            INSERT INTO pages (id, workspace_id, title, order_key, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(id),
                .text(workspaceID),
                .text(title),
                .text("000002"),
                .text(createdAt ?? now),
                .text(updatedAt ?? now)
            ]
        )
    }

    private func updatePageTimestamps(
        database: SQLiteDatabase,
        pageID: String,
        createdAt: String,
        updatedAt: String
    ) throws {
        try database.execute(
            """
            UPDATE pages
            SET created_at = ?,
                updated_at = ?
            WHERE id = ?
            """,
            bindings: [
                .text(createdAt),
                .text(updatedAt),
                .text(pageID)
            ]
        )
    }

    private func storeConflict(
        database: SQLiteDatabase,
        blockID: String,
        text: String,
        revision: Int = 2
    ) throws {
        try ConflictRepository(database: database).storeConflict(
            ConflictVersion(
                blockID: blockID,
                payloadJSON: "{\"text\":\"\(text)\"}",
                textPlain: text,
                remoteRevision: revision
            )
        )
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        temporaryFiles.append(directory)
        return directory
    }

    private static let onePixelPNGData = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
    )!
}

private struct WorkspaceStaticCloudKitAccountStatusProvider: CloudKitAccountStatusProviding {
    let status: CKAccountStatus

    func accountStatus() throws -> CKAccountStatus {
        status
    }
}

private final class CountingCloudKitAccountStatusProvider: CloudKitAccountStatusProviding {
    let status: CKAccountStatus
    private(set) var callCount = 0

    init(status: CKAccountStatus) {
        self.status = status
    }

    func accountStatus() throws -> CKAccountStatus {
        callCount += 1
        return status
    }
}

private final class RecordingEncryptedPageAuthenticator: EncryptedPageAuthenticating {
    private var results: [Bool]
    private(set) var requestCount = 0

    init(results: [Bool]) {
        self.results = results
    }

    func authenticateForEncryptedPage() async -> Bool {
        requestCount += 1
        guard !results.isEmpty else {
            return false
        }
        return results.removeFirst()
    }
}

private final class CapturingAttachmentThumbnailScheduler: AttachmentThumbnailScheduling {
    private struct ScheduledThumbnailGeneration {
        let attachmentID: String
        let generate: () throws -> String?
        let completion: @MainActor (Result<String?, Error>) -> Void
    }

    private var scheduledThumbnailGenerations: [ScheduledThumbnailGeneration] = []

    var scheduledAttachmentIDs: [String] {
        scheduledThumbnailGenerations.map(\.attachmentID)
    }

    func scheduleThumbnailGeneration(
        attachmentID: String,
        generate: @escaping @Sendable () throws -> String?,
        completion: @MainActor @escaping @Sendable (Result<String?, Error>) -> Void
    ) {
        scheduledThumbnailGenerations.append(
            ScheduledThumbnailGeneration(
                attachmentID: attachmentID,
                generate: generate,
                completion: completion
            )
        )
    }

    @MainActor
    func runScheduledThumbnailGeneration(at index: Int) throws {
        let scheduledThumbnailGeneration = scheduledThumbnailGenerations[index]
        scheduledThumbnailGeneration.completion(
            Result {
                try scheduledThumbnailGeneration.generate()
            }
        )
    }

    @MainActor
    func completeScheduledThumbnailGeneration(
        at index: Int,
        with result: Result<String?, Error>
    ) {
        scheduledThumbnailGenerations[index].completion(result)
    }
}

private final class CapturingAttachmentTextRecognitionScheduler: AttachmentTextRecognitionScheduling {
    private struct ScheduledTextRecognition {
        let attachmentID: String
        let recognize: () throws -> Void
        let completion: @MainActor (Result<Void, Error>) -> Void
    }

    private var scheduledTextRecognitions: [ScheduledTextRecognition] = []

    var scheduledAttachmentIDs: [String] {
        scheduledTextRecognitions.map(\.attachmentID)
    }

    func schedulePendingTextRecognitionLookup(
        load: @escaping @Sendable () throws -> [String],
        completion: @MainActor @escaping @Sendable (Result<[String], Error>) -> Void
    ) {
        let result = Result {
            try load()
        }
        Task { @MainActor in
            completion(result)
        }
    }

    func scheduleTextRecognition(
        attachmentID: String,
        recognize: @escaping @Sendable () throws -> Void,
        completion: @MainActor @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        scheduledTextRecognitions.append(
            ScheduledTextRecognition(
                attachmentID: attachmentID,
                recognize: recognize,
                completion: completion
            )
        )
    }

    @MainActor
    func runScheduledTextRecognition(at index: Int) throws {
        let scheduledTextRecognition = scheduledTextRecognitions[index]
        scheduledTextRecognition.completion(
            Result {
                try scheduledTextRecognition.recognize()
            }
        )
    }
}

private struct StaticImageTextRecognizer: ImageTextRecognizing {
    let observations: [AttachmentRecognizedTextObservation]

    func recognizeText(in imageURL: URL) throws -> [AttachmentRecognizedTextObservation] {
        observations
    }
}

private final class RecordingObsidianVaultImporter: ObsidianVaultImporting, @unchecked Sendable {
    private let summary: ObsidianVaultImportSummary
    private(set) var importedVaultURLs: [URL] = []

    init(summary: ObsidianVaultImportSummary) {
        self.summary = summary
    }

    func importVault(vaultURL: URL, workspaceID: String) throws -> ObsidianVaultImportSummary {
        importedVaultURLs.append(vaultURL)
        return summary
    }
}

private final class DeferredObsidianImportScheduler: WorkspaceObsidianImportScheduling {
    private struct ScheduledImport {
        let operation: @Sendable () -> WorkspaceObsidianImportResult
        let completion: @MainActor @Sendable (WorkspaceObsidianImportResult) -> Void
    }

    private var scheduledImports: [ScheduledImport] = []

    var scheduledOperationCount: Int {
        scheduledImports.count
    }

    func scheduleObsidianImport(
        operation: @escaping @Sendable () -> WorkspaceObsidianImportResult,
        completion: @escaping @MainActor @Sendable (WorkspaceObsidianImportResult) -> Void
    ) {
        scheduledImports.append(
            ScheduledImport(
                operation: operation,
                completion: completion
            )
        )
    }

    @MainActor
    func runNextScheduledOperation() throws {
        guard !scheduledImports.isEmpty else {
            throw WorkspaceViewModelTestError.noScheduledForegroundSync
        }
        let scheduledImport = scheduledImports.removeFirst()
        scheduledImport.completion(scheduledImport.operation())
    }
}

private final class DeferredWorkspaceSyncScheduler: WorkspaceSyncScheduling {
    private struct ScheduledForegroundSync {
        let operation: @Sendable () -> WorkspaceForegroundSyncResult
        let completion: @MainActor @Sendable (WorkspaceForegroundSyncResult) -> Void
    }

    private var scheduledForegroundSyncs: [ScheduledForegroundSync] = []

    var scheduledOperationCount: Int {
        scheduledForegroundSyncs.count
    }

    func scheduleForegroundSync(
        operation: @escaping @Sendable () -> WorkspaceForegroundSyncResult,
        completion: @escaping @MainActor @Sendable (WorkspaceForegroundSyncResult) -> Void
    ) {
        scheduledForegroundSyncs.append(
            ScheduledForegroundSync(
                operation: operation,
                completion: completion
            )
        )
    }

    @MainActor
    func runNextScheduledOperation() throws {
        guard !scheduledForegroundSyncs.isEmpty else {
            throw WorkspaceViewModelTestError.noScheduledForegroundSync
        }

        let scheduledForegroundSync = scheduledForegroundSyncs.removeFirst()
        scheduledForegroundSync.completion(scheduledForegroundSync.operation())
    }
}

private final class DeferredCloudKitAccountStatusScheduler: CloudKitAccountStatusScheduling {
    private struct ScheduledAccountStatusRefresh {
        let operation: @Sendable () -> WorkspaceCloudKitAccountStatusRefreshResult
        let completion: @MainActor @Sendable (WorkspaceCloudKitAccountStatusRefreshResult) -> Void
    }

    private var scheduledAccountStatusRefreshes: [ScheduledAccountStatusRefresh] = []

    var scheduledOperationCount: Int {
        scheduledAccountStatusRefreshes.count
    }

    func scheduleAccountStatusRefresh(
        operation: @escaping @Sendable () -> WorkspaceCloudKitAccountStatusRefreshResult,
        completion: @escaping @MainActor @Sendable (WorkspaceCloudKitAccountStatusRefreshResult) -> Void
    ) {
        scheduledAccountStatusRefreshes.append(
            ScheduledAccountStatusRefresh(
                operation: operation,
                completion: completion
            )
        )
    }

    @MainActor
    func runNextScheduledOperation() throws {
        guard !scheduledAccountStatusRefreshes.isEmpty else {
            throw WorkspaceViewModelTestError.noScheduledForegroundSync
        }

        let scheduledRefresh = scheduledAccountStatusRefreshes.removeFirst()
        scheduledRefresh.completion(scheduledRefresh.operation())
    }
}

private enum ForegroundSyncCall: Equatable {
    case ensureSubscription
    case upload(SyncChange)
    case fetch
}

private final class ForegroundSyncCallRecorder: @unchecked Sendable {
    private(set) var calls: [ForegroundSyncCall] = []

    func record(_ call: ForegroundSyncCall) {
        calls.append(call)
    }
}

private final class OrderedForegroundSyncAdapter: CloudKitSyncAdapter {
    private let recorder: ForegroundSyncCallRecorder

    init(recorder: ForegroundSyncCallRecorder) {
        self.recorder = recorder
    }

    func upload(change: SyncChange) throws -> CloudKitUploadResult {
        recorder.record(.upload(change))
        return CloudKitUploadResult(
            recordName: "\(change.entityType)-\(change.entityID)",
            changeTag: "tag-\(change.entityID)"
        )
    }
}

private final class PartiallyFailingForegroundSyncAdapter: CloudKitSyncAdapter {
    private let recorder: ForegroundSyncCallRecorder
    private let failingChange: SyncChange

    init(recorder: ForegroundSyncCallRecorder, failingChange: SyncChange) {
        self.recorder = recorder
        self.failingChange = failingChange
    }

    func upload(change: SyncChange) throws -> CloudKitUploadResult {
        recorder.record(.upload(change))
        if change == failingChange {
            throw WorkspaceViewModelTestError.uploadFailed
        }
        return CloudKitUploadResult(
            recordName: "\(change.entityType)-\(change.entityID)",
            changeTag: "tag-\(change.entityID)"
        )
    }
}

private final class OrderedForegroundSyncFetcher: CloudKitRemoteChangeFetching {
    private let recorder: ForegroundSyncCallRecorder
    private var hasMoreChangesSequence: [Bool]

    init(recorder: ForegroundSyncCallRecorder, hasMoreChangesSequence: [Bool] = [false]) {
        self.recorder = recorder
        self.hasMoreChangesSequence = hasMoreChangesSequence
    }

    func fetchRemoteChanges(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitRemoteChangeSet {
        recorder.record(.fetch)
        let hasMoreChanges = hasMoreChangesSequence.isEmpty
            ? false
            : hasMoreChangesSequence.removeFirst()
        return CloudKitRemoteChangeSet(
            workspaceChanges: [],
            notebookChanges: [],
            pageChanges: [],
            diaryPageChanges: [],
            attachmentChanges: [],
            blockChanges: [],
            fullSnapshotPageIDs: [],
            deletedRecords: [],
            serverChangeTokenData: nil,
            hasMoreChanges: hasMoreChanges
        )
    }
}

private final class OrderedForegroundSyncSubscriptionEnsurer: CloudKitSubscriptionEnsuring {
    private let recorder: ForegroundSyncCallRecorder

    init(recorder: ForegroundSyncCallRecorder) {
        self.recorder = recorder
    }

    func ensureRemoteChangeSubscription() throws {
        recorder.record(.ensureSubscription)
    }
}

private struct FailingWorkspaceRemoteChangeFetcher: CloudKitRemoteChangeFetching {
    func fetchRemoteChanges(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitRemoteChangeSet {
        throw WorkspaceViewModelTestError.remoteFetchFailed
    }
}

private enum WorkspaceViewModelTestError: Error, CustomStringConvertible {
    case thumbnailGenerationFailed
    case noScheduledForegroundSync
    case remoteFetchFailed
    case uploadFailed

    var description: String {
        switch self {
        case .thumbnailGenerationFailed:
            return "thumbnailGenerationFailed"
        case .noScheduledForegroundSync:
            return "noScheduledForegroundSync"
        case .remoteFetchFailed:
            return "remoteFetchFailed"
        case .uploadFailed:
            return "uploadFailed"
        }
    }
}
