import Foundation

struct RemoteWorkspaceChange: Equatable, Sendable {
    let workspaceID: String
    let name: String
    let updatedAt: String?

    init(workspaceID: String, name: String, updatedAt: String? = nil) {
        self.workspaceID = workspaceID
        self.name = name
        self.updatedAt = updatedAt
    }
}

struct RemoteNotebookChange: Equatable, Sendable {
    let notebookID: String
    let workspaceID: String
    let parentNotebookID: String?
    let name: String
    let orderKey: String
    let updatedAt: String?

    init(
        notebookID: String,
        workspaceID: String,
        parentNotebookID: String? = nil,
        name: String,
        orderKey: String,
        updatedAt: String? = nil
    ) {
        self.notebookID = notebookID
        self.workspaceID = workspaceID
        self.parentNotebookID = parentNotebookID
        self.name = name
        self.orderKey = orderKey
        self.updatedAt = updatedAt
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
    let isEncrypted: Bool
    let updatedAt: String?

    init(
        pageID: String,
        workspaceID: String,
        notebookID: String?,
        title: String,
        orderKey: String,
        isArchived: Bool,
        isFavorite: Bool = false,
        isEncrypted: Bool = false,
        updatedAt: String? = nil
    ) {
        self.pageID = pageID
        self.workspaceID = workspaceID
        self.notebookID = notebookID
        self.title = title
        self.orderKey = orderKey
        self.isArchived = isArchived
        self.isFavorite = isFavorite
        self.isEncrypted = isEncrypted
        self.updatedAt = updatedAt
    }
}

struct RemoteDiaryPageChange: Equatable, Sendable {
    let pageID: String
    let workspaceID: String
    let diaryDate: String
    let updatedAt: String?

    init(pageID: String, workspaceID: String, diaryDate: String, updatedAt: String? = nil) {
        self.pageID = pageID
        self.workspaceID = workspaceID
        self.diaryDate = diaryDate
        self.updatedAt = updatedAt
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
    let updatedAt: String?

    init(
        blockID: String,
        pageID: String,
        type: BlockType,
        textPlain: String,
        payloadJSON: String,
        revision: Int,
        parentBlockID: String? = nil,
        orderKey: String = "000001",
        isDeleted: Bool = false,
        updatedAt: String? = nil
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
        self.updatedAt = updatedAt
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
    let updatedAt: String?

    init(
        attachmentID: String,
        workspaceID: String,
        originalFilename: String,
        utiType: String,
        byteSize: Int,
        contentHash: String,
        localPath: String,
        thumbnailPath: String?,
        updatedAt: String? = nil
    ) {
        self.attachmentID = attachmentID
        self.workspaceID = workspaceID
        self.originalFilename = originalFilename
        self.utiType = utiType
        self.byteSize = byteSize
        self.contentHash = contentHash
        self.localPath = localPath
        self.thumbnailPath = thumbnailPath
        self.updatedAt = updatedAt
    }
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
        guard try shouldApplyRemoteChange(
            entityType: "workspace",
            entityID: remote.workspaceID,
            remoteUpdatedAt: remote.updatedAt,
            localUpdatedAt: localUpdatedAt(table: "workspaces", idColumn: "id", entityID: remote.workspaceID)
        ) else {
            return
        }

        let now = remote.updatedAt ?? ISO8601DateFormatter().string(from: Date())
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
        try clearPendingLocalChanges(entityType: "workspace", entityID: remote.workspaceID)
    }

    func applyRemoteNotebook(_ remote: RemoteNotebookChange) throws {
        guard try shouldApplyRemoteChange(
            entityType: "notebook",
            entityID: remote.notebookID,
            remoteUpdatedAt: remote.updatedAt,
            localUpdatedAt: localUpdatedAt(table: "notebooks", idColumn: "id", entityID: remote.notebookID)
        ) else {
            return
        }

        let now = remote.updatedAt ?? ISO8601DateFormatter().string(from: Date())
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
        try clearPendingLocalChanges(entityType: "notebook", entityID: remote.notebookID)
    }

    func applyRemotePage(_ remote: RemotePageChange) throws {
        guard try shouldApplyRemoteChange(
            entityType: "page",
            entityID: remote.pageID,
            remoteUpdatedAt: remote.updatedAt,
            localUpdatedAt: localUpdatedAt(table: "pages", idColumn: "id", entityID: remote.pageID)
        ) else {
            return
        }

        let now = remote.updatedAt ?? ISO8601DateFormatter().string(from: Date())
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
                is_encrypted,
                created_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                workspace_id = excluded.workspace_id,
                notebook_id = excluded.notebook_id,
                title = excluded.title,
                order_key = excluded.order_key,
                is_archived = excluded.is_archived,
                is_favorite = excluded.is_favorite,
                is_encrypted = excluded.is_encrypted,
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
                .integer(remote.isEncrypted ? 1 : 0),
                .text(now),
                .text(now)
            ]
        )
        try clearPendingLocalChanges(entityType: "page", entityID: remote.pageID)
    }

    func applyRemoteDiaryPage(_ remote: RemoteDiaryPageChange) throws {
        guard try shouldApplyRemoteChange(
            entityType: "diaryPage",
            entityID: remote.pageID,
            remoteUpdatedAt: remote.updatedAt,
            localUpdatedAt: localDiaryPageUpdatedAt(remote)
        ) else {
            return
        }

        let now = remote.updatedAt ?? ISO8601DateFormatter().string(from: Date())
        try database.withImmediateTransaction("apply_remote_diary_page") {
            try database.execute(
                """
                DELETE FROM diary_pages
                WHERE (workspace_id = ? AND diary_date = ?)
                   OR page_id = ?
                """,
                bindings: [
                    .text(remote.workspaceID),
                    .text(remote.diaryDate),
                    .text(remote.pageID)
                ]
            )
            try database.execute(
                """
                INSERT INTO diary_pages (page_id, workspace_id, diary_date, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(remote.pageID),
                    .text(remote.workspaceID),
                    .text(remote.diaryDate),
                    .text(now),
                    .text(now)
                ]
            )
            try clearPendingLocalChanges(entityType: "diaryPage", entityID: remote.pageID)
        }
    }

    func applyRemoteBlock(_ remote: RemoteBlockChange) throws {
        if try hasPendingLocalChange(entityType: "block", entityID: remote.blockID) {
            if let decision = try pendingTimestampDecision(
                entityType: "block",
                entityID: remote.blockID,
                remoteUpdatedAt: remote.updatedAt,
                localUpdatedAt: localUpdatedAt(table: "blocks", idColumn: "id", entityID: remote.blockID)
            ) {
                switch decision {
                case .applyRemote:
                    try applyRemoteBlockReplacingLocal(remote, shouldClearPendingLocalChanges: true)
                case .keepLocal:
                    EditorLog.sync.debug(
                        "sync_remote_block_lww_kept_local block_id=\(remote.blockID, privacy: .public)"
                    )
                }
                return
            }
            try autoMergeRemoteBlockWithPendingLocalChange(remote)
            return
        }

        try applyRemoteBlockReplacingLocal(remote, shouldClearPendingLocalChanges: false)
    }

    func applyRemoteBlockPageSnapshot(
        pageID: String,
        changes: [RemoteBlockChange],
        remoteUpdatedAt: String?
    ) throws {
        if try hasPendingLocalPageContentChange(pageID: pageID) {
            guard let decision = try pendingTimestampDecision(
                entityType: "pageSnapshot",
                entityID: pageID,
                remoteUpdatedAt: remoteUpdatedAt ?? Self.latestUpdatedAt(in: changes),
                localUpdatedAt: localUpdatedAt(table: "pages", idColumn: "id", entityID: pageID)
            ) else {
                EditorLog.sync.debug(
                    "sync_remote_page_snapshot_kept_local_missing_timestamp page_id=\(pageID, privacy: .public)"
                )
                return
            }

            guard decision == .applyRemote else {
                EditorLog.sync.debug(
                    "sync_remote_page_snapshot_lww_kept_local_merging_remote_blocks page_id=\(pageID, privacy: .public)"
                )
                try mergeRemoteBlockPageSnapshotWithPendingLocal(
                    pageID: pageID,
                    changes: changes
                )
                return
            }
        }

        try applyRemoteBlockPageSnapshotReplacingLocal(
            pageID: pageID,
            changes: changes,
            remoteUpdatedAt: remoteUpdatedAt
        )
    }

    private func mergeRemoteBlockPageSnapshotWithPendingLocal(
        pageID: String,
        changes: [RemoteBlockChange]
    ) throws {
        let sortedChanges = RemoteBlockChangeDependencySorter.sorted(changes)
        for remote in sortedChanges {
            try applyRemoteBlock(remote)
        }

        EditorLog.sync.debug(
            "sync_remote_page_snapshot_merged_with_pending_local page_id=\(pageID, privacy: .public) remote_blocks=\(sortedChanges.count, privacy: .public)"
        )
    }

    private func applyRemoteBlockPageSnapshotReplacingLocal(
        pageID: String,
        changes: [RemoteBlockChange],
        remoteUpdatedAt: String?
    ) throws {
        let sortedChanges = RemoteBlockChangeDependencySorter.sorted(changes)
        let localBlockIDs = Set(try blockIDs(pageID: pageID))
        let remoteBlockIDs = Set(sortedChanges.map(\.blockID))
        let remoteDeletedBlockIDs = Set(sortedChanges.filter(\.isDeleted).map(\.blockID))
        let missingLocalBlockIDs = localBlockIDs.subtracting(remoteBlockIDs)
        let deletedBlockIDs = missingLocalBlockIDs.union(remoteDeletedBlockIDs)
        let timestamp = remoteUpdatedAt
            ?? Self.latestUpdatedAt(in: sortedChanges)
            ?? ISO8601DateFormatter().string(from: Date())

        try database.withImmediateTransaction("apply_remote_block_page_snapshot") {
            try database.execute(
                """
                UPDATE pages
                SET updated_at = ?
                WHERE id = ?
                """,
                bindings: [
                    .text(timestamp),
                    .text(pageID)
                ]
            )

            if !deletedBlockIDs.isEmpty {
                let placeholders = Array(repeating: "?", count: deletedBlockIDs.count).joined(separator: ", ")
                try database.execute(
                    """
                    UPDATE blocks
                    SET is_deleted = 1,
                        sync_state = ?,
                        updated_at = ?
                    WHERE id IN (\(placeholders))
                    """,
                    bindings: [
                        .text("synced"),
                        .text(timestamp)
                    ] + deletedBlockIDs.map(SQLiteValue.text)
                )
            }

            for remote in sortedChanges {
                let now = remote.updatedAt ?? timestamp
                let parentBlockID = try resolvableParentBlockID(
                    remote.parentBlockID,
                    childBlockID: remote.blockID
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
                        parentBlockID.map(SQLiteValue.text) ?? .null,
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
                try database.execute(
                    """
                    DELETE FROM conflict_versions
                    WHERE block_id = ?
                    """,
                    bindings: [.text(remote.blockID)]
                )
            }

            try clearPendingLocalPageContentChanges(
                pageID: pageID,
                blockIDs: localBlockIDs.union(remoteBlockIDs)
            )
        }

        for blockID in deletedBlockIDs {
            try deleteSourceLinks(blockID: blockID)
            try deletePageParentLink(sourceBlockID: blockID)
        }
        for remote in sortedChanges {
            if remote.isDeleted {
                try deleteSourceLinks(blockID: remote.blockID)
                try deletePageParentLink(sourceBlockID: remote.blockID)
            } else {
                let pageReferenceTargetPageID = Self.pageReferenceTargetPageID(payloadJSON: remote.payloadJSON)
                try BacklinkRepository(database: database).rebuildLinksForBlock(
                    blockID: remote.blockID,
                    text: remote.textPlain,
                    pageReferenceTargetPageID: pageReferenceTargetPageID,
                    blockReferenceTargetBlockID: remote.type == .blockReference
                        ? Self.blockReferenceTargetBlockID(payloadJSON: remote.payloadJSON)
                        : nil
                )
                try syncPageParentLink(
                    sourceBlockID: remote.blockID,
                    parentPageID: remote.pageID,
                    childPageID: pageReferenceTargetPageID,
                    orderKey: remote.orderKey
                )
            }
        }

        EditorLog.sync.debug(
            "sync_remote_page_snapshot_applied page_id=\(pageID, privacy: .public) remote_blocks=\(sortedChanges.count, privacy: .public) deleted_local_blocks=\(deletedBlockIDs.count, privacy: .public)"
        )
    }

    private func applyRemoteBlockReplacingLocal(
        _ remote: RemoteBlockChange,
        shouldClearPendingLocalChanges: Bool
    ) throws {
        let now = remote.updatedAt ?? ISO8601DateFormatter().string(from: Date())
        let parentBlockID = try resolvableParentBlockID(remote.parentBlockID, childBlockID: remote.blockID)
        try database.withImmediateTransaction("apply_remote_block") {
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
                    parentBlockID.map(SQLiteValue.text) ?? .null,
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
            try database.execute(
                """
                DELETE FROM conflict_versions
                WHERE block_id = ?
                """,
                bindings: [.text(remote.blockID)]
            )
            if shouldClearPendingLocalChanges {
                try clearPendingLocalChanges(entityType: "block", entityID: remote.blockID)
            }
        }
        if remote.isDeleted {
            try deleteSourceLinks(blockID: remote.blockID)
            try deletePageParentLink(sourceBlockID: remote.blockID)
        } else {
            let pageReferenceTargetPageID = Self.pageReferenceTargetPageID(payloadJSON: remote.payloadJSON)
            try BacklinkRepository(database: database).rebuildLinksForBlock(
                blockID: remote.blockID,
                text: remote.textPlain,
                pageReferenceTargetPageID: pageReferenceTargetPageID,
                blockReferenceTargetBlockID: remote.type == .blockReference
                    ? Self.blockReferenceTargetBlockID(payloadJSON: remote.payloadJSON)
                    : nil
            )
            try syncPageParentLink(
                sourceBlockID: remote.blockID,
                parentPageID: remote.pageID,
                childPageID: pageReferenceTargetPageID,
                orderKey: remote.orderKey
            )
        }
    }

    private func autoMergeRemoteBlockWithPendingLocalChange(_ remote: RemoteBlockChange) throws {
        guard !remote.isDeleted else {
            EditorLog.sync.debug(
                "sync_remote_block_delete_kept_local block_id=\(remote.blockID, privacy: .public) revision=\(remote.revision, privacy: .public)"
            )
            return
        }

        guard let localRow = try database.query(
            """
            SELECT payload_json,
                   text_plain,
                   revision
            FROM blocks
            WHERE id = ? AND is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(remote.blockID)]
        ).first else {
            EditorLog.sync.debug(
                "sync_remote_block_auto_merge_missing_local block_id=\(remote.blockID, privacy: .public)"
            )
            return
        }

        let localText = localRow["text_plain"] ?? ""
        let mergedText = AutomaticTextMerge.merge(local: localText, remote: remote.textPlain)
        let payloadJSON = try AutomaticTextMerge.payloadJSON(
            updating: localRow["payload_json"] ?? "",
            text: mergedText
        )
        let localRevision = Int(localRow["revision"] ?? "") ?? 0
        let mergedRevision = max(localRevision, remote.revision) + 1
        let now = ISO8601DateFormatter().string(from: Date())

        try database.withImmediateTransaction("auto_merge_remote_block") {
            try database.execute(
                """
                UPDATE blocks
                SET payload_json = ?,
                    text_plain = ?,
                    revision = ?,
                    sync_state = ?,
                    updated_at = ?
                WHERE id = ? AND is_deleted = 0
                """,
                bindings: [
                    .text(payloadJSON),
                    .text(mergedText),
                    .integer(mergedRevision),
                    .text("local"),
                    .text(now),
                    .text(remote.blockID)
                ]
            )
            try database.execute(
                """
                DELETE FROM conflict_versions
                WHERE block_id = ?
                """,
                bindings: [.text(remote.blockID)]
            )
            try BacklinkRepository(database: database).rebuildLinksForBlock(
                blockID: remote.blockID,
                text: mergedText,
                pageReferenceTargetPageID: Self.pageReferenceTargetPageID(payloadJSON: payloadJSON),
                blockReferenceTargetBlockID: remote.type == .blockReference
                    ? Self.blockReferenceTargetBlockID(payloadJSON: payloadJSON)
                    : nil
            )
        }
        try syncPageParentLink(
            sourceBlockID: remote.blockID,
            parentPageID: remote.pageID,
            childPageID: Self.pageReferenceTargetPageID(payloadJSON: payloadJSON),
            orderKey: remote.orderKey
        )

        EditorLog.sync.debug(
            "sync_remote_block_auto_merged block_id=\(remote.blockID, privacy: .public) local_revision=\(localRevision, privacy: .public) remote_revision=\(remote.revision, privacy: .public)"
        )
    }

    private func resolvableParentBlockID(_ parentBlockID: String?, childBlockID: String) throws -> String? {
        guard let parentBlockID else {
            return nil
        }
        let rows = try database.query(
            """
            SELECT COUNT(*)
            FROM blocks
            WHERE id = ?
            """,
            bindings: [.text(parentBlockID)]
        )
        guard Int(rows.first?["COUNT(*)"] ?? "") ?? 0 > 0 else {
            EditorLog.sync.error(
                "remote_block_parent_missing child_block_id=\(childBlockID, privacy: .public) parent_block_id=\(parentBlockID, privacy: .public) action=reparent_to_root"
            )
            return nil
        }
        return parentBlockID
    }

    func applyRemoteAttachment(_ remote: RemoteAttachmentChange) throws {
        guard try shouldApplyRemoteChange(
            entityType: "attachment",
            entityID: remote.attachmentID,
            remoteUpdatedAt: remote.updatedAt,
            localUpdatedAt: localUpdatedAt(table: "attachments", idColumn: "id", entityID: remote.attachmentID)
        ) else {
            return
        }

        let now = remote.updatedAt ?? ISO8601DateFormatter().string(from: Date())
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
        try clearPendingLocalChanges(entityType: "attachment", entityID: remote.attachmentID)
    }

    func applyRemoteDeletion(_ remote: RemoteDeletedRecord) throws {
        guard try !hasPendingLocalChange(entityType: remote.entityType, entityID: remote.entityID) else {
            return
        }

        switch remote.entityType {
        case "page":
            try applyRemotePageDeletion(pageID: remote.entityID)
        case "diaryPage":
            try applyRemoteDiaryPageDeletion(pageID: remote.entityID)
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

    private func hasPendingLocalPageContentChange(pageID: String) throws -> Bool {
        let rows = try database.query(
            """
            SELECT COUNT(*) AS count
            FROM sync_changes
            WHERE (entity_type = 'page' AND entity_id = ?)
               OR (
                   entity_type = 'block'
                   AND entity_id IN (
                       SELECT id
                       FROM blocks
                       WHERE page_id = ?
                   )
               )
            """,
            bindings: [
                .text(pageID),
                .text(pageID)
            ]
        )
        return Int(rows.first?["count"] ?? "") ?? 0 > 0
    }

    private enum PendingTimestampDecision {
        case applyRemote
        case keepLocal
    }

    private func shouldApplyRemoteChange(
        entityType: String,
        entityID: String,
        remoteUpdatedAt: String?,
        localUpdatedAt: String?
    ) throws -> Bool {
        guard try hasPendingLocalChange(entityType: entityType, entityID: entityID) else {
            return true
        }
        guard let decision = try pendingTimestampDecision(
            entityType: entityType,
            entityID: entityID,
            remoteUpdatedAt: remoteUpdatedAt,
            localUpdatedAt: localUpdatedAt
        ) else {
            return false
        }
        return decision == .applyRemote
    }

    private func pendingTimestampDecision(
        entityType: String,
        entityID: String,
        remoteUpdatedAt: String?,
        localUpdatedAt: String?
    ) throws -> PendingTimestampDecision? {
        guard let remoteUpdatedAt, let localUpdatedAt else {
            return nil
        }
        let decision: PendingTimestampDecision = Self.compareRemoteToLocal(
            remoteUpdatedAt: remoteUpdatedAt,
            localUpdatedAt: localUpdatedAt
        ) == .orderedAscending ? .keepLocal : .applyRemote
        if decision == .applyRemote {
            EditorLog.sync.debug(
                "sync_remote_lww_applied_remote entity_type=\(entityType, privacy: .public) entity_id=\(entityID, privacy: .public)"
            )
        } else {
            EditorLog.sync.debug(
                "sync_remote_lww_kept_local entity_type=\(entityType, privacy: .public) entity_id=\(entityID, privacy: .public)"
            )
        }
        return decision
    }

    private func clearPendingLocalChanges(entityType: String, entityID: String) throws {
        try database.execute(
            """
            DELETE FROM sync_changes
            WHERE entity_type = ?
              AND entity_id = ?
            """,
            bindings: [
                .text(entityType),
                .text(entityID)
            ]
        )
    }

    private func clearPendingLocalPageContentChanges(pageID: String, blockIDs: Set<String>) throws {
        try clearPendingLocalChanges(entityType: "page", entityID: pageID)
        guard !blockIDs.isEmpty else {
            return
        }

        let placeholders = Array(repeating: "?", count: blockIDs.count).joined(separator: ", ")
        try database.execute(
            """
            DELETE FROM sync_changes
            WHERE entity_type = 'block'
              AND entity_id IN (\(placeholders))
            """,
            bindings: blockIDs.map(SQLiteValue.text)
        )
    }

    private func localUpdatedAt(table: String, idColumn: String, entityID: String) throws -> String? {
        try database.query(
            """
            SELECT updated_at
            FROM \(table)
            WHERE \(idColumn) = ?
            LIMIT 1
            """,
            bindings: [.text(entityID)]
        ).first?["updated_at"] ?? nil
    }

    private func blockIDs(pageID: String) throws -> [String] {
        try database.query(
            """
            SELECT id
            FROM blocks
            WHERE page_id = ?
            """,
            bindings: [.text(pageID)]
        ).compactMap { $0["id"] }
    }

    private func localDiaryPageUpdatedAt(_ remote: RemoteDiaryPageChange) throws -> String? {
        try database.query(
            """
            SELECT updated_at
            FROM diary_pages
            WHERE page_id = ?
               OR (workspace_id = ? AND diary_date = ?)
            ORDER BY updated_at DESC
            LIMIT 1
            """,
            bindings: [
                .text(remote.pageID),
                .text(remote.workspaceID),
                .text(remote.diaryDate)
            ]
        ).first?["updated_at"] ?? nil
    }

    private static func compareRemoteToLocal(
        remoteUpdatedAt: String,
        localUpdatedAt: String
    ) -> ComparisonResult {
        if let remoteDate = parseTimestamp(remoteUpdatedAt),
           let localDate = parseTimestamp(localUpdatedAt) {
            return remoteDate.compare(localDate)
        }
        if remoteUpdatedAt == localUpdatedAt {
            return .orderedSame
        }
        return remoteUpdatedAt < localUpdatedAt ? .orderedAscending : .orderedDescending
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func latestUpdatedAt(in changes: [RemoteBlockChange]) -> String? {
        changes.compactMap(\.updatedAt).max()
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

    private func applyRemoteDiaryPageDeletion(pageID: String) throws {
        try database.execute(
            """
            DELETE FROM diary_pages
            WHERE page_id = ?
            """,
            bindings: [.text(pageID)]
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
            try deletePageParentLink(sourceBlockID: blockID)
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

    private func syncPageParentLink(
        sourceBlockID: String,
        parentPageID: String,
        childPageID: String?,
        orderKey: String
    ) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try database.withImmediateTransaction("sync_remote_page_parent_link") {
            try deletePageParentLink(sourceBlockID: sourceBlockID)
            guard let childPageID else {
                return
            }

            try database.execute(
                """
                INSERT OR REPLACE INTO page_parent_links (
                    parent_page_id,
                    child_page_id,
                    source_block_id,
                    order_key,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(parentPageID),
                    .text(childPageID),
                    .text(sourceBlockID),
                    .text(orderKey),
                    .text(now),
                    .text(now)
                ]
            )
        }
    }

    private func deletePageParentLink(sourceBlockID: String) throws {
        try database.execute(
            """
            DELETE FROM page_parent_links
            WHERE source_block_id = ?
            """,
            bindings: [.text(sourceBlockID)]
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
