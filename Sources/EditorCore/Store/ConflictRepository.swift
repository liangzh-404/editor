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
    let localTextPlain: String
    let remoteTextPlain: String
    let remoteRevision: Int

    var textPlain: String {
        remoteTextPlain
    }
}

enum ConflictTextDiffSegmentKind: Equatable, Sendable {
    case unchanged
    case removed
    case added
}

struct ConflictTextDiffSegment: Equatable, Sendable {
    let kind: ConflictTextDiffSegmentKind
    let text: String
}

enum ConflictTextDiff {
    static func segments(local: String, remote: String) -> [ConflictTextDiffSegment] {
        let localLines = local.components(separatedBy: .newlines)
        let remoteLines = remote.components(separatedBy: .newlines)

        var prefixCount = 0
        while prefixCount < localLines.count,
              prefixCount < remoteLines.count,
              localLines[prefixCount] == remoteLines[prefixCount] {
            prefixCount += 1
        }

        var suffixCount = 0
        while suffixCount < localLines.count - prefixCount,
              suffixCount < remoteLines.count - prefixCount,
              localLines[localLines.count - 1 - suffixCount] == remoteLines[remoteLines.count - 1 - suffixCount] {
            suffixCount += 1
        }

        var diffSegments: [ConflictTextDiffSegment] = []
        diffSegments.append(
            contentsOf: localLines.prefix(prefixCount).map {
                ConflictTextDiffSegment(kind: .unchanged, text: $0)
            }
        )

        let localChangedLines = localLines.dropFirst(prefixCount).dropLast(suffixCount)
        diffSegments.append(
            contentsOf: localChangedLines.map {
                ConflictTextDiffSegment(kind: .removed, text: $0)
            }
        )

        let remoteChangedLines = remoteLines.dropFirst(prefixCount).dropLast(suffixCount)
        diffSegments.append(
            contentsOf: remoteChangedLines.map {
                ConflictTextDiffSegment(kind: .added, text: $0)
            }
        )

        diffSegments.append(
            contentsOf: localLines.suffix(suffixCount).map {
                ConflictTextDiffSegment(kind: .unchanged, text: $0)
            }
        )
        return diffSegments
    }
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
                   blocks.text_plain AS local_text_plain,
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
                localTextPlain: row["local_text_plain"] ?? "",
                remoteTextPlain: row["text_plain"] ?? "",
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
            localTextPlain: "",
            remoteTextPlain: row["text_plain"] ?? "",
            remoteRevision: Int(row["remote_revision"] ?? "") ?? 0
        )
        let payloadJSON = row["payload_json"] ?? ""
        let now = ISO8601DateFormatter().string(from: Date())

        try database.withImmediateTransaction("accept_remote_conflict") {
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
        }

        return snapshot
    }

    func acceptRemoteVersions(pageID: String) throws -> [ConflictSnapshot] {
        let pageConflicts = try conflicts(pageID: pageID)
        var accepted: [ConflictSnapshot] = []
        var acceptedBlockIDs: Set<String> = []

        for conflict in pageConflicts where !acceptedBlockIDs.contains(conflict.blockID) {
            accepted.append(try acceptRemoteVersion(conflictID: conflict.id))
            acceptedBlockIDs.insert(conflict.blockID)
        }

        return accepted
    }

    func acceptLocalVersion(conflictID: String) throws -> ConflictSnapshot {
        guard let row = try database.query(
            """
            SELECT conflict_versions.id,
                   conflict_versions.block_id,
                   blocks.text_plain AS local_text_plain,
                   conflict_versions.text_plain,
                   conflict_versions.remote_revision
            FROM conflict_versions
            INNER JOIN blocks ON blocks.id = conflict_versions.block_id
            WHERE conflict_versions.id = ?
            LIMIT 1
            """,
            bindings: [.text(conflictID)]
        ).first else {
            throw ConflictRepositoryError.conflictNotFound
        }

        let snapshot = ConflictSnapshot(
            id: row["id"] ?? "",
            blockID: row["block_id"] ?? "",
            localTextPlain: row["local_text_plain"] ?? "",
            remoteTextPlain: row["text_plain"] ?? "",
            remoteRevision: Int(row["remote_revision"] ?? "") ?? 0
        )
        let now = ISO8601DateFormatter().string(from: Date())

        try database.withImmediateTransaction("accept_local_conflict") {
            try database.execute(
                """
                UPDATE blocks
                SET sync_state = ?,
                    updated_at = ?
                WHERE id = ? AND is_deleted = 0
                """,
                bindings: [
                    .text("local"),
                    .text(now),
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
            if try !hasPendingBlockUpdate(blockID: snapshot.blockID) {
                try SyncRepository(database: database).enqueue(
                    entityType: "block",
                    entityID: snapshot.blockID,
                    changeType: "update"
                )
            }
        }

        return snapshot
    }

    func acceptLocalVersions(pageID: String) throws -> [ConflictSnapshot] {
        let pageConflicts = try conflicts(pageID: pageID)
        var accepted: [ConflictSnapshot] = []
        var acceptedBlockIDs: Set<String> = []

        for conflict in pageConflicts where !acceptedBlockIDs.contains(conflict.blockID) {
            accepted.append(try acceptLocalVersion(conflictID: conflict.id))
            acceptedBlockIDs.insert(conflict.blockID)
        }

        return accepted
    }

    func resolveManually(conflictID: String, text: String) throws -> ConflictSnapshot {
        guard let row = try database.query(
            """
            SELECT conflict_versions.id,
                   conflict_versions.block_id,
                   blocks.text_plain AS local_text_plain,
                   conflict_versions.text_plain,
                   conflict_versions.remote_revision
            FROM conflict_versions
            INNER JOIN blocks ON blocks.id = conflict_versions.block_id
            WHERE conflict_versions.id = ?
            LIMIT 1
            """,
            bindings: [.text(conflictID)]
        ).first else {
            throw ConflictRepositoryError.conflictNotFound
        }

        let snapshot = ConflictSnapshot(
            id: row["id"] ?? "",
            blockID: row["block_id"] ?? "",
            localTextPlain: row["local_text_plain"] ?? "",
            remoteTextPlain: row["text_plain"] ?? "",
            remoteRevision: Int(row["remote_revision"] ?? "") ?? 0
        )
        let payloadJSON = try blockPayloadJSON(text: text)
        let now = ISO8601DateFormatter().string(from: Date())

        try database.withImmediateTransaction("resolve_manual_conflict") {
            try database.execute(
                """
                UPDATE blocks
                SET payload_json = ?,
                    text_plain = ?,
                    revision = revision + 1,
                    sync_state = ?,
                    updated_at = ?
                WHERE id = ? AND is_deleted = 0
                """,
                bindings: [
                    .text(payloadJSON),
                    .text(text),
                    .text("local"),
                    .text(now),
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
                text: text
            )
            if try !hasPendingBlockUpdate(blockID: snapshot.blockID) {
                try SyncRepository(database: database).enqueue(
                    entityType: "block",
                    entityID: snapshot.blockID,
                    changeType: "update"
                )
            }
        }

        return snapshot
    }

    func resolveManualConflicts(_ merges: [(conflictID: String, text: String)]) throws -> [ConflictSnapshot] {
        var resolved: [ConflictSnapshot] = []

        for merge in merges {
            resolved.append(
                try resolveManually(conflictID: merge.conflictID, text: merge.text)
            )
        }

        return resolved
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

    private func hasPendingBlockUpdate(blockID: String) throws -> Bool {
        let rows = try database.query(
            """
            SELECT id
            FROM sync_changes
            WHERE entity_type = ?
              AND entity_id = ?
              AND change_type = ?
            LIMIT 1
            """,
            bindings: [
                .text("block"),
                .text(blockID),
                .text("update")
            ]
        )
        return rows.first != nil
    }
}

private func blockPayloadJSON(text: String) throws -> String {
    let data = try JSONSerialization.data(
        withJSONObject: ["text": text],
        options: [.sortedKeys]
    )

    guard let payload = String(data: data, encoding: .utf8) else {
        throw PageRepositoryError.invalidPayloadEncoding
    }

    return payload
}

enum ConflictRepositoryError: Error, Equatable {
    case conflictNotFound
}
