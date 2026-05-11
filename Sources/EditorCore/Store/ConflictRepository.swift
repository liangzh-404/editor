import Foundation

struct ConflictVersion: Equatable, Sendable {
    let blockID: String
    let payloadJSON: String
    let textPlain: String
    let remoteRevision: Int
}

struct ConflictSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let blockID: String
    let textPlain: String
    let remoteRevision: Int
}

final class ConflictRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func storeConflict(_ conflict: ConflictVersion) throws {
        try database.execute(
            """
            INSERT INTO conflict_versions (
                id,
                block_id,
                payload_json,
                text_plain,
                remote_revision,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text("conflict-\(UUID().uuidString.lowercased())"),
                .text(conflict.blockID),
                .text(conflict.payloadJSON),
                .text(conflict.textPlain),
                .integer(conflict.remoteRevision),
                .text(ISO8601DateFormatter().string(from: Date()))
            ]
        )
    }

    func conflicts(pageID: String) throws -> [ConflictSnapshot] {
        try database.query(
            """
            SELECT conflict_versions.id,
                   conflict_versions.block_id,
                   conflict_versions.text_plain,
                   conflict_versions.remote_revision
            FROM conflict_versions
            INNER JOIN blocks ON blocks.id = conflict_versions.block_id
            WHERE blocks.page_id = ?
              AND blocks.is_deleted = 0
            ORDER BY blocks.order_key ASC, conflict_versions.created_at ASC
            """,
            bindings: [.text(pageID)]
        ).map { row in
            ConflictSnapshot(
                id: row["id"] ?? "",
                blockID: row["block_id"] ?? "",
                textPlain: row["text_plain"] ?? "",
                remoteRevision: Int(row["remote_revision"] ?? "") ?? 0
            )
        }
    }

    func acceptRemoteVersion(conflictID: String) throws -> ConflictSnapshot {
        guard let row = try database.query(
            """
            SELECT id, block_id, payload_json, text_plain, remote_revision
            FROM conflict_versions
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(conflictID)]
        ).first else {
            throw ConflictRepositoryError.conflictNotFound
        }

        let snapshot = ConflictSnapshot(
            id: row["id"] ?? "",
            blockID: row["block_id"] ?? "",
            textPlain: row["text_plain"] ?? "",
            remoteRevision: Int(row["remote_revision"] ?? "") ?? 0
        )
        let payloadJSON = row["payload_json"] ?? ""
        let now = ISO8601DateFormatter().string(from: Date())

        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try database.execute(
                """
                UPDATE blocks
                SET payload_json = ?,
                    text_plain = ?,
                    revision = ?,
                    sync_state = ?,
                    updated_at = ?
                WHERE id = ? AND is_deleted = 0
                """,
                bindings: [
                    .text(payloadJSON),
                    .text(snapshot.textPlain),
                    .integer(snapshot.remoteRevision),
                    .text("synced"),
                    .text(now),
                    .text(snapshot.blockID)
                ]
            )
            try database.execute(
                """
                DELETE FROM sync_changes
                WHERE entity_type = ? AND entity_id = ?
                """,
                bindings: [
                    .text("block"),
                    .text(snapshot.blockID)
                ]
            )
            try database.execute(
                """
                DELETE FROM conflict_versions
                WHERE block_id = ?
                """,
                bindings: [.text(snapshot.blockID)]
            )
            try BacklinkRepository(database: database).rebuildLinksForBlock(
                blockID: snapshot.blockID,
                text: snapshot.textPlain
            )
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }

        return snapshot
    }

    func conflicts(blockID: String) throws -> [ConflictVersion] {
        try database.query(
            """
            SELECT block_id, payload_json, text_plain, remote_revision
            FROM conflict_versions
            WHERE block_id = ?
            ORDER BY created_at ASC
            """,
            bindings: [.text(blockID)]
        ).map { row in
            ConflictVersion(
                blockID: row["block_id"] ?? "",
                payloadJSON: row["payload_json"] ?? "",
                textPlain: row["text_plain"] ?? "",
                remoteRevision: Int(row["remote_revision"] ?? "") ?? 0
            )
        }
    }
}

enum ConflictRepositoryError: Error, Equatable {
    case conflictNotFound
}
