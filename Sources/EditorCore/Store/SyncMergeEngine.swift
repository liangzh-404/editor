import Foundation

struct RemoteBlockChange: Equatable, Sendable {
    let blockID: String
    let pageID: String
    let type: BlockType
    let textPlain: String
    let payloadJSON: String
    let revision: Int
}

final class SyncMergeEngine {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func applyRemoteBlock(_ remote: RemoteBlockChange) throws {
        if try hasPendingLocalChange(blockID: remote.blockID) {
            try ConflictRepository(database: database).storeConflict(
                ConflictVersion(
                    blockID: remote.blockID,
                    payloadJSON: remote.payloadJSON,
                    textPlain: remote.textPlain,
                    remoteRevision: remote.revision
                )
            )
            EditorLog.sync.debug(
                "sync_conflict_stored block_id=\(remote.blockID, privacy: .public) revision=\(remote.revision, privacy: .public)"
            )
            return
        }

        try database.execute(
            """
            UPDATE blocks
            SET type = ?,
                payload_json = ?,
                text_plain = ?,
                revision = ?,
                sync_state = ?,
                updated_at = ?
            WHERE id = ? AND page_id = ? AND is_deleted = 0
            """,
            bindings: [
                .text(remote.type.rawValue),
                .text(remote.payloadJSON),
                .text(remote.textPlain),
                .integer(remote.revision),
                .text("synced"),
                .text(ISO8601DateFormatter().string(from: Date())),
                .text(remote.blockID),
                .text(remote.pageID)
            ]
        )
        try BacklinkRepository(database: database).rebuildLinksForBlock(
            blockID: remote.blockID,
            text: remote.textPlain
        )
    }

    private func hasPendingLocalChange(blockID: String) throws -> Bool {
        let rows = try database.query(
            """
            SELECT COUNT(*)
            FROM sync_changes
            WHERE entity_type = ? AND entity_id = ?
            """,
            bindings: [
                .text("block"),
                .text(blockID)
            ]
        )
        return Int(rows.first?["COUNT(*)"] ?? "") ?? 0 > 0
    }
}
