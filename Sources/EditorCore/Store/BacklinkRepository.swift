import Foundation

struct Backlink: Identifiable, Equatable, Sendable {
    let sourcePageID: String
    let sourceBlockID: String?
    let targetPageID: String?
    let targetBlockID: String?
    let linkText: String

    var id: String {
        [
            sourcePageID,
            sourceBlockID ?? "",
            targetPageID ?? "",
            targetBlockID ?? "",
            linkText
        ].joined(separator: ":")
    }
}

final class BacklinkRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func rebuildLinksForBlock(blockID: String, text: String) throws {
        try database.execute(
            """
            DELETE FROM links
            WHERE source_block_id = ?
            """,
            bindings: [.text(blockID)]
        )

        let sourceRows = try database.query(
            """
            SELECT page_id
            FROM blocks
            WHERE id = ? AND is_deleted = 0
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        )
        guard let sourcePageID = sourceRows.first?["page_id"] ?? nil else {
            return
        }

        for linkText in Self.pageReferenceTexts(in: text) {
            let targetPageID = try targetPageID(forTitle: linkText)
            try database.execute(
                """
                INSERT INTO links (
                    id,
                    source_page_id,
                    source_block_id,
                    target_page_id,
                    target_block_id,
                    link_text,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text("link-\(UUID().uuidString.lowercased())"),
                    .text(sourcePageID),
                    .text(blockID),
                    targetPageID.map(SQLiteValue.text) ?? .null,
                    .null,
                    .text(linkText),
                    .text(ISO8601DateFormatter().string(from: Date()))
                ]
            )
        }
    }

    func backlinks(targetPageID: String) throws -> [Backlink] {
        try database.query(
            """
            SELECT source_page_id,
                   source_block_id,
                   target_page_id,
                   target_block_id,
                   link_text
            FROM links
            WHERE target_page_id = ?
            ORDER BY created_at ASC
            """,
            bindings: [.text(targetPageID)]
        ).map { row in
            Backlink(
                sourcePageID: row["source_page_id"] ?? "",
                sourceBlockID: row["source_block_id"] ?? nil,
                targetPageID: row["target_page_id"] ?? nil,
                targetBlockID: row["target_block_id"] ?? nil,
                linkText: row["link_text"] ?? ""
            )
        }
    }

    private func targetPageID(forTitle title: String) throws -> String? {
        try database.query(
            """
            SELECT id
            FROM pages
            WHERE title = ? AND is_archived = 0
            ORDER BY created_at ASC
            LIMIT 1
            """,
            bindings: [.text(title)]
        ).first?["id"] ?? nil
    }

    static func pageReferenceTexts(in text: String) -> [String] {
        var references: [String] = []
        var remaining = text[...]

        while let start = remaining.range(of: "[[") {
            let afterStart = remaining[start.upperBound...]
            guard let end = afterStart.range(of: "]]") else {
                break
            }
            let title = afterStart[..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                references.append(title)
            }
            remaining = afterStart[end.upperBound...]
        }

        return references
    }
}
