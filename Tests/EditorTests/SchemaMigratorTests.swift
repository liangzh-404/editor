import Foundation
import XCTest

final class SchemaMigratorTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testMigrationCreatesM1Tables() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)

        let tableNames = Set(try database.queryStrings(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        ))

        XCTAssertTrue(tableNames.contains("schema_migrations"))
        XCTAssertTrue(tableNames.contains("workspaces"))
        XCTAssertTrue(tableNames.contains("pages"))
        XCTAssertTrue(tableNames.contains("blocks"))
        XCTAssertTrue(tableNames.contains("attachments"))
        XCTAssertTrue(tableNames.contains("links"))
        XCTAssertTrue(tableNames.contains("sync_changes"))
        XCTAssertTrue(tableNames.contains("sync_records"))
        XCTAssertTrue(tableNames.contains("conflict_versions"))
        XCTAssertTrue(tableNames.contains("search_index"))
    }

    func testSyncChangesTableTracksRetryState() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)

        let columns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('sync_changes')"))

        XCTAssertTrue(columns.contains("attempt_count"))
        XCTAssertTrue(columns.contains("last_error"))
        XCTAssertTrue(columns.contains("next_attempt_at"))
    }

    func testMigrationRecordsSchemaVersionOne() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)

        let version = try database.queryInt(
            "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1"
        )
        XCTAssertEqual(version, SchemaMigrator.currentVersion)
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
