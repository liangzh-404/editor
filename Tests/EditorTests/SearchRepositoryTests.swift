import Foundation
import XCTest

final class SearchRepositoryTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testSearchIndexesPageTitlesBlockTextAndAttachmentFilenames() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(blockID: blockID, text: "Alpha searchable block")
        let attachment = try AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        ).importAttachment(
            sourceURL: try makeSourceFile(name: "invoice-2026.pdf", contents: "pdf"),
            workspaceID: workspaceID,
            pageID: pageID
        ).attachment

        let repository = SearchRepository(database: database)
        try repository.rebuildIndex()

        XCTAssertTrue(try repository.search("Welcome").contains(SearchResult(entityType: "page", entityID: pageID, title: "Welcome", snippet: "Welcome", destinationPageID: pageID)))
        XCTAssertTrue(try repository.search("Alpha").contains(SearchResult(entityType: "block", entityID: blockID, title: "Welcome", snippet: "Alpha searchable block", destinationPageID: pageID)))
        XCTAssertTrue(try repository.search("invoice").contains(SearchResult(entityType: "attachment", entityID: attachment.id, title: "invoice-2026.pdf", snippet: "invoice-2026.pdf", destinationPageID: pageID)))
    }

    func testSearchRanksTitleMatchesBeforeBodyMatches() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let welcomeBlockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(
            blockID: welcomeBlockID,
            text: "Needle Needle Needle Needle appears repeatedly only in this block body"
        )
        let titledPage = try pageRepository.createPage(workspaceID: workspaceID, title: "Needle Project")

        let repository = SearchRepository(database: database)
        try repository.rebuildIndex()

        let results = try repository.search("Needle")

        XCTAssertEqual(results.first?.entityType, "page")
        XCTAssertEqual(results.first?.entityID, titledPage.id)
    }

    func testSearchSnippetUsesContextAroundMatch() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let longText = [
            "Opening context that should not dominate the search result",
            "middle words around FocusTerm should stay visible",
            "closing context that should be clipped away from the list row"
        ].joined(separator: " ")
        try pageRepository.updateBlockText(blockID: blockID, text: longText)

        let repository = SearchRepository(database: database)
        try repository.rebuildIndex()

        let result = try XCTUnwrap(try repository.search("FocusTerm").first)

        XCTAssertTrue(result.snippet.contains("FocusTerm"))
        XCTAssertLessThan(result.snippet.count, longText.count)
    }

    private func migratedDatabase() throws -> SQLiteDatabase {
        let database = try SQLiteDatabase.open(path: makeTemporaryDirectory().appendingPathComponent("editor.sqlite").path)
        try SchemaMigrator.migrate(database: database)
        return database
    }

    private func makeSourceFile(name: String, contents: String) throws -> URL {
        let directory = makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent(name)
        try contents.data(using: .utf8)?.write(to: fileURL)
        return fileURL
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
