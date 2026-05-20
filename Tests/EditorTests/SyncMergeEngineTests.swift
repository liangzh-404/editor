import Foundation
import XCTest

final class SyncMergeEngineTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testRemoteSameBlockConflictKeepsLocalTextAndStoresRemoteVersion() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(blockID: blockID, text: "Local edit")

        try SyncMergeEngine(database: database).applyRemoteBlock(
            RemoteBlockChange(
                blockID: blockID,
                pageID: pageID,
                type: .paragraph,
                textPlain: "Remote edit",
                payloadJSON: "{\"text\":\"Remote edit\"}",
                revision: 2
            )
        )

        XCTAssertEqual(try pageRepository.loadWorkspaceSnapshot().blocks.first?.textPlain, "Local edit")
        XCTAssertEqual(
            try ConflictRepository(database: database).conflicts(blockID: blockID),
            [
                ConflictVersion(
                    blockID: blockID,
                    payloadJSON: "{\"text\":\"Remote edit\"}",
                    textPlain: "Remote edit",
                    remoteRevision: 2
                )
            ]
        )
    }

    func testAcceptRemoteConflictAppliesRemoteTextAndClearsLocalPendingChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(blockID: blockID, text: "Local edit")
        try SyncMergeEngine(database: database).applyRemoteBlock(
            RemoteBlockChange(
                blockID: blockID,
                pageID: pageID,
                type: .paragraph,
                textPlain: "Remote edit",
                payloadJSON: "{\"text\":\"Remote edit\"}",
                revision: 2
            )
        )
        let conflictRepository = ConflictRepository(database: database)
        let conflict = try XCTUnwrap(try conflictRepository.conflicts(pageID: pageID).first)

        let accepted = try conflictRepository.acceptRemoteVersion(conflictID: conflict.id)

        XCTAssertEqual(accepted.blockID, blockID)
        XCTAssertEqual(try pageRepository.loadWorkspaceSnapshot().blocks.first?.textPlain, "Remote edit")
        XCTAssertEqual(try conflictRepository.conflicts(pageID: pageID), [])
        XCTAssertEqual(try SyncRepository(database: database).pendingChanges(), [])
    }

    func testAcceptLocalConflictKeepsLocalTextAndPendingUpdate() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(blockID: blockID, text: "Local edit")
        try SyncMergeEngine(database: database).applyRemoteBlock(
            RemoteBlockChange(
                blockID: blockID,
                pageID: pageID,
                type: .paragraph,
                textPlain: "Remote edit",
                payloadJSON: "{\"text\":\"Remote edit\"}",
                revision: 2
            )
        )
        let conflictRepository = ConflictRepository(database: database)
        let conflict = try XCTUnwrap(try conflictRepository.conflicts(pageID: pageID).first)

        let accepted = try conflictRepository.acceptLocalVersion(conflictID: conflict.id)

        XCTAssertEqual(accepted.blockID, blockID)
        XCTAssertEqual(accepted.localTextPlain, "Local edit")
        XCTAssertEqual(try pageRepository.loadWorkspaceSnapshot().blocks.first?.textPlain, "Local edit")
        XCTAssertEqual(try conflictRepository.conflicts(pageID: pageID), [])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().filter {
                $0 == SyncChange(entityType: "block", entityID: blockID, changeType: "update")
            }.count,
            1
        )
    }

    func testResolveConflictWithManualTextAppliesMergedTextAndKeepsPendingUpdate() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(blockID: blockID, text: "Local edit")
        try SyncMergeEngine(database: database).applyRemoteBlock(
            RemoteBlockChange(
                blockID: blockID,
                pageID: pageID,
                type: .paragraph,
                textPlain: "Remote edit",
                payloadJSON: "{\"text\":\"Remote edit\"}",
                revision: 2
            )
        )
        let conflictRepository = ConflictRepository(database: database)
        let conflict = try XCTUnwrap(try conflictRepository.conflicts(pageID: pageID).first)

        XCTAssertEqual(conflict.localTextPlain, "Local edit")
        XCTAssertEqual(conflict.remoteTextPlain, "Remote edit")

        let resolved = try conflictRepository.resolveManually(
            conflictID: conflict.id,
            text: "Merged edit"
        )

        XCTAssertEqual(resolved.blockID, blockID)
        XCTAssertEqual(try pageRepository.loadWorkspaceSnapshot().blocks.first?.textPlain, "Merged edit")
        XCTAssertEqual(try conflictRepository.conflicts(pageID: pageID), [])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().filter {
                $0 == SyncChange(entityType: "block", entityID: blockID, changeType: "update")
            }.count,
            1
        )
    }

    func testRemotePageReferenceBlockRebuildsPageParentLink() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
        let sourceBlockID = try XCTUnwrap(snapshot.blocks.first?.id)
        let childPage = try pageRepository.createPage(workspaceID: workspaceID, title: "Remote child")
        try database.execute("DELETE FROM sync_changes")

        try SyncMergeEngine(database: database).applyRemoteBlock(
            RemoteBlockChange(
                blockID: sourceBlockID,
                pageID: sourcePageID,
                type: .pageReference,
                textPlain: "Remote child",
                payloadJSON: "{\"text\":\"Remote child\",\"target_page_id\":\"\(childPage.id)\"}",
                revision: 2,
                orderKey: "000001"
            )
        )

        XCTAssertEqual(
            try pageRepository.loadWorkspaceSnapshot().pageParentLinks,
            [
                PageParentLink(
                    parentPageID: sourcePageID,
                    childPageID: childPage.id,
                    sourceBlockID: sourceBlockID,
                    orderKey: "000001"
                )
            ]
        )
    }

    func testConflictTextDiffHighlightsChangedMiddleLine() {
        XCTAssertEqual(
            ConflictTextDiff.segments(
                local: "Title\nLocal body\nShared",
                remote: "Title\nRemote body\nShared"
            ),
            [
                ConflictTextDiffSegment(kind: .unchanged, text: "Title"),
                ConflictTextDiffSegment(kind: .removed, text: "Local body"),
                ConflictTextDiffSegment(kind: .added, text: "Remote body"),
                ConflictTextDiffSegment(kind: .unchanged, text: "Shared")
            ]
        )
    }

    func testConflictTextDiffHighlightsAddedTrailingLine() {
        XCTAssertEqual(
            ConflictTextDiff.segments(
                local: "Title",
                remote: "Title\nRemote tail"
            ),
            [
                ConflictTextDiffSegment(kind: .unchanged, text: "Title"),
                ConflictTextDiffSegment(kind: .added, text: "Remote tail")
            ]
        )
    }

    func testConflictMergeDraftsSeedLocalRemoteAndPruneRemovedConflicts() {
        let firstConflict = ConflictSnapshot(
            id: "conflict-one",
            blockID: "block-one",
            localTextPlain: "Local one",
            remoteTextPlain: "Remote one",
            remoteRevision: 2
        )
        let secondConflict = ConflictSnapshot(
            id: "conflict-two",
            blockID: "block-two",
            localTextPlain: "Local two",
            remoteTextPlain: "Remote two",
            remoteRevision: 3
        )
        var drafts = ConflictMergeDrafts()

        XCTAssertEqual(drafts.text(for: firstConflict), "Local one")

        drafts.setText("Manual one", for: firstConflict)
        XCTAssertEqual(
            drafts.mergedTexts(for: [firstConflict, secondConflict]),
            [
                "conflict-one": "Manual one",
                "conflict-two": "Local two"
            ]
        )

        drafts.useRemoteText(for: firstConflict)
        XCTAssertEqual(drafts.text(for: firstConflict), "Remote one")

        drafts.useLocalText(for: firstConflict)
        XCTAssertEqual(drafts.text(for: firstConflict), "Local one")

        drafts.setText("Manual two", for: secondConflict)
        drafts.prune(keeping: [firstConflict.id])
        XCTAssertEqual(drafts.text(for: secondConflict), "Local two")
    }

    func testConflictMergeDraftsCanSeedEveryDraftFromLocalOrRemoteText() {
        let firstConflict = ConflictSnapshot(
            id: "conflict-one",
            blockID: "block-one",
            localTextPlain: "Local one",
            remoteTextPlain: "Remote one",
            remoteRevision: 2
        )
        let secondConflict = ConflictSnapshot(
            id: "conflict-two",
            blockID: "block-two",
            localTextPlain: "Local two",
            remoteTextPlain: "Remote two",
            remoteRevision: 3
        )
        let conflicts = [firstConflict, secondConflict]
        var drafts = ConflictMergeDrafts()

        drafts.setText("Manual one", for: firstConflict)
        drafts.setText("Manual two", for: secondConflict)
        drafts.useRemoteText(for: conflicts)
        XCTAssertEqual(
            drafts.mergedTexts(for: conflicts),
            [
                "conflict-one": "Remote one",
                "conflict-two": "Remote two"
            ]
        )

        drafts.useLocalText(for: conflicts)
        XCTAssertEqual(
            drafts.mergedTexts(for: conflicts),
            [
                "conflict-one": "Local one",
                "conflict-two": "Local two"
            ]
        )
    }

    private func migratedDatabase() throws -> SQLiteDatabase {
        let database = try SQLiteDatabase.open(path: makeTemporaryDirectory().appendingPathComponent("editor.sqlite").path)
        try SchemaMigrator.migrate(database: database)
        return database
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
}
