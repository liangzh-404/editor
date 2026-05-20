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

    func testLocalBlockEditRemainsReadableAndPendingWhenCloudKitUploadFails() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(blockID: blockID, text: "Offline edit survives")
        let syncRepository = SyncRepository(database: database)
        let adapter = FailingOnceCloudKitSyncAdapter(failingEntityID: blockID)

        let result = try SyncEngine(
            syncRepository: syncRepository,
            adapter: adapter,
            retryPolicy: SyncRetryPolicy(baseDelay: 60, maximumDelay: 300),
            now: { Date(timeIntervalSince1970: 1_000) }
        ).uploadPendingChanges()

        let reloadedBlock = try XCTUnwrap(
            pageRepository.loadWorkspaceSnapshot().blocks.first { $0.id == blockID }
        )
        XCTAssertEqual(reloadedBlock.textPlain, "Offline edit survives")
        XCTAssertEqual(result.uploadedCount, 0)
        XCTAssertEqual(result.failedCount, 1)
        XCTAssertEqual(try syncRepository.pendingChanges(), [
            SyncChange(entityType: "block", entityID: blockID, changeType: "update")
        ])
        XCTAssertEqual(try syncRepository.syncRecords(), [])
        XCTAssertEqual(
            try syncRepository.retryState(change: SyncChange(entityType: "block", entityID: blockID, changeType: "update")),
            SyncRetryState(
                attemptCount: 1,
                lastError: "temporaryUnavailable",
                nextAttemptAt: Date(timeIntervalSince1970: 1_060)
            )
        )
    }

    func testCloudKitErrorDiagnosticIncludesNSErrorUserInfo() {
        let error = NSError(
            domain: CKErrorDomain,
            code: CKError.serverRejectedRequest.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "Server Rejected Request",
                "CKErrorServerDescription": "Field syncGeneration is not defined",
                "RequestUUID": "F754BFF0",
                "ContainerID": CloudKitSyncConfiguration.containerIdentifier
            ]
        )

        let description = CloudKitErrorDiagnostic.describe(error)

        XCTAssertTrue(description.contains("domain=CKErrorDomain"))
        XCTAssertTrue(description.contains("code=15"))
        XCTAssertTrue(description.contains("CKErrorServerDescription=Field syncGeneration is not defined"))
        XCTAssertTrue(description.contains("RequestUUID=F754BFF0"))
        XCTAssertTrue(description.contains("ContainerID=iCloud.com.liangzhang.editor.sync"))
    }

    func testCloudKitErrorDiagnosticPrioritizesUnderlyingErrorOverHTTPHeaders() {
        let underlyingError = NSError(
            domain: "CKInternalErrorDomain",
            code: 2000,
            userInfo: [
                NSLocalizedDescriptionKey: "Field payloadJSON is not queryable"
            ]
        )
        let error = NSError(
            domain: CKErrorDomain,
            code: CKError.serverRejectedRequest.rawValue,
            userInfo: [
                "CKDHTTPHeaders": [
                    "x-apple-request-uuid": "55EBCECA",
                    "Date": "Tue, 19 May 2026 16:41:09 GMT",
                    "Via": "very-long-header-value"
                ],
                "CKHTTPStatus": 500,
                "ContainerID": CloudKitSyncConfiguration.containerIdentifier,
                "NSDebugDescription": "CKInternalErrorDomain: 2000",
                NSUnderlyingErrorKey: underlyingError
            ]
        )

        let description = CloudKitErrorDiagnostic.describe(error)

        XCTAssertTrue(description.contains("CKHTTPStatus=500"))
        XCTAssertTrue(description.contains("ContainerID=iCloud.com.liangzhang.editor.sync"))
        XCTAssertTrue(description.contains("NSDebugDescription=CKInternalErrorDomain: 2000"))
        XCTAssertTrue(description.contains("NSUnderlyingError=[domain=CKInternalErrorDomain code=2000"))
        XCTAssertTrue(description.contains("x-apple-request-uuid=55EBCECA"))
        XCTAssertFalse(description.contains("very-long-header-value"))
    }

    func testCloudKitRuntimeProbeRunsOnlyWhenRequested() {
        XCTAssertFalse(CloudKitRuntimeProbe.isEnabled(environment: [:]))
        XCTAssertFalse(CloudKitRuntimeProbe.isEnabled(environment: ["EDITOR_CLOUDKIT_PROBE": "0"]))
        XCTAssertTrue(CloudKitRuntimeProbe.isEnabled(environment: ["EDITOR_CLOUDKIT_PROBE": "1"]))
    }

    func testCloudKitRuntimeProbeRunsAccountSaveFetchAndDeleteMinimalRecord() throws {
        let recorder = RuntimeProbeCallRecorder()
        let accountStatusProvider = RecordingCloudKitAccountStatusProvider(recorder: recorder)
        let zoneEnsurer = CapturingCloudKitRecordZoneEnsurer(recorder: recorder)
        let databaseInspector = CapturingCloudKitDatabaseInspector(recorder: recorder)
        let saver = CapturingCloudKitRecordSaver(recorder: recorder)
        let reader = CapturingCloudKitRecordReader(recorder: recorder)
        let deleter = CapturingCloudKitRecordDeleter(recorder: recorder)

        let result = CloudKitRuntimeProbe.run(
            recordName: "runtime-probe-test",
            accountStatusProvider: accountStatusProvider,
            zoneEnsurer: zoneEnsurer,
            databaseInspector: databaseInspector,
            saver: saver,
            reader: reader,
            deleter: deleter
        )

        XCTAssertTrue(result.isSuccess)
        let record = try XCTUnwrap(saver.savedRecords.first)
        XCTAssertEqual(record.recordType, "EditorRuntimeProbeRecord")
        XCTAssertEqual(record.recordID.recordName, "runtime-probe-test")
        XCTAssertEqual(record.recordID.zoneID.zoneName, CloudKitSyncConfiguration.recordZoneName)
        XCTAssertEqual(record["probeVersion"] as? String, "1")
        XCTAssertNotNil(record["createdAt"] as? Date)
        XCTAssertEqual(reader.fetchedRecordIDs.map(\.recordName), ["runtime-probe-test"])
        XCTAssertEqual(deleter.deletedRecordIDs.map(\.recordName), ["runtime-probe-test"])
        XCTAssertEqual(recorder.calls, [
            "accountStatus",
            "ensureRecordZoneExists",
            "fetchAllRecordZones",
            "fetchAllSubscriptions",
            "save:runtime-probe-test",
            "fetch:runtime-probe-test",
            "delete:runtime-probe-test"
        ])
    }

    func testCloudKitRuntimeProbeReturnsDiagnosticAndSkipsCleanupWhenSaveFails() {
        let accountStatusProvider = RecordingCloudKitAccountStatusProvider()
        let zoneEnsurer = CapturingCloudKitRecordZoneEnsurer()
        let databaseInspector = CapturingCloudKitDatabaseInspector()
        let saver = FailingCloudKitRecordSaver(error: NSError(
            domain: CKErrorDomain,
            code: CKError.serverRejectedRequest.rawValue,
            userInfo: [
                "CKHTTPStatus": 500,
                "ContainerID": CloudKitSyncConfiguration.containerIdentifier
            ]
        ))
        let reader = CapturingCloudKitRecordReader()
        let deleter = CapturingCloudKitRecordDeleter()

        let result = CloudKitRuntimeProbe.run(
            recordName: "runtime-probe-failing",
            accountStatusProvider: accountStatusProvider,
            zoneEnsurer: zoneEnsurer,
            databaseInspector: databaseInspector,
            saver: saver,
            reader: reader,
            deleter: deleter
        )

        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.recordName, "runtime-probe-failing")
        XCTAssertTrue(result.errorDescription?.contains("CKHTTPStatus=500") == true)
        XCTAssertEqual(reader.fetchedRecordIDs, [])
        XCTAssertEqual(deleter.deletedRecordIDs, [])
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

    func testRetryAfterBackoffUploadsAndClearsQueuedChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let syncRepository = SyncRepository(database: database)
        try syncRepository.enqueue(entityType: "block", entityID: "block-recovered", changeType: "update")
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
            now: { Date(timeIntervalSince1970: 1_501) }
        ).uploadPendingChanges()

        XCTAssertEqual(result.uploadedCount, 1)
        XCTAssertEqual(result.failedCount, 0)
        XCTAssertEqual(adapter.uploadedChanges, [change])
        XCTAssertEqual(try syncRepository.pendingChanges(), [])
        XCTAssertEqual(try syncRepository.syncRecords(), [
            SyncRecord(
                entityType: "block",
                entityID: "block-recovered",
                recordName: "block-block-recovered",
                changeTag: "tag-block-recovered"
            )
        ])
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

    func testFetchRemoteChangesUsesAndPersistsServerChangeToken() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let syncRepository = SyncRepository(database: database)
        let previousToken = Data("previous-token".utf8)
        let nextToken = Data("next-token".utf8)
        try syncRepository.saveServerChangeTokenData(previousToken, scope: "privateDatabase")
        let fetcher = StaticRemoteBlockChangeFetcher(
            changes: [],
            serverChangeTokenData: nextToken
        )

        let result = try SyncEngine(
            syncRepository: syncRepository,
            adapter: RecordingCloudKitSyncAdapter(),
            remoteChangeFetcher: fetcher,
            mergeEngine: SyncMergeEngine(database: database)
        ).fetchRemoteChanges()

        XCTAssertEqual(result.appliedCount, 0)
        XCTAssertEqual(fetcher.receivedServerChangeTokenData, previousToken)
        XCTAssertEqual(
            try syncRepository.serverChangeTokenData(scope: "privateDatabase"),
            nextToken
        )
    }

    func testFetchRemoteChangesResetsExpiredServerChangeTokenAndRetriesFromScratch() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let syncRepository = SyncRepository(database: database)
        let previousToken = Data("previous-token".utf8)
        let nextToken = Data("next-token".utf8)
        try syncRepository.saveServerChangeTokenData(previousToken, scope: "privateDatabase")
        let fetcher = ExpiringThenSucceedingRemoteChangeFetcher(
            serverChangeTokenDataAfterRetry: nextToken
        )

        let result = try SyncEngine(
            syncRepository: syncRepository,
            adapter: RecordingCloudKitSyncAdapter(),
            remoteChangeFetcher: fetcher,
            mergeEngine: SyncMergeEngine(database: database)
        ).fetchRemoteChanges()

        XCTAssertEqual(result.appliedCount, 0)
        XCTAssertEqual(fetcher.receivedServerChangeTokenData, [previousToken, nil])
        XCTAssertEqual(
            try syncRepository.serverChangeTokenData(scope: "privateDatabase"),
            nextToken
        )
    }

    func testFetchRemoteChangesDoesNotResetTokenForNonExpiryFetchFailure() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let syncRepository = SyncRepository(database: database)
        let previousToken = Data("previous-token".utf8)
        try syncRepository.saveServerChangeTokenData(previousToken, scope: "privateDatabase")
        let fetcher = AlwaysFailingRemoteChangeFetcher(error: SyncEngineTestError.temporaryUnavailable)

        XCTAssertThrowsError(
            try SyncEngine(
                syncRepository: syncRepository,
                adapter: RecordingCloudKitSyncAdapter(),
                remoteChangeFetcher: fetcher,
                mergeEngine: SyncMergeEngine(database: database)
            ).fetchRemoteChanges()
        )

        XCTAssertEqual(fetcher.receivedServerChangeTokenData, [previousToken])
        XCTAssertEqual(
            try syncRepository.serverChangeTokenData(scope: "privateDatabase"),
            previousToken
        )
    }

    func testEnsureRemoteChangeSubscriptionCreatesSilentRecordZoneSubscription() throws {
        let saver = CapturingCloudKitSubscriptionSaver()
        let zoneEnsurer = CapturingCloudKitRecordZoneEnsurer()
        let ensurer = CloudKitPrivateDatabaseSubscriptionEnsurer(
            subscriptionSaver: saver,
            zoneEnsurer: zoneEnsurer
        )

        try ensurer.ensureRemoteChangeSubscription()

        XCTAssertEqual(zoneEnsurer.ensureCallCount, 1)
        let subscription = try XCTUnwrap(saver.savedSubscriptions.first as? CKRecordZoneSubscription)
        XCTAssertEqual(subscription.subscriptionID, "editor-private-database-changes")
        XCTAssertEqual(subscription.zoneID.zoneName, CloudKitSyncConfiguration.recordZoneName)
        XCTAssertEqual(subscription.notificationInfo?.shouldSendContentAvailable, true)
        XCTAssertNil(subscription.notificationInfo?.alertBody)
    }

    func testSyncEngineEnsuresRemoteChangeSubscriptionThroughInjectedEnsurer() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let ensurer = RecordingCloudKitSubscriptionEnsurer()

        try SyncEngine(
            syncRepository: SyncRepository(database: database),
            adapter: RecordingCloudKitSyncAdapter(),
            subscriptionEnsurer: ensurer
        ).ensureRemoteChangeSubscription()

        XCTAssertEqual(ensurer.ensureCallCount, 1)
    }

    func testRemoteNotificationSyncHandlerReturnsNewDataWhenRemoteChangesApply() {
        let syncer = RecordingRemoteNotificationSyncer(
            uploadSummary: SyncUploadSummary(uploadedCount: 0, failedCount: 0),
            fetchSummary: SyncFetchSummary(appliedCount: 2)
        )

        let result = RemoteNotificationSyncHandler(syncer: syncer).handleRemoteNotification()

        XCTAssertEqual(result, .newData)
        XCTAssertEqual(syncer.calls, [.ensureRemoteChangeSubscription, .uploadPendingChanges, .fetchRemoteChanges])
    }

    func testRemoteNotificationSyncHandlerReportIncludesUploadAndFetchCounts() {
        let syncer = RecordingRemoteNotificationSyncer(
            uploadSummary: SyncUploadSummary(uploadedCount: 1, failedCount: 0),
            fetchSummary: SyncFetchSummary(appliedCount: 2)
        )

        let report = RemoteNotificationSyncHandler(syncer: syncer).handleRemoteNotificationReport()

        XCTAssertEqual(report.result, .newData)
        XCTAssertEqual(report.uploadedCount, 1)
        XCTAssertEqual(report.failedUploadCount, 0)
        XCTAssertEqual(report.fetchedCount, 2)
        XCTAssertNil(report.errorDescription)
        XCTAssertEqual(syncer.calls, [.ensureRemoteChangeSubscription, .uploadPendingChanges, .fetchRemoteChanges])
    }

    func testRemoteNotificationSyncHandlerReturnsNoDataWithoutSyncEngine() {
        let result = RemoteNotificationSyncHandler(syncer: nil).handleRemoteNotification()

        XCTAssertEqual(result, .noData)
    }

    func testRemoteNotificationSyncHandlerReturnsFailedWhenSyncThrows() {
        let syncer = RecordingRemoteNotificationSyncer(
            uploadSummary: SyncUploadSummary(uploadedCount: 0, failedCount: 0),
            fetchSummary: SyncFetchSummary(appliedCount: 0),
            errorAfterCall: .fetchRemoteChanges
        )

        let result = RemoteNotificationSyncHandler(syncer: syncer).handleRemoteNotification()

        XCTAssertEqual(result, .failed)
        XCTAssertEqual(syncer.calls, [.ensureRemoteChangeSubscription, .uploadPendingChanges, .fetchRemoteChanges])
    }

    func testRemoteNotificationSyncHandlerStillFetchesWhenLocalUploadFails() {
        let syncer = RecordingRemoteNotificationSyncer(
            uploadSummary: SyncUploadSummary(uploadedCount: 0, failedCount: 1),
            fetchSummary: SyncFetchSummary(appliedCount: 2)
        )

        let result = RemoteNotificationSyncHandler(syncer: syncer).handleRemoteNotification()

        XCTAssertEqual(result, .newData)
        XCTAssertEqual(syncer.calls, [.ensureRemoteChangeSubscription, .uploadPendingChanges, .fetchRemoteChanges])
    }

    @MainActor
    func testRemoteNotificationRegistrationPolicyRegistersOnlyWhenCloudKitIsAvailable() {
        let registrar = RecordingRemoteNotificationRegistrar()

        RemoteNotificationRegistrationPolicy.registerIfNeeded(
            hasCloudKitContainers: false,
            registrar: registrar
        )
        XCTAssertEqual(registrar.registerCallCount, 0)

        RemoteNotificationRegistrationPolicy.registerIfNeeded(
            hasCloudKitContainers: true,
            registrar: registrar
        )
        XCTAssertEqual(registrar.registerCallCount, 1)
    }

    @MainActor
    func testRemoteNotificationRegistrationPolicySkipsDuringHeadlessSyncDiagnostic() {
        let registrar = RecordingRemoteNotificationRegistrar()

        RemoteNotificationRegistrationPolicy.registerIfNeeded(
            hasCloudKitContainers: true,
            environment: [CloudKitSyncDiagnosticRequest.enabledKey: "1"],
            registrar: registrar
        )

        XCTAssertEqual(registrar.registerCallCount, 0)
    }

    @MainActor
    func testRemoteNotificationRegistrationPolicySkipsDuringRemoteNotificationSyncDiagnostic() {
        let registrar = RecordingRemoteNotificationRegistrar()

        RemoteNotificationRegistrationPolicy.registerIfNeeded(
            hasCloudKitContainers: true,
            environment: [RemoteNotificationSyncDiagnosticRequest.enabledKey: "1"],
            registrar: registrar
        )

        XCTAssertEqual(registrar.registerCallCount, 0)
    }

    func testFetchRemoteChangesAppliesRemoteBlockDeletion() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try BacklinkRepository(database: database).rebuildLinksForBlock(
            blockID: blockID,
            text: "See [[欢迎]]"
        )
        XCTAssertFalse(try BacklinkRepository(database: database).backlinks(targetPageID: pageID).isEmpty)
        let fetcher = StaticRemoteBlockChangeFetcher(
            changes: [],
            deletedRecords: [
                RemoteDeletedRecord(entityType: "block", entityID: blockID)
            ]
        )

        let result = try SyncEngine(
            syncRepository: SyncRepository(database: database),
            adapter: RecordingCloudKitSyncAdapter(),
            remoteChangeFetcher: fetcher,
            mergeEngine: SyncMergeEngine(database: database)
        ).fetchRemoteChanges()
        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()

        XCTAssertEqual(result.appliedCount, 1)
        XCTAssertEqual(reloadedSnapshot.blocks, [])
        XCTAssertEqual(try BacklinkRepository(database: database).backlinks(targetPageID: pageID), [])
    }

    func testFetchRemoteChangesAppliesRemoteBlockSoftDeleteRecords() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try BacklinkRepository(database: database).rebuildLinksForBlock(
            blockID: blockID,
            text: "See [[欢迎]]"
        )
        let fetcher = StaticRemoteBlockChangeFetcher(
            changes: [
                RemoteBlockChange(
                    blockID: blockID,
                    pageID: pageID,
                    type: .paragraph,
                    textPlain: "",
                    payloadJSON: "{\"text\":\"\"}",
                    revision: 2,
                    isDeleted: true
                )
            ]
        )

        let result = try SyncEngine(
            syncRepository: SyncRepository(database: database),
            adapter: RecordingCloudKitSyncAdapter(),
            remoteChangeFetcher: fetcher,
            mergeEngine: SyncMergeEngine(database: database)
        ).fetchRemoteChanges()
        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()

        XCTAssertEqual(result.appliedCount, 1)
        XCTAssertEqual(reloadedSnapshot.blocks, [])
        XCTAssertEqual(try BacklinkRepository(database: database).backlinks(targetPageID: pageID), [])
    }

    func testFetchRemoteChangesAppliesRemotePageDeletion() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try BacklinkRepository(database: database).rebuildLinksForBlock(
            blockID: blockID,
            text: "See [[欢迎]]"
        )
        let fetcher = StaticRemoteBlockChangeFetcher(
            changes: [],
            deletedRecords: [
                RemoteDeletedRecord(entityType: "page", entityID: pageID)
            ]
        )

        let result = try SyncEngine(
            syncRepository: SyncRepository(database: database),
            adapter: RecordingCloudKitSyncAdapter(),
            remoteChangeFetcher: fetcher,
            mergeEngine: SyncMergeEngine(database: database)
        ).fetchRemoteChanges()
        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()

        XCTAssertEqual(result.appliedCount, 1)
        XCTAssertEqual(reloadedSnapshot.pages, [])
        XCTAssertEqual(reloadedSnapshot.archivedPages.map(\.id), [pageID])
        XCTAssertEqual(reloadedSnapshot.blocks, [])
        XCTAssertEqual(try BacklinkRepository(database: database).backlinks(targetPageID: pageID), [])
    }

    func testFetchRemoteChangesAppliesRemoteNotebookDeletionWithoutDeletingPages() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let notebookID = try XCTUnwrap(snapshot.selectedNotebookID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let fetcher = StaticRemoteBlockChangeFetcher(
            changes: [],
            deletedRecords: [
                RemoteDeletedRecord(entityType: "notebook", entityID: notebookID)
            ]
        )

        _ = try SyncEngine(
            syncRepository: SyncRepository(database: database),
            adapter: RecordingCloudKitSyncAdapter(),
            remoteChangeFetcher: fetcher,
            mergeEngine: SyncMergeEngine(database: database)
        ).fetchRemoteChanges()
        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.notebooks, [])
        XCTAssertEqual(reloadedSnapshot.pages.map(\.id), [pageID])
        XCTAssertNil(reloadedSnapshot.pages.first?.notebookID)
    }

    func testFetchRemoteChangesAppliesRemoteAttachmentDeletion() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let imported = try attachmentRepository.importAttachment(
            sourceURL: try makeSourceFile(name: "brief.txt", contents: "local attachment"),
            workspaceID: workspaceID,
            pageID: pageID
        )
        try database.execute("DELETE FROM sync_changes")
        let fetcher = StaticRemoteBlockChangeFetcher(
            changes: [],
            deletedRecords: [
                RemoteDeletedRecord(entityType: "attachment", entityID: imported.attachment.id)
            ]
        )

        _ = try SyncEngine(
            syncRepository: SyncRepository(database: database),
            adapter: RecordingCloudKitSyncAdapter(),
            remoteChangeFetcher: fetcher,
            mergeEngine: SyncMergeEngine(database: database)
        ).fetchRemoteChanges()
        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()

        XCTAssertFalse(reloadedSnapshot.attachments.contains { $0.id == imported.attachment.id })
        XCTAssertFalse(reloadedSnapshot.blocks.contains { $0.id == imported.block.id })
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported.attachment.localPath))
    }

    func testFetchRemoteChangesAppliesWorkspaceNotebookPageAttachmentAndBlockChanges() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let fetcher = StaticRemoteBlockChangeFetcher(
            workspaceChanges: [
                RemoteWorkspaceChange(workspaceID: "workspace-remote", name: "Remote")
            ],
            notebookChanges: [
                RemoteNotebookChange(
                    notebookID: "notebook-remote",
                    workspaceID: "workspace-remote",
                    name: "Projects",
                    orderKey: "000001"
                )
            ],
            pageChanges: [
                RemotePageChange(
                    pageID: "page-remote",
                    workspaceID: "workspace-remote",
                    notebookID: "notebook-remote",
                    title: "Roadmap",
                    orderKey: "000001",
                    isArchived: false,
                    isFavorite: true
                )
            ],
            attachmentChanges: [
                RemoteAttachmentChange(
                    attachmentID: "attachment-remote",
                    workspaceID: "workspace-remote",
                    originalFilename: "brief.pdf",
                    utiType: "com.adobe.pdf",
                    byteSize: 128,
                    contentHash: "hash-remote",
                    localPath: "/remote/brief.pdf",
                    thumbnailPath: nil
                )
            ],
            changes: [
                RemoteBlockChange(
                    blockID: "block-remote",
                    pageID: "page-remote",
                    type: .paragraph,
                    textPlain: "Remote body",
                    payloadJSON: "{\"text\":\"Remote body\"}",
                    revision: 1,
                    orderKey: "000001"
                )
            ]
        )

        let result = try SyncEngine(
            syncRepository: SyncRepository(database: database),
            adapter: RecordingCloudKitSyncAdapter(),
            remoteChangeFetcher: fetcher,
            mergeEngine: SyncMergeEngine(database: database)
        ).fetchRemoteChanges()
        let snapshot = try PageRepository(database: database).loadWorkspaceSnapshot()

        XCTAssertEqual(result.appliedCount, 5)
        XCTAssertEqual(snapshot.workspaces, [WorkspaceSummary(id: "workspace-remote", name: "Remote")])
        XCTAssertEqual(snapshot.notebooks, [
            NotebookSummary(id: "notebook-remote", workspaceID: "workspace-remote", name: "Projects")
        ])
        let page = try XCTUnwrap(snapshot.pages.first)
        XCTAssertEqual(snapshot.pages.count, 1)
        XCTAssertEqual(page.id, "page-remote")
        XCTAssertEqual(page.workspaceID, "workspace-remote")
        XCTAssertEqual(page.notebookID, "notebook-remote")
        XCTAssertEqual(page.title, "Roadmap")
        XCTAssertEqual(page.isFavorite, true)
        XCTAssertNotNil(page.updatedAt)
        XCTAssertEqual(snapshot.favoritePages.map(\.id), ["page-remote"])
        XCTAssertEqual(snapshot.blocks.map(\.textPlain), ["Remote body"])
        XCTAssertEqual(snapshot.attachments.map(\.originalFilename), ["brief.pdf"])
    }

    func testFetchRemoteChangesReportsEntityIDWhenRemoteApplyFails() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let fetcher = StaticRemoteBlockChangeFetcher(
            changes: [
                RemoteBlockChange(
                    blockID: "block-orphan",
                    pageID: "missing-page",
                    type: .paragraph,
                    textPlain: "Remote body",
                    payloadJSON: "{\"text\":\"Remote body\"}",
                    revision: 1,
                    orderKey: "000001"
                )
            ]
        )

        XCTAssertThrowsError(
            try SyncEngine(
                syncRepository: SyncRepository(database: database),
                adapter: RecordingCloudKitSyncAdapter(),
                remoteChangeFetcher: fetcher,
                mergeEngine: SyncMergeEngine(database: database)
            ).fetchRemoteChanges()
        ) { error in
            let applyError = error as? SyncRemoteApplyError
            XCTAssertEqual(applyError?.entityType, "block")
            XCTAssertEqual(applyError?.entityID, "block-orphan")
            XCTAssertEqual(applyError?.details, "page_id=missing-page parent_block_id=nil")
            XCTAssertEqual(
                applyError?.description,
                "remote_apply_failed entity_type=block entity_id=block-orphan page_id=missing-page parent_block_id=nil error=Step failed: FOREIGN KEY constraint failed"
            )
        }
    }

    func testFetchRemoteChangesAppliesParentBlocksBeforeChildrenFromSameBatch() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let fetcher = StaticRemoteBlockChangeFetcher(
            workspaceChanges: [
                RemoteWorkspaceChange(workspaceID: "workspace-remote", name: "Remote")
            ],
            pageChanges: [
                RemotePageChange(
                    pageID: "page-remote",
                    workspaceID: "workspace-remote",
                    notebookID: nil,
                    title: "Roadmap",
                    orderKey: "000001",
                    isArchived: false
                )
            ],
            changes: [
                RemoteBlockChange(
                    blockID: "block-child",
                    pageID: "page-remote",
                    type: .paragraph,
                    textPlain: "Child",
                    payloadJSON: "{\"text\":\"Child\"}",
                    revision: 1,
                    parentBlockID: "block-parent",
                    orderKey: "000002"
                ),
                RemoteBlockChange(
                    blockID: "block-parent",
                    pageID: "page-remote",
                    type: .paragraph,
                    textPlain: "Parent",
                    payloadJSON: "{\"text\":\"Parent\"}",
                    revision: 1,
                    orderKey: "000001"
                )
            ]
        )

        _ = try SyncEngine(
            syncRepository: SyncRepository(database: database),
            adapter: RecordingCloudKitSyncAdapter(),
            remoteChangeFetcher: fetcher,
            mergeEngine: SyncMergeEngine(database: database)
        ).fetchRemoteChanges()

        let childRow = try XCTUnwrap(
            try database.query(
                "SELECT parent_block_id FROM blocks WHERE id = ? LIMIT 1",
                bindings: [.text("block-child")]
            ).first
        )
        XCTAssertEqual(childRow["parent_block_id"], "block-parent")
    }

    func testFetchRemoteChangesReparentsBlockToRootWhenRemoteParentIsMissing() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let fetcher = StaticRemoteBlockChangeFetcher(
            workspaceChanges: [
                RemoteWorkspaceChange(workspaceID: "workspace-remote", name: "Remote")
            ],
            pageChanges: [
                RemotePageChange(
                    pageID: "page-remote",
                    workspaceID: "workspace-remote",
                    notebookID: nil,
                    title: "Roadmap",
                    orderKey: "000001",
                    isArchived: false
                )
            ],
            changes: [
                RemoteBlockChange(
                    blockID: "block-orphan-child",
                    pageID: "page-remote",
                    type: .paragraph,
                    textPlain: "Child",
                    payloadJSON: "{\"text\":\"Child\"}",
                    revision: 1,
                    parentBlockID: "block-missing-parent",
                    orderKey: "000002"
                )
            ],
            serverChangeTokenData: Data("next-token".utf8)
        )

        let result = try SyncEngine(
            syncRepository: SyncRepository(database: database),
            adapter: RecordingCloudKitSyncAdapter(),
            remoteChangeFetcher: fetcher,
            mergeEngine: SyncMergeEngine(database: database)
        ).fetchRemoteChanges()

        let childRow = try XCTUnwrap(
            try database.query(
                "SELECT parent_block_id FROM blocks WHERE id = ? LIMIT 1",
                bindings: [.text("block-orphan-child")]
            ).first
        )
        XCTAssertNil(childRow["parent_block_id"] ?? nil)
        XCTAssertEqual(result.appliedCount, 3)
        XCTAssertNotNil(try SyncRepository(database: database).serverChangeTokenData(scope: "privateDatabase"))
    }

    func testFetchRemoteChangesPersistsNestedNotebookParent() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let fetcher = StaticRemoteBlockChangeFetcher(
            workspaceChanges: [
                RemoteWorkspaceChange(workspaceID: "workspace-remote", name: "Remote")
            ],
            notebookChanges: [
                RemoteNotebookChange(
                    notebookID: "notebook-parent",
                    workspaceID: "workspace-remote",
                    name: "Projects",
                    orderKey: "000001"
                ),
                RemoteNotebookChange(
                    notebookID: "notebook-child",
                    workspaceID: "workspace-remote",
                    parentNotebookID: "notebook-parent",
                    name: "Client A",
                    orderKey: "000001"
                )
            ],
            changes: []
        )

        _ = try SyncEngine(
            syncRepository: SyncRepository(database: database),
            adapter: RecordingCloudKitSyncAdapter(),
            remoteChangeFetcher: fetcher,
            mergeEngine: SyncMergeEngine(database: database)
        ).fetchRemoteChanges()
        let snapshot = try PageRepository(database: database).loadWorkspaceSnapshot()

        XCTAssertEqual(
            snapshot.notebooks.first { $0.id == "notebook-child" }?.parentNotebookID,
            "notebook-parent"
        )
    }

    func testCloudKitPrivateDatabaseAdapterMapsRemoteRecordsToChangeSet() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let fetcher = StaticCloudKitRecordFetcher(recordsByType: [
            "WorkspaceRecord": [
                makeRecord(type: "WorkspaceRecord", entityType: "workspace", entityID: "workspace-remote") {
                    $0["name"] = "Remote" as CKRecordValue
                }
            ],
            "NotebookRecord": [
                makeRecord(type: "NotebookRecord", entityType: "notebook", entityID: "notebook-remote") {
                    $0["workspaceID"] = "workspace-remote" as CKRecordValue
                    $0["name"] = "Projects" as CKRecordValue
                    $0["orderKey"] = "000001" as CKRecordValue
                }
            ],
            "PageRecord": [
                makeRecord(type: "PageRecord", entityType: "page", entityID: "page-remote") {
                    $0["workspaceID"] = "workspace-remote" as CKRecordValue
                    $0["notebookID"] = "notebook-remote" as CKRecordValue
                    $0["title"] = "Roadmap" as CKRecordValue
                    $0["orderKey"] = "000001" as CKRecordValue
                    $0["isArchived"] = NSNumber(value: false)
                    $0["isFavorite"] = NSNumber(value: true)
                    $0["isEncrypted"] = NSNumber(value: true)
                }
            ],
            "AttachmentRecord": [
                makeRecord(type: "AttachmentRecord", entityType: "attachment", entityID: "attachment-remote") {
                    $0["workspaceID"] = "workspace-remote" as CKRecordValue
                    $0["originalFilename"] = "brief.pdf" as CKRecordValue
                    $0["utiType"] = "com.adobe.pdf" as CKRecordValue
                    $0["byteSize"] = NSNumber(value: 128)
                    $0["contentHash"] = "hash-remote" as CKRecordValue
                    $0["localPath"] = "/remote/brief.pdf" as CKRecordValue
                }
            ],
            "BlockRecord": [
                makeRecord(type: "BlockRecord", entityType: "block", entityID: "block-remote") {
                    $0["pageID"] = "page-remote" as CKRecordValue
                    $0["orderKey"] = "000001" as CKRecordValue
                    $0["type"] = BlockType.paragraph.rawValue as CKRecordValue
                    $0["payloadJSON"] = "{\"text\":\"Remote body\"}" as CKRecordValue
                    $0["textPlain"] = "Remote body" as CKRecordValue
                    $0["revision"] = NSNumber(value: 1)
                }
            ]
        ])

        let changeSet = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordFetcher: fetcher
        ).fetchRemoteChanges(sinceServerChangeTokenData: nil)

        XCTAssertEqual(changeSet.workspaceChanges.map(\.workspaceID), ["workspace-remote"])
        XCTAssertEqual(changeSet.notebookChanges.map(\.notebookID), ["notebook-remote"])
        XCTAssertEqual(changeSet.pageChanges.map(\.pageID), ["page-remote"])
        XCTAssertEqual(changeSet.pageChanges.first?.isFavorite, true)
        XCTAssertEqual(changeSet.pageChanges.first?.isEncrypted, true)
        XCTAssertEqual(changeSet.attachmentChanges.map(\.attachmentID), ["attachment-remote"])
        XCTAssertEqual(changeSet.blockChanges.map(\.blockID), ["block-remote"])
    }

    func testCloudKitPrivateDatabaseAdapterIgnoresRecordsFromPreviousSyncGeneration() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let fetcher = StaticCloudKitRecordFetcher(recordsByType: [
            "WorkspaceRecord": [
                makeRecord(
                    type: "WorkspaceRecord",
                    entityType: "workspace",
                    entityID: "workspace-old",
                    syncGeneration: nil
                ) {
                    $0["name"] = "Old Missing Generation" as CKRecordValue
                },
                makeRecord(
                    type: "WorkspaceRecord",
                    entityType: "workspace",
                    entityID: "workspace-previous",
                    syncGeneration: "editor-cloudkit-previous"
                ) {
                    $0["name"] = "Old Explicit Generation" as CKRecordValue
                },
                makeRecord(
                    type: "WorkspaceRecord",
                    entityType: "workspace",
                    entityID: "workspace-v1",
                    syncGeneration: "editor-cloudkit-v1"
                ) {
                    $0["name"] = "Old v1 Generation" as CKRecordValue
                }
            ]
        ])

        let changeSet = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordFetcher: fetcher
        ).fetchRemoteChanges(sinceServerChangeTokenData: nil)

        XCTAssertEqual(changeSet.workspaceChanges, [])
    }

    func testCloudKitPrivateDatabaseAdapterMapsRemoteNotebookParentFromRecord() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let fetcher = StaticCloudKitRecordFetcher(recordsByType: [
            "NotebookRecord": [
                makeRecord(type: "NotebookRecord", entityType: "notebook", entityID: "notebook-child") {
                    $0["workspaceID"] = "workspace-remote" as CKRecordValue
                    $0["parentNotebookID"] = "notebook-parent" as CKRecordValue
                    $0["name"] = "Client A" as CKRecordValue
                    $0["orderKey"] = "000001" as CKRecordValue
                }
            ]
        ])

        let changeSet = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordFetcher: fetcher
        ).fetchRemoteChanges(sinceServerChangeTokenData: nil)

        XCTAssertEqual(changeSet.notebookChanges.first?.parentNotebookID, "notebook-parent")
    }


    func testCloudKitPrivateDatabaseAdapterDownloadsAttachmentAssets() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let assetURL = try makeSourceFile(name: "brief.pdf", contents: "remote asset")
        let downloadDirectory = makeTemporaryDirectory()
        let fetcher = StaticCloudKitRecordFetcher(recordsByType: [
            "AttachmentRecord": [
                makeRecord(type: "AttachmentRecord", entityType: "attachment", entityID: "attachment-remote") {
                    $0["workspaceID"] = "workspace-remote" as CKRecordValue
                    $0["originalFilename"] = "brief.pdf" as CKRecordValue
                    $0["utiType"] = "com.adobe.pdf" as CKRecordValue
                    $0["byteSize"] = NSNumber(value: 12)
                    $0["contentHash"] = "hash-remote" as CKRecordValue
                    $0["localPath"] = "/remote/brief.pdf" as CKRecordValue
                    $0["asset"] = CKAsset(fileURL: assetURL)
                }
            ]
        ])

        let changeSet = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordFetcher: fetcher,
            attachmentDownloadDirectory: downloadDirectory
        ).fetchRemoteChanges(sinceServerChangeTokenData: nil)
        let attachment = try XCTUnwrap(changeSet.attachmentChanges.first)

        XCTAssertNotEqual(attachment.localPath, "/remote/brief.pdf")
        XCTAssertTrue(attachment.localPath.hasPrefix(downloadDirectory.path))
        XCTAssertEqual(
            try String(contentsOfFile: attachment.localPath, encoding: .utf8),
            "remote asset"
        )
    }

    func testCloudKitPrivateDatabaseAdapterDoesNotReuseRemoteLocalPathWithoutAsset() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let downloadDirectory = makeTemporaryDirectory()
        let fetcher = StaticCloudKitRecordFetcher(recordsByType: [
            "AttachmentRecord": [
                makeRecord(type: "AttachmentRecord", entityType: "attachment", entityID: "attachment-remote") {
                    $0["workspaceID"] = "workspace-remote" as CKRecordValue
                    $0["originalFilename"] = "photo.png" as CKRecordValue
                    $0["utiType"] = "public.png" as CKRecordValue
                    $0["byteSize"] = NSNumber(value: 12)
                    $0["contentHash"] = "hash-remote" as CKRecordValue
                    $0["localPath"] = "/remote/photo.png" as CKRecordValue
                }
            ]
        ])

        let changeSet = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordFetcher: fetcher,
            attachmentDownloadDirectory: downloadDirectory
        ).fetchRemoteChanges(sinceServerChangeTokenData: nil)
        let attachment = try XCTUnwrap(changeSet.attachmentChanges.first)

        XCTAssertEqual(attachment.localPath, "")
    }

    func testCloudKitPrivateDatabaseAdapterDownloadsAttachmentThumbnailAssets() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let assetURL = try makeSourceFile(name: "brief.pdf", contents: "remote asset")
        let thumbnailAssetURL = try makeSourceFile(name: "thumbnail.jpg", contents: "remote thumbnail")
        let downloadDirectory = makeTemporaryDirectory()
        let fetcher = StaticCloudKitRecordFetcher(recordsByType: [
            "AttachmentRecord": [
                makeRecord(type: "AttachmentRecord", entityType: "attachment", entityID: "attachment-remote") {
                    $0["workspaceID"] = "workspace-remote" as CKRecordValue
                    $0["originalFilename"] = "brief.pdf" as CKRecordValue
                    $0["utiType"] = "com.adobe.pdf" as CKRecordValue
                    $0["byteSize"] = NSNumber(value: 12)
                    $0["contentHash"] = "hash-remote" as CKRecordValue
                    $0["localPath"] = "/remote/brief.pdf" as CKRecordValue
                    $0["thumbnailPath"] = "/remote/thumbnail.jpg" as CKRecordValue
                    $0["asset"] = CKAsset(fileURL: assetURL)
                    $0["thumbnailAsset"] = CKAsset(fileURL: thumbnailAssetURL)
                }
            ]
        ])

        let changeSet = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordFetcher: fetcher,
            attachmentDownloadDirectory: downloadDirectory
        ).fetchRemoteChanges(sinceServerChangeTokenData: nil)
        let attachment = try XCTUnwrap(changeSet.attachmentChanges.first)
        let thumbnailPath = try XCTUnwrap(attachment.thumbnailPath)

        XCTAssertNotEqual(thumbnailPath, "/remote/thumbnail.jpg")
        XCTAssertTrue(thumbnailPath.hasPrefix(downloadDirectory.path))
        XCTAssertEqual(
            try String(contentsOfFile: thumbnailPath, encoding: .utf8),
            "remote thumbnail"
        )
    }

    func testCloudKitPrivateDatabaseAdapterMapsDeletedRecordIDsToDeletionChanges() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let nextToken = Data("next-token".utf8)
        let fetcher = TokenAwareCloudKitRecordFetcher(
            recordsByType: [:],
            deletedRecordIDsByType: [
                "NotebookRecord": [
                    CKRecord.ID(recordName: "editor-cloudkit-v2.notebook.notebook-remote")
                ],
                "PageRecord": [
                    CKRecord.ID(recordName: "editor-cloudkit-v2.page.page-remote")
                ],
                "AttachmentRecord": [
                    CKRecord.ID(recordName: "editor-cloudkit-v2.attachment.attachment-remote")
                ],
                "BlockRecord": [
                    CKRecord.ID(recordName: "editor-cloudkit-v2.block.block-remote")
                ]
            ],
            nextServerChangeTokenData: nextToken
        )

        let changeSet = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordFetcher: fetcher
        ).fetchRemoteChanges(sinceServerChangeTokenData: nil)

        XCTAssertEqual(changeSet.deletedRecords, [
            RemoteDeletedRecord(entityType: "notebook", entityID: "notebook-remote"),
            RemoteDeletedRecord(entityType: "page", entityID: "page-remote"),
            RemoteDeletedRecord(entityType: "attachment", entityID: "attachment-remote"),
            RemoteDeletedRecord(entityType: "block", entityID: "block-remote")
        ])
        XCTAssertEqual(changeSet.serverChangeTokenData, nextToken)
    }

    func testCloudKitPrivateDatabaseAdapterIgnoresDeletedRecordIDsFromPreviousSyncGeneration() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let fetcher = TokenAwareCloudKitRecordFetcher(
            recordsByType: [:],
            deletedRecordIDsByType: [
                "PageRecord": [CKRecord.ID(recordName: "page-page-old")]
            ],
            nextServerChangeTokenData: Data("token-v2".utf8)
        )

        let changeSet = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordFetcher: fetcher
        ).fetchRemoteChanges(sinceServerChangeTokenData: nil)

        XCTAssertEqual(changeSet.deletedRecords, [])
    }

    func testCloudKitPrivateDatabaseAdapterDeletesAllKnownRecordTypesForFreshStart() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let workspaceRecord = makeRecord(
            type: "WorkspaceRecord",
            entityType: "workspace",
            entityID: "workspace-old",
            syncGeneration: nil
        ) {
            $0["name"] = "Old" as CKRecordValue
        }
        let pageRecord = makeRecord(type: "PageRecord", entityType: "page", entityID: "page-current") {
            $0["workspaceID"] = "workspace-old" as CKRecordValue
            $0["title"] = "Current" as CKRecordValue
            $0["orderKey"] = "000001" as CKRecordValue
            $0["isArchived"] = NSNumber(value: false)
        }
        let fetcher = StaticCloudKitRecordFetcher(recordsByType: [
            "WorkspaceRecord": [workspaceRecord],
            "PageRecord": [pageRecord]
        ])
        let deleter = CapturingCloudKitRecordDeleter()

        let deletedCount = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordDeleter: deleter,
            recordFetcher: fetcher
        ).resetRemoteDataForFreshStart()

        XCTAssertEqual(deletedCount, 2)
        XCTAssertEqual(
            deleter.deletedRecordIDs.map(\.recordName),
            [
                workspaceRecord.recordID.recordName,
                pageRecord.recordID.recordName
            ]
        )
    }

    func testCloudKitPrivateDatabaseAdapterUsesTokenAwareRecordChangeFetcher() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let previousToken = Data("previous-token".utf8)
        let nextToken = Data("next-token".utf8)
        let fetcher = TokenAwareCloudKitRecordFetcher(
            recordsByType: [
                "WorkspaceRecord": [
                    makeRecord(type: "WorkspaceRecord", entityType: "workspace", entityID: "workspace-token") {
                        $0["name"] = "Token Remote" as CKRecordValue
                    }
                ]
            ],
            nextServerChangeTokenData: nextToken
        )

        let changeSet = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordFetcher: fetcher
        ).fetchRemoteChanges(sinceServerChangeTokenData: previousToken)

        XCTAssertEqual(fetcher.receivedServerChangeTokenData, previousToken)
        XCTAssertEqual(fetcher.fetchRecordsCalls, [])
        XCTAssertEqual(changeSet.serverChangeTokenData, nextToken)
        XCTAssertEqual(changeSet.workspaceChanges, [
            RemoteWorkspaceChange(workspaceID: "workspace-token", name: "Token Remote")
        ])
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
        XCTAssertEqual(record.recordID.recordName, "editor-cloudkit-v2.block.\(blockID)")
        XCTAssertEqual(record.recordID.zoneID.zoneName, CloudKitSyncConfiguration.recordZoneName)
        XCTAssertEqual(record["entityID"] as? String, blockID)
        XCTAssertEqual(record["syncGeneration"] as? String, "editor-cloudkit-v2")
        XCTAssertEqual(record["textPlain"] as? String, "Cloud text")
        XCTAssertEqual(record["type"] as? String, BlockType.paragraph.rawValue)
        XCTAssertEqual(result.recordName, "editor-cloudkit-v2.block.\(blockID)")
    }

    func testLiveCloudKitRecordSaverUsesOverwriteSavePolicyForIdempotentUploads() {
        let record = CKRecord(
            recordType: "PageRecord",
            recordID: CKRecord.ID(
                recordName: "editor-cloudkit-v2.page.page-existing",
                zoneID: CloudKitSyncConfiguration.recordZoneID
            )
        )

        let operation = LiveCloudKitRecordSaver.makeSaveOperation(record: record)

        XCTAssertEqual(operation.recordsToSave?.count, 1)
        XCTAssertEqual(operation.recordsToSave?.first?.recordID.recordName, record.recordID.recordName)
        XCTAssertEqual(operation.savePolicy, .allKeys)
        XCTAssertFalse(operation.isAtomic)
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
        XCTAssertEqual(record.recordID.recordName, "editor-cloudkit-v2.notebook.\(notebook.id)")
        XCTAssertEqual(record["entityID"] as? String, notebook.id)
        XCTAssertEqual(record["syncGeneration"] as? String, "editor-cloudkit-v2")
        XCTAssertEqual(record["workspaceID"] as? String, workspaceID)
        XCTAssertEqual(record["name"] as? String, "Projects")
        XCTAssertEqual(result.recordName, "editor-cloudkit-v2.notebook.\(notebook.id)")
    }

    func testCloudKitPrivateDatabaseAdapterMapsNestedNotebookParentToRecord() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let parent = try pageRepository.createNotebook(workspaceID: workspaceID, name: "Projects")
        let child = try pageRepository.createNotebook(
            workspaceID: workspaceID,
            name: "Client A",
            parentNotebookID: parent.id
        )
        let saver = CapturingCloudKitRecordSaver()

        _ = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordSaver: saver
        ).upload(change: SyncChange(entityType: "notebook", entityID: child.id, changeType: "create"))

        let record = try XCTUnwrap(saver.savedRecords.first)
        XCTAssertEqual(record["parentNotebookID"] as? String, parent.id)
    }

    func testCloudKitPrivateDatabaseAdapterMapsPageFavoriteAndEncryptionToRecord() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let cipher = EncryptedNoteCipher(
            metadataStore: KeychainMetadataStore(service: "com.liangzhang.editor.tests.\(UUID().uuidString)")
        )
        let pageRepository = PageRepository(database: database, encryptedNoteCipher: cipher)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try pageRepository.updatePageFavorite(pageID: pageID, isFavorite: true)
        try pageRepository.updatePageEncryption(pageID: pageID, isEncrypted: true)
        let saver = CapturingCloudKitRecordSaver()

        _ = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordSaver: saver
        ).upload(change: SyncChange(entityType: "page", entityID: pageID, changeType: "update"))

        let record = try XCTUnwrap(saver.savedRecords.first)
        XCTAssertEqual(record.recordType, "PageRecord")
        XCTAssertEqual(record["entityID"] as? String, pageID)
        XCTAssertEqual((record["isFavorite"] as? NSNumber)?.boolValue, true)
        XCTAssertEqual((record["isEncrypted"] as? NSNumber)?.boolValue, true)
        XCTAssertEqual((record["isArchived"] as? NSNumber)?.boolValue, false)
        XCTAssertTrue((record["title"] as? String)?.hasPrefix(EncryptedNoteCipher.ciphertextPrefix) == true)
    }

    func testCloudKitPrivateDatabaseAdapterMapsAttachmentAssetsToRecord() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let imported = try AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        ).importAttachment(
            sourceURL: try makeSourceFile(name: "brief.txt", contents: "local asset"),
            workspaceID: workspaceID,
            pageID: pageID
        )
        let thumbnailURL = URL(fileURLWithPath: imported.attachment.localPath)
            .deletingLastPathComponent()
            .appendingPathComponent("thumbnail.jpg")
        try Data("thumbnail asset".utf8).write(to: thumbnailURL)
        try database.execute(
            """
            UPDATE attachments
            SET thumbnail_path = ?
            WHERE id = ?
            """,
            bindings: [
                .text(thumbnailURL.path),
                .text(imported.attachment.id)
            ]
        )
        let saver = CapturingCloudKitRecordSaver()

        _ = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordSaver: saver
        ).upload(change: SyncChange(entityType: "attachment", entityID: imported.attachment.id, changeType: "create"))

        let record = try XCTUnwrap(saver.savedRecords.first)
        let asset = try XCTUnwrap(record["asset"] as? CKAsset)
        let thumbnailAsset = try XCTUnwrap(record["thumbnailAsset"] as? CKAsset)
        XCTAssertEqual(asset.fileURL?.path, imported.attachment.localPath)
        XCTAssertEqual(thumbnailAsset.fileURL?.path, thumbnailURL.path)
    }

    func testCloudKitPrivateDatabaseAdapterDeletesRecordForDeleteChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let deleter = CapturingCloudKitRecordDeleter()

        let result = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordDeleter: deleter
        ).upload(change: SyncChange(entityType: "page", entityID: "page-old", changeType: "delete"))

        XCTAssertEqual(deleter.deletedRecordIDs.map(\.recordName), ["editor-cloudkit-v2.page.page-old"])
        XCTAssertEqual(deleter.deletedRecordIDs.map(\.zoneID.zoneName), [CloudKitSyncConfiguration.recordZoneName])
        XCTAssertEqual(result.recordName, "editor-cloudkit-v2.page.page-old")
        XCTAssertNil(result.changeTag)
    }

    func testCloudKitPrivateDatabaseAdapterTreatsMissingRemoteRecordDeleteAsSuccess() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let deleter = FailingCloudKitRecordDeleter(error: NSError(
            domain: CKErrorDomain,
            code: CKError.unknownItem.rawValue
        ))

        let result = try CloudKitPrivateDatabaseAdapter(
            database: database,
            recordDeleter: deleter
        ).upload(change: SyncChange(entityType: "page", entityID: "page-local-only", changeType: "delete"))

        XCTAssertEqual(deleter.deletedRecordIDs.map(\.recordName), ["editor-cloudkit-v2.page.page-local-only"])
        XCTAssertEqual(deleter.deletedRecordIDs.map(\.zoneID.zoneName), [CloudKitSyncConfiguration.recordZoneName])
        XCTAssertEqual(result.recordName, "editor-cloudkit-v2.page.page-local-only")
        XCTAssertNil(result.changeTag)
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

    private func makeSourceFile(name: String, contents: String) throws -> URL {
        let directory = makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent(name)
        try Data(contents.utf8).write(to: fileURL)
        return fileURL
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
    let workspaceChanges: [RemoteWorkspaceChange]
    let notebookChanges: [RemoteNotebookChange]
    let pageChanges: [RemotePageChange]
    let attachmentChanges: [RemoteAttachmentChange]
    let changes: [RemoteBlockChange]
    let deletedRecords: [RemoteDeletedRecord]
    let serverChangeTokenData: Data?
    private(set) var receivedServerChangeTokenData: Data?

    init(
        workspaceChanges: [RemoteWorkspaceChange] = [],
        notebookChanges: [RemoteNotebookChange] = [],
        pageChanges: [RemotePageChange] = [],
        attachmentChanges: [RemoteAttachmentChange] = [],
        changes: [RemoteBlockChange],
        deletedRecords: [RemoteDeletedRecord] = [],
        serverChangeTokenData: Data? = nil
    ) {
        self.workspaceChanges = workspaceChanges
        self.notebookChanges = notebookChanges
        self.pageChanges = pageChanges
        self.attachmentChanges = attachmentChanges
        self.changes = changes
        self.deletedRecords = deletedRecords
        self.serverChangeTokenData = serverChangeTokenData
    }

    func fetchRemoteChanges(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitRemoteChangeSet {
        receivedServerChangeTokenData = serverChangeTokenData
        return CloudKitRemoteChangeSet(
            workspaceChanges: workspaceChanges,
            notebookChanges: notebookChanges,
            pageChanges: pageChanges,
            attachmentChanges: attachmentChanges,
            blockChanges: changes,
            deletedRecords: deletedRecords,
            serverChangeTokenData: self.serverChangeTokenData
        )
    }
}

final class ExpiringThenSucceedingRemoteChangeFetcher: CloudKitRemoteChangeFetching {
    let serverChangeTokenDataAfterRetry: Data?
    private(set) var receivedServerChangeTokenData: [Data?] = []

    init(serverChangeTokenDataAfterRetry: Data?) {
        self.serverChangeTokenDataAfterRetry = serverChangeTokenDataAfterRetry
    }

    func fetchRemoteChanges(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitRemoteChangeSet {
        receivedServerChangeTokenData.append(serverChangeTokenData)
        if serverChangeTokenData != nil {
            throw NSError(
                domain: CKErrorDomain,
                code: CKError.changeTokenExpired.rawValue
            )
        }

        return CloudKitRemoteChangeSet(serverChangeTokenData: serverChangeTokenDataAfterRetry)
    }
}

final class AlwaysFailingRemoteChangeFetcher: CloudKitRemoteChangeFetching {
    let error: Error
    private(set) var receivedServerChangeTokenData: [Data?] = []

    init(error: Error) {
        self.error = error
    }

    func fetchRemoteChanges(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitRemoteChangeSet {
        receivedServerChangeTokenData.append(serverChangeTokenData)
        throw error
    }
}

enum SyncEngineTestError: Error, CustomStringConvertible {
    case temporaryUnavailable

    var description: String {
        "temporaryUnavailable"
    }
}

final class RuntimeProbeCallRecorder {
    private(set) var calls: [String] = []

    func append(_ call: String) {
        calls.append(call)
    }
}

final class RecordingCloudKitAccountStatusProvider: CloudKitAccountStatusProviding {
    private let status: CKAccountStatus
    private let recorder: RuntimeProbeCallRecorder?

    init(
        status: CKAccountStatus = .available,
        recorder: RuntimeProbeCallRecorder? = nil
    ) {
        self.status = status
        self.recorder = recorder
    }

    func accountStatus() throws -> CKAccountStatus {
        recorder?.append("accountStatus")
        return status
    }
}

final class CapturingCloudKitDatabaseInspector: CloudKitDatabaseInspecting {
    private let recorder: RuntimeProbeCallRecorder?

    init(recorder: RuntimeProbeCallRecorder? = nil) {
        self.recorder = recorder
    }

    func fetchAllRecordZones() throws -> [CKRecordZone] {
        recorder?.append("fetchAllRecordZones")
        return [CKRecordZone.default()]
    }

    func fetchAllSubscriptions() throws -> [CKSubscription] {
        recorder?.append("fetchAllSubscriptions")
        return []
    }
}

final class CapturingCloudKitRecordZoneEnsurer: CloudKitRecordZoneEnsuring {
    private let recorder: RuntimeProbeCallRecorder?
    private(set) var ensureCallCount = 0

    init(recorder: RuntimeProbeCallRecorder? = nil) {
        self.recorder = recorder
    }

    func ensureRecordZoneExists() throws {
        recorder?.append("ensureRecordZoneExists")
        ensureCallCount += 1
    }
}

final class CapturingCloudKitRecordSaver: CloudKitRecordSaving {
    private(set) var savedRecords: [CKRecord] = []
    private let recorder: RuntimeProbeCallRecorder?

    init(recorder: RuntimeProbeCallRecorder? = nil) {
        self.recorder = recorder
    }

    func save(record: CKRecord) throws -> CKRecord {
        recorder?.append("save:\(record.recordID.recordName)")
        savedRecords.append(record)
        return record
    }
}

final class FailingCloudKitRecordSaver: CloudKitRecordSaving {
    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func save(record: CKRecord) throws -> CKRecord {
        throw error
    }
}

final class CapturingCloudKitRecordReader: CloudKitRecordReading {
    private(set) var fetchedRecordIDs: [CKRecord.ID] = []
    private let recorder: RuntimeProbeCallRecorder?

    init(recorder: RuntimeProbeCallRecorder? = nil) {
        self.recorder = recorder
    }

    func fetch(recordID: CKRecord.ID) throws -> CKRecord {
        recorder?.append("fetch:\(recordID.recordName)")
        fetchedRecordIDs.append(recordID)
        return CKRecord(recordType: "EditorRuntimeProbeRecord", recordID: recordID)
    }
}

final class CapturingCloudKitRecordDeleter: CloudKitRecordDeleting {
    private(set) var deletedRecordIDs: [CKRecord.ID] = []
    private let recorder: RuntimeProbeCallRecorder?

    init(recorder: RuntimeProbeCallRecorder? = nil) {
        self.recorder = recorder
    }

    func delete(recordID: CKRecord.ID) throws {
        recorder?.append("delete:\(recordID.recordName)")
        deletedRecordIDs.append(recordID)
    }
}

final class FailingCloudKitRecordDeleter: CloudKitRecordDeleting {
    private let error: Error
    private(set) var deletedRecordIDs: [CKRecord.ID] = []

    init(error: Error) {
        self.error = error
    }

    func delete(recordID: CKRecord.ID) throws {
        deletedRecordIDs.append(recordID)
        throw error
    }
}

final class CapturingCloudKitSubscriptionSaver: CloudKitSubscriptionSaving {
    private(set) var savedSubscriptions: [CKSubscription] = []

    func save(subscription: CKSubscription) throws -> CKSubscription {
        savedSubscriptions.append(subscription)
        return subscription
    }
}

final class RecordingCloudKitSubscriptionEnsurer: CloudKitSubscriptionEnsuring {
    private(set) var ensureCallCount = 0

    func ensureRemoteChangeSubscription() throws {
        ensureCallCount += 1
    }
}

final class RecordingRemoteNotificationRegistrar: RemoteNotificationRegistering {
    private(set) var registerCallCount = 0

    func registerForRemoteNotifications() {
        registerCallCount += 1
    }
}

enum RemoteNotificationSyncCall: Equatable {
    case ensureRemoteChangeSubscription
    case uploadPendingChanges
    case fetchRemoteChanges
}

final class RecordingRemoteNotificationSyncer: RemoteNotificationSyncing {
    private let uploadSummary: SyncUploadSummary
    private let fetchSummary: SyncFetchSummary
    private let errorAfterCall: RemoteNotificationSyncCall?
    private(set) var calls: [RemoteNotificationSyncCall] = []

    init(
        uploadSummary: SyncUploadSummary,
        fetchSummary: SyncFetchSummary,
        errorAfterCall: RemoteNotificationSyncCall? = nil
    ) {
        self.uploadSummary = uploadSummary
        self.fetchSummary = fetchSummary
        self.errorAfterCall = errorAfterCall
    }

    func ensureRemoteChangeSubscription() throws {
        calls.append(.ensureRemoteChangeSubscription)
        if errorAfterCall == .ensureRemoteChangeSubscription {
            throw SyncEngineTestError.temporaryUnavailable
        }
    }

    func uploadPendingChanges() throws -> SyncUploadSummary {
        calls.append(.uploadPendingChanges)
        if errorAfterCall == .uploadPendingChanges {
            throw SyncEngineTestError.temporaryUnavailable
        }
        return uploadSummary
    }

    func fetchRemoteChanges() throws -> SyncFetchSummary {
        calls.append(.fetchRemoteChanges)
        if errorAfterCall == .fetchRemoteChanges {
            throw SyncEngineTestError.temporaryUnavailable
        }
        return fetchSummary
    }
}

final class StaticCloudKitRecordFetcher: CloudKitRecordFetching {
    let recordsByType: [String: [CKRecord]]

    init(recordsByType: [String: [CKRecord]]) {
        self.recordsByType = recordsByType
    }

    func fetchRecords(recordType: String) throws -> [CKRecord] {
        recordsByType[recordType] ?? []
    }
}

final class TokenAwareCloudKitRecordFetcher: CloudKitRecordFetching {
    let recordsByType: [String: [CKRecord]]
    let deletedRecordIDsByType: [String: [CKRecord.ID]]
    let nextServerChangeTokenData: Data
    private(set) var receivedServerChangeTokenData: Data?
    private(set) var fetchRecordsCalls: [String] = []

    init(
        recordsByType: [String: [CKRecord]],
        deletedRecordIDsByType: [String: [CKRecord.ID]] = [:],
        nextServerChangeTokenData: Data
    ) {
        self.recordsByType = recordsByType
        self.deletedRecordIDsByType = deletedRecordIDsByType
        self.nextServerChangeTokenData = nextServerChangeTokenData
    }

    func fetchRecords(recordType: String) throws -> [CKRecord] {
        fetchRecordsCalls.append(recordType)
        return recordsByType[recordType] ?? []
    }

    func fetchRecordChanges(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitFetchedRecordChangeSet {
        receivedServerChangeTokenData = serverChangeTokenData
        return CloudKitFetchedRecordChangeSet(
            recordsByType: recordsByType,
            deletedRecordIDsByType: deletedRecordIDsByType,
            serverChangeTokenData: nextServerChangeTokenData
        )
    }
}

private func makeRecord(
    type: String,
    entityType: String,
    entityID: String,
    syncGeneration: String? = "editor-cloudkit-v2",
    configure: (CKRecord) -> Void
) -> CKRecord {
    let record = CKRecord(
        recordType: type,
        recordID: CKRecord.ID(
            recordName: "editor-cloudkit-v2.\(entityType).\(entityID)",
            zoneID: CloudKitSyncConfiguration.recordZoneID
        )
    )
    record["entityType"] = entityType as CKRecordValue
    record["entityID"] = entityID as CKRecordValue
    if let syncGeneration {
        record["syncGeneration"] = syncGeneration as CKRecordValue
    }
    configure(record)
    return record
}
