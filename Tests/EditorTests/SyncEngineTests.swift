import Foundation
import CloudKit
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

    func testUploadFailureRecordsRetryStateAndContinuesWithLaterChanges() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let syncRepository = SyncRepository(database: database)
        try syncRepository.enqueue(entityType: "block", entityID: "block-failing", changeType: "update")
        try syncRepository.enqueue(entityType: "block", entityID: "block-success", changeType: "update")
        let adapter = FailingOnceCloudKitSyncAdapter(failingEntityID: "block-failing")

        let result = try SyncEngine(
            syncRepository: syncRepository,
            adapter: adapter,
            retryPolicy: SyncRetryPolicy(baseDelay: 60, maximumDelay: 300),
            now: { Date(timeIntervalSince1970: 1_000) }
        ).uploadPendingChanges()

        XCTAssertEqual(result.uploadedCount, 1)
        XCTAssertEqual(result.failedCount, 1)
        XCTAssertEqual(adapter.uploadedChanges.map(\.entityID), ["block-failing", "block-success"])
        XCTAssertEqual(try syncRepository.pendingChanges(), [
            SyncChange(entityType: "block", entityID: "block-failing", changeType: "update")
        ])
        XCTAssertEqual(try syncRepository.retryState(change: SyncChange(entityType: "block", entityID: "block-failing", changeType: "update")), SyncRetryState(
            attemptCount: 1,
            lastError: "temporaryUnavailable",
            nextAttemptAt: Date(timeIntervalSince1970: 1_060)
        ))
        XCTAssertEqual(try syncRepository.syncRecords().map(\.entityID), ["block-success"])
    }

    func testUploadSkipsChangesUntilRetryDate() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let syncRepository = SyncRepository(database: database)
        try syncRepository.enqueue(entityType: "block", entityID: "block-waiting", changeType: "update")
        let change = try XCTUnwrap(syncRepository.pendingChanges().first)
        try syncRepository.recordFailure(
            change: change,
            errorDescription: "temporaryUnavailable",
            nextAttemptAt: Date(timeIntervalSince1970: 1_500)
        )
        let adapter = RecordingCloudKitSyncAdapter()

        let result = try SyncEngine(
            syncRepository: syncRepository,
            adapter: adapter,
            now: { Date(timeIntervalSince1970: 1_000) }
        ).uploadPendingChanges()

        XCTAssertEqual(result.uploadedCount, 0)
        XCTAssertEqual(result.failedCount, 0)
        XCTAssertEqual(adapter.uploadedChanges, [])
        XCTAssertEqual(try syncRepository.pendingChanges(), [change])
    }

    func testFetchRemoteChangesAppliesRemoteBlockUpdates() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let fetcher = StaticRemoteBlockChangeFetcher(
            changes: [
                RemoteBlockChange(
                    blockID: blockID,
                    pageID: pageID,
                    type: .paragraph,
                    textPlain: "Remote fetched text",
                    payloadJSON: "{\"text\":\"Remote fetched text\"}",
                    revision: 3
                )
            ]
        )

        let result = try SyncEngine(
            syncRepository: SyncRepository(database: database),
            adapter: RecordingCloudKitSyncAdapter(),
            remoteChangeFetcher: fetcher,
            mergeEngine: SyncMergeEngine(database: database)
        ).fetchRemoteChanges()

        XCTAssertEqual(result.appliedCount, 1)
        XCTAssertEqual(try pageRepository.loadWorkspaceSnapshot().blocks.first?.textPlain, "Remote fetched text")
    }

    func testCloudKitPrivateDatabaseAdapterMapsBlockChangeToRecord() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(blockID: blockID, text: "Cloud text")
        let saver = CapturingCloudKitRecordSaver()

        let result = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordSaver: saver
        ).upload(change: SyncChange(entityType: "block", entityID: blockID, changeType: "update"))

        let record = try XCTUnwrap(saver.savedRecords.first)
        XCTAssertEqual(record.recordType, "BlockRecord")
        XCTAssertEqual(record.recordID.recordName, "block-\(blockID)")
        XCTAssertEqual(record["entityID"] as? String, blockID)
        XCTAssertEqual(record["textPlain"] as? String, "Cloud text")
        XCTAssertEqual(record["type"] as? String, BlockType.paragraph.rawValue)
        XCTAssertEqual(result.recordName, "block-\(blockID)")
    }

    func testCloudKitPrivateDatabaseAdapterMapsNotebookChangeToRecord() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let notebook = try pageRepository.createNotebook(workspaceID: workspaceID, name: "Projects")
        let saver = CapturingCloudKitRecordSaver()

        let result = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordSaver: saver
        ).upload(change: SyncChange(entityType: "notebook", entityID: notebook.id, changeType: "create"))

        let record = try XCTUnwrap(saver.savedRecords.first)
        XCTAssertEqual(record.recordType, "NotebookRecord")
        XCTAssertEqual(record.recordID.recordName, "notebook-\(notebook.id)")
        XCTAssertEqual(record["entityID"] as? String, notebook.id)
        XCTAssertEqual(record["workspaceID"] as? String, workspaceID)
        XCTAssertEqual(record["name"] as? String, "Projects")
        XCTAssertEqual(result.recordName, "notebook-\(notebook.id)")
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

final class FailingOnceCloudKitSyncAdapter: CloudKitSyncAdapter {
    private(set) var uploadedChanges: [SyncChange] = []
    private let failingEntityID: String

    init(failingEntityID: String) {
        self.failingEntityID = failingEntityID
    }

    func upload(change: SyncChange) throws -> CloudKitUploadResult {
        uploadedChanges.append(change)
        if change.entityID == failingEntityID {
            throw SyncEngineTestError.temporaryUnavailable
        }

        return CloudKitUploadResult(
            recordName: "\(change.entityType)-\(change.entityID)",
            changeTag: "tag-\(change.entityID)"
        )
    }
}

final class StaticRemoteBlockChangeFetcher: CloudKitRemoteChangeFetching {
    let changes: [RemoteBlockChange]

    init(changes: [RemoteBlockChange]) {
        self.changes = changes
    }

    func fetchRemoteBlockChanges() throws -> [RemoteBlockChange] {
        changes
    }
}

enum SyncEngineTestError: Error, CustomStringConvertible {
    case temporaryUnavailable

    var description: String {
        "temporaryUnavailable"
    }
}

final class CapturingCloudKitRecordSaver: CloudKitRecordSaving {
    private(set) var savedRecords: [CKRecord] = []

    func save(record: CKRecord) throws -> CKRecord {
        savedRecords.append(record)
        return record
    }
}
