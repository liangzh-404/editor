import SwiftUI

enum AppEnvironment {
    @MainActor
    static func makeRootView() -> some View {
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

            let attachmentsDirectory = try attachmentsDirectory()
            try DataProtectionService.applyNativeProtectionRecursively(to: attachmentsDirectory)
            let syncEngine = makeCloudKitSyncEngine(
                database: database,
                attachmentsDirectory: attachmentsDirectory
            )
            return RemoteNotificationSyncHandler(syncer: syncEngine).handleRemoteNotification()
        } catch {
            EditorLog.sync.error(
                "remote_notification_environment_failed error=\(String(describing: error), privacy: .public)"
            )
            return .failed
        }
    }

    @MainActor
    private static func makeWorkspaceViewModel() throws -> WorkspaceViewModel {
        let databasePath = try databasePath()
        let database = try SQLiteDatabase.open(path: databasePath)
        try SchemaMigrator.migrate(database: database)
        try DataProtectionService.applyNativeProtection(to: URL(fileURLWithPath: databasePath))

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        try seedLargePageForUITestingIfNeeded(repository: repository, snapshot: snapshot)
        try seedReferenceTargetsForUITestingIfNeeded(repository: repository, snapshot: snapshot)
        try seedFavoritePageForUITestingIfNeeded(repository: repository, snapshot: snapshot)
        let attachmentsDirectory = try attachmentsDirectory()
        try DataProtectionService.applyNativeProtectionRecursively(to: attachmentsDirectory)
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: attachmentsDirectory
        )
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
            attachmentRepository: attachmentRepository,
            searchRepository: SearchRepository(database: database),
            backlinkRepository: BacklinkRepository(database: database),
            conflictRepository: ConflictRepository(database: database),
            syncEngine: makeCloudKitSyncEngine(
                database: database,
                attachmentsDirectory: attachmentsDirectory
            ),
            cloudKitAccountMetadataService: makeCloudKitAccountMetadataService()
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

    private static func makeCloudKitSyncEngine(
        database: SQLiteDatabase,
        attachmentsDirectory: URL
    ) -> SyncEngine? {
        guard CloudKitEntitlementInspector.currentProcessHasCloudKitContainers() else {
            EditorLog.sync.debug("cloudkit_sync_engine_disabled reason=missing_entitlement")
            return nil
        }

        let adapter = CloudKitPrivateDatabaseAdapter(
            database: database,
            recordFetcher: LiveCloudKitRecordFetcher(),
            attachmentDownloadDirectory: attachmentsDirectory
        )
        return SyncEngine(
            syncRepository: SyncRepository(database: database),
            adapter: adapter,
            remoteChangeFetcher: adapter,
            mergeEngine: SyncMergeEngine(database: database),
            subscriptionEnsurer: CloudKitPrivateDatabaseSubscriptionEnsurer()
        )
    }

    private static func databasePath() throws -> String {
        let applicationSupport = applicationSupportRoot()
        let directory = applicationSupport.appendingPathComponent("Editor", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("editor.sqlite").path
    }

    private static func attachmentsDirectory() throws -> URL {
        let applicationSupport = applicationSupportRoot()
        let directory = applicationSupport
            .appendingPathComponent("Editor", isDirectory: true)
            .appendingPathComponent("Attachments", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
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
        .background(Color.white)
    }
}
