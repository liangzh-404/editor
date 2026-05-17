import XCTest

final class DiaryRepositoryTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testOpenDailyDiaryPageCreatesNormalPageOnceAndAppearsInDocuments() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let repository = DiaryRepository(database: database)
        let date = try XCTUnwrap(Self.date(year: 2026, month: 5, day: 16))

        let page = try repository.openDailyPage(workspaceID: workspaceID, date: date, calendar: Self.calendar)
        let samePage = try repository.openDailyPage(workspaceID: workspaceID, date: date, calendar: Self.calendar)
        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()
        let pageBlocks = reloadedSnapshot.blocks.filter { $0.pageID == page.id }

        XCTAssertEqual(page.id, samePage.id)
        XCTAssertEqual(page.title, "2026年5月16日 星期六")
        XCTAssertTrue(reloadedSnapshot.pages.contains { $0.id == page.id })
        XCTAssertEqual(pageBlocks.count, 1)
        XCTAssertEqual(pageBlocks.first?.type, .paragraph)
        XCTAssertEqual(pageBlocks.first?.textPlain, "")
    }

    func testOpenDailyDiaryPageCreatesSeparatePageForDifferentDate() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let repository = DiaryRepository(database: database)
        let firstDate = try XCTUnwrap(Self.date(year: 2026, month: 5, day: 16))
        let secondDate = try XCTUnwrap(Self.date(year: 2026, month: 5, day: 17))

        let firstPage = try repository.openDailyPage(workspaceID: workspaceID, date: firstDate, calendar: Self.calendar)
        let secondPage = try repository.openDailyPage(workspaceID: workspaceID, date: secondDate, calendar: Self.calendar)
        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()

        XCTAssertNotEqual(firstPage.id, secondPage.id)
        XCTAssertEqual(firstPage.title, "2026年5月16日 星期六")
        XCTAssertEqual(secondPage.title, "2026年5月17日 星期日")
        XCTAssertTrue(reloadedSnapshot.pages.contains { $0.id == firstPage.id })
        XCTAssertTrue(reloadedSnapshot.pages.contains { $0.id == secondPage.id })
    }

    func testLegacyDiaryEntryMigratesNonEmptyLinesIntoSeparateDailyPageBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let diaryRepository = DiaryRepository(database: database)
        let entry = try diaryRepository.activeEntry(workspaceID: workspaceID)
        try diaryRepository.updateEntryText(entryID: entry.id, text: "旧日记内容\n\n第二条\n第三条")
        let date = try XCTUnwrap(Self.date(year: 2026, month: 5, day: 16))

        let page = try diaryRepository.openDailyPage(workspaceID: workspaceID, date: date, calendar: Self.calendar)
        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()
        let blocks = reloadedSnapshot.blocks.filter { $0.pageID == page.id }

        XCTAssertEqual(page.title, "2026年5月16日 星期六")
        XCTAssertEqual(blocks.map(\.textPlain), ["旧日记内容", "第二条", "第三条"])
        XCTAssertTrue(reloadedSnapshot.pages.contains { $0.id == page.id })
    }

    func testOpeningExistingDailyPageSplitsSingleMultilineParagraphIntoBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let diaryRepository = DiaryRepository(database: database)
        let date = try XCTUnwrap(Self.date(year: 2026, month: 5, day: 16))
        let page = try diaryRepository.openDailyPage(workspaceID: workspaceID, date: date, calendar: Self.calendar)
        let initialBlock = try XCTUnwrap(
            try pageRepository.loadWorkspaceSnapshot()
                .blocks
                .first { $0.pageID == page.id }
        )
        try pageRepository.updateBlockText(blockID: initialBlock.id, text: "第一条\n第二条\n第三条")

        _ = try diaryRepository.openDailyPage(workspaceID: workspaceID, date: date, calendar: Self.calendar)
        let blocks = try pageRepository.loadWorkspaceSnapshot()
            .blocks
            .filter { $0.pageID == page.id }

        XCTAssertEqual(blocks.map(\.textPlain), ["第一条", "第二条", "第三条"])
    }

    private func migratedDatabase() throws -> SQLiteDatabase {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        try SchemaMigrator.migrate(database: database)
        return database
    }

    private func temporaryDatabasePath() -> String {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryFiles.append(directory)
        return directory.appendingPathComponent("editor.sqlite").path
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func date(year: Int, month: Int, day: Int) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}
