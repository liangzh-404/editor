import Foundation
import XCTest

final class BacklinkRepositoryTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testBlockUpdateMaintainsBacklinksForPageMentions() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        try pageRepository.updateBlockText(blockID: blockID, text: "See [[Welcome]]")

        XCTAssertEqual(
            try BacklinkRepository(database: database).backlinks(targetPageID: pageID),
            [
                Backlink(
                    sourcePageID: pageID,
                    sourceBlockID: blockID,
                    targetPageID: pageID,
                    targetBlockID: nil,
                    linkText: "Welcome"
                )
            ]
        )
    }

    func testBlockUpdateRemovesStaleBacklinks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        try pageRepository.updateBlockText(blockID: blockID, text: "See [[Welcome]]")
        try pageRepository.updateBlockText(blockID: blockID, text: "No link now")

        XCTAssertEqual(
            try BacklinkRepository(database: database).backlinks(targetPageID: pageID),
            []
        )
    }

    private func migratedDatabase() throws -> SQLiteDatabase {
        let database = try SQLiteDatabase.open(path: makeTemporaryDirectory().appendingPathComponent("editor.sqlite").path)
        try SchemaMigrator.migrate(database: database)
        return database
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
