import Foundation

enum SearchMatchKind: String, Equatable, Sendable {
    case exact
    case fullText
    case fuzzy
    case semantic
}

struct SearchSemanticCandidate: Equatable, Sendable {
    let entityType: String
    let entityID: String
    let score: Double
    let snippet: String?

    init(
        entityType: String,
        entityID: String,
        score: Double,
        snippet: String? = nil
    ) {
        self.entityType = entityType
        self.entityID = entityID
        self.score = score
        self.snippet = snippet
    }
}

protocol SearchSemanticProvider: Sendable {
    func candidates(for query: String, limit: Int) throws -> [SearchSemanticCandidate]
}

struct SearchResultHighlightRect: Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(boundingBox: AttachmentRecognizedTextBoundingBox) {
        self.init(
            x: boundingBox.x,
            y: boundingBox.y,
            width: boundingBox.width,
            height: boundingBox.height
        )
    }
}

struct SearchResultHighlight: Equatable, Sendable {
    let blockID: String
    let attachmentID: String?
    let rects: [SearchResultHighlightRect]
}

struct SearchResult: Identifiable, Equatable, Sendable {
    let entityType: String
    let entityID: String
    let title: String
    let snippet: String
    let destinationPageID: String?
    let destinationBlockID: String?
    let matchKind: SearchMatchKind
    let highlight: SearchResultHighlight?

    init(
        entityType: String,
        entityID: String,
        title: String,
        snippet: String,
        destinationPageID: String? = nil,
        destinationBlockID: String? = nil,
        highlight: SearchResultHighlight? = nil,
        matchKind: SearchMatchKind = .exact
    ) {
        self.entityType = entityType
        self.entityID = entityID
        self.title = title
        self.snippet = snippet
        self.destinationPageID = destinationPageID
        self.destinationBlockID = destinationBlockID
        self.highlight = highlight
        self.matchKind = matchKind
    }

    var id: String {
        "\(entityType):\(entityID)"
    }

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.entityType == rhs.entityType
            && lhs.entityID == rhs.entityID
            && lhs.title == rhs.title
            && lhs.snippet == rhs.snippet
            && lhs.destinationPageID == rhs.destinationPageID
    }
}

final class SearchRepository: @unchecked Sendable {
    private let database: SQLiteDatabase
    private let semanticProvider: SearchSemanticProvider?
    private static let fuzzyCandidateLimit = 420
    private let ocrRegionDecoder = JSONDecoder()

    private struct SearchDestination {
        let pageID: String
        let blockID: String?
        let highlight: SearchResultHighlight?
    }

    init(database: SQLiteDatabase, semanticProvider: SearchSemanticProvider? = nil) {
        self.database = database
        self.semanticProvider = semanticProvider
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
                  AND pages.is_archived = 0
                  AND pages.is_encrypted = 0
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

    func updateAttachmentIndex(attachmentID: String) throws {
        try database.withImmediateTransaction("search_index_attachment_update") {
            try deleteIndex(entityType: "attachment", entityID: attachmentID)
            for attachment in try attachmentIndexRows(attachmentID: attachmentID) {
                try insertAttachmentIndex(attachment)
            }
        }

        EditorLog.render.debug("search_index_attachment_updated attachment_id=\(attachmentID, privacy: .public)")
    }

    func updateDiaryEntryIndex(entryID: String) throws {
        try database.withImmediateTransaction("search_index_diary_update") {
            try deleteIndex(entityType: "diary", entityID: entryID)
        }

        EditorLog.render.debug("search_index_diary_updated entry_id=\(entryID, privacy: .public)")
    }

    func search(_ query: String, limit: Int = 20) throws -> [SearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, limit > 0 else {
            return []
        }

        let tokens = searchTokens(for: query)
        var results: [SearchResult] = []
        var seenIDs: Set<String> = []

        try appendRows(
            exactSearchRows(query: trimmedQuery, limit: limit),
            matchKind: .exact,
            query: trimmedQuery,
            to: &results,
            seenIDs: &seenIDs,
            limit: limit
        )

        if let ftsQuery = ftsQuery(for: tokens), results.count < limit {
            try appendRows(
                fullTextSearchRows(ftsQuery: ftsQuery, titlePattern: titlePriorityPattern(for: tokens), limit: limit),
                matchKind: .fullText,
                query: trimmedQuery,
                to: &results,
                seenIDs: &seenIDs,
                limit: limit
            )
        }

        if results.count < limit {
            try appendRows(
                fuzzySearchRows(query: trimmedQuery, excluding: seenIDs, limit: max(0, limit - results.count)),
                matchKind: .fuzzy,
                query: trimmedQuery,
                to: &results,
                seenIDs: &seenIDs,
                limit: limit
            )
        }

        if results.count < limit {
            try appendSemanticCandidates(
                semanticProvider?.candidates(for: trimmedQuery, limit: max(0, limit - results.count)) ?? [],
                query: trimmedQuery,
                to: &results,
                seenIDs: &seenIDs,
                limit: limit
            )
        }

        return results
    }

    private func appendRows(
        _ rows: [SQLiteRow],
        matchKind: SearchMatchKind,
        query: String,
        to results: inout [SearchResult],
        seenIDs: inout Set<String>,
        limit: Int
    ) throws {
        for row in rows {
            guard results.count < limit else {
                return
            }
            let entityType = row["entity_type"] ?? ""
            let entityID = row["entity_id"] ?? ""
            let id = "\(entityType):\(entityID)"
            guard !seenIDs.contains(id) else {
                continue
            }

            guard let destination = try searchDestination(
                entityType: entityType,
                entityID: entityID,
                query: query
            ) else {
                continue
            }
            seenIDs.insert(id)
            results.append(
                SearchResult(
                    entityType: entityType,
                    entityID: entityID,
                    title: row["title"] ?? "",
                    snippet: row["snippet"] ?? row["body"] ?? row["title"] ?? "",
                    destinationPageID: destination.pageID,
                    destinationBlockID: destination.blockID,
                    highlight: destination.highlight,
                    matchKind: matchKind
                )
            )
        }
    }

    private func appendSemanticCandidates(
        _ candidates: [SearchSemanticCandidate],
        query: String,
        to results: inout [SearchResult],
        seenIDs: inout Set<String>,
        limit: Int
    ) throws {
        for candidate in candidates.sorted(by: { $0.score > $1.score }) {
            guard results.count < limit else {
                return
            }
            let id = "\(candidate.entityType):\(candidate.entityID)"
            guard !seenIDs.contains(id) else {
                continue
            }
            guard let row = try indexRow(entityType: candidate.entityType, entityID: candidate.entityID) else {
                continue
            }
            guard let destination = try searchDestination(
                entityType: candidate.entityType,
                entityID: candidate.entityID,
                query: query
            ) else {
                continue
            }
            seenIDs.insert(id)
            results.append(
                SearchResult(
                    entityType: candidate.entityType,
                    entityID: candidate.entityID,
                    title: row["title"] ?? "",
                    snippet: candidate.snippet ?? row["body"] ?? row["title"] ?? "",
                    destinationPageID: destination.pageID,
                    destinationBlockID: destination.blockID,
                    highlight: destination.highlight,
                    matchKind: .semantic
                )
            )
        }
    }

    private func indexRow(entityType: String, entityID: String) throws -> SQLiteRow? {
        try database.query(
            """
            SELECT entity_type,
                   entity_id,
                   title,
                   body
            FROM search_index
            WHERE entity_type = ?
              AND entity_id = ?
            LIMIT 1
            """,
            bindings: [.text(entityType), .text(entityID)]
        ).first
    }

    private func searchDestination(
        entityType: String,
        entityID: String,
        query: String
    ) throws -> SearchDestination? {
        switch entityType {
        case "page":
            return SearchDestination(pageID: entityID, blockID: nil, highlight: nil)
        case "block":
            guard let pageID = try database.query(
                """
                SELECT page_id
                FROM blocks
                WHERE id = ? AND is_deleted = 0
                LIMIT 1
                """,
                bindings: [.text(entityID)]
            ).first?["page_id"] ?? nil else {
                return nil
            }
            return SearchDestination(pageID: pageID, blockID: entityID, highlight: nil)
        case "attachment":
            guard let row = try database.query(
                """
                SELECT blocks.id AS block_id,
                       blocks.page_id AS page_id
                FROM blocks
                INNER JOIN pages ON pages.id = blocks.page_id
                WHERE blocks.is_deleted = 0
                  AND pages.is_archived = 0
                  AND pages.is_encrypted = 0
                  AND json_valid(blocks.payload_json)
                  AND json_extract(blocks.payload_json, '$.attachment_id') = ?
                LIMIT 1
                """,
                bindings: [.text(entityID)]
            ).first else {
                return nil
            }
            let blockID = row["block_id"] ?? ""
            guard let pageID = row["page_id"] ?? nil, !blockID.isEmpty else {
                return nil
            }
            return SearchDestination(
                pageID: pageID,
                blockID: blockID,
                highlight: try attachmentHighlight(
                    attachmentID: entityID,
                    blockID: blockID,
                    query: query
                )
            )
        default:
            return nil
        }
    }

    private func attachmentHighlight(
        attachmentID: String,
        blockID: String,
        query: String
    ) throws -> SearchResultHighlight? {
        guard let regionsJSON = try database.query(
            """
            SELECT regions_json
            FROM attachment_text_recognition
            WHERE attachment_id = ?
            LIMIT 1
            """,
            bindings: [.text(attachmentID)]
        ).first?["regions_json"] ?? nil,
              let data = regionsJSON.data(using: .utf8),
              let observations = try? ocrRegionDecoder.decode([AttachmentRecognizedTextObservation].self, from: data) else {
            return nil
        }

        let matchingRects = observations
            .filter { observationMatchesQuery($0.text, query: query) }
            .map { SearchResultHighlightRect(boundingBox: $0.boundingBox) }

        guard !matchingRects.isEmpty else {
            return nil
        }

        return SearchResultHighlight(
            blockID: blockID,
            attachmentID: attachmentID,
            rects: matchingRects
        )
    }

    private func observationMatchesQuery(_ text: String, query: String) -> Bool {
        let normalizedText = text.lowercased()
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if !normalizedQuery.isEmpty, normalizedText.contains(normalizedQuery) {
            return true
        }

        return searchTokens(for: query).contains { token in
            normalizedText.contains(token.lowercased())
        }
    }

    private func indexPages() throws {
        let pages = try database.query(
            """
            SELECT id, title
            FROM pages
            WHERE is_archived = 0
              AND is_encrypted = 0
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
              AND pages.is_archived = 0
              AND pages.is_encrypted = 0
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
        for attachment in try attachmentIndexRows() {
            try insertAttachmentIndex(attachment)
        }
    }

    private func attachmentIndexRows(attachmentID: String? = nil) throws -> [SQLiteRow] {
        let attachmentFilter = attachmentID == nil ? "" : "AND attachments.id = ?"
        return try database.query(
            """
            SELECT attachments.id AS id,
                   attachments.original_filename AS original_filename,
                   COALESCE(attachment_text_recognition.recognized_text, '') AS recognized_text
            FROM attachments
            LEFT JOIN attachment_text_recognition
              ON attachment_text_recognition.attachment_id = attachments.id
             AND attachment_text_recognition.content_hash = attachments.content_hash
            WHERE EXISTS (
                SELECT 1
                FROM blocks
                INNER JOIN pages ON pages.id = blocks.page_id
                WHERE blocks.is_deleted = 0
                  AND pages.is_archived = 0
                  AND pages.is_encrypted = 0
                  AND json_valid(blocks.payload_json)
                  AND json_extract(blocks.payload_json, '$.attachment_id') = attachments.id
            )
            \(attachmentFilter)
            """
            ,
            bindings: attachmentID.map { [.text($0)] } ?? []
        )
    }

    private func insertAttachmentIndex(_ attachment: SQLiteRow) throws {
        let filename = attachment["original_filename"] ?? ""
        let recognizedText = attachment["recognized_text"] ?? ""
        try insertIndex(
            entityType: "attachment",
            entityID: attachment["id"] ?? "",
            title: filename,
            body: [filename, recognizedText]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n")
        )
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

    private func exactSearchRows(query: String, limit: Int) throws -> [SQLiteRow] {
        let normalizedQuery = query.lowercased()
        let containsPattern = likePattern(for: query)
        let prefixPattern = likePrefixPattern(for: query)
        return try database.query(
            """
            SELECT entity_type,
                   entity_id,
                   title,
                   CASE
                       WHEN lower(body) LIKE ? ESCAPE '\\' THEN
                           CASE
                               WHEN instr(lower(body), ?) > 0 THEN substr(body, max(1, instr(lower(body), ?) - 40), 96)
                               ELSE body
                           END
                       ELSE title
                   END AS snippet
            FROM search_index
            WHERE lower(title) = ?
               OR lower(title) LIKE ? ESCAPE '\\'
               OR lower(body) LIKE ? ESCAPE '\\'
            ORDER BY CASE
                         WHEN lower(title) = ? THEN 0
                         WHEN lower(title) LIKE ? ESCAPE '\\' THEN 1
                         WHEN lower(title) LIKE ? ESCAPE '\\' THEN 2
                         ELSE 3
                     END ASC,
                     length(title) ASC,
                     title ASC
            LIMIT ?
            """,
            bindings: [
                .text(containsPattern),
                .text(normalizedQuery),
                .text(normalizedQuery),
                .text(normalizedQuery),
                .text(prefixPattern),
                .text(containsPattern),
                .text(normalizedQuery),
                .text(prefixPattern),
                .text(containsPattern),
                .integer(limit)
            ]
        )
    }

    private func fullTextSearchRows(
        ftsQuery: String,
        titlePattern: String,
        limit: Int
    ) throws -> [SQLiteRow] {
        try database.query(
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
                .text(titlePattern),
                .integer(limit)
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

    private func fuzzySearchRows(
        query: String,
        excluding existingIDs: Set<String>,
        limit: Int
    ) throws -> [SQLiteRow] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, limit > 0 else {
            return []
        }

        let pattern = likePattern(for: trimmedQuery)
        let fuzzyNeedle = fuzzyCandidateNeedle(for: trimmedQuery)
        let fuzzyPattern = fuzzyNeedle.map(likePattern(for:)) ?? pattern
        let rows = try database.query(
            """
            SELECT entity_type,
                   entity_id,
                   title,
                   body,
                   CASE
                       WHEN lower(body) LIKE ? ESCAPE '\\' THEN body
                       ELSE title
                   END AS snippet
            FROM search_index
            WHERE lower(title) LIKE ? ESCAPE '\\'
               OR lower(body) LIKE ? ESCAPE '\\'
               OR lower(title) LIKE ? ESCAPE '\\'
               OR lower(body) LIKE ? ESCAPE '\\'
            ORDER BY CASE
                         WHEN lower(title) LIKE ? ESCAPE '\\' THEN 0
                         ELSE 1
                     END ASC,
                     title ASC
            LIMIT ?
            """,
            bindings: [
                .text(pattern),
                .text(pattern),
                .text(pattern),
                .text(fuzzyPattern),
                .text(fuzzyPattern),
                .text(pattern),
                .integer(Self.fuzzyCandidateLimit)
            ]
        )

        var filteredRows: [SQLiteRow] = []
        for row in rows {
            let id = "\(row["entity_type"] ?? ""):\(row["entity_id"] ?? "")"
            guard !existingIDs.contains(id) else {
                continue
            }
            guard rowMatchesFuzzyQuery(row, query: trimmedQuery) else {
                continue
            }

            filteredRows.append(row)
            if filteredRows.count == limit {
                break
            }
        }
        return filteredRows
    }

    private func rowMatchesFuzzyQuery(_ row: SQLiteRow, query: String) -> Bool {
        let normalizedQuery = normalizeForFuzzy(query)
        guard normalizedQuery.count >= 3 else {
            return false
        }
        let maxDistance = max(1, min(3, normalizedQuery.count / 4))
        let searchableText = [row["title"], row["body"]]
            .compactMap { $0 }
            .joined(separator: " ")
        return fuzzyTokens(in: searchableText).contains { token in
            abs(token.count - normalizedQuery.count) <= maxDistance
                && levenshteinDistance(token, normalizedQuery, maximum: maxDistance) <= maxDistance
        }
    }

    private func fuzzyTokens(in text: String) -> [String] {
        text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    private func normalizeForFuzzy(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func fuzzyCandidateNeedle(for query: String) -> String? {
        let normalized = normalizeForFuzzy(query)
        guard normalized.count >= 2 else {
            return nil
        }
        return String(normalized.prefix(2))
    }

    private func levenshteinDistance(_ lhs: String, _ rhs: String, maximum: Int) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        guard abs(left.count - right.count) <= maximum else {
            return maximum + 1
        }
        var previous = Array(0...right.count)
        var current = Array(repeating: 0, count: right.count + 1)

        for leftIndex in 1...left.count {
            current[0] = leftIndex
            var rowMinimum = current[0]
            for rightIndex in 1...right.count {
                let substitutionCost = left[leftIndex - 1] == right[rightIndex - 1] ? 0 : 1
                current[rightIndex] = min(
                    previous[rightIndex] + 1,
                    current[rightIndex - 1] + 1,
                    previous[rightIndex - 1] + substitutionCost
                )
                rowMinimum = min(rowMinimum, current[rightIndex])
            }
            if rowMinimum > maximum {
                return maximum + 1
            }
            swap(&previous, &current)
        }
        return previous[right.count]
    }

    private func likePattern(for query: String) -> String {
        let escaped = query
            .lowercased()
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return "%\(escaped)%"
    }

    private func likePrefixPattern(for query: String) -> String {
        let escaped = query
            .lowercased()
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return "\(escaped)%"
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

final class LocalSemanticSearchProvider: SearchSemanticProvider, @unchecked Sendable {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func candidates(for query: String, limit: Int) throws -> [SearchSemanticCandidate] {
        let relatedTerms = Self.relatedTerms(for: query)
        guard !relatedTerms.isEmpty, limit > 0 else {
            return []
        }

        var candidates: [SearchSemanticCandidate] = []
        var seenIDs: Set<String> = []
        for term in relatedTerms {
            let rows = try semanticRows(for: term, limit: max(0, limit - candidates.count))
            for row in rows {
                let entityType = row["entity_type"] ?? ""
                let entityID = row["entity_id"] ?? ""
                let id = "\(entityType):\(entityID)"
                guard !seenIDs.contains(id) else {
                    continue
                }
                seenIDs.insert(id)
                candidates.append(
                    SearchSemanticCandidate(
                        entityType: entityType,
                        entityID: entityID,
                        score: Self.score(for: term, title: row["title"] ?? "", body: row["body"] ?? ""),
                        snippet: row["body"] ?? row["title"]
                    )
                )
                if candidates.count == limit {
                    return candidates
                }
            }
        }
        return candidates
    }

    private func semanticRows(for term: String, limit: Int) throws -> [SQLiteRow] {
        guard limit > 0 else {
            return []
        }
        let pattern = Self.likePattern(for: term)
        return try database.query(
            """
            SELECT entity_type,
                   entity_id,
                   title,
                   body
            FROM search_index
            WHERE lower(title) LIKE ? ESCAPE '\\'
               OR lower(body) LIKE ? ESCAPE '\\'
            ORDER BY CASE
                         WHEN lower(title) LIKE ? ESCAPE '\\' THEN 0
                         ELSE 1
                     END ASC,
                     length(title) ASC
            LIMIT ?
            """,
            bindings: [
                .text(pattern),
                .text(pattern),
                .text(pattern),
                .integer(limit)
            ]
        )
    }

    private static func relatedTerms(for query: String) -> [String] {
        let normalized = query
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let groups = [
            ["car", "vehicle", "automobile", "auto"],
            ["task", "todo", "action", "待办", "任务"],
            ["meeting", "sync", "discussion", "会议", "沟通"],
            ["search", "find", "lookup", "检索", "搜索", "查找"],
            ["plan", "roadmap", "strategy", "计划", "规划"],
            ["note", "document", "page", "笔记", "文档"]
        ]

        guard let group = groups.first(where: { $0.contains(normalized) }) else {
            return []
        }
        return group.filter { $0 != normalized }
    }

    private static func score(for term: String, title: String, body: String) -> Double {
        let normalizedTerm = term.lowercased()
        if title.lowercased().contains(normalizedTerm) {
            return 0.72
        }
        if body.lowercased().contains(normalizedTerm) {
            return 0.62
        }
        return 0.5
    }

    private static func likePattern(for query: String) -> String {
        let escaped = query
            .lowercased()
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return "%\(escaped)%"
    }
}
