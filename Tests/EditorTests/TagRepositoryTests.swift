import XCTest

final class TagRepositoryTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testCreateNestedTagsLoadsPathOrder() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let repository = TagRepository(database: database)

        let work = try repository.createTag(workspaceID: workspaceID, name: "Work")
        let project = try repository.createTag(workspaceID: workspaceID, parentTagID: work.id, name: "Project A")

        XCTAssertEqual(try repository.tags(workspaceID: workspaceID).map(\.path), ["Work", "Work/Project A"])
        XCTAssertEqual(project.parentTagID, work.id)
    }

    func testCreateTagReusesExistingTagWithSameParentAndName() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let repository = TagRepository(database: database)

        let first = try repository.createTag(workspaceID: workspaceID, name: "Writing")
        let second = try repository.createTag(workspaceID: workspaceID, name: "Writing")

        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(try repository.tags(workspaceID: workspaceID).map(\.path), ["Writing"])
    }

    func testRepairDuplicateTagsMergesAssignmentsIntoCanonicalTag() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let firstPageID = try XCTUnwrap(snapshot.selectedPageID)
        let secondPage = try pageRepository.createPage(workspaceID: workspaceID, title: "Second")
        let repository = TagRepository(database: database)
        let canonical = try repository.createTag(workspaceID: workspaceID, name: "复盘")
        let duplicateID = "tag-duplicate-review"
        try database.execute(
            """
            INSERT INTO tags (id, workspace_id, parent_tag_id, name, order_key, created_at, updated_at)
            VALUES (?, ?, NULL, ?, ?, ?, ?)
            """,
            bindings: [
                .text(duplicateID),
                .text(workspaceID),
                .text("复盘"),
                .text("000002"),
                .text("2999-05-24T00:00:00Z"),
                .text("2999-05-24T00:00:00Z")
            ]
        )
        try repository.assignTags(pageID: firstPageID, tagIDs: [canonical.id])
        try database.execute(
            "INSERT INTO page_tags (page_id, tag_id, created_at) VALUES (?, ?, ?)",
            bindings: [
                .text(secondPage.id),
                .text(duplicateID),
                .text("2026-05-24T00:00:01Z")
            ]
        )
        try database.execute("DELETE FROM sync_changes")

        let repairedCount = try repository.repairDuplicateTags()

        XCTAssertEqual(repairedCount, 1)
        XCTAssertEqual(try repository.tags(workspaceID: workspaceID).map(\.path), ["复盘"])
        XCTAssertEqual(
            try repository.tagAssignments().map { "\($0.pageID):\($0.tagID)" }.sorted(),
            [
                "\(firstPageID):\(canonical.id)",
                "\(secondPage.id):\(canonical.id)"
            ].sorted()
        )
        let pendingChanges = try SyncRepository(database: database).pendingChanges()
        XCTAssertTrue(pendingChanges.contains(
            SyncChange(entityType: "pageTag", entityID: "\(secondPage.id).\(canonical.id)", changeType: "create")
        ))
        XCTAssertTrue(pendingChanges.contains(
            SyncChange(entityType: "tag", entityID: duplicateID, changeType: "delete")
        ))
    }

    func testAssignTagsToPageAndLoadPageIDsForTag() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let repository = TagRepository(database: database)
        let tag = try repository.createTag(workspaceID: workspaceID, name: "Writing")

        try repository.assignTags(pageID: pageID, tagIDs: [tag.id])

        XCTAssertEqual(try repository.tagAssignments(), [PageTagAssignment(pageID: pageID, tagID: tag.id)])
        XCTAssertEqual(try repository.pageIDs(tagID: tag.id), [pageID])
    }

    func testTagCreateAssignAndRemoveQueueSyncChanges() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let repository = TagRepository(database: database)
        let syncRepository = SyncRepository(database: database)

        let tag = try repository.createTag(workspaceID: workspaceID, name: "Writing")
        try repository.assignTags(pageID: pageID, tagIDs: [tag.id])
        try repository.assignTags(pageID: pageID, tagIDs: [])

        XCTAssertTrue(try syncRepository.pendingChanges().contains(
            SyncChange(entityType: "tag", entityID: tag.id, changeType: "create")
        ))
        XCTAssertTrue(try syncRepository.pendingChanges().contains(
            SyncChange(entityType: "pageTag", entityID: "\(pageID).\(tag.id)", changeType: "create")
        ))
        XCTAssertTrue(try syncRepository.pendingChanges().contains(
            SyncChange(entityType: "pageTag", entityID: "\(pageID).\(tag.id)", changeType: "delete")
        ))
    }

    func testDeleteTagRemovesChildrenAndAssignments() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let repository = TagRepository(database: database)
        let parent = try repository.createTag(workspaceID: workspaceID, name: "Work")
        let child = try repository.createTag(workspaceID: workspaceID, parentTagID: parent.id, name: "PL")
        try repository.assignTags(pageID: pageID, tagIDs: [child.id])

        try repository.deleteTag(id: parent.id)

        XCTAssertEqual(try repository.tags(workspaceID: workspaceID), [])
        XCTAssertEqual(try repository.tagAssignments(), [])
        XCTAssertEqual(try repository.pageIDs(tagID: child.id), [])
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
}
