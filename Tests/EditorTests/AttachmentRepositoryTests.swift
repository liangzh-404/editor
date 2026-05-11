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
