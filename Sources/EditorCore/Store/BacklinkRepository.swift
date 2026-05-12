import Foundation

struct Backlink: Identifiable, Equatable, Sendable {
    let sourcePageID: String
    let sourcePageTitle: String
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

struct ExternalLink: Identifiable, Equatable, Sendable {
    let sourcePageID: String
    let sourcePageTitle: String
    let sourceBlockID: String?
    let targetURL: String
    let linkText: String

    var id: String {
        [
            sourcePageID,
            sourceBlockID ?? "",
            targetURL,
            linkText
        ].joined(separator: ":")
    }

    var destinationURL: URL? {
        guard let url = URL(string: targetURL),
              let scheme = url.scheme,
              !scheme.isEmpty else {
            return nil
        }

        return url
    }
}

final class BacklinkRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func rebuildLinksForBlock(
        blockID: String,
        text: String,
        pageReferenceTargetPageID: String? = nil,
        blockReferenceTargetBlockID: String? = nil
    ) throws {
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

        if let pageReferenceTargetPageID {
            try insertLink(
                sourcePageID: sourcePageID,
                sourceBlockID: blockID,
                targetPageID: pageReferenceTargetPageID,
                targetBlockID: blockReferenceTargetBlockID,
                targetURL: nil,
                linkText: text
            )
            return
        }

        for linkText in Self.pageReferenceTexts(in: text) {
            let targetPageID = try targetPageID(forTitle: linkText)
            try insertLink(
                sourcePageID: sourcePageID,
                sourceBlockID: blockID,
                targetPageID: targetPageID,
                targetBlockID: nil,
                targetURL: nil,
                linkText: linkText
            )
        }

        for externalLink in Self.externalMarkdownLinks(in: text) {
            try insertLink(
                sourcePageID: sourcePageID,
                sourceBlockID: blockID,
                targetPageID: nil,
                targetBlockID: nil,
                targetURL: externalLink.url,
                linkText: externalLink.text
            )
        }
    }

    func backlinks(targetPageID: String) throws -> [Backlink] {
        try database.query(
            """
            SELECT source_page_id,
                   source_pages.title AS source_page_title,
                   source_block_id,
                   target_page_id,
                   target_block_id,
                   link_text
            FROM links
            INNER JOIN pages AS source_pages ON source_pages.id = links.source_page_id
            WHERE target_page_id = ?
            ORDER BY links.created_at ASC
            """,
            bindings: [.text(targetPageID)]
        ).map { row in
            Backlink(
                sourcePageID: row["source_page_id"] ?? "",
                sourcePageTitle: row["source_page_title"] ?? "",
                sourceBlockID: row["source_block_id"] ?? nil,
                targetPageID: row["target_page_id"] ?? nil,
                targetBlockID: row["target_block_id"] ?? nil,
                linkText: row["link_text"] ?? ""
            )
        }
    }

    func externalLinks(sourcePageID: String) throws -> [ExternalLink] {
        try database.query(
            """
            SELECT source_page_id,
                   source_pages.title AS source_page_title,
                   source_block_id,
                   target_url,
                   link_text
            FROM links
            INNER JOIN pages AS source_pages ON source_pages.id = links.source_page_id
            WHERE source_page_id = ? AND target_url IS NOT NULL
            ORDER BY links.created_at ASC
            """,
            bindings: [.text(sourcePageID)]
        ).compactMap { row in
            guard let targetURL = row["target_url"], !targetURL.isEmpty else {
                return nil
            }

            return ExternalLink(
                sourcePageID: row["source_page_id"] ?? "",
                sourcePageTitle: row["source_page_title"] ?? "",
                sourceBlockID: row["source_block_id"] ?? nil,
                targetURL: targetURL,
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

    private func insertLink(
        sourcePageID: String,
        sourceBlockID: String,
        targetPageID: String?,
        targetBlockID: String?,
        targetURL: String?,
        linkText: String
    ) throws {
        try database.execute(
            """
            INSERT INTO links (
                id,
                source_page_id,
                source_block_id,
                target_page_id,
                target_block_id,
                target_url,
                link_text,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text("link-\(UUID().uuidString.lowercased())"),
                .text(sourcePageID),
                .text(sourceBlockID),
                targetPageID.map(SQLiteValue.text) ?? .null,
                targetBlockID.map(SQLiteValue.text) ?? .null,
                targetURL.map(SQLiteValue.text) ?? .null,
                .text(linkText),
                .text(ISO8601DateFormatter().string(from: Date()))
            ]
        )
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

    static func externalMarkdownLinks(in text: String) -> [(text: String, url: String)] {
        var links: [(text: String, url: String)] = []
        var remaining = text[...]

        while let labelStart = remaining.range(of: "[") {
            guard labelStart.lowerBound == remaining.startIndex || remaining[remaining.index(before: labelStart.lowerBound)] != "!" else {
                remaining = remaining[labelStart.upperBound...]
                continue
            }

            let afterLabelStart = remaining[labelStart.upperBound...]
            guard let labelEnd = afterLabelStart.range(of: "]"),
                  labelEnd.upperBound < remaining.endIndex,
                  remaining[labelEnd.upperBound] == "(" else {
                remaining = afterLabelStart
                continue
            }

            let afterURLStartIndex = remaining.index(after: labelEnd.upperBound)
            let afterURLStart = remaining[afterURLStartIndex...]
            guard let urlEnd = afterURLStart.range(of: ")") else {
                break
            }

            let label = afterLabelStart[..<labelEnd.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let url = afterURLStart[..<urlEnd.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            if !label.isEmpty, Self.isExternalURL(url) {
                links.append((text: label, url: url))
            }
            remaining = afterURLStart[urlEnd.upperBound...]
        }

        return links
    }

    private static func isExternalURL(_ url: String) -> Bool {
        guard !url.isEmpty,
              let schemeEnd = url.firstIndex(of: ":"),
              schemeEnd > url.startIndex else {
            return false
        }

        return url[..<schemeEnd].allSatisfy { character in
            character.isLetter || character.isNumber || character == "+" || character == "-" || character == "."
        }
    }
}
