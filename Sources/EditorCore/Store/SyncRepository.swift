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

struct SyncRetryState: Equatable, Sendable {
    let attemptCount: Int
    let lastError: String?
    let nextAttemptAt: Date?
}

struct RuntimeDiagnosticEvent: Equatable, Sendable {
    let id: String
    let eventName: String
    let payloadJSON: String
    let createdAt: Date
}

final class SyncRepository {
    private let database: SQLiteDatabase
    private let dateFormatter = ISO8601DateFormatter()

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func enqueue(entityType: String, entityID: String, changeType: String) throws {
        try database.execute(
            """
            DELETE FROM sync_changes
            WHERE entity_type = ?
              AND entity_id = ?
              AND change_type = ?
            """,
            bindings: [
                .text(entityType),
                .text(entityID),
                .text(changeType)
            ]
        )

        try database.execute(
            """
            INSERT INTO sync_changes (
                id,
                entity_type,
                entity_id,
                change_type,
                attempt_count,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text("sync-\(UUID().uuidString.lowercased())"),
                .text(entityType),
                .text(entityID),
                .text(changeType),
                .integer(0),
                .text(dateFormatter.string(from: Date()))
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
            GROUP BY entity_type, entity_id, change_type
            ORDER BY MIN(created_at) ASC, MIN(rowid) ASC
            """
        ).map { row in
            SyncChange(
                entityType: row["entity_type"] ?? "",
                entityID: row["entity_id"] ?? "",
                changeType: row["change_type"] ?? ""
            )
        }
    }

    func retryState(change: SyncChange) throws -> SyncRetryState {
        let row = try database.query(
            """
            SELECT attempt_count, last_error, next_attempt_at
            FROM sync_changes
            WHERE entity_type = ?
              AND entity_id = ?
              AND change_type = ?
            LIMIT 1
            """,
            bindings: [
                .text(change.entityType),
                .text(change.entityID),
                .text(change.changeType)
            ]
        ).first

        return SyncRetryState(
            attemptCount: Int(row?["attempt_count"] ?? "") ?? 0,
            lastError: row?["last_error"] ?? nil,
            nextAttemptAt: (row?["next_attempt_at"] ?? nil).flatMap(dateFormatter.date(from:))
        )
    }

    func recordFailure(
        change: SyncChange,
        errorDescription: String,
        nextAttemptAt: Date
    ) throws {
        try database.execute(
            """
            UPDATE sync_changes
            SET attempt_count = attempt_count + 1,
                last_error = ?,
                next_attempt_at = ?
            WHERE entity_type = ?
              AND entity_id = ?
              AND change_type = ?
            """,
            bindings: [
                .text(errorDescription),
                .text(dateFormatter.string(from: nextAttemptAt)),
                .text(change.entityType),
                .text(change.entityID),
                .text(change.changeType)
            ]
        )
    }

    func clearRetryState(change: SyncChange) throws {
        try database.execute(
            """
            UPDATE sync_changes
            SET attempt_count = 0,
                last_error = NULL,
                next_attempt_at = NULL
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

    func markUploaded(change: SyncChange, uploadResult: CloudKitUploadResult) throws {
        if change.changeType == "delete" {
            try database.execute(
                """
                DELETE FROM sync_records
                WHERE entity_type = ? AND entity_id = ?
                """,
                bindings: [
                    .text(change.entityType),
                    .text(change.entityID)
                ]
            )
        } else {
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
                    .text(dateFormatter.string(from: Date()))
                ]
            )
        }

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

    func saveServerChangeTokenData(_ tokenData: Data, scope: String) throws {
        try database.execute(
            """
            INSERT OR REPLACE INTO sync_server_change_tokens (
                scope,
                token_base64,
                updated_at
            )
            VALUES (?, ?, ?)
            """,
            bindings: [
                .text(scope),
                .text(tokenData.base64EncodedString()),
                .text(dateFormatter.string(from: Date()))
            ]
        )
    }

    func serverChangeTokenData(scope: String) throws -> Data? {
        guard let tokenBase64 = try database.query(
            """
            SELECT token_base64
            FROM sync_server_change_tokens
            WHERE scope = ?
            LIMIT 1
            """,
            bindings: [.text(scope)]
        ).first?["token_base64"] ?? nil else {
            return nil
        }

        return Data(base64Encoded: tokenBase64)
    }

    func clearServerChangeTokenData(scope: String) throws {
        try database.execute(
            """
            DELETE FROM sync_server_change_tokens
            WHERE scope = ?
            """,
            bindings: [.text(scope)]
        )
    }
}

final class RuntimeDiagnosticRepository {
    private let database: SQLiteDatabase
    private let dateFormatter = ISO8601DateFormatter()

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func record(
        eventName: String,
        payloadJSON: String,
        createdAt: Date = Date()
    ) throws {
        try database.execute(
            """
            INSERT INTO runtime_diagnostics (
                id,
                event_name,
                payload_json,
                created_at
            )
            VALUES (?, ?, ?, ?)
            """,
            bindings: [
                .text("runtime-diagnostic-\(UUID().uuidString.lowercased())"),
                .text(eventName),
                .text(payloadJSON),
                .text(dateFormatter.string(from: createdAt))
            ]
        )
    }

    func recentEvents(limit: Int) throws -> [RuntimeDiagnosticEvent] {
        try database.query(
            """
            SELECT id, event_name, payload_json, created_at
            FROM runtime_diagnostics
            ORDER BY created_at DESC, rowid DESC
            LIMIT ?
            """,
            bindings: [.integer(limit)]
        ).map { row in
            RuntimeDiagnosticEvent(
                id: row["id"] ?? "",
                eventName: row["event_name"] ?? "",
                payloadJSON: row["payload_json"] ?? "",
                createdAt: (row["created_at"] ?? nil).flatMap(dateFormatter.date(from:)) ?? Date(timeIntervalSince1970: 0)
            )
        }
    }
}
