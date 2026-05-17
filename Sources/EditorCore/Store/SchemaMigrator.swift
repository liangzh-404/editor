import Foundation

enum SchemaMigrator {
    static let currentVersion = 9

    static func migrate(database: SQLiteDatabase) throws {
        try database.execute("PRAGMA foreign_keys = ON")
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY,
                applied_at TEXT NOT NULL
            );
            """
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS workspaces (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS notebooks (
                id TEXT PRIMARY KEY,
                workspace_id TEXT NOT NULL,
                parent_notebook_id TEXT,
                name TEXT NOT NULL,
                order_key TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
            );
            """
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS pages (
                id TEXT PRIMARY KEY,
                workspace_id TEXT NOT NULL,
                notebook_id TEXT,
                title TEXT NOT NULL,
                order_key TEXT NOT NULL,
                is_archived INTEGER NOT NULL DEFAULT 0,
                is_favorite INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
                FOREIGN KEY (notebook_id) REFERENCES notebooks(id) ON DELETE SET NULL
            );
            """
        )
        try addColumnIfMissing(
            database: database,
            table: "notebooks",
            column: "parent_notebook_id",
            definition: "TEXT"
        )
        try addColumnIfMissing(
            database: database,
            table: "pages",
            column: "notebook_id",
            definition: "TEXT"
        )
        try addColumnIfMissing(
            database: database,
            table: "pages",
            column: "is_favorite",
            definition: "INTEGER NOT NULL DEFAULT 0"
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS tags (
                id TEXT PRIMARY KEY,
                workspace_id TEXT NOT NULL,
                parent_tag_id TEXT,
                name TEXT NOT NULL,
                order_key TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
                FOREIGN KEY (parent_tag_id) REFERENCES tags(id) ON DELETE CASCADE
            );
            """
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS page_tags (
                page_id TEXT NOT NULL,
                tag_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                PRIMARY KEY (page_id, tag_id),
                FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE,
                FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
            );
            """
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS diary_entries (
                id TEXT PRIMARY KEY,
                workspace_id TEXT NOT NULL,
                text_plain TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
            );
            """
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS page_origin (
                page_id TEXT PRIMARY KEY,
                promoted_from_diary_entry_id TEXT,
                created_at TEXT NOT NULL,
                FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE,
                FOREIGN KEY (promoted_from_diary_entry_id) REFERENCES diary_entries(id) ON DELETE SET NULL
            );
            """
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS diary_pages (
                page_id TEXT PRIMARY KEY,
                workspace_id TEXT NOT NULL,
                diary_date TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                UNIQUE (workspace_id, diary_date),
                FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE,
                FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
            );
            """
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS page_parent_links (
                parent_page_id TEXT NOT NULL,
                child_page_id TEXT NOT NULL,
                source_block_id TEXT NOT NULL,
                order_key TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                PRIMARY KEY (parent_page_id, child_page_id),
                UNIQUE (source_block_id),
                FOREIGN KEY (parent_page_id) REFERENCES pages(id) ON DELETE CASCADE,
                FOREIGN KEY (child_page_id) REFERENCES pages(id) ON DELETE CASCADE,
                FOREIGN KEY (source_block_id) REFERENCES blocks(id) ON DELETE CASCADE
            );
            """
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS blocks (
                id TEXT PRIMARY KEY,
                page_id TEXT NOT NULL,
                parent_block_id TEXT,
                order_key TEXT NOT NULL,
                type TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                text_plain TEXT NOT NULL,
                revision INTEGER NOT NULL DEFAULT 0,
                sync_state TEXT NOT NULL DEFAULT 'local',
                is_deleted INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE,
                FOREIGN KEY (parent_block_id) REFERENCES blocks(id) ON DELETE CASCADE
            );
            """
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS attachments (
                id TEXT PRIMARY KEY,
                workspace_id TEXT NOT NULL,
                original_filename TEXT NOT NULL,
                uti_type TEXT NOT NULL,
                byte_size INTEGER NOT NULL,
                content_hash TEXT NOT NULL,
                local_path TEXT NOT NULL,
                thumbnail_path TEXT,
                sync_state TEXT NOT NULL DEFAULT 'local',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
            );
            """
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS links (
                id TEXT PRIMARY KEY,
                source_page_id TEXT NOT NULL,
                source_block_id TEXT,
                target_page_id TEXT,
                target_block_id TEXT,
                target_url TEXT,
                link_text TEXT NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY (source_page_id) REFERENCES pages(id) ON DELETE CASCADE
            );
            """
        )
        try addColumnIfMissing(
            database: database,
            table: "links",
            column: "target_url",
            definition: "TEXT"
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS sync_changes (
                id TEXT PRIMARY KEY,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                change_type TEXT NOT NULL,
                attempt_count INTEGER NOT NULL DEFAULT 0,
                last_error TEXT,
                next_attempt_at TEXT,
                created_at TEXT NOT NULL
            );
            """
        )
        try addColumnIfMissing(
            database: database,
            table: "sync_changes",
            column: "attempt_count",
            definition: "INTEGER NOT NULL DEFAULT 0"
        )
        try addColumnIfMissing(
            database: database,
            table: "sync_changes",
            column: "last_error",
            definition: "TEXT"
        )
        try addColumnIfMissing(
            database: database,
            table: "sync_changes",
            column: "next_attempt_at",
            definition: "TEXT"
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS sync_records (
                id TEXT PRIMARY KEY,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                record_name TEXT NOT NULL,
                change_tag TEXT,
                updated_at TEXT NOT NULL
            );
            """
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS sync_server_change_tokens (
                scope TEXT PRIMARY KEY,
                token_base64 TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS conflict_versions (
                id TEXT PRIMARY KEY,
                block_id TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                text_plain TEXT NOT NULL,
                remote_revision INTEGER NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY (block_id) REFERENCES blocks(id) ON DELETE CASCADE
            );
            """
        )

        try database.execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS search_index
            USING fts5(
                entity_type UNINDEXED,
                entity_id UNINDEXED,
                title,
                body,
                tokenize = 'unicode61'
            );
            """
        )

        try database.execute(
            """
            INSERT OR IGNORE INTO schema_migrations (version, applied_at)
            VALUES (\(currentVersion), datetime('now'));
            """
        )
        try ensureDefaultNotebooks(database: database)
    }

    private static func addColumnIfMissing(
        database: SQLiteDatabase,
        table: String,
        column: String,
        definition: String
    ) throws {
        let columns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('\(table)')"))
        guard !columns.contains(column) else {
            return
        }

        try database.execute("ALTER TABLE \(table) ADD COLUMN \(column) \(definition)")
    }

    private static func ensureDefaultNotebooks(database: SQLiteDatabase) throws {
        let workspaces = try database.query(
            """
            SELECT id, created_at, updated_at
            FROM workspaces
            ORDER BY created_at ASC
            """
        )

        for workspace in workspaces {
            guard let workspaceID = workspace["id"] else {
                continue
            }

            let countRows = try database.query(
                "SELECT COUNT(*) AS notebook_count FROM notebooks WHERE workspace_id = ?",
                bindings: [.text(workspaceID)]
            )
            let count = Int(countRows.first?["notebook_count"] ?? "") ?? 0
            if count == 0 {
                let now = ISO8601DateFormatter().string(from: Date())
                let notebookID = "notebook-\(workspaceID)"
                try database.execute(
                    """
                    INSERT INTO notebooks (id, workspace_id, parent_notebook_id, name, order_key, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    bindings: [
                        .text(notebookID),
                        .text(workspaceID),
                        .null,
                        .text("笔记本"),
                        .text("000001"),
                        .text(workspace["created_at"] ?? now),
                        .text(workspace["updated_at"] ?? now)
                    ]
                )
            }

            guard let notebookID = try database.query(
                """
                SELECT id
                FROM notebooks
                WHERE workspace_id = ?
                ORDER BY order_key ASC
                LIMIT 1
                """,
                bindings: [.text(workspaceID)]
            ).first?["id"] else {
                continue
            }

            try database.execute(
                """
                UPDATE pages
                SET notebook_id = ?
                WHERE workspace_id = ? AND notebook_id IS NULL
                """,
                bindings: [
                    .text(notebookID),
                    .text(workspaceID)
                ]
            )
        }
    }
}
