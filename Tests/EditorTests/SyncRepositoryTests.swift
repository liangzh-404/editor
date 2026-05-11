import Foundation
import XCTest

final class SyncRepositoryTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testBlockUpdateEnqueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        try pageRepository.updateBlockText(blockID: blockID, text: "Dirty local edit")

        let changes = try SyncRepository(database: database).pendingChanges()
        XCTAssertEqual(changes.map(\.entityType), ["block"])
        XCTAssertEqual(changes.map(\.entityID), [blockID])
        XCTAssertEqual(changes.map(\.changeType), ["update"])
    }

    func testAttachmentImportEnqueuesAttachmentAndBlockSyncChanges() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)

        let importResult = try AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        ).importAttachment(
            sourceURL: try makeSourceFile(name: "asset.txt", contents: "sync me"),
            workspaceID: workspaceID,
            pageID: pageID
        )

        let changes = try SyncRepository(database: database).pendingChanges()
        XCTAssertTrue(changes.contains(SyncChange(entityType: "attachment", entityID: importResult.attachment.id, changeType: "create")))
        XCTAssertTrue(changes.contains(SyncChange(entityType: "block", entityID: importResult.block.id, changeType: "create")))
    }

    func testRecordFailureKeepsChangeAndSchedulesRetry() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = SyncRepository(database: database)
        try repository.enqueue(entityType: "block", entityID: "block-1", changeType: "update")
        let change = try XCTUnwrap(repository.pendingChanges().first)
        let retryDate = Date(timeIntervalSince1970: 1_800)

        try repository.recordFailure(
            change: change,
            errorDescription: "Network unavailable",
            nextAttemptAt: retryDate
        )

        XCTAssertEqual(try repository.pendingChanges().map(\.entityID), ["block-1"])
        XCTAssertEqual(try repository.retryState(change: change), SyncRetryState(
            attemptCount: 1,
            lastError: "Network unavailable",
            nextAttemptAt: retryDate
        ))
    }

    func testServerChangeTokenRoundTripsByScope() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = SyncRepository(database: database)
        let tokenData = Data("token-v1".utf8)

        XCTAssertNil(try repository.serverChangeTokenData(scope: "privateDatabase"))

        try repository.saveServerChangeTokenData(tokenData, scope: "privateDatabase")

        XCTAssertEqual(
            try repository.serverChangeTokenData(scope: "privateDatabase"),
            tokenData
        )
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
