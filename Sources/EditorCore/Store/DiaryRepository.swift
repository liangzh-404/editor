import Foundation

final class DiaryRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func openDailyPage(
        workspaceID: String,
        date: Date = Date(),
        calendar: Calendar = .current
    ) throws -> PageSummary {
        let diaryDate = Self.diaryDateString(from: date, calendar: calendar)
        if let page = try dailyPage(workspaceID: workspaceID, diaryDate: diaryDate) {
            try normalizeDailyPageBlocks(
                page,
                pageRepository: PageRepository(database: database)
            )
            return page
        }

        let title = Self.diaryTitle(from: date, calendar: calendar)
        let pageRepository = PageRepository(database: database)
        if let page = try pageMatchingTitle(workspaceID: workspaceID, title: title) {
            try recordDailyPageMapping(
                pageID: page.id,
                workspaceID: workspaceID,
                diaryDate: diaryDate
            )
            try normalizeDailyPageBlocks(page, pageRepository: pageRepository)
            return page
        }

        let page = try pageRepository.createPage(
            workspaceID: workspaceID,
            title: title
        )
        try recordDailyPageMapping(
            pageID: page.id,
            workspaceID: workspaceID,
            diaryDate: diaryDate
        )

        if let legacyText = try newestEntry(workspaceID: workspaceID)?.textPlain {
            try migrateLegacyText(
                legacyText,
                into: page,
                pageRepository: pageRepository
            )
        }

        return page
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

    private func dailyPage(workspaceID: String, diaryDate: String) throws -> PageSummary? {
        try database.query(
            """
            SELECT pages.id,
                   pages.workspace_id,
                   pages.notebook_id,
                   pages.title,
                   pages.is_favorite,
                   pages.updated_at
            FROM diary_pages
            INNER JOIN pages ON pages.id = diary_pages.page_id
            WHERE diary_pages.workspace_id = ?
              AND diary_pages.diary_date = ?
              AND pages.is_archived = 0
            LIMIT 1
            """,
            bindings: [
                .text(workspaceID),
                .text(diaryDate)
            ]
        ).first.map { row in
            PageSummary(
                id: row["id"] ?? "",
                workspaceID: row["workspace_id"] ?? "",
                notebookID: row["notebook_id"] ?? nil,
                title: row["title"] ?? "",
                isFavorite: Self.sqliteBool(row["is_favorite"]),
                updatedAt: row["updated_at"]
            )
        }
    }

    private func pageMatchingTitle(workspaceID: String, title: String) throws -> PageSummary? {
        try database.query(
            """
            SELECT id,
                   workspace_id,
                   notebook_id,
                   title,
                   is_favorite,
                   is_encrypted,
                   updated_at
            FROM pages
            WHERE workspace_id = ?
              AND title = ?
              AND is_archived = 0
            ORDER BY updated_at DESC, created_at DESC
            LIMIT 1
            """,
            bindings: [
                .text(workspaceID),
                .text(title)
            ]
        ).first.map { row in
            PageSummary(
                id: row["id"] ?? "",
                workspaceID: row["workspace_id"] ?? "",
                notebookID: row["notebook_id"] ?? nil,
                title: row["title"] ?? "",
                isFavorite: Self.sqliteBool(row["is_favorite"]),
                isEncrypted: Self.sqliteBool(row["is_encrypted"]),
                updatedAt: row["updated_at"]
            )
        }
    }

    private func recordDailyPageMapping(
        pageID: String,
        workspaceID: String,
        diaryDate: String
    ) throws {
        let now = Self.timestamp()
        try database.withImmediateTransaction("record_daily_page_mapping") {
            try database.execute(
                """
                DELETE FROM diary_pages
                WHERE (workspace_id = ? AND diary_date = ?)
                   OR page_id = ?
                """,
                bindings: [
                    .text(workspaceID),
                    .text(diaryDate),
                    .text(pageID)
                ]
            )
            try database.execute(
                """
                INSERT INTO diary_pages (page_id, workspace_id, diary_date, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(pageID),
                    .text(workspaceID),
                    .text(diaryDate),
                    .text(now),
                    .text(now)
                ]
            )
        }
        try SyncRepository(database: database).enqueue(
            entityType: "diaryPage",
            entityID: pageID,
            changeType: "create"
        )
    }

    private func normalizeDailyPageBlocks(
        _ page: PageSummary,
        pageRepository: PageRepository
    ) throws {
        let blocks = try pageRepository.loadWorkspaceSnapshot()
            .blocks
            .filter { $0.pageID == page.id }
        guard blocks.count == 1,
              let block = blocks.first,
              block.type == .paragraph,
              block.textPlain.contains("\n") else {
            return
        }

        try splitText(block.textPlain, firstBlockID: block.id, pageID: page.id, pageRepository: pageRepository)
    }

    private func migrateLegacyText(
        _ legacyText: String,
        into page: PageSummary,
        pageRepository: PageRepository
    ) throws {
        let lines = legacyText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty,
              let initialBlock = try pageRepository.loadWorkspaceSnapshot()
                .blocks
                .first(where: { $0.pageID == page.id }) else {
            return
        }

        try splitText(legacyText, firstBlockID: initialBlock.id, pageID: page.id, pageRepository: pageRepository)
    }

    private func splitText(
        _ text: String,
        firstBlockID: String,
        pageID: String,
        pageRepository: PageRepository
    ) throws {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let firstLine = lines.first else {
            return
        }

        try pageRepository.updateBlockText(blockID: firstBlockID, text: firstLine)
        for line in lines.dropFirst() {
            _ = try pageRepository.appendBlock(
                pageID: pageID,
                type: .paragraph,
                text: line
            )
        }
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

    private static func diaryDateString(from date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func diaryTitle(from date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: date)
    }

    private static func sqliteBool(_ value: String?) -> Bool {
        value == "1" || value == "true"
    }
}

enum DiaryRepositoryError: Error, Equatable {
    case emptySelection
    case entryNotFound
}
