import Foundation

final class PageRepository {
    private let database: SQLiteDatabase

    private let defaultWorkspaceID = "workspace-local"
    private let defaultNotebookID = "notebook-local"
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

        let notebooks = try database.query(
            """
            SELECT id, workspace_id, name
            FROM notebooks
            WHERE workspace_id = ?
            ORDER BY order_key ASC
            """,
            bindings: selectedWorkspaceID.map { [.text($0)] } ?? [.text("")]
        ).map { row in
            NotebookSummary(
                id: row["id"] ?? "",
                workspaceID: row["workspace_id"] ?? "",
                name: row["name"] ?? ""
            )
        }

        let selectedNotebookID = notebooks.first?.id

        let pages = try database.query(
            """
            SELECT pages.id,
                   pages.workspace_id,
                   pages.notebook_id,
                   pages.title
            FROM pages
            LEFT JOIN notebooks ON notebooks.id = pages.notebook_id
            WHERE pages.workspace_id = ?
              AND pages.is_archived = 0
            ORDER BY COALESCE(notebooks.order_key, '999999'), pages.order_key ASC
            """,
            bindings: selectedWorkspaceID.map { [.text($0)] } ?? [.text("")]
        ).map { row in
            PageSummary(
                id: row["id"] ?? "",
                workspaceID: row["workspace_id"] ?? "",
                notebookID: row["notebook_id"] ?? nil,
                title: row["title"] ?? ""
            )
        }

        let archivedPages = try database.query(
            """
            SELECT pages.id,
                   pages.workspace_id,
                   pages.notebook_id,
                   pages.title
            FROM pages
            LEFT JOIN notebooks ON notebooks.id = pages.notebook_id
            WHERE pages.workspace_id = ?
              AND pages.is_archived = 1
            ORDER BY pages.updated_at DESC
            """,
            bindings: selectedWorkspaceID.map { [.text($0)] } ?? [.text("")]
        ).map { row in
            PageSummary(
                id: row["id"] ?? "",
                workspaceID: row["workspace_id"] ?? "",
                notebookID: row["notebook_id"] ?? nil,
                title: row["title"] ?? ""
            )
        }

        let selectedPageID = pages.first?.id

        let blocks = try loadBlocks(pageIDs: pages.map(\.id))

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
            notebooks: notebooks,
            pages: pages,
            archivedPages: archivedPages,
            blocks: blocks,
            attachments: attachments,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedNotebookID: selectedNotebookID,
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

    func createNotebook(workspaceID: String, name: String) throws -> NotebookSummary {
        let workspaceRows = try database.query(
            """
            SELECT id
            FROM workspaces
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(workspaceID)]
        )
        guard workspaceRows.first != nil else {
            throw PageRepositoryError.workspaceNotFound
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let notebookID = "notebook-\(UUID().uuidString.lowercased())"
        let orderKey = try nextNotebookOrderKey(workspaceID: workspaceID)

        try database.execute(
            """
            INSERT INTO notebooks (id, workspace_id, name, order_key, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(notebookID),
                .text(workspaceID),
                .text(name),
                .text(orderKey),
                .text(now),
                .text(now)
            ]
        )
        try SyncRepository(database: database).enqueue(
            entityType: "notebook",
            entityID: notebookID,
            changeType: "create"
        )

        EditorLog.store.debug(
            "notebook_created notebook_id=\(notebookID, privacy: .public) workspace_id=\(workspaceID, privacy: .public)"
        )

        return NotebookSummary(id: notebookID, workspaceID: workspaceID, name: name)
    }

    func updateNotebookName(notebookID: String, name: String) throws {
        let rows = try database.query(
            """
            SELECT id
            FROM notebooks
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(notebookID)]
        )
        guard rows.first != nil else {
            throw PageRepositoryError.notebookNotFound
        }

        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            UPDATE notebooks
            SET name = ?,
                updated_at = ?
            WHERE id = ?
            """,
            bindings: [
                .text(name),
                .text(now),
                .text(notebookID)
            ]
        )
        try SyncRepository(database: database).enqueue(
            entityType: "notebook",
            entityID: notebookID,
            changeType: "update"
        )

        EditorLog.store.debug(
            "notebook_renamed notebook_id=\(notebookID, privacy: .public) length=\(name.count, privacy: .public)"
        )
    }

    func moveNotebook(notebookID: String, toIndex targetIndex: Int) throws {
        let selectedRows = try database.query(
            """
            SELECT workspace_id
            FROM notebooks
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(notebookID)]
        )

        guard let workspaceID = selectedRows.first?["workspace_id"] ?? nil else {
            throw PageRepositoryError.notebookNotFound
        }

        let notebooks = try database.query(
            """
            SELECT id, order_key
            FROM notebooks
            WHERE workspace_id = ?
            ORDER BY order_key ASC
            """,
            bindings: [.text(workspaceID)]
        ).map { row in
            OrderedNotebook(
                id: row["id"] ?? "",
                orderKey: row["order_key"] ?? ""
            )
        }

        guard let currentIndex = notebooks.firstIndex(where: { $0.id == notebookID }) else {
            throw PageRepositoryError.notebookNotFound
        }

        var reorderedNotebooks = notebooks
        let movingNotebook = reorderedNotebooks.remove(at: currentIndex)
        let clampedTargetIndex = min(max(targetIndex, 0), reorderedNotebooks.count)
        reorderedNotebooks.insert(movingNotebook, at: clampedTargetIndex)

        let now = ISO8601DateFormatter().string(from: Date())
        var changedNotebookIDs: [String] = []
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            for (index, notebook) in reorderedNotebooks.enumerated() {
                let nextOrderKey = String(format: "%06d", index + 1)
                guard nextOrderKey != notebook.orderKey else {
                    continue
                }

                try database.execute(
                    """
                    UPDATE notebooks
                    SET order_key = ?,
                        updated_at = ?
                    WHERE id = ?
                    """,
                    bindings: [
                        .text(nextOrderKey),
                        .text(now),
                        .text(notebook.id)
                    ]
                )
                changedNotebookIDs.append(notebook.id)
            }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }

        let syncRepository = SyncRepository(database: database)
        for changedNotebookID in changedNotebookIDs {
            try syncRepository.enqueue(
                entityType: "notebook",
                entityID: changedNotebookID,
                changeType: "update"
            )
        }

        EditorLog.store.debug(
            "notebook_moved notebook_id=\(notebookID, privacy: .public) workspace_id=\(workspaceID, privacy: .public) target_index=\(targetIndex, privacy: .public) changed_notebooks=\(changedNotebookIDs.count, privacy: .public)"
        )
    }

    func createPage(workspaceID: String, title: String, notebookID: String? = nil) throws -> PageSummary {
        let workspaceRows = try database.query(
            """
            SELECT id
            FROM workspaces
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(workspaceID)]
        )
        guard workspaceRows.first != nil else {
            throw PageRepositoryError.workspaceNotFound
        }

        let resolvedNotebookID = try notebookID ?? defaultNotebookID(for: workspaceID)
        if let resolvedNotebookID {
            let notebookRows = try database.query(
                """
                SELECT id
                FROM notebooks
                WHERE id = ? AND workspace_id = ?
                LIMIT 1
                """,
                bindings: [
                    .text(resolvedNotebookID),
                    .text(workspaceID)
                ]
            )
            guard notebookRows.first != nil else {
                throw PageRepositoryError.notebookNotFound
            }
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let pageID = "page-\(UUID().uuidString.lowercased())"
        let blockID = "block-\(UUID().uuidString.lowercased())"
        let orderKey = try nextPageOrderKey(workspaceID: workspaceID, notebookID: resolvedNotebookID)

        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try database.execute(
                """
                INSERT INTO pages (id, workspace_id, notebook_id, title, order_key, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(pageID),
                    .text(workspaceID),
                    resolvedNotebookID.map(SQLiteValue.text) ?? .null,
                    .text(title),
                    .text(orderKey),
                    .text(now),
                    .text(now)
                ]
            )
            try insertBlock(
                id: blockID,
                pageID: pageID,
                orderKey: "000001",
                type: .paragraph,
                text: "",
                createdAt: now
            )
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }

        let syncRepository = SyncRepository(database: database)
        try syncRepository.enqueue(entityType: "page", entityID: pageID, changeType: "create")
        try syncRepository.enqueue(entityType: "block", entityID: blockID, changeType: "create")

        EditorLog.store.debug(
            "page_created page_id=\(pageID, privacy: .public) workspace_id=\(workspaceID, privacy: .public)"
        )

        return PageSummary(id: pageID, workspaceID: workspaceID, notebookID: resolvedNotebookID, title: title)
    }

    func archivePage(pageID: String) throws {
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
            SET is_archived = 1,
                updated_at = ?
            WHERE id = ? AND is_archived = 0
            """,
            bindings: [
                .text(now),
                .text(pageID)
            ]
        )
        try SyncRepository(database: database).enqueue(
            entityType: "page",
            entityID: pageID,
            changeType: "archive"
        )

        EditorLog.store.debug("page_archived page_id=\(pageID, privacy: .public)")
    }

    func restorePage(pageID: String) throws {
        let rows = try database.query(
            """
            SELECT id
            FROM pages
            WHERE id = ? AND is_archived = 1
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
            SET is_archived = 0,
                updated_at = ?
            WHERE id = ? AND is_archived = 1
            """,
            bindings: [
                .text(now),
                .text(pageID)
            ]
        )
        try SyncRepository(database: database).enqueue(
            entityType: "page",
            entityID: pageID,
            changeType: "restore"
        )

        EditorLog.store.debug("page_restored page_id=\(pageID, privacy: .public)")
    }

    func permanentlyDeleteArchivedPage(pageID: String) throws {
        let rows = try database.query(
            """
            SELECT id
            FROM pages
            WHERE id = ? AND is_archived = 1
            LIMIT 1
            """,
            bindings: [.text(pageID)]
        )
        guard rows.first != nil else {
            throw PageRepositoryError.pageNotFound
        }

        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let syncRepository = SyncRepository(database: database)
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
                DELETE FROM pages
                WHERE id = ? AND is_archived = 1
                """,
                bindings: [.text(pageID)]
            )
            try syncRepository.enqueue(
                entityType: "page",
                entityID: pageID,
                changeType: "delete"
            )
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }

        EditorLog.store.debug("page_permanently_deleted page_id=\(pageID, privacy: .public)")
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

    func indentBlock(blockID: String) throws -> Bool {
        let block = try requiredActiveBlock(blockID: blockID)
        let pageID = block["page_id"] ?? ""
        let parentBlockID = block["parent_block_id"] ?? nil
        let siblings = try siblingBlocks(pageID: pageID, parentBlockID: parentBlockID)

        guard let currentIndex = siblings.firstIndex(of: blockID),
              currentIndex > 0 else {
            return false
        }

        let newParentBlockID = siblings[currentIndex - 1]
        try updateBlockParent(blockID: blockID, parentBlockID: newParentBlockID)
        EditorLog.store.debug(
            "block_indented block_id=\(blockID, privacy: .public) parent_block_id=\(newParentBlockID, privacy: .public)"
        )
        return true
    }

    func outdentBlock(blockID: String) throws -> Bool {
        let block = try requiredActiveBlock(blockID: blockID)
        guard let parentBlockID = block["parent_block_id"] ?? nil else {
            return false
        }

        let parent = try requiredActiveBlock(blockID: parentBlockID)
        let newParentBlockID = parent["parent_block_id"] ?? nil
        try updateBlockParent(blockID: blockID, parentBlockID: newParentBlockID)
        EditorLog.store.debug(
            "block_outdented block_id=\(blockID, privacy: .public) parent_block_id=\(newParentBlockID ?? "root", privacy: .public)"
        )
        return true
    }

    func deleteBlock(blockID: String) throws {
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

        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try database.execute(
                """
                UPDATE blocks
                SET is_deleted = 1,
                    revision = revision + 1,
                    sync_state = ?,
                    updated_at = ?
                WHERE id = ? AND is_deleted = 0
                """,
                bindings: [
                    .text("local"),
                    .text(now),
                    .text(blockID)
                ]
            )
            try database.execute(
                """
                DELETE FROM links
                WHERE source_block_id = ?
                """,
                bindings: [.text(blockID)]
            )
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }

        try SyncRepository(database: database).enqueue(
            entityType: "block",
            entityID: blockID,
            changeType: "delete"
        )

        EditorLog.store.debug(
            "block_deleted block_id=\(blockID, privacy: .public) page_id=\(pageID, privacy: .public)"
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
            INSERT INTO notebooks (id, workspace_id, name, order_key, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(defaultNotebookID),
                .text(defaultWorkspaceID),
                .text("Notebook"),
                .text("000001"),
                .text(now),
                .text(now)
            ]
        )

        try database.execute(
            """
            INSERT INTO pages (id, workspace_id, notebook_id, title, order_key, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(defaultPageID),
                .text(defaultWorkspaceID),
                .text(defaultNotebookID),
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

    private func loadBlocks(pageIDs: [String]) throws -> [BlockSnapshot] {
        guard !pageIDs.isEmpty else {
            return []
        }

        let placeholders = Array(repeating: "?", count: pageIDs.count).joined(separator: ", ")
        return try database.query(
            """
            SELECT id, page_id, parent_block_id, order_key, type, text_plain
            FROM blocks
            WHERE page_id IN (\(placeholders)) AND is_deleted = 0
            ORDER BY page_id ASC, order_key ASC
            """,
            bindings: pageIDs.map(SQLiteValue.text)
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
    }

    private func nextNotebookOrderKey(workspaceID: String) throws -> String {
        let rows = try database.query(
            """
            SELECT order_key
            FROM notebooks
            WHERE workspace_id = ?
            ORDER BY order_key DESC
            LIMIT 1
            """,
            bindings: [.text(workspaceID)]
        )
        let lastOrderKey = rows.first.flatMap { $0["order_key"] } ?? "000000"
        let nextValue = (Int(lastOrderKey) ?? 0) + 1
        return String(format: "%06d", nextValue)
    }

    private func nextPageOrderKey(workspaceID: String, notebookID: String?) throws -> String {
        let rows = try database.query(
            """
            SELECT order_key
            FROM pages
            WHERE workspace_id = ?
              AND is_archived = 0
              AND (
                  (notebook_id IS NULL AND ? IS NULL)
                  OR notebook_id = ?
              )
            ORDER BY order_key DESC
            LIMIT 1
            """,
            bindings: [
                .text(workspaceID),
                notebookID.map(SQLiteValue.text) ?? .null,
                notebookID.map(SQLiteValue.text) ?? .null
            ]
        )
        let lastOrderKey = rows.first.flatMap { $0["order_key"] } ?? "000000"
        let nextValue = (Int(lastOrderKey) ?? 0) + 1
        return String(format: "%06d", nextValue)
    }

    private func defaultNotebookID(for workspaceID: String) throws -> String? {
        try database.query(
            """
            SELECT id
            FROM notebooks
            WHERE workspace_id = ?
            ORDER BY order_key ASC
            LIMIT 1
            """,
            bindings: [.text(workspaceID)]
        ).first?["id"] ?? nil
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

    private func requiredActiveBlock(blockID: String) throws -> SQLiteRow {
        guard let row = try database.query(
            """
            SELECT id, page_id, parent_block_id
            FROM blocks
            WHERE id = ? AND is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first else {
            throw PageRepositoryError.blockNotFound
        }
        return row
    }

    private func siblingBlocks(pageID: String, parentBlockID: String?) throws -> [String] {
        try database.query(
            """
            SELECT id
            FROM blocks
            WHERE page_id = ?
              AND is_deleted = 0
              AND (
                  (parent_block_id IS NULL AND ? IS NULL)
                  OR parent_block_id = ?
              )
            ORDER BY order_key ASC
            """,
            bindings: [
                .text(pageID),
                parentBlockID.map(SQLiteValue.text) ?? .null,
                parentBlockID.map(SQLiteValue.text) ?? .null
            ]
        ).compactMap { $0["id"] }
    }

    private func updateBlockParent(blockID: String, parentBlockID: String?) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            UPDATE blocks
            SET parent_block_id = ?,
                revision = revision + 1,
                sync_state = ?,
                updated_at = ?
            WHERE id = ? AND is_deleted = 0
            """,
            bindings: [
                parentBlockID.map(SQLiteValue.text) ?? .null,
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
    case workspaceNotFound
    case notebookNotFound
    case pageNotFound
    case blockNotFound
    case invalidPayloadEncoding
}

private struct OrderedBlock {
    let id: String
    let orderKey: String
}

private struct OrderedNotebook {
    let id: String
    let orderKey: String
}
