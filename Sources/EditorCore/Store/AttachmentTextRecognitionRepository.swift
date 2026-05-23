import Foundation

struct AttachmentRecognizedTextBoundingBox: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct AttachmentRecognizedTextObservation: Codable, Equatable, Sendable {
    let text: String
    let confidence: Double
    let boundingBox: AttachmentRecognizedTextBoundingBox
}

struct AttachmentRecognizedText: Equatable, Sendable {
    let attachmentID: String
    let contentHash: String
    let recognizedText: String
    let observations: [AttachmentRecognizedTextObservation]
}

protocol ImageTextRecognizing: Sendable {
    func recognizeText(in imageURL: URL) throws -> [AttachmentRecognizedTextObservation]
}

final class AttachmentTextRecognitionRepository: @unchecked Sendable {
    private let database: SQLiteDatabase
    private let fileManager: FileManager
    private let dateProvider: () -> Date
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        database: SQLiteDatabase,
        fileManager: FileManager = .default,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.database = database
        self.fileManager = fileManager
        self.dateProvider = dateProvider
    }

    func upsertRecognizedText(
        attachmentID: String,
        contentHash: String,
        observations: [AttachmentRecognizedTextObservation]
    ) throws {
        let recognizedText = observations
            .map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
        let regionsJSON = String(data: try encoder.encode(observations), encoding: .utf8) ?? "[]"
        let recognizedAt = ISO8601DateFormatter().string(from: dateProvider())

        try database.execute(
            """
            INSERT INTO attachment_text_recognition (
                attachment_id,
                content_hash,
                recognized_text,
                regions_json,
                recognized_at
            )
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(attachment_id) DO UPDATE SET
                content_hash = excluded.content_hash,
                recognized_text = excluded.recognized_text,
                regions_json = excluded.regions_json,
                recognized_at = excluded.recognized_at
            """,
            bindings: [
                .text(attachmentID),
                .text(contentHash),
                .text(recognizedText),
                .text(regionsJSON),
                .text(recognizedAt)
            ]
        )
    }

    func recognizedText(attachmentID: String) throws -> AttachmentRecognizedText? {
        guard let row = try database.query(
            """
            SELECT attachment_id,
                   content_hash,
                   recognized_text,
                   regions_json
            FROM attachment_text_recognition
            WHERE attachment_id = ?
            LIMIT 1
            """,
            bindings: [.text(attachmentID)]
        ).first else {
            return nil
        }

        return AttachmentRecognizedText(
            attachmentID: row["attachment_id"] ?? attachmentID,
            contentHash: row["content_hash"] ?? "",
            recognizedText: row["recognized_text"] ?? "",
            observations: observations(from: row["regions_json"] ?? "[]")
        )
    }

    func observations(attachmentID: String) throws -> [AttachmentRecognizedTextObservation] {
        try recognizedText(attachmentID: attachmentID)?.observations ?? []
    }

    @discardableResult
    func recognizeImageAttachmentIfNeeded(
        attachmentID: String,
        recognizer: ImageTextRecognizing
    ) throws -> Bool {
        guard let row = try database.query(
            """
            SELECT id,
                   uti_type,
                   content_hash,
                   local_path
            FROM attachments
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(attachmentID)]
        ).first else {
            return false
        }

        let utiType = row["uti_type"] ?? ""
        guard AttachmentKind(utiType: utiType) == .image else {
            return false
        }

        let contentHash = row["content_hash"] ?? ""
        guard !contentHash.isEmpty,
              try currentRecognitionContentHash(attachmentID: attachmentID) != contentHash else {
            return false
        }

        let localPath = row["local_path"] ?? ""
        guard fileManager.fileExists(atPath: localPath) else {
            return false
        }

        let observations = try recognizer.recognizeText(in: URL(fileURLWithPath: localPath))
        try upsertRecognizedText(
            attachmentID: attachmentID,
            contentHash: contentHash,
            observations: observations
        )
        return true
    }

    func pendingImageAttachmentIDs(limit: Int = 200) throws -> [String] {
        guard limit > 0 else {
            return []
        }

        let rows = try database.query(
            """
            SELECT attachments.id AS id,
                   attachments.uti_type AS uti_type,
                   attachments.content_hash AS content_hash,
                   attachment_text_recognition.content_hash AS recognized_hash
            FROM attachments
            LEFT JOIN attachment_text_recognition
              ON attachment_text_recognition.attachment_id = attachments.id
            WHERE EXISTS (
                SELECT 1
                FROM blocks
                INNER JOIN pages ON pages.id = blocks.page_id
                WHERE blocks.is_deleted = 0
                  AND pages.is_archived = 0
                  AND pages.is_encrypted = 0
                  AND blocks.type = ?
                  AND json_valid(blocks.payload_json)
                  AND json_extract(blocks.payload_json, '$.attachment_id') = attachments.id
            )
            ORDER BY attachments.created_at ASC
            LIMIT ?
            """,
            bindings: [
                .text(BlockType.attachmentImage.rawValue),
                .integer(limit)
            ]
        )

        return rows.compactMap { row in
            guard AttachmentKind(utiType: row["uti_type"] ?? "") == .image,
                  row["content_hash"] != row["recognized_hash"] else {
                return nil
            }
            return row["id"] ?? ""
        }.filter { !$0.isEmpty }
    }

    private func observations(from regionsJSON: String) -> [AttachmentRecognizedTextObservation] {
        guard let data = regionsJSON.data(using: .utf8) else {
            return []
        }
        return (try? decoder.decode([AttachmentRecognizedTextObservation].self, from: data)) ?? []
    }

    private func currentRecognitionContentHash(attachmentID: String) throws -> String? {
        try database.query(
            """
            SELECT content_hash
            FROM attachment_text_recognition
            WHERE attachment_id = ?
            LIMIT 1
            """,
            bindings: [.text(attachmentID)]
        ).first?["content_hash"] ?? nil
    }
}
