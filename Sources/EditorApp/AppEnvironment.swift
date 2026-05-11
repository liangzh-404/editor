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
            backlinkRepository: BacklinkRepository(database: database)
        )
        try viewModel.load()
        return viewModel
    }

    private static func databasePath() throws -> String {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let directory = applicationSupport.appendingPathComponent("Editor", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("editor.sqlite").path
    }

    private static func attachmentsDirectory() throws -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let directory = applicationSupport
            .appendingPathComponent("Editor", isDirectory: true)
            .appendingPathComponent("Attachments", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
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
