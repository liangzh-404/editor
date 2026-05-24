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

struct ConflictMergeDrafts: Equatable, Sendable {
    private var textsByConflictID: [String: String] = [:]

    func text(for conflict: ConflictSnapshot) -> String {
        textsByConflictID[conflict.id] ?? conflict.localTextPlain
    }

    mutating func setText(_ text: String, for conflict: ConflictSnapshot) {
        textsByConflictID[conflict.id] = text
    }

    mutating func useLocalText(for conflict: ConflictSnapshot) {
        setText(conflict.localTextPlain, for: conflict)
    }

    mutating func useLocalText(for conflicts: [ConflictSnapshot]) {
        conflicts.forEach { useLocalText(for: $0) }
    }

    mutating func useRemoteText(for conflict: ConflictSnapshot) {
        setText(conflict.remoteTextPlain, for: conflict)
    }

    mutating func useRemoteText(for conflicts: [ConflictSnapshot]) {
        conflicts.forEach { useRemoteText(for: $0) }
    }

    mutating func prune(keeping conflictIDs: [String]) {
        let validIDs = Set(conflictIDs)
        textsByConflictID = textsByConflictID.filter { validIDs.contains($0.key) }
    }

    func mergedTexts(for conflicts: [ConflictSnapshot]) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: conflicts.map { conflict in
                (conflict.id, text(for: conflict))
            }
        )
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

enum AutomaticTextMerge {
    static func merge(local: String, remote: String) -> String {
        if local == remote {
            return local
        }
        if local.isEmpty {
            return remote
        }
        if remote.isEmpty {
            return local
        }
        if local.contains(remote) {
            return local
        }
        if remote.contains(local) {
            return remote
        }

        return mergeLines(
            local.components(separatedBy: "\n"),
            remote.components(separatedBy: "\n")
        ).joined(separator: "\n")
    }

    static func payloadJSON(
        updating payloadJSON: String,
        text: String,
        preservingInlineLinksFrom additionalPayloadJSONs: [String] = []
    ) throws -> String {
        let data = payloadJSON.data(using: .utf8) ?? Data()
        var payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if payload["filename"] != nil && payload["text"] == nil {
            payload["filename"] = text
        } else {
            payload["text"] = text
        }
        let inlineLinks = InlineInternalLinkTarget.pruned(
            payloadJSONs: [payloadJSON] + additionalPayloadJSONs,
            visibleText: text
        )
        if inlineLinks.isEmpty {
            payload.removeValue(forKey: "inline_links")
        } else {
            payload["inline_links"] = InlineInternalLinkTarget.payloadRows(for: inlineLinks)
        }

        let updatedData = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        )
        guard let updatedPayload = String(data: updatedData, encoding: .utf8) else {
            throw PageRepositoryError.invalidPayloadEncoding
        }
        return updatedPayload
    }

    private static func mergeLines(_ localLines: [String], _ remoteLines: [String]) -> [String] {
        let commonPairs = longestCommonSubsequencePairs(localLines, remoteLines)
        var merged: [String] = []
        var localCursor = 0
        var remoteCursor = 0

        for pair in commonPairs {
            merged.append(
                contentsOf: mergeSegment(
                    Array(localLines[localCursor..<pair.localIndex]),
                    Array(remoteLines[remoteCursor..<pair.remoteIndex])
                )
            )
            merged.append(localLines[pair.localIndex])
            localCursor = pair.localIndex + 1
            remoteCursor = pair.remoteIndex + 1
        }

        merged.append(
            contentsOf: mergeSegment(
                Array(localLines[localCursor...]),
                Array(remoteLines[remoteCursor...])
            )
        )
        return merged
    }

    private static func mergeSegment(_ localLines: [String], _ remoteLines: [String]) -> [String] {
        if localLines == remoteLines {
            return localLines
        }
        if localLines.isEmpty {
            return remoteLines
        }
        if remoteLines.isEmpty {
            return localLines
        }

        var merged = localLines
        for line in remoteLines where !merged.contains(line) {
            merged.append(line)
        }
        return merged
    }

    private static func longestCommonSubsequencePairs(
        _ localLines: [String],
        _ remoteLines: [String]
    ) -> [(localIndex: Int, remoteIndex: Int)] {
        let localCount = localLines.count
        let remoteCount = remoteLines.count
        var lengths = Array(
            repeating: Array(repeating: 0, count: remoteCount + 1),
            count: localCount + 1
        )

        if localCount > 0 && remoteCount > 0 {
            for localIndex in stride(from: localCount - 1, through: 0, by: -1) {
                for remoteIndex in stride(from: remoteCount - 1, through: 0, by: -1) {
                    if localLines[localIndex] == remoteLines[remoteIndex] {
                        lengths[localIndex][remoteIndex] = lengths[localIndex + 1][remoteIndex + 1] + 1
                    } else {
                        lengths[localIndex][remoteIndex] = max(
                            lengths[localIndex + 1][remoteIndex],
                            lengths[localIndex][remoteIndex + 1]
                        )
                    }
                }
            }
        }

        var pairs: [(localIndex: Int, remoteIndex: Int)] = []
        var localIndex = 0
        var remoteIndex = 0
        while localIndex < localCount && remoteIndex < remoteCount {
            if localLines[localIndex] == remoteLines[remoteIndex] {
                pairs.append((localIndex, remoteIndex))
                localIndex += 1
                remoteIndex += 1
            } else if lengths[localIndex + 1][remoteIndex] >= lengths[localIndex][remoteIndex + 1] {
                localIndex += 1
            } else {
                remoteIndex += 1
            }
        }
        return pairs
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
            SELECT conflict_versions.id,
                   conflict_versions.block_id,
                   conflict_versions.payload_json,
                   conflict_versions.text_plain,
                   conflict_versions.remote_revision,
                   blocks.page_id
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
            localTextPlain: "",
            remoteTextPlain: row["text_plain"] ?? "",
            remoteRevision: Int(row["remote_revision"] ?? "") ?? 0
        )
        let pageID = row["page_id"] ?? ""
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
                DELETE FROM sync_changes
                WHERE entity_type = 'page'
                  AND entity_id = ?
                  AND NOT EXISTS (
                      SELECT 1
                      FROM sync_changes
                      WHERE entity_type = 'block'
                        AND entity_id IN (
                            SELECT id
                            FROM blocks
                            WHERE page_id = ?
                        )
                  )
                """,
                bindings: [
                    .text(pageID),
                    .text(pageID)
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
                text: snapshot.textPlain,
                pageReferenceTargetPageID: Self.pageReferenceTargetPageID(payloadJSON: payloadJSON),
                blockReferenceTargetBlockID: Self.blockReferenceTargetBlockID(payloadJSON: payloadJSON),
                inlineInternalLinks: InlineInternalLinkTarget.pruned(
                    payloadJSON: payloadJSON,
                    visibleText: snapshot.textPlain
                )
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
                   blocks.payload_json AS local_payload_json,
                   conflict_versions.payload_json AS remote_payload_json,
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
        let payloadJSON = try AutomaticTextMerge.payloadJSON(
            updating: row["local_payload_json"] ?? "",
            text: text,
            preservingInlineLinksFrom: [row["remote_payload_json"] ?? ""]
        )
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
                text: text,
                pageReferenceTargetPageID: Self.pageReferenceTargetPageID(payloadJSON: payloadJSON),
                blockReferenceTargetBlockID: Self.blockReferenceTargetBlockID(payloadJSON: payloadJSON),
                inlineInternalLinks: InlineInternalLinkTarget.pruned(
                    payloadJSON: payloadJSON,
                    visibleText: text
                )
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

    func resolveAutomatically(pageID: String) throws -> [ConflictSnapshot] {
        let pageConflicts = try conflicts(pageID: pageID)
        var resolved: [ConflictSnapshot] = []
        var resolvedBlockIDs: Set<String> = []

        for conflict in pageConflicts where !resolvedBlockIDs.contains(conflict.blockID) {
            resolved.append(try resolveAutomatically(conflictID: conflict.id))
            resolvedBlockIDs.insert(conflict.blockID)
        }
        return resolved
    }

    func resolveAutomatically(conflictID: String) throws -> ConflictSnapshot {
        guard let row = try database.query(
            """
            SELECT conflict_versions.id,
                   conflict_versions.block_id,
                   blocks.text_plain AS local_text_plain,
                   blocks.payload_json AS local_payload_json,
                   blocks.revision AS local_revision,
                   conflict_versions.payload_json AS remote_payload_json,
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
        let mergedText = AutomaticTextMerge.merge(
            local: snapshot.localTextPlain,
            remote: snapshot.remoteTextPlain
        )
        let payloadJSON = try AutomaticTextMerge.payloadJSON(
            updating: row["local_payload_json"] ?? "",
            text: mergedText,
            preservingInlineLinksFrom: [row["remote_payload_json"] ?? ""]
        )
        let localRevision = Int(row["local_revision"] ?? "") ?? 0
        let mergedRevision = max(localRevision, snapshot.remoteRevision) + 1
        let now = ISO8601DateFormatter().string(from: Date())

        try database.withImmediateTransaction("resolve_automatic_conflict") {
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
                    .text(mergedText),
                    .integer(mergedRevision),
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
                text: mergedText,
                pageReferenceTargetPageID: Self.pageReferenceTargetPageID(payloadJSON: payloadJSON),
                blockReferenceTargetBlockID: Self.blockReferenceTargetBlockID(payloadJSON: payloadJSON),
                inlineInternalLinks: InlineInternalLinkTarget.pruned(
                    payloadJSON: payloadJSON,
                    visibleText: mergedText
                )
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

    private static func pageReferenceTargetPageID(payloadJSON: String) -> String? {
        guard let data = payloadJSON.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let targetPageID = payload["target_page_id"] as? String,
              !targetPageID.isEmpty else {
            return nil
        }

        return targetPageID
    }

    private static func blockReferenceTargetBlockID(payloadJSON: String) -> String? {
        guard let data = payloadJSON.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let targetBlockID = payload["target_block_id"] as? String,
              !targetBlockID.isEmpty else {
            return nil
        }

        return targetBlockID
    }
}

enum ConflictRepositoryError: Error, Equatable {
    case conflictNotFound
}
