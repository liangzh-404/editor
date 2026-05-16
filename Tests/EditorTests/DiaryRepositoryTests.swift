import XCTest

final class DiaryRepositoryTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testActiveDiaryEntryPersistsTextWithoutCreatingDocumentPage() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let repository = DiaryRepository(database: database)

        let entry = try repository.activeEntry(workspaceID: workspaceID)
        try repository.updateEntryText(entryID: entry.id, text: "Fast capture")

        let reloadedEntry = try repository.activeEntry(workspaceID: workspaceID)
        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedEntry.textPlain, "Fast capture")
        XCTAssertFalse(reloadedSnapshot.pages.contains { $0.title == "Fast capture" })
    }

    func testPromoteSelectedDiaryTextCreatesPageAndKeepsDiaryText() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let repository = DiaryRepository(database: database)
        let entry = try repository.activeEntry(workspaceID: workspaceID)
        try repository.updateEntryText(entryID: entry.id, text: "Alpha capture Beta")

        let page = try repository.promoteTextToPage(entryID: entry.id, selectedText: "Alpha capture")
        let reloadedEntry = try repository.activeEntry(workspaceID: workspaceID)
        let blocks = try pageRepository.loadWorkspaceSnapshot().blocks.filter { $0.pageID == page.id }

        XCTAssertEqual(page.title, "Alpha capture")
        XCTAssertEqual(blocks.map(\.textPlain), ["Alpha capture"])
        XCTAssertEqual(reloadedEntry.textPlain, "Alpha capture Beta")
    }

    private func migratedDatabase() throws -> SQLiteDatabase {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        try SchemaMigrator.migrate(database: database)
        return database
    }

    private func temporaryDatabasePath() -> String {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryFiles.append(directory)
        return directory.appendingPathComponent("editor.sqlite").path
    }
}
