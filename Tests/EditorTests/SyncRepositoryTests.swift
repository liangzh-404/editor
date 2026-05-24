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
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        try pageRepository.updateBlockText(blockID: blockID, text: "Dirty local edit")

        let changes = try SyncRepository(database: database).pendingChanges()
        XCTAssertEqual(changes, [
            SyncChange(entityType: "block", entityID: blockID, changeType: "update"),
            SyncChange(entityType: "page", entityID: pageID, changeType: "update")
        ])
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

    func testMarkUploadedForDeleteRemovesSyncRecordAndClearsChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = SyncRepository(database: database)
        try repository.enqueue(entityType: "page", entityID: "page-old", changeType: "delete")
        try repository.markUploaded(
            change: SyncChange(entityType: "page", entityID: "page-old", changeType: "update"),
            uploadResult: CloudKitUploadResult(recordName: "page-page-old", changeTag: "tag-old")
        )

        try repository.markUploaded(
            change: SyncChange(entityType: "page", entityID: "page-old", changeType: "delete"),
            uploadResult: CloudKitUploadResult(recordName: "page-page-old", changeTag: nil)
        )

        XCTAssertEqual(try repository.pendingChanges(), [])
        XCTAssertFalse(try repository.syncRecords().contains { $0.entityID == "page-old" })
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

    func testEnqueueCoalescesDuplicateChangeAndClearsRetryState() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = SyncRepository(database: database)
        try repository.enqueue(entityType: "page", entityID: "page-welcome", changeType: "update")
        let failedChange = try XCTUnwrap(repository.pendingChanges().first)
        try repository.recordFailure(
            change: failedChange,
            errorDescription: "CloudKit unavailable",
            nextAttemptAt: Date(timeIntervalSince1970: 1_800)
        )

        try repository.enqueue(entityType: "page", entityID: "page-welcome", changeType: "update")

        let expectedChange = SyncChange(entityType: "page", entityID: "page-welcome", changeType: "update")
        XCTAssertEqual(try repository.pendingChanges(), [expectedChange])
        XCTAssertEqual(
            try repository.retryState(change: expectedChange),
            SyncRetryState(attemptCount: 0, lastError: nil, nextAttemptAt: nil)
        )
    }

    func testPendingChangesCoalescesExistingDuplicateRows() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        try database.execute("DROP INDEX IF EXISTS idx_sync_changes_entity_change")
        try insertSyncChange(
            database: database,
            id: "sync-old",
            entityType: "page",
            entityID: "page-welcome",
            changeType: "update",
            createdAt: "2026-05-20T01:40:00Z"
        )
        try insertSyncChange(
            database: database,
            id: "sync-new",
            entityType: "page",
            entityID: "page-welcome",
            changeType: "update",
            createdAt: "2026-05-20T01:41:00Z"
        )

        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges(),
            [SyncChange(entityType: "page", entityID: "page-welcome", changeType: "update")]
        )
    }

    func testEnqueueUnsyncedLocalRecordsRestoresDroppedCreateChanges() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let tagRepository = TagRepository(database: database)
        let tag = try tagRepository.createTag(workspaceID: workspaceID, name: "Writing")
        try tagRepository.assignTags(pageID: pageID, tagIDs: [tag.id])
        try database.execute("DELETE FROM sync_changes")
        try database.execute("DELETE FROM sync_records")

        try SyncRepository(database: database).enqueueUnsyncedLocalRecords()

        let pendingChanges = try SyncRepository(database: database).pendingChanges()
        XCTAssertTrue(pendingChanges.contains(
            SyncChange(entityType: "workspace", entityID: workspaceID, changeType: "create")
        ))
        XCTAssertTrue(pendingChanges.contains(
            SyncChange(entityType: "page", entityID: pageID, changeType: "create")
        ))
        XCTAssertTrue(pendingChanges.contains(
            SyncChange(entityType: "block", entityID: blockID, changeType: "create")
        ))
        XCTAssertTrue(pendingChanges.contains(
            SyncChange(entityType: "tag", entityID: tag.id, changeType: "create")
        ))
        XCTAssertTrue(pendingChanges.contains(
            SyncChange(entityType: "pageTag", entityID: "\(pageID).\(tag.id)", changeType: "create")
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

    func testRuntimeDiagnosticsPersistRecentEventsNewestFirst() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = RuntimeDiagnosticRepository(database: database)

        try repository.record(
            eventName: "remote_notification_registration_succeeded",
            payloadJSON: #"{"token_length":32}"#,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        try repository.record(
            eventName: "cloudkit_sync_diagnostic_completed",
            payloadJSON: #"{"pending_change_count":0}"#,
            createdAt: Date(timeIntervalSince1970: 200)
        )

        let events = try repository.recentEvents(limit: 10)

        XCTAssertEqual(events.map(\.eventName), [
            "cloudkit_sync_diagnostic_completed",
            "remote_notification_registration_succeeded"
        ])
        XCTAssertEqual(events.first?.payloadJSON, #"{"pending_change_count":0}"#)
        XCTAssertTrue(events.allSatisfy { $0.id.hasPrefix("runtime-diagnostic-") })
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

    private func insertSyncChange(
        database: SQLiteDatabase,
        id: String,
        entityType: String,
        entityID: String,
        changeType: String,
        createdAt: String
    ) throws {
        try database.execute(
            """
            INSERT INTO sync_changes (
                id,
                entity_type,
                entity_id,
                change_type,
                attempt_count,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(id),
                .text(entityType),
                .text(entityID),
                .text(changeType),
                .integer(0),
                .text(createdAt)
            ]
        )
    }
}
