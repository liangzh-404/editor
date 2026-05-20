import Foundation
import XCTest

final class LocalSyncGenerationResetPolicyTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testPrepareStoreDirectoryDropsExistingLocalDataWhenGenerationMarkerIsMissing() throws {
        let root = makeTemporaryDirectory()
        let editorDirectory = root.appendingPathComponent("Editor", isDirectory: true)
        let attachmentDirectory = editorDirectory.appendingPathComponent("Attachments", isDirectory: true)
        try FileManager.default.createDirectory(at: attachmentDirectory, withIntermediateDirectories: true)
        try Data("old database".utf8).write(to: editorDirectory.appendingPathComponent("editor.sqlite"))
        try Data("old attachment".utf8).write(to: attachmentDirectory.appendingPathComponent("old.txt"))

        let preparedDirectory = try LocalSyncGenerationResetPolicy.prepareStoreDirectory(
            applicationSupportRoot: root,
            currentGeneration: "editor-cloudkit-v2"
        )

        XCTAssertEqual(preparedDirectory, editorDirectory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: editorDirectory.appendingPathComponent("editor.sqlite").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: attachmentDirectory.appendingPathComponent("old.txt").path))
        XCTAssertEqual(
            try String(contentsOf: editorDirectory.appendingPathComponent(".sync-generation"), encoding: .utf8),
            "editor-cloudkit-v2"
        )
    }

    func testPrepareStoreDirectoryPreservesDataWhenGenerationMarkerMatches() throws {
        let root = makeTemporaryDirectory()
        let editorDirectory = root.appendingPathComponent("Editor", isDirectory: true)
        try FileManager.default.createDirectory(at: editorDirectory, withIntermediateDirectories: true)
        try Data("editor-cloudkit-v2".utf8).write(to: editorDirectory.appendingPathComponent(".sync-generation"))
        try Data("current database".utf8).write(to: editorDirectory.appendingPathComponent("editor.sqlite"))

        _ = try LocalSyncGenerationResetPolicy.prepareStoreDirectory(
            applicationSupportRoot: root,
            currentGeneration: "editor-cloudkit-v2"
        )

        XCTAssertEqual(
            try String(contentsOf: editorDirectory.appendingPathComponent("editor.sqlite"), encoding: .utf8),
            "current database"
        )
    }

    func testPrepareStoreDirectoryDropsExistingLocalDataWhenGenerationMarkerIsPreviousGeneration() throws {
        let root = makeTemporaryDirectory()
        let editorDirectory = root.appendingPathComponent("Editor", isDirectory: true)
        try FileManager.default.createDirectory(at: editorDirectory, withIntermediateDirectories: true)
        try Data("editor-cloudkit-v1".utf8).write(to: editorDirectory.appendingPathComponent(".sync-generation"))
        try Data("previous database".utf8).write(to: editorDirectory.appendingPathComponent("editor.sqlite"))

        _ = try LocalSyncGenerationResetPolicy.prepareStoreDirectory(
            applicationSupportRoot: root,
            currentGeneration: "editor-cloudkit-v2"
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: editorDirectory.appendingPathComponent("editor.sqlite").path))
        XCTAssertEqual(
            try String(contentsOf: editorDirectory.appendingPathComponent(".sync-generation"), encoding: .utf8),
            "editor-cloudkit-v2"
        )
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
}
