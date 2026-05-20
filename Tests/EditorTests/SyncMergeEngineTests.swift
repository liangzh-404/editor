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

    func testRemoteSameBlockConflictAutoMergesAndKeepsPendingUpdate() throws {
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

        XCTAssertEqual(try pageRepository.loadWorkspaceSnapshot().blocks.first?.textPlain, "Local edit\nRemote edit")
        XCTAssertEqual(try ConflictRepository(database: database).conflicts(blockID: blockID), [])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges(),
            [
                SyncChange(entityType: "block", entityID: blockID, changeType: "update"),
                SyncChange(entityType: "page", entityID: pageID, changeType: "update")
            ]
        )
    }

    func testRemoteNewerBlockWinsPendingLocalChangeAndClearsPendingUpdate() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(blockID: blockID, text: "Local stale edit")
        try setBlockUpdatedAt(database: database, blockID: blockID, updatedAt: "2026-05-21T00:00:00Z")

        try SyncMergeEngine(database: database).applyRemoteBlock(
            RemoteBlockChange(
                blockID: blockID,
                pageID: pageID,
                type: .paragraph,
                textPlain: "Remote latest edit",
                payloadJSON: "{\"text\":\"Remote latest edit\"}",
                revision: 3,
                updatedAt: "2026-05-21T00:00:01Z"
            )
        )

        let reloadedBlock = try XCTUnwrap(try pageRepository.loadWorkspaceSnapshot().blocks.first)
        XCTAssertEqual(reloadedBlock.textPlain, "Remote latest edit")
        XCTAssertEqual(try blockRevision(database: database, blockID: blockID), 3)
        XCTAssertEqual(try ConflictRepository(database: database).conflicts(blockID: blockID), [])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().filter {
                $0 == SyncChange(entityType: "block", entityID: blockID, changeType: "update")
            },
            []
        )
    }

    func testLocalNewerBlockKeepsPendingUpdateOverOlderRemoteChange() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try pageRepository.updateBlockText(blockID: blockID, text: "Local latest edit")
        try setBlockUpdatedAt(database: database, blockID: blockID, updatedAt: "2026-05-21T00:00:02Z")

        try SyncMergeEngine(database: database).applyRemoteBlock(
            RemoteBlockChange(
                blockID: blockID,
                pageID: pageID,
                type: .paragraph,
                textPlain: "Remote stale edit",
                payloadJSON: "{\"text\":\"Remote stale edit\"}",
                revision: 3,
                updatedAt: "2026-05-21T00:00:01Z"
            )
        )

        XCTAssertEqual(try pageRepository.loadWorkspaceSnapshot().blocks.first?.textPlain, "Local latest edit")
        XCTAssertEqual(try ConflictRepository(database: database).conflicts(blockID: blockID), [])
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().filter {
                $0 == SyncChange(entityType: "block", entityID: blockID, changeType: "update")
            },
            [
                SyncChange(entityType: "block", entityID: blockID, changeType: "update")
            ]
        )
    }

    func testRemoteNewerPageSnapshotReplacesWholePendingLocalPageContent() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let firstBlockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try database.execute("DELETE FROM sync_changes")
        let localOnlyBlock = try pageRepository.appendBlock(
            pageID: pageID,
            type: .paragraph,
            text: "Local only"
        )
        try pageRepository.updateBlockText(blockID: firstBlockID, text: "Local stale first")
        try setPageUpdatedAt(database: database, pageID: pageID, updatedAt: "2026-05-21T00:00:00Z")

        try SyncMergeEngine(database: database).applyRemoteBlockPageSnapshot(
            pageID: pageID,
            changes: [
                RemoteBlockChange(
                    blockID: firstBlockID,
                    pageID: pageID,
                    type: .paragraph,
                    textPlain: "Remote latest first",
                    payloadJSON: "{\"text\":\"Remote latest first\"}",
                    revision: 4,
                    orderKey: "000001",
                    updatedAt: "2026-05-21T00:00:01Z"
                ),
                RemoteBlockChange(
                    blockID: "block-remote-second",
                    pageID: pageID,
                    type: .paragraph,
                    textPlain: "Remote second",
                    payloadJSON: "{\"text\":\"Remote second\"}",
                    revision: 1,
                    orderKey: "000002",
                    updatedAt: "2026-05-21T00:00:01Z"
                )
            ],
            remoteUpdatedAt: "2026-05-21T00:00:01Z"
        )

        let activeBlocks = try pageRepository.loadWorkspaceSnapshot().blocks
            .filter { $0.pageID == pageID }
            .sorted { $0.orderKey < $1.orderKey }
        XCTAssertEqual(activeBlocks.map(\.id), [firstBlockID, "block-remote-second"])
        XCTAssertEqual(activeBlocks.map(\.textPlain), ["Remote latest first", "Remote second"])
        XCTAssertEqual(try isBlockDeleted(database: database, blockID: localOnlyBlock.id), true)
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().filter { change in
                change.entityID == pageID || change.entityID == firstBlockID || change.entityID == localOnlyBlock.id
            },
            []
        )
    }

    func testLocalNewerPageSnapshotKeepsPendingLocalContentAndAppliesRemoteOnlyBlocks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let firstBlockID = try XCTUnwrap(snapshot.blocks.first?.id)
        try database.execute("DELETE FROM sync_changes")
        let localOnlyBlock = try pageRepository.appendBlock(
            pageID: pageID,
            type: .paragraph,
            text: "Local only"
        )
        try pageRepository.updateBlockText(blockID: firstBlockID, text: "Local latest first")
        try setBlockUpdatedAt(database: database, blockID: firstBlockID, updatedAt: "2026-05-21T00:00:02Z")
        try setPageUpdatedAt(database: database, pageID: pageID, updatedAt: "2026-05-21T00:00:02Z")

        try SyncMergeEngine(database: database).applyRemoteBlockPageSnapshot(
            pageID: pageID,
            changes: [
                RemoteBlockChange(
                    blockID: firstBlockID,
                    pageID: pageID,
                    type: .paragraph,
                    textPlain: "Remote stale first",
                    payloadJSON: "{\"text\":\"Remote stale first\"}",
                    revision: 4,
                    orderKey: "000001",
                    updatedAt: "2026-05-21T00:00:01Z"
                ),
                RemoteBlockChange(
                    blockID: "block-remote-second",
                    pageID: pageID,
                    type: .paragraph,
                    textPlain: "Remote second",
                    payloadJSON: "{\"text\":\"Remote second\"}",
                    revision: 1,
                    orderKey: "000002",
                    updatedAt: "2026-05-21T00:00:01Z"
                )
            ],
            remoteUpdatedAt: "2026-05-21T00:00:01Z"
        )

        let activeBlocks = try pageRepository.loadWorkspaceSnapshot().blocks
            .filter { $0.pageID == pageID }
            .sorted { $0.orderKey < $1.orderKey }
        let activeBlocksByID = Dictionary(uniqueKeysWithValues: activeBlocks.map { ($0.id, $0) })
        XCTAssertEqual(activeBlocksByID[firstBlockID]?.textPlain, "Local latest first")
        XCTAssertEqual(activeBlocksByID[localOnlyBlock.id]?.textPlain, "Local only")
        XCTAssertEqual(activeBlocksByID["block-remote-second"]?.textPlain, "Remote second")
        XCTAssertEqual(try isBlockDeleted(database: database, blockID: localOnlyBlock.id), false)
        XCTAssertEqual(
            try SyncRepository(database: database).pendingChanges().filter { change in
                change.entityID == pageID || change.entityID == firstBlockID || change.entityID == localOnlyBlock.id
            },
            [
                SyncChange(entityType: "block", entityID: localOnlyBlock.id, changeType: "create"),
                SyncChange(entityType: "block", entityID: firstBlockID, changeType: "update"),
                SyncChange(entityType: "page", entityID: pageID, changeType: "update")
            ]
        )
    }

    func testAutomaticConflictMergePreservesSharedPrefixAndSuffix() {
        XCTAssertEqual(
            AutomaticTextMerge.merge(
                local: "Title\nLocal body\nShared",
                remote: "Title\nRemote body\nShared"
            ),
            "Title\nLocal body\nRemote body\nShared"
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
        try storeConflict(database: database, blockID: blockID, text: "Remote edit")
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
        try storeConflict(database: database, blockID: blockID, text: "Remote edit")
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
        try storeConflict(database: database, blockID: blockID, text: "Remote edit")
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

    private func storeConflict(
        database: SQLiteDatabase,
        blockID: String,
        text: String,
        revision: Int = 2
    ) throws {
        try ConflictRepository(database: database).storeConflict(
            ConflictVersion(
                blockID: blockID,
                payloadJSON: "{\"text\":\"\(text)\"}",
                textPlain: text,
                remoteRevision: revision
            )
        )
    }

    private func setBlockUpdatedAt(
        database: SQLiteDatabase,
        blockID: String,
        updatedAt: String
    ) throws {
        try database.execute(
            "UPDATE blocks SET updated_at = ? WHERE id = ?",
            bindings: [
                .text(updatedAt),
                .text(blockID)
            ]
        )
    }

    private func setPageUpdatedAt(
        database: SQLiteDatabase,
        pageID: String,
        updatedAt: String
    ) throws {
        try database.execute(
            "UPDATE pages SET updated_at = ? WHERE id = ?",
            bindings: [
                .text(updatedAt),
                .text(pageID)
            ]
        )
    }

    private func isBlockDeleted(database: SQLiteDatabase, blockID: String) throws -> Bool {
        let row = try XCTUnwrap(
            try database.query(
                "SELECT is_deleted FROM blocks WHERE id = ? LIMIT 1",
                bindings: [.text(blockID)]
            ).first
        )
        return (Int(row["is_deleted"] ?? "") ?? 0) == 1
    }

    private func blockRevision(database: SQLiteDatabase, blockID: String) throws -> Int {
        let row = try XCTUnwrap(
            try database.query(
                "SELECT revision FROM blocks WHERE id = ? LIMIT 1",
                bindings: [.text(blockID)]
            ).first
        )
        return Int(row["revision"] ?? "") ?? 0
    }
}
