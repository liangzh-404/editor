# Block-First Information Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the visible Notebook-first editor flow with a block-first writing flow: launch into a fast diary editor, show normal pages in All Documents sorted by update time, organize pages with nested tags, and promote selected diary text into a page with `Cmd+]`.

**Architecture:** Keep the existing SQLite, PageRepository, WorkspaceViewModel, SearchRepository, NativeTextBlockEditor, and SwiftUI shell foundations. Add focused tag and diary storage boundaries, then move the shell's primary navigation to Diary, All Documents, Favorites, Tags, Search, and Archive while leaving existing Notebook rows as compatibility data behind the visible route.

**Tech Stack:** Swift 6, SwiftUI, XCTest, SQLite3 FTS5, native AppKit/UIKit text wrappers, macOS UI automation through `EditorMacUITests`, cached UI test loop through `scripts/mac_ui_test.sh`.

---

## Source Spec

- `docs/superpowers/specs/2026-05-16-block-first-information-architecture-design.md`

## File Structure

- Modify `Sources/EditorCore/Store/SchemaMigrator.swift`: bump schema version and add `tags`, `page_tags`, `diary_entries`, and `page_origin`.
- Modify `Sources/EditorCore/Models/EditorModels.swift`: add `TagSummary`, `PageTagAssignment`, `DiaryEntrySnapshot`, and snapshot arrays for tags and active diary entry.
- Create `Sources/EditorCore/Store/TagRepository.swift`: tag creation, nested loading, page assignment, and tag-filtered page IDs.
- Create `Sources/EditorCore/Store/DiaryRepository.swift`: active diary entry loading, text persistence, FTS indexing hooks, and text-only promotion into a page.
- Modify `Sources/EditorCore/Store/PageRepository.swift`: load pages for All Documents sorted by `updated_at DESC`, load tags into `WorkspaceSnapshot`, keep Notebook data loadable, and expose promoted-page insertion helpers if `DiaryRepository` delegates page/block creation.
- Modify `Sources/EditorCore/Store/SearchRepository.swift`: index and return diary search results with a diary-specific result type.
- Modify `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`: add collection selection state, All Documents rows, tag selection, active diary text, diary save, and promotion commands.
- Modify `Sources/EditorCore/Features/Shell/EditorShellView.swift`: replace visible Notebook-first navigation with Diary, All Documents, Favorites, Tags, Search, and Archive.
- Modify `Sources/EditorCore/Features/Editing/NativeTextBlockEditor.swift`: route `Cmd+]` from focused diary editing through a dedicated promotion callback.
- Modify `Sources/EditorApp/AppEnvironment.swift`: construct and pass `TagRepository` and `DiaryRepository`.
- Modify `Sources/EditorApp/EditorApp.swift`: add a menu command for Promote to Page where the focused diary editor can receive it.
- Test `Tests/EditorTests/SchemaMigratorTests.swift`: schema additions.
- Test `Tests/EditorTests/TagRepositoryTests.swift`: tag CRUD, nesting, and assignments.
- Test `Tests/EditorTests/DiaryRepositoryTests.swift`: diary persistence, exclusion from documents/tags, search indexing, and promotion.
- Test `Tests/EditorTests/PageRepositoryTests.swift`: All Documents ordering and compatibility behavior.
- Test `Tests/EditorTests/SearchRepositoryTests.swift`: diary result type and existing page/block result regressions.
- Test `Tests/EditorTests/WorkspaceViewModelTests.swift`: collection state, diary launch state, tag filtering, and promotion.
- Test `Tests/EditorMacUITests/EditorMacEditingUITests.swift`: launch-to-diary typing, All Documents ordering, and `Cmd+]` promotion UI.
- Update `docs/superpowers/2026-05-12-full-feature-implementation-audit.md`: replace the next-slice list with this plan's sequence as tasks land.

## Task 1: Schema And Models

**Files:**
- Modify: `Sources/EditorCore/Store/SchemaMigrator.swift`
- Modify: `Sources/EditorCore/Models/EditorModels.swift`
- Test: `Tests/EditorTests/SchemaMigratorTests.swift`

- [x] **Step 1: Write failing schema tests**

Add these tests to `Tests/EditorTests/SchemaMigratorTests.swift`:

```swift
func testMigrationCreatesTagAndDiaryTables() throws {
    let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
    defer { database.close() }

    try SchemaMigrator.migrate(database: database)

    let tableNames = Set(try database.queryStrings(
        "SELECT name FROM sqlite_master WHERE type = 'table'"
    ))

    XCTAssertTrue(tableNames.contains("tags"))
    XCTAssertTrue(tableNames.contains("page_tags"))
    XCTAssertTrue(tableNames.contains("diary_entries"))
    XCTAssertTrue(tableNames.contains("page_origin"))
}

func testTagAndDiaryTablesExposeRequiredColumns() throws {
    let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
    defer { database.close() }

    try SchemaMigrator.migrate(database: database)

    let tagColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('tags')"))
    let pageTagColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('page_tags')"))
    let diaryColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('diary_entries')"))
    let pageOriginColumns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('page_origin')"))

    XCTAssertTrue(tagColumns.isSuperset(of: ["id", "workspace_id", "parent_tag_id", "name", "order_key", "created_at", "updated_at"]))
    XCTAssertTrue(pageTagColumns.isSuperset(of: ["page_id", "tag_id", "created_at"]))
    XCTAssertTrue(diaryColumns.isSuperset(of: ["id", "workspace_id", "text_plain", "created_at", "updated_at"]))
    XCTAssertTrue(pageOriginColumns.isSuperset(of: ["page_id", "promoted_from_diary_entry_id", "created_at"]))
}
```

- [x] **Step 2: Run tests and verify RED**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/SchemaMigratorTests/testMigrationCreatesTagAndDiaryTables -only-testing:EditorTests/SchemaMigratorTests/testTagAndDiaryTablesExposeRequiredColumns
```

Expected: FAIL because `tags`, `page_tags`, `diary_entries`, and `page_origin` do not exist.

- [x] **Step 3: Implement schema migration**

In `Sources/EditorCore/Store/SchemaMigrator.swift`:

```swift
static let currentVersion = 8
```

Add `CREATE TABLE IF NOT EXISTS` statements for:

```sql
CREATE TABLE IF NOT EXISTS tags (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    parent_tag_id TEXT,
    name TEXT NOT NULL,
    order_key TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS page_tags (
    page_id TEXT NOT NULL,
    tag_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY (page_id, tag_id),
    FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS diary_entries (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    text_plain TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS page_origin (
    page_id TEXT PRIMARY KEY,
    promoted_from_diary_entry_id TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE,
    FOREIGN KEY (promoted_from_diary_entry_id) REFERENCES diary_entries(id) ON DELETE SET NULL
);
```

In `Sources/EditorCore/Models/EditorModels.swift`, add:

```swift
struct TagSummary: Identifiable, Equatable, Sendable {
    let id: String
    let workspaceID: String
    let parentTagID: String?
    let name: String
    let path: String
}

struct PageTagAssignment: Equatable, Sendable {
    let pageID: String
    let tagID: String
}

struct DiaryEntrySnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let workspaceID: String
    let textPlain: String
}
```

Extend `WorkspaceSnapshot` with:

```swift
let tags: [TagSummary]
let pageTags: [PageTagAssignment]
let activeDiaryEntry: DiaryEntrySnapshot?
```

Update all `WorkspaceSnapshot` initializers and replacement helpers to preserve the three new properties.

- [x] **Step 4: Run tests and verify GREEN**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/SchemaMigratorTests/testMigrationCreatesTagAndDiaryTables -only-testing:EditorTests/SchemaMigratorTests/testTagAndDiaryTablesExposeRequiredColumns -only-testing:EditorTests/SchemaMigratorTests/testMigrationRecordsSchemaVersionOne
```

Expected: PASS with schema version equal to `8`.

- [x] **Step 5: Commit**

Run:

```bash
git add Sources/EditorCore/Store/SchemaMigrator.swift Sources/EditorCore/Models/EditorModels.swift Tests/EditorTests/SchemaMigratorTests.swift
git commit -m "Add block-first schema models"
```

## Task 2: Tags Repository

**Files:**
- Create: `Sources/EditorCore/Store/TagRepository.swift`
- Modify: `Sources/EditorCore/Models/EditorModels.swift`
- Test: `Tests/EditorTests/TagRepositoryTests.swift`

- [x] **Step 1: Write failing tag repository tests**

Create `Tests/EditorTests/TagRepositoryTests.swift`:

```swift
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
```

- [x] **Step 2: Run tests and verify RED**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/TagRepositoryTests
```

Expected: FAIL because `TagRepository` is not implemented.

- [x] **Step 3: Implement TagRepository**

Create `Sources/EditorCore/Store/TagRepository.swift` with:

```swift
import Foundation

final class TagRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func createTag(workspaceID: String, parentTagID: String? = nil, name: String) throws -> TagSummary {
        let now = ISO8601DateFormatter().string(from: Date())
        let tagID = "tag-\(UUID().uuidString.lowercased())"
        let orderKey = try nextTagOrderKey(workspaceID: workspaceID, parentTagID: parentTagID)
        try database.execute(
            """
            INSERT INTO tags (id, workspace_id, parent_tag_id, name, order_key, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(tagID),
                .text(workspaceID),
                parentTagID.map(SQLiteValue.text) ?? .null,
                .text(name),
                .text(orderKey),
                .text(now),
                .text(now)
            ]
        )
        return try tags(workspaceID: workspaceID).first { $0.id == tagID } ?? TagSummary(
            id: tagID,
            workspaceID: workspaceID,
            parentTagID: parentTagID,
            name: name,
            path: name
        )
    }

    func tags(workspaceID: String) throws -> [TagSummary] {
        let rows = try database.query(
            """
            SELECT id, workspace_id, parent_tag_id, name, order_key
            FROM tags
            WHERE workspace_id = ?
            ORDER BY order_key ASC
            """,
            bindings: [.text(workspaceID)]
        )
        let rawTags = rows.map { row in
            TagSummary(
                id: row["id"] ?? "",
                workspaceID: row["workspace_id"] ?? "",
                parentTagID: row["parent_tag_id"] ?? nil,
                name: row["name"] ?? "",
                path: row["name"] ?? ""
            )
        }
        return rawTags.map { tag in
            TagSummary(
                id: tag.id,
                workspaceID: tag.workspaceID,
                parentTagID: tag.parentTagID,
                name: tag.name,
                path: Self.path(for: tag, in: rawTags)
            )
        }.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    func assignTags(pageID: String, tagIDs: [String]) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try database.withImmediateTransaction("page_tags_assign") {
            try database.execute("DELETE FROM page_tags WHERE page_id = ?", bindings: [.text(pageID)])
            for tagID in tagIDs {
                try database.execute(
                    "INSERT INTO page_tags (page_id, tag_id, created_at) VALUES (?, ?, ?)",
                    bindings: [.text(pageID), .text(tagID), .text(now)]
                )
            }
        }
    }

    func tagAssignments() throws -> [PageTagAssignment] {
        try database.query(
            """
            SELECT page_id, tag_id
            FROM page_tags
            ORDER BY page_id ASC, tag_id ASC
            """
        ).map { row in
            PageTagAssignment(pageID: row["page_id"] ?? "", tagID: row["tag_id"] ?? "")
        }
    }

    func pageIDs(tagID: String) throws -> [String] {
        try database.query(
            """
            SELECT page_id
            FROM page_tags
            WHERE tag_id = ?
            ORDER BY created_at ASC
            """,
            bindings: [.text(tagID)]
        ).compactMap { $0["page_id"] }
    }

    private func nextTagOrderKey(workspaceID: String, parentTagID: String?) throws -> String {
        let rows = try database.query(
            """
            SELECT order_key
            FROM tags
            WHERE workspace_id = ? AND parent_tag_id IS ?
            ORDER BY order_key DESC
            LIMIT 1
            """,
            bindings: [.text(workspaceID), parentTagID.map(SQLiteValue.text) ?? .null]
        )
        let last = Int(rows.first?["order_key"] ?? "0") ?? 0
        return String(format: "%06d", last + 1)
    }

    private static func path(for tag: TagSummary, in tags: [TagSummary]) -> String {
        guard let parentTagID = tag.parentTagID,
              let parent = tags.first(where: { $0.id == parentTagID }) else {
            return tag.name
        }
        return "\(path(for: parent, in: tags))/\(tag.name)"
    }
}
```

- [x] **Step 4: Run tests and verify GREEN**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/TagRepositoryTests
```

Expected: PASS.

- [x] **Step 5: Commit**

Run:

```bash
git add Sources/EditorCore/Store/TagRepository.swift Sources/EditorCore/Models/EditorModels.swift Tests/EditorTests/TagRepositoryTests.swift
git commit -m "Add tag repository"
```

## Task 3: All Documents Ordering

**Files:**
- Modify: `Sources/EditorCore/Store/PageRepository.swift`
- Modify: `Sources/EditorCore/Models/EditorModels.swift`
- Test: `Tests/EditorTests/PageRepositoryTests.swift`

- [x] **Step 1: Write failing All Documents tests**

Add to `Tests/EditorTests/PageRepositoryTests.swift`:

```swift
func testLoadWorkspaceSnapshotOrdersActivePagesByUpdatedTimeDescending() throws {
    let database = try migratedDatabase()
    defer { database.close() }
    let repository = PageRepository(database: database)
    let snapshot = try repository.bootstrapWorkspaceIfNeeded()
    let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)

    let older = try repository.createPage(workspaceID: workspaceID, title: "Older")
    Thread.sleep(forTimeInterval: 0.01)
    let newer = try repository.createPage(workspaceID: workspaceID, title: "Newer")
    try repository.updatePageTitle(pageID: older.id, title: "Older updated last")

    let reloaded = try repository.loadWorkspaceSnapshot()

    XCTAssertEqual(reloaded.pages.map(\.title).prefix(2), ["Older updated last", "Newer"])
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
```

- [x] **Step 2: Run tests and verify RED**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/PageRepositoryTests/testLoadWorkspaceSnapshotOrdersActivePagesByUpdatedTimeDescending -only-testing:EditorTests/PageRepositoryTests/testLoadWorkspaceSnapshotLoadsTagsAndAssignments
```

Expected: FAIL because `loadWorkspaceSnapshot()` still orders pages by Notebook/order key and does not load tags into the snapshot.

- [x] **Step 3: Implement All Documents snapshot loading**

In `PageRepository.loadWorkspaceSnapshot()`:

- Change the active pages SQL `ORDER BY` to:

```sql
ORDER BY pages.updated_at DESC, pages.created_at DESC
```

- Load tags through `TagRepository(database: database).tags(workspaceID:)`.
- Load page tag assignments through `TagRepository(database: database).tagAssignments()`.
- Populate the new `WorkspaceSnapshot` properties.
- Keep `notebooks` loading unchanged so compatibility tests continue to pass.

- [x] **Step 4: Run tests and verify GREEN**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/PageRepositoryTests/testLoadWorkspaceSnapshotOrdersActivePagesByUpdatedTimeDescending -only-testing:EditorTests/PageRepositoryTests/testLoadWorkspaceSnapshotLoadsTagsAndAssignments -only-testing:EditorTests/PageRepositoryTests/testBootstrapCreatesDefaultWorkspacePageAndParagraphBlock
```

Expected: PASS.

- [x] **Step 5: Commit**

Run:

```bash
git add Sources/EditorCore/Store/PageRepository.swift Sources/EditorCore/Models/EditorModels.swift Tests/EditorTests/PageRepositoryTests.swift
git commit -m "Load all documents by update time"
```

## Task 4: Diary Repository

**Files:**
- Create: `Sources/EditorCore/Store/DiaryRepository.swift`
- Modify: `Sources/EditorCore/Models/EditorModels.swift`
- Test: `Tests/EditorTests/DiaryRepositoryTests.swift`

- [x] **Step 1: Write failing diary tests**

Create `Tests/EditorTests/DiaryRepositoryTests.swift`:

```swift
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

    func testActiveDiaryEntryPersistsTextWithoutCreatingDocumentPage() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let repository = DiaryRepository(database: database)

        let entry = try repository.activeEntry(workspaceID: workspaceID)
        try repository.updateEntryText(entryID: entry.id, text: "Fast capture")

        let reloadedEntry = try repository.activeEntry(workspaceID: workspaceID)
        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()

        XCTAssertEqual(reloadedEntry.textPlain, "Fast capture")
        XCTAssertFalse(reloadedSnapshot.pages.contains { $0.title == "Fast capture" })
    }

    func testPromoteSelectedDiaryTextCreatesPageAndKeepsDiaryText() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let repository = DiaryRepository(database: database)
        let entry = try repository.activeEntry(workspaceID: workspaceID)
        try repository.updateEntryText(entryID: entry.id, text: "Alpha capture Beta")

        let page = try repository.promoteTextToPage(entryID: entry.id, selectedText: "Alpha capture")
        let reloadedEntry = try repository.activeEntry(workspaceID: workspaceID)
        let blocks = try pageRepository.loadWorkspaceSnapshot().blocks.filter { $0.pageID == page.id }

        XCTAssertEqual(page.title, "Alpha capture")
        XCTAssertEqual(blocks.map(\.textPlain), ["Alpha capture"])
        XCTAssertEqual(reloadedEntry.textPlain, "Alpha capture Beta")
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
```

- [x] **Step 2: Run tests and verify RED**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/DiaryRepositoryTests
```

Expected: FAIL because `DiaryRepository` is not implemented.

- [x] **Step 3: Implement DiaryRepository**

Create `Sources/EditorCore/Store/DiaryRepository.swift` with methods:

```swift
final class DiaryRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func activeEntry(workspaceID: String) throws -> DiaryEntrySnapshot
    func updateEntryText(entryID: String, text: String) throws
    func promoteTextToPage(entryID: String, selectedText: String) throws -> PageSummary
}
```

Implementation rules:

- `activeEntry(workspaceID:)` returns the newest diary entry or inserts an empty one.
- `updateEntryText(entryID:text:)` updates `diary_entries.text_plain` and `updated_at`.
- `promoteTextToPage(entryID:selectedText:)` trims selected text, creates a page through `PageRepository.createPage`, replaces the page's initial empty block text with the selected text, writes `page_origin`, and preserves the diary entry text.
- Empty selected text throws `PageRepositoryError.emptyTitle` if that error exists; otherwise introduce `DiaryRepositoryError.emptySelection`.

- [x] **Step 4: Run tests and verify GREEN**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/DiaryRepositoryTests
```

Expected: PASS.

- [x] **Step 5: Commit**

Run:

```bash
git add Sources/EditorCore/Store/DiaryRepository.swift Tests/EditorTests/DiaryRepositoryTests.swift
git commit -m "Add diary repository"
```

## Task 5: Diary Search And Document Exclusion

**Files:**
- Modify: `Sources/EditorCore/Store/SearchRepository.swift`
- Modify: `Sources/EditorCore/Store/DiaryRepository.swift`
- Test: `Tests/EditorTests/SearchRepositoryTests.swift`
- Test: `Tests/EditorTests/DiaryRepositoryTests.swift`

- [x] **Step 1: Write failing search tests**

Add to `Tests/EditorTests/SearchRepositoryTests.swift`:

```swift
func testSearchFindsDiaryEntriesWithDiaryResultType() throws {
    let database = try migratedDatabase()
    defer { database.close() }
    let pageRepository = PageRepository(database: database)
    let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
    let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
    let diaryRepository = DiaryRepository(database: database)
    let entry = try diaryRepository.activeEntry(workspaceID: workspaceID)
    try diaryRepository.updateEntryText(entryID: entry.id, text: "Private searchable diary capture")

    let results = try SearchRepository(database: database).search("private searchable")

    XCTAssertEqual(results.first?.entityType, "diary")
    XCTAssertEqual(results.first?.entityID, entry.id)
    XCTAssertNil(results.first?.destinationPageID)
}
```

Add to `Tests/EditorTests/DiaryRepositoryTests.swift`:

```swift
func testDiaryTextDoesNotAppearInAllDocumentsAfterSearchIndexing() throws {
    let database = try migratedDatabase()
    defer { database.close() }
    let pageRepository = PageRepository(database: database)
    let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
    let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
    let diaryRepository = DiaryRepository(database: database)
    let entry = try diaryRepository.activeEntry(workspaceID: workspaceID)
    try diaryRepository.updateEntryText(entryID: entry.id, text: "Diary-only text")

    let reloaded = try pageRepository.loadWorkspaceSnapshot()

    XCTAssertFalse(reloaded.pages.contains { $0.title.contains("Diary-only") })
    XCTAssertFalse(reloaded.blocks.contains { $0.textPlain.contains("Diary-only") })
}
```

- [x] **Step 2: Run tests and verify RED**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/SearchRepositoryTests/testSearchFindsDiaryEntriesWithDiaryResultType -only-testing:EditorTests/DiaryRepositoryTests/testDiaryTextDoesNotAppearInAllDocumentsAfterSearchIndexing
```

Expected: FAIL because diary entries are not indexed.

- [x] **Step 3: Implement diary indexing**

In `SearchRepository`:

- Add `indexDiaryEntries()` called by `rebuildIndex()`.
- Add `updateDiaryEntryIndex(entryID:)`.
- Teach `search(_:)` to map `entity_type = 'diary'` to `SearchResult(entityType: "diary", entityID: entryID, title: "Diary", snippet: ..., destinationPageID: nil)`.

In `DiaryRepository.updateEntryText`, call `SearchRepository(database: database).updateDiaryEntryIndex(entryID:)` after the diary row update.

- [x] **Step 4: Run tests and verify GREEN**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/SearchRepositoryTests/testSearchFindsDiaryEntriesWithDiaryResultType -only-testing:EditorTests/DiaryRepositoryTests/testDiaryTextDoesNotAppearInAllDocumentsAfterSearchIndexing -only-testing:EditorTests/SearchRepositoryTests/testSearchFindsBlockText
```

Expected: PASS.

- [x] **Step 5: Commit**

Run:

```bash
git add Sources/EditorCore/Store/SearchRepository.swift Sources/EditorCore/Store/DiaryRepository.swift Tests/EditorTests/SearchRepositoryTests.swift Tests/EditorTests/DiaryRepositoryTests.swift
git commit -m "Index diary text in search"
```

## Task 6: WorkspaceViewModel Block-First State

**Files:**
- Modify: `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`
- Modify: `Sources/EditorApp/AppEnvironment.swift`
- Test: `Tests/EditorTests/WorkspaceViewModelTests.swift`

- [x] **Step 1: Write failing view-model tests**

Add to `WorkspaceViewModelTests`:

```swift
@MainActor
func testLoadStartsInDiaryModeWithActiveDiaryEntry() throws {
    let database = try migratedDatabase()
    defer { database.close() }
    let repository = PageRepository(database: database)
    _ = try repository.bootstrapWorkspaceIfNeeded()
    let viewModel = WorkspaceViewModel(
        repository: repository,
        diaryRepository: DiaryRepository(database: database)
    )

    try viewModel.load()

    XCTAssertEqual(viewModel.selectedCollection, .diary)
    XCTAssertNotNil(viewModel.activeDiaryEntry)
    XCTAssertNil(viewModel.selectedPageID)
}

@MainActor
func testPromoteSelectedDiaryTextSelectsNewPageAndShowsAllDocuments() throws {
    let database = try migratedDatabase()
    defer { database.close() }
    let repository = PageRepository(database: database)
    _ = try repository.bootstrapWorkspaceIfNeeded()
    let viewModel = WorkspaceViewModel(
        repository: repository,
        diaryRepository: DiaryRepository(database: database)
    )
    try viewModel.load()
    try viewModel.updateDiaryText("Promote me now")

    try viewModel.promoteSelectedDiaryTextToPage("Promote me")

    XCTAssertEqual(viewModel.selectedCollection, .allDocuments)
    XCTAssertEqual(viewModel.selectedPage?.title, "Promote me")
    XCTAssertEqual(viewModel.visibleBlocks.map(\.textPlain), ["Promote me"])
}
```

- [x] **Step 2: Run tests and verify RED**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/WorkspaceViewModelTests/testLoadStartsInDiaryModeWithActiveDiaryEntry -only-testing:EditorTests/WorkspaceViewModelTests/testPromoteSelectedDiaryTextSelectsNewPageAndShowsAllDocuments
```

Expected: FAIL because `WorkspaceViewModel` has no diary collection state.

- [x] **Step 3: Implement view-model state**

In `WorkspaceViewModel.swift`, add:

```swift
enum WorkspaceCollection: Equatable, Sendable {
    case diary
    case allDocuments
    case favorites
    case tag(String)
    case search
    case archive
}
```

Add published properties:

```swift
@Published private(set) var selectedCollection: WorkspaceCollection = .diary
@Published private(set) var activeDiaryEntry: DiaryEntrySnapshot?
```

Extend initializer with:

```swift
private let diaryRepository: DiaryRepository?
```

Add methods:

```swift
func selectCollection(_ collection: WorkspaceCollection)
func updateDiaryText(_ text: String) throws
func promoteSelectedDiaryTextToPage(_ selectedText: String) throws
```

Rules:

- `load()` sets `selectedCollection = .diary`, loads active diary entry, and clears `selectedPageID`.
- Selecting a page sets `selectedCollection = .allDocuments`.
- Promotion calls `DiaryRepository.promoteTextToPage`, reloads snapshot, selects the new page, and sets `selectedCollection = .allDocuments`.

In `AppEnvironment.swift`, construct `DiaryRepository(database:)` and pass it into `WorkspaceViewModel`.

- [x] **Step 4: Run tests and verify GREEN**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/WorkspaceViewModelTests/testLoadStartsInDiaryModeWithActiveDiaryEntry -only-testing:EditorTests/WorkspaceViewModelTests/testPromoteSelectedDiaryTextSelectsNewPageAndShowsAllDocuments
```

Expected: PASS.

- [x] **Step 5: Commit**

Run:

```bash
git add Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift Sources/EditorApp/AppEnvironment.swift Tests/EditorTests/WorkspaceViewModelTests.swift
git commit -m "Add diary-first workspace state"
```

## Task 7: Shell UI For Diary And All Documents

**Files:**
- Modify: `Sources/EditorCore/Features/Shell/EditorShellView.swift`
- Test: `Tests/EditorMacUITests/EditorMacEditingUITests.swift`

- [x] **Step 1: Write failing macOS UI tests**

Add to `EditorMacEditingUITests`:

```swift
@MainActor
func testLaunchStartsInBlankDiaryEditorForFastTyping() {
    let app = XCUIApplication()
    app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
    app.launch()

    let diaryEditor = app.textViews["editor.diary.text"]
    XCTAssertTrue(diaryEditor.waitForExistence(timeout: 5), "Launch should expose the diary editor")
    diaryEditor.click()
    app.typeText("Captured immediately")

    XCTAssertTrue(
        diaryEditor.waitForValue(containing: "Captured immediately", timeout: 5),
        "Typing after launch should write into diary"
    )
}

@MainActor
func testAllDocumentsListShowsPagesSortedByUpdatedTime() {
    let app = XCUIApplication()
    app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
    app.launchEnvironment["EDITOR_UI_TEST_FAVORITE_PAGE"] = "1"
    app.launch()

    let allDocuments = app.buttons["editor.collection.all-documents"]
    XCTAssertTrue(allDocuments.waitForExistence(timeout: 5), "All Documents should be visible in the rail")
    allDocuments.click()

    let welcome = app.staticTexts["editor.page-row.page-welcome"]
    XCTAssertTrue(welcome.waitForExistence(timeout: 5), "Existing pages should appear in All Documents")
}
```

- [x] **Step 2: Run tests and verify RED**

Run:

```bash
scripts/mac_ui_test.sh test testLaunchStartsInBlankDiaryEditorForFastTyping testAllDocumentsListShowsPagesSortedByUpdatedTime
```

Expected: FAIL because the shell still opens with Notebook page navigation and no diary editor.

- [x] **Step 3: Implement visible shell route**

In `EditorShellView.swift`:

- Replace the visible `WorkspaceSidebar` sections with rail buttons for Diary, All Documents, Favorites, Tags, Search, and Archive.
- Give rail buttons these identifiers:
  - `editor.collection.diary`
  - `editor.collection.all-documents`
  - `editor.collection.favorites`
  - `editor.collection.tags`
  - `editor.collection.search`
  - `editor.collection.archive`
- Rename the visible middle-column title to `All Documents` when that collection is active.
- Render `PageRow` directly from `viewModel.snapshot.pages` for All Documents.
- Keep Archive and Favorites behavior connected to existing page state.
- Add `DiaryEditorView` with a text editor identifier `editor.diary.text`.
- Use native text editing when practical; if reusing `NativeTextBlockEditor` requires a block-shaped adapter, create a local diary text wrapper view that preserves multiline typing and keyboard command forwarding.

- [x] **Step 4: Run tests and verify GREEN**

Run:

```bash
scripts/mac_ui_test.sh run testLaunchStartsInBlankDiaryEditorForFastTyping testAllDocumentsListShowsPagesSortedByUpdatedTime
```

Expected: PASS.

- [x] **Step 5: Commit**

Run:

```bash
git add Sources/EditorCore/Features/Shell/EditorShellView.swift Tests/EditorMacUITests/EditorMacEditingUITests.swift
git commit -m "Show diary-first shell"
```

## Task 8: Cmd+] Text Promotion

**Files:**
- Modify: `Sources/EditorCore/Features/Editing/NativeTextBlockEditor.swift`
- Modify: `Sources/EditorCore/Features/Shell/EditorShellView.swift`
- Modify: `Sources/EditorApp/EditorApp.swift`
- Test: `Tests/EditorTests/NativeTextBlockEditorTests.swift`
- Test: `Tests/EditorMacUITests/EditorMacEditingUITests.swift`

- [ ] **Step 1: Write failing command resolver test**

Add to `NativeTextBlockEditorTests`:

```swift
func testDiaryPromotionKeyboardResolverHandlesCommandRightBracketOnly() {
    XCTAssertTrue(
        DiaryPromotionKeyboardResolver.requestsPromotion(
            input: "]",
            modifiers: [.command]
        )
    )
    XCTAssertFalse(
        DiaryPromotionKeyboardResolver.requestsPromotion(
            input: "]",
            modifiers: []
        )
    )
    XCTAssertFalse(
        DiaryPromotionKeyboardResolver.requestsPromotion(
            input: "[",
            modifiers: [.command]
        )
    )
}
```

Add to `EditorMacEditingUITests`:

```swift
@MainActor
func testCommandRightBracketPromotesSelectedDiaryTextToPage() {
    let app = XCUIApplication()
    app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
    app.launch()

    let diaryEditor = app.textViews["editor.diary.text"]
    XCTAssertTrue(diaryEditor.waitForExistence(timeout: 5), "Diary editor should be visible at launch")
    diaryEditor.click()
    app.typeText("Promote this text")
    diaryEditor.typeKey("a", modifierFlags: [.command])
    diaryEditor.typeKey("]", modifierFlags: [.command])

    let pageTitle = app.textFields["editor.page-title"]
    XCTAssertTrue(
        pageTitle.waitForValue(equalTo: "Promote this text", timeout: 5),
        "Cmd+] should create and open a page from selected diary text"
    )

    let promotedBlock = app.textViews
        .matching(NSPredicate(format: "value CONTAINS %@", "Promote this text"))
        .firstMatch
    XCTAssertTrue(promotedBlock.waitForExistence(timeout: 5))
}
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/NativeTextBlockEditorTests/testDiaryPromotionKeyboardResolverHandlesCommandRightBracketOnly
scripts/mac_ui_test.sh test testCommandRightBracketPromotesSelectedDiaryTextToPage
```

Expected: FAIL because `DiaryPromotionKeyboardResolver` and UI promotion route do not exist.

- [ ] **Step 3: Implement promotion command path**

Add resolver near other keyboard resolvers:

```swift
enum DiaryPromotionKeyboardResolver {
    static func requestsPromotion(
        input: String?,
        modifiers: Set<BlockKeyboardShortcutModifier>
    ) -> Bool {
        modifiers == [.command] && input == "]"
    }
}
```

In the diary editor key handling path:

- Detect `Cmd+]`.
- Read the current selected text from the native text view.
- Call `WorkspaceViewModel.promoteSelectedDiaryTextToPage(_:)`.
- Return `true` from the key handler after successful command routing.

In `EditorApp.swift`, add a menu command labeled `Promote to Page` with `.keyboardShortcut("]", modifiers: [.command])` that calls the same focused diary action.

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/NativeTextBlockEditorTests/testDiaryPromotionKeyboardResolverHandlesCommandRightBracketOnly
scripts/mac_ui_test.sh run testCommandRightBracketPromotesSelectedDiaryTextToPage
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/EditorCore/Features/Editing/NativeTextBlockEditor.swift Sources/EditorCore/Features/Shell/EditorShellView.swift Sources/EditorApp/EditorApp.swift Tests/EditorTests/NativeTextBlockEditorTests.swift Tests/EditorMacUITests/EditorMacEditingUITests.swift
git commit -m "Promote diary text to page"
```

## Task 9: Tag UI For Pages

**Files:**
- Modify: `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`
- Modify: `Sources/EditorCore/Features/Shell/EditorShellView.swift`
- Test: `Tests/EditorTests/WorkspaceViewModelTests.swift`
- Test: `Tests/EditorMacUITests/EditorMacEditingUITests.swift`

- [ ] **Step 1: Write failing tag UI tests**

Add to `WorkspaceViewModelTests`:

```swift
@MainActor
func testAssignTagToSelectedPageFiltersAllDocumentsByTag() throws {
    let database = try migratedDatabase()
    defer { database.close() }
    let repository = PageRepository(database: database)
    let snapshot = try repository.bootstrapWorkspaceIfNeeded()
    let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
    let pageID = try XCTUnwrap(snapshot.selectedPageID)
    let tagRepository = TagRepository(database: database)
    let tag = try tagRepository.createTag(workspaceID: workspaceID, name: "Writing")
    let viewModel = WorkspaceViewModel(repository: repository, tagRepository: tagRepository)
    try viewModel.load()
    viewModel.selectPage(id: pageID)

    try viewModel.assignTagsToSelectedPage([tag.id])
    viewModel.selectCollection(.tag(tag.id))

    XCTAssertEqual(viewModel.visibleDocumentPages.map(\.id), [pageID])
}
```

Add to `EditorMacEditingUITests`:

```swift
@MainActor
func testPageRowsExposeTagChipsInAllDocuments() {
    let app = XCUIApplication()
    app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
    app.launchEnvironment["EDITOR_UI_TEST_TAGGED_PAGE"] = "1"
    app.launch()

    app.buttons["editor.collection.all-documents"].click()
    let pageRow = app.staticTexts["editor.page-row.page-welcome"]
    XCTAssertTrue(pageRow.waitForExistence(timeout: 5))
    XCTAssertTrue(pageRow.waitForLabelOrValue(containing: "Writing", timeout: 5))
}
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/WorkspaceViewModelTests/testAssignTagToSelectedPageFiltersAllDocumentsByTag
scripts/mac_ui_test.sh test testPageRowsExposeTagChipsInAllDocuments
```

Expected: FAIL because page tag assignment is not exposed through the view model or UI.

- [ ] **Step 3: Implement tag view-model and row UI**

In `WorkspaceViewModel`:

- Inject `TagRepository`.
- Add `visibleDocumentPages`.
- Add `assignTagsToSelectedPage(_:)`.
- Make `.tag(tagID)` filter `snapshot.pages` through `snapshot.pageTags`.

In `EditorShellView`:

- Show tag rows under the Tags rail section using `snapshot.tags`.
- Show compact tag chips in `PageRow`.
- Add DEBUG fixture seeding in `AppEnvironment` for `EDITOR_UI_TEST_TAGGED_PAGE=1`.

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/WorkspaceViewModelTests/testAssignTagToSelectedPageFiltersAllDocumentsByTag
scripts/mac_ui_test.sh run testPageRowsExposeTagChipsInAllDocuments
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift Sources/EditorCore/Features/Shell/EditorShellView.swift Sources/EditorApp/AppEnvironment.swift Tests/EditorTests/WorkspaceViewModelTests.swift Tests/EditorMacUITests/EditorMacEditingUITests.swift
git commit -m "Expose document tags in shell"
```

## Task 10: Final Regression Sweep

**Files:**
- Modify: `docs/superpowers/2026-05-12-full-feature-implementation-audit.md`

- [ ] **Step 1: Update audit evidence**

Update the audit with:

- Block-first information architecture implemented.
- All Documents replaces visible Notebook-first page list.
- Diary launch-to-type behavior.
- Diary search inclusion and document/tag exclusion.
- Text-only diary promotion through `Cmd+]`.
- Tag creation, nesting, assignment, and filtering.

- [ ] **Step 2: Run focused unit suite**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/SchemaMigratorTests -only-testing:EditorTests/PageRepositoryTests -only-testing:EditorTests/TagRepositoryTests -only-testing:EditorTests/DiaryRepositoryTests -only-testing:EditorTests/SearchRepositoryTests -only-testing:EditorTests/WorkspaceViewModelTests -only-testing:EditorTests/NativeTextBlockEditorTests
```

Expected: PASS.

- [ ] **Step 3: Run focused macOS UI suite**

Run:

```bash
scripts/mac_ui_test.sh build
scripts/mac_ui_test.sh rerun testLaunchStartsInBlankDiaryEditorForFastTyping testAllDocumentsListShowsPagesSortedByUpdatedTime testCommandRightBracketPromotesSelectedDiaryTextToPage testPageFavoriteToggleUpdatesSidebarAndRowState testMarkdownExportToolbarCapturesCurrentPageMarkdown
```

Expected: PASS.

- [ ] **Step 4: Run app builds**

Run:

```bash
xcodebuild -quiet build -project Editor.xcodeproj -scheme EditorMac -destination 'platform=macOS,arch=arm64'
xcodebuild -quiet build -project Editor.xcodeproj -scheme EditorIOS -destination 'generic/platform=iOS Simulator'
```

Expected: PASS for both builds.

- [ ] **Step 5: Commit audit**

Run:

```bash
git add docs/superpowers/2026-05-12-full-feature-implementation-audit.md
git commit -m "Update block-first implementation audit"
```

## Completion Criteria

- Launching macOS opens a blank diary editor with immediate typing.
- All Documents is the visible document list and is sorted by `updated_at DESC`.
- Notebook navigation is no longer the primary visible organization model.
- Existing pages remain visible in All Documents.
- Existing favorites remain visible and editable.
- Nested tags can be created and assigned to pages.
- Tag filters show matching pages and exclude diary text.
- Diary text persists locally and is searchable.
- Diary text does not appear in All Documents or tag filters.
- `Cmd+]` promotes selected diary text into a new normal page.
- Promoted pages support tags, favorite, search, and Markdown export.
- Focused unit tests, focused macOS UI tests, macOS build, and iOS build pass.

## Self-Review

- Spec coverage: every decision in `2026-05-16-block-first-information-architecture-design.md` maps to Tasks 1 through 10.
- Red-flag scan: no unresolved marker strings or open implementation gaps remain in this plan.
- Type consistency: repositories, model names, view-model methods, commands, and UI identifiers use the same names across tasks.
