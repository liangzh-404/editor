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

extension Notification.Name {
    static let editorSyncChangeEnqueued = Notification.Name("editor.syncChangeEnqueued")
}

final class SyncRepository {
    private let database: SQLiteDatabase
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func enqueue(entityType: String, entityID: String, changeType: String) throws {
        let createdAt = dateFormatter.string(from: Date())
        try enqueueCoalesced(
            entityType: entityType,
            entityID: entityID,
            changeType: changeType,
            createdAt: createdAt
        )
        if entityType == "block" {
            try enqueueParentPageContentChange(blockID: entityID, createdAt: createdAt)
        }

        EditorLog.sync.debug(
            "sync_change_enqueued entity_type=\(entityType, privacy: .public) entity_id=\(entityID, privacy: .public) change_type=\(changeType, privacy: .public)"
        )
        NotificationCenter.default.post(
            name: .editorSyncChangeEnqueued,
            object: database,
            userInfo: [
                "entityType": entityType,
                "entityID": entityID,
                "changeType": changeType
            ]
        )
    }

    private func enqueueCoalesced(
        entityType: String,
        entityID: String,
        changeType: String,
        createdAt: String
    ) throws {
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
                .text(createdAt)
            ]
        )
    }

    private func enqueueParentPageContentChange(blockID: String, createdAt: String) throws {
        guard let pageID = try database.query(
            """
            SELECT page_id
            FROM blocks
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first?["page_id"] ?? nil else {
            return
        }

        try database.execute(
            """
            UPDATE pages
            SET updated_at = ?
            WHERE id = ?
            """,
            bindings: [
                .text(createdAt),
                .text(pageID)
            ]
        )
        let pendingPageCreateRow = try database.query(
            """
            SELECT COUNT(*) AS count
            FROM sync_changes
            WHERE entity_type = 'page'
              AND entity_id = ?
              AND change_type = 'create'
            """,
            bindings: [.text(pageID)]
        ).first
        let pendingPageCreateCount = Int(pendingPageCreateRow?["count"] ?? "") ?? 0
        guard pendingPageCreateCount == 0 else {
            return
        }

        try enqueueCoalesced(
            entityType: "page",
            entityID: pageID,
            changeType: "update",
            createdAt: createdAt
        )
    }

    func pageIDForBlock(blockID: String) throws -> String? {
        try database.query(
            """
            SELECT page_id
            FROM blocks
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(blockID)]
        ).first?["page_id"] ?? nil
    }

    func hasPendingBlockChanges(pageID: String) throws -> Bool {
        let row = try database.query(
            """
            SELECT COUNT(*) AS count
            FROM sync_changes
            WHERE entity_type = 'block'
              AND entity_id IN (
                  SELECT id
                  FROM blocks
                  WHERE page_id = ?
              )
            """,
            bindings: [.text(pageID)]
        ).first
        return Int(row?["count"] ?? "") ?? 0 > 0
    }

    func pageExists(pageID: String) throws -> Bool {
        let rows = try database.query(
            """
            SELECT 1
            FROM pages
            WHERE id = ? AND is_archived = 0
            LIMIT 1
            """,
            bindings: [.text(pageID)]
        )
        return !rows.isEmpty
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

    func enqueueUnsyncedDiaryPageMappings() throws {
        let now = dateFormatter.string(from: Date())
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
            SELECT 'sync-' || lower(hex(randomblob(16))),
                   'diaryPage',
                   diary_pages.page_id,
                   'create',
                   0,
                   ?
            FROM diary_pages
            WHERE NOT EXISTS (
                SELECT 1
                FROM sync_records
                WHERE entity_type = 'diaryPage'
                  AND entity_id = diary_pages.page_id
            )
              AND NOT EXISTS (
                SELECT 1
                FROM sync_changes
                WHERE entity_type = 'diaryPage'
                  AND entity_id = diary_pages.page_id
            )
            """,
            bindings: [.text(now)]
        )
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
