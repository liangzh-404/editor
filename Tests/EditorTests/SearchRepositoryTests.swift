import Foundation
import XCTest

final class SearchRepositoryTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testSearchIndexesPageTitlesBlockTextAndAttachmentFilenames() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(blockID: blockID, text: "Alpha searchable block")
        let attachment = try AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        ).importAttachment(
            sourceURL: try makeSourceFile(name: "invoice-2026.pdf", contents: "pdf"),
            workspaceID: workspaceID,
            pageID: pageID
        ).attachment

        let repository = SearchRepository(database: database)
        try repository.rebuildIndex()

        XCTAssertTrue(try repository.search("欢迎").contains(SearchResult(entityType: "page", entityID: pageID, title: "欢迎", snippet: "欢迎", destinationPageID: pageID)))
        XCTAssertTrue(try repository.search("Alpha").contains(SearchResult(entityType: "block", entityID: blockID, title: "欢迎", snippet: "Alpha searchable block", destinationPageID: pageID)))
        XCTAssertTrue(try repository.search("invoice").contains(SearchResult(entityType: "attachment", entityID: attachment.id, title: "invoice-2026.pdf", snippet: "invoice-2026.pdf", destinationPageID: pageID)))
    }

    func testSearchRanksTitleMatchesBeforeBodyMatches() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let welcomeBlockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(
            blockID: welcomeBlockID,
            text: "Needle Needle Needle Needle appears repeatedly only in this block body"
        )
        let titledPage = try pageRepository.createPage(workspaceID: workspaceID, title: "Needle Project")

        let repository = SearchRepository(database: database)
        try repository.rebuildIndex()

        let results = try repository.search("Needle")

        XCTAssertEqual(results.first?.entityType, "page")
        XCTAssertEqual(results.first?.entityID, titledPage.id)
    }

    func testSearchSnippetUsesContextAroundMatch() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let longText = [
            "Opening context that should not dominate the search result",
            "middle words around FocusTerm should stay visible",
            "closing context that should be clipped away from the list row"
        ].joined(separator: " ")
        try pageRepository.updateBlockText(blockID: blockID, text: longText)

        let repository = SearchRepository(database: database)
        try repository.rebuildIndex()

        let result = try XCTUnwrap(try repository.search("FocusTerm").first)

        XCTAssertTrue(result.snippet.contains("FocusTerm"))
        XCTAssertLessThan(result.snippet.count, longText.count)
    }

    func testSearchFindsDailyDiaryContentAsNormalBlockResult() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let diaryRepository = DiaryRepository(database: database)
        let page = try diaryRepository.openDailyPage(
            workspaceID: workspaceID,
            date: Self.date(year: 2026, month: 5, day: 16),
            calendar: Self.gregorianCalendar
        )
        let dailyBlockID = try XCTUnwrap(
            try pageRepository.loadWorkspaceSnapshot()
                .blocks
                .first { $0.pageID == page.id }?
                .id
        )
        try pageRepository.updateBlockText(blockID: dailyBlockID, text: "Private searchable diary capture")

        let repository = SearchRepository(database: database)
        try repository.rebuildIndex()

        let results = try repository.search("private searchable")

        XCTAssertEqual(results.first?.entityType, "block")
        XCTAssertEqual(results.first?.entityID, dailyBlockID)
        XCTAssertEqual(results.first?.destinationPageID, page.id)
    }

    func testSearchFindsChineseSubstringInsideBlockText() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(blockID: blockID, text: "今天要赶紧处理搜索匹配")

        let repository = SearchRepository(database: database)
        try repository.rebuildIndex()

        let results = try repository.search("赶紧")

        XCTAssertEqual(results.first?.entityType, "block")
        XCTAssertEqual(results.first?.entityID, blockID)
        XCTAssertEqual(results.first?.destinationPageID, pageID)
        XCTAssertTrue(results.first?.snippet.contains("赶紧") == true)
    }

    func testSearchDoesNotReturnArchivedPageBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let archivedPage = try pageRepository.createPage(workspaceID: workspaceID, title: "Archived Search")
        let blockID = try XCTUnwrap(
            try pageRepository.loadWorkspaceSnapshot()
                .blocks
                .first { $0.pageID == archivedPage.id }?
                .id
        )
        try pageRepository.updateBlockText(blockID: blockID, text: "Archived hidden needle")
        try pageRepository.archivePage(pageID: archivedPage.id)

        let repository = SearchRepository(database: database)
        try repository.rebuildIndex()

        XCTAssertFalse(try repository.search("needle").contains { $0.destinationPageID == archivedPage.id })
    }

    func testRebuildIndexDoesNotExposeLegacyDiaryEntriesAfterDailyPageMigration() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let diaryRepository = DiaryRepository(database: database)
        let entry = try diaryRepository.activeEntry(workspaceID: workspaceID)
        try diaryRepository.updateEntryText(entryID: entry.id, text: "Rebuild diary searchable")
        let dailyPage = try diaryRepository.openDailyPage(
            workspaceID: workspaceID,
            date: Self.date(year: 2026, month: 5, day: 16),
            calendar: Self.gregorianCalendar
        )

        let repository = SearchRepository(database: database)
        try database.execute("DELETE FROM search_index")
        try repository.rebuildIndex()

        XCTAssertTrue(try repository.search("rebuild diary").contains { result in
            result.entityType == "block" && result.destinationPageID == dailyPage.id
        })
        XCTAssertFalse(try repository.search("rebuild diary").contains { $0.entityType == "diary" })
    }

    func testUpdateBlockIndexReplacesOnlyChangedBlockEntry() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(blockID: blockID, text: "Alpha searchable block")

        let repository = SearchRepository(database: database)
        try repository.rebuildIndex()
        XCTAssertTrue(try repository.search("Alpha").contains { $0.entityType == "block" && $0.entityID == blockID })

        try pageRepository.updateBlockText(blockID: blockID, text: "Beta searchable block")
        try repository.updateBlockIndex(blockID: blockID)

        XCTAssertFalse(try repository.search("Alpha").contains { $0.entityType == "block" && $0.entityID == blockID })
        XCTAssertTrue(try repository.search("Beta").contains { $0.entityType == "block" && $0.entityID == blockID })
    }

    func testEncryptedPagePlaintextRowsStayOutOfSearchIndex() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let cipher = SearchTestCipher()
        let pageRepository = PageRepository(database: database, encryptedNoteCipher: cipher)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let encryptedPage = try pageRepository.createPage(
            workspaceID: workspaceID,
            title: "Hidden Ledger",
            isEncrypted: true
        )
        let encryptedBlockID = try XCTUnwrap(
            try pageRepository.loadWorkspaceSnapshot()
                .blocks
                .first { $0.pageID == encryptedPage.id }?
                .id
        )
        try pageRepository.updateBlockText(blockID: encryptedBlockID, text: "secret launch phrase")
        let attachment = try AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory(),
            encryptedNoteCipher: cipher
        ).importAttachment(
            sourceURL: try makeSourceFile(name: "private-invoice.pdf", contents: "pdf"),
            workspaceID: workspaceID,
            pageID: encryptedPage.id
        ).attachment

        let rawPageTitle = try XCTUnwrap(
            try database.query("SELECT title FROM pages WHERE id = ? LIMIT 1", bindings: [.text(encryptedPage.id)]).first?["title"]
        )
        let rawBlockRows = try database.query(
            "SELECT text_plain, payload_json FROM blocks WHERE page_id = ? AND is_deleted = 0 ORDER BY order_key ASC",
            bindings: [.text(encryptedPage.id)]
        )
        XCTAssertEqual(rawPageTitle, "Hidden Ledger")
        XCTAssertTrue(rawBlockRows.contains { $0["text_plain"] == "secret launch phrase" })
        XCTAssertTrue(rawBlockRows.contains { $0["text_plain"] == "private-invoice.pdf" })
        XCTAssertTrue(rawBlockRows.allSatisfy { row in
            row["text_plain"]?.hasPrefix(EncryptedNoteCipher.ciphertextPrefix) == false
                && row["payload_json"]?.hasPrefix(EncryptedNoteCipher.ciphertextPrefix) == false
        })

        let repository = SearchRepository(database: database)
        try repository.rebuildIndex()

        XCTAssertEqual(try repository.search("Hidden Ledger"), [])
        XCTAssertEqual(try repository.search("secret launch"), [])
        XCTAssertFalse(try repository.search("private-invoice").contains { $0.entityID == attachment.id })
    }

    private func migratedDatabase() throws -> SQLiteDatabase {
        let database = try SQLiteDatabase.open(path: makeTemporaryDirectory().appendingPathComponent("editor.sqlite").path)
        try SchemaMigrator.migrate(database: database)
        return database
    }

    private static var gregorianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func date(year: Int, month: Int, day: Int) -> Date {
        gregorianCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeSourceFile(name: String, contents: String) throws -> URL {
        let directory = makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent(name)
        try contents.data(using: .utf8)?.write(to: fileURL)
        return fileURL
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        temporaryFiles.append(directory)
        return directory
    }

    private struct SearchTestCipher: EncryptedNoteCiphering {
        func encrypt(_ plaintext: String) throws -> String {
            guard !isCiphertext(plaintext) else {
                return plaintext
            }
            return EncryptedNoteCipher.ciphertextPrefix + Data(plaintext.utf8).base64EncodedString()
        }

        func decrypt(_ storedValue: String) throws -> String {
            guard isCiphertext(storedValue) else {
                return storedValue
            }
            let encoded = String(storedValue.dropFirst(EncryptedNoteCipher.ciphertextPrefix.count))
            guard let data = Data(base64Encoded: encoded),
                  let plaintext = String(data: data, encoding: .utf8) else {
                return storedValue
            }
            return plaintext
        }

        func isCiphertext(_ storedValue: String) -> Bool {
            storedValue.hasPrefix(EncryptedNoteCipher.ciphertextPrefix)
        }
    }
}
