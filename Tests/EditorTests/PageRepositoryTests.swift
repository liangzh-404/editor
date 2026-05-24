import Foundation
import XCTest

final class PageRepositoryTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testBootstrapCreatesDefaultWorkspacePageAndParagraphBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()

        XCTAssertEqual(snapshot.workspaces.map(\.name), ["本地"])
        XCTAssertEqual(snapshot.notebooks.map(\.name), ["笔记本"])
        XCTAssertEqual(snapshot.pages.map(\.title), ["欢迎"])
        XCTAssertEqual(snapshot.pages.first?.notebookID, snapshot.notebooks.first?.id)
        XCTAssertEqual(snapshot.blocks.count, 1)
        XCTAssertEqual(snapshot.blocks.first?.type, .paragraph)
        XCTAssertEqual(snapshot.blocks.first?.textPlain, "开始用块写作。")
        XCTAssertEqual(snapshot.selectedWorkspaceID, snapshot.workspaces.first?.id)
        XCTAssertEqual(snapshot.selectedPageID, snapshot.pages.first?.id)
    }

    func testBootstrapIsIdempotent() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        _ = try repository.bootstrapWorkspaceIfNeeded()
        _ = try repository.bootstrapWorkspaceIfNeeded()
        let snapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(snapshot.workspaces.count, 1)
        XCTAssertEqual(snapshot.pages.count, 1)
        XCTAssertEqual(snapshot.blocks.count, 1)
    }

    func testUpdateBlockTextPersistsParagraphContent() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(initialSnapshot.blocks.first?.id)

        try repository.updateBlockText(blockID: blockID, text: "Edited locally")
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.blocks.first?.textPlain, "Edited locally")
    }

    func testUpdateBlockTextWithSameContentDoesNotMarkBlockDirty() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let block = try XCTUnwrap(initialSnapshot.blocks.first)
        let initialRow = try XCTUnwrap(
            try database.query(
                "SELECT revision, updated_at, sync_state FROM blocks WHERE id = ? LIMIT 1",
                bindings: [.text(block.id)]
            ).first
        )

        try repository.updateBlockText(blockID: block.id, text: block.textPlain)

        let finalRow = try XCTUnwrap(
            try database.query(
                "SELECT revision, updated_at, sync_state FROM blocks WHERE id = ? LIMIT 1",
                bindings: [.text(block.id)]
            ).first
        )
        XCTAssertEqual(finalRow["revision"], initialRow["revision"])
        XCTAssertEqual(finalRow["updated_at"], initialRow["updated_at"])
        XCTAssertEqual(finalRow["sync_state"], initialRow["sync_state"])
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges(), [])
    }

    func testTableBlockPersistsStructuredRowsInPayload() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(initialSnapshot.blocks.first?.id)

        try repository.updateBlock(
            blockID: blockID,
            type: .table,
            text:
                """
                | Name | Status |
                | --- | --- |
                | Editor | Draft |
                """
        )

        let payloadJSON = try XCTUnwrap(
            try database.query(
                "SELECT payload_json FROM blocks WHERE id = ? LIMIT 1",
                bindings: [.text(blockID)]
            ).first?["payload_json"]
        )
        let payload = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(payloadJSON.utf8)) as? [String: Any]
        )

        XCTAssertEqual(payload["rows"] as? [[String]], [["Name", "Status"], ["Editor", "Draft"]])

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        XCTAssertEqual(reloadedSnapshot.blocks.first?.tableRows, [["Name", "Status"], ["Editor", "Draft"]])
    }

    func testUpdatePageTitlePersistsAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(initialSnapshot.selectedPageID)

        try repository.updatePageTitle(pageID: pageID, title: "Editable Title")
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.pages.first?.title, "Editable Title")
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges().last?.entityType, "page")
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges().last?.entityID, pageID)
    }

    func testUpdatePageTitleWithSameTitleDoesNotQueueSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let page = try XCTUnwrap(initialSnapshot.pages.first)
        let initialUpdatedAt = try XCTUnwrap(
            try database.query(
                "SELECT updated_at FROM pages WHERE id = ? LIMIT 1",
                bindings: [.text(page.id)]
            ).first?["updated_at"]
        )

        try repository.updatePageTitle(pageID: page.id, title: page.title)

        let finalUpdatedAt = try XCTUnwrap(
            try database.query(
                "SELECT updated_at FROM pages WHERE id = ? LIMIT 1",
                bindings: [.text(page.id)]
            ).first?["updated_at"]
        )
        XCTAssertEqual(finalUpdatedAt, initialUpdatedAt)
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges(), [])
    }

    func testUpdatePageFavoritePersistsReloadsAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(initialSnapshot.selectedPageID)

        try repository.updatePageFavorite(pageID: pageID, isFavorite: true)
        let favoriteSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(favoriteSnapshot.pages.first?.isFavorite, true)
        XCTAssertEqual(favoriteSnapshot.favoritePages.map(\.id), [pageID])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "page", entityID: pageID, changeType: "update")
        )

        try repository.updatePageFavorite(pageID: pageID, isFavorite: false)
        let unfavoriteSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(unfavoriteSnapshot.pages.first?.isFavorite, false)
        XCTAssertEqual(unfavoriteSnapshot.favoritePages, [])
    }

    func testUpdatePagePinnedPersistsReloadsAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(initialSnapshot.selectedPageID)

        try repository.updatePagePinned(pageID: pageID, isPinned: true)
        let pinnedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(pinnedSnapshot.pages.first?.isPinned, true)
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "page", entityID: pageID, changeType: "update")
        )

        try repository.updatePagePinned(pageID: pageID, isPinned: false)
        let unpinnedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(unpinnedSnapshot.pages.first?.isPinned, false)
    }

    func testPinnedPagesLoadBeforeMoreRecentlyEditedUnpinnedPages() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let pinnedPage = try repository.createPage(workspaceID: workspaceID, title: "Pinned")
        try repository.updatePagePinned(pageID: pinnedPage.id, isPinned: true)
        let laterPage = try repository.createPage(workspaceID: workspaceID, title: "Later")

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.pages.first?.id, pinnedPage.id)
        XCTAssertEqual(reloadedSnapshot.pages.first?.isPinned, true)
        XCTAssertEqual(reloadedSnapshot.pages.dropFirst().first?.id, laterPage.id)
    }

    func testEncryptedPageStoresPlaintextAndReloadsWithEncryptionFlag() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let cipher = EncryptedNoteCipher(
            metadataStore: KeychainMetadataStore(service: "com.liangzhang.editor.tests.\(UUID().uuidString)")
        )
        let repository = PageRepository(database: database, encryptedNoteCipher: cipher)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(initialSnapshot.selectedPageID)
        let blockID = try XCTUnwrap(initialSnapshot.blocks.first?.id)

        try repository.updatePageTitle(pageID: pageID, title: "Private Plan")
        try repository.updateBlockText(blockID: blockID, text: "secret launch detail")
        try repository.updatePageEncryption(pageID: pageID, isEncrypted: true)

        let rawPage = try XCTUnwrap(
            try database.query("SELECT title, is_encrypted FROM pages WHERE id = ? LIMIT 1", bindings: [.text(pageID)]).first
        )
        let rawBlock = try XCTUnwrap(
            try database.query("SELECT payload_json, text_plain FROM blocks WHERE id = ? LIMIT 1", bindings: [.text(blockID)]).first
        )
        XCTAssertEqual(rawPage["is_encrypted"], "1")
        XCTAssertEqual(rawPage["title"], "Private Plan")
        XCTAssertEqual(rawBlock["text_plain"], "secret launch detail")
        XCTAssertFalse(rawBlock["payload_json"]?.hasPrefix(EncryptedNoteCipher.ciphertextPrefix) == true)

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.pages.first?.title, "Private Plan")
        XCTAssertEqual(reloadedSnapshot.pages.first?.isEncrypted, true)
        XCTAssertEqual(reloadedSnapshot.blocks.first?.textPlain, "secret launch detail")
    }

    func testLoadWorkspaceSnapshotKeepsPlaintextEncryptedPagesReadableWhenCipherCannotDecrypt() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let writingCipher = TestEncryptedNoteCipher(decryptShouldFail: false)
        let writingRepository = PageRepository(database: database, encryptedNoteCipher: writingCipher)
        let initialSnapshot = try writingRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let encryptedPage = try writingRepository.createPage(
            workspaceID: workspaceID,
            title: "Private Plan",
            isEncrypted: true
        )
        _ = try writingRepository.appendBlock(
            pageID: encryptedPage.id,
            type: .paragraph,
            text: "secret launch detail"
        )

        let readingRepository = PageRepository(
            database: database,
            encryptedNoteCipher: TestEncryptedNoteCipher(decryptShouldFail: true)
        )
        let reloadedSnapshot = try readingRepository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.pages.map(\.id), [encryptedPage.id, initialSnapshot.selectedPageID])
        XCTAssertEqual(reloadedSnapshot.pages.first?.title, "Private Plan")
        XCTAssertEqual(reloadedSnapshot.pages.first?.isEncrypted, true)
        XCTAssertEqual(
            reloadedSnapshot.blocks.filter { $0.pageID == encryptedPage.id }.map(\.textPlain),
            ["", "secret launch detail"]
        )
        XCTAssertTrue(reloadedSnapshot.pages.contains { $0.title == "欢迎" })
    }

    func testLoadWorkspaceSnapshotDecryptsLegacyCiphertextRows() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let cipher = TestEncryptedNoteCipher(decryptShouldFail: false)
        let repository = PageRepository(database: database, encryptedNoteCipher: cipher)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let encryptedPage = try repository.createPage(
            workspaceID: workspaceID,
            title: "Plain New Page",
            isEncrypted: true
        )
        let blockID = try XCTUnwrap(
            try repository.loadWorkspaceSnapshot()
                .blocks
                .first { $0.pageID == encryptedPage.id }?
                .id
        )
        try database.execute(
            "UPDATE pages SET title = ? WHERE id = ?",
            bindings: [
                .text(try cipher.encrypt("Legacy Secret Page")),
                .text(encryptedPage.id)
            ]
        )
        try database.execute(
            "UPDATE blocks SET payload_json = ?, text_plain = ? WHERE id = ?",
            bindings: [
                .text(try cipher.encrypt("{}")),
                .text(try cipher.encrypt("legacy secret body")),
                .text(blockID)
            ]
        )

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        let page = try XCTUnwrap(reloadedSnapshot.pages.first { $0.id == encryptedPage.id })
        let block = try XCTUnwrap(reloadedSnapshot.blocks.first { $0.id == blockID })

        XCTAssertEqual(page.title, "Legacy Secret Page")
        XCTAssertEqual(block.textPlain, "legacy secret body")
    }

    func testEncryptedPageUpdatesContinueWritingPlaintextAndCanBeToggled() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let cipher = EncryptedNoteCipher(
            metadataStore: KeychainMetadataStore(service: "com.liangzhang.editor.tests.\(UUID().uuidString)")
        )
        let repository = PageRepository(database: database, encryptedNoteCipher: cipher)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(initialSnapshot.selectedPageID)
        let blockID = try XCTUnwrap(initialSnapshot.blocks.first?.id)

        try repository.updatePageEncryption(pageID: pageID, isEncrypted: true)
        try repository.updatePageTitle(pageID: pageID, title: "Updated Secret")
        try repository.updateBlockText(blockID: blockID, text: "rotated secret body")

        let rawPageTitle = try XCTUnwrap(
            try database.query("SELECT title FROM pages WHERE id = ? LIMIT 1", bindings: [.text(pageID)]).first?["title"]
        )
        let rawBlockText = try XCTUnwrap(
            try database.query("SELECT text_plain FROM blocks WHERE id = ? LIMIT 1", bindings: [.text(blockID)]).first?["text_plain"]
        )
        XCTAssertEqual(rawPageTitle, "Updated Secret")
        XCTAssertEqual(rawBlockText, "rotated secret body")

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.pages.first?.title, "Updated Secret")
        XCTAssertEqual(reloadedSnapshot.blocks.first?.textPlain, "rotated secret body")

        try repository.updatePageEncryption(pageID: pageID, isEncrypted: false)
        let decryptedRawPageTitle = try XCTUnwrap(
            try database.query("SELECT title FROM pages WHERE id = ? LIMIT 1", bindings: [.text(pageID)]).first?["title"]
        )
        let decryptedRawBlockText = try XCTUnwrap(
            try database.query("SELECT text_plain FROM blocks WHERE id = ? LIMIT 1", bindings: [.text(blockID)]).first?["text_plain"]
        )
        XCTAssertEqual(decryptedRawPageTitle, "Updated Secret")
        XCTAssertEqual(decryptedRawBlockText, "rotated secret body")
        XCTAssertEqual(try repository.loadWorkspaceSnapshot().pages.first?.isEncrypted, false)
    }

    func testSearchIndexSkipsEncryptedPageTitlesAndBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let cipher = EncryptedNoteCipher(
            metadataStore: KeychainMetadataStore(service: "com.liangzhang.editor.tests.\(UUID().uuidString)")
        )
        let repository = PageRepository(database: database, encryptedNoteCipher: cipher)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        try repository.updatePageTitle(pageID: pageID, title: "Classified Roadmap")
        try repository.updateBlockText(blockID: blockID, text: "vault-only launch phrase")
        try repository.updatePageEncryption(pageID: pageID, isEncrypted: true)

        let searchRepository = SearchRepository(database: database)
        try searchRepository.rebuildIndex()

        XCTAssertEqual(try searchRepository.search("Classified Roadmap"), [])
        XCTAssertEqual(try searchRepository.search("vault-only"), [])
        XCTAssertEqual(try database.queryInt("SELECT COUNT(*) FROM search_index"), 0)
    }

    func testConvertTextBlockToPageFromEncryptedPagePreservesEncryption() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let cipher = EncryptedNoteCipher(
            metadataStore: KeychainMetadataStore(service: "com.liangzhang.editor.tests.\(UUID().uuidString)")
        )
        let repository = PageRepository(database: database, encryptedNoteCipher: cipher)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "Secret Child")
        try repository.updatePageEncryption(pageID: sourcePageID, isEncrypted: true)

        let createdPage = try repository.convertTextBlockToPage(blockID: blockID)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        let reloadedCreatedPage = try XCTUnwrap(reloadedSnapshot.pages.first { $0.id == createdPage.id })
        let sourceBlock = try XCTUnwrap(reloadedSnapshot.blocks.first { $0.id == blockID })
        let rawCreatedPage = try XCTUnwrap(
            try database.query("SELECT title, is_encrypted FROM pages WHERE id = ? LIMIT 1", bindings: [.text(createdPage.id)]).first
        )
        let rawSourceBlock = try XCTUnwrap(
            try database.query("SELECT text_plain, payload_json FROM blocks WHERE id = ? LIMIT 1", bindings: [.text(blockID)]).first
        )

        XCTAssertEqual(reloadedCreatedPage.title, "Secret Child")
        XCTAssertEqual(reloadedCreatedPage.isEncrypted, true)
        XCTAssertEqual(sourceBlock.type, .pageReference)
        XCTAssertEqual(sourceBlock.textPlain, "Secret Child")
        XCTAssertEqual(sourceBlock.pageReferenceTargetPageID, createdPage.id)
        XCTAssertEqual(rawCreatedPage["is_encrypted"], "1")
        XCTAssertEqual(rawCreatedPage["title"], "Secret Child")
        XCTAssertEqual(rawSourceBlock["text_plain"], "Secret Child")
        XCTAssertFalse(rawSourceBlock["payload_json"]?.hasPrefix(EncryptedNoteCipher.ciphertextPrefix) == true)
        XCTAssertEqual(reloadedSnapshot.pageParentLinks, [])
    }

    func testLoadWorkspaceSnapshotOrdersActivePagesByUpdatedTimeDescending() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)

        let older = try repository.createPage(workspaceID: workspaceID, title: "Older")
        Thread.sleep(forTimeInterval: 0.01)
        _ = try repository.createPage(workspaceID: workspaceID, title: "Newer")
        try repository.updatePageTitle(pageID: older.id, title: "Older updated last")

        let reloaded = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloaded.pages.map(\.title).prefix(2), ["Older updated last", "Newer"])
    }

    func testLoadWorkspaceSnapshotOrdersDailyPagesByModifiedTimestampForRecentList() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let diaryRepository = DiaryRepository(database: database)
        let olderDay = try diaryRepository.openDailyPage(
            workspaceID: workspaceID,
            date: Self.date(year: 2026, month: 5, day: 16),
            calendar: Self.gregorianCalendar
        )
        Thread.sleep(forTimeInterval: 0.01)
        let newerDay = try diaryRepository.openDailyPage(
            workspaceID: workspaceID,
            date: Self.date(year: 2026, month: 5, day: 17),
            calendar: Self.gregorianCalendar
        )
        let olderBlockID = try XCTUnwrap(
            try repository.loadWorkspaceSnapshot()
                .blocks
                .first { $0.pageID == olderDay.id }?
                .id
        )

        Thread.sleep(forTimeInterval: 0.01)
        try repository.updateBlockText(blockID: olderBlockID, text: "修改旧日记应该进入最近列表前面")

        let reloaded = try repository.loadWorkspaceSnapshot()
        let diaryPages = reloaded.pages.filter { [olderDay.id, newerDay.id].contains($0.id) }

        XCTAssertEqual(diaryPages.map(\.id), [olderDay.id, newerDay.id])
        XCTAssertGreaterThan(
            try XCTUnwrap(diaryPages.first?.updatedAt),
            try XCTUnwrap(diaryPages.last?.updatedAt)
        )
    }

    func testLoadWorkspaceSnapshotLoadsTagsAndAssignments() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let tagRepository = TagRepository(database: database)
        let tag = try tagRepository.createTag(workspaceID: workspaceID, name: "Writing")
        try tagRepository.assignTags(pageID: pageID, tagIDs: [tag.id])

        let reloaded = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloaded.tags.map(\.path), ["Writing"])
        XCTAssertEqual(reloaded.pageTags, [PageTagAssignment(pageID: pageID, tagID: tag.id)])
    }

    func testArchivedFavoritePageHidesFromFavoritesUntilRestored() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let createdPage = try repository.createPage(workspaceID: workspaceID, title: "Scratch")

        try repository.updatePageFavorite(pageID: createdPage.id, isFavorite: true)
        try repository.archivePage(pageID: createdPage.id)
        let archivedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(archivedSnapshot.favoritePages, [])
        XCTAssertEqual(archivedSnapshot.archivedPages.first?.isFavorite, true)

        try repository.restorePage(pageID: createdPage.id)
        let restoredSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(restoredSnapshot.favoritePages.map(\.title), ["Scratch"])
    }

    func testCreatePagePersistsEmptyEditablePageAtTopOfAllDocuments() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)

        let createdPage = try repository.createPage(workspaceID: workspaceID, title: "未命名")
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        let createdBlocks = reloadedSnapshot.blocks.filter { $0.pageID == createdPage.id }

        XCTAssertEqual(reloadedSnapshot.pages.map(\.title), ["未命名", "欢迎"])
        XCTAssertEqual(reloadedSnapshot.pages.first?.id, createdPage.id)
        XCTAssertEqual(createdBlocks.map(\.type), [.paragraph])
        XCTAssertEqual(createdBlocks.map(\.textPlain), [""])
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges().suffix(2).map(\.entityType), ["page", "block"])
    }

    func testCreateNotebookAndPageInNotebookPersistsGrouping() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)

        let notebook = try repository.createNotebook(workspaceID: workspaceID, name: "Projects")
        let page = try repository.createPage(
            workspaceID: workspaceID,
            title: "Roadmap",
            notebookID: notebook.id
        )
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertTrue(reloadedSnapshot.notebooks.contains(notebook))
        XCTAssertEqual(reloadedSnapshot.pages.first { $0.id == page.id }?.notebookID, notebook.id)
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges().suffix(3).map(\.entityType), ["notebook", "page", "block"])
    }

    func testCreateNestedNotebookPersistsParentNotebook() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)

        let parent = try repository.createNotebook(workspaceID: workspaceID, name: "Projects")
        let child = try repository.createNotebook(
            workspaceID: workspaceID,
            name: "Client A",
            parentNotebookID: parent.id
        )
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(child.parentNotebookID, parent.id)
        XCTAssertEqual(
            reloadedSnapshot.notebooks.first { $0.id == child.id }?.parentNotebookID,
            parent.id
        )
    }

    func testLoadWorkspaceSnapshotOrdersNestedNotebooksDepthFirst() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)

        let projects = try repository.createNotebook(workspaceID: workspaceID, name: "Projects")
        _ = try repository.createNotebook(workspaceID: workspaceID, name: "Areas")
        _ = try repository.createNotebook(
            workspaceID: workspaceID,
            name: "Client A",
            parentNotebookID: projects.id
        )

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(
            reloadedSnapshot.notebooks.map(\.name),
            ["笔记本", "Projects", "Client A", "Areas"]
        )
    }

    func testUpdateNotebookParentPersistsAndPreventsCycles() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let parent = try repository.createNotebook(workspaceID: workspaceID, name: "Projects")
        let child = try repository.createNotebook(workspaceID: workspaceID, name: "Client A")

        try repository.updateNotebookParent(notebookID: child.id, parentNotebookID: parent.id)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(
            reloadedSnapshot.notebooks.first { $0.id == child.id }?.parentNotebookID,
            parent.id
        )
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "notebook", entityID: child.id, changeType: "update")
        )
        XCTAssertThrowsError(
            try repository.updateNotebookParent(notebookID: parent.id, parentNotebookID: child.id)
        )
    }

    func testUpdateNotebookNamePersistsAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let notebookID = try XCTUnwrap(initialSnapshot.selectedNotebookID)

        try repository.updateNotebookName(notebookID: notebookID, name: "Projects")
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.notebooks.first?.name, "Projects")
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "notebook", entityID: notebookID, changeType: "update")
        )
    }

    func testMoveNotebookPersistsStableOrderAndQueuesSyncChanges() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        _ = try repository.createNotebook(workspaceID: workspaceID, name: "Projects")
        let areas = try repository.createNotebook(workspaceID: workspaceID, name: "Areas")

        try repository.moveNotebook(notebookID: areas.id, toIndex: 0)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.notebooks.map(\.name), ["Areas", "笔记本", "Projects"])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().suffix(3).map(\.entityType),
            ["notebook", "notebook", "notebook"]
        )
    }

    func testArchivePageHidesItAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let createdPage = try repository.createPage(workspaceID: workspaceID, title: "Scratch")

        try repository.archivePage(pageID: createdPage.id)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.pages.map(\.title), ["欢迎"])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "page", entityID: createdPage.id, changeType: "archive")
        )
    }

    func testRestoreArchivedPageMakesItVisibleAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let createdPage = try repository.createPage(workspaceID: workspaceID, title: "Scratch")
        try repository.archivePage(pageID: createdPage.id)

        let archivedSnapshot = try repository.loadWorkspaceSnapshot()
        XCTAssertEqual(archivedSnapshot.pages.map(\.title), ["欢迎"])
        XCTAssertEqual(archivedSnapshot.archivedPages.map(\.title), ["Scratch"])

        try repository.restorePage(pageID: createdPage.id)
        let restoredSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(restoredSnapshot.pages.map(\.title), ["Scratch", "欢迎"])
        XCTAssertEqual(restoredSnapshot.archivedPages, [])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "page", entityID: createdPage.id, changeType: "restore")
        )
    }

    func testPermanentlyDeleteArchivedPageRemovesItAndQueuesDeleteTombstone() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let createdPage = try repository.createPage(workspaceID: workspaceID, title: "Scratch")
        try repository.archivePage(pageID: createdPage.id)

        try repository.permanentlyDeleteArchivedPage(pageID: createdPage.id)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.pages.map(\.title), ["欢迎"])
        XCTAssertEqual(reloadedSnapshot.archivedPages, [])
        XCTAssertEqual(
            try database.queryInt("SELECT COUNT(*) FROM blocks WHERE page_id = '\(createdPage.id)'"),
            0
        )
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().last,
            SyncChange(entityType: "page", entityID: createdPage.id, changeType: "delete")
        )
    }

    func testImportMarkdownReplacesPageBlocksWithTypedBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)

        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                # Imported

                Body

                - Item
                """
        )
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.blocks.map(\.type), [.heading1, .paragraph, .unorderedListItem])
        XCTAssertEqual(reloadedSnapshot.blocks.map(\.textPlain), ["Imported", "Body", "Item"])
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges().map(\.entityType), ["block", "block", "block", "page"])
    }

    func testImportMarkdownKeepsIndentedListContinuationOutOfCodeBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)

        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                - Unordered parent
                    Unordered continuation

                1. Ordered parent
                    Ordered continuation
                """
        )
        let blocks = try repository.loadWorkspaceSnapshot().blocks

        XCTAssertEqual(blocks.map(\.type), [.unorderedListItem, .paragraph, .orderedListItem, .paragraph])
        XCTAssertEqual(
            blocks.map(\.textPlain),
            ["Unordered parent", "Unordered continuation", "Ordered parent", "Ordered continuation"]
        )
    }

    func testImportMarkdownPersistsOuterPipeOptionalTableRows() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)

        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                Name | Status
                --- | ---
                Editor | Ready
                """
        )
        let tableBlock = try XCTUnwrap(try repository.loadWorkspaceSnapshot().blocks.first)

        XCTAssertEqual(tableBlock.type, .table)
        XCTAssertEqual(tableBlock.tableRows, [["Name", "Status"], ["Editor", "Ready"]])
        XCTAssertEqual(
            tableBlock.textPlain,
            """
            Name | Status
            --- | ---
            Editor | Ready
            """
        )
    }

    func testImportMarkdownPersistsTaskItemCompletionState() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)

        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                - [x] Done
                - [ ] Todo
                """
        )

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.blocks.map(\.type), [.taskItem, .taskItem])
        XCTAssertEqual(reloadedSnapshot.blocks.map(\.textPlain), ["Done", "Todo"])
        XCTAssertEqual(reloadedSnapshot.blocks.map(\.taskItemIsCompleted), [true, false])
    }

    func testImportMarkdownResolvesPageAndBlockReferenceTargets() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let targetPage = try repository.createPage(workspaceID: workspaceID, title: "Specs")
        let targetBlock = try repository.appendBlock(
            pageID: targetPage.id,
            type: .paragraph,
            text: "API contract"
        )

        try repository.importMarkdown(
            pageID: sourcePageID,
            markdown:
                """
                [[Specs]]

                [[#API contract]]
                """
        )

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        let importedBlocks = reloadedSnapshot.blocks.filter { $0.pageID == sourcePageID }
        XCTAssertEqual(importedBlocks.map(\.type), [.pageReference, .blockReference])
        XCTAssertEqual(importedBlocks.map(\.textPlain), ["Specs", "API contract"])
        XCTAssertEqual(importedBlocks.first?.pageReferenceTargetPageID, targetPage.id)
        XCTAssertEqual(importedBlocks.last?.pageReferenceTargetPageID, targetPage.id)
        XCTAssertEqual(importedBlocks.last?.blockReferenceTargetBlockID, targetBlock.id)
        XCTAssertEqual(
            try BacklinkRepository(database: database).backlinks(targetPageID: targetPage.id),
            [
                Backlink(
                    sourcePageID: sourcePageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: importedBlocks[0].id,
                    targetPageID: targetPage.id,
                    targetBlockID: nil,
                    linkText: "Specs"
                ),
                Backlink(
                    sourcePageID: sourcePageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: importedBlocks[1].id,
                    targetPageID: targetPage.id,
                    targetBlockID: targetBlock.id,
                    linkText: "API contract"
                )
            ]
        )
    }

    func testUpdateTaskItemCompletionPersistsAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let block = try repository.appendBlock(pageID: pageID, type: .taskItem, text: "Ship")

        try repository.updateTaskItemCompletion(blockID: block.id, isCompleted: true)

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        let reloadedBlock = try XCTUnwrap(reloadedSnapshot.blocks.first { $0.id == block.id })

        XCTAssertEqual(reloadedBlock.type, .taskItem)
        XCTAssertEqual(reloadedBlock.textPlain, "Ship")
        XCTAssertTrue(reloadedBlock.taskItemIsCompleted)
        XCTAssertTrue(
            try SyncRepository(database: database).pendingChanges().contains(
                SyncChange(entityType: "block", entityID: block.id, changeType: "update")
            )
        )
    }

    func testUpdateToggleExpansionPersistsAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let block = try repository.appendBlock(pageID: pageID, type: .toggle, text: "Details")

        try repository.updateToggleExpansion(blockID: block.id, isExpanded: false)

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        let reloadedBlock = try XCTUnwrap(reloadedSnapshot.blocks.first { $0.id == block.id })

        XCTAssertEqual(reloadedBlock.type, .toggle)
        XCTAssertEqual(reloadedBlock.textPlain, "Details")
        XCTAssertFalse(reloadedBlock.toggleIsExpanded)
        XCTAssertTrue(
            try SyncRepository(database: database).pendingChanges().contains(
                SyncChange(entityType: "block", entityID: block.id, changeType: "update")
            )
        )
    }

    func testUpdateCodeBlockLineWrappingPersistsAndQueuesSyncChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let block = try repository.appendBlock(pageID: pageID, type: .codeBlock, text: "let value = 1")

        try repository.updateCodeBlockLineWrapping(blockID: block.id, isWrapped: false)

        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        let reloadedBlock = try XCTUnwrap(reloadedSnapshot.blocks.first { $0.id == block.id })

        XCTAssertEqual(reloadedBlock.type, .codeBlock)
        XCTAssertEqual(reloadedBlock.textPlain, "let value = 1")
        XCTAssertFalse(reloadedBlock.codeBlockLineWrapping)
        XCTAssertTrue(
            try SyncRepository(database: database).pendingChanges().contains(
                SyncChange(entityType: "block", entityID: block.id, changeType: "update")
            )
        )
    }

    func testMoveBlockPersistsStableOrder() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                First
                Second
                Third
                """
        )
        let importedSnapshot = try repository.loadWorkspaceSnapshot()
        let thirdBlockID = try XCTUnwrap(importedSnapshot.blocks.last?.id)

        try repository.moveBlock(blockID: thirdBlockID, toIndex: 0)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.blocks.map(\.textPlain), ["Third", "First", "Second"])
        XCTAssertEqual(reloadedSnapshot.blocks.map(\.orderKey), ["000001", "000002", "000003"])
    }

    func testMoveBlocksPersistsDraggedGroupOrder() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                Parent
                Child
                Sibling
                Tail
                """
        )
        let importedSnapshot = try repository.loadWorkspaceSnapshot()
        let parentID = try XCTUnwrap(importedSnapshot.blocks.first?.id)
        let childID = try XCTUnwrap(importedSnapshot.blocks.dropFirst().first?.id)
        XCTAssertTrue(try repository.indentBlock(blockID: childID))

        try repository.moveBlocks(blockIDs: [parentID, childID], toIndex: 2)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.blocks.map(\.textPlain), ["Sibling", "Tail", "Parent", "Child"])
        XCTAssertEqual(reloadedSnapshot.blocks.first { $0.id == childID }?.parentBlockID, parentID)
        XCTAssertEqual(reloadedSnapshot.blocks.map(\.orderKey), ["000001", "000002", "000003", "000004"])
    }

    func testIndentBlockNestsUnderPreviousSiblingAndQueuesSync() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                First
                Second
                Third
                """
        )
        let importedSnapshot = try repository.loadWorkspaceSnapshot()
        let firstBlockID = try XCTUnwrap(importedSnapshot.blocks.first?.id)
        let secondBlockID = try XCTUnwrap(importedSnapshot.blocks.dropFirst().first?.id)

        XCTAssertTrue(try repository.indentBlock(blockID: secondBlockID))
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.blocks.first { $0.id == secondBlockID }?.parentBlockID, firstBlockID)
        XCTAssertTrue(
            try SyncRepository(database: database).pendingChanges().contains(
                SyncChange(entityType: "block", entityID: secondBlockID, changeType: "update")
            )
        )
    }

    func testOutdentBlockRestoresParentAndQueuesSync() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                First
                Second
                """
        )
        let importedSnapshot = try repository.loadWorkspaceSnapshot()
        let secondBlockID = try XCTUnwrap(importedSnapshot.blocks.dropFirst().first?.id)
        _ = try repository.indentBlock(blockID: secondBlockID)

        XCTAssertTrue(try repository.outdentBlock(blockID: secondBlockID))
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertNil(reloadedSnapshot.blocks.first { $0.id == secondBlockID }?.parentBlockID)
        XCTAssertTrue(
            try SyncRepository(database: database).pendingChanges().contains(
                SyncChange(entityType: "block", entityID: secondBlockID, changeType: "update")
            )
        )
    }

    func testUpdateBlockParentPersistsArbitraryDropTargetParentAndQueuesSync() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                Root
                Child
                Grandchild
                Moved
                """
        )
        let importedSnapshot = try repository.loadWorkspaceSnapshot()
        let rootID = try XCTUnwrap(importedSnapshot.blocks.first?.id)
        let childID = try XCTUnwrap(importedSnapshot.blocks.dropFirst().first?.id)
        let grandchildID = try XCTUnwrap(importedSnapshot.blocks.dropFirst(2).first?.id)
        let movedID = try XCTUnwrap(importedSnapshot.blocks.dropFirst(3).first?.id)
        XCTAssertTrue(try repository.indentBlock(blockID: childID))
        XCTAssertTrue(try repository.indentBlock(blockID: grandchildID))

        try repository.updateBlockParent(blockID: movedID, parentBlockID: childID)
        var reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        XCTAssertEqual(reloadedSnapshot.blocks.first { $0.id == movedID }?.parentBlockID, childID)
        XCTAssertTrue(
            try SyncRepository(database: database).pendingChanges().contains(
                SyncChange(entityType: "block", entityID: movedID, changeType: "update")
            )
        )

        try repository.updateBlockParent(blockID: movedID, parentBlockID: nil)
        reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        XCTAssertNil(reloadedSnapshot.blocks.first { $0.id == movedID }?.parentBlockID)

        XCTAssertThrowsError(
            try repository.updateBlockParent(blockID: rootID, parentBlockID: grandchildID)
        ) { error in
            XCTAssertEqual(error as? PageRepositoryError, .cyclicBlockParent)
        }
    }

    func testAppendParagraphBlockPersistsAtEnd() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)

        let appendedBlock = try repository.appendBlock(
            pageID: pageID,
            type: .paragraph,
            text: ""
        )
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(appendedBlock.type, .paragraph)
        XCTAssertEqual(appendedBlock.textPlain, "")
        XCTAssertEqual(reloadedSnapshot.blocks.map(\.id).last, appendedBlock.id)
        XCTAssertEqual(reloadedSnapshot.blocks.map(\.orderKey), ["000001", "000002"])
        XCTAssertTrue(
            try SyncRepository(database: database).pendingChanges().contains(
                SyncChange(entityType: "block", entityID: appendedBlock.id, changeType: "create")
            )
        )
    }

    func testAppendPageReferenceBlockCreatesTypedBlockAndBacklink() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let targetPage = try repository.createPage(workspaceID: workspaceID, title: "Specs")

        let block = try repository.appendPageReferenceBlock(
            pageID: sourcePageID,
            targetPageID: targetPage.id
        )

        XCTAssertEqual(block.type, .pageReference)
        XCTAssertEqual(block.textPlain, "Specs")
        XCTAssertEqual(block.pageReferenceTargetPageID, targetPage.id)
        XCTAssertEqual(
            try BacklinkRepository(database: database).backlinks(targetPageID: targetPage.id),
            [
                Backlink(
                    sourcePageID: sourcePageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: block.id,
                    targetPageID: targetPage.id,
                    targetBlockID: nil,
                    linkText: "Specs"
                )
            ]
        )

        let reloadedBlock = try XCTUnwrap(
            repository.loadWorkspaceSnapshot().blocks.first { $0.id == block.id }
        )
        XCTAssertEqual(reloadedBlock.type, .pageReference)
        XCTAssertEqual(reloadedBlock.pageReferenceTargetPageID, targetPage.id)
    }

    func testPlainTextBlocksIgnoreReferenceTargetsInPayloadWhenLoadingSnapshot() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        try database.execute(
            """
            UPDATE blocks
            SET type = 'paragraph',
                payload_json = ?,
                text_plain = 'Plain text'
            WHERE id = ?
            """,
            bindings: [
                .text(#"{"text":"Plain text","target_page_id":"page-target","target_block_id":"block-target"}"#),
                .text(blockID)
            ]
        )

        let reloadedBlock = try XCTUnwrap(
            repository.loadWorkspaceSnapshot().blocks.first { $0.id == blockID }
        )
        XCTAssertEqual(reloadedBlock.type, .paragraph)
        XCTAssertNil(reloadedBlock.pageReferenceTargetPageID)
        XCTAssertNil(reloadedBlock.blockReferenceTargetBlockID)
    }

    func testAppendPageReferenceBlockUsesPlaintextTitleFromEncryptedTarget() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let cipher = EncryptedNoteCipher(
            metadataStore: KeychainMetadataStore(service: "com.liangzhang.editor.tests.\(UUID().uuidString)")
        )
        let repository = PageRepository(database: database, encryptedNoteCipher: cipher)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let targetPage = try repository.createPage(workspaceID: workspaceID, title: "Secret Specs")
        try repository.updatePageEncryption(pageID: targetPage.id, isEncrypted: true)

        let block = try repository.appendPageReferenceBlock(
            pageID: sourcePageID,
            targetPageID: targetPage.id
        )

        XCTAssertEqual(block.type, .pageReference)
        XCTAssertEqual(block.textPlain, "Secret Specs")
        XCTAssertEqual(block.pageReferenceTargetPageID, targetPage.id)
    }

    func testConvertTextBlockToPageReplacesSourceWithPageReference() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "项目计划")

        let createdPage = try repository.convertTextBlockToPage(blockID: blockID)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        let sourceBlock = try XCTUnwrap(reloadedSnapshot.blocks.first { $0.id == blockID })
        let createdPageInitialBlock = try XCTUnwrap(
            reloadedSnapshot.blocks.first { $0.pageID == createdPage.id }
        )

        XCTAssertEqual(createdPage.title, "项目计划")
        XCTAssertEqual(sourceBlock.type, .pageReference)
        XCTAssertEqual(sourceBlock.textPlain, "项目计划")
        XCTAssertEqual(sourceBlock.pageReferenceTargetPageID, createdPage.id)
        XCTAssertEqual(
            reloadedSnapshot.pageParentLinks,
            [
                PageParentLink(
                    parentPageID: sourcePageID,
                    childPageID: createdPage.id,
                    sourceBlockID: blockID,
                    orderKey: "000001"
                )
            ]
        )
        XCTAssertEqual(createdPageInitialBlock.type, .paragraph)
        XCTAssertEqual(createdPageInitialBlock.textPlain, "")
        XCTAssertEqual(
            try BacklinkRepository(database: database).backlinks(targetPageID: createdPage.id),
            [
                Backlink(
                    sourcePageID: sourcePageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: blockID,
                    targetPageID: createdPage.id,
                    targetBlockID: nil,
                    linkText: "项目计划"
                )
            ]
        )
    }

    func testConvertTextBlockToPageMovesNestedChildBlocksIntoCreatedPage() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "项目计划")
        let childBlock = try repository.appendBlock(
            pageID: sourcePageID,
            type: .paragraph,
            text: "迁移到子页面"
        )
        XCTAssertTrue(try repository.indentBlock(blockID: childBlock.id))

        let createdPage = try repository.convertTextBlockToPage(blockID: blockID)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        let sourcePageBlocks = reloadedSnapshot.blocks.filter { $0.pageID == sourcePageID }
        let createdPageBlocks = reloadedSnapshot.blocks.filter { $0.pageID == createdPage.id }
        let migratedChildBlock = try XCTUnwrap(createdPageBlocks.first { $0.id == childBlock.id })

        XCTAssertEqual(sourcePageBlocks.map(\.id), [blockID])
        XCTAssertEqual(createdPageBlocks.map(\.id), [childBlock.id])
        XCTAssertNil(migratedChildBlock.parentBlockID)
        XCTAssertEqual(migratedChildBlock.textPlain, "迁移到子页面")
    }

    func testConvertHeadingBlockToPageKeepsSourceBlockTypography() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlock(blockID: blockID, type: .heading2, text: "章节标题")

        let createdPage = try repository.convertTextBlockToPage(blockID: blockID)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        let sourceBlock = try XCTUnwrap(reloadedSnapshot.blocks.first { $0.id == blockID })

        XCTAssertEqual(createdPage.title, "章节标题")
        XCTAssertEqual(sourceBlock.type, .heading2)
        XCTAssertEqual(sourceBlock.textPlain, "章节标题")
        XCTAssertEqual(sourceBlock.pageReferenceTargetPageID, createdPage.id)
        XCTAssertEqual(
            reloadedSnapshot.pageParentLinks,
            [
                PageParentLink(
                    parentPageID: sourcePageID,
                    childPageID: createdPage.id,
                    sourceBlockID: blockID,
                    orderKey: "000001"
                )
            ]
        )
    }

    func testConvertListBlockToPageKeepsSourceBlockListType() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let sourceBlock = try repository.appendBlock(
            pageID: sourcePageID,
            type: .orderedListItem,
            text: "第一项"
        )

        let createdPage = try repository.convertTextBlockToPage(blockID: sourceBlock.id)
        let reloadedSourceBlock = try XCTUnwrap(
            repository.loadWorkspaceSnapshot().blocks.first { $0.id == sourceBlock.id }
        )

        XCTAssertEqual(createdPage.title, "第一项")
        XCTAssertEqual(reloadedSourceBlock.type, .orderedListItem)
        XCTAssertEqual(reloadedSourceBlock.textPlain, "第一项")
        XCTAssertEqual(reloadedSourceBlock.pageReferenceTargetPageID, createdPage.id)
    }

    func testConvertListBlockToPageReopensExistingChildPage() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let sourceBlock = try repository.appendBlock(
            pageID: sourcePageID,
            type: .unorderedListItem,
            text: "已有子页面"
        )
        let createdPage = try repository.convertTextBlockToPage(blockID: sourceBlock.id)

        let reopenedPage = try repository.convertTextBlockToPage(blockID: sourceBlock.id)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()
        let parentLinks = reloadedSnapshot.pageParentLinks.filter { $0.sourceBlockID == sourceBlock.id }

        XCTAssertEqual(reopenedPage.id, createdPage.id)
        XCTAssertEqual(parentLinks.count, 1)
    }

    func testEditingConvertedHeadingKeepsChildPageTarget() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlock(blockID: blockID, type: .heading2, text: "章节标题")
        let createdPage = try repository.convertTextBlockToPage(blockID: blockID)

        try repository.updateBlockText(blockID: blockID, text: "章节标题更新")
        let reloadedSourceBlock = try XCTUnwrap(
            repository.loadWorkspaceSnapshot().blocks.first { $0.id == blockID }
        )

        XCTAssertEqual(reloadedSourceBlock.type, .heading2)
        XCTAssertEqual(reloadedSourceBlock.textPlain, "章节标题更新")
        XCTAssertEqual(reloadedSourceBlock.pageReferenceTargetPageID, createdPage.id)
    }

    func testAppendBlockReferenceBlockCreatesTypedBlockAndBlockBacklink() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let targetPage = try repository.createPage(workspaceID: workspaceID, title: "Specs")
        let targetBlock = try repository.appendBlock(
            pageID: targetPage.id,
            type: .paragraph,
            text: "API contract"
        )

        let block = try repository.appendBlockReferenceBlock(
            pageID: sourcePageID,
            targetBlockID: targetBlock.id
        )

        XCTAssertEqual(block.type, .blockReference)
        XCTAssertEqual(block.textPlain, "API contract")
        XCTAssertEqual(block.pageReferenceTargetPageID, targetPage.id)
        XCTAssertEqual(block.blockReferenceTargetBlockID, targetBlock.id)
        XCTAssertEqual(
            try BacklinkRepository(database: database).backlinks(targetPageID: targetPage.id),
            [
                Backlink(
                    sourcePageID: sourcePageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: block.id,
                    targetPageID: targetPage.id,
                    targetBlockID: targetBlock.id,
                    linkText: "API contract"
                )
            ]
        )
    }

    func testAppendBlockReferenceBlockUsesPlaintextFromEncryptedTarget() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let cipher = EncryptedNoteCipher(
            metadataStore: KeychainMetadataStore(service: "com.liangzhang.editor.tests.\(UUID().uuidString)")
        )
        let repository = PageRepository(database: database, encryptedNoteCipher: cipher)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let targetPage = try repository.createPage(workspaceID: workspaceID, title: "Encrypted Source")
        let targetBlock = try repository.appendBlock(
            pageID: targetPage.id,
            type: .paragraph,
            text: "Secret API contract"
        )
        try repository.updatePageEncryption(pageID: targetPage.id, isEncrypted: true)

        let block = try repository.appendBlockReferenceBlock(
            pageID: sourcePageID,
            targetBlockID: targetBlock.id
        )

        XCTAssertEqual(block.type, .blockReference)
        XCTAssertEqual(block.textPlain, "Secret API contract")
        XCTAssertEqual(block.pageReferenceTargetPageID, targetPage.id)
        XCTAssertEqual(block.blockReferenceTargetBlockID, targetBlock.id)
    }

    func testInsertParagraphBlockAfterCurrentBlockPersistsOrderAndQueuesSync() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        try repository.importMarkdown(
            pageID: pageID,
            markdown:
                """
                First
                Second
                """
        )
        let importedSnapshot = try repository.loadWorkspaceSnapshot()
        let firstBlockID = try XCTUnwrap(importedSnapshot.blocks.first?.id)

        let insertedBlock = try repository.insertParagraphBlock(after: firstBlockID)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.blocks.map(\.textPlain), ["First", "", "Second"])
        XCTAssertEqual(reloadedSnapshot.blocks.map(\.orderKey), ["000001", "000002", "000003"])
        XCTAssertEqual(reloadedSnapshot.blocks.dropFirst().first?.id, insertedBlock.id)
        let pendingChanges = try SyncRepository(database: database).pendingChanges()
        XCTAssertTrue(pendingChanges.contains(
            SyncChange(entityType: "block", entityID: insertedBlock.id, changeType: "create")
        ))
        XCTAssertTrue(pendingChanges.contains(
            SyncChange(
                entityType: "block",
                entityID: try XCTUnwrap(importedSnapshot.blocks.last?.id),
                changeType: "update"
            )
        ))
        XCTAssertTrue(
            pendingChanges.contains(
                SyncChange(entityType: "page", entityID: pageID, changeType: "update")
            )
        )
    }

    func testDeleteBlockHidesItQueuesSyncChangeAndRemovesBacklinks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try repository.updateBlockText(blockID: blockID, text: "See [[欢迎]]")
        XCTAssertFalse(try BacklinkRepository(database: database).backlinks(targetPageID: pageID).isEmpty)

        try repository.deleteBlock(blockID: blockID)
        let reloadedSnapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedSnapshot.blocks, [])
        XCTAssertEqual(try BacklinkRepository(database: database).backlinks(targetPageID: pageID), [])
        XCTAssertTrue(
            try SyncRepository(database: database).pendingChanges().contains(
                SyncChange(entityType: "block", entityID: blockID, changeType: "delete")
            )
        )
    }

    func testLargePageImportLoadAndSearchIndexRemainUsable() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let markdown = (1...750)
            .map { "Block \($0) searchable content" }
            .joined(separator: "\n")

        try repository.importMarkdown(pageID: pageID, markdown: markdown)
        let loadedSnapshot = try repository.loadWorkspaceSnapshot()
        try SearchRepository(database: database).rebuildIndex()
        let searchResults = try SearchRepository(database: database).search("Block 750")

        XCTAssertEqual(loadedSnapshot.blocks.count, 750)
        XCTAssertEqual(loadedSnapshot.blocks.first?.orderKey, "000001")
        XCTAssertEqual(loadedSnapshot.blocks.last?.orderKey, "000750")
        XCTAssertTrue(searchResults.contains { $0.snippet == "Block 750 searchable content" })
    }

    private func migratedDatabase() throws -> SQLiteDatabase {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        try SchemaMigrator.migrate(database: database)
        return database
    }

    private func temporaryDatabasePath() -> String {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        temporaryFiles.append(directory)
        return directory.appendingPathComponent("editor.sqlite").path
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

    private struct TestEncryptedNoteCipher: EncryptedNoteCiphering {
        enum TestError: Error {
            case decryptFailed
        }

        let decryptShouldFail: Bool

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
            if decryptShouldFail {
                throw TestError.decryptFailed
            }
            let encoded = String(storedValue.dropFirst(EncryptedNoteCipher.ciphertextPrefix.count))
            guard let data = Data(base64Encoded: encoded),
                  let plaintext = String(data: data, encoding: .utf8) else {
                throw TestError.decryptFailed
            }
            return plaintext
        }

        func isCiphertext(_ storedValue: String) -> Bool {
            storedValue.hasPrefix(EncryptedNoteCipher.ciphertextPrefix)
        }
    }
}
