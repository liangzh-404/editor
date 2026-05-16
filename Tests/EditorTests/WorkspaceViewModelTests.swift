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
    func testLoadStartsInDiaryModeWithActiveDiaryEntry() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            diaryRepository: DiaryRepository(database: database)
        )

        try viewModel.load()

        XCTAssertEqual(viewModel.selectedCollection, .diary)
        XCTAssertNotNil(viewModel.activeDiaryEntry)
        XCTAssertNil(viewModel.selectedPageID)
    }

    @MainActor
    func testPromoteSelectedDiaryTextSelectsNewPageAndShowsAllDocuments() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let viewModel = WorkspaceViewModel(
            repository: repository,
            diaryRepository: DiaryRepository(database: database)
        )
        try viewModel.load()
        try viewModel.updateDiaryText("Promote me now")

        try viewModel.promoteSelectedDiaryTextToPage("Promote me")

        XCTAssertEqual(viewModel.selectedCollection, .allDocuments)
        XCTAssertEqual(viewModel.selectedPage?.title, "Promote me")
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Promote me"])
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

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Start writing in blocks.")
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

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Start writing in blocks.")
        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .paragraph)
        XCTAssertFalse(viewModel.canUndoTextEdit)
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
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

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        XCTAssertEqual(reloadedSnapshot.blocks.first?.type, .heading1)
        XCTAssertEqual(reloadedSnapshot.blocks.first?.textPlain, "")
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
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Start writing in blocks.")
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
                    sourcePageTitle: "Welcome",
                    sourceBlockID: blockID,
                    targetPageID: targetPage.id,
                    targetBlockID: nil,
                    linkText: "Specs"
                )
            ]
        )
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

        let createdPage = try viewModel.createPageInSelectedWorkspace(title: "Untitled")

        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["Untitled", "Welcome"])
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

        XCTAssertEqual(viewModel.snapshot.notebooks.map(\.name), ["Notebook", "Projects", "Client A", "Areas"])
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

        XCTAssertEqual(viewModel.snapshot.notebooks.map(\.name), ["Areas", "Notebook", "Projects"])
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

        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["Welcome"])
        XCTAssertEqual(viewModel.selectedPage?.title, "Welcome")
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Start writing in blocks."])
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
        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["Current", "Welcome"])
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
        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["Scratch", "Current", "Welcome"])
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

        XCTAssertEqual(viewModel.selectedPage?.title, "Welcome")
        XCTAssertTrue(viewModel.canUndoPageArchive)

        try viewModel.undoLastPageArchive()

        XCTAssertEqual(viewModel.snapshot.archivedPages, [])
        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["Scratch", "Welcome"])
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
        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["Scratch", "Welcome"])
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
        XCTAssertEqual(viewModel.snapshot.pages.map(\.title), ["Welcome"])
        XCTAssertEqual(viewModel.selectedPage?.title, "Welcome")
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
            Start writing in blocks.

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
        let markdownURL = exportDirectory.appendingPathComponent("Welcome.md")

        try viewModel.exportCurrentPageMarkdownPackage(to: markdownURL)

        XCTAssertEqual(
            try String(contentsOf: markdownURL, encoding: .utf8),
            """
            Start writing in blocks.

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
                    sourcePageTitle: "Welcome",
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
            "Start writing in blocks. [Swift](https://swift.org)"
        )
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
        XCTAssertEqual(
            viewModel.selectedPageExternalLinks,
            [
                ExternalLink(
                    sourcePageID: pageID,
                    sourcePageTitle: "Welcome",
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
                selection: EditorTextSelection(blockID: blockID, location: 6, length: 7)
            )
        )

        XCTAssertEqual(
            viewModel.visibleBlocks.first?.textPlain,
            "Start [Swift](https://swift.org) in blocks."
        )
        XCTAssertEqual(nextSelection, EditorTextSelection(blockID: blockID, location: 7, length: 5))
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
        XCTAssertEqual(
            viewModel.selectedPageExternalLinks,
            [
                ExternalLink(
                    sourcePageID: pageID,
                    sourcePageTitle: "Welcome",
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
                    sourcePageTitle: "Welcome",
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
                selection: EditorTextSelection(blockID: blockID, location: 6, length: 7)
            )
        )

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Start **writing** in blocks.")
        XCTAssertEqual(nextSelection, EditorTextSelection(blockID: blockID, location: 8, length: 7))
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
        XCTAssertTrue(viewModel.canUndoTextEdit)

        try viewModel.undoLastTextEdit()
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Start writing in blocks.")
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
                selection: EditorTextSelection(blockID: blockID, location: 6, length: 7)
            )
        )

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Start *writing* in blocks.")
        XCTAssertEqual(nextSelection, EditorTextSelection(blockID: blockID, location: 7, length: 7))
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
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Start writing in blocks.")
        XCTAssertFalse(viewModel.canUndoTextEdit)
    }

    @MainActor
    func testSelectedPageConflictsRefreshAndAcceptRemoteVersion() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "Local edit")
        try SyncMergeEngine(database: database).applyRemoteBlock(
            RemoteBlockChange(
                blockID: blockID,
                pageID: pageID,
                type: .paragraph,
                textPlain: "Remote edit",
                payloadJSON: "{\"text\":\"Remote edit\"}",
                revision: 2
            )
        )

        let viewModel = WorkspaceViewModel(
            repository: repository,
            conflictRepository: ConflictRepository(database: database)
        )
        try viewModel.load()
        let conflict = try XCTUnwrap(viewModel.selectedPageConflicts.first)

        try viewModel.acceptRemoteConflict(id: conflict.id)

        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "Remote edit")
        XCTAssertEqual(viewModel.selectedPageConflicts, [])
        XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
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
        try SyncMergeEngine(database: database).applyRemoteBlock(
            RemoteBlockChange(
                blockID: firstBlockID,
                pageID: pageID,
                type: .paragraph,
                textPlain: "Remote one",
                payloadJSON: "{\"text\":\"Remote one\"}",
                revision: 2
            )
        )
        try SyncMergeEngine(database: database).applyRemoteBlock(
            RemoteBlockChange(
                blockID: secondBlock.id,
                pageID: pageID,
                type: .paragraph,
                textPlain: "Remote two",
                payloadJSON: "{\"text\":\"Remote two\"}",
                revision: 2
            )
        )

        let viewModel = WorkspaceViewModel(
            repository: repository,
            conflictRepository: ConflictRepository(database: database)
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
        try SyncMergeEngine(database: database).applyRemoteBlock(
            RemoteBlockChange(
                blockID: firstBlockID,
                pageID: pageID,
                type: .paragraph,
                textPlain: "Remote one",
                payloadJSON: "{\"text\":\"Remote one\"}",
                revision: 2
            )
        )
        try SyncMergeEngine(database: database).applyRemoteBlock(
            RemoteBlockChange(
                blockID: secondBlock.id,
                pageID: pageID,
                type: .paragraph,
                textPlain: "Remote two",
                payloadJSON: "{\"text\":\"Remote two\"}",
                revision: 2
            )
        )

        let viewModel = WorkspaceViewModel(
            repository: repository,
            conflictRepository: ConflictRepository(database: database)
        )
        try viewModel.load()
        XCTAssertEqual(viewModel.selectedPageConflicts.count, 2)

        try viewModel.acceptAllLocalConflictsForSelectedPage()

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Local one", "Local two"])
        XCTAssertEqual(viewModel.selectedPageConflicts, [])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().filter { $0.changeType == "update" }.count,
            2
        )
        XCTAssertEqual(viewModel.pendingFocusBlockID, firstBlockID)
    }

    @MainActor
    func testManualConflictMergeRefreshesBlockAndKeepsPendingSync() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "Local edit")
        try SyncMergeEngine(database: database).applyRemoteBlock(
            RemoteBlockChange(
                blockID: blockID,
                pageID: pageID,
                type: .paragraph,
                textPlain: "Remote edit",
                payloadJSON: "{\"text\":\"Remote edit\"}",
                revision: 2
            )
        )

        let viewModel = WorkspaceViewModel(
            repository: repository,
            conflictRepository: ConflictRepository(database: database)
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
        try SyncMergeEngine(database: database).applyRemoteBlock(
            RemoteBlockChange(
                blockID: firstBlockID,
                pageID: pageID,
                type: .paragraph,
                textPlain: "Remote one",
                payloadJSON: "{\"text\":\"Remote one\"}",
                revision: 2
            )
        )
        try SyncMergeEngine(database: database).applyRemoteBlock(
            RemoteBlockChange(
                blockID: secondBlock.id,
                pageID: pageID,
                type: .paragraph,
                textPlain: "Remote two",
                payloadJSON: "{\"text\":\"Remote two\"}",
                revision: 2
            )
        )

        let viewModel = WorkspaceViewModel(
            repository: repository,
            conflictRepository: ConflictRepository(database: database)
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
            2
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
                    sourcePageTitle: "Welcome",
                    sourceBlockID: insertedBlock.id,
                    targetURL: "https://swift.org",
                    linkText: "Swift"
                )
            ]
        )
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
                    sourcePageTitle: "Welcome",
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
                    sourcePageTitle: "Welcome",
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

private enum WorkspaceViewModelTestError: Error, CustomStringConvertible {
    case thumbnailGenerationFailed

    var description: String {
        switch self {
        case .thumbnailGenerationFailed:
            return "thumbnailGenerationFailed"
        }
    }
}
