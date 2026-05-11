import Foundation
import XCTest

final class WorkspaceViewModelTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    @MainActor
    func testLoadExposesRepositorySnapshotSelectionAndBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        XCTAssertEqual(viewModel.snapshot.workspaces.count, 1)
        XCTAssertEqual(viewModel.snapshot.pages.count, 1)
        XCTAssertEqual(viewModel.snapshot.blocks.count, 1)
        XCTAssertEqual(viewModel.selectedWorkspaceID, viewModel.snapshot.workspaces.first?.id)
        XCTAssertEqual(viewModel.selectedPageID, viewModel.snapshot.pages.first?.id)
        XCTAssertEqual(viewModel.selectedPage?.title, "Welcome")
        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Start writing in blocks."])
    }

    @MainActor
    func testUpdateBlockTextRefreshesVisibleBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.updateBlockText(blockID: blockID, text: "Editable now")

        XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Editable now"])
    }

    @MainActor
    func testImportAttachmentRefreshesVisibleBlocksAndAttachmentMetadata() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        _ = try pageRepository.bootstrapWorkspaceIfNeeded()
        let attachmentRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let sourceURL = try makeSourceFile(name: "screen.png", contents: "png-data")

        let viewModel = WorkspaceViewModel(
            repository: pageRepository,
            attachmentRepository: attachmentRepository
        )
        try viewModel.load()
        try viewModel.importAttachment(sourceURL: sourceURL)

        XCTAssertEqual(viewModel.visibleBlocks.last?.type, .attachmentImage)
        XCTAssertEqual(viewModel.snapshot.attachments.map(\.originalFilename), ["screen.png"])
    }

    @MainActor
    func testMarkdownHeadingShortcutUpdatesBlockTypeAndText() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()
        let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

        try viewModel.updateBlockText(blockID: blockID, text: "# ")

        XCTAssertEqual(viewModel.visibleBlocks.first?.type, .heading1)
        XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "")

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        XCTAssertEqual(reloadedSnapshot.blocks.first?.type, .heading1)
        XCTAssertEqual(reloadedSnapshot.blocks.first?.textPlain, "")
    }

    @MainActor
    func testAppendParagraphBlockRefreshesVisibleBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()

        let viewModel = WorkspaceViewModel(repository: repository)
        try viewModel.load()

        try viewModel.appendParagraphBlockToCurrentPage()

        XCTAssertEqual(viewModel.visibleBlocks.map(\.type), [.paragraph, .paragraph])
        XCTAssertEqual(viewModel.visibleBlocks.last?.textPlain, "")
    }

    private func migratedDatabase() throws -> SQLiteDatabase {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        try SchemaMigrator.migrate(database: database)
        return database
    }

    private func temporaryDatabasePath() -> String {
        makeTemporaryDirectory().appendingPathComponent("editor.sqlite").path
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
