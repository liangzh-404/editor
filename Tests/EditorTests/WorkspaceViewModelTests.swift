import Foundation
import CloudKit
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
        XCTAssertEqual(viewModel.selectedPage?.title, "Welcome")
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Start writing in blocks."])
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
            attachmentRepository: attachmentRepository
        )
        try viewModel.load()
        try viewModel.importAttachment(sourceURL: sourceURL)

        XCTAssertEqual(viewModel.visibleBlocks.last?.type, .attachmentImage)
        XCTAssertEqual(viewModel.snapshot.attachments.map(\.originalFilename), ["screen.png"])
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

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        XCTAssertEqual(reloadedSnapshot.blocks.first?.type, .heading1)
        XCTAssertEqual(reloadedSnapshot.blocks.first?.textPlain, "")
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
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Start writing in blocks.")
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "block", entityID: blockID, changeType: "update")
        )
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
    func testCreatePageSelectsNewEmptyPage() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        let createdPage = try viewModel.createPageInSelectedWorkspace(title: "Untitled")

        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["Welcome", "Untitled"])
        XCTAssertEqual(viewModel.selectedPageID, createdPage.id)
        XCTAssertEqual(viewModel.selectedPage?.title, "Untitled")
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

        XCTAssertEqual(viewModel.snapshot.notebooks.map(\.name), ["Notebook", "Projects"])
        XCTAssertEqual(viewModel.snapshot.notebooks.last, notebook)
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

        XCTAssertEqual(viewModel.snapshot.notebooks.map(\.name), ["Areas", "Notebook", "Projects"])
        XCTAssertEqual(viewModel.selectedNotebookID, areas.id)
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

        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["Welcome"])
        XCTAssertEqual(viewModel.selectedPage?.title, "Welcome")
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Start writing in blocks."])
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
        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["Welcome", "Scratch"])
        XCTAssertEqual(viewModel.selectedPageID, page.id)
        XCTAssertEqual(viewModel.selectedPage?.title, "Scratch")
    }

    @MainActor
    func testCreatePageRequestsFocusForInitialEmptyBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        _ = try viewModel.createPageInSelectedWorkspace(title: "Untitled")
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
    func testSelectSearchResultNavigatesToDestinationPage() throws {
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

        try viewModel.updateBlockText(blockID: blockID, text: "See [[Welcome]]")

        XCTAssertEqual(
            viewModel.selectedPageBacklinks,
            [
                Backlink(
                    sourcePageID: pageID,
                    sourcePageTitle: "Welcome",
                    sourceBlockID: blockID,
                    targetPageID: pageID,
                    targetBlockID: nil,
                    linkText: "Welcome"
                )
            ]
        )
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
                sourcePageTitle: "Welcome",
                sourceBlockID: snapshot.blocks.first?.id,
                targetPageID: secondPageID,
                targetBlockID: nil,
                linkText: "Second"
            )
        )

        XCTAssertEqual(viewModel.selectedPageID, snapshot.selectedPageID)
        XCTAssertEqual(viewModel.selectedPage?.title, "Welcome")
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
        XCTAssertEqual(viewModel.cloudKitAccountStatusText, "iCloud Available")
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

        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: syncRepository,
                adapter: RecordingCloudKitSyncAdapter()
            )
        )
        try viewModel.load()

        viewModel.syncNow()

        XCTAssertEqual(try syncRepository.pendingChanges(), [])
        XCTAssertEqual(viewModel.syncStatusText, "Synced 1 change")
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
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: syncRepository,
                adapter: RecordingCloudKitSyncAdapter()
            )
        )
        try viewModel.load()

        viewModel.syncAfterActivation()

        XCTAssertEqual(try syncRepository.pendingChanges(), [])
        XCTAssertEqual(viewModel.syncStatusText, "Synced 1 change")
    }

    @MainActor
    func testSyncAfterActivationEnsuresRemoteChangeSubscriptionWhenEngineIsAvailable() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let subscriptionEnsurer = RecordingCloudKitSubscriptionEnsurer()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            syncEngine: SyncEngine(
                syncRepository: SyncRepository(database: database),
                adapter: RecordingCloudKitSyncAdapter(),
                subscriptionEnsurer: subscriptionEnsurer
            )
        )
        try viewModel.load()

        viewModel.syncAfterActivation()

        XCTAssertEqual(subscriptionEnsurer.ensureCallCount, 1)
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
            )
        )
        try viewModel.load()

        viewModel.syncNow()

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Fetched into UI")
        XCTAssertEqual(viewModel.syncStatusText, "Synced 1 remote change")
    }

    private func migratedDatabase() throws -> SQLiteDatabase {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        try SchemaMigrator.migrate(database: database)
        return database
    }

    private func temporaryDatabasePath() -> String {
        makeTemporaryDirectory().appendingPathComponent("editor.sqlite").path
    }

    private func makeSourceFile(name: String, contents: String) throws -> URL {
        let directory = makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent(name)
        try contents.data(using: .utf8)?.write(to: fileURL)
        return fileURL
    }

    private func insertPage(
        database: SQLiteDatabase,
        id: String,
        workspaceID: String,
        title: String
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
                .text(now),
                .text(now)
            ]
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
}

private struct WorkspaceStaticCloudKitAccountStatusProvider: CloudKitAccountStatusProviding {
    let status: CKAccountStatus

    func accountStatus() throws -> CKAccountStatus {
        status
    }
}
