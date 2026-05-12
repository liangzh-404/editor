import Foundation
import XCTest

final class PageRepositoryTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testBootstrapCreatesDefaultWorkspacePageAndParagraphBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()

        XCTAssertEqual(snapshot.workspaces.map(\.name), ["Local"])
        XCTAssertEqual(snapshot.notebooks.map(\.name), ["Notebook"])
        XCTAssertEqual(snapshot.pages.map(\.title), ["Welcome"])
        XCTAssertEqual(snapshot.pages.first?.notebookID, snapshot.notebooks.first?.id)
        XCTAssertEqual(snapshot.blocks.count, 1)
        XCTAssertEqual(snapshot.blocks.first?.type, .paragraph)
        XCTAssertEqual(snapshot.blocks.first?.textPlain, "Start writing in blocks.")
        XCTAssertEqual(snapshot.selectedWorkspaceID, snapshot.workspaces.first?.id)
        XCTAssertEqual(snapshot.selectedPageID, snapshot.pages.first?.id)
    }

    func testBootstrapIsIdempotent() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let snapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(snapshot.workspaces.count, 1)
        XCTAssertEqual(snapshot.pages.count, 1)
        XCTAssertEqual(snapshot.blocks.count, 1)
    }

    func testUpdateBlockTextPersistsParagraphContent() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(initialSnapshot.blocks.first?.id)

        try repository.updateBlockText(blockID: blockID, text: "Edited locally")
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.blocks.first?.textPlain, "Edited locally")
    }

    func testUpdatePageTitlePersistsAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(initialSnapshot.selectedPageID)

        try repository.updatePageTitle(pageID: pageID, title: "Editable Title")
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.pages.first?.title, "Editable Title")
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges().last?.entityType, "page")
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges().last?.entityID, pageID)
    }

    func testCreatePagePersistsEmptyEditablePageAtEnd() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)

        let createdPage = try repository.createPage(workspaceID: workspaceID, title: "Untitled")
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        let createdBlocks = reloadedSnapshot.blocks.filter { $0.pageID == createdPage.id }

        XCTAssertEqual(reloadedSnapshot.pages.map(\.title), ["Welcome", "Untitled"])
        XCTAssertEqual(reloadedSnapshot.pages.last?.id, createdPage.id)
        XCTAssertEqual(createdBlocks.map(\.type), [.paragraph])
        XCTAssertEqual(createdBlocks.map(\.textPlain), [""])
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges().suffix(2).map(\.entityType), ["page", "block"])
    }

    func testCreateNotebookAndPageInNotebookPersistsGrouping() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)

        let notebook = try repository.createNotebook(workspaceID: workspaceID, name: "Projects")
        let page = try repository.createPage(
            workspaceID: workspaceID,
            title: "Roadmap",
            notebookID: notebook.id
        )
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertTrue(reloadedSnapshot.notebooks.contains(notebook))
        XCTAssertEqual(reloadedSnapshot.pages.first { $0.id == page.id }?.notebookID, notebook.id)
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges().suffix(3).map(\.entityType), ["notebook", "page", "block"])
    }

    func testCreateNestedNotebookPersistsParentNotebook() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)

        let parent = try repository.createNotebook(workspaceID: workspaceID, name: "Projects")
        let child = try repository.createNotebook(
            workspaceID: workspaceID,
            name: "Client A",
            parentNotebookID: parent.id
        )
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(child.parentNotebookID, parent.id)
        XCTAssertEqual(
            reloadedSnapshot.notebooks.first { $0.id == child.id }?.parentNotebookID,
            parent.id
        )
    }

    func testLoadWorkspaceSnapshotOrdersNestedNotebooksDepthFirst() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)

        let projects = try repository.createNotebook(workspaceID: workspaceID, name: "Projects")
        _ = try repository.createNotebook(workspaceID: workspaceID, name: "Areas")
        _ = try repository.createNotebook(
            workspaceID: workspaceID,
            name: "Client A",
            parentNotebookID: projects.id
        )

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(
            reloadedSnapshot.notebooks.map(\.name),
            ["Notebook", "Projects", "Client A", "Areas"]
        )
    }

    func testUpdateNotebookParentPersistsAndPreventsCycles() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let parent = try repository.createNotebook(workspaceID: workspaceID, name: "Projects")
        let child = try repository.createNotebook(workspaceID: workspaceID, name: "Client A")

        try repository.updateNotebookParent(notebookID: child.id, parentNotebookID: parent.id)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(
            reloadedSnapshot.notebooks.first { $0.id == child.id }?.parentNotebookID,
            parent.id
        )
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "notebook", entityID: child.id, changeType: "update")
        )
        XCTAssertThrowsError(
            try repository.updateNotebookParent(notebookID: parent.id, parentNotebookID: child.id)
        )
    }

    func testUpdateNotebookNamePersistsAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let notebookID = try XCTUnwrap(initialSnapshot.selectedNotebookID)

        try repository.updateNotebookName(notebookID: notebookID, name: "Projects")
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.notebooks.first?.name, "Projects")
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "notebook", entityID: notebookID, changeType: "update")
        )
    }

    func testMoveNotebookPersistsStableOrderAndQueuesSyncChanges() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        _ = try repository.createNotebook(workspaceID: workspaceID, name: "Projects")
        let areas = try repository.createNotebook(workspaceID: workspaceID, name: "Areas")

        try repository.moveNotebook(notebookID: areas.id, toIndex: 0)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.notebooks.map(\.name), ["Areas", "Notebook", "Projects"])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().suffix(3).map(\.entityType),
            ["notebook", "notebook", "notebook"]
        )
    }

    func testArchivePageHidesItAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let createdPage = try repository.createPage(workspaceID: workspaceID, title: "Scratch")

        try repository.archivePage(pageID: createdPage.id)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.pages.map(\.title), ["Welcome"])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "page", entityID: createdPage.id, changeType: "archive")
        )
    }

    func testRestoreArchivedPageMakesItVisibleAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let createdPage = try repository.createPage(workspaceID: workspaceID, title: "Scratch")
        try repository.archivePage(pageID: createdPage.id)

        let archivedSnapshot = try repository.loadWorkspaceSnapshot()
        XCTAssertEqual(archivedSnapshot.pages.map(\.title), ["Welcome"])
        XCTAssertEqual(archivedSnapshot.archivedPages.map(\.title), ["Scratch"])

        try repository.restorePage(pageID: createdPage.id)
        let restoredSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(restoredSnapshot.pages.map(\.title), ["Welcome", "Scratch"])
        XCTAssertEqual(restoredSnapshot.archivedPages, [])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "page", entityID: createdPage.id, changeType: "restore")
        )
    }

    func testPermanentlyDeleteArchivedPageRemovesItAndQueuesDeleteTombstone() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let createdPage = try repository.createPage(workspaceID: workspaceID, title: "Scratch")
        try repository.archivePage(pageID: createdPage.id)

        try repository.permanentlyDeleteArchivedPage(pageID: createdPage.id)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.pages.map(\.title), ["Welcome"])
        XCTAssertEqual(reloadedSnapshot.archivedPages, [])
        XCTAssertEqual(
            try database.queryInt("SELECT COUNT(*) FROM blocks WHERE page_id = '\(createdPage.id)'"),
            0
        )
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "page", entityID: createdPage.id, changeType: "delete")
        )
    }

    func testImportMarkdownReplacesPageBlocksWithTypedBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)

        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                # Imported

                Body

                - Item
                """
        )
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.blocks.map(\.type), [.heading1, .paragraph, .unorderedListItem])
        XCTAssertEqual(reloadedSnapshot.blocks.map(\.textPlain), ["Imported", "Body", "Item"])
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges().map(\.entityType), ["block", "block", "block"])
    }

    func testImportMarkdownPersistsTaskItemCompletionState() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)

        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                - [x] Done
                - [ ] Todo
                """
        )

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.blocks.map(\.type), [.taskItem, .taskItem])
        XCTAssertEqual(reloadedSnapshot.blocks.map(\.textPlain), ["Done", "Todo"])
        XCTAssertEqual(reloadedSnapshot.blocks.map(\.taskItemIsCompleted), [true, false])
    }

    func testUpdateTaskItemCompletionPersistsAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let block = try repository.appendBlock(pageID: pageID, type: .taskItem, text: "Ship")

        try repository.updateTaskItemCompletion(blockID: block.id, isCompleted: true)

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        let reloadedBlock = try XCTUnwrap(reloadedSnapshot.blocks.first { $0.id == block.id })

        XCTAssertEqual(reloadedBlock.type, .taskItem)
        XCTAssertEqual(reloadedBlock.textPlain, "Ship")
        XCTAssertTrue(reloadedBlock.taskItemIsCompleted)
        XCTAssertTrue(
            try SyncRepository(database: database).pendingChanges().contains(
                SyncChange(entityType: "block", entityID: block.id, changeType: "update")
            )
        )
    }

    func testUpdateToggleExpansionPersistsAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let block = try repository.appendBlock(pageID: pageID, type: .toggle, text: "Details")

        try repository.updateToggleExpansion(blockID: block.id, isExpanded: false)

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        let reloadedBlock = try XCTUnwrap(reloadedSnapshot.blocks.first { $0.id == block.id })

        XCTAssertEqual(reloadedBlock.type, .toggle)
        XCTAssertEqual(reloadedBlock.textPlain, "Details")
        XCTAssertFalse(reloadedBlock.toggleIsExpanded)
        XCTAssertTrue(
            try SyncRepository(database: database).pendingChanges().contains(
                SyncChange(entityType: "block", entityID: block.id, changeType: "update")
            )
        )
    }

    func testUpdateCodeBlockLineWrappingPersistsAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let block = try repository.appendBlock(pageID: pageID, type: .codeBlock, text: "let value = 1")

        try repository.updateCodeBlockLineWrapping(blockID: block.id, isWrapped: false)

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        let reloadedBlock = try XCTUnwrap(reloadedSnapshot.blocks.first { $0.id == block.id })

        XCTAssertEqual(reloadedBlock.type, .codeBlock)
        XCTAssertEqual(reloadedBlock.textPlain, "let value = 1")
        XCTAssertFalse(reloadedBlock.codeBlockLineWrapping)
        XCTAssertTrue(
            try SyncRepository(database: database).pendingChanges().contains(
                SyncChange(entityType: "block", entityID: block.id, changeType: "update")
            )
        )
    }

    func testMoveBlockPersistsStableOrder() throws {
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
        let importedSnapshot = try repository.loadWorkspaceSnapshot()
        let thirdBlockID = try XCTUnwrap(importedSnapshot.blocks.last?.id)

        try repository.moveBlock(blockID: thirdBlockID, toIndex: 0)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.blocks.map(\.textPlain), ["Third", "First", "Second"])
        XCTAssertEqual(reloadedSnapshot.blocks.map(\.orderKey), ["000001", "000002", "000003"])
    }

    func testIndentBlockNestsUnderPreviousSiblingAndQueuesSync() throws {
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
        let importedSnapshot = try repository.loadWorkspaceSnapshot()
        let firstBlockID = try XCTUnwrap(importedSnapshot.blocks.first?.id)
        let secondBlockID = try XCTUnwrap(importedSnapshot.blocks.dropFirst().first?.id)

        XCTAssertTrue(try repository.indentBlock(blockID: secondBlockID))
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.blocks.first { $0.id == secondBlockID }?.parentBlockID, firstBlockID)
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "block", entityID: secondBlockID, changeType: "update")
        )
    }

    func testOutdentBlockRestoresParentAndQueuesSync() throws {
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
        let importedSnapshot = try repository.loadWorkspaceSnapshot()
        let secondBlockID = try XCTUnwrap(importedSnapshot.blocks.dropFirst().first?.id)
        _ = try repository.indentBlock(blockID: secondBlockID)

        XCTAssertTrue(try repository.outdentBlock(blockID: secondBlockID))
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertNil(reloadedSnapshot.blocks.first { $0.id == secondBlockID }?.parentBlockID)
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "block", entityID: secondBlockID, changeType: "update")
        )
    }

    func testAppendParagraphBlockPersistsAtEnd() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)

        let appendedBlock = try repository.appendBlock(
            pageID: pageID,
            type: .paragraph,
            text: ""
        )
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(appendedBlock.type, .paragraph)
        XCTAssertEqual(appendedBlock.textPlain, "")
        XCTAssertEqual(reloadedSnapshot.blocks.map(\.id).last, appendedBlock.id)
        XCTAssertEqual(reloadedSnapshot.blocks.map(\.orderKey), ["000001", "000002"])
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges().last?.entityID, appendedBlock.id)
    }

    func testAppendPageReferenceBlockCreatesTypedBlockAndBacklink() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let targetPage = try repository.createPage(workspaceID: workspaceID, title: "Specs")

        let block = try repository.appendPageReferenceBlock(
            pageID: sourcePageID,
            targetPageID: targetPage.id
        )

        XCTAssertEqual(block.type, .pageReference)
        XCTAssertEqual(block.textPlain, "Specs")
        XCTAssertEqual(block.pageReferenceTargetPageID, targetPage.id)
        XCTAssertEqual(
            try BacklinkRepository(database: database).backlinks(targetPageID: targetPage.id),
            [
                Backlink(
                    sourcePageID: sourcePageID,
                    sourcePageTitle: "Welcome",
                    sourceBlockID: block.id,
                    targetPageID: targetPage.id,
                    targetBlockID: nil,
                    linkText: "Specs"
                )
            ]
        )

        let reloadedBlock = try XCTUnwrap(
            repository.loadWorkspaceSnapshot().blocks.first { $0.id == block.id }
        )
        XCTAssertEqual(reloadedBlock.type, .pageReference)
        XCTAssertEqual(reloadedBlock.pageReferenceTargetPageID, targetPage.id)
    }

    func testAppendBlockReferenceBlockCreatesTypedBlockAndBlockBacklink() throws {
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

        let block = try repository.appendBlockReferenceBlock(
            pageID: sourcePageID,
            targetBlockID: targetBlock.id
        )

        XCTAssertEqual(block.type, .blockReference)
        XCTAssertEqual(block.textPlain, "API contract")
        XCTAssertEqual(block.pageReferenceTargetPageID, targetPage.id)
        XCTAssertEqual(block.blockReferenceTargetBlockID, targetBlock.id)
        XCTAssertEqual(
            try BacklinkRepository(database: database).backlinks(targetPageID: targetPage.id),
            [
                Backlink(
                    sourcePageID: sourcePageID,
                    sourcePageTitle: "Welcome",
                    sourceBlockID: block.id,
                    targetPageID: targetPage.id,
                    targetBlockID: targetBlock.id,
                    linkText: "API contract"
                )
            ]
        )
    }

    func testInsertParagraphBlockAfterCurrentBlockPersistsOrderAndQueuesSync() throws {
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
        let importedSnapshot = try repository.loadWorkspaceSnapshot()
        let firstBlockID = try XCTUnwrap(importedSnapshot.blocks.first?.id)

        let insertedBlock = try repository.insertParagraphBlock(after: firstBlockID)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.blocks.map(\.textPlain), ["First", "", "Second"])
        XCTAssertEqual(reloadedSnapshot.blocks.map(\.orderKey), ["000001", "000002", "000003"])
        XCTAssertEqual(reloadedSnapshot.blocks.dropFirst().first?.id, insertedBlock.id)
        XCTAssertEqual(
            Array(try SyncRepository(database: database).pendingChanges().suffix(2)),
            [
                SyncChange(entityType: "block", entityID: insertedBlock.id, changeType: "create"),
                SyncChange(
                    entityType: "block",
                    entityID: try XCTUnwrap(importedSnapshot.blocks.last?.id),
                    changeType: "update"
                )
            ]
        )
    }

    func testDeleteBlockHidesItQueuesSyncChangeAndRemovesBacklinks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "See [[Welcome]]")
        XCTAssertFalse(try BacklinkRepository(database: database).backlinks(targetPageID: pageID).isEmpty)

        try repository.deleteBlock(blockID: blockID)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.blocks, [])
        XCTAssertEqual(try BacklinkRepository(database: database).backlinks(targetPageID: pageID), [])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "block", entityID: blockID, changeType: "delete")
        )
    }

    func testLargePageImportLoadAndSearchIndexRemainUsable() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let markdown = (1...750)
            .map { "Block \($0) searchable content" }
            .joined(separator: "\n")

        try repository.importMarkdown(pageID: pageID, markdown: markdown)
        let loadedSnapshot = try repository.loadWorkspaceSnapshot()
        try SearchRepository(database: database).rebuildIndex()
        let searchResults = try SearchRepository(database: database).search("Block 750")

        XCTAssertEqual(loadedSnapshot.blocks.count, 750)
        XCTAssertEqual(loadedSnapshot.blocks.first?.orderKey, "000001")
        XCTAssertEqual(loadedSnapshot.blocks.last?.orderKey, "000750")
        XCTAssertTrue(searchResults.contains { $0.snippet == "Block 750 searchable content" })
    }

    private func migratedDatabase() throws -> SQLiteDatabase {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        try SchemaMigrator.migrate(database: database)
        return database
    }

    private func temporaryDatabasePath() -> String {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        temporaryFiles.append(directory)
        return directory.appendingPathComponent("editor.sqlite").path
    }
}
