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
