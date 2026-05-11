import Foundation

struct RemoteWorkspaceChange: Equatable, Sendable {
    let workspaceID: String
    let name: String
}

struct RemoteNotebookChange: Equatable, Sendable {
    let notebookID: String
    let workspaceID: String
    let name: String
    let orderKey: String
}

struct RemotePageChange: Equatable, Sendable {
    let pageID: String
    let workspaceID: String
    let notebookID: String?
    let title: String
    let orderKey: String
    let isArchived: Bool
}

struct RemoteBlockChange: Equatable, Sendable {
    let blockID: String
    let pageID: String
    let type: BlockType
    let textPlain: String
    let payloadJSON: String
    let revision: Int
    let parentBlockID: String?
    let orderKey: String
    let isDeleted: Bool

    init(
        blockID: String,
        pageID: String,
        type: BlockType,
        textPlain: String,
        payloadJSON: String,
        revision: Int,
        parentBlockID: String? = nil,
        orderKey: String = "000001",
        isDeleted: Bool = false
    ) {
        self.blockID = blockID
        self.pageID = pageID
        self.type = type
        self.textPlain = textPlain
        self.payloadJSON = payloadJSON
        self.revision = revision
        self.parentBlockID = parentBlockID
        self.orderKey = orderKey
        self.isDeleted = isDeleted
    }
}

struct RemoteAttachmentChange: Equatable, Sendable {
    let attachmentID: String
    let workspaceID: String
    let originalFilename: String
    let utiType: String
    let byteSize: Int
    let contentHash: String
    let localPath: String
    let thumbnailPath: String?
}

struct RemoteDeletedRecord: Equatable, Sendable {
    let entityType: String
    let entityID: String
}

final class SyncMergeEngine {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func applyRemoteWorkspace(_ remote: RemoteWorkspaceChange) throws {
        guard try !hasPendingLocalChange(entityType: "workspace", entityID: remote.workspaceID) else {
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            INSERT INTO workspaces (id, name, created_at, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                updated_at = excluded.updated_at
            """,
            bindings: [
                .text(remote.workspaceID),
                .text(remote.name),
                .text(now),
                .text(now)
            ]
        )
    }

    func applyRemoteNotebook(_ remote: RemoteNotebookChange) throws {
        guard try !hasPendingLocalChange(entityType: "notebook", entityID: remote.notebookID) else {
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            INSERT INTO notebooks (id, workspace_id, name, order_key, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                workspace_id = excluded.workspace_id,
                name = excluded.name,
                order_key = excluded.order_key,
                updated_at = excluded.updated_at
            """,
            bindings: [
                .text(remote.notebookID),
                .text(remote.workspaceID),
                .text(remote.name),
                .text(remote.orderKey),
                .text(now),
                .text(now)
            ]
        )
    }

    func applyRemotePage(_ remote: RemotePageChange) throws {
        guard try !hasPendingLocalChange(entityType: "page", entityID: remote.pageID) else {
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            INSERT INTO pages (
                id,
                workspace_id,
                notebook_id,
                title,
                order_key,
                is_archived,
                created_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                workspace_id = excluded.workspace_id,
                notebook_id = excluded.notebook_id,
                title = excluded.title,
                order_key = excluded.order_key,
                is_archived = excluded.is_archived,
                updated_at = excluded.updated_at
            """,
            bindings: [
                .text(remote.pageID),
                .text(remote.workspaceID),
                remote.notebookID.map(SQLiteValue.text) ?? .null,
                .text(remote.title),
                .text(remote.orderKey),
                .integer(remote.isArchived ? 1 : 0),
                .text(now),
                .text(now)
            ]
        )
    }

    func applyRemoteBlock(_ remote: RemoteBlockChange) throws {
        if try hasPendingLocalChange(entityType: "block", entityID: remote.blockID) {
            try ConflictRepository(database: database).storeConflict(
                ConflictVersion(
                    blockID: remote.blockID,
                    payloadJSON: remote.payloadJSON,
                    textPlain: remote.textPlain,
                    remoteRevision: remote.revision
                )
            )
            EditorLog.sync.debug(
                "sync_conflict_stored block_id=\(remote.blockID, privacy: .public) revision=\(remote.revision, privacy: .public)"
            )
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
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
            ON CONFLICT(id) DO UPDATE SET
                page_id = excluded.page_id,
                parent_block_id = excluded.parent_block_id,
                order_key = excluded.order_key,
                type = excluded.type,
                payload_json = excluded.payload_json,
                text_plain = excluded.text_plain,
                revision = excluded.revision,
                sync_state = excluded.sync_state,
                is_deleted = excluded.is_deleted,
                updated_at = excluded.updated_at
            """,
            bindings: [
                .text(remote.blockID),
                .text(remote.pageID),
                remote.parentBlockID.map(SQLiteValue.text) ?? .null,
                .text(remote.orderKey),
                .text(remote.type.rawValue),
                .text(remote.payloadJSON),
                .text(remote.textPlain),
                .integer(remote.revision),
                .text("synced"),
                .integer(remote.isDeleted ? 1 : 0),
                .text(now),
                .text(now)
            ]
        )
        if remote.isDeleted {
            try deleteSourceLinks(blockID: remote.blockID)
        } else {
            try BacklinkRepository(database: database).rebuildLinksForBlock(
                blockID: remote.blockID,
                text: remote.textPlain
            )
        }
    }

    func applyRemoteAttachment(_ remote: RemoteAttachmentChange) throws {
        guard try !hasPendingLocalChange(entityType: "attachment", entityID: remote.attachmentID) else {
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            INSERT INTO attachments (
                id,
                workspace_id,
                original_filename,
                uti_type,
                byte_size,
                content_hash,
                local_path,
                thumbnail_path,
                sync_state,
                created_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                workspace_id = excluded.workspace_id,
                original_filename = excluded.original_filename,
                uti_type = excluded.uti_type,
                byte_size = excluded.byte_size,
                content_hash = excluded.content_hash,
                local_path = excluded.local_path,
                thumbnail_path = excluded.thumbnail_path,
                sync_state = excluded.sync_state,
                updated_at = excluded.updated_at
            """,
            bindings: [
                .text(remote.attachmentID),
                .text(remote.workspaceID),
                .text(remote.originalFilename),
                .text(remote.utiType),
                .integer(remote.byteSize),
                .text(remote.contentHash),
                .text(remote.localPath),
                remote.thumbnailPath.map(SQLiteValue.text) ?? .null,
                .text("synced"),
                .text(now),
                .text(now)
            ]
        )
    }

    func applyRemoteDeletion(_ remote: RemoteDeletedRecord) throws {
        guard try !hasPendingLocalChange(entityType: remote.entityType, entityID: remote.entityID) else {
            return
        }

        switch remote.entityType {
        case "block":
            try applyRemoteBlockDeletion(blockID: remote.entityID)
        default:
            EditorLog.sync.debug(
                "remote_deletion_ignored entity_type=\(remote.entityType, privacy: .public) entity_id=\(remote.entityID, privacy: .public)"
            )
        }
    }

    private func hasPendingLocalChange(entityType: String, entityID: String) throws -> Bool {
        let rows = try database.query(
            """
            SELECT COUNT(*)
            FROM sync_changes
            WHERE entity_type = ? AND entity_id = ?
            """,
            bindings: [
                .text(entityType),
                .text(entityID)
            ]
        )
        return Int(rows.first?["COUNT(*)"] ?? "") ?? 0 > 0
    }

    private func applyRemoteBlockDeletion(blockID: String) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try database.execute(
                """
                UPDATE blocks
                SET is_deleted = 1,
                    sync_state = ?,
                    updated_at = ?
                WHERE id = ? AND is_deleted = 0
                """,
                bindings: [
                    .text("synced"),
                    .text(now),
                    .text(blockID)
                ]
            )
            try deleteSourceLinks(blockID: blockID)
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }

        EditorLog.sync.debug(
            "remote_block_deleted block_id=\(blockID, privacy: .public)"
        )
    }

    private func deleteSourceLinks(blockID: String) throws {
        try database.execute(
            """
            DELETE FROM links
            WHERE source_block_id = ?
            """,
            bindings: [.text(blockID)]
        )
    }
}
