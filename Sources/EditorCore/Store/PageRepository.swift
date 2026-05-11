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

    func updatePageTitle(pageID: String, title: String) throws {
        let rows = try database.query(
            """
            SELECT id
            FROM pages
            WHERE id = ? AND is_archived = 0
            LIMIT 1
            """,
            bindings: [.text(pageID)]
        )
        guard rows.first != nil else {
            throw PageRepositoryError.pageNotFound
        }

        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            UPDATE pages
            SET title = ?,
                updated_at = ?
            WHERE id = ? AND is_archived = 0
            """,
            bindings: [
                .text(title),
                .text(now),
                .text(pageID)
            ]
        )
        try SyncRepository(database: database).enqueue(
            entityType: "page",
            entityID: pageID,
            changeType: "update"
        )

        EditorLog.store.debug(
            "page_title_updated page_id=\(pageID, privacy: .public) length=\(title.count, privacy: .public)"
        )
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
        try BacklinkRepository(database: database).rebuildLinksForBlock(
            blockID: blockID,
            text: text
        )
    }

    func importMarkdown(pageID: String, markdown: String) throws {
        let drafts = MarkdownTransformer.importBlocks(markdown: markdown)
        let now = ISO8601DateFormatter().string(from: Date())

        try database.execute(
            """
            UPDATE blocks
            SET is_deleted = 1,
                updated_at = ?
            WHERE page_id = ? AND is_deleted = 0
            """,
            bindings: [
                .text(now),
                .text(pageID)
            ]
        )
        try database.execute(
            """
            DELETE FROM links
            WHERE source_page_id = ?
            """,
            bindings: [.text(pageID)]
        )

        for (index, draft) in drafts.enumerated() {
            let blockID = "block-\(UUID().uuidString.lowercased())"
            try insertBlock(
                id: blockID,
                pageID: pageID,
                orderKey: String(format: "%06d", index + 1),
                type: draft.type,
                text: draft.textPlain,
                createdAt: now
            )
            try SyncRepository(database: database).enqueue(
                entityType: "block",
                entityID: blockID,
                changeType: "create"
            )
            try BacklinkRepository(database: database).rebuildLinksForBlock(
                blockID: blockID,
                text: draft.textPlain
            )
        }

        EditorLog.markdown.debug(
            "markdown_imported page_id=\(pageID, privacy: .public) blocks=\(drafts.count, privacy: .public)"
        )
    }

    func appendBlock(pageID: String, type: BlockType, text: String) throws -> BlockSnapshot {
        let pageRows = try database.query(
            """
            SELECT id
            FROM pages
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(pageID)]
        )
        guard pageRows.first != nil else {
            throw PageRepositoryError.pageNotFound
        }

        let blockCountRows = try database.query(
            """
            SELECT COUNT(*) AS block_count
            FROM blocks
            WHERE page_id = ? AND is_deleted = 0
            """,
            bindings: [.text(pageID)]
        )
        let blockCount = Int(blockCountRows.first?["block_count"] ?? "") ?? 0
        let now = ISO8601DateFormatter().string(from: Date())
        let blockID = "block-\(UUID().uuidString.lowercased())"
        let orderKey = String(format: "%06d", blockCount + 1)

        try insertBlock(
            id: blockID,
            pageID: pageID,
            orderKey: orderKey,
            type: type,
            text: text,
            createdAt: now
        )
        try SyncRepository(database: database).enqueue(
            entityType: "block",
            entityID: blockID,
            changeType: "create"
        )
        try BacklinkRepository(database: database).rebuildLinksForBlock(
            blockID: blockID,
            text: text
        )

        EditorLog.store.debug(
            "block_appended block_id=\(blockID, privacy: .public) page_id=\(pageID, privacy: .public) type=\(type.rawValue, privacy: .public)"
        )

        return BlockSnapshot(
            id: blockID,
            pageID: pageID,
            parentBlockID: nil,
            orderKey: orderKey,
            type: type,
            textPlain: text
        )
    }

    func moveBlock(blockID: String, toIndex targetIndex: Int) throws {
        let selectedRows = try database.query(
            """
            SELECT page_id
            FROM blocks
            WHERE id = ? AND is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        )

        guard let pageID = selectedRows.first?["page_id"] ?? nil else {
            throw PageRepositoryError.blockNotFound
        }

        let blocks = try database.query(
            """
            SELECT id, order_key
            FROM blocks
            WHERE page_id = ? AND is_deleted = 0
            ORDER BY order_key ASC
            """,
            bindings: [.text(pageID)]
        ).map { row in
            OrderedBlock(
                id: row["id"] ?? "",
                orderKey: row["order_key"] ?? ""
            )
        }

        guard let currentIndex = blocks.firstIndex(where: { $0.id == blockID }) else {
            throw PageRepositoryError.blockNotFound
        }

        var reorderedBlocks = blocks
        let movingBlock = reorderedBlocks.remove(at: currentIndex)
        let clampedTargetIndex = min(max(targetIndex, 0), reorderedBlocks.count)
        reorderedBlocks.insert(movingBlock, at: clampedTargetIndex)

        let now = ISO8601DateFormatter().string(from: Date())
        var changedBlockIDs: [String] = []
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            for (index, block) in reorderedBlocks.enumerated() {
                let nextOrderKey = String(format: "%06d", index + 1)
                guard nextOrderKey != block.orderKey else {
                    continue
                }

                try database.execute(
                    """
                    UPDATE blocks
                    SET order_key = ?,
                        revision = revision + 1,
                        sync_state = ?,
                        updated_at = ?
                    WHERE id = ? AND is_deleted = 0
                    """,
                    bindings: [
                        .text(nextOrderKey),
                        .text("local"),
                        .text(now),
                        .text(block.id)
                    ]
                )
                changedBlockIDs.append(block.id)
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }

        let syncRepository = SyncRepository(database: database)
        for changedBlockID in changedBlockIDs {
            try syncRepository.enqueue(
                entityType: "block",
                entityID: changedBlockID,
                changeType: "update"
            )
        }

        EditorLog.store.debug(
            "block_moved block_id=\(blockID, privacy: .public) page_id=\(pageID, privacy: .public) target_index=\(targetIndex, privacy: .public) changed_blocks=\(changedBlockIDs.count, privacy: .public)"
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

    private func insertBlock(
        id: String,
        pageID: String,
        orderKey: String,
        type: BlockType,
        text: String,
        createdAt: String
    ) throws {
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
                .text(id),
                .text(pageID),
                .null,
                .text(orderKey),
                .text(type.rawValue),
                .text(try blockPayloadJSON(type: type, text: text)),
                .text(text),
                .integer(1),
                .text("local"),
                .integer(0),
                .text(createdAt),
                .text(createdAt)
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
    case pageNotFound
    case blockNotFound
    case invalidPayloadEncoding
}

private struct OrderedBlock {
    let id: String
    let orderKey: String
}
