import SwiftUI

enum AppEnvironment {
    @MainActor
    static func makeRootView() -> some View {
        do {
            return AnyView(EditorShellView(viewModel: try makeWorkspaceViewModel()))
        } catch {
            return AnyView(AppStartupFailureView(error: error))
        }
    }

    @MainActor
    private static func makeWorkspaceViewModel() throws -> WorkspaceViewModel {
        let databasePath = try databasePath()
        let database = try SQLiteDatabase.open(path: databasePath)
        try SchemaMigrator.migrate(database: database)
        try DataProtectionService.applyNativeProtection(to: URL(fileURLWithPath: databasePath))

        let repository = PageRepository(database: database)
        try repository.bootstrapWorkspaceIfNeeded()
        let attachmentsDirectory = try attachmentsDirectory()
        try DataProtectionService.applyNativeProtectionRecursively(to: attachmentsDirectory)
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: attachmentsDirectory
        )

        let viewModel = WorkspaceViewModel(
            repository: repository,
            attachmentRepository: attachmentRepository,
            searchRepository: SearchRepository(database: database),
            backlinkRepository: BacklinkRepository(database: database),
            syncEngine: makeCloudKitSyncEngine(database: database),
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

    private static func makeCloudKitSyncEngine(database: SQLiteDatabase) -> SyncEngine? {
        guard CloudKitEntitlementInspector.currentProcessHasCloudKitContainers() else {
            EditorLog.sync.debug("cloudkit_sync_engine_disabled reason=missing_entitlement")
            return nil
        }

        return SyncEngine(
            syncRepository: SyncRepository(database: database),
            adapter: CloudKitPrivateDatabaseAdapter(database: database)
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
