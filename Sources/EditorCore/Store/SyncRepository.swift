import Foundation

struct SyncChange: Equatable, Sendable {
    let entityType: String
    let entityID: String
    let changeType: String
}

final class SyncRepository {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func enqueue(entityType: String, entityID: String, changeType: String) throws {
        try database.execute(
            """
            INSERT INTO sync_changes (
                id,
                entity_type,
                entity_id,
                change_type,
                created_at
            )
            VALUES (?, ?, ?, ?, ?)
            """,
            bindings: [
                .text("sync-\(UUID().uuidString.lowercased())"),
                .text(entityType),
                .text(entityID),
                .text(changeType),
                .text(ISO8601DateFormatter().string(from: Date()))
            ]
        )

        EditorLog.sync.debug(
            "sync_change_enqueued entity_type=\(entityType, privacy: .public) entity_id=\(entityID, privacy: .public) change_type=\(changeType, privacy: .public)"
        )
    }

    func pendingChanges() throws -> [SyncChange] {
        try database.query(
            """
            SELECT entity_type, entity_id, change_type
            FROM sync_changes
            ORDER BY created_at ASC
            """
        ).map { row in
            SyncChange(
                entityType: row["entity_type"] ?? "",
                entityID: row["entity_id"] ?? "",
                changeType: row["change_type"] ?? ""
            )
        }
    }
}
