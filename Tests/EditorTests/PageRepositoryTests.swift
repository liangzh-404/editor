import Foundation
import XCTest

final class PageRepositoryTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testBootstrapCreatesDefaultWorkspacePageAndParagraphBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()

        XCTAssertEqual(snapshot.workspaces.map(\.name), ["Local"])
        XCTAssertEqual(snapshot.pages.map(\.title), ["Welcome"])
        XCTAssertEqual(snapshot.blocks.count, 1)
        XCTAssertEqual(snapshot.blocks.first?.type, .paragraph)
        XCTAssertEqual(snapshot.blocks.first?.textPlain, "Start writing in blocks.")
        XCTAssertEqual(snapshot.selectedWorkspaceID, snapshot.workspaces.first?.id)
        XCTAssertEqual(snapshot.selectedPageID, snapshot.pages.first?.id)
    }

    func testBootstrapIsIdempotent() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let snapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(snapshot.workspaces.count, 1)
        XCTAssertEqual(snapshot.pages.count, 1)
        XCTAssertEqual(snapshot.blocks.count, 1)
    }

    private func migratedDatabase() throws -> SQLiteDatabase {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        try SchemaMigrator.migrate(database: database)
        return database
    }

    private func temporaryDatabasePath() -> String {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        temporaryFiles.append(directory)
        return directory.appendingPathComponent("editor.sqlite").path
    }
}

