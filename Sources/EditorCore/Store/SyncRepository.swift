import Foundation

struct SyncChange: Equatable, Sendable {
    let entityType: String
    let entityID: String
    let changeType: String
}

struct SyncRecord: Equatable, Sendable {
    let entityType: String
    let entityID: String
    let recordName: String
    let changeTag: String?
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

    func markUploaded(change: SyncChange, uploadResult: CloudKitUploadResult) throws {
        try database.execute(
            """
            INSERT OR REPLACE INTO sync_records (
                id,
                entity_type,
                entity_id,
                record_name,
                change_tag,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text("\(change.entityType)-\(change.entityID)"),
                .text(change.entityType),
                .text(change.entityID),
                .text(uploadResult.recordName),
                uploadResult.changeTag.map(SQLiteValue.text) ?? .null,
                .text(ISO8601DateFormatter().string(from: Date()))
            ]
        )

        try database.execute(
            """
            DELETE FROM sync_changes
            WHERE entity_type = ?
              AND entity_id = ?
              AND change_type = ?
            """,
            bindings: [
                .text(change.entityType),
                .text(change.entityID),
                .text(change.changeType)
            ]
        )
    }

    func syncRecords() throws -> [SyncRecord] {
        try database.query(
            """
            SELECT entity_type, entity_id, record_name, change_tag
            FROM sync_records
            ORDER BY updated_at ASC
            """
        ).map { row in
            SyncRecord(
                entityType: row["entity_type"] ?? "",
                entityID: row["entity_id"] ?? "",
                recordName: row["record_name"] ?? "",
                changeTag: row["change_tag"] ?? nil
            )
        }
    }
}
