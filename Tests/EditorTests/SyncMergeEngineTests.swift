import Foundation
import XCTest

final class SyncMergeEngineTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testRemoteSameBlockConflictKeepsLocalTextAndStoresRemoteVersion() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(blockID: blockID, text: "Local edit")

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

        XCTAssertEqual(try pageRepository.loadWorkspaceSnapshot().blocks.first?.textPlain, "Local edit")
        XCTAssertEqual(
            try ConflictRepository(database: database).conflicts(blockID: blockID),
            [
                ConflictVersion(
                    blockID: blockID,
                    payloadJSON: "{\"text\":\"Remote edit\"}",
                    textPlain: "Remote edit",
                    remoteRevision: 2
                )
            ]
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
