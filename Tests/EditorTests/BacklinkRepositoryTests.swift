import Foundation
import XCTest

final class BacklinkRepositoryTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try super.tearDownWithError()
    }

    func testBlockUpdateMaintainsBacklinksForPageMentions() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        try pageRepository.updateBlockText(blockID: blockID, text: "See [[欢迎]]")

        XCTAssertEqual(
            try BacklinkRepository(database: database).backlinks(targetPageID: pageID),
            [
                Backlink(
                    sourcePageID: pageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: blockID,
                    targetPageID: pageID,
                    targetBlockID: nil,
                    linkText: "欢迎"
                )
            ]
        )
    }

    func testBlockUpdateRemovesStaleBacklinks() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        try pageRepository.updateBlockText(blockID: blockID, text: "See [[欢迎]]")
        try pageRepository.updateBlockText(blockID: blockID, text: "No link now")

        XCTAssertEqual(
            try BacklinkRepository(database: database).backlinks(targetPageID: pageID),
            []
        )
    }

    func testBlockUpdateMaintainsExternalMarkdownLinksForSourcePage() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let pageRepository = PageRepository(database: database)
        let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
        let pageID = try XCTUnwrap(snapshot.selectedPageID)
        let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

        try pageRepository.updateBlockText(
            blockID: blockID,
            text: "Read [Swift](https://swift.org) and [Docs](x-editor://local)"
        )

        XCTAssertEqual(
            try BacklinkRepository(database: database).externalLinks(sourcePageID: pageID),
            [
                ExternalLink(
                    sourcePageID: pageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: blockID,
                    targetURL: "https://swift.org",
                    linkText: "Swift"
                ),
                ExternalLink(
                    sourcePageID: pageID,
                    sourcePageTitle: "欢迎",
                    sourceBlockID: blockID,
                    targetURL: "x-editor://local",
                    linkText: "Docs"
                )
            ]
        )
    }

    func testExternalLinkDestinationURLRequiresScheme() throws {
        XCTAssertEqual(
            ExternalLink(
                sourcePageID: "page",
                sourcePageTitle: "Page",
                sourceBlockID: "block",
                targetURL: "https://swift.org",
                linkText: "Swift"
            ).destinationURL?.absoluteString,
            "https://swift.org"
        )

        XCTAssertNil(
            ExternalLink(
                sourcePageID: "page",
                sourcePageTitle: "Page",
                sourceBlockID: "block",
                targetURL: "not-a-url",
                linkText: "Invalid"
            ).destinationURL
        )
    }

    func testExternalMarkdownLinksIgnoreImagesAndLocalTargets() throws {
        XCTAssertEqual(
            BacklinkRepository.externalMarkdownLinks(
                in: "![Logo](https://example.com/logo.png) [Guide](README.md) [Swift](https://swift.org)"
            ).map(\.url),
            ["https://swift.org"]
        )
    }

    private func migratedDatabase() throws -> SQLiteDatabase {
        let database = try SQLiteDatabase.open(path: makeTemporaryDirectory().appendingPathComponent("editor.sqlite").path)
        try SchemaMigrator.migrate(database: database)
        return database
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
