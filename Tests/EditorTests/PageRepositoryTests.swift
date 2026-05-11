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
        XCTAssertEqual(snapshot.pages.map(\.title), ["Welcome"])
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
