import Foundation
import XCTest

final class ObsidianVaultImporterTests: XCTestCase {
    private var temporaryURLs: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryURLs.removeAll()
        try super.tearDownWithError()
    }

    func testMarkdownDocumentParserSplitsFrontmatterTagsAndEncryptedEnvelope() throws {
        let document = ObsidianMarkdownDocument.parse(
            """
            ---
            tags:
              - 加密笔记
              - 复盘/周复盘
            创建时间: 2026-04-19 23:26
            aliases: [weekly, review]
            ---
            CRYPTO_NOTE_BODY_V1
            {
              "version": 1,
              "kdf": "PBKDF2-SHA-256",
              "cipher": "AES-GCM",
              "iterations": 210000,
              "salt": "salt",
              "iv": "iv",
              "ciphertext": "ciphertext",
              "updatedAt": "2026-04-27T14:12:26.141Z"
            }
            """
        )

        XCTAssertEqual(document.tags, ["加密笔记", "复盘/周复盘"])
        XCTAssertEqual(document.frontmatter?.fields["创建时间"], .scalar("2026-04-19 23:26"))
        XCTAssertEqual(document.frontmatter?.fields["aliases"], .list(["weekly", "review"]))
        XCTAssertTrue(document.isEncrypted)
        XCTAssertTrue(document.isSecretNote)
        XCTAssertEqual(document.encryptionEnvelope?.cipher, "AES-GCM")
        XCTAssertEqual(document.markdownForImport, "加密笔记，待解密支持。")
    }

    func testEncryptedDocumentDecryptsToPlainMarkdownAndNormalizesObsidianEmbeds() throws {
        let document = ObsidianMarkdownDocument.parse(
            """
            ---
            tags:
              - 加密笔记
            ---
            CRYPTO_NOTE_BODY_V1
            {
              "version": 1,
              "kdf": "PBKDF2-SHA-256",
              "cipher": "AES-GCM",
              "iterations": 5,
              "salt": "ABEiM0RVZneImaq7zN3u/w==",
              "iv": "AQIDBAUGBwgJCgsM",
              "ciphertext": "h3CAghYvbdtcO8TaFbLdlYzz2QXgHsbXgBaLM/UqmOb2imJhHYP5WzehrhXh3cBEPyWI7ua21/LHzVrkfNTvUjUtI2B7neywcLufrUPz+X+Y",
              "updatedAt": "2026-05-20T00:00:00.000Z"
            }
            """
        )

        XCTAssertEqual(
            document.markdownForImport,
            """
            Secret body
            文字 ![a.png](a.png) 文字
            [[Specs#^abc123]]
            """
        )
    }

    func testDiaryResolverMatchesObservedObsidianDateNamingVariants() {
        XCTAssertEqual(
            ObsidianDiaryDateResolver.match(relativePath: "日记/2025年/一月/3周/2025年1月15日 星期三.md"),
            ObsidianDiaryMatch(dateString: "2025-01-15", kind: "daily", pattern: "chinese-date")
        )
        XCTAssertEqual(
            ObsidianDiaryDateResolver.match(relativePath: "日记/2023年/四月/16周/2023-04-17 星期一.md"),
            ObsidianDiaryMatch(dateString: "2023-04-17", kind: "daily", pattern: "dash-date")
        )
        XCTAssertEqual(
            ObsidianDiaryDateResolver.match(relativePath: "未分类/2026.1.11 周复盘.md"),
            ObsidianDiaryMatch(dateString: nil, kind: "weeklyReview", pattern: "weekly-review")
        )
        XCTAssertEqual(
            ObsidianDiaryDateResolver.match(relativePath: "未分类/复盘- 2022.3.20.md"),
            ObsidianDiaryMatch(dateString: "2022-03-20", kind: "review", pattern: "dot-date")
        )
        XCTAssertEqual(
            ObsidianDiaryDateResolver.match(relativePath: "日记/2023年/十二月/52周/2023年 W52.md"),
            ObsidianDiaryMatch(dateString: nil, kind: "weekly", pattern: "year-week")
        )
    }

    func testVaultImporterImportsOnlyMarkdownAndStoresObsidianMetadata() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let encryptedNoteCipher = ObsidianImporterTestCipher()
        let repository = PageRepository(database: database, encryptedNoteCipher: encryptedNoteCipher)
        let initialSnapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = try XCTUnwrap(initialSnapshot.selectedWorkspaceID)
        let vaultURL = try makeTemporaryDirectory().appendingPathComponent("空", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        try write(
            """
            ---
            tags:
              - 日记
              - 复盘/周复盘
            创建时间: 2025-01-15 08:00
            custom-field: kept
            ---
            # Daily body
            """,
            to: vaultURL.appendingPathComponent("日记/2025年/一月/3周/2025年1月15日 星期三.md")
        )
        let attachmentsDirectory = try makeTemporaryDirectory()
        try writeData(Data([0x89, 0x50, 0x4E, 0x47]), to: vaultURL.appendingPathComponent("技术/语言/go/assets/photo.png"))
        try writeData(Data("override-pdf".utf8), to: vaultURL.appendingPathComponent("attachments/diagram.pdf"))
        try write(
            """
            ---
            tags: [技术/语言, go]
            aliases: []
            ---
            Go body
            ![diagram](assets/photo.png)
            文字 ![[inline.png]] 中间
            ![[Specs#^abc123|引用块]]
            Middle
            ![[diagram.pdf]]
            Tail
            """,
            to: vaultURL.appendingPathComponent("技术/语言/go/GO.md")
        )
        try write(
            """
            Target paragraph ^abc123
            """,
            to: vaultURL.appendingPathComponent("技术/语言/go/Specs.md")
        )
        try writeData(Data([0x89, 0x50, 0x4E, 0x47]), to: vaultURL.appendingPathComponent("技术/语言/go/inline.png"))
        try writeData(Data([0x89, 0x50, 0x4E, 0x47]), to: vaultURL.appendingPathComponent("未分类/a.png"))
        let encryptedNoteMarkdown = """
            ---
            tags:
              - 加密笔记
            修改时间: 2025-11-16 23:13
            ---
            CRYPTO_NOTE_BODY_V1
            {
              "version": 1,
              "kdf": "PBKDF2-SHA-256",
              "cipher": "AES-GCM",
              "iterations": 5,
              "salt": "ABEiM0RVZneImaq7zN3u/w==",
              "iv": "AQIDBAUGBwgJCgsM",
              "ciphertext": "h3CAghYvbdtcO8TaFbLdlYzz2QXgHsbXgBaLM/UqmOb2imJhHYP5WzehrhXh3cBEPyWI7ua21/LHzVrkfNTvUjUtI2B7neywcLufrUPz+X+Y",
              "updatedAt": "2026-05-20T00:00:00.000Z"
            }
            """
        XCTAssertEqual(
            ObsidianMarkdownDocument.parse(encryptedNoteMarkdown).markdownForImport,
            """
            Secret body
            文字 ![a.png](a.png) 文字
            [[Specs#^abc123]]
            """
        )
        try write(
            encryptedNoteMarkdown,
            to: vaultURL.appendingPathComponent("未分类/推特账号.md")
        )
        try write(
            """
            ---
            tags:
              - 复盘/周复盘
            ---
            Weekly body
            """,
            to: vaultURL.appendingPathComponent("未分类/2026.1.11 周复盘.md")
        )
        try write("ignored", to: vaultURL.appendingPathComponent(".obsidian/ignored.md"))
        try write("binary", to: vaultURL.appendingPathComponent("未分类/assets/photo.png"))

        let summary = try ObsidianVaultImporter(
            database: database,
            attachmentsDirectory: attachmentsDirectory,
            encryptedNoteCipher: encryptedNoteCipher
        ).importVault(
            vaultURL: vaultURL,
            workspaceID: workspaceID
        )
        let snapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(summary.markdownFileCount, 5)
        XCTAssertEqual(summary.importedPageCount, 5)
        XCTAssertEqual(summary.encryptedPageCount, 1)
        XCTAssertEqual(summary.diaryPageCount, 1)
        XCTAssertEqual(summary.ignoredNonMarkdownFileCount, 5)
        XCTAssertEqual(summary.importedAttachmentCount, 4)
        XCTAssertEqual(summary.diaryPatterns["chinese-date"], 1)
        XCTAssertEqual(summary.diaryPatterns["weekly-review"], 1)
        XCTAssertTrue(snapshot.pages.contains { $0.title == "2025年1月15日 星期三" })
        XCTAssertTrue(snapshot.pages.contains { $0.title == "GO" })
        XCTAssertTrue(snapshot.pages.contains { $0.title == "Specs" })
        XCTAssertTrue(snapshot.pages.contains { $0.title == "2026.1.11 周复盘" })
        XCTAssertTrue(snapshot.pages.contains { $0.title == "推特账号" })
        XCTAssertEqual(snapshot.pages.first { $0.title == "推特账号" }?.isEncrypted, true)
        XCTAssertFalse(snapshot.pages.contains { $0.title == "ignored" })
        XCTAssertTrue(snapshot.notebooks.contains { $0.name == "空" })
        XCTAssertTrue(snapshot.notebooks.contains { $0.name == "日记" })
        XCTAssertTrue(snapshot.notebooks.contains { $0.name == "go" })
        XCTAssertTrue(snapshot.tags.contains { $0.path == "复盘/周复盘" })
        XCTAssertTrue(snapshot.tags.contains { $0.path == "技术/语言" })
        XCTAssertTrue(snapshot.tags.contains { $0.path == "秘闻笔记" })

        let diaryRows = try database.query(
            """
            SELECT diary_date
            FROM diary_pages
            ORDER BY diary_date ASC
            """
        )
        XCTAssertEqual(diaryRows.map { $0["diary_date"] ?? "" }, ["2025-01-15"])

        let metadataRows = try database.query(
            """
            SELECT source_path,
                   frontmatter_json,
                   custom_metadata_json,
                   is_encrypted,
                   encryption_scheme,
                   encryption_password_hint,
                   diary_date
            FROM page_import_metadata
            ORDER BY source_path ASC
            """
        )
        XCTAssertEqual(metadataRows.count, 5)
        let encryptedRow = try XCTUnwrap(metadataRows.first { $0["source_path"] == "未分类/推特账号.md" })
        XCTAssertEqual(encryptedRow["is_encrypted"], "1")
        XCTAssertEqual(encryptedRow["encryption_scheme"], "AES-GCM")
        XCTAssertEqual(encryptedRow["encryption_password_hint"], "jueduino2")
        XCTAssertTrue((encryptedRow["custom_metadata_json"] ?? "").contains("CRYPTO_NOTE_BODY_V1"))
        XCTAssertTrue((encryptedRow["custom_metadata_json"] ?? "").contains("\"secret_note\":true"))
        XCTAssertTrue((encryptedRow["custom_metadata_json"] ?? "").contains("\"stored_plaintext\":false"))
        let diaryRow = try XCTUnwrap(metadataRows.first { $0["source_path"] == "日记/2025年/一月/3周/2025年1月15日 星期三.md" })
        XCTAssertEqual(diaryRow["diary_date"], "2025-01-15")
        XCTAssertTrue((diaryRow["frontmatter_json"] ?? "").contains("custom-field"))

        let attachmentRows = try database.query(
            """
            SELECT original_filename
            FROM attachments
            ORDER BY original_filename ASC
            """
        )
        XCTAssertEqual(attachmentRows.map { $0["original_filename"] ?? "" }, ["a.png", "diagram.pdf", "inline.png", "photo.png"])

        let goPageID = try XCTUnwrap(snapshot.pages.first { $0.title == "GO" }?.id)
        let specsPageID = try XCTUnwrap(snapshot.pages.first { $0.title == "Specs" }?.id)
        let goBlockRows = try database.query(
            """
            SELECT id,
                   type,
                   text_plain,
                   payload_json
            FROM blocks
            WHERE page_id = ?
              AND is_deleted = 0
            ORDER BY order_key ASC
            """,
            bindings: [.text(goPageID)]
        )
        XCTAssertEqual(
            goBlockRows.map { row in "\(row["type"] ?? ""):\(row["text_plain"] ?? "")" },
            [
                "paragraph:Go body",
                "attachmentImage:photo.png",
                "paragraph:文字",
                "attachmentImage:inline.png",
                "paragraph:中间",
                "blockReference:Specs#^abc123",
                "paragraph:Middle",
                "attachmentFile:diagram.pdf",
                "paragraph:Tail"
            ]
        )
        let blockReferenceRow = try XCTUnwrap(goBlockRows.first { $0["type"] == "blockReference" })
        let specsTargetBlock = try XCTUnwrap(
            try database.query(
                """
                SELECT id
                FROM blocks
                WHERE page_id = ?
                  AND text_plain = ?
                  AND is_deleted = 0
                LIMIT 1
                """,
                bindings: [.text(specsPageID), .text("Target paragraph ^abc123")]
            ).first
        )
        XCTAssertTrue((blockReferenceRow["payload_json"] ?? "").contains(specsTargetBlock["id"] ?? "missing"))

        let encryptedPageID = try XCTUnwrap(snapshot.pages.first { $0.title == "推特账号" }?.id)
        let encryptedSnapshotBlocks = snapshot.blocks.filter { $0.pageID == encryptedPageID }
        XCTAssertEqual(
            encryptedSnapshotBlocks.map { "\($0.type.rawValue):\($0.textPlain)" },
            [
                "paragraph:Secret body",
                "paragraph:文字",
                "attachmentImage:a.png",
                "paragraph:文字",
                "blockReference:Specs#^abc123"
            ]
        )
        XCTAssertEqual(
            encryptedSnapshotBlocks.first { $0.type == .blockReference }?.blockReferenceTargetBlockID,
            specsTargetBlock["id"] ?? "missing"
        )

        let encryptedRawPage = try XCTUnwrap(
            try database.query(
                """
                SELECT title,
                       is_encrypted
                FROM pages
                WHERE id = ?
                LIMIT 1
                """,
                bindings: [.text(encryptedPageID)]
            ).first
        )
        XCTAssertEqual(encryptedRawPage["is_encrypted"], "1")
        XCTAssertTrue(encryptedRawPage["title"]?.hasPrefix(EncryptedNoteCipher.ciphertextPrefix) == true)
        XCTAssertNotEqual(encryptedRawPage["title"], "推特账号")

        let encryptedRawBlockRows = try database.query(
            """
            SELECT type,
                   text_plain,
                   payload_json
            FROM blocks
            WHERE page_id = ?
              AND is_deleted = 0
            ORDER BY order_key ASC
            """,
            bindings: [.text(encryptedPageID)]
        )
        XCTAssertEqual(encryptedRawBlockRows.count, 5)
        XCTAssertTrue(encryptedRawBlockRows.allSatisfy { row in
            row["text_plain"]?.hasPrefix(EncryptedNoteCipher.ciphertextPrefix) == true
                && row["payload_json"]?.hasPrefix(EncryptedNoteCipher.ciphertextPrefix) == true
        })
        XCTAssertFalse(encryptedRawBlockRows.contains { $0["text_plain"] == "Secret body" })
    }

    func testConfiguredVaultPathCanBeOverridden() throws {
        let database = try migratedDatabase()
        defer { database.close() }

        let repository = PageRepository(database: database)
        let workspaceID = try XCTUnwrap(try repository.bootstrapWorkspaceIfNeeded().selectedWorkspaceID)
        let attachmentsDirectory = try makeTemporaryDirectory()
        let configuredVaultURL = try makeTemporaryDirectory().appendingPathComponent("ConfiguredVault", isDirectory: true)
        let overrideVaultURL = try makeTemporaryDirectory().appendingPathComponent("OverrideVault", isDirectory: true)
        try write("configured", to: configuredVaultURL.appendingPathComponent("Configured.md"))
        try write("override", to: overrideVaultURL.appendingPathComponent("Override.md"))

        var configuration = ObsidianVaultImportConfiguration()
        configuration.defaultVaultURL = configuredVaultURL
        let importer = ObsidianVaultImporter(
            database: database,
            attachmentsDirectory: attachmentsDirectory,
            configuration: configuration
        )

        let configuredSummary = try importer.importConfiguredVault(workspaceID: workspaceID)
        let overrideSummary = try importer.importConfiguredVault(
            workspaceID: workspaceID,
            vaultURL: overrideVaultURL
        )
        let snapshot = try repository.loadWorkspaceSnapshot()

        XCTAssertEqual(configuredSummary.importedPageCount, 1)
        XCTAssertEqual(overrideSummary.importedPageCount, 1)
        XCTAssertTrue(snapshot.pages.contains { $0.title == "Configured" })
        XCTAssertTrue(snapshot.pages.contains { $0.title == "Override" })
    }

    private func migratedDatabase() throws -> SQLiteDatabase {
        let database = try SQLiteDatabase.open(path: temporaryDatabasePath())
        try SchemaMigrator.migrate(database: database)
        return database
    }

    private func temporaryDatabasePath() -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("editor-obsidian-importer-\(UUID().uuidString).sqlite")
        temporaryURLs.append(url)
        return url.path
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("editor-obsidian-importer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryURLs.append(url)
        return url
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeData(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
    }
}

private struct ObsidianImporterTestCipher: EncryptedNoteCiphering {
    func encrypt(_ plaintext: String) throws -> String {
        guard !isCiphertext(plaintext) else {
            return plaintext
        }
        return EncryptedNoteCipher.ciphertextPrefix + Data(plaintext.utf8).base64EncodedString()
    }

    func decrypt(_ storedValue: String) throws -> String {
        guard isCiphertext(storedValue) else {
            return storedValue
        }
        let encoded = String(storedValue.dropFirst(EncryptedNoteCipher.ciphertextPrefix.count))
        guard let data = Data(base64Encoded: encoded),
              let plaintext = String(data: data, encoding: .utf8) else {
            throw ObsidianImporterTestCipherError.invalidCiphertext
        }
        return plaintext
    }

    func isCiphertext(_ storedValue: String) -> Bool {
        storedValue.hasPrefix(EncryptedNoteCipher.ciphertextPrefix)
    }
}

private enum ObsidianImporterTestCipherError: Error {
    case invalidCiphertext
}
