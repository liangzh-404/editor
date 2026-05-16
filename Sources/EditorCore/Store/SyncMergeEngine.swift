import Foundation

struct RemoteWorkspaceChange: Equatable, Sendable {
    let workspaceID: String
    let name: String
}

struct RemoteNotebookChange: Equatable, Sendable {
    let notebookID: String
    let workspaceID: String
    let parentNotebookID: String?
    let name: String
    let orderKey: String

    init(
        notebookID: String,
        workspaceID: String,
        parentNotebookID: String? = nil,
        name: String,
        orderKey: String
    ) {
        self.notebookID = notebookID
        self.workspaceID = workspaceID
        self.parentNotebookID = parentNotebookID
        self.name = name
        self.orderKey = orderKey
    }
}

struct RemotePageChange: Equatable, Sendable {
    let pageID: String
    let workspaceID: String
    let notebookID: String?
    let title: String
    let orderKey: String
    let isArchived: Bool
    let isFavorite: Bool

    init(
        pageID: String,
        workspaceID: String,
        notebookID: String?,
        title: String,
        orderKey: String,
        isArchived: Bool,
        isFavorite: Bool = false
    ) {
        self.pageID = pageID
        self.workspaceID = workspaceID
        self.notebookID = notebookID
        self.title = title
        self.orderKey = orderKey
        self.isArchived = isArchived
        self.isFavorite = isFavorite
    }
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
            INSERT INTO notebooks (id, workspace_id, parent_notebook_id, name, order_key, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                workspace_id = excluded.workspace_id,
                parent_notebook_id = excluded.parent_notebook_id,
                name = excluded.name,
                order_key = excluded.order_key,
                updated_at = excluded.updated_at
            """,
            bindings: [
                .text(remote.notebookID),
                .text(remote.workspaceID),
                remote.parentNotebookID.map(SQLiteValue.text) ?? .null,
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
                is_favorite,
                created_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                workspace_id = excluded.workspace_id,
                notebook_id = excluded.notebook_id,
                title = excluded.title,
                order_key = excluded.order_key,
                is_archived = excluded.is_archived,
                is_favorite = excluded.is_favorite,
                updated_at = excluded.updated_at
            """,
            bindings: [
                .text(remote.pageID),
                .text(remote.workspaceID),
                remote.notebookID.map(SQLiteValue.text) ?? .null,
                .text(remote.title),
                .text(remote.orderKey),
                .integer(remote.isArchived ? 1 : 0),
                .integer(remote.isFavorite ? 1 : 0),
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
                text: remote.textPlain,
                pageReferenceTargetPageID: remote.type == .pageReference || remote.type == .blockReference
                    ? Self.pageReferenceTargetPageID(payloadJSON: remote.payloadJSON)
                    : nil,
                blockReferenceTargetBlockID: remote.type == .blockReference
                    ? Self.blockReferenceTargetBlockID(payloadJSON: remote.payloadJSON)
                    : nil
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
        case "page":
            try applyRemotePageDeletion(pageID: remote.entityID)
        case "notebook":
            try applyRemoteNotebookDeletion(notebookID: remote.entityID)
        case "attachment":
            try applyRemoteAttachmentDeletion(attachmentID: remote.entityID)
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

    private func applyRemotePageDeletion(pageID: String) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try database.withImmediateTransaction("apply_remote_page_deletion") {
            try database.execute(
                """
                UPDATE pages
                SET is_archived = 1,
                    updated_at = ?
                WHERE id = ? AND is_archived = 0
                """,
                bindings: [
                    .text(now),
                    .text(pageID)
                ]
            )
            try database.execute(
                """
                UPDATE blocks
                SET is_deleted = 1,
                    sync_state = ?,
                    updated_at = ?
                WHERE page_id = ? AND is_deleted = 0
                """,
                bindings: [
                    .text("synced"),
                    .text(now),
                    .text(pageID)
                ]
            )
            try database.execute(
                """
                DELETE FROM links
                WHERE source_page_id = ? OR target_page_id = ?
                """,
                bindings: [
                    .text(pageID),
                    .text(pageID)
                ]
            )
            try database.execute(
                """
                DELETE FROM search_index
                WHERE (entity_type = 'page' AND entity_id = ?)
                   OR (entity_type = 'block' AND entity_id IN (
                       SELECT id FROM blocks WHERE page_id = ?
                   ))
                """,
                bindings: [
                    .text(pageID),
                    .text(pageID)
                ]
            )
        }

        EditorLog.sync.debug(
            "remote_page_deleted page_id=\(pageID, privacy: .public)"
        )
    }

    private func applyRemoteNotebookDeletion(notebookID: String) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try database.withImmediateTransaction("apply_remote_notebook_deletion") {
            try database.execute(
                """
                UPDATE pages
                SET notebook_id = NULL,
                    updated_at = ?
                WHERE notebook_id = ?
                """,
                bindings: [
                    .text(now),
                    .text(notebookID)
                ]
            )
            try database.execute(
                """
                DELETE FROM notebooks
                WHERE id = ?
                """,
                bindings: [.text(notebookID)]
            )
        }

        EditorLog.sync.debug(
            "remote_notebook_deleted notebook_id=\(notebookID, privacy: .public)"
        )
    }

    private func applyRemoteAttachmentDeletion(attachmentID: String) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try database.withImmediateTransaction("apply_remote_attachment_deletion") {
            try database.execute(
                """
                DELETE FROM links
                WHERE source_block_id IN (
                    SELECT id
                    FROM blocks
                    WHERE json_extract(payload_json, '$.attachment_id') = ?
                )
                """,
                bindings: [.text(attachmentID)]
            )
            try database.execute(
                """
                UPDATE blocks
                SET is_deleted = 1,
                    sync_state = ?,
                    updated_at = ?
                WHERE is_deleted = 0
                  AND json_extract(payload_json, '$.attachment_id') = ?
                """,
                bindings: [
                    .text("synced"),
                    .text(now),
                    .text(attachmentID)
                ]
            )
            try database.execute(
                """
                DELETE FROM search_index
                WHERE (entity_type = 'attachment' AND entity_id = ?)
                   OR (entity_type = 'block' AND entity_id IN (
                       SELECT id
                       FROM blocks
                       WHERE json_extract(payload_json, '$.attachment_id') = ?
                   ))
                """,
                bindings: [
                    .text(attachmentID),
                    .text(attachmentID)
                ]
            )
            try database.execute(
                """
                DELETE FROM attachments
                WHERE id = ?
                """,
                bindings: [.text(attachmentID)]
            )
        }

        EditorLog.sync.debug(
            "remote_attachment_deleted attachment_id=\(attachmentID, privacy: .public)"
        )
    }

    private func applyRemoteBlockDeletion(blockID: String) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try database.withImmediateTransaction("apply_remote_block_deletion") {
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

    private static func pageReferenceTargetPageID(payloadJSON: String) -> String? {
        guard let data = payloadJSON.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let targetPageID = payload["target_page_id"] as? String,
              !targetPageID.isEmpty else {
            return nil
        }

        return targetPageID
    }

    private static func blockReferenceTargetBlockID(payloadJSON: String) -> String? {
        guard let data = payloadJSON.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let targetBlockID = payload["target_block_id"] as? String,
              !targetBlockID.isEmpty else {
            return nil
        }

        return targetBlockID
    }
}
