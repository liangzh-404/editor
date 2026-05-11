import Foundation

final class PageRepository {
    private let database: SQLiteDatabase

    private let defaultWorkspaceID = "workspace-local"
    private let defaultPageID = "page-welcome"
    private let defaultBlockID = "block-welcome-001"

    init(database: SQLiteDatabase) {
        self.database = database
    }

    @discardableResult
    func bootstrapWorkspaceIfNeeded() throws -> WorkspaceSnapshot {
        let workspaceCount = try database.queryInt("SELECT COUNT(*) FROM workspaces")
        if workspaceCount == 0 {
            try insertDefaultContent()
        }

        return try loadWorkspaceSnapshot()
    }

    func loadWorkspaceSnapshot() throws -> WorkspaceSnapshot {
        let workspaces = try database.query(
            """
            SELECT id, name
            FROM workspaces
            ORDER BY created_at ASC
            """
        ).map { row in
            WorkspaceSummary(
                id: row["id"] ?? "",
                name: row["name"] ?? ""
            )
        }

        let selectedWorkspaceID = workspaces.first?.id

        let pages = try database.query(
            """
            SELECT id, workspace_id, title
            FROM pages
            WHERE workspace_id = ?
            ORDER BY order_key ASC
            """,
            bindings: selectedWorkspaceID.map { [.text($0)] } ?? [.text("")]
        ).map { row in
            PageSummary(
                id: row["id"] ?? "",
                workspaceID: row["workspace_id"] ?? "",
                title: row["title"] ?? ""
            )
        }

        let selectedPageID = pages.first?.id

        let blocks = try database.query(
            """
            SELECT id, page_id, parent_block_id, order_key, type, text_plain
            FROM blocks
            WHERE page_id = ? AND is_deleted = 0
            ORDER BY order_key ASC
            """,
            bindings: selectedPageID.map { [.text($0)] } ?? [.text("")]
        ).map { row in
            BlockSnapshot(
                id: row["id"] ?? "",
                pageID: row["page_id"] ?? "",
                parentBlockID: row["parent_block_id"] ?? nil,
                orderKey: row["order_key"] ?? "",
                type: BlockType(rawValue: row["type"] ?? "") ?? .paragraph,
                textPlain: row["text_plain"] ?? ""
            )
        }

        let attachments = try database.query(
            """
            SELECT id,
                   workspace_id,
                   original_filename,
                   uti_type,
                   byte_size,
                   content_hash,
                   local_path,
                   thumbnail_path
            FROM attachments
            WHERE workspace_id = ?
            ORDER BY created_at ASC
            """,
            bindings: selectedWorkspaceID.map { [.text($0)] } ?? [.text("")]
        ).map { row in
            let utiType = row["uti_type"] ?? "public.data"
            return AttachmentSnapshot(
                id: row["id"] ?? "",
                workspaceID: row["workspace_id"] ?? "",
                originalFilename: row["original_filename"] ?? "",
                utiType: utiType,
                byteSize: Int(row["byte_size"] ?? "") ?? 0,
                contentHash: row["content_hash"] ?? "",
                localPath: row["local_path"] ?? "",
                thumbnailPath: row["thumbnail_path"] ?? nil,
                kind: AttachmentKind(utiType: utiType)
            )
        }

        return WorkspaceSnapshot(
            workspaces: workspaces,
            pages: pages,
            blocks: blocks,
            attachments: attachments,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedPageID: selectedPageID
        )
    }

    func updateBlockText(blockID: String, text: String) throws {
        let rows = try database.query(
            """
            SELECT type
            FROM blocks
            WHERE id = ? AND is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        )
        let type = rows.first
            .flatMap { $0["type"] }
            .flatMap(BlockType.init(rawValue:)) ?? .paragraph

        try updateBlock(blockID: blockID, type: type, text: text)
    }

    func updateBlock(blockID: String, type: BlockType, text: String) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let payloadJSON = try blockPayloadJSON(type: type, text: text)

        try database.execute(
            """
            UPDATE blocks
            SET type = ?,
                payload_json = ?,
                text_plain = ?,
                revision = revision + 1,
                sync_state = ?,
                updated_at = ?
            WHERE id = ? AND is_deleted = 0
            """,
            bindings: [
                .text(type.rawValue),
                .text(payloadJSON),
                .text(text),
                .text("local"),
                .text(now),
                .text(blockID)
            ]
        )
        try SyncRepository(database: database).enqueue(
            entityType: "block",
            entityID: blockID,
            changeType: "update"
        )
    }

    private func insertDefaultContent() throws {
        let now = ISO8601DateFormatter().string(from: Date())

        try database.execute(
            """
            INSERT INTO workspaces (id, name, created_at, updated_at)
            VALUES (?, ?, ?, ?)
            """,
            bindings: [
                .text(defaultWorkspaceID),
                .text("Local"),
                .text(now),
                .text(now)
            ]
        )

        try database.execute(
            """
            INSERT INTO pages (id, workspace_id, title, order_key, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(defaultPageID),
                .text(defaultWorkspaceID),
                .text("Welcome"),
                .text("000001"),
                .text(now),
                .text(now)
            ]
        )

        try database.execute(
            """
            INSERT INTO blocks (
                id,
                page_id,
                parent_block_id,
                order_key,
                type,
                payload_json,
                text_plain,
                revision,
                sync_state,
                is_deleted,
                created_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(defaultBlockID),
                .text(defaultPageID),
                .null,
                .text("000001"),
                .text(BlockType.paragraph.rawValue),
                .text("{\"text\":\"Start writing in blocks.\"}"),
                .text("Start writing in blocks."),
                .integer(1),
                .text("local"),
                .integer(0),
                .text(now),
                .text(now)
            ]
        )
    }

    private func blockPayloadJSON(type: BlockType, text: String) throws -> String {
        let payload: [String: String]
        switch type {
        case .divider:
            payload = [:]
        default:
            payload = ["text": text]
        }

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        )

        guard let payload = String(data: data, encoding: .utf8) else {
            throw PageRepositoryError.invalidPayloadEncoding
        }

        return payload
    }
}

enum PageRepositoryError: Error, Equatable {
    case invalidPayloadEncoding
}
