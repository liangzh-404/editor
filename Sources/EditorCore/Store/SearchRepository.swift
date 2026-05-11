import Foundation

struct SearchResult: Identifiable, Equatable, Sendable {
    let entityType: String
    let entityID: String
    let title: String
    let snippet: String

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

    func search(_ query: String, limit: Int = 20) throws -> [SearchResult] {
        guard let ftsQuery = ftsQuery(for: query) else {
            return []
        }

        return try database.query(
            """
            SELECT entity_type, entity_id, title, body
            FROM search_index
            WHERE search_index MATCH ?
            ORDER BY rank
            LIMIT ?
            """,
            bindings: [
                .text(ftsQuery),
                .integer(limit)
            ]
        ).map { row in
            SearchResult(
                entityType: row["entity_type"] ?? "",
                entityID: row["entity_id"] ?? "",
                title: row["title"] ?? "",
                snippet: row["body"] ?? ""
            )
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

    private func ftsQuery(for query: String) -> String? {
        let tokens = query
            .split { character in
                !character.isLetter && !character.isNumber
            }
            .map(String.init)

        guard !tokens.isEmpty else {
            return nil
        }

        return tokens
            .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            .joined(separator: " OR ")
    }
}
