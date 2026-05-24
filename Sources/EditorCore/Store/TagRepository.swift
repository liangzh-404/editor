import Foundation

enum PageTagSyncIdentity {
    static func entityID(pageID: String, tagID: String) -> String {
        "\(pageID).\(tagID)"
    }

    static func components(entityID: String) -> (pageID: String, tagID: String)? {
        let parts = entityID.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return nil
        }

        return (pageID: parts[0], tagID: parts[1])
    }
}

final class TagRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func createTag(
        workspaceID: String,
        parentTagID: String? = nil,
        name: String
    ) throws -> TagSummary {
        if let existingTag = try existingTag(
            workspaceID: workspaceID,
            parentTagID: parentTagID,
            name: name
        ) {
            return existingTag
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let tagID = "tag-\(UUID().uuidString.lowercased())"
        let orderKey = try nextTagOrderKey(workspaceID: workspaceID, parentTagID: parentTagID)
        try database.execute(
            """
            INSERT INTO tags (id, workspace_id, parent_tag_id, name, order_key, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(tagID),
                .text(workspaceID),
                parentTagID.map(SQLiteValue.text) ?? .null,
                .text(name),
                .text(orderKey),
                .text(now),
                .text(now)
            ]
        )
        try SyncRepository(database: database).enqueue(
            entityType: "tag",
            entityID: tagID,
            changeType: "create"
        )

        return try tags(workspaceID: workspaceID).first { $0.id == tagID } ?? TagSummary(
            id: tagID,
            workspaceID: workspaceID,
            parentTagID: parentTagID,
            name: name,
            path: name
        )
    }

    func tags(workspaceID: String) throws -> [TagSummary] {
        let rows = try database.query(
            """
            SELECT id, workspace_id, parent_tag_id, name, order_key
            FROM tags
            WHERE workspace_id = ?
            ORDER BY order_key ASC
            """,
            bindings: [.text(workspaceID)]
        )
        let rawTags = rows.map { row in
            TagSummary(
                id: row["id"] ?? "",
                workspaceID: row["workspace_id"] ?? "",
                parentTagID: row["parent_tag_id"] ?? nil,
                name: row["name"] ?? "",
                path: row["name"] ?? ""
            )
        }

        return rawTags.map { tag in
            TagSummary(
                id: tag.id,
                workspaceID: tag.workspaceID,
                parentTagID: tag.parentTagID,
                name: tag.name,
                path: Self.path(for: tag, in: rawTags)
            )
        }.sorted { left, right in
            left.path.localizedStandardCompare(right.path) == .orderedAscending
        }
    }

    @discardableResult
    func repairDuplicateTags() throws -> Int {
        struct RepairTagRow {
            let id: String
            let workspaceID: String
            let path: String
            let depth: Int
            let pageCount: Int
            let createdAt: String
        }

        let rows = try database.query(
            """
            WITH RECURSIVE tag_paths(id, workspace_id, parent_tag_id, name, path, depth, created_at) AS (
                SELECT id,
                       workspace_id,
                       parent_tag_id,
                       name,
                       name,
                       0,
                       created_at
                FROM tags
                WHERE parent_tag_id IS NULL
                   OR NOT EXISTS (
                       SELECT 1
                       FROM tags AS parent
                       WHERE parent.id = tags.parent_tag_id
                   )
                UNION ALL
                SELECT child.id,
                       child.workspace_id,
                       child.parent_tag_id,
                       child.name,
                       tag_paths.path || '/' || child.name,
                       tag_paths.depth + 1,
                       child.created_at
                FROM tags AS child
                JOIN tag_paths ON child.parent_tag_id = tag_paths.id
            )
            SELECT id,
                   workspace_id,
                   path,
                   depth,
                   created_at,
                   (
                       SELECT COUNT(DISTINCT page_id)
                       FROM page_tags
                       WHERE tag_id = tag_paths.id
                   ) AS page_count
            FROM tag_paths
            ORDER BY depth ASC, path ASC, page_count DESC, created_at ASC
            """
        ).map { row in
            RepairTagRow(
                id: row["id"] ?? "",
                workspaceID: row["workspace_id"] ?? "",
                path: row["path"] ?? "",
                depth: Int(row["depth"] ?? "") ?? 0,
                pageCount: Int(row["page_count"] ?? "") ?? 0,
                createdAt: row["created_at"] ?? ""
            )
        }

        let groupedRows = Dictionary(grouping: rows) { row in
            "\(row.workspaceID)\u{1F}\(row.path)"
        }
        let duplicateGroups = groupedRows.values
            .filter { $0.count > 1 }
            .sorted { left, right in
                let leftDepth = left.map(\.depth).min() ?? 0
                let rightDepth = right.map(\.depth).min() ?? 0
                if leftDepth != rightDepth {
                    return leftDepth < rightDepth
                }
                return (left.first?.path ?? "") < (right.first?.path ?? "")
            }
        guard !duplicateGroups.isEmpty else {
            return 0
        }

        let syncRepository = SyncRepository(database: database)
        var repairedCount = 0
        try database.withImmediateTransaction("repair_duplicate_tags") {
            for group in duplicateGroups {
                let sortedGroup = group.sorted { left, right in
                    if left.pageCount != right.pageCount {
                        return left.pageCount > right.pageCount
                    }
                    return left.createdAt < right.createdAt
                }
                guard let canonical = sortedGroup.first else {
                    continue
                }

                for duplicate in sortedGroup.dropFirst() {
                    let duplicateAssignments = try database.query(
                        """
                        SELECT page_id, created_at
                        FROM page_tags
                        WHERE tag_id = ?
                        ORDER BY created_at ASC
                        """,
                        bindings: [.text(duplicate.id)]
                    )

                    for assignment in duplicateAssignments {
                        guard let pageID = assignment["page_id"] else {
                            continue
                        }
                        let createdAt = assignment["created_at"] ?? ISO8601DateFormatter().string(from: Date())
                        try database.execute(
                            """
                            INSERT OR IGNORE INTO page_tags (page_id, tag_id, created_at)
                            VALUES (?, ?, ?)
                            """,
                            bindings: [
                                .text(pageID),
                                .text(canonical.id),
                                .text(createdAt)
                            ]
                        )
                        try syncRepository.enqueue(
                            entityType: "pageTag",
                            entityID: PageTagSyncIdentity.entityID(pageID: pageID, tagID: canonical.id),
                            changeType: "create"
                        )
                        try syncRepository.enqueue(
                            entityType: "pageTag",
                            entityID: PageTagSyncIdentity.entityID(pageID: pageID, tagID: duplicate.id),
                            changeType: "delete"
                        )
                    }

                    try database.execute(
                        "UPDATE tags SET parent_tag_id = ? WHERE parent_tag_id = ?",
                        bindings: [
                            .text(canonical.id),
                            .text(duplicate.id)
                        ]
                    )
                    try database.execute(
                        "DELETE FROM page_tags WHERE tag_id = ?",
                        bindings: [.text(duplicate.id)]
                    )
                    try database.execute(
                        "DELETE FROM tags WHERE id = ?",
                        bindings: [.text(duplicate.id)]
                    )
                    try syncRepository.enqueue(
                        entityType: "tag",
                        entityID: duplicate.id,
                        changeType: "delete"
                    )
                    repairedCount += 1
                }
            }
        }

        return repairedCount
    }

    func assignTags(pageID: String, tagIDs: [String]) throws {
        let existingTagIDs = Set(
            try database.query(
                "SELECT tag_id FROM page_tags WHERE page_id = ?",
                bindings: [.text(pageID)]
            ).compactMap { $0["tag_id"] }
        )
        let nextTagIDs = Set(tagIDs)
        let removedTagIDs = existingTagIDs.subtracting(nextTagIDs)
        let addedTagIDs = nextTagIDs.subtracting(existingTagIDs)
        guard !removedTagIDs.isEmpty || !addedTagIDs.isEmpty else {
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        try database.withImmediateTransaction("page_tags_assign") {
            for tagID in removedTagIDs {
                try database.execute(
                    "DELETE FROM page_tags WHERE page_id = ? AND tag_id = ?",
                    bindings: [.text(pageID), .text(tagID)]
                )
            }
            for tagID in addedTagIDs {
                try database.execute(
                    "INSERT INTO page_tags (page_id, tag_id, created_at) VALUES (?, ?, ?)",
                    bindings: [.text(pageID), .text(tagID), .text(now)]
                )
            }
        }

        let syncRepository = SyncRepository(database: database)
        for tagID in addedTagIDs.sorted() {
            try syncRepository.enqueue(
                entityType: "pageTag",
                entityID: PageTagSyncIdentity.entityID(pageID: pageID, tagID: tagID),
                changeType: "create"
            )
        }
        for tagID in removedTagIDs.sorted() {
            try syncRepository.enqueue(
                entityType: "pageTag",
                entityID: PageTagSyncIdentity.entityID(pageID: pageID, tagID: tagID),
                changeType: "delete"
            )
        }
    }

    func tagAssignments() throws -> [PageTagAssignment] {
        try database.query(
            """
            SELECT page_id, tag_id
            FROM page_tags
            ORDER BY page_id ASC, tag_id ASC
            """
        ).map { row in
            PageTagAssignment(pageID: row["page_id"] ?? "", tagID: row["tag_id"] ?? "")
        }
    }

    func pageIDs(tagID: String) throws -> [String] {
        try database.query(
            """
            SELECT page_id
            FROM page_tags
            WHERE tag_id = ?
            ORDER BY created_at ASC
            """,
            bindings: [.text(tagID)]
        ).compactMap { $0["page_id"] }
    }

    func deleteTag(id tagID: String) throws {
        let tagIDs = try tagIDsIncludingDescendants(of: tagID)
        guard !tagIDs.isEmpty else {
            return
        }

        let placeholders = Array(repeating: "?", count: tagIDs.count).joined(separator: ", ")
        let tagIDBindings = tagIDs.map(SQLiteValue.text)
        let assignments = try database.query(
            """
            SELECT page_id, tag_id
            FROM page_tags
            WHERE tag_id IN (\(placeholders))
            """,
            bindings: tagIDBindings
        )
        try database.execute(
            "DELETE FROM tags WHERE id = ?",
            bindings: [.text(tagID)]
        )
        let syncRepository = SyncRepository(database: database)
        for assignment in assignments {
            guard let pageID = assignment["page_id"],
                  let tagID = assignment["tag_id"] else {
                continue
            }
            try syncRepository.enqueue(
                entityType: "pageTag",
                entityID: PageTagSyncIdentity.entityID(pageID: pageID, tagID: tagID),
                changeType: "delete"
            )
        }
        for removedTagID in tagIDs {
            try syncRepository.enqueue(
                entityType: "tag",
                entityID: removedTagID,
                changeType: "delete"
            )
        }
    }

    private func tagIDsIncludingDescendants(of tagID: String) throws -> [String] {
        guard try database.query(
            "SELECT id FROM tags WHERE id = ? LIMIT 1",
            bindings: [.text(tagID)]
        ).first != nil else {
            return []
        }

        var tagIDs: [String] = []
        func appendTagAndChildren(_ currentTagID: String) throws {
            tagIDs.append(currentTagID)
            let childIDs = try database.query(
                "SELECT id FROM tags WHERE parent_tag_id = ? ORDER BY order_key ASC",
                bindings: [.text(currentTagID)]
            ).compactMap { $0["id"] }
            for childID in childIDs {
                try appendTagAndChildren(childID)
            }
        }

        try appendTagAndChildren(tagID)
        return tagIDs
    }

    private func nextTagOrderKey(workspaceID: String, parentTagID: String?) throws -> String {
        let rows = try database.query(
            """
            SELECT order_key
            FROM tags
            WHERE workspace_id = ?
              AND parent_tag_id IS ?
            ORDER BY order_key DESC
            LIMIT 1
            """,
            bindings: [.text(workspaceID), parentTagID.map(SQLiteValue.text) ?? .null]
        )
        let last = Int(rows.first?["order_key"] ?? "0") ?? 0
        return String(format: "%06d", last + 1)
    }

    private func existingTag(
        workspaceID: String,
        parentTagID: String?,
        name: String
    ) throws -> TagSummary? {
        let rows: [SQLiteRow]
        if let parentTagID {
            rows = try database.query(
                """
                SELECT id
                FROM tags
                WHERE workspace_id = ?
                  AND parent_tag_id = ?
                  AND name = ?
                ORDER BY created_at ASC
                LIMIT 1
                """,
                bindings: [
                    .text(workspaceID),
                    .text(parentTagID),
                    .text(name)
                ]
            )
        } else {
            rows = try database.query(
                """
                SELECT id
                FROM tags
                WHERE workspace_id = ?
                  AND parent_tag_id IS NULL
                  AND name = ?
                ORDER BY created_at ASC
                LIMIT 1
                """,
                bindings: [
                    .text(workspaceID),
                    .text(name)
                ]
            )
        }

        guard let tagID = rows.first?["id"] else {
            return nil
        }
        return try tags(workspaceID: workspaceID).first { $0.id == tagID }
    }

    private static func path(for tag: TagSummary, in tags: [TagSummary]) -> String {
        guard let parentTagID = tag.parentTagID,
              let parent = tags.first(where: { $0.id == parentTagID }) else {
            return tag.name
        }

        return "\(path(for: parent, in: tags))/\(tag.name)"
    }
}
