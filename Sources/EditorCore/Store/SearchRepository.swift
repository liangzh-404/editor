import Foundation

struct SearchResult: Identifiable, Equatable, Sendable {
    let entityType: String
    let entityID: String
    let title: String
    let snippet: String
    let destinationPageID: String?

    init(
        entityType: String,
        entityID: String,
        title: String,
        snippet: String,
        destinationPageID: String? = nil
    ) {
        self.entityType = entityType
        self.entityID = entityID
        self.title = title
        self.snippet = snippet
        self.destinationPageID = destinationPageID
    }

    var id: String {
        "\(entityType):\(entityID)"
    }
}

final class SearchRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func rebuildIndex() throws {
        try database.execute("DELETE FROM search_index")
        try indexPages()
        try indexBlocks()
        try indexAttachments()
        EditorLog.render.debug("search_index_rebuilt")
    }

    func updateBlockIndex(blockID: String) throws {
        try database.withImmediateTransaction("search_index_block_update") {
            try deleteIndex(entityType: "block", entityID: blockID)
            let rows = try database.query(
                """
                SELECT blocks.id AS block_id,
                       pages.title AS page_title,
                       blocks.text_plain AS text_plain
                FROM blocks
                INNER JOIN pages ON pages.id = blocks.page_id
                WHERE blocks.id = ?
                  AND blocks.is_deleted = 0
                  AND blocks.text_plain != ''
                LIMIT 1
                """,
                bindings: [.text(blockID)]
            )

            if let row = rows.first {
                try insertIndex(
                    entityType: "block",
                    entityID: row["block_id"] ?? "",
                    title: row["page_title"] ?? "",
                    body: row["text_plain"] ?? ""
                )
            }
        }

        EditorLog.render.debug("search_index_block_updated block_id=\(blockID, privacy: .public)")
    }

    func updateDiaryEntryIndex(entryID: String) throws {
        try database.withImmediateTransaction("search_index_diary_update") {
            try deleteIndex(entityType: "diary", entityID: entryID)
        }

        EditorLog.render.debug("search_index_diary_updated entry_id=\(entryID, privacy: .public)")
    }

    func search(_ query: String, limit: Int = 20) throws -> [SearchResult] {
        let tokens = searchTokens(for: query)
        guard let ftsQuery = ftsQuery(for: tokens) else {
            return []
        }

        let rows = try database.query(
            """
            SELECT entity_type,
                   entity_id,
                   title,
                   snippet(search_index, 3, '', '', '...', 12) AS snippet
            FROM search_index
            WHERE search_index MATCH ?
            ORDER BY CASE
                         WHEN lower(title) LIKE ? THEN 0
                         ELSE 1
                     END ASC,
                     rank
            LIMIT ?
            """,
            bindings: [
                .text(ftsQuery),
                .text(titlePriorityPattern(for: tokens)),
                .integer(limit)
            ]
        )

        var results: [SearchResult] = []
        for row in rows {
            let entityType = row["entity_type"] ?? ""
            let entityID = row["entity_id"] ?? ""
            results.append(
                SearchResult(
                    entityType: entityType,
                    entityID: entityID,
                    title: row["title"] ?? "",
                    snippet: row["snippet"] ?? "",
                    destinationPageID: try destinationPageID(entityType: entityType, entityID: entityID)
                )
            )
        }

        return results
    }

    private func destinationPageID(entityType: String, entityID: String) throws -> String? {
        switch entityType {
        case "page":
            return entityID
        case "block":
            return try database.query(
                """
                SELECT page_id
                FROM blocks
                WHERE id = ? AND is_deleted = 0
                LIMIT 1
                """,
                bindings: [.text(entityID)]
            ).first?["page_id"] ?? nil
        case "attachment":
            return try database.query(
                """
                SELECT blocks.page_id
                FROM blocks
                INNER JOIN pages ON pages.id = blocks.page_id
                WHERE blocks.is_deleted = 0
                  AND pages.is_archived = 0
                  AND json_extract(blocks.payload_json, '$.attachment_id') = ?
                LIMIT 1
                """,
                bindings: [.text(entityID)]
            ).first?["page_id"] ?? nil
        default:
            return nil
        }
    }

    private func indexPages() throws {
        let pages = try database.query(
            """
            SELECT id, title
            FROM pages
            WHERE is_archived = 0
            """
        )

        for page in pages {
            let pageID = page["id"] ?? ""
            let title = page["title"] ?? ""
            try insertIndex(entityType: "page", entityID: pageID, title: title, body: title)
        }
    }

    private func indexBlocks() throws {
        let blocks = try database.query(
            """
            SELECT blocks.id AS block_id,
                   pages.title AS page_title,
                   blocks.text_plain AS text_plain
            FROM blocks
            INNER JOIN pages ON pages.id = blocks.page_id
            WHERE blocks.is_deleted = 0
              AND blocks.text_plain != ''
            """
        )

        for block in blocks {
            try insertIndex(
                entityType: "block",
                entityID: block["block_id"] ?? "",
                title: block["page_title"] ?? "",
                body: block["text_plain"] ?? ""
            )
        }
    }

    private func indexAttachments() throws {
        let attachments = try database.query(
            """
            SELECT id, original_filename
            FROM attachments
            """
        )

        for attachment in attachments {
            let filename = attachment["original_filename"] ?? ""
            try insertIndex(
                entityType: "attachment",
                entityID: attachment["id"] ?? "",
                title: filename,
                body: filename
            )
        }
    }

    private func insertIndex(
        entityType: String,
        entityID: String,
        title: String,
        body: String
    ) throws {
        try database.execute(
            """
            INSERT INTO search_index (entity_type, entity_id, title, body)
            VALUES (?, ?, ?, ?)
            """,
            bindings: [
                .text(entityType),
                .text(entityID),
                .text(title),
                .text(body)
            ]
        )
    }

    private func deleteIndex(entityType: String, entityID: String) throws {
        try database.execute(
            """
            DELETE FROM search_index
            WHERE entity_type = ? AND entity_id = ?
            """,
            bindings: [
                .text(entityType),
                .text(entityID)
            ]
        )
    }

    private func searchTokens(for query: String) -> [String] {
        query
            .split { character in
                !character.isLetter && !character.isNumber
            }
            .map(String.init)
    }

    private func ftsQuery(for tokens: [String]) -> String? {
        guard !tokens.isEmpty else {
            return nil
        }

        return tokens
            .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            .joined(separator: " OR ")
    }

    private func titlePriorityPattern(for tokens: [String]) -> String {
        guard let firstToken = tokens.first else {
            return "%"
        }

        return "%\(firstToken.lowercased())%"
    }
}
