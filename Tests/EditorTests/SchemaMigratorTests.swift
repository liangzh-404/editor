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
        XCTAssertTrue(tableNames.contains("runtime_diagnostics"))
        XCTAssertTrue(tableNames.contains("conflict_versions"))
        XCTAssertTrue(tableNames.contains("search_index"))
    }

    func testRuntimeDiagnosticsTableCapturesObservableSyncEvents() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)

        let columns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('runtime_diagnostics')"))

        XCTAssertTrue(columns.contains("id"))
        XCTAssertTrue(columns.contains("event_name"))
        XCTAssertTrue(columns.contains("payload_json"))
        XCTAssertTrue(columns.contains("created_at"))
    }

    func testDatabaseConfiguresBusyTimeoutForStartupDiagnostics() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        XCTAssertEqual(try database.queryInt("PRAGMA busy_timeout"), 1_000)
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

    func testSyncChangesTablePreventsDuplicateEntityChangeRows() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)
        try insertSyncChange(
            database: database,
            id: "sync-one",
            entityType: "page",
            entityID: "page-welcome",
            changeType: "update",
            attemptCount: 0,
            createdAt: "2026-05-20T02:00:00Z"
        )

        XCTAssertThrowsError(
            try insertSyncChange(
                database: database,
                id: "sync-two",
                entityType: "page",
                entityID: "page-welcome",
                changeType: "update",
                attemptCount: 0,
                createdAt: "2026-05-20T02:01:00Z"
            )
        )
    }

    func testMigrationCompactsDuplicateSyncChangesBeforeAddingUniqueIndex() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)
        try database.execute("DROP INDEX IF EXISTS idx_sync_changes_entity_change")
        try insertSyncChange(
            database: database,
            id: "sync-old",
            entityType: "page",
            entityID: "page-welcome",
            changeType: "update",
            attemptCount: 2,
            createdAt: "2026-05-20T02:00:00Z"
        )
        try insertSyncChange(
            database: database,
            id: "sync-new",
            entityType: "page",
            entityID: "page-welcome",
            changeType: "update",
            attemptCount: 0,
            createdAt: "2026-05-20T02:01:00Z"
        )

        try SchemaMigrator.migrate(database: database)

        let rows = try database.query(
            """
            SELECT id, attempt_count
            FROM sync_changes
            WHERE entity_type = 'page'
              AND entity_id = 'page-welcome'
              AND change_type = 'update'
            """
        )
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?["id"], "sync-new")
        XCTAssertEqual(rows.first?["attempt_count"], "0")
        XCTAssertThrowsError(
            try insertSyncChange(
                database: database,
                id: "sync-later",
                entityType: "page",
                entityID: "page-welcome",
                changeType: "update",
                attemptCount: 0,
                createdAt: "2026-05-20T02:02:00Z"
            )
        )
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

    func testPagesExposeEncryptedNoteFlag() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)

        let pageColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('pages')"))

        XCTAssertTrue(pageColumns.contains("is_encrypted"))
    }

    func testPagesExposePinnedNoteFlag() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)

        let pageColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('pages')"))

        XCTAssertTrue(pageColumns.contains("is_pinned"))
    }

    func testMigrationCreatesAttachmentTextRecognitionTable() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)

        let tableNames = Set(try database.queryStrings(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        ))
        let columns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('attachment_text_recognition')"))

        XCTAssertTrue(tableNames.contains("attachment_text_recognition"))
        XCTAssertTrue(columns.isSuperset(of: [
            "attachment_id",
            "content_hash",
            "recognized_text",
            "regions_json",
            "recognized_at"
        ]))
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
        XCTAssertTrue(tableNames.contains("diary_pages"))
        XCTAssertTrue(tableNames.contains("page_parent_links"))
    }

    func testTagAndDiaryTablesExposeRequiredColumns() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)

        let tagColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('tags')"))
        let pageTagColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('page_tags')"))
        let diaryColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('diary_entries')"))
        let pageOriginColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('page_origin')"))
        let diaryPageColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('diary_pages')"))
        let pageParentLinkColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('page_parent_links')"))

        XCTAssertTrue(tagColumns.isSuperset(of: ["id", "workspace_id", "parent_tag_id", "name", "order_key", "created_at", "updated_at"]))
        XCTAssertTrue(pageTagColumns.isSuperset(of: ["page_id", "tag_id", "created_at"]))
        XCTAssertTrue(diaryColumns.isSuperset(of: ["id", "workspace_id", "text_plain", "created_at", "updated_at"]))
        XCTAssertTrue(pageOriginColumns.isSuperset(of: ["page_id", "promoted_from_diary_entry_id", "created_at"]))
        XCTAssertTrue(diaryPageColumns.isSuperset(of: ["page_id", "workspace_id", "diary_date", "created_at", "updated_at"]))
        XCTAssertTrue(pageParentLinkColumns.isSuperset(of: ["parent_page_id", "child_page_id", "source_block_id", "order_key", "created_at", "updated_at"]))
    }

    func testLinksTableTracksExternalTargets() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)

        let linkColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('links')"))

        XCTAssertTrue(linkColumns.contains("target_url"))
    }

    func testLinksTableTracksInlineSourceRangesAndKind() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)

        let columns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('links')"))

        XCTAssertTrue(columns.contains("source_range_location"))
        XCTAssertTrue(columns.contains("source_range_length"))
        XCTAssertTrue(columns.contains("link_kind"))
    }

    func testMigrationCreatesLookupIndexesForLargeVaultPerformance() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try SchemaMigrator.migrate(database: database)

        let indexNames = Set(try database.queryStrings(
            "SELECT name FROM sqlite_master WHERE type = 'index'"
        ))

        XCTAssertTrue(indexNames.contains("idx_blocks_page_order"))
        XCTAssertTrue(indexNames.contains("idx_blocks_parent"))
        XCTAssertTrue(indexNames.contains("idx_links_source_page"))
        XCTAssertTrue(indexNames.contains("idx_links_target_page"))
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

    func testImmediateTransactionReusesExistingTransaction() throws {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        defer { database.close() }

        try database.execute("CREATE TABLE items (id TEXT PRIMARY KEY)")
        try database.withImmediateTransaction("outer") {
            try database.execute(
                "INSERT INTO items (id) VALUES (?)",
                bindings: [.text("outer")]
            )
            try database.withImmediateTransaction("inner") {
                try database.execute(
                    "INSERT INTO items (id) VALUES (?)",
                    bindings: [.text("inner")]
                )
            }
        }

        XCTAssertEqual(try database.queryInt("SELECT COUNT(*) FROM items"), 2)
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

    private func insertSyncChange(
        database: SQLiteDatabase,
        id: String,
        entityType: String,
        entityID: String,
        changeType: String,
        attemptCount: Int,
        createdAt: String
    ) throws {
        try database.execute(
            """
            INSERT INTO sync_changes (
                id,
                entity_type,
                entity_id,
                change_type,
                attempt_count,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(id),
                .text(entityType),
                .text(entityID),
                .text(changeType),
                .integer(attemptCount),
                .text(createdAt)
            ]
        )
    }
}

private enum SQLiteTransactionTestError: Error {
    case expectedFailure
}
