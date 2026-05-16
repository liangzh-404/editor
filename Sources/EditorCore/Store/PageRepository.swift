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
            SELECT id, workspace_id, parent_notebook_id, name, order_key
            FROM notebooks
            WHERE workspace_id = ?
            ORDER BY order_key ASC
            """,
            bindings: selectedWorkspaceID.map { [.text($0)] } ?? [.text("")]
        ).enumerated().map { index, row in
            OrderedNotebookSummary(
                notebook: NotebookSummary(
                    id: row["id"] ?? "",
                    workspaceID: row["workspace_id"] ?? "",
                    parentNotebookID: row["parent_notebook_id"] ?? nil,
                    name: row["name"] ?? ""
                ),
                orderKey: row["order_key"] ?? "",
                originalIndex: index
            )
        }
        let sortedNotebooks = Self.depthFirstNotebooks(notebooks)

        let selectedNotebookID = sortedNotebooks.first?.id

        let pages = try database.query(
            """
            SELECT pages.id,
                   pages.workspace_id,
                   pages.notebook_id,
                   pages.title,
                   pages.is_favorite
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
                title: row["title"] ?? "",
                isFavorite: Self.sqliteBool(row["is_favorite"])
            )
        }

        let archivedPages = try database.query(
            """
            SELECT pages.id,
                   pages.workspace_id,
                   pages.notebook_id,
                   pages.title,
                   pages.is_favorite
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
                title: row["title"] ?? "",
                isFavorite: Self.sqliteBool(row["is_favorite"])
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
            notebooks: sortedNotebooks,
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

    func updatePageFavorite(pageID: String, isFavorite: Bool) throws {
        let rows = try database.query(
            """
            SELECT id
            FROM pages
            WHERE id = ?
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
            SET is_favorite = ?,
                updated_at = ?
            WHERE id = ?
            """,
            bindings: [
                .integer(isFavorite ? 1 : 0),
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
            "page_favorite_updated page_id=\(pageID, privacy: .public) is_favorite=\(isFavorite, privacy: .public)"
        )
    }

    func createNotebook(
        workspaceID: String,
        name: String,
        parentNotebookID: String? = nil
    ) throws -> NotebookSummary {
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
        if let parentNotebookID {
            let parentRows = try database.query(
                """
                SELECT id
                FROM notebooks
                WHERE id = ? AND workspace_id = ?
                LIMIT 1
                """,
                bindings: [.text(parentNotebookID), .text(workspaceID)]
            )
            guard parentRows.first != nil else {
                throw PageRepositoryError.notebookNotFound
            }
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let notebookID = "notebook-\(UUID().uuidString.lowercased())"
        let orderKey = try nextNotebookOrderKey(
            workspaceID: workspaceID,
            parentNotebookID: parentNotebookID
        )

        try database.execute(
            """
            INSERT INTO notebooks (id, workspace_id, parent_notebook_id, name, order_key, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(notebookID),
                .text(workspaceID),
                parentNotebookID.map(SQLiteValue.text) ?? .null,
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

        return NotebookSummary(
            id: notebookID,
            workspaceID: workspaceID,
            parentNotebookID: parentNotebookID,
            name: name
        )
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
            SELECT workspace_id, parent_notebook_id
            FROM notebooks
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(notebookID)]
        )

        guard let workspaceID = selectedRows.first?["workspace_id"] ?? nil else {
            throw PageRepositoryError.notebookNotFound
        }
        let parentNotebookID = selectedRows.first?["parent_notebook_id"] ?? nil

        let notebooks = try database.query(
            """
            SELECT id, order_key
            FROM notebooks
            WHERE workspace_id = ?
              AND (
                  (parent_notebook_id IS NULL AND ? IS NULL)
                  OR parent_notebook_id = ?
              )
            ORDER BY order_key ASC
            """,
            bindings: [
                .text(workspaceID),
                parentNotebookID.map(SQLiteValue.text) ?? .null,
                parentNotebookID.map(SQLiteValue.text) ?? .null
            ]
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
        try database.withImmediateTransaction("move_notebook") {
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

    func updateNotebookParent(notebookID: String, parentNotebookID: String?) throws {
        let notebookRows = try database.query(
            """
            SELECT workspace_id
            FROM notebooks
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(notebookID)]
        )
        guard let workspaceID = notebookRows.first?["workspace_id"] ?? nil else {
            throw PageRepositoryError.notebookNotFound
        }

        if let parentNotebookID {
            guard parentNotebookID != notebookID else {
                throw PageRepositoryError.cyclicNotebookParent
            }

            let parentRows = try database.query(
                """
                SELECT workspace_id
                FROM notebooks
                WHERE id = ?
                LIMIT 1
                """,
                bindings: [.text(parentNotebookID)]
            )
            guard parentRows.first?["workspace_id"] == workspaceID else {
                throw PageRepositoryError.notebookNotFound
            }
            guard try !notebookParentChainContains(
                notebookID: parentNotebookID,
                ancestorNotebookID: notebookID
            ) else {
                throw PageRepositoryError.cyclicNotebookParent
            }
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let orderKey = try nextNotebookOrderKey(
            workspaceID: workspaceID,
            parentNotebookID: parentNotebookID
        )
        try database.execute(
            """
            UPDATE notebooks
            SET parent_notebook_id = ?,
                order_key = ?,
                updated_at = ?
            WHERE id = ?
            """,
            bindings: [
                parentNotebookID.map(SQLiteValue.text) ?? .null,
                .text(orderKey),
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
            "notebook_parent_updated notebook_id=\(notebookID, privacy: .public)"
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

        try database.withImmediateTransaction("create_page") {
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
                parentBlockID: nil,
                orderKey: "000001",
                type: .paragraph,
                text: "",
                createdAt: now
            )
        }

        let syncRepository = SyncRepository(database: database)
        try syncRepository.enqueue(entityType: "page", entityID: pageID, changeType: "create")
        try syncRepository.enqueue(entityType: "block", entityID: blockID, changeType: "create")

        EditorLog.store.debug(
            "page_created page_id=\(pageID, privacy: .public) workspace_id=\(workspaceID, privacy: .public)"
        )

        return PageSummary(
            id: pageID,
            workspaceID: workspaceID,
            notebookID: resolvedNotebookID,
            title: title,
            isFavorite: false
        )
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

        try database.withImmediateTransaction("permanently_delete_archived_page") {
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
        }

        EditorLog.store.debug("page_permanently_deleted page_id=\(pageID, privacy: .public)")
    }

    func updateBlock(
        blockID: String,
        type: BlockType,
        text: String,
        taskItemIsCompleted explicitTaskItemIsCompleted: Bool? = nil,
        toggleIsExpanded explicitToggleIsExpanded: Bool? = nil,
        codeBlockLineWrapping explicitCodeBlockLineWrapping: Bool? = nil
    ) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let taskItemIsCompleted: Bool
        if type == .taskItem {
            if let explicitTaskItemIsCompleted {
                taskItemIsCompleted = explicitTaskItemIsCompleted
            } else {
                taskItemIsCompleted = try currentTaskItemCompletion(blockID: blockID) ?? false
            }
        } else {
            taskItemIsCompleted = false
        }
        let toggleIsExpanded: Bool
        if type == .toggle {
            if let explicitToggleIsExpanded {
                toggleIsExpanded = explicitToggleIsExpanded
            } else {
                toggleIsExpanded = try currentToggleExpansion(blockID: blockID) ?? true
            }
        } else {
            toggleIsExpanded = true
        }
        let codeBlockLineWrapping: Bool
        if type == .codeBlock {
            if let explicitCodeBlockLineWrapping {
                codeBlockLineWrapping = explicitCodeBlockLineWrapping
            } else {
                codeBlockLineWrapping = try currentCodeBlockLineWrapping(blockID: blockID) ?? true
            }
        } else {
            codeBlockLineWrapping = true
        }
        let payloadJSON = try blockPayloadJSON(
            type: type,
            text: text,
            taskItemIsCompleted: taskItemIsCompleted,
            toggleIsExpanded: toggleIsExpanded,
            codeBlockLineWrapping: codeBlockLineWrapping
        )

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

    func updateToggleExpansion(blockID: String, isExpanded: Bool) throws {
        guard let row = try database.query(
            """
            SELECT type, text_plain
            FROM blocks
            WHERE id = ? AND is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first,
              BlockType(rawValue: row["type"] ?? "") == .toggle else {
            throw PageRepositoryError.blockNotFound
        }

        let text = row["text_plain"] ?? ""
        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            UPDATE blocks
            SET payload_json = ?,
                revision = revision + 1,
                sync_state = ?,
                updated_at = ?
            WHERE id = ? AND is_deleted = 0
            """,
            bindings: [
                .text(try blockPayloadJSON(
                    type: .toggle,
                    text: text,
                    toggleIsExpanded: isExpanded
                )),
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

    func updateCodeBlockLineWrapping(blockID: String, isWrapped: Bool) throws {
        guard let row = try database.query(
            """
            SELECT type, text_plain
            FROM blocks
            WHERE id = ? AND is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first,
              BlockType(rawValue: row["type"] ?? "") == .codeBlock else {
            throw PageRepositoryError.blockNotFound
        }

        let text = row["text_plain"] ?? ""
        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            UPDATE blocks
            SET payload_json = ?,
                revision = revision + 1,
                sync_state = ?,
                updated_at = ?
            WHERE id = ? AND is_deleted = 0
            """,
            bindings: [
                .text(try blockPayloadJSON(
                    type: .codeBlock,
                    text: text,
                    codeBlockLineWrapping: isWrapped
                )),
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

    func updateTaskItemCompletion(blockID: String, isCompleted: Bool) throws {
        guard let row = try database.query(
            """
            SELECT type, text_plain
            FROM blocks
            WHERE id = ? AND is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first,
              BlockType(rawValue: row["type"] ?? "") == .taskItem else {
            throw PageRepositoryError.blockNotFound
        }

        let text = row["text_plain"] ?? ""
        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            UPDATE blocks
            SET payload_json = ?,
                revision = revision + 1,
                sync_state = ?,
                updated_at = ?
            WHERE id = ? AND is_deleted = 0
            """,
            bindings: [
                .text(try blockPayloadJSON(
                    type: .taskItem,
                    text: text,
                    taskItemIsCompleted: isCompleted
                )),
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
                parentBlockID: nil,
                orderKey: String(format: "%06d", index + 1),
                type: draft.type,
                text: draft.textPlain,
                taskItemIsCompleted: draft.taskItemIsCompleted,
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

#if DEBUG
    func replacePageWithUITestLargePage(pageID: String, blockCount: Int) throws {
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

        for index in 1...blockCount {
            let blockID = String(format: "block-ui-large-%03d", index)
            let text = "Large block \(index) searchable content"
            try insertBlock(
                id: blockID,
                pageID: pageID,
                parentBlockID: nil,
                orderKey: String(format: "%06d", index),
                type: .paragraph,
                text: text,
                createdAt: now
            )
        }

        EditorLog.markdown.debug(
            "ui_test_large_page_seeded page_id=\(pageID, privacy: .public) blocks=\(blockCount, privacy: .public)"
        )
    }
#endif

    func appendBlock(pageID: String, type: BlockType, text: String) throws -> BlockSnapshot {
        try appendBlock(
            pageID: pageID,
            type: type,
            text: text,
            taskItemIsCompleted: false,
            pageReferenceTargetPageID: nil,
            blockReferenceTargetBlockID: nil
        )
    }

    func appendPageReferenceBlock(pageID: String, targetPageID: String) throws -> BlockSnapshot {
        let targetRows = try database.query(
            """
            SELECT title
            FROM pages
            WHERE id = ? AND is_archived = 0
            LIMIT 1
            """,
            bindings: [.text(targetPageID)]
        )
        guard let targetTitle = targetRows.first?["title"] else {
            throw PageRepositoryError.pageNotFound
        }

        return try appendBlock(
            pageID: pageID,
            type: .pageReference,
            text: targetTitle,
            taskItemIsCompleted: false,
            pageReferenceTargetPageID: targetPageID,
            blockReferenceTargetBlockID: nil
        )
    }

    func appendBlockReferenceBlock(pageID: String, targetBlockID: String) throws -> BlockSnapshot {
        guard let targetRow = try database.query(
            """
            SELECT id, page_id, text_plain
            FROM blocks
            WHERE id = ? AND is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(targetBlockID)]
        ).first else {
            throw PageRepositoryError.blockNotFound
        }

        return try appendBlock(
            pageID: pageID,
            type: .blockReference,
            text: targetRow["text_plain"] ?? "",
            taskItemIsCompleted: false,
            pageReferenceTargetPageID: targetRow["page_id"],
            blockReferenceTargetBlockID: targetBlockID
        )
    }

    private func appendBlock(
        pageID: String,
        type: BlockType,
        text: String,
        taskItemIsCompleted: Bool,
        pageReferenceTargetPageID: String?,
        blockReferenceTargetBlockID: String?
    ) throws -> BlockSnapshot {
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
            parentBlockID: nil,
            orderKey: orderKey,
            type: type,
            text: text,
            taskItemIsCompleted: taskItemIsCompleted,
            pageReferenceTargetPageID: pageReferenceTargetPageID,
            blockReferenceTargetBlockID: blockReferenceTargetBlockID,
            createdAt: now
        )
        try SyncRepository(database: database).enqueue(
            entityType: "block",
            entityID: blockID,
            changeType: "create"
        )
        try BacklinkRepository(database: database).rebuildLinksForBlock(
            blockID: blockID,
            text: text,
            pageReferenceTargetPageID: pageReferenceTargetPageID,
            blockReferenceTargetBlockID: blockReferenceTargetBlockID
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
            textPlain: text,
            taskItemIsCompleted: taskItemIsCompleted,
            codeBlockLineWrapping: type == .codeBlock,
            pageReferenceTargetPageID: pageReferenceTargetPageID,
            blockReferenceTargetBlockID: blockReferenceTargetBlockID
        )
    }

    func insertParagraphBlock(after blockID: String, text: String = "") throws -> BlockSnapshot {
        let selectedRows = try database.query(
            """
            SELECT page_id, parent_block_id
            FROM blocks
            WHERE id = ? AND is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        )
        guard let selectedRow = selectedRows.first,
              let pageID = selectedRow["page_id"] else {
            throw PageRepositoryError.blockNotFound
        }
        let parentBlockID = selectedRow["parent_block_id"] ?? nil

        let orderedBlockIDs = try database.query(
            """
            SELECT id
            FROM blocks
            WHERE page_id = ? AND is_deleted = 0
            ORDER BY order_key ASC
            """,
            bindings: [.text(pageID)]
        ).compactMap { $0["id"] }
        guard let currentIndex = orderedBlockIDs.firstIndex(of: blockID) else {
            throw PageRepositoryError.blockNotFound
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let insertedBlockID = "block-\(UUID().uuidString.lowercased())"
        let shiftedBlockIDs = Array(orderedBlockIDs.suffix(from: currentIndex + 1))
        var reorderedBlockIDs = orderedBlockIDs
        reorderedBlockIDs.insert(insertedBlockID, at: currentIndex + 1)

        try database.withImmediateTransaction("insert_paragraph_block") {
            try insertBlock(
                id: insertedBlockID,
                pageID: pageID,
                parentBlockID: parentBlockID,
                orderKey: String(format: "%06d", currentIndex + 2),
                type: .paragraph,
                text: text,
                createdAt: now
            )
            for (index, reorderedBlockID) in reorderedBlockIDs.enumerated() {
                try database.execute(
                    """
                    UPDATE blocks
                    SET order_key = ?,
                        updated_at = ?
                    WHERE id = ?
                    """,
                    bindings: [
                        .text(String(format: "%06d", index + 1)),
                        .text(now),
                        .text(reorderedBlockID)
                    ]
                )
            }
        }

        let syncRepository = SyncRepository(database: database)
        try syncRepository.enqueue(
            entityType: "block",
            entityID: insertedBlockID,
            changeType: "create"
        )
        for shiftedBlockID in shiftedBlockIDs {
            try syncRepository.enqueue(
                entityType: "block",
                entityID: shiftedBlockID,
                changeType: "update"
            )
        }
        try BacklinkRepository(database: database).rebuildLinksForBlock(
            blockID: insertedBlockID,
            text: text
        )
        EditorLog.store.debug(
            "block_inserted_after block_id=\(insertedBlockID, privacy: .public) previous_block_id=\(blockID, privacy: .public)"
        )

        return BlockSnapshot(
            id: insertedBlockID,
            pageID: pageID,
            parentBlockID: parentBlockID,
            orderKey: String(format: "%06d", currentIndex + 2),
            type: .paragraph,
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
        try database.withImmediateTransaction("move_block") {
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
        try database.withImmediateTransaction("delete_block") {
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
            INSERT INTO notebooks (id, workspace_id, parent_notebook_id, name, order_key, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(defaultNotebookID),
                .text(defaultWorkspaceID),
                .null,
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
            SELECT id, page_id, parent_block_id, order_key, type, payload_json, text_plain
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
                textPlain: row["text_plain"] ?? "",
                taskItemIsCompleted: Self.taskItemIsCompleted(
                    payloadJSON: row["payload_json"] ?? ""
                ),
                toggleIsExpanded: Self.toggleIsExpanded(
                    payloadJSON: row["payload_json"] ?? ""
                ),
                codeBlockLineWrapping: Self.codeBlockLineWrapping(
                    payloadJSON: row["payload_json"] ?? ""
                ),
                pageReferenceTargetPageID: Self.pageReferenceTargetPageID(
                    payloadJSON: row["payload_json"] ?? ""
                ),
                blockReferenceTargetBlockID: Self.blockReferenceTargetBlockID(
                    payloadJSON: row["payload_json"] ?? ""
                )
            )
        }
    }

    private func nextNotebookOrderKey(
        workspaceID: String,
        parentNotebookID: String? = nil
    ) throws -> String {
        let rows = try database.query(
            """
            SELECT order_key
            FROM notebooks
            WHERE workspace_id = ?
              AND (
                  (parent_notebook_id IS NULL AND ? IS NULL)
                  OR parent_notebook_id = ?
              )
            ORDER BY order_key DESC
            LIMIT 1
            """,
            bindings: [
                .text(workspaceID),
                parentNotebookID.map(SQLiteValue.text) ?? .null,
                parentNotebookID.map(SQLiteValue.text) ?? .null
            ]
        )
        let lastOrderKey = rows.first.flatMap { $0["order_key"] } ?? "000000"
        let nextValue = (Int(lastOrderKey) ?? 0) + 1
        return String(format: "%06d", nextValue)
    }

    private func notebookParentChainContains(
        notebookID: String,
        ancestorNotebookID: String
    ) throws -> Bool {
        var currentNotebookID: String? = notebookID
        var visitedNotebookIDs: Set<String> = []

        while let current = currentNotebookID,
              !visitedNotebookIDs.contains(current) {
            if current == ancestorNotebookID {
                return true
            }

            visitedNotebookIDs.insert(current)
            currentNotebookID = try database.query(
                """
                SELECT parent_notebook_id
                FROM notebooks
                WHERE id = ?
                LIMIT 1
                """,
                bindings: [.text(current)]
            ).first?["parent_notebook_id"] ?? nil
        }

        return false
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
        parentBlockID: String?,
        orderKey: String,
        type: BlockType,
        text: String,
        taskItemIsCompleted: Bool = false,
        pageReferenceTargetPageID: String? = nil,
        blockReferenceTargetBlockID: String? = nil,
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
                parentBlockID.map(SQLiteValue.text) ?? .null,
                .text(orderKey),
                .text(type.rawValue),
                .text(try blockPayloadJSON(
                    type: type,
                    text: text,
                    taskItemIsCompleted: taskItemIsCompleted,
                    pageReferenceTargetPageID: pageReferenceTargetPageID,
                    blockReferenceTargetBlockID: blockReferenceTargetBlockID
                )),
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

    private func blockPayloadJSON(
        type: BlockType,
        text: String,
        taskItemIsCompleted: Bool = false,
        toggleIsExpanded: Bool = true,
        codeBlockLineWrapping: Bool = true,
        pageReferenceTargetPageID: String? = nil,
        blockReferenceTargetBlockID: String? = nil
    ) throws -> String {
        let payload: [String: Any]
        switch type {
        case .divider:
            payload = [:]
        case .taskItem:
            payload = [
                "completed": taskItemIsCompleted,
                "text": text
            ]
        case .toggle:
            payload = [
                "expanded": toggleIsExpanded,
                "text": text
            ]
        case .codeBlock:
            payload = [
                "line_wrapping": codeBlockLineWrapping,
                "text": text
            ]
        case .pageReference:
            payload = [
                "target_page_id": pageReferenceTargetPageID ?? "",
                "text": text
            ]
        case .blockReference:
            payload = [
                "target_block_id": blockReferenceTargetBlockID ?? "",
                "target_page_id": pageReferenceTargetPageID ?? "",
                "text": text
            ]
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

    private func currentTaskItemCompletion(blockID: String) throws -> Bool? {
        guard let row = try database.query(
            """
            SELECT type, payload_json
            FROM blocks
            WHERE id = ? AND is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first,
              BlockType(rawValue: row["type"] ?? "") == .taskItem else {
            return nil
        }

        return Self.taskItemIsCompleted(payloadJSON: row["payload_json"] ?? "")
    }

    private func currentToggleExpansion(blockID: String) throws -> Bool? {
        guard let row = try database.query(
            """
            SELECT type, payload_json
            FROM blocks
            WHERE id = ? AND is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first,
              BlockType(rawValue: row["type"] ?? "") == .toggle else {
            return nil
        }

        return Self.toggleIsExpanded(payloadJSON: row["payload_json"] ?? "")
    }

    private func currentCodeBlockLineWrapping(blockID: String) throws -> Bool? {
        guard let row = try database.query(
            """
            SELECT type, payload_json
            FROM blocks
            WHERE id = ? AND is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first,
              BlockType(rawValue: row["type"] ?? "") == .codeBlock else {
            return nil
        }

        return Self.codeBlockLineWrapping(payloadJSON: row["payload_json"] ?? "")
    }

    private static func taskItemIsCompleted(payloadJSON: String) -> Bool {
        guard let data = payloadJSON.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        if let completed = payload["completed"] as? Bool {
            return completed
        }
        if let completed = payload["completed"] as? String {
            return completed == "true" || completed == "1"
        }
        return false
    }

    private static func toggleIsExpanded(payloadJSON: String) -> Bool {
        guard let data = payloadJSON.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return true
        }

        if let expanded = payload["expanded"] as? Bool {
            return expanded
        }
        if let expanded = payload["expanded"] as? String {
            return expanded == "true" || expanded == "1"
        }
        return true
    }

    private static func codeBlockLineWrapping(payloadJSON: String) -> Bool {
        guard let data = payloadJSON.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return true
        }

        if let lineWrapping = payload["line_wrapping"] as? Bool {
            return lineWrapping
        }
        if let lineWrapping = payload["line_wrapping"] as? String {
            return lineWrapping == "true" || lineWrapping == "1"
        }
        return true
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

    private static func sqliteBool(_ value: String?) -> Bool {
        value == "1" || value == "true"
    }

    private static func depthFirstNotebooks(_ notebooks: [OrderedNotebookSummary]) -> [NotebookSummary] {
        let notebookIDs = Set(notebooks.map(\.notebook.id))
        var childrenByParentID: [String?: [OrderedNotebookSummary]] = [:]
        for notebook in notebooks {
            let parentID = notebook.notebook.parentNotebookID
            let resolvedParentID = parentID.flatMap { notebookIDs.contains($0) ? $0 : nil }
            childrenByParentID[resolvedParentID, default: []].append(notebook)
        }

        for parentID in childrenByParentID.keys {
            childrenByParentID[parentID]?.sort(by: orderedNotebookSummarySort)
        }

        var visitedNotebookIDs: Set<String> = []
        var result: [NotebookSummary] = []

        func appendSubtree(parentID: String?) {
            for child in childrenByParentID[parentID] ?? [] {
                guard !visitedNotebookIDs.contains(child.notebook.id) else {
                    continue
                }

                visitedNotebookIDs.insert(child.notebook.id)
                result.append(child.notebook)
                appendSubtree(parentID: child.notebook.id)
            }
        }

        appendSubtree(parentID: nil)

        for notebook in notebooks.sorted(by: orderedNotebookSummarySort) {
            guard !visitedNotebookIDs.contains(notebook.notebook.id) else {
                continue
            }

            visitedNotebookIDs.insert(notebook.notebook.id)
            result.append(notebook.notebook)
        }

        return result
    }

    private static func orderedNotebookSummarySort(
        lhs: OrderedNotebookSummary,
        rhs: OrderedNotebookSummary
    ) -> Bool {
        if lhs.orderKey != rhs.orderKey {
            return lhs.orderKey < rhs.orderKey
        }
        return lhs.originalIndex < rhs.originalIndex
    }
}

enum PageRepositoryError: Error, Equatable {
    case workspaceNotFound
    case notebookNotFound
    case cyclicNotebookParent
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

private struct OrderedNotebookSummary {
    let notebook: NotebookSummary
    let orderKey: String
    let originalIndex: Int
}
