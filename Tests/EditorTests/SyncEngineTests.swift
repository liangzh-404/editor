import Foundation
import XCTest

final class SyncEngineTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testUploadPendingChangesPersistsSyncRecordAndClearsChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(blockID: blockID, text: "Sync me")

        let adapter = RecordingCloudKitSyncAdapter()
        try SyncEngine(
            syncRepository: SyncRepository(database: database),
            adapter: adapter
        ).uploadPendingChanges()

        XCTAssertEqual(adapter.uploadedChanges.map(\.entityID), [blockID])
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges(), [])
        XCTAssertEqual(
            try SyncRepository(database: database).syncRecords(),
            [
                SyncRecord(
                    entityType: "block",
                    entityID: blockID,
                    recordName: "block-\(blockID)",
                    changeTag: "tag-\(blockID)"
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

final class RecordingCloudKitSyncAdapter: CloudKitSyncAdapter {
    private(set) var uploadedChanges: [SyncChange] = []

    func upload(change: SyncChange) throws -> CloudKitUploadResult {
        uploadedChanges.append(change)
        return CloudKitUploadResult(
            recordName: "\(change.entityType)-\(change.entityID)",
            changeTag: "tag-\(change.entityID)"
        )
    }
}
