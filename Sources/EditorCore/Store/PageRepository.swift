import Foundation

final class PageRepository {
    private let database: SQLiteDatabase
    private let encryptedNoteCipher: EncryptedNoteCiphering

    var syncChangeNotificationObject: AnyObject {
        database
    }

    private let defaultWorkspaceID = "workspace-local"
    private let defaultNotebookID = "notebook-local"
    private let defaultPageID = "page-welcome"
    private let defaultBlockID = "block-welcome-001"

    init(
        database: SQLiteDatabase,
        encryptedNoteCipher: EncryptedNoteCiphering = EncryptedNoteCipher()
    ) {
        self.database = database
        self.encryptedNoteCipher = encryptedNoteCipher
    }

    @discardableResult
    func bootstrapWorkspaceIfNeeded() throws -> WorkspaceSnapshot {
        let workspaceCount = try database.queryInt("SELECT COUNT(*) FROM workspaces")
        if workspaceCount == 0 {
            try insertDefaultContent()
        } else {
            try localizeDefaultSeedContentIfUnmodified()
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
                   pages.is_favorite,
                   pages.is_encrypted,
                   pages.updated_at
            FROM pages
            LEFT JOIN notebooks ON notebooks.id = pages.notebook_id
            WHERE pages.workspace_id = ?
              AND pages.is_archived = 0
            ORDER BY pages.updated_at DESC, pages.created_at DESC
            """,
            bindings: selectedWorkspaceID.map { [.text($0)] } ?? [.text("")]
        ).map { row in
            PageSummary(
                id: row["id"] ?? "",
                workspaceID: row["workspace_id"] ?? "",
                notebookID: row["notebook_id"] ?? nil,
                title: try decryptPageTitleIfNeeded(row),
                isFavorite: Self.sqliteBool(row["is_favorite"]),
                isEncrypted: Self.sqliteBool(row["is_encrypted"]),
                updatedAt: row["updated_at"]
            )
        }

        let archivedPages = try database.query(
            """
            SELECT pages.id,
                   pages.workspace_id,
                   pages.notebook_id,
                   pages.title,
                   pages.is_favorite,
                   pages.is_encrypted,
                   pages.updated_at
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
                title: try decryptPageTitleIfNeeded(row),
                isFavorite: Self.sqliteBool(row["is_favorite"]),
                isEncrypted: Self.sqliteBool(row["is_encrypted"]),
                updatedAt: row["updated_at"]
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

        let tagRepository = TagRepository(database: database)
        let tags = try selectedWorkspaceID.map { try tagRepository.tags(workspaceID: $0) } ?? []
        let pageTags = try tagRepository.tagAssignments()
        let diaryPages = try database.query(
            """
            SELECT page_id, workspace_id, diary_date
            FROM diary_pages
            WHERE workspace_id = ?
            ORDER BY diary_date DESC
            """,
            bindings: selectedWorkspaceID.map { [.text($0)] } ?? [.text("")]
        ).map { row in
            DiaryPageSnapshot(
                pageID: row["page_id"] ?? "",
                workspaceID: row["workspace_id"] ?? "",
                diaryDate: row["diary_date"] ?? ""
            )
        }
        let pageParentLinks = try database.query(
            """
            SELECT parent_page_id, child_page_id, source_block_id, order_key
            FROM page_parent_links
            ORDER BY parent_page_id ASC, order_key ASC
            """
        ).map { row in
            PageParentLink(
                parentPageID: row["parent_page_id"] ?? "",
                childPageID: row["child_page_id"] ?? "",
                sourceBlockID: row["source_block_id"] ?? "",
                orderKey: row["order_key"] ?? ""
            )
        }

        return WorkspaceSnapshot(
            workspaces: workspaces,
            notebooks: sortedNotebooks,
            pages: pages,
            archivedPages: archivedPages,
            blocks: blocks,
            attachments: attachments,
            tags: tags,
            pageTags: pageTags,
            diaryPages: diaryPages,
            pageParentLinks: pageParentLinks,
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
            WHERE blocks.id = ? AND blocks.is_deleted = 0
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
            SELECT id,
                   title,
                   is_encrypted
            FROM pages
            WHERE id = ? AND is_archived = 0
            LIMIT 1
            """,
            bindings: [.text(pageID)]
        )
        guard let row = rows.first else {
            throw PageRepositoryError.pageNotFound
        }
        let isEncrypted = Self.sqliteBool(row["is_encrypted"])
        let currentTitle = try decryptedStoredValue(row["title"] ?? "", isEncrypted: isEncrypted)
        if currentTitle == title {
            EditorLog.store.debug(
                "page_title_update_skipped_noop page_id=\(pageID, privacy: .public)"
            )
            return
        }

        let now = Self.timestamp()
        let storedTitle = try storedValue(title, isEncrypted: isEncrypted)
        try database.execute(
            """
            UPDATE pages
            SET title = ?,
                updated_at = ?
            WHERE id = ? AND is_archived = 0
            """,
            bindings: [
                .text(storedTitle),
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

        let now = Self.timestamp()
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

    func updatePageEncryption(pageID: String, isEncrypted: Bool) throws {
        let pageRow = try database.query(
            """
            SELECT id,
                   title,
                   is_encrypted
            FROM pages
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(pageID)]
        ).first
        guard let pageRow else {
            throw PageRepositoryError.pageNotFound
        }

        let wasEncrypted = Self.sqliteBool(pageRow["is_encrypted"])
        guard wasEncrypted != isEncrypted else {
            EditorLog.store.debug(
                "page_encryption_update_skipped_noop page_id=\(pageID, privacy: .public)"
            )
            return
        }

        let blockRows = try database.query(
            """
            SELECT id,
                   payload_json,
                   text_plain
            FROM blocks
            WHERE page_id = ? AND is_deleted = 0
            ORDER BY order_key ASC
            """,
            bindings: [.text(pageID)]
        )
        let currentTitle = try decryptedStoredValue(pageRow["title"] ?? "", isEncrypted: wasEncrypted)
        let storedTitle = try storedValue(currentTitle, isEncrypted: isEncrypted)
        let now = Self.timestamp()
        var changedBlockIDs: [String] = []

        try database.withImmediateTransaction("update_page_encryption") {
            try database.execute(
                """
                UPDATE pages
                SET title = ?,
                    is_encrypted = ?,
                    updated_at = ?
                WHERE id = ?
                """,
                bindings: [
                    .text(storedTitle),
                    .integer(isEncrypted ? 1 : 0),
                    .text(now),
                    .text(pageID)
                ]
            )

            for blockRow in blockRows {
                guard let blockID = blockRow["id"] else {
                    continue
                }
                let plaintextPayloadJSON = try decryptedStoredValue(
                    blockRow["payload_json"] ?? "",
                    isEncrypted: wasEncrypted
                )
                let plaintextText = try decryptedStoredValue(
                    blockRow["text_plain"] ?? "",
                    isEncrypted: wasEncrypted
                )
                try database.execute(
                    """
                    UPDATE blocks
                    SET payload_json = ?,
                        text_plain = ?,
                        revision = revision + 1,
                        sync_state = ?,
                        updated_at = ?
                    WHERE id = ? AND is_deleted = 0
                    """,
                    bindings: [
                        .text(try storedValue(plaintextPayloadJSON, isEncrypted: isEncrypted)),
                        .text(try storedValue(plaintextText, isEncrypted: isEncrypted)),
                        .text("local"),
                        .text(now),
                        .text(blockID)
                    ]
                )
                changedBlockIDs.append(blockID)
            }

            try database.execute(
                """
                DELETE FROM links
                WHERE source_page_id = ?
                """,
                bindings: [.text(pageID)]
            )
        }

        let syncRepository = SyncRepository(database: database)
        try syncRepository.enqueue(entityType: "page", entityID: pageID, changeType: "update")
        for blockID in changedBlockIDs {
            try syncRepository.enqueue(entityType: "block", entityID: blockID, changeType: "update")
        }
        try deleteSearchIndexForPage(pageID: pageID, blockIDs: changedBlockIDs)
        if !isEncrypted {
            try rebuildLinksForBlocks(blockIDs: changedBlockIDs)
        }

        EditorLog.store.debug(
            "page_encryption_updated page_id=\(pageID, privacy: .public) is_encrypted=\(isEncrypted, privacy: .public) blocks=\(changedBlockIDs.count, privacy: .public)"
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

        let now = Self.timestamp()
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

        let now = Self.timestamp()
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

        let now = Self.timestamp()
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

        let now = Self.timestamp()
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

    func createPage(
        workspaceID: String,
        title: String,
        notebookID: String? = nil,
        isEncrypted: Bool = false
    ) throws -> PageSummary {
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

        let now = Self.timestamp()
        let pageID = "page-\(UUID().uuidString.lowercased())"
        let blockID = "block-\(UUID().uuidString.lowercased())"
        let orderKey = try nextPageOrderKey(workspaceID: workspaceID, notebookID: resolvedNotebookID)
        let storedTitle = try storedValue(title, isEncrypted: isEncrypted)

        try database.withImmediateTransaction("create_page") {
            try database.execute(
                """
                INSERT INTO pages (id, workspace_id, notebook_id, title, order_key, is_encrypted, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(pageID),
                    .text(workspaceID),
                    resolvedNotebookID.map(SQLiteValue.text) ?? .null,
                    .text(storedTitle),
                    .text(orderKey),
                    .integer(isEncrypted ? 1 : 0),
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
            isFavorite: false,
            isEncrypted: isEncrypted,
            updatedAt: now
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

        let now = Self.timestamp()
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

        let now = Self.timestamp()
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
        codeBlockLineWrapping explicitCodeBlockLineWrapping: Bool? = nil,
        tableRows explicitTableRows: [[String]]? = nil,
        attachmentDisplayWidth explicitAttachmentDisplayWidth: Double? = nil
    ) throws {
        let now = Self.timestamp()
        let currentRows = try database.query(
            """
            SELECT blocks.type AS type,
                   blocks.payload_json AS payload_json,
                   blocks.text_plain AS text_plain,
                   blocks.page_id AS page_id,
                   pages.is_encrypted AS is_encrypted
            FROM blocks
            INNER JOIN pages ON pages.id = blocks.page_id
            WHERE blocks.id = ? AND blocks.is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        )
        guard let currentRow = currentRows.first else {
            throw PageRepositoryError.blockNotFound
        }
        let isEncrypted = Self.sqliteBool(currentRow["is_encrypted"])
        let currentType = BlockType(rawValue: currentRow["type"] ?? "") ?? .paragraph
        let currentPayloadJSON = try decryptedStoredValue(
            currentRow["payload_json"] ?? "",
            isEncrypted: isEncrypted
        )
        let currentText = try decryptedStoredValue(
            currentRow["text_plain"] ?? "",
            isEncrypted: isEncrypted
        )
        let referenceTargets = try currentReferenceTargets(blockID: blockID)
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
        let payloadJSON: String
        if let attachmentKind = Self.attachmentKind(for: type) {
            let displayWidth = type == .attachmentImage
                ? explicitAttachmentDisplayWidth ?? Self.attachmentDisplayWidth(
                    type: currentType,
                    payloadJSON: currentPayloadJSON
                )
                : nil
            payloadJSON = try attachmentBlockPayloadJSON(
                attachmentID: Self.attachmentID(type: currentType, payloadJSON: currentPayloadJSON),
                kind: attachmentKind,
                filename: text,
                displayWidth: displayWidth
            )
        } else {
            payloadJSON = try blockPayloadJSON(
                type: type,
                text: text,
                taskItemIsCompleted: taskItemIsCompleted,
                toggleIsExpanded: toggleIsExpanded,
                codeBlockLineWrapping: codeBlockLineWrapping,
                pageReferenceTargetPageID: referenceTargets.pageID,
                blockReferenceTargetBlockID: referenceTargets.blockID,
                tableRows: explicitTableRows
            )
        }
        let storedPayloadJSON = try storedValue(payloadJSON, isEncrypted: isEncrypted)
        let storedText = try storedValue(text, isEncrypted: isEncrypted)
        if currentRow["type"] == type.rawValue,
           currentPayloadJSON == payloadJSON,
           currentText == text {
            EditorLog.store.debug(
                "block_update_skipped_noop block_id=\(blockID, privacy: .public) type=\(type.rawValue, privacy: .public)"
            )
            return
        }

        try database.execute(
            """
            UPDATE blocks
            SET type = ?,
                payload_json = ?,
                text_plain = ?,
                revision = revision + 1,
                sync_state = ?,
                updated_at = ?
            WHERE blocks.id = ? AND blocks.is_deleted = 0
            """,
            bindings: [
                .text(type.rawValue),
                .text(storedPayloadJSON),
                .text(storedText),
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
        if isEncrypted {
            try database.execute(
                """
                DELETE FROM links
                WHERE source_block_id = ?
                """,
                bindings: [.text(blockID)]
            )
            try deleteSearchIndexForPage(pageID: currentRow["page_id"] ?? "", blockIDs: [blockID])
        } else {
            try BacklinkRepository(database: database).rebuildLinksForBlock(
                blockID: blockID,
                text: text,
                pageReferenceTargetPageID: referenceTargets.pageID,
                blockReferenceTargetBlockID: referenceTargets.blockID
            )
        }
    }

    func replaceBlocks(pageID: String, blocks replacementBlocks: [BlockSnapshot]) throws {
        let pageRows = try database.query(
            """
            SELECT id
            FROM pages
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(pageID)]
        )
        guard pageRows.first != nil,
              replacementBlocks.allSatisfy({ $0.pageID == pageID }) else {
            throw PageRepositoryError.pageNotFound
        }

        let activeBlockIDs = Set(
            try database.query(
                """
                SELECT id
                FROM blocks
                WHERE page_id = ? AND is_deleted = 0
                """,
                bindings: [.text(pageID)]
            ).compactMap { $0["id"] }
        )
        let replacementBlockIDs = Set(replacementBlocks.map(\.id))
        let removedBlockIDs = activeBlockIDs.subtracting(replacementBlockIDs)
        let existingReplacementBlockIDs: Set<String>
        if replacementBlocks.isEmpty {
            existingReplacementBlockIDs = []
        } else {
            let placeholders = Array(repeating: "?", count: replacementBlocks.count).joined(separator: ", ")
            existingReplacementBlockIDs = Set(
                try database.query(
                    """
                    SELECT id
                    FROM blocks
                    WHERE id IN (\(placeholders))
                    """,
                    bindings: replacementBlocks.map { SQLiteValue.text($0.id) }
                ).compactMap { $0["id"] }
            )
        }

        let now = Self.timestamp()
        let isEncrypted = try pageIsEncrypted(pageID: pageID)
        try database.withImmediateTransaction("replace_page_blocks") {
            if !removedBlockIDs.isEmpty {
                let placeholders = Array(repeating: "?", count: removedBlockIDs.count).joined(separator: ", ")
                try database.execute(
                    """
                    UPDATE blocks
                    SET is_deleted = 1,
                        revision = revision + 1,
                        sync_state = ?,
                        updated_at = ?
                    WHERE id IN (\(placeholders))
                      AND is_deleted = 0
                    """,
                    bindings: [.text("local"), .text(now)] + removedBlockIDs.map(SQLiteValue.text)
                )
            }

            try database.execute(
                """
                DELETE FROM links
                WHERE source_page_id = ?
                """,
                bindings: [.text(pageID)]
            )

            for block in replacementBlocks {
                let payloadJSON = try blockPayloadJSON(block: block)
                let storedPayloadJSON = try storedValue(payloadJSON, isEncrypted: isEncrypted)
                let storedText = try storedValue(block.textPlain, isEncrypted: isEncrypted)
                if existingReplacementBlockIDs.contains(block.id) {
                    try database.execute(
                        """
                        UPDATE blocks
                        SET page_id = ?,
                            parent_block_id = ?,
                            order_key = ?,
                            type = ?,
                            payload_json = ?,
                            text_plain = ?,
                            revision = revision + 1,
                            sync_state = ?,
                            is_deleted = 0,
                            updated_at = ?
                        WHERE id = ?
                        """,
                        bindings: [
                            .text(block.pageID),
                            block.parentBlockID.map(SQLiteValue.text) ?? .null,
                            .text(block.orderKey),
                            .text(block.type.rawValue),
                            .text(storedPayloadJSON),
                            .text(storedText),
                            .text("local"),
                            .text(now),
                            .text(block.id)
                        ]
                    )
                } else {
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
                            .text(block.id),
                            .text(block.pageID),
                            block.parentBlockID.map(SQLiteValue.text) ?? .null,
                            .text(block.orderKey),
                            .text(block.type.rawValue),
                            .text(storedPayloadJSON),
                            .text(storedText),
                            .integer(1),
                            .text("local"),
                            .integer(0),
                            .text(now),
                            .text(now)
                        ]
                    )
                }
            }
        }

        let syncRepository = SyncRepository(database: database)
        for removedBlockID in removedBlockIDs {
            try syncRepository.enqueue(
                entityType: "block",
                entityID: removedBlockID,
                changeType: "delete"
            )
        }
        for block in replacementBlocks {
            try syncRepository.enqueue(
                entityType: "block",
                entityID: block.id,
                changeType: existingReplacementBlockIDs.contains(block.id) ? "update" : "create"
            )
        }
        try rebuildLinksForBlocks(blockIDs: replacementBlocks.map(\.id))
        EditorLog.store.debug(
            "page_blocks_replaced page_id=\(pageID, privacy: .public) blocks=\(replacementBlocks.count, privacy: .public) removed=\(removedBlockIDs.count, privacy: .public)"
        )
    }

    func updateToggleExpansion(blockID: String, isExpanded: Bool) throws {
        guard let row = try database.query(
            """
            SELECT blocks.type,
                   blocks.text_plain,
                   blocks.page_id AS page_id,
                   pages.is_encrypted AS is_encrypted
            FROM blocks
            INNER JOIN pages ON pages.id = blocks.page_id
            WHERE blocks.id = ? AND blocks.is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first,
              BlockType(rawValue: row["type"] ?? "") == .toggle else {
            throw PageRepositoryError.blockNotFound
        }

        let isEncrypted = Self.sqliteBool(row["is_encrypted"])
        let text = try decryptedStoredValue(row["text_plain"] ?? "", isEncrypted: isEncrypted)
        let payloadJSON = try storedValue(
            try blockPayloadJSON(
                type: .toggle,
                text: text,
                toggleIsExpanded: isExpanded
            ),
            isEncrypted: isEncrypted
        )
        let now = Self.timestamp()
        try database.execute(
            """
            UPDATE blocks
            SET payload_json = ?,
                revision = revision + 1,
                sync_state = ?,
                updated_at = ?
            WHERE blocks.id = ? AND blocks.is_deleted = 0
            """,
            bindings: [
                .text(payloadJSON),
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
        if isEncrypted {
            try deleteSearchIndexForPage(pageID: row["page_id"] ?? "", blockIDs: [blockID])
        } else {
            try BacklinkRepository(database: database).rebuildLinksForBlock(
                blockID: blockID,
                text: text
            )
        }
    }

    func updateCodeBlockLineWrapping(blockID: String, isWrapped: Bool) throws {
        guard let row = try database.query(
            """
            SELECT blocks.type,
                   blocks.text_plain,
                   blocks.page_id AS page_id,
                   pages.is_encrypted AS is_encrypted
            FROM blocks
            INNER JOIN pages ON pages.id = blocks.page_id
            WHERE blocks.id = ? AND blocks.is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first,
              BlockType(rawValue: row["type"] ?? "") == .codeBlock else {
            throw PageRepositoryError.blockNotFound
        }

        let isEncrypted = Self.sqliteBool(row["is_encrypted"])
        let text = try decryptedStoredValue(row["text_plain"] ?? "", isEncrypted: isEncrypted)
        let payloadJSON = try storedValue(
            try blockPayloadJSON(
                type: .codeBlock,
                text: text,
                codeBlockLineWrapping: isWrapped
            ),
            isEncrypted: isEncrypted
        )
        let now = Self.timestamp()
        try database.execute(
            """
            UPDATE blocks
            SET payload_json = ?,
                revision = revision + 1,
                sync_state = ?,
                updated_at = ?
            WHERE blocks.id = ? AND blocks.is_deleted = 0
            """,
            bindings: [
                .text(payloadJSON),
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
        if isEncrypted {
            try deleteSearchIndexForPage(pageID: row["page_id"] ?? "", blockIDs: [blockID])
        } else {
            try BacklinkRepository(database: database).rebuildLinksForBlock(
                blockID: blockID,
                text: text
            )
        }
    }

    func updateTaskItemCompletion(blockID: String, isCompleted: Bool) throws {
        guard let row = try database.query(
            """
            SELECT blocks.type,
                   blocks.text_plain,
                   blocks.page_id AS page_id,
                   pages.is_encrypted AS is_encrypted
            FROM blocks
            INNER JOIN pages ON pages.id = blocks.page_id
            WHERE blocks.id = ? AND blocks.is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first,
              BlockType(rawValue: row["type"] ?? "") == .taskItem else {
            throw PageRepositoryError.blockNotFound
        }

        let isEncrypted = Self.sqliteBool(row["is_encrypted"])
        let text = try decryptedStoredValue(row["text_plain"] ?? "", isEncrypted: isEncrypted)
        let payloadJSON = try storedValue(
            try blockPayloadJSON(
                type: .taskItem,
                text: text,
                taskItemIsCompleted: isCompleted
            ),
            isEncrypted: isEncrypted
        )
        let now = Self.timestamp()
        try database.execute(
            """
            UPDATE blocks
            SET payload_json = ?,
                revision = revision + 1,
                sync_state = ?,
                updated_at = ?
            WHERE blocks.id = ? AND blocks.is_deleted = 0
            """,
            bindings: [
                .text(payloadJSON),
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
        if isEncrypted {
            try deleteSearchIndexForPage(pageID: row["page_id"] ?? "", blockIDs: [blockID])
        } else {
            try BacklinkRepository(database: database).rebuildLinksForBlock(
                blockID: blockID,
                text: text
            )
        }
    }

    func importMarkdown(
        pageID: String,
        markdown: String,
        attachmentImporter: ((MarkdownBlockDraft) throws -> AttachmentImportResult?)? = nil
    ) throws {
        let drafts = MarkdownTransformer.importBlocks(markdown: markdown)
        let now = Self.timestamp()
        let isEncrypted = try pageIsEncrypted(pageID: pageID)

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
            let referenceTargets = try markdownReferenceTargets(for: draft)
            let importDraft: MarkdownBlockDraft
            if draft.attachmentRelativePath != nil {
                if let importedAttachment = try attachmentImporter?(draft) {
                    if !isEncrypted {
                        try BacklinkRepository(database: database).rebuildLinksForBlock(
                            blockID: importedAttachment.block.id,
                            text: importedAttachment.block.textPlain
                        )
                    }
                    continue
                }
                importDraft = markdownAttachmentFallbackDraft(for: draft)
            } else {
                importDraft = draft
            }
            try insertBlock(
                id: blockID,
                pageID: pageID,
                parentBlockID: nil,
                orderKey: String(format: "%06d", index + 1),
                type: importDraft.type,
                text: importDraft.textPlain,
                taskItemIsCompleted: importDraft.taskItemIsCompleted,
                pageReferenceTargetPageID: referenceTargets.pageID,
                blockReferenceTargetBlockID: referenceTargets.blockID,
                createdAt: now
            )
            try SyncRepository(database: database).enqueue(
                entityType: "block",
                entityID: blockID,
                changeType: "create"
            )
            if !isEncrypted {
                try BacklinkRepository(database: database).rebuildLinksForBlock(
                    blockID: blockID,
                    text: importDraft.textPlain,
                    pageReferenceTargetPageID: referenceTargets.pageID,
                    blockReferenceTargetBlockID: referenceTargets.blockID
                )
            }
        }

        EditorLog.markdown.debug(
            "markdown_imported page_id=\(pageID, privacy: .public) blocks=\(drafts.count, privacy: .public)"
        )
    }

    private func markdownAttachmentFallbackDraft(for draft: MarkdownBlockDraft) -> MarkdownBlockDraft {
        guard let attachmentRelativePath = draft.attachmentRelativePath else {
            return draft
        }

        let markdownText: String
        if draft.type == .attachmentImage {
            markdownText = "![\(draft.textPlain)](\(attachmentRelativePath))"
        } else {
            markdownText = "[\(draft.textPlain)](\(attachmentRelativePath))"
        }
        return MarkdownBlockDraft(type: .paragraph, textPlain: markdownText)
    }

    private func markdownReferenceTargets(
        for draft: MarkdownBlockDraft
    ) throws -> (pageID: String?, blockID: String?) {
        switch draft.type {
        case .pageReference:
            return (try markdownPageReferenceTargetPageID(title: draft.textPlain), nil)
        case .blockReference:
            return try markdownBlockReferenceTargets(text: draft.textPlain)
        default:
            return (nil, nil)
        }
    }

    private func markdownPageReferenceTargetPageID(title: String) throws -> String? {
        let rows = try database.query(
            """
            SELECT id,
                   title,
                   is_encrypted
            FROM pages
            WHERE is_archived = 0
            ORDER BY created_at ASC
            """
        )
        for row in rows {
            let isEncrypted = Self.sqliteBool(row["is_encrypted"])
            let pageTitle = try decryptedStoredValue(row["title"] ?? "", isEncrypted: isEncrypted)
            if pageTitle == title {
                return row["id"] ?? nil
            }
        }
        return nil
    }

    func markdownBlockReferenceTargets(text: String) throws -> (pageID: String?, blockID: String?) {
        if let obsidianTargets = try obsidianBlockReferenceTargets(text: text),
           obsidianTargets.pageID != nil,
           obsidianTargets.blockID != nil {
            return obsidianTargets
        }

        let rows = try database.query(
            """
            SELECT b.id,
                   b.page_id,
                   b.text_plain,
                   p.is_encrypted
            FROM blocks b
            JOIN pages p ON p.id = b.page_id
            WHERE b.is_deleted = 0
              AND p.is_archived = 0
            ORDER BY b.created_at ASC
            """
        )
        for row in rows {
            let isEncrypted = Self.sqliteBool(row["is_encrypted"])
            let candidateText = try decryptedStoredValue(row["text_plain"] ?? "", isEncrypted: isEncrypted)
            if candidateText == text {
                return (row["page_id"] ?? nil, row["id"] ?? nil)
            }
        }

        return (nil, nil)
    }

    @discardableResult
    func relinkBlockReferenceBlock(blockID: String, text: String) throws -> Bool {
        guard let sourceRow = try database.query(
            """
            SELECT b.page_id,
                   p.is_encrypted
            FROM blocks b
            JOIN pages p ON p.id = b.page_id
            WHERE b.id = ?
              AND b.type = ?
              AND b.is_deleted = 0
            LIMIT 1
            """,
            bindings: [
                .text(blockID),
                .text(BlockType.blockReference.rawValue)
            ]
        ).first else {
            return false
        }

        let targets = try markdownBlockReferenceTargets(text: text)
        guard targets.pageID != nil || targets.blockID != nil else {
            return false
        }
        let isEncrypted = Self.sqliteBool(sourceRow["is_encrypted"])
        let now = Self.timestamp()
        try database.execute(
            """
            UPDATE blocks
            SET payload_json = ?,
                updated_at = ?
            WHERE id = ?
              AND type = ?
              AND is_deleted = 0
            """,
            bindings: [
                .text(try storedValue(
                    try blockPayloadJSON(
                        type: .blockReference,
                        text: text,
                        pageReferenceTargetPageID: targets.pageID,
                        blockReferenceTargetBlockID: targets.blockID
                    ),
                    isEncrypted: isEncrypted
                )),
                .text(now),
                .text(blockID),
                .text(BlockType.blockReference.rawValue)
            ]
        )
        if isEncrypted {
            try deleteSearchIndexForPage(pageID: sourceRow["page_id"] ?? "", blockIDs: [blockID])
        } else {
            try BacklinkRepository(database: database).rebuildLinksForBlock(
                blockID: blockID,
                text: text,
                pageReferenceTargetPageID: targets.pageID,
                blockReferenceTargetBlockID: targets.blockID
            )
        }
        return true
    }

    func relinkObsidianBlockReferenceBlocks() throws {
        let rows = try database.query(
            """
            SELECT b.id,
                   b.text_plain,
                   p.is_encrypted
            FROM blocks b
            JOIN pages p ON p.id = b.page_id
            WHERE b.type = ?
              AND b.is_deleted = 0
            ORDER BY b.created_at ASC
            """,
            bindings: [.text(BlockType.blockReference.rawValue)]
        )

        for row in rows {
            guard let blockID = row["id"] ?? nil else {
                continue
            }
            let isEncrypted = Self.sqliteBool(row["is_encrypted"])
            let text = try decryptedStoredValue(row["text_plain"] ?? "", isEncrypted: isEncrypted)
            guard text.contains("#^") else {
                continue
            }
            _ = try relinkBlockReferenceBlock(blockID: blockID, text: text)
        }
    }

    private func obsidianBlockReferenceTargets(text: String) throws -> (pageID: String?, blockID: String?)? {
        guard let anchorRange = text.range(of: "#^") else {
            return nil
        }

        let rawPageTitle = String(text[..<anchorRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let anchor = String(text[anchorRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !anchor.isEmpty else {
            return nil
        }

        let pageTitle = rawPageTitle.isEmpty ? nil : rawPageTitle
        let anchorText = "^\(anchor)"
        let rows = try database.query(
            """
            SELECT b.id,
                   b.page_id,
                   b.text_plain,
                   p.title,
                   p.is_encrypted
            FROM blocks b
            JOIN pages p ON p.id = b.page_id
            WHERE p.is_archived = 0
              AND b.is_deleted = 0
            ORDER BY b.created_at ASC
            """
        )
        for row in rows {
            let isEncrypted = Self.sqliteBool(row["is_encrypted"])
            if let pageTitle {
                let candidatePageTitle = try decryptedStoredValue(row["title"] ?? "", isEncrypted: isEncrypted)
                guard candidatePageTitle == pageTitle else {
                    continue
                }
            }
            let candidateText = try decryptedStoredValue(row["text_plain"] ?? "", isEncrypted: isEncrypted)
            if candidateText == anchorText || candidateText.hasSuffix(anchorText) {
                return (row["page_id"] ?? nil, row["id"] ?? nil)
            }
        }
        return nil
    }

#if DEBUG
    func replacePageWithUITestLargePage(pageID: String, blockCount: Int) throws {
        let now = Self.timestamp()

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
            SELECT title,
                   is_encrypted
            FROM pages
            WHERE id = ? AND is_archived = 0
            LIMIT 1
            """,
            bindings: [.text(targetPageID)]
        )
        guard let targetRow = targetRows.first,
              targetRow["title"] != nil else {
            throw PageRepositoryError.pageNotFound
        }
        let targetTitlePlaintext = try decryptPageTitleIfNeeded(targetRow)

        return try appendBlock(
            pageID: pageID,
            type: .pageReference,
            text: targetTitlePlaintext,
            taskItemIsCompleted: false,
            pageReferenceTargetPageID: targetPageID,
            blockReferenceTargetBlockID: nil
        )
    }

    @discardableResult
    func convertTextBlockToPage(blockID: String) throws -> PageSummary {
        guard let source = try database.query(
            """
            SELECT blocks.type,
                   blocks.text_plain,
                   blocks.page_id,
                   blocks.order_key,
                   blocks.payload_json,
                   pages.workspace_id,
                   pages.notebook_id,
                   pages.is_encrypted AS source_is_encrypted
            FROM blocks
            INNER JOIN pages ON pages.id = blocks.page_id
            WHERE blocks.id = ?
              AND blocks.is_deleted = 0
              AND pages.is_archived = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first else {
            throw PageRepositoryError.blockNotFound
        }
        guard let type = source["type"].flatMap(BlockType.init(rawValue:)),
              type.isTextEditable,
              let pageID = source["page_id"],
              let workspaceID = source["workspace_id"] else {
            throw PageRepositoryError.blockNotFound
        }

        let sourceIsEncrypted = Self.sqliteBool(source["source_is_encrypted"])
        let sourceText = try decryptedStoredValue(
            source["text_plain"] ?? "",
            isEncrypted: sourceIsEncrypted
        )
        let sourcePayloadJSON = try decryptedStoredValue(
            source["payload_json"] ?? "",
            isEncrypted: sourceIsEncrypted
        )
        if let targetPageID = Self.pageReferenceTargetPageID(payloadJSON: sourcePayloadJSON),
           let existingPage = try pageSummary(pageID: targetPageID) {
            EditorLog.store.debug(
                "block_page_conversion_reused block_id=\(blockID, privacy: .public) target_page_id=\(targetPageID, privacy: .public)"
            )
            return existingPage
        }
        let title = Self.pageTitle(fromBlockText: sourceText)
        let sourceOrderKey = source["order_key"] ?? "000001"
        let notebookID = source["notebook_id"] ?? nil
        let descendantBlockIDs = try descendantBlockIDs(rootBlockID: blockID, pageID: pageID)
        let now = Self.timestamp()
        let newPageID = "page-\(UUID().uuidString.lowercased())"
        let initialBlockID = "block-\(UUID().uuidString.lowercased())"
        let orderKey = try nextPageOrderKey(workspaceID: workspaceID, notebookID: notebookID)
        let shouldPreserveSourceType = type != .paragraph
        let sourceReferenceType = shouldPreserveSourceType ? type : BlockType.pageReference
        let sourceReferenceText = shouldPreserveSourceType ? sourceText : title
        let pageReferencePayload = try blockPayloadJSON(
            type: sourceReferenceType,
            text: sourceReferenceText,
            pageReferenceTargetPageID: newPageID
        )
        let storedTitle = try storedValue(title, isEncrypted: sourceIsEncrypted)
        let storedSourceReferenceText = try storedValue(sourceReferenceText, isEncrypted: sourceIsEncrypted)
        let storedPageReferencePayload = try storedValue(pageReferencePayload, isEncrypted: sourceIsEncrypted)

        try database.withImmediateTransaction("convert_text_block_to_page") {
            try database.execute(
                """
                INSERT INTO pages (id, workspace_id, notebook_id, title, order_key, is_encrypted, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(newPageID),
                    .text(workspaceID),
                    notebookID.map(SQLiteValue.text) ?? .null,
                    .text(storedTitle),
                    .text(orderKey),
                    .integer(sourceIsEncrypted ? 1 : 0),
                    .text(now),
                    .text(now)
                ]
            )
            if descendantBlockIDs.isEmpty {
                try insertBlock(
                    id: initialBlockID,
                    pageID: newPageID,
                    parentBlockID: nil,
                    orderKey: "000001",
                    type: .paragraph,
                    text: "",
                    createdAt: now
                )
            } else {
                let placeholders = descendantBlockIDs.map { _ in "?" }.joined(separator: ", ")
                try database.execute(
                    """
                    UPDATE blocks
                    SET page_id = ?,
                        parent_block_id = CASE
                            WHEN parent_block_id = ? THEN NULL
                            ELSE parent_block_id
                        END,
                        revision = revision + 1,
                        sync_state = ?,
                        updated_at = ?
                    WHERE id IN (\(placeholders))
                      AND is_deleted = 0
                    """,
                    bindings: [
                        .text(newPageID),
                        .text(blockID),
                        .text("local"),
                        .text(now)
                    ] + descendantBlockIDs.map(SQLiteValue.text)
                )
            }
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
                    .text(sourceReferenceType.rawValue),
                    .text(storedPageReferencePayload),
                    .text(storedSourceReferenceText),
                    .text("local"),
                    .text(now),
                    .text(blockID)
                ]
            )
            if !sourceIsEncrypted {
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
                        .text(pageID),
                        .text(newPageID),
                        .text(blockID),
                        .text(sourceOrderKey),
                        .text(now),
                        .text(now)
                    ]
                )
            }

            let syncRepository = SyncRepository(database: database)
            try syncRepository.enqueue(entityType: "page", entityID: newPageID, changeType: "create")
            if descendantBlockIDs.isEmpty {
                try syncRepository.enqueue(entityType: "block", entityID: initialBlockID, changeType: "create")
            } else {
                for descendantBlockID in descendantBlockIDs {
                    try syncRepository.enqueue(entityType: "block", entityID: descendantBlockID, changeType: "update")
                }
                if !sourceIsEncrypted {
                    try rebuildLinksForBlocks(blockIDs: descendantBlockIDs)
                }
            }
            try syncRepository.enqueue(entityType: "block", entityID: blockID, changeType: "update")
            if sourceIsEncrypted {
                try deleteSearchIndexForPage(pageID: pageID, blockIDs: [blockID] + descendantBlockIDs)
            } else {
                try BacklinkRepository(database: database).rebuildLinksForBlock(
                    blockID: blockID,
                    text: sourceReferenceText,
                    pageReferenceTargetPageID: newPageID
                )
            }
        }

        EditorLog.store.debug(
            "block_converted_to_page block_id=\(blockID, privacy: .public) source_page_id=\(pageID, privacy: .public) new_page_id=\(newPageID, privacy: .public)"
        )

        return PageSummary(
            id: newPageID,
            workspaceID: workspaceID,
            notebookID: notebookID,
            title: title,
            isFavorite: false,
            isEncrypted: sourceIsEncrypted,
            updatedAt: now
        )
    }

    private func pageSummary(pageID: String) throws -> PageSummary? {
        guard let row = try database.query(
            """
            SELECT id,
                   workspace_id,
                   notebook_id,
                   title,
                   is_favorite,
                   is_encrypted,
                   updated_at
            FROM pages
            WHERE id = ?
              AND is_archived = 0
            LIMIT 1
            """,
            bindings: [.text(pageID)]
        ).first else {
            return nil
        }

        return PageSummary(
            id: row["id"] ?? "",
            workspaceID: row["workspace_id"] ?? "",
            notebookID: row["notebook_id"] ?? nil,
            title: try decryptPageTitleIfNeeded(row),
            isFavorite: Self.sqliteBool(row["is_favorite"]),
            isEncrypted: Self.sqliteBool(row["is_encrypted"]),
            updatedAt: row["updated_at"]
        )
    }

    func appendBlockReferenceBlock(pageID: String, targetBlockID: String) throws -> BlockSnapshot {
        guard let targetRow = try database.query(
            """
            SELECT blocks.id,
                   blocks.page_id,
                   blocks.text_plain,
                   pages.is_encrypted AS is_encrypted
            FROM blocks
            INNER JOIN pages ON pages.id = blocks.page_id
            WHERE blocks.id = ? AND blocks.is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(targetBlockID)]
        ).first else {
            throw PageRepositoryError.blockNotFound
        }

        return try appendBlock(
            pageID: pageID,
            type: .blockReference,
            text: try decryptedStoredValue(
                targetRow["text_plain"] ?? "",
                isEncrypted: Self.sqliteBool(targetRow["is_encrypted"])
            ),
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
        let now = Self.timestamp()
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
        if try !pageIsEncrypted(pageID: pageID) {
            try BacklinkRepository(database: database).rebuildLinksForBlock(
                blockID: blockID,
                text: text,
                pageReferenceTargetPageID: pageReferenceTargetPageID,
                blockReferenceTargetBlockID: blockReferenceTargetBlockID
            )
        }

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
            blockReferenceTargetBlockID: blockReferenceTargetBlockID,
            tableRows: Self.tableRows(type: type, payloadJSON: "", text: text)
        )
    }

    func insertParagraphBlock(after blockID: String, text: String = "") throws -> BlockSnapshot {
        let selectedRows = try database.query(
            """
            SELECT page_id, parent_block_id
            FROM blocks
            WHERE blocks.id = ? AND blocks.is_deleted = 0
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

        let now = Self.timestamp()
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
        if try !pageIsEncrypted(pageID: pageID) {
            try BacklinkRepository(database: database).rebuildLinksForBlock(
                blockID: insertedBlockID,
                text: text
            )
        }
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
        try moveBlocks(blockIDs: [blockID], toIndex: targetIndex)
    }

    func moveBlocks(blockIDs: [String], toIndex targetIndex: Int) throws {
        let uniqueBlockIDs = NSOrderedSet(array: blockIDs).array.compactMap { $0 as? String }
        guard let firstBlockID = uniqueBlockIDs.first else {
            return
        }

        let selectedRows = try database.query(
            """
            SELECT page_id
            FROM blocks
            WHERE blocks.id = ? AND blocks.is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(firstBlockID)]
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

        let movingBlockIDSet = Set(uniqueBlockIDs)
        let movingBlocks = blocks.filter { movingBlockIDSet.contains($0.id) }
        guard movingBlocks.count == uniqueBlockIDs.count else {
            throw PageRepositoryError.blockNotFound
        }

        let remainingBlocks = blocks.filter { !movingBlockIDSet.contains($0.id) }
        let clampedTargetIndex = min(max(targetIndex, 0), remainingBlocks.count)
        var reorderedBlocks = remainingBlocks
        reorderedBlocks.insert(contentsOf: movingBlocks, at: clampedTargetIndex)

        let now = Self.timestamp()
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
            "blocks_moved first_block_id=\(firstBlockID, privacy: .public) moved_count=\(movingBlocks.count, privacy: .public) page_id=\(pageID, privacy: .public) target_index=\(targetIndex, privacy: .public) changed_blocks=\(changedBlockIDs.count, privacy: .public)"
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
            WHERE blocks.id = ? AND blocks.is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        )

        guard let pageID = selectedRows.first?["page_id"] ?? nil else {
            throw PageRepositoryError.blockNotFound
        }

        let now = Self.timestamp()
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
        let now = Self.timestamp()

        try database.execute(
            """
            INSERT INTO workspaces (id, name, created_at, updated_at)
            VALUES (?, ?, ?, ?)
            """,
            bindings: [
                .text(defaultWorkspaceID),
                .text("本地"),
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
                .text("笔记本"),
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
                .text("欢迎"),
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
                .text("{\"text\":\"开始用块写作。\"}"),
                .text("开始用块写作。"),
                .integer(1),
                .text("local"),
                .integer(0),
                .text(now),
                .text(now)
            ]
        )
    }

    private func localizeDefaultSeedContentIfUnmodified() throws {
        let now = Self.timestamp()

        try database.execute(
            """
            UPDATE workspaces
            SET name = ?,
                updated_at = ?
            WHERE id = ?
              AND name = ?
            """,
            bindings: [
                .text("本地"),
                .text(now),
                .text(defaultWorkspaceID),
                .text("Local")
            ]
        )

        try database.execute(
            """
            UPDATE notebooks
            SET name = ?,
                updated_at = ?
            WHERE id = ?
              AND name = ?
            """,
            bindings: [
                .text("笔记本"),
                .text(now),
                .text(defaultNotebookID),
                .text("Notebook")
            ]
        )

        try database.execute(
            """
            UPDATE pages
            SET title = ?,
                updated_at = ?
            WHERE id = ?
              AND title = ?
            """,
            bindings: [
                .text("欢迎"),
                .text(now),
                .text(defaultPageID),
                .text("Welcome")
            ]
        )

        try database.execute(
            """
            UPDATE blocks
            SET payload_json = ?,
                text_plain = ?,
                updated_at = ?
            WHERE id = ?
              AND text_plain = ?
            """,
            bindings: [
                .text("{\"text\":\"开始用块写作。\"}"),
                .text("开始用块写作。"),
                .text(now),
                .text(defaultBlockID),
                .text("Start writing in blocks.")
            ]
        )

        let oldDefaultBlockText = "Start writing in blocks."
        let newDefaultBlockText = "开始用块写作。"
        let defaultBlockRows = try database.query(
            """
            SELECT type, text_plain
            FROM blocks
            WHERE id = ?
              AND text_plain LIKE ?
            LIMIT 1
            """,
            bindings: [
                .text(defaultBlockID),
                .text("\(oldDefaultBlockText)%")
            ]
        )
        if let currentText = defaultBlockRows.first?["text_plain"],
           let currentTypeRawValue = defaultBlockRows.first?["type"],
           let currentType = BlockType(rawValue: currentTypeRawValue),
           currentText.hasPrefix(oldDefaultBlockText) {
            let suffix = String(currentText.dropFirst(oldDefaultBlockText.count))
            let localizedText = "\(newDefaultBlockText)\(suffix)"
            let payloadJSON = try blockPayloadJSON(type: currentType, text: localizedText)
            try database.execute(
                """
                UPDATE blocks
                SET payload_json = ?,
                    text_plain = ?,
                    updated_at = ?
                WHERE id = ?
                  AND text_plain = ?
                """,
                bindings: [
                    .text(payloadJSON),
                    .text(localizedText),
                    .text(now),
                    .text(defaultBlockID),
                    .text(currentText)
                ]
            )
        }
    }

    private func loadBlocks(pageIDs: [String]) throws -> [BlockSnapshot] {
        guard !pageIDs.isEmpty else {
            return []
        }

        let placeholders = Array(repeating: "?", count: pageIDs.count).joined(separator: ", ")
        return try database.query(
            """
            SELECT blocks.id AS id,
                   blocks.page_id AS page_id,
                   blocks.parent_block_id AS parent_block_id,
                   blocks.order_key AS order_key,
                   blocks.type AS type,
                   blocks.payload_json AS payload_json,
                   blocks.text_plain AS text_plain,
                   pages.is_encrypted AS is_encrypted
            FROM blocks
            INNER JOIN pages ON pages.id = blocks.page_id
            WHERE blocks.page_id IN (\(placeholders)) AND blocks.is_deleted = 0
            ORDER BY blocks.page_id ASC, blocks.order_key ASC
            """,
            bindings: pageIDs.map(SQLiteValue.text)
        ).map { row in
            let type = BlockType(rawValue: row["type"] ?? "") ?? .paragraph
            let isEncrypted = Self.sqliteBool(row["is_encrypted"])
            let payloadJSON = try decryptedStoredValue(row["payload_json"] ?? "", isEncrypted: isEncrypted)
            let textPlain = try decryptedStoredValue(row["text_plain"] ?? "", isEncrypted: isEncrypted)
            return BlockSnapshot(
                id: row["id"] ?? "",
                pageID: row["page_id"] ?? "",
                parentBlockID: row["parent_block_id"] ?? nil,
                orderKey: row["order_key"] ?? "",
                type: type,
                textPlain: textPlain,
                taskItemIsCompleted: Self.taskItemIsCompleted(
                    payloadJSON: payloadJSON
                ),
                toggleIsExpanded: Self.toggleIsExpanded(
                    payloadJSON: payloadJSON
                ),
                codeBlockLineWrapping: Self.codeBlockLineWrapping(
                    payloadJSON: payloadJSON
                ),
                pageReferenceTargetPageID: Self.pageReferenceTargetPageID(
                    payloadJSON: payloadJSON
                ),
                blockReferenceTargetBlockID: Self.blockReferenceTargetBlockID(
                    payloadJSON: payloadJSON
                ),
                tableRows: Self.tableRows(
                    type: type,
                    payloadJSON: payloadJSON,
                    text: textPlain
                ),
                attachmentID: Self.attachmentID(
                    type: type,
                    payloadJSON: payloadJSON
                ),
                attachmentDisplayWidth: Self.attachmentDisplayWidth(
                    type: type,
                    payloadJSON: payloadJSON
                )
            )
        }
    }

    private static func pageTitle(fromBlockText text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? "未命名" : trimmedText
    }

    private func decryptPageTitleIfNeeded(_ row: SQLiteRow) throws -> String {
        try decryptedStoredValue(
            row["title"] ?? "",
            isEncrypted: Self.sqliteBool(row["is_encrypted"])
        )
    }

    private func storedValue(_ plaintext: String, isEncrypted: Bool) throws -> String {
        isEncrypted ? try encryptedNoteCipher.encrypt(plaintext) : plaintext
    }

    private func decryptedStoredValue(_ storedValue: String, isEncrypted: Bool) throws -> String {
        guard isEncrypted || encryptedNoteCipher.isCiphertext(storedValue) else {
            return storedValue
        }
        return try encryptedNoteCipher.decrypt(storedValue)
    }

    private func pageIsEncrypted(pageID: String) throws -> Bool {
        let row = try database.query(
            """
            SELECT is_encrypted
            FROM pages
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(pageID)]
        ).first

        return Self.sqliteBool(row?["is_encrypted"])
    }

    private func deleteSearchIndexForPage(pageID: String, blockIDs: [String]) throws {
        try database.execute(
            """
            DELETE FROM search_index
            WHERE entity_type = 'page' AND entity_id = ?
            """,
            bindings: [.text(pageID)]
        )

        guard !blockIDs.isEmpty else {
            return
        }

        let placeholders = blockIDs.map { _ in "?" }.joined(separator: ", ")
        try database.execute(
            """
            DELETE FROM search_index
            WHERE entity_type = 'block' AND entity_id IN (\(placeholders))
            """,
            bindings: blockIDs.map(SQLiteValue.text)
        )
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
        let isEncrypted = try pageIsEncrypted(pageID: pageID)
        let payloadJSON = try storedValue(
            try blockPayloadJSON(
                type: type,
                text: text,
                taskItemIsCompleted: taskItemIsCompleted,
                pageReferenceTargetPageID: pageReferenceTargetPageID,
                blockReferenceTargetBlockID: blockReferenceTargetBlockID
            ),
            isEncrypted: isEncrypted
        )
        let storedText = try storedValue(text, isEncrypted: isEncrypted)
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
                .text(payloadJSON),
                .text(storedText),
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

    private func descendantBlockIDs(rootBlockID: String, pageID: String) throws -> [String] {
        let rows = try database.query(
            """
            SELECT id, parent_block_id
            FROM blocks
            WHERE page_id = ?
              AND is_deleted = 0
            ORDER BY order_key ASC
            """,
            bindings: [.text(pageID)]
        )

        var childIDsByParentID: [String: [String]] = [:]
        for row in rows {
            guard let id = row["id"],
                  let parentBlockID = row["parent_block_id"] else {
                continue
            }
            childIDsByParentID[parentBlockID, default: []].append(id)
        }

        var descendantIDs: [String] = []
        func appendDescendants(of parentID: String) {
            for childID in childIDsByParentID[parentID] ?? [] {
                descendantIDs.append(childID)
                appendDescendants(of: childID)
            }
        }

        appendDescendants(of: rootBlockID)
        return descendantIDs
    }

    private func rebuildLinksForBlocks(blockIDs: [String]) throws {
        guard !blockIDs.isEmpty else {
            return
        }

        let placeholders = blockIDs.map { _ in "?" }.joined(separator: ", ")
        let rows = try database.query(
            """
            SELECT id, text_plain, payload_json
            FROM blocks
            WHERE id IN (\(placeholders))
              AND is_deleted = 0
            """,
            bindings: blockIDs.map(SQLiteValue.text)
        )
        let backlinkRepository = BacklinkRepository(database: database)

        for row in rows {
            let payloadJSON = row["payload_json"] ?? ""
            try backlinkRepository.rebuildLinksForBlock(
                blockID: row["id"] ?? "",
                text: row["text_plain"] ?? "",
                pageReferenceTargetPageID: Self.pageReferenceTargetPageID(payloadJSON: payloadJSON),
                blockReferenceTargetBlockID: Self.blockReferenceTargetBlockID(payloadJSON: payloadJSON)
            )
        }
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

    @discardableResult
    func updateBlockParent(blockID: String, parentBlockID: String?) throws -> Bool {
        let block = try requiredActiveBlock(blockID: blockID)
        let pageID = block["page_id"] ?? ""
        let currentParentBlockID = block["parent_block_id"] ?? nil
        guard currentParentBlockID != parentBlockID else {
            return false
        }

        if let parentBlockID {
            guard parentBlockID != blockID else {
                throw PageRepositoryError.cyclicBlockParent
            }

            let parent = try requiredActiveBlock(blockID: parentBlockID)
            guard parent["page_id"] == pageID else {
                throw PageRepositoryError.blockNotFound
            }
            guard try !blockParentChainContains(
                blockID: parentBlockID,
                ancestorBlockID: blockID
            ) else {
                throw PageRepositoryError.cyclicBlockParent
            }
        }

        try persistBlockParent(blockID: blockID, parentBlockID: parentBlockID)
        return true
    }

    private func persistBlockParent(blockID: String, parentBlockID: String?) throws {
        let now = Self.timestamp()
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

    private func blockParentChainContains(
        blockID: String,
        ancestorBlockID: String
    ) throws -> Bool {
        var currentBlockID: String? = blockID
        var visitedBlockIDs: Set<String> = []

        while let current = currentBlockID,
              !visitedBlockIDs.contains(current) {
            if current == ancestorBlockID {
                return true
            }

            visitedBlockIDs.insert(current)
            currentBlockID = try database.query(
                """
                SELECT parent_block_id
                FROM blocks
                WHERE id = ? AND is_deleted = 0
                LIMIT 1
                """,
                bindings: [.text(current)]
            ).first?["parent_block_id"] ?? nil
        }

        return false
    }

    private func blockPayloadJSON(
        type: BlockType,
        text: String,
        taskItemIsCompleted: Bool = false,
        toggleIsExpanded: Bool = true,
        codeBlockLineWrapping: Bool = true,
        pageReferenceTargetPageID: String? = nil,
        blockReferenceTargetBlockID: String? = nil,
        tableRows explicitTableRows: [[String]]? = nil
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
        case .table:
            let tableRows = Self.normalizedTableRows(text: text, explicitRows: explicitTableRows)
            payload = [
                "rows": tableRows,
                "text": MarkdownTableDocument(rows: tableRows).markdown
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
            var defaultPayload: [String: Any] = ["text": text]
            if let pageReferenceTargetPageID,
               !pageReferenceTargetPageID.isEmpty {
                defaultPayload["target_page_id"] = pageReferenceTargetPageID
            }
            payload = defaultPayload
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

    private func blockPayloadJSON(block: BlockSnapshot) throws -> String {
        switch block.type {
        case .attachmentImage:
            return try attachmentBlockPayloadJSON(
                attachmentID: block.attachmentID,
                kind: .image,
                filename: block.textPlain,
                displayWidth: block.attachmentDisplayWidth
            )
        case .attachmentVideo:
            return try attachmentBlockPayloadJSON(
                attachmentID: block.attachmentID,
                kind: .video,
                filename: block.textPlain
            )
        case .attachmentFile:
            return try attachmentBlockPayloadJSON(
                attachmentID: block.attachmentID,
                kind: .file,
                filename: block.textPlain
            )
        default:
            return try blockPayloadJSON(
                type: block.type,
                text: block.textPlain,
                taskItemIsCompleted: block.taskItemIsCompleted,
                toggleIsExpanded: block.toggleIsExpanded,
                codeBlockLineWrapping: block.codeBlockLineWrapping,
                pageReferenceTargetPageID: block.pageReferenceTargetPageID,
                blockReferenceTargetBlockID: block.blockReferenceTargetBlockID,
                tableRows: block.tableRows
            )
        }
    }

    private func attachmentBlockPayloadJSON(
        attachmentID: String?,
        kind: AttachmentKind,
        filename: String,
        displayWidth: Double? = nil
    ) throws -> String {
        var payload: [String: Any] = [
            "attachment_id": attachmentID ?? "",
            "filename": filename,
            "kind": kind.rawValue
        ]
        if kind == .image,
           let displayWidth {
            payload["display_width"] = displayWidth
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

    private static func normalizedTableRows(text: String, explicitRows: [[String]]?) -> [[String]] {
        if let explicitRows, !explicitRows.isEmpty {
            return MarkdownTableDocument(rows: explicitRows).rows
        }

        let parsedRows = MarkdownTableDocument(markdown: text).rows
        if !parsedRows.isEmpty {
            return parsedRows
        }

        return MarkdownTableDocument.defaultGridRows(firstCellText: text)
    }

    private static func tableRows(type: BlockType, payloadJSON: String, text: String) -> [[String]] {
        guard type == .table else {
            return []
        }

        if let data = payloadJSON.data(using: .utf8),
           let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let rows = payload["rows"] as? [[String]],
           !rows.isEmpty {
            return MarkdownTableDocument(rows: rows).rows
        }

        return normalizedTableRows(text: text, explicitRows: nil)
    }

    private static func attachmentID(type: BlockType, payloadJSON: String) -> String? {
        guard type == .attachmentImage || type == .attachmentVideo || type == .attachmentFile,
              let data = payloadJSON.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return payload["attachment_id"] as? String
    }

    private static func attachmentDisplayWidth(type: BlockType, payloadJSON: String) -> Double? {
        guard type == .attachmentImage,
              let data = payloadJSON.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let width = payload["display_width"] as? Double {
            return width
        }
        if let width = payload["display_width"] as? Int {
            return Double(width)
        }
        return nil
    }

    private static func attachmentKind(for type: BlockType) -> AttachmentKind? {
        switch type {
        case .attachmentImage:
            return .image
        case .attachmentVideo:
            return .video
        case .attachmentFile:
            return .file
        default:
            return nil
        }
    }

    private func currentReferenceTargets(blockID: String) throws -> (pageID: String?, blockID: String?) {
        guard let row = try database.query(
            """
            SELECT blocks.payload_json,
                   pages.is_encrypted AS is_encrypted
            FROM blocks
            INNER JOIN pages ON pages.id = blocks.page_id
            WHERE blocks.id = ? AND blocks.is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first else {
            return (nil, nil)
        }

        let payloadJSON = try decryptedStoredValue(
            row["payload_json"] ?? "",
            isEncrypted: Self.sqliteBool(row["is_encrypted"])
        )
        return (
            Self.pageReferenceTargetPageID(payloadJSON: payloadJSON),
            Self.blockReferenceTargetBlockID(payloadJSON: payloadJSON)
        )
    }

    private func currentTaskItemCompletion(blockID: String) throws -> Bool? {
        guard let row = try database.query(
            """
            SELECT blocks.type,
                   blocks.payload_json,
                   pages.is_encrypted AS is_encrypted
            FROM blocks
            INNER JOIN pages ON pages.id = blocks.page_id
            WHERE blocks.id = ? AND blocks.is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first,
              BlockType(rawValue: row["type"] ?? "") == .taskItem else {
            return nil
        }

        let payloadJSON = try decryptedStoredValue(
            row["payload_json"] ?? "",
            isEncrypted: Self.sqliteBool(row["is_encrypted"])
        )
        return Self.taskItemIsCompleted(payloadJSON: payloadJSON)
    }

    private func currentToggleExpansion(blockID: String) throws -> Bool? {
        guard let row = try database.query(
            """
            SELECT blocks.type,
                   blocks.payload_json,
                   pages.is_encrypted AS is_encrypted
            FROM blocks
            INNER JOIN pages ON pages.id = blocks.page_id
            WHERE blocks.id = ? AND blocks.is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first,
              BlockType(rawValue: row["type"] ?? "") == .toggle else {
            return nil
        }

        let payloadJSON = try decryptedStoredValue(
            row["payload_json"] ?? "",
            isEncrypted: Self.sqliteBool(row["is_encrypted"])
        )
        return Self.toggleIsExpanded(payloadJSON: payloadJSON)
    }

    private func currentCodeBlockLineWrapping(blockID: String) throws -> Bool? {
        guard let row = try database.query(
            """
            SELECT blocks.type,
                   blocks.payload_json,
                   pages.is_encrypted AS is_encrypted
            FROM blocks
            INNER JOIN pages ON pages.id = blocks.page_id
            WHERE blocks.id = ? AND blocks.is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first,
              BlockType(rawValue: row["type"] ?? "") == .codeBlock else {
            return nil
        }

        let payloadJSON = try decryptedStoredValue(
            row["payload_json"] ?? "",
            isEncrypted: Self.sqliteBool(row["is_encrypted"])
        )
        return Self.codeBlockLineWrapping(payloadJSON: payloadJSON)
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

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
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
    case cyclicBlockParent
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
