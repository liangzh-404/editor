import AVFoundation
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct AttachmentImportResult: Equatable {
    let attachment: AttachmentSnapshot
    let block: BlockSnapshot
}

enum AttachmentThumbnailPolicy: Equatable {
    case immediate
    case deferred
}

final class AttachmentRepository: @unchecked Sendable {
    private let database: SQLiteDatabase
    private let attachmentsDirectory: URL
    private let fileManager: FileManager

    init(
        database: SQLiteDatabase,
        attachmentsDirectory: URL,
        fileManager: FileManager = .default,
        encryptedNoteCipher _: EncryptedNoteCiphering = EncryptedNoteCipher()
    ) {
        self.database = database
        self.attachmentsDirectory = attachmentsDirectory
        self.fileManager = fileManager
    }

    func importAttachment(
        sourceURL: URL,
        workspaceID: String,
        pageID: String,
        thumbnailPolicy: AttachmentThumbnailPolicy = .immediate
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
        let thumbnailPath = try thumbnailPolicy == .immediate
            ? makeThumbnailIfNeeded(
                sourceURL: targetURL,
                kind: kind,
                targetDirectory: targetDirectory
            )
            : nil

        let attachment = AttachmentSnapshot(
            id: attachmentID,
            workspaceID: workspaceID,
            originalFilename: originalFilename,
            utiType: utiType,
            byteSize: data.count,
            contentHash: sha256Hex(data),
            localPath: targetURL.path,
            thumbnailPath: thumbnailPath,
            kind: kind
        )
        let block = BlockSnapshot(
            id: blockID,
            pageID: pageID,
            parentBlockID: nil,
            orderKey: try nextOrderKey(pageID: pageID),
            type: kind.blockType,
            textPlain: originalFilename,
            attachmentID: attachmentID
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

    @discardableResult
    func generateMissingThumbnail(attachmentID: String) throws -> String? {
        let rows = try database.query(
            """
            SELECT id,
                   uti_type,
                   local_path,
                   thumbnail_path
            FROM attachments
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(attachmentID)]
        )
        guard let row = rows.first else {
            throw AttachmentRepositoryError.attachmentNotFound(attachmentID)
        }

        if let existingThumbnailPath = row["thumbnail_path"] ?? nil,
           fileManager.fileExists(atPath: existingThumbnailPath) {
            return existingThumbnailPath
        }

        let utiType = row["uti_type"] ?? UTType.data.identifier
        let kind = AttachmentKind(utiType: utiType)
        guard kind != .file else {
            return nil
        }

        let localPath = row["local_path"] ?? ""
        let sourceURL = URL(fileURLWithPath: localPath)
        let targetDirectory = sourceURL.deletingLastPathComponent()
        guard let thumbnailPath = try makeThumbnailIfNeeded(
            sourceURL: sourceURL,
            kind: kind,
            targetDirectory: targetDirectory
        ) else {
            return nil
        }

        try database.execute(
            """
            UPDATE attachments
            SET thumbnail_path = ?,
                updated_at = ?
            WHERE id = ?
            """,
            bindings: [
                .text(thumbnailPath),
                .text(ISO8601DateFormatter().string(from: Date())),
                .text(attachmentID)
            ]
        )

        EditorLog.attachment.debug(
            "attachment_thumbnail_generated id=\(attachmentID, privacy: .public) kind=\(kind.rawValue, privacy: .public)"
        )
        return thumbnailPath
    }

    @discardableResult
    func purgeUnreferencedAttachments(workspaceID: String) throws -> Int {
        let orphanedAttachments = try database.query(
            """
            SELECT id, local_path, thumbnail_path
            FROM attachments
            WHERE workspace_id = ?
              AND NOT EXISTS (
                  SELECT 1
                  FROM blocks
                  WHERE blocks.is_deleted = 0
                    AND json_extract(blocks.payload_json, '$.attachment_id') = attachments.id
              )
            """,
            bindings: [.text(workspaceID)]
        )
        guard !orphanedAttachments.isEmpty else {
            return 0
        }

        try database.withImmediateTransaction("purge_unreferenced_attachments") {
            for row in orphanedAttachments {
                let attachmentID = row["id"] ?? ""
                try database.execute(
                    """
                    DELETE FROM search_index
                    WHERE entity_type = 'attachment' AND entity_id = ?
                    """,
                    bindings: [.text(attachmentID)]
                )
                try database.execute(
                    """
                    DELETE FROM attachments
                    WHERE id = ?
                    """,
                    bindings: [.text(attachmentID)]
                )
            }
        }

        for row in orphanedAttachments {
            if let localPath = row["local_path"] ?? nil {
                let attachmentDirectory = URL(fileURLWithPath: localPath)
                    .deletingLastPathComponent()
                if fileManager.fileExists(atPath: attachmentDirectory.path) {
                    try fileManager.removeItem(at: attachmentDirectory)
                }
            } else if let thumbnailPath = row["thumbnail_path"] ?? nil,
                      fileManager.fileExists(atPath: thumbnailPath) {
                try fileManager.removeItem(atPath: thumbnailPath)
            }
        }

        EditorLog.attachment.debug(
            "unreferenced_attachments_purged workspace_id=\(workspaceID, privacy: .public) count=\(orphanedAttachments.count, privacy: .public)"
        )
        return orphanedAttachments.count
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
        let isEncrypted = try pageIsEncrypted(pageID: block.pageID)
        let payloadJSON = try attachmentPayloadJSON(
            attachmentID: attachmentID,
            kind: kind,
            filename: block.textPlain
        )
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
                .text(try storedValue(payloadJSON, isEncrypted: isEncrypted)),
                .text(try storedValue(block.textPlain, isEncrypted: isEncrypted)),
                .integer(1),
                .text("local"),
                .integer(0),
                .text(createdAt),
                .text(createdAt)
            ]
        )
    }

    private func storedValue(_ plaintext: String, isEncrypted _: Bool) throws -> String {
        plaintext
    }

    private func pageIsEncrypted(pageID: String) throws -> Bool {
        let row = try database.query(
            """
            SELECT is_encrypted
            FROM pages
            WHERE id = ?
            LIMIT 1
            """,
            bindings: [.text(pageID)]
        ).first
        return (Int(row?["is_encrypted"] ?? "0") ?? 0) != 0
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

    private func makeThumbnailIfNeeded(
        sourceURL: URL,
        kind: AttachmentKind,
        targetDirectory: URL
    ) throws -> String? {
        switch kind {
        case .image:
            return try makeImageThumbnail(
                sourceURL: sourceURL,
                targetDirectory: targetDirectory
            )
        case .video:
            return try makeVideoThumbnail(
                sourceURL: sourceURL,
                targetDirectory: targetDirectory
            )
        case .file:
            return nil
        }
    }

    private func makeImageThumbnail(
        sourceURL: URL,
        targetDirectory: URL
    ) throws -> String? {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 512
        ] as CFDictionary
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return nil
        }

        return try writeThumbnail(thumbnail, targetDirectory: targetDirectory)
    }

    private func makeVideoThumbnail(
        sourceURL: URL,
        targetDirectory: URL
    ) throws -> String? {
        let asset = AVURLAsset(url: sourceURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 512, height: 512)

        let semaphore = DispatchSemaphore(value: 0)
        final class ThumbnailBox: @unchecked Sendable {
            var result: Result<CGImage, Error>?
        }
        let thumbnailBox = ThumbnailBox()

        Task {
            do {
                let result = try await generator.image(at: .zero)
                thumbnailBox.result = .success(result.image)
            } catch {
                thumbnailBox.result = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()

        do {
            let thumbnail = try thumbnailBox.result?.get() ?? {
                throw AttachmentRepositoryError.thumbnailGenerationFailed
            }()
            return try writeThumbnail(thumbnail, targetDirectory: targetDirectory)
        } catch {
            EditorLog.attachment.debug(
                "video_thumbnail_skipped source=\(sourceURL.lastPathComponent, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    private func writeThumbnail(
        _ thumbnail: CGImage,
        targetDirectory: URL
    ) throws -> String? {
        let thumbnailURL = targetDirectory.appendingPathComponent("thumbnail.jpg")
        guard let destination = CGImageDestinationCreateWithURL(
            thumbnailURL as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let destinationOptions = [
            kCGImageDestinationLossyCompressionQuality: 0.82
        ] as CFDictionary
        CGImageDestinationAddImage(destination, thumbnail, destinationOptions)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return thumbnailURL.path
    }
}

enum AttachmentRepositoryError: Error, Equatable {
    case attachmentNotFound(String)
    case invalidPayloadEncoding
    case thumbnailGenerationFailed
}
