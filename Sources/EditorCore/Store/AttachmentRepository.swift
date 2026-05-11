import CryptoKit
import Foundation
import UniformTypeIdentifiers

struct AttachmentImportResult: Equatable {
    let attachment: AttachmentSnapshot
    let block: BlockSnapshot
}

final class AttachmentRepository {
    private let database: SQLiteDatabase
    private let attachmentsDirectory: URL
    private let fileManager: FileManager

    init(
        database: SQLiteDatabase,
        attachmentsDirectory: URL,
        fileManager: FileManager = .default
    ) {
        self.database = database
        self.attachmentsDirectory = attachmentsDirectory
        self.fileManager = fileManager
    }

    func importAttachment(
        sourceURL: URL,
        workspaceID: String,
        pageID: String
    ) throws -> AttachmentImportResult {
        let data = try Data(contentsOf: sourceURL)
        let now = ISO8601DateFormatter().string(from: Date())
        let attachmentID = "attachment-\(UUID().uuidString.lowercased())"
        let blockID = "block-\(UUID().uuidString.lowercased())"
        let originalFilename = sourceURL.lastPathComponent
        let utiType = UTType(filenameExtension: sourceURL.pathExtension)?.identifier ?? UTType.data.identifier
        let kind = AttachmentKind(utiType: utiType)
        let targetDirectory = attachmentsDirectory
            .appendingPathComponent(workspaceID, isDirectory: true)
            .appendingPathComponent(attachmentID, isDirectory: true)
        let targetURL = targetDirectory.appendingPathComponent(originalFilename)

        try fileManager.createDirectory(
            at: targetDirectory,
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(at: sourceURL, to: targetURL)

        let attachment = AttachmentSnapshot(
            id: attachmentID,
            workspaceID: workspaceID,
            originalFilename: originalFilename,
            utiType: utiType,
            byteSize: data.count,
            contentHash: sha256Hex(data),
            localPath: targetURL.path,
            thumbnailPath: nil,
            kind: kind
        )
        let block = BlockSnapshot(
            id: blockID,
            pageID: pageID,
            parentBlockID: nil,
            orderKey: try nextOrderKey(pageID: pageID),
            type: kind.blockType,
            textPlain: originalFilename
        )

        do {
            try insert(attachment: attachment, createdAt: now)
            try insert(block: block, attachmentID: attachment.id, kind: kind, createdAt: now)
            let syncRepository = SyncRepository(database: database)
            try syncRepository.enqueue(
                entityType: "attachment",
                entityID: attachment.id,
                changeType: "create"
            )
            try syncRepository.enqueue(
                entityType: "block",
                entityID: block.id,
                changeType: "create"
            )
        } catch {
            try? fileManager.removeItem(at: targetDirectory)
            throw error
        }

        EditorLog.attachment.debug(
            "attachment_imported id=\(attachmentID, privacy: .public) kind=\(kind.rawValue, privacy: .public) bytes=\(data.count, privacy: .public)"
        )
        return AttachmentImportResult(attachment: attachment, block: block)
    }

    private func insert(attachment: AttachmentSnapshot, createdAt: String) throws {
        try database.execute(
            """
            INSERT INTO attachments (
                id,
                workspace_id,
                original_filename,
                uti_type,
                byte_size,
                content_hash,
                local_path,
                thumbnail_path,
                sync_state,
                created_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(attachment.id),
                .text(attachment.workspaceID),
                .text(attachment.originalFilename),
                .text(attachment.utiType),
                .integer(attachment.byteSize),
                .text(attachment.contentHash),
                .text(attachment.localPath),
                attachment.thumbnailPath.map(SQLiteValue.text) ?? .null,
                .text("local"),
                .text(createdAt),
                .text(createdAt)
            ]
        )
    }

    private func insert(
        block: BlockSnapshot,
        attachmentID: String,
        kind: AttachmentKind,
        createdAt: String
    ) throws {
        try database.execute(
            """
            INSERT INTO blocks (
                id,
                page_id,
                parent_block_id,
                order_key,
                type,
                payload_json,
                text_plain,
                revision,
                sync_state,
                is_deleted,
                created_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(block.id),
                .text(block.pageID),
                .null,
                .text(block.orderKey),
                .text(block.type.rawValue),
                .text(try attachmentPayloadJSON(attachmentID: attachmentID, kind: kind, filename: block.textPlain)),
                .text(block.textPlain),
                .integer(1),
                .text("local"),
                .integer(0),
                .text(createdAt),
                .text(createdAt)
            ]
        )
    }

    private func nextOrderKey(pageID: String) throws -> String {
        let rows = try database.query(
            """
            SELECT order_key
            FROM blocks
            WHERE page_id = ? AND is_deleted = 0
            ORDER BY order_key DESC
            LIMIT 1
            """,
            bindings: [.text(pageID)]
        )
        let lastOrderKey = rows.first.flatMap { $0["order_key"] } ?? "000000"
        let nextValue = (Int(lastOrderKey) ?? 0) + 1
        return String(format: "%06d", nextValue)
    }

    private func attachmentPayloadJSON(
        attachmentID: String,
        kind: AttachmentKind,
        filename: String
    ) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: [
                "attachment_id": attachmentID,
                "filename": filename,
                "kind": kind.rawValue
            ],
            options: [.sortedKeys]
        )

        guard let payload = String(data: data, encoding: .utf8) else {
            throw AttachmentRepositoryError.invalidPayloadEncoding
        }

        return payload
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

enum AttachmentRepositoryError: Error, Equatable {
    case invalidPayloadEncoding
}
