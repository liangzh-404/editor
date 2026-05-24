import SwiftUI

enum AppEnvironment {
    @MainActor
    static func makeRootView() -> some View {
#if DEBUG
        if CloudKitRuntimeProbeDiagnosticRequest(environment: ProcessInfo.processInfo.environment) != nil {
            return AnyView(CloudKitRuntimeProbeDiagnosticView())
        }
        if RemoteNotificationSyncDiagnosticRequest(environment: ProcessInfo.processInfo.environment) != nil {
            return AnyView(RemoteNotificationSyncDiagnosticView())
        }
        if CloudKitSyncDiagnosticRequest(environment: ProcessInfo.processInfo.environment) != nil {
            return AnyView(CloudKitSyncDiagnosticView())
        }
#endif

        do {
            return AnyView(EditorShellView(viewModel: try makeWorkspaceViewModel()))
        } catch {
            EditorLog.render.error(
                "app_startup_failed error=\(String(describing: error), privacy: .public)"
            )
            return AnyView(AppStartupFailureView(error: error))
        }
    }

    static func handleRemoteNotificationSync() -> RemoteNotificationSyncResult {
        do {
            let databasePath = try databasePath()
            let database = try SQLiteDatabase.open(path: databasePath)
            defer { database.close() }

            try SchemaMigrator.migrate(database: database)
            try DataProtectionService.applyNativeProtection(to: URL(fileURLWithPath: databasePath))
            _ = try PageRepository(database: database).bootstrapWorkspaceIfNeeded()
            try repairLocalStoreBeforeSync(database: database)

            let attachmentsDirectory = try attachmentsDirectory()
            try DataProtectionService.applyNativeProtectionRecursively(to: attachmentsDirectory)
            let syncEngine = makeCloudKitSyncEngine(
                database: database,
                attachmentsDirectory: attachmentsDirectory
            )
            let report = RemoteNotificationSyncHandler(syncer: syncEngine).handleRemoteNotificationReport()
            recordRuntimeDiagnostic(
                database: database,
                eventName: "remote_notification_sync_completed",
                payload: remoteNotificationSyncDiagnosticPayload(report)
            )
            return report.result
        } catch {
            EditorLog.sync.error(
                "remote_notification_environment_failed error=\(String(describing: error), privacy: .public)"
            )
            recordRuntimeDiagnostic(
                eventName: "remote_notification_environment_failed",
                payload: ["error": String(describing: error)]
            )
            return .failed
        }
    }

    @MainActor
    private static func makeWorkspaceViewModel() throws -> WorkspaceViewModel {
        try resetApplicationDataForUITestingIfNeeded()
        let databasePath = try databasePath()
        let database = try SQLiteDatabase.open(path: databasePath)
        try SchemaMigrator.migrate(database: database)
        try DataProtectionService.applyNativeProtection(to: URL(fileURLWithPath: databasePath))

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        try seedLargePageForUITestingIfNeeded(repository: repository, snapshot: snapshot)
        try seedReferenceTargetsForUITestingIfNeeded(repository: repository, snapshot: snapshot)
        try seedFavoritePageForUITestingIfNeeded(repository: repository, snapshot: snapshot)
        try seedTaggedPageForUITestingIfNeeded(snapshot: snapshot, tagRepository: TagRepository(database: database))
        try repairLocalStoreBeforeSync(database: database)
        let attachmentsDirectory = try attachmentsDirectory()
        try DataProtectionService.applyNativeProtectionRecursively(to: attachmentsDirectory)
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: attachmentsDirectory
        )
        try attachmentRepository.repairAttachmentFilePaths()
        try seedAttachmentForUITestingIfNeeded(
            attachmentRepository: attachmentRepository,
            snapshot: snapshot
        )
        try seedConflictForUITestingIfNeeded(
            repository: repository,
            conflictRepository: ConflictRepository(database: database),
            snapshot: snapshot
        )

        let viewModel = WorkspaceViewModel(
            repository: repository,
            diaryRepository: DiaryRepository(database: database),
            tagRepository: TagRepository(database: database),
            attachmentRepository: attachmentRepository,
            attachmentTextRecognitionRepository: AttachmentTextRecognitionRepository(database: database),
            imageTextRecognizer: VisionImageTextRecognizer(),
            searchRepository: SearchRepository(
                database: database,
                semanticProvider: LocalSemanticSearchProvider(database: database)
            ),
            backlinkRepository: BacklinkRepository(database: database),
            conflictRepository: ConflictRepository(database: database),
            obsidianImporter: ObsidianVaultImporter(
                database: database,
                attachmentsDirectory: attachmentsDirectory
            ),
            syncEngine: makeCloudKitSyncEngine(
                database: database,
                attachmentsDirectory: attachmentsDirectory
            ),
            cloudKitAccountMetadataService: makeCloudKitAccountMetadataService(),
            searchDebounceNanoseconds: 180_000_000
        )
        try viewModel.load()
        return viewModel
    }

    private static func makeCloudKitAccountMetadataService() -> CloudKitAccountMetadataService? {
        guard CloudKitEntitlementInspector.currentProcessHasCloudKitContainers() else {
            EditorLog.sync.debug("cloudkit_account_service_disabled reason=missing_entitlement")
            return nil
        }

        return CloudKitAccountMetadataService()
    }

    private static func repairLocalStoreBeforeSync(database: SQLiteDatabase) throws {
        let repairedTagCount = try TagRepository(database: database).repairDuplicateTags()
        try SyncRepository(database: database).enqueueUnsyncedLocalRecords()
        if repairedTagCount > 0 {
            EditorLog.sync.debug(
                "local_store_repaired duplicate_tags=\(repairedTagCount, privacy: .public)"
            )
        }
    }

    private static func makeCloudKitSyncEngine(
        database: SQLiteDatabase,
        attachmentsDirectory: URL
    ) -> SyncEngine? {
        guard CloudKitEntitlementInspector.currentProcessHasCloudKitContainers() else {
            EditorLog.sync.debug("cloudkit_sync_engine_disabled reason=missing_entitlement")
            return nil
        }

#if DEBUG
        CloudKitRuntimeProbe.runIfEnabled()
#endif

        let adapter = CloudKitPrivateDatabaseAdapter(
            database: database,
            recordFetcher: LiveCloudKitRecordFetcher(),
            attachmentDownloadDirectory: attachmentsDirectory
        )
        return SyncEngine(
            syncRepository: SyncRepository(database: database),
            adapter: adapter,
            remoteChangeFetcher: adapter,
            remoteSnapshotFetcher: adapter,
            mergeEngine: SyncMergeEngine(database: database),
            subscriptionEnsurer: CloudKitPrivateDatabaseSubscriptionEnsurer(),
            uploadBatchSize: 50,
            maximumUploadsPerRun: 250
        )
    }

#if DEBUG
    static func runCloudKitRuntimeProbeDiagnostic(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> CloudKitRuntimeProbeDiagnosticResult {
        guard CloudKitRuntimeProbeDiagnosticRequest(environment: environment) != nil else {
            return CloudKitRuntimeProbeDiagnosticResult(
                status: .skipped,
                recordName: nil,
                errorDescription: nil
            )
        }

        do {
            let databasePath = try databasePath()
            let database = try SQLiteDatabase.open(path: databasePath)
            defer { database.close() }

            try SchemaMigrator.migrate(database: database)
            try DataProtectionService.applyNativeProtection(to: URL(fileURLWithPath: databasePath))

            let result = CloudKitRuntimeProbe.run(
                accountStatusProvider: LiveCloudKitAccountStatusProvider(),
                zoneEnsurer: LiveCloudKitRecordZoneEnsurer.shared,
                databaseInspector: LiveCloudKitDatabaseInspector(),
                saver: LiveCloudKitRecordSaver(),
                reader: LiveCloudKitRecordFetcher(),
                deleter: LiveCloudKitRecordDeleter()
            )
            let eventName = result.isSuccess
                ? "cloudkit_runtime_probe_completed"
                : "cloudkit_runtime_probe_failed"
            var payload: [String: Any] = ["record_name": result.recordName]
            if let errorDescription = result.errorDescription {
                payload["error"] = errorDescription
            }
            recordRuntimeDiagnostic(
                database: database,
                eventName: eventName,
                payload: payload
            )
            return CloudKitRuntimeProbeDiagnosticResult(
                status: result.isSuccess ? .completed : .failed,
                recordName: result.recordName,
                errorDescription: result.errorDescription
            )
        } catch {
            let description = String(describing: error)
            recordRuntimeDiagnostic(
                eventName: "cloudkit_runtime_probe_failed",
                payload: ["error": description]
            )
            return CloudKitRuntimeProbeDiagnosticResult(
                status: .failed,
                recordName: nil,
                errorDescription: description
            )
        }
    }

    static func runCloudKitSyncDiagnostic(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> CloudKitSyncDiagnosticResult {
        guard let request = CloudKitSyncDiagnosticRequest(environment: environment) else {
            return CloudKitSyncDiagnosticResult(
                status: .skipped,
                appendedBlockID: nil,
                uploadedCount: 0,
                failedUploadCount: 0,
                fetchedCount: 0,
                pendingChangeCount: 0,
                errorDescription: nil
            )
        }

        do {
            let databasePath = try databasePath()
            let database = try SQLiteDatabase.open(path: databasePath)
            defer { database.close() }

            try SchemaMigrator.migrate(database: database)
            try DataProtectionService.applyNativeProtection(to: URL(fileURLWithPath: databasePath))

            let repository = PageRepository(database: database)
            let snapshot = try repository.bootstrapWorkspaceIfNeeded()
            try repairLocalStoreBeforeSync(database: database)
            let appendedBlockID: String?
            if let appendText = request.appendText {
                let pageID = request.pageID ?? snapshot.selectedPageID ?? "page-welcome"
                let block = try repository.appendBlock(
                    pageID: pageID,
                    type: .paragraph,
                    text: appendText
                )
                appendedBlockID = block.id
                EditorLog.sync.debug(
                    "cloudkit_sync_diagnostic_block_appended block_id=\(block.id, privacy: .public) page_id=\(pageID, privacy: .public)"
                )
            } else {
                appendedBlockID = nil
            }

            let attachmentsDirectory = try attachmentsDirectory()
            try DataProtectionService.applyNativeProtectionRecursively(to: attachmentsDirectory)
            guard let syncEngine = makeCloudKitSyncEngine(
                database: database,
                attachmentsDirectory: attachmentsDirectory
            ) else {
                throw CloudKitSyncDiagnosticError.missingSyncEngine
            }

            try syncEngine.ensureRemoteChangeSubscription()
            let uploadSummary = try syncEngine.uploadPendingChanges()
            let fetchSummary = try syncEngine.fetchRemoteChanges()
            let pendingChangeCount = try database.queryInt("SELECT COUNT(*) FROM sync_changes")

            EditorLog.sync.debug(
                "cloudkit_sync_diagnostic_completed appended_block_id=\(appendedBlockID ?? "nil", privacy: .public) uploaded=\(uploadSummary.uploadedCount, privacy: .public) failed_uploads=\(uploadSummary.failedCount, privacy: .public) fetched=\(fetchSummary.appliedCount, privacy: .public) pending=\(pendingChangeCount, privacy: .public)"
            )
            recordRuntimeDiagnostic(
                database: database,
                eventName: "cloudkit_sync_diagnostic_completed",
                payload: [
                    "appended_block_id": appendedBlockID ?? "nil",
                    "uploaded_count": uploadSummary.uploadedCount,
                    "failed_upload_count": uploadSummary.failedCount,
                    "fetched_count": fetchSummary.appliedCount,
                    "pending_change_count": pendingChangeCount
                ]
            )
            return CloudKitSyncDiagnosticResult(
                status: .completed,
                appendedBlockID: appendedBlockID,
                uploadedCount: uploadSummary.uploadedCount,
                failedUploadCount: uploadSummary.failedCount,
                fetchedCount: fetchSummary.appliedCount,
                pendingChangeCount: pendingChangeCount,
                errorDescription: nil
            )
        } catch {
            let description = String(describing: error)
            EditorLog.sync.error(
                "cloudkit_sync_diagnostic_failed error=\(description, privacy: .public)"
            )
            recordRuntimeDiagnostic(
                eventName: "cloudkit_sync_diagnostic_failed",
                payload: ["error": description]
            )
            return CloudKitSyncDiagnosticResult(
                status: .failed,
                appendedBlockID: nil,
                uploadedCount: 0,
                failedUploadCount: 0,
                fetchedCount: 0,
                pendingChangeCount: 0,
                errorDescription: description
            )
        }
    }
#endif

    static func recordRuntimeDiagnostic(
        eventName: String,
        payload: [String: Any]
    ) {
        do {
            let databasePath = try databasePath()
            let database = try SQLiteDatabase.open(path: databasePath)
            defer { database.close() }

            try SchemaMigrator.migrate(database: database)
            try RuntimeDiagnosticRepository(database: database).record(
                eventName: eventName,
                payloadJSON: runtimeDiagnosticPayloadJSON(payload)
            )
            try DataProtectionService.applyNativeProtection(to: URL(fileURLWithPath: databasePath))
        } catch {
            EditorLog.sync.error(
                "runtime_diagnostic_record_failed event_name=\(eventName, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    private static func recordRuntimeDiagnostic(
        database: SQLiteDatabase,
        eventName: String,
        payload: [String: Any]
    ) {
        do {
            try RuntimeDiagnosticRepository(database: database).record(
                eventName: eventName,
                payloadJSON: runtimeDiagnosticPayloadJSON(payload)
            )
        } catch {
            EditorLog.sync.error(
                "runtime_diagnostic_record_failed event_name=\(eventName, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    private static func remoteNotificationSyncDiagnosticPayload(
        _ report: RemoteNotificationSyncReport
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "result": report.result.diagnosticName,
            "uploaded_count": report.uploadedCount,
            "failed_upload_count": report.failedUploadCount,
            "fetched_count": report.fetchedCount
        ]
        if let errorDescription = report.errorDescription {
            payload["error"] = errorDescription
        }
        return payload
    }

    private static func runtimeDiagnosticPayloadJSON(_ payload: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"serialization_failed":true}"#
        }

        return json
    }

    private static func databasePath() throws -> String {
        let directory = try editorStoreDirectory()
        return directory.appendingPathComponent("editor.sqlite").path
    }

    private static func attachmentsDirectory() throws -> URL {
        let directory = try editorStoreDirectory()
            .appendingPathComponent("Attachments", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private static func editorStoreDirectory() throws -> URL {
        try LocalSyncGenerationResetPolicy.prepareStoreDirectory(
            applicationSupportRoot: applicationSupportRoot()
        )
    }

    private static func applicationSupportRoot() -> URL {
        if let override = ProcessInfo.processInfo.environment["EDITOR_APP_SUPPORT_DIR"],
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        return FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
    }

    private static func resetApplicationDataForUITestingIfNeeded() throws {
        guard ProcessInfo.processInfo.environment["EDITOR_UI_TEST_RESET_STORE"] == "1" else {
            return
        }

        let editorDirectory = applicationSupportRoot()
            .appendingPathComponent("Editor", isDirectory: true)
        if FileManager.default.fileExists(atPath: editorDirectory.path) {
            try FileManager.default.removeItem(at: editorDirectory)
        }
    }

    private static func seedLargePageForUITestingIfNeeded(
        repository: PageRepository,
        snapshot: WorkspaceSnapshot
    ) throws {
#if DEBUG
        guard let rawBlockCount = ProcessInfo.processInfo.environment["EDITOR_UI_TEST_LARGE_PAGE_BLOCK_COUNT"],
              let blockCount = Int(rawBlockCount),
              blockCount > 0,
              let pageID = snapshot.selectedPageID else {
            return
        }

        try repository.updatePageTitle(pageID: pageID, title: "Large Page")
        try repository.replacePageWithUITestLargePage(pageID: pageID, blockCount: blockCount)
#else
        _ = repository
        _ = snapshot
#endif
    }

    private static func seedReferenceTargetsForUITestingIfNeeded(
        repository: PageRepository,
        snapshot: WorkspaceSnapshot
    ) throws {
#if DEBUG
        guard ProcessInfo.processInfo.environment["EDITOR_UI_TEST_REFERENCE_TARGETS"] == "1",
              let workspaceID = snapshot.selectedWorkspaceID else {
            return
        }

        let targetPage = try repository.createPage(
            workspaceID: workspaceID,
            title: "Reference Target",
            notebookID: snapshot.selectedNotebookID
        )
        _ = try repository.appendBlock(
            pageID: targetPage.id,
            type: .paragraph,
            text: "Reference target block"
        )
#else
        _ = repository
        _ = snapshot
#endif
    }

    private static func seedFavoritePageForUITestingIfNeeded(
        repository: PageRepository,
        snapshot: WorkspaceSnapshot
    ) throws {
#if DEBUG
        guard ProcessInfo.processInfo.environment["EDITOR_UI_TEST_FAVORITE_PAGE"] == "1",
              let pageID = snapshot.selectedPageID else {
            return
        }

        try repository.updatePageFavorite(pageID: pageID, isFavorite: true)
#else
        _ = repository
        _ = snapshot
#endif
    }

    private static func seedTaggedPageForUITestingIfNeeded(
        snapshot: WorkspaceSnapshot,
        tagRepository: TagRepository
    ) throws {
#if DEBUG
        guard ProcessInfo.processInfo.environment["EDITOR_UI_TEST_TAGGED_PAGE"] == "1",
              let workspaceID = snapshot.selectedWorkspaceID,
              let pageID = snapshot.selectedPageID else {
            return
        }

        _ = try tagRepository.createTag(workspaceID: workspaceID, name: "Research")
        let tag = try tagRepository.createTag(workspaceID: workspaceID, name: "Writing")
        try tagRepository.assignTags(pageID: pageID, tagIDs: [tag.id])
#else
        _ = snapshot
        _ = tagRepository
#endif
    }

    private static func seedAttachmentForUITestingIfNeeded(
        attachmentRepository: AttachmentRepository,
        snapshot: WorkspaceSnapshot
    ) throws {
#if DEBUG
        guard let filename = ProcessInfo.processInfo.environment["EDITOR_UI_TEST_ATTACHMENT_FILENAME"],
              !filename.isEmpty,
              let workspaceID = snapshot.selectedWorkspaceID,
              let pageID = snapshot.selectedPageID else {
            return
        }

        let safeFilename = URL(fileURLWithPath: filename).lastPathComponent
        let fixtureDirectory = applicationSupportRoot()
            .appendingPathComponent("EditorUITestFixtures", isDirectory: true)
        try FileManager.default.createDirectory(
            at: fixtureDirectory,
            withIntermediateDirectories: true
        )
        let sourceURL = fixtureDirectory.appendingPathComponent(safeFilename)
        if !FileManager.default.fileExists(atPath: sourceURL.path) {
            try "Attachment fixture from macOS UI automation"
                .write(to: sourceURL, atomically: true, encoding: .utf8)
        }

        _ = try attachmentRepository.importAttachment(
            sourceURL: sourceURL,
            workspaceID: workspaceID,
            pageID: pageID
        )
#else
        _ = attachmentRepository
        _ = snapshot
#endif
    }

    private static func seedConflictForUITestingIfNeeded(
        repository: PageRepository,
        conflictRepository: ConflictRepository,
        snapshot: WorkspaceSnapshot
    ) throws {
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        guard environment["EDITOR_UI_TEST_CONFLICT"] == "1",
              let pageID = snapshot.selectedPageID,
              let firstBlockID = snapshot.blocks.first(where: { $0.pageID == pageID })?.id else {
            return
        }

        let conflictCount = max(1, Int(environment["EDITOR_UI_TEST_CONFLICT_COUNT"] ?? "1") ?? 1)
        for index in 1...conflictCount {
            let localText = index == 1 ? "Local conflict draft" : "Local conflict draft \(index)"
            let remoteText = index == 1 ? "Remote conflict draft" : "Remote conflict draft \(index)"
            let blockID: String
            if index == 1 {
                blockID = firstBlockID
                try repository.updateBlockText(blockID: blockID, text: localText)
            } else {
                blockID = try repository.appendBlock(pageID: pageID, type: .paragraph, text: localText).id
            }
            let payloadData = try JSONSerialization.data(withJSONObject: ["text": remoteText])
            guard let payloadJSON = String(data: payloadData, encoding: .utf8) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try conflictRepository.storeConflict(
                ConflictVersion(
                    blockID: blockID,
                    payloadJSON: payloadJSON,
                    textPlain: remoteText,
                    remoteRevision: index + 1
                )
            )
        }
#else
        _ = repository
        _ = conflictRepository
        _ = snapshot
#endif
    }
}

private extension RemoteNotificationSyncResult {
    var diagnosticName: String {
        switch self {
        case .newData:
            return "new_data"
        case .noData:
            return "no_data"
        case .failed:
            return "failed"
        }
    }
}

#if DEBUG
struct CloudKitRuntimeProbeDiagnosticResult: Equatable {
    enum Status: Equatable {
        case skipped
        case completed
        case failed
    }

    let status: Status
    let recordName: String?
    let errorDescription: String?

    var displayText: String {
        switch status {
        case .skipped:
            return "CloudKit runtime probe skipped"
        case .completed:
            return "CloudKit runtime probe completed"
        case .failed:
            return "CloudKit runtime probe failed"
        }
    }
}

private struct RemoteNotificationSyncDiagnosticView: View {
    @State private var resultText = "Remote notification sync diagnostic running"

    var body: some View {
        Text(resultText)
            .font(.system(.body, design: .monospaced))
            .padding()
            .task {
                let result = await Task.detached {
                    AppEnvironment.handleRemoteNotificationSync()
                }.value
                resultText = "Remote notification sync diagnostic \(result.diagnosticName)"
            }
    }
}

private struct CloudKitRuntimeProbeDiagnosticView: View {
    @State private var resultText = "CloudKit runtime probe running"

    var body: some View {
        Text(resultText)
            .font(.system(.body, design: .monospaced))
            .padding()
            .task {
                let result = await Task.detached {
                    AppEnvironment.runCloudKitRuntimeProbeDiagnostic()
                }.value
                resultText = result.displayText
            }
    }
}

private struct CloudKitSyncDiagnosticView: View {
    @State private var resultText = "CloudKit diagnostic running"

    var body: some View {
        Text(resultText)
            .font(.system(.body, design: .monospaced))
            .padding()
            .task {
                let result = await Task.detached {
                    AppEnvironment.runCloudKitSyncDiagnostic()
                }.value
                resultText = result.displayText
            }
    }
}
#endif

private struct AppStartupFailureView: View {
    let error: Error

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unable to open local workspace")
                .font(.title2.weight(.semibold))
            Text(String(describing: error))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(EditorDesignTokens.Colors.editorBackground.color)
    }
}
