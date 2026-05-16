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
        XCTAssertTrue(tableNames.contains("notebooks"))
        XCTAssertTrue(tableNames.contains("links"))
        XCTAssertTrue(tableNames.contains("sync_changes"))
        XCTAssertTrue(tableNames.contains("sync_records"))
        XCTAssertTrue(tableNames.contains("sync_server_change_tokens"))
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

    func testPagesCanBelongToNotebooks() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)

        let pageColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('pages')"))
        let notebookColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('notebooks')"))

        XCTAssertTrue(pageColumns.contains("notebook_id"))
        XCTAssertTrue(notebookColumns.contains("workspace_id"))
        XCTAssertTrue(notebookColumns.contains("parent_notebook_id"))
        XCTAssertTrue(notebookColumns.contains("name"))
        XCTAssertTrue(notebookColumns.contains("order_key"))
    }

    func testMigrationCreatesTagAndDiaryTables() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)

        let tableNames = Set(try database.queryStrings(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        ))

        XCTAssertTrue(tableNames.contains("tags"))
        XCTAssertTrue(tableNames.contains("page_tags"))
        XCTAssertTrue(tableNames.contains("diary_entries"))
        XCTAssertTrue(tableNames.contains("page_origin"))
    }

    func testTagAndDiaryTablesExposeRequiredColumns() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)

        let tagColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('tags')"))
        let pageTagColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('page_tags')"))
        let diaryColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('diary_entries')"))
        let pageOriginColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('page_origin')"))

        XCTAssertTrue(tagColumns.isSuperset(of: ["id", "workspace_id", "parent_tag_id", "name", "order_key", "created_at", "updated_at"]))
        XCTAssertTrue(pageTagColumns.isSuperset(of: ["page_id", "tag_id", "created_at"]))
        XCTAssertTrue(diaryColumns.isSuperset(of: ["id", "workspace_id", "text_plain", "created_at", "updated_at"]))
        XCTAssertTrue(pageOriginColumns.isSuperset(of: ["page_id", "promoted_from_diary_entry_id", "created_at"]))
    }

    func testLinksTableTracksExternalTargets() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)

        let linkColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('links')"))

        XCTAssertTrue(linkColumns.contains("target_url"))
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

    func testImmediateTransactionCommitsOperation() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try database.execute("CREATE TABLE items (id TEXT PRIMARY KEY)")
        try database.withImmediateTransaction("test_commit") {
            try database.execute(
                "INSERT INTO items (id) VALUES (?)",
                bindings: [.text("item-1")]
            )
        }

        XCTAssertEqual(try database.queryInt("SELECT COUNT(*) FROM items"), 1)
    }

    func testImmediateTransactionRollsBackFailedOperation() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try database.execute("CREATE TABLE items (id TEXT PRIMARY KEY)")
        XCTAssertThrowsError(
            try database.withImmediateTransaction("test_rollback") {
                try database.execute(
                    "INSERT INTO items (id) VALUES (?)",
                    bindings: [.text("item-1")]
                )
                throw SQLiteTransactionTestError.expectedFailure
            }
        )

        XCTAssertEqual(try database.queryInt("SELECT COUNT(*) FROM items"), 0)
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

private enum SQLiteTransactionTestError: Error {
    case expectedFailure
}
