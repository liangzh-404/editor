import AVFoundation
import Foundation
import XCTest

final class AttachmentRepositoryTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testImportFileCopiesIntoManagedStorageAndPersistsAttachmentBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let initialSnapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(initialSnapshot.selectedPageID)
        let sourceURL = try makeSourceFile(name: "brief.txt", contents: "local attachment")
        let attachmentDirectory = makeTemporaryDirectory()

        let repository = AttachmentRepository(
            database: database,
            attachmentsDirectory: attachmentDirectory
        )
        let result = try repository.importAttachment(
            sourceURL: sourceURL,
            workspaceID: workspaceID,
            pageID: pageID
        )

        XCTAssertEqual(result.attachment.originalFilename, "brief.txt")
        XCTAssertEqual(result.attachment.kind, .file)
        XCTAssertEqual(result.block.type, .attachmentFile)
        XCTAssertNotEqual(result.attachment.localPath, sourceURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.attachment.localPath))
        XCTAssertEqual(
            try String(contentsOfFile: result.attachment.localPath, encoding: .utf8),
            "local attachment"
        )

        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()
        XCTAssertTrue(reloadedSnapshot.attachments.contains(result.attachment))
        XCTAssertTrue(reloadedSnapshot.blocks.contains(result.block))
    }

    func testImportClassifiesImageVideoAndGenericFiles() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let initialSnapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(initialSnapshot.selectedPageID)
        let repository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )

        let image = try repository.importAttachment(
            sourceURL: makeSourceFile(name: "photo.png", contents: "image-bytes"),
            workspaceID: workspaceID,
            pageID: pageID
        )
        let video = try repository.importAttachment(
            sourceURL: makeSourceFile(name: "clip.mov", contents: "video-bytes"),
            workspaceID: workspaceID,
            pageID: pageID
        )
        let file = try repository.importAttachment(
            sourceURL: makeSourceFile(name: "notes.md", contents: "# Notes"),
            workspaceID: workspaceID,
            pageID: pageID
        )

        XCTAssertEqual(image.attachment.kind, .image)
        XCTAssertEqual(image.block.type, .attachmentImage)
        XCTAssertEqual(video.attachment.kind, .video)
        XCTAssertEqual(video.block.type, .attachmentVideo)
        XCTAssertEqual(file.attachment.kind, .file)
        XCTAssertEqual(file.block.type, .attachmentFile)
    }

    func testImportDrawingPersistsEditableDrawingBlock() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let initialSnapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(initialSnapshot.selectedPageID)
        let repository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let drawingData = Data("editable-drawing-data".utf8)

        let result = try repository.importAttachment(
            sourceURL: try makeSourceFile(name: "sketch.drawing", data: drawingData),
            workspaceID: workspaceID,
            pageID: pageID
        )

        XCTAssertEqual(result.attachment.kind.rawValue, "drawing")
        XCTAssertEqual(result.attachment.utiType, "com.apple.drawing")
        XCTAssertEqual(result.block.type.rawValue, "drawing")
        XCTAssertEqual(result.block.textPlain, "sketch.drawing")
        XCTAssertEqual(result.block.attachmentID, result.attachment.id)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: result.attachment.localPath)), drawingData)

        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()
        let reloadedBlock = try XCTUnwrap(reloadedSnapshot.blocks.first { $0.id == result.block.id })
        let reloadedAttachment = try XCTUnwrap(reloadedSnapshot.attachments.first { $0.id == result.attachment.id })
        XCTAssertEqual(reloadedBlock.type.rawValue, "drawing")
        XCTAssertTrue(reloadedAttachment.matches(block: reloadedBlock))
    }

    func testImportImageCreatesAndPersistsThumbnail() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let initialSnapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(initialSnapshot.selectedPageID)
        let repository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )

        let result = try repository.importAttachment(
            sourceURL: try makeSourceFile(name: "photo.png", data: Self.onePixelPNGData),
            workspaceID: workspaceID,
            pageID: pageID
        )
        let thumbnailPath = try XCTUnwrap(result.attachment.thumbnailPath)
        let reloadedAttachment = try XCTUnwrap(
            pageRepository.loadWorkspaceSnapshot().attachments.first { $0.id == result.attachment.id }
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbnailPath))
        XCTAssertNotEqual(thumbnailPath, result.attachment.localPath)
        XCTAssertEqual(reloadedAttachment.thumbnailPath, thumbnailPath)
    }

    func testImportImageCanDeferThumbnailAndGenerateItLater() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let initialSnapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(initialSnapshot.selectedPageID)
        let repository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )

        let result = try repository.importAttachment(
            sourceURL: try makeSourceFile(name: "photo.png", data: Self.onePixelPNGData),
            workspaceID: workspaceID,
            pageID: pageID,
            thumbnailPolicy: .deferred
        )

        XCTAssertNil(result.attachment.thumbnailPath)
        XCTAssertNil(
            try pageRepository.loadWorkspaceSnapshot().attachments.first { $0.id == result.attachment.id }?.thumbnailPath
        )

        let generatedThumbnailPath = try XCTUnwrap(
            try repository.generateMissingThumbnail(attachmentID: result.attachment.id)
        )
        let reloadedAttachment = try XCTUnwrap(
            pageRepository.loadWorkspaceSnapshot().attachments.first { $0.id == result.attachment.id }
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: generatedThumbnailPath))
        XCTAssertNotEqual(generatedThumbnailPath, result.attachment.localPath)
        XCTAssertEqual(reloadedAttachment.thumbnailPath, generatedThumbnailPath)
    }

    func testRepairAttachmentFilePathsRestoresMovedAppContainerPaths() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let initialSnapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(initialSnapshot.selectedPageID)
        let oldAttachmentsDirectory = makeTemporaryDirectory()
        let newAttachmentsDirectory = makeTemporaryDirectory()
        let oldRepository = AttachmentRepository(
            database: database,
            attachmentsDirectory: oldAttachmentsDirectory
        )
        let result = try oldRepository.importAttachment(
            sourceURL: try makeSourceFile(name: "photo.png", data: Self.onePixelPNGData),
            workspaceID: workspaceID,
            pageID: pageID
        )
        let oldAttachmentDirectory = URL(fileURLWithPath: result.attachment.localPath)
            .deletingLastPathComponent()
        let newAttachmentDirectory = newAttachmentsDirectory
            .appendingPathComponent(workspaceID, isDirectory: true)
            .appendingPathComponent(result.attachment.id, isDirectory: true)
        try FileManager.default.createDirectory(
            at: newAttachmentDirectory.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.moveItem(
            at: oldAttachmentDirectory,
            to: newAttachmentDirectory
        )

        let repairedCount = try AttachmentRepository(
            database: database,
            attachmentsDirectory: newAttachmentsDirectory
        ).repairAttachmentFilePaths()
        let repairedAttachment = try XCTUnwrap(
            pageRepository.loadWorkspaceSnapshot().attachments.first { $0.id == result.attachment.id }
        )

        XCTAssertEqual(repairedCount, 1)
        XCTAssertEqual(
            repairedAttachment.localPath,
            newAttachmentDirectory.appendingPathComponent("photo.png").path
        )
        XCTAssertEqual(
            repairedAttachment.thumbnailPath,
            newAttachmentDirectory.appendingPathComponent("thumbnail.jpg").path
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: repairedAttachment.localPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(repairedAttachment.thumbnailPath)))
    }

    func testImportVideoCreatesAndPersistsThumbnail() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let initialSnapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(initialSnapshot.selectedPageID)
        let repository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )

        let result = try repository.importAttachment(
            sourceURL: try makeTinyVideoFile(name: "clip.mov"),
            workspaceID: workspaceID,
            pageID: pageID
        )
        let thumbnailPath = try XCTUnwrap(result.attachment.thumbnailPath)
        let reloadedAttachment = try XCTUnwrap(
            pageRepository.loadWorkspaceSnapshot().attachments.first { $0.id == result.attachment.id }
        )

        XCTAssertEqual(result.attachment.kind, .video)
        XCTAssertEqual(result.block.type, .attachmentVideo)
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbnailPath))
        XCTAssertNotEqual(thumbnailPath, result.attachment.localPath)
        XCTAssertEqual(reloadedAttachment.thumbnailPath, thumbnailPath)
    }

    func testAttachmentSnapshotMatchesItsAttachmentBlockForPreview() {
        let attachment = AttachmentSnapshot(
            id: "attachment-photo",
            workspaceID: "workspace-local",
            originalFilename: "photo.png",
            utiType: "public.png",
            byteSize: 12,
            contentHash: "hash",
            localPath: "/tmp/photo.png",
            thumbnailPath: "/tmp/thumbnail.jpg",
            kind: .image
        )
        let matchingBlock = BlockSnapshot(
            id: "block-photo",
            pageID: "page-local",
            parentBlockID: nil,
            orderKey: "000002",
            type: .attachmentImage,
            textPlain: "photo.png"
        )
        let fileBlock = matchingBlock.replacing(type: .attachmentFile, text: "photo.png")

        XCTAssertTrue(attachment.matches(block: matchingBlock))
        XCTAssertFalse(attachment.matches(block: fileBlock))
    }

    func testAttachmentSnapshotDoesNotMatchDifferentPayloadAttachmentID() {
        let attachment = AttachmentSnapshot(
            id: "attachment-photo",
            workspaceID: "workspace-local",
            originalFilename: "photo.png",
            utiType: "public.png",
            byteSize: 12,
            contentHash: "hash",
            localPath: "/tmp/photo.png",
            thumbnailPath: "/tmp/thumbnail.jpg",
            kind: .image
        )
        let otherAttachmentBlock = BlockSnapshot(
            id: "block-photo",
            pageID: "page-local",
            parentBlockID: nil,
            orderKey: "000002",
            type: .attachmentImage,
            textPlain: "photo.png",
            attachmentID: "attachment-other"
        )

        XCTAssertFalse(attachment.matches(block: otherAttachmentBlock))
    }

    func testImportedAttachmentBlockCarriesPayloadAttachmentID() throws {
        let database = try migratedDatabase()
        defer { database.close() }
        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let repository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )

        let result = try repository.importAttachment(
            sourceURL: makeSourceFile(name: "photo.png", contents: "image bytes"),
            workspaceID: workspaceID,
            pageID: pageID
        )

        let reloadedBlock = try XCTUnwrap(
            pageRepository.loadWorkspaceSnapshot().blocks.first { $0.id == result.block.id }
        )
        XCTAssertEqual(reloadedBlock.attachmentID, result.attachment.id)
    }

    func testAttachmentPreviewPathSupportsImageAndVideoBlocksOnly() {
        let imageAttachment = AttachmentSnapshot(
            id: "attachment-photo",
            workspaceID: "workspace-local",
            originalFilename: "photo.png",
            utiType: "public.png",
            byteSize: 12,
            contentHash: "hash",
            localPath: "/tmp/photo.png",
            thumbnailPath: "/tmp/photo-thumbnail.jpg",
            kind: .image
        )
        let videoAttachment = AttachmentSnapshot(
            id: "attachment-video",
            workspaceID: "workspace-local",
            originalFilename: "clip.mov",
            utiType: "com.apple.quicktime-movie",
            byteSize: 12,
            contentHash: "hash",
            localPath: "/tmp/clip.mov",
            thumbnailPath: "/tmp/video-thumbnail.jpg",
            kind: .video
        )
        let fileAttachment = AttachmentSnapshot(
            id: "attachment-file",
            workspaceID: "workspace-local",
            originalFilename: "brief.txt",
            utiType: "public.plain-text",
            byteSize: 12,
            contentHash: "hash",
            localPath: "/tmp/brief.txt",
            thumbnailPath: nil,
            kind: .file
        )

        XCTAssertEqual(
            imageAttachment.previewPath(for: BlockSnapshot(
                id: "block-photo",
                pageID: "page-local",
                parentBlockID: nil,
                orderKey: "000001",
                type: .attachmentImage,
                textPlain: "photo.png"
            )),
            "/tmp/photo.png"
        )
        XCTAssertEqual(
            videoAttachment.previewPath(for: BlockSnapshot(
                id: "block-video",
                pageID: "page-local",
                parentBlockID: nil,
                orderKey: "000002",
                type: .attachmentVideo,
                textPlain: "clip.mov"
            )),
            "/tmp/video-thumbnail.jpg"
        )
        XCTAssertNil(fileAttachment.previewPath(for: BlockSnapshot(
            id: "block-file",
            pageID: "page-local",
            parentBlockID: nil,
            orderKey: "000003",
            type: .attachmentFile,
            textPlain: "brief.txt"
        )))
    }

    func testAttachmentPreviewStateShowsPendingForMediaWithoutThumbnail() {
        let imageBlock = BlockSnapshot(
            id: "block-photo",
            pageID: "page-local",
            parentBlockID: nil,
            orderKey: "000001",
            type: .attachmentImage,
            textPlain: "photo.png"
        )
        let videoBlock = BlockSnapshot(
            id: "block-video",
            pageID: "page-local",
            parentBlockID: nil,
            orderKey: "000002",
            type: .attachmentVideo,
            textPlain: "clip.mov"
        )
        let fileBlock = BlockSnapshot(
            id: "block-file",
            pageID: "page-local",
            parentBlockID: nil,
            orderKey: "000003",
            type: .attachmentFile,
            textPlain: "brief.txt"
        )
        let imageAttachment = AttachmentSnapshot(
            id: "attachment-photo",
            workspaceID: "workspace-local",
            originalFilename: "photo.png",
            utiType: "public.png",
            byteSize: 12,
            contentHash: "hash",
            localPath: "/tmp/photo.png",
            thumbnailPath: nil,
            kind: .image
        )
        let videoAttachment = AttachmentSnapshot(
            id: "attachment-video",
            workspaceID: "workspace-local",
            originalFilename: "clip.mov",
            utiType: "com.apple.quicktime-movie",
            byteSize: 12,
            contentHash: "hash",
            localPath: "/tmp/clip.mov",
            thumbnailPath: nil,
            kind: .video
        )
        let fileAttachment = AttachmentSnapshot(
            id: "attachment-file",
            workspaceID: "workspace-local",
            originalFilename: "brief.txt",
            utiType: "public.plain-text",
            byteSize: 12,
            contentHash: "hash",
            localPath: "/tmp/brief.txt",
            thumbnailPath: nil,
            kind: .file
        )

        XCTAssertEqual(imageAttachment.previewState(for: imageBlock), .thumbnail("/tmp/photo.png"))
        XCTAssertEqual(videoAttachment.previewState(for: videoBlock), .pending)
        XCTAssertEqual(fileAttachment.previewState(for: fileBlock), .unavailable)
        XCTAssertEqual(imageAttachment.previewPath(for: imageBlock), "/tmp/photo.png")
    }

    func testDeletingAttachmentBlockRemovesReferenceButKeepsAttachmentMetadata() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let initialSnapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(initialSnapshot.selectedPageID)
        let repository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let result = try repository.importAttachment(
            sourceURL: makeSourceFile(name: "brief.txt", contents: "local attachment"),
            workspaceID: workspaceID,
            pageID: pageID
        )

        try pageRepository.deleteBlock(blockID: result.block.id)
        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()

        XCTAssertFalse(reloadedSnapshot.blocks.contains { $0.id == result.block.id })
        XCTAssertTrue(reloadedSnapshot.attachments.contains(result.attachment))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.attachment.localPath))
    }

    func testPurgeUnreferencedAttachmentsRemovesMetadataAndLocalFiles() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let initialSnapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let pageID = try XCTUnwrap(initialSnapshot.selectedPageID)
        let repository = AttachmentRepository(
            database: database,
            attachmentsDirectory: makeTemporaryDirectory()
        )
        let result = try repository.importAttachment(
            sourceURL: makeSourceFile(name: "brief.txt", contents: "local attachment"),
            workspaceID: workspaceID,
            pageID: pageID
        )
        let attachmentDirectory = URL(fileURLWithPath: result.attachment.localPath)
            .deletingLastPathComponent()
        try pageRepository.deleteBlock(blockID: result.block.id)

        let purgedCount = try repository.purgeUnreferencedAttachments(workspaceID: workspaceID)
        let reloadedSnapshot = try pageRepository.loadWorkspaceSnapshot()

        XCTAssertEqual(purgedCount, 1)
        XCTAssertFalse(reloadedSnapshot.attachments.contains { $0.id == result.attachment.id })
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.attachment.localPath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: attachmentDirectory.path))
    }

    private func migratedDatabase() throws -> SQLiteDatabase {
        let database = try SQLiteDatabase.open(path: makeTemporaryDirectory().appendingPathComponent("editor.sqlite").path)
        try SchemaMigrator.migrate(database: database)
        return database
    }

    private func makeSourceFile(name: String, contents: String) throws -> URL {
        let directory = makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent(name)
        try contents.data(using: .utf8)?.write(to: fileURL)
        return fileURL
    }

    private func makeSourceFile(name: String, data: Data) throws -> URL {
        let directory = makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent(name)
        try data.write(to: fileURL)
        return fileURL
    }

    private func makeTinyVideoFile(name: String) throws -> URL {
        let directory = makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent(name)
        let writer = try AVAssetWriter(outputURL: fileURL, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 16,
                AVVideoHeightKey: 16
            ]
        )
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: 16,
                kCVPixelBufferHeightKey as String: 16
            ]
        )
        writer.add(input)

        guard writer.startWriting() else {
            throw writer.error ?? AttachmentRepositoryTestError.videoWriterFailed
        }
        writer.startSession(atSourceTime: .zero)

        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw AttachmentRepositoryTestError.missingPixelBufferPool
        }
        var pixelBuffer: CVPixelBuffer?
        let pixelBufferStatus = CVPixelBufferPoolCreatePixelBuffer(
            nil,
            pixelBufferPool,
            &pixelBuffer
        )
        guard pixelBufferStatus == kCVReturnSuccess, let pixelBuffer else {
            throw AttachmentRepositoryTestError.pixelBufferCreationFailed(pixelBufferStatus)
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            memset(baseAddress, 0x44, CVPixelBufferGetDataSize(pixelBuffer))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.01)
        }
        guard adaptor.append(pixelBuffer, withPresentationTime: .zero) else {
            throw writer.error ?? AttachmentRepositoryTestError.videoWriterFailed
        }
        input.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        if writer.status == .failed {
            throw writer.error ?? AttachmentRepositoryTestError.videoWriterFailed
        }

        return fileURL
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        temporaryFiles.append(directory)
        return directory
    }

    private static let onePixelPNGData = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
    )!
}

private enum AttachmentRepositoryTestError: Error {
    case missingPixelBufferPool
    case pixelBufferCreationFailed(CVReturn)
    case videoWriterFailed
}
