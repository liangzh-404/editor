import Foundation

final class DiaryRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func activeEntry(workspaceID: String) throws -> DiaryEntrySnapshot {
        if let entry = try newestEntry(workspaceID: workspaceID) {
            return entry
        }

        let now = Self.timestamp()
        let entryID = "diary-\(UUID().uuidString.lowercased())"
        try database.execute(
            """
            INSERT INTO diary_entries (id, workspace_id, text_plain, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(entryID),
                .text(workspaceID),
                .text(""),
                .text(now),
                .text(now)
            ]
        )

        return DiaryEntrySnapshot(
            id: entryID,
            workspaceID: workspaceID,
            textPlain: ""
        )
    }

    func updateEntryText(entryID: String, text: String) throws {
        let now = Self.timestamp()
        try database.execute(
            """
            UPDATE diary_entries
            SET text_plain = ?,
                updated_at = ?
            WHERE id = ?
            """,
            bindings: [
                .text(text),
                .text(now),
                .text(entryID)
            ]
        )
        try SearchRepository(database: database).updateDiaryEntryIndex(entryID: entryID)
    }

    func promoteTextToPage(entryID: String, selectedText: String) throws -> PageSummary {
        let pageText = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pageText.isEmpty else {
            throw DiaryRepositoryError.emptySelection
        }

        let entry = try entry(entryID: entryID)
        let pageRepository = PageRepository(database: database)
        let page = try pageRepository.createPage(workspaceID: entry.workspaceID, title: pageText)
        let snapshot = try pageRepository.loadWorkspaceSnapshot()
        guard let block = snapshot.blocks.first(where: { $0.pageID == page.id }) else {
            throw PageRepositoryError.blockNotFound
        }

        try pageRepository.updateBlock(blockID: block.id, type: .paragraph, text: pageText)
        try database.execute(
            """
            INSERT OR REPLACE INTO page_origin (page_id, promoted_from_diary_entry_id, created_at)
            VALUES (?, ?, ?)
            """,
            bindings: [
                .text(page.id),
                .text(entryID),
                .text(Self.timestamp())
            ]
        )

        return page
    }

    private func newestEntry(workspaceID: String) throws -> DiaryEntrySnapshot? {
        try database.query(
            """
            SELECT id, workspace_id, text_plain
            FROM diary_entries
            WHERE workspace_id = ?
            ORDER BY updated_at DESC, created_at DESC
            LIMIT 1
            """,
            bindings: [.text(workspaceID)]
        ).first.map(Self.entrySnapshot(row:))
    }

    private func entry(entryID: String) throws -> DiaryEntrySnapshot {
        guard let entry = try database.query(
            """
            SELECT id, workspace_id, text_plain
            FROM diary_entries
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(entryID)]
        ).first.map(Self.entrySnapshot(row:)) else {
            throw DiaryRepositoryError.entryNotFound
        }

        return entry
    }

    private static func entrySnapshot(row: SQLiteRow) -> DiaryEntrySnapshot {
        DiaryEntrySnapshot(
            id: row["id"] ?? "",
            workspaceID: row["workspace_id"] ?? "",
            textPlain: row["text_plain"] ?? ""
        )
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}

enum DiaryRepositoryError: Error, Equatable {
    case emptySelection
    case entryNotFound
}
