import Foundation

enum SchemaMigrator {
    static let currentVersion = 1

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
            CREATE TABLE IF NOT EXISTS pages (
                id TEXT PRIMARY KEY,
                workspace_id TEXT NOT NULL,
                title TEXT NOT NULL,
                order_key TEXT NOT NULL,
                is_archived INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
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
                link_text TEXT NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY (source_page_id) REFERENCES pages(id) ON DELETE CASCADE
            );
            """
        )

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS sync_changes (
                id TEXT PRIMARY KEY,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                change_type TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            """
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
    }
}
