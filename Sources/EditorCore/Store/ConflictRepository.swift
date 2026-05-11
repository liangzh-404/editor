import Foundation

struct ConflictVersion: Equatable, Sendable {
    let blockID: String
    let payloadJSON: String
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
