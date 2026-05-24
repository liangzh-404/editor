import CryptoKit
import Foundation

struct ObsidianVaultImportConfiguration: Equatable, Sendable {
    static let defaultObsidianVaultURL = URL(
        fileURLWithPath: "/Users/liangzhang/Library/Mobile Documents/iCloud~md~obsidian/Documents/空",
        isDirectory: true
    )

    var sourceType = "obsidian"
    var defaultVaultURL: URL? = Self.defaultObsidianVaultURL
    var encryptedNoteDefaultPassword = "jueduino2"
    var encryptedNotePlaceholder = "加密笔记，待解密支持。"
    var secretNoteTagName = "秘闻笔记"
    var skipsPreviouslyImportedSources = true
    var importsReferencedAttachments = true
    var attachmentSearchDirectories: [URL] = []
}

struct ObsidianVaultImportSummary: Equatable, Sendable {
    var markdownFileCount = 0
    var importedPageCount = 0
    var skippedPageCount = 0
    var encryptedPageCount = 0
    var diaryPageCount = 0
    var importedAttachmentCount = 0
    var ignoredNonMarkdownFileCount = 0
    var diaryPatterns: [String: Int] = [:]
}

protocol ObsidianVaultImporting {
    func importVault(vaultURL: URL, workspaceID: String) throws -> ObsidianVaultImportSummary
}

struct ObsidianFrontmatter: Equatable, Sendable {
    let raw: String
    let fields: [String: ObsidianFrontmatterValue]
}

enum ObsidianFrontmatterValue: Equatable, Sendable {
    case scalar(String)
    case list([String])

    var stringValue: String? {
        switch self {
        case .scalar(let value):
            return value
        case .list:
            return nil
        }
    }

    var listValue: [String] {
        switch self {
        case .scalar(let value):
            return value.isEmpty ? [] : [value]
        case .list(let values):
            return values
        }
    }

    var jsonValue: Any {
        switch self {
        case .scalar(let value):
            return value
        case .list(let values):
            return values
        }
    }
}

struct ObsidianEncryptedEnvelope: Equatable, Sendable, Decodable {
    let version: Int
    let kdf: String
    let cipher: String
    let iterations: Int
    let salt: String
    let iv: String
    let ciphertext: String
    let updatedAt: String
}

struct ObsidianMarkdownDocument: Equatable, Sendable {
    static let encryptedBodyMarker = "CRYPTO_NOTE_BODY_V1"
    private static let attachmentEmbedExtensions: Set<String> = [
        "7z", "aiff", "avi", "avif", "bin", "bmp", "csv", "doc", "docx", "excalidraw",
        "flac", "gif", "heic", "heif", "jpeg", "jpg", "json", "m4a", "m4v", "mkv",
        "mov", "mp3", "mp4", "ogg", "pdf", "png", "ppt", "pptx", "rar", "rtf",
        "svg", "tif", "tiff", "tsv", "txt", "wav", "webm", "webp", "xls", "xlsx",
        "xml", "yaml", "yml", "zip"
    ]

    let frontmatter: ObsidianFrontmatter?
    let bodyMarkdown: String
    let tags: [String]
    let isEncrypted: Bool
    let isSecretNote: Bool
    let encryptionEnvelope: ObsidianEncryptedEnvelope?
    let encryptionEnvelopeJSON: String?
    let decryptedBodyMarkdown: String?
    let markdownForImport: String

    static func parse(
        _ markdown: String,
        configuration: ObsidianVaultImportConfiguration = ObsidianVaultImportConfiguration()
    ) -> ObsidianMarkdownDocument {
        let split = splitFrontmatter(markdown)
        let frontmatter = split.rawFrontmatter.map { raw in
            ObsidianFrontmatter(
                raw: raw,
                fields: ObsidianFrontmatterParser.parseFields(raw)
            )
        }
        let parsedTags = frontmatter.map { tags(from: $0.fields) } ?? []
        let encryptedPayload = encryptedPayload(from: split.body)
        let isEncrypted = encryptedPayload != nil || parsedTags.contains("加密笔记")
        let envelope: ObsidianEncryptedEnvelope?
        let envelopeJSON: String?
        if let encryptedPayload {
            envelopeJSON = encryptedPayload
            envelope = try? JSONDecoder().decode(
                ObsidianEncryptedEnvelope.self,
                from: Data(encryptedPayload.utf8)
            )
        } else {
            envelopeJSON = nil
            envelope = nil
        }
        let decryptedBodyMarkdown = envelope.flatMap {
            try? ObsidianEncryptedNoteDecryptor.decrypt(
                envelope: $0,
                password: configuration.encryptedNoteDefaultPassword
            )
        }

        let markdownForImport = if let decryptedBodyMarkdown {
            normalizeObsidianEmbeds(in: decryptedBodyMarkdown)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if encryptedPayload == nil {
            normalizeObsidianEmbeds(in: split.body)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            configuration.encryptedNotePlaceholder
        }

        return ObsidianMarkdownDocument(
            frontmatter: frontmatter,
            bodyMarkdown: split.body,
            tags: parsedTags,
            isEncrypted: isEncrypted,
            isSecretNote: isEncrypted,
            encryptionEnvelope: envelope,
            encryptionEnvelopeJSON: envelopeJSON,
            decryptedBodyMarkdown: decryptedBodyMarkdown,
            markdownForImport: markdownForImport
        )
    }

    private static func splitFrontmatter(_ markdown: String) -> (rawFrontmatter: String?, body: String) {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return (nil, normalized)
        }

        guard let closingIndex = lines.dropFirst().firstIndex(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines) == "---"
        }) else {
            return (nil, normalized)
        }

        let frontmatter = lines[1..<closingIndex].joined(separator: "\n")
        let bodyStartIndex = lines.index(after: closingIndex)
        let body = bodyStartIndex < lines.endIndex
            ? lines[bodyStartIndex...].joined(separator: "\n")
            : ""
        return (frontmatter, body)
    }

    private static func tags(from fields: [String: ObsidianFrontmatterValue]) -> [String] {
        guard let tagValue = fields["tags"] else {
            return []
        }

        var seen: Set<String> = []
        var result: [String] = []
        for rawTag in tagValue.listValue {
            let tag = rawTag
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            guard !tag.isEmpty, !seen.contains(tag) else {
                continue
            }
            seen.insert(tag)
            result.append(tag)
        }
        return result
    }

    private static func encryptedPayload(from body: String) -> String? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(encryptedBodyMarker),
              let jsonStart = trimmed.firstIndex(of: "{") else {
            return nil
        }

        return String(trimmed[jsonStart...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeObsidianEmbeds(in markdown: String) -> String {
        markdown
            .components(separatedBy: .newlines)
            .map(normalizedObsidianEmbedsLine)
            .joined(separator: "\n")
    }

    private static func normalizedObsidianEmbedsLine(_ line: String) -> String {
        let prefix = "![["
        let suffix = "]]"
        var result = ""
        var remaining = line[...]

        while let start = remaining.range(of: prefix) {
            result += remaining[..<start.lowerBound]
            let afterStart = remaining[start.upperBound...]
            guard let end = afterStart.range(of: suffix) else {
                result += remaining[start.lowerBound...]
                return result
            }

            let rawTarget = String(afterStart[..<end.lowerBound])
            result += normalizedObsidianEmbed(rawTarget)
            remaining = afterStart[end.upperBound...]
        }

        result += remaining
        return result
    }

    private static func normalizedObsidianEmbed(_ rawTarget: String) -> String {
        let target = rawTarget
            .split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !target.isEmpty else {
            return "![[]]"
        }

        if isAttachmentEmbedTarget(target) {
            let label = (target.removingPercentEncoding ?? target)
                .split(separator: "/")
                .last
                .map(String.init) ?? target
            return "![\(label)](\(target))"
        }

        return "[[\(target)]]"
    }

    private static func isAttachmentEmbedTarget(_ target: String) -> Bool {
        let path = target
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? target
        let pathExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
        return attachmentEmbedExtensions.contains(pathExtension)
    }
}

enum ObsidianEncryptedNoteDecryptor {
    enum DecryptionError: Error {
        case unsupportedEnvelope
        case invalidBase64
        case invalidCiphertext
        case invalidPlaintext
    }

    static func decrypt(
        envelope: ObsidianEncryptedEnvelope,
        password: String
    ) throws -> String {
        guard envelope.kdf == "PBKDF2-SHA-256",
              envelope.cipher == "AES-GCM",
              envelope.iterations > 0 else {
            throw DecryptionError.unsupportedEnvelope
        }
        guard let salt = Data(base64Encoded: envelope.salt),
              let iv = Data(base64Encoded: envelope.iv),
              let ciphertextAndTag = Data(base64Encoded: envelope.ciphertext) else {
            throw DecryptionError.invalidBase64
        }
        guard ciphertextAndTag.count > 16 else {
            throw DecryptionError.invalidCiphertext
        }

        let ciphertext = ciphertextAndTag.prefix(ciphertextAndTag.count - 16)
        let tag = ciphertextAndTag.suffix(16)
        let key = pbkdf2SHA256(
            password: Data(password.utf8),
            salt: salt,
            iterations: envelope.iterations,
            keyByteCount: 32
        )
        let sealedBox = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: iv),
            ciphertext: ciphertext,
            tag: tag
        )
        let plaintext = try AES.GCM.open(sealedBox, using: key)
        guard let markdown = String(data: plaintext, encoding: .utf8) else {
            throw DecryptionError.invalidPlaintext
        }
        return markdown
    }

    private static func pbkdf2SHA256(
        password: Data,
        salt: Data,
        iterations: Int,
        keyByteCount: Int
    ) -> SymmetricKey {
        let passwordKey = SymmetricKey(data: password)
        let blockCount = Int(ceil(Double(keyByteCount) / Double(SHA256.byteCount)))
        var derivedBytes: [UInt8] = []

        for blockIndex in 1...blockCount {
            var saltAndIndex = Data(salt)
            var bigEndianBlockIndex = UInt32(blockIndex).bigEndian
            withUnsafeBytes(of: &bigEndianBlockIndex) { bytes in
                saltAndIndex.append(contentsOf: bytes)
            }

            var previous = Array(HMAC<SHA256>.authenticationCode(for: saltAndIndex, using: passwordKey))
            var accumulated = previous
            if iterations > 1 {
                for _ in 1..<iterations {
                    previous = Array(HMAC<SHA256>.authenticationCode(for: Data(previous), using: passwordKey))
                    for byteIndex in accumulated.indices {
                        accumulated[byteIndex] ^= previous[byteIndex]
                    }
                }
            }
            derivedBytes.append(contentsOf: accumulated)
        }

        return SymmetricKey(data: Data(derivedBytes.prefix(keyByteCount)))
    }
}

enum ObsidianFrontmatterParser {
    static func parseFields(_ rawFrontmatter: String) -> [String: ObsidianFrontmatterValue] {
        let lines = rawFrontmatter.components(separatedBy: .newlines)
        var fields: [String: ObsidianFrontmatterValue] = [:]
        var index = 0

        while index < lines.count {
            let line = lines[index]
            defer { index += 1 }

            guard !line.hasPrefix(" "), !line.hasPrefix("\t"),
                  let separator = line.firstIndex(of: ":") else {
                continue
            }

            let key = String(line[..<separator])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                continue
            }

            let rawValue = String(line[line.index(after: separator)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let value: ObsidianFrontmatterValue
            if rawValue.isEmpty {
                let list = followingListValues(lines: lines, startIndex: index + 1)
                value = .list(list)
            } else if rawValue.hasPrefix("[") && rawValue.hasSuffix("]") {
                value = .list(inlineListValues(rawValue))
            } else {
                value = .scalar(unquoted(rawValue))
            }
            fields[key] = merged(existing: fields[key], next: value)
        }

        return fields
    }

    private static func followingListValues(lines: [String], startIndex: Int) -> [String] {
        var values: [String] = []
        var index = startIndex
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("- ") else {
                break
            }
            values.append(unquoted(String(trimmed.dropFirst(2))))
            index += 1
        }
        return values
    }

    private static func inlineListValues(_ rawValue: String) -> [String] {
        let start = rawValue.index(after: rawValue.startIndex)
        let end = rawValue.index(before: rawValue.endIndex)
        let content = rawValue[start..<end]
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return content
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { unquoted(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.isEmpty }
    }

    private static func unquoted(_ value: String) -> String {
        guard value.count >= 2 else {
            return value
        }
        if (value.hasPrefix("\"") && value.hasSuffix("\""))
            || (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    private static func merged(
        existing: ObsidianFrontmatterValue?,
        next: ObsidianFrontmatterValue
    ) -> ObsidianFrontmatterValue {
        guard let existing else {
            return next
        }
        return .list(existing.listValue + next.listValue)
    }
}

struct ObsidianDiaryMatch: Equatable, Sendable {
    let dateString: String?
    let kind: String
    let pattern: String
}

struct ObsidianSourceTimestamps: Equatable, Sendable {
    let createdAt: String?
    let modifiedAt: String?
}

enum ObsidianDiaryDateResolver {
    static func match(relativePath: String) -> ObsidianDiaryMatch? {
        let components = relativePath.split(separator: "/").map(String.init)
        let filename = components.last.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent } ?? relativePath
        let isDiaryPath = components.first == "日记"

        if isDiaryPath,
           firstMatch(in: filename, pattern: #"(20\d{2})年\s*W\d{1,2}"#) != nil {
            return ObsidianDiaryMatch(dateString: nil, kind: "weekly", pattern: "year-week")
        }

        if filename.contains("周复盘") {
            return ObsidianDiaryMatch(dateString: nil, kind: "weeklyReview", pattern: "weekly-review")
        }

        if let match = firstDateMatch(in: filename) {
            return ObsidianDiaryMatch(
                dateString: match.dateString,
                kind: kind(filename: filename, isDiaryPath: isDiaryPath),
                pattern: match.pattern
            )
        }

        if let inferredYear = inferredYear(from: components),
           let match = firstMonthDayMatch(in: filename, year: inferredYear) {
            return ObsidianDiaryMatch(
                dateString: match.dateString,
                kind: kind(filename: filename, isDiaryPath: isDiaryPath),
                pattern: match.pattern
            )
        }

        if filename.range(of: #"\d{1,2}\s*月\s*\d{1,2}\s*日"#, options: .regularExpression) != nil {
            return ObsidianDiaryMatch(
                dateString: nil,
                kind: kind(filename: filename, isDiaryPath: isDiaryPath),
                pattern: "month-day-no-year"
            )
        }

        return nil
    }

    private static func firstDateMatch(in text: String) -> (dateString: String, pattern: String)? {
        let patterns: [(String, String)] = [
            (#"(20\d{2})年\s*(\d{1,2})月\s*(\d{1,2})日"#, "chinese-date"),
            (#"(20\d{2})-(\d{1,2})-(\d{1,2})"#, "dash-date"),
            (#"(20\d{2})\.(\d{1,2})\.(\d{1,2})"#, "dot-date")
        ]
        for (pattern, name) in patterns {
            guard let match = firstMatch(in: text, pattern: pattern),
                  match.count == 3,
                  let year = Int(match[0]),
                  let month = Int(match[1]),
                  let day = Int(match[2]) else {
                continue
            }
            return (dateString(year: year, month: month, day: day), name)
        }
        return nil
    }

    private static func firstMonthDayMatch(in text: String, year: Int) -> (dateString: String, pattern: String)? {
        guard let match = firstMatch(in: text, pattern: #"(\d{1,2})\s*月\s*(\d{1,2})\s*日"#),
              match.count == 2,
              let month = Int(match[0]),
              let day = Int(match[1]) else {
            return nil
        }
        return (dateString(year: year, month: month, day: day), "month-day")
    }

    private static func inferredYear(from components: [String]) -> Int? {
        for component in components {
            guard let match = firstMatch(in: component, pattern: #"(20\d{2})年"#),
                  let rawYear = match.first,
                  let year = Int(rawYear) else {
                continue
            }
            return year
        }
        return nil
    }

    private static func kind(filename: String, isDiaryPath: Bool) -> String {
        if filename.contains("周复盘") {
            return "weeklyReview"
        }
        if filename.contains("复盘") {
            return "review"
        }
        if filename.contains("观察") {
            return "observation"
        }
        if isDiaryPath || filename.contains("日记") || filename.contains("每日") {
            return "daily"
        }
        return "datedNote"
    }

    private static func firstMatch(in text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }
        var captures: [String] = []
        for index in 1..<match.numberOfRanges {
            let captureRange = match.range(at: index)
            guard captureRange.location != NSNotFound,
                  let range = Range(captureRange, in: text) else {
                continue
            }
            captures.append(String(text[range]))
        }
        return captures
    }

    private static func dateString(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}

final class ObsidianVaultImporter: ObsidianVaultImporting {
    private let database: SQLiteDatabase
    private let pageRepository: PageRepository
    private let tagRepository: TagRepository
    private let attachmentRepository: AttachmentRepository?
    private let fileManager: FileManager
    private let configuration: ObsidianVaultImportConfiguration

    init(
        database: SQLiteDatabase,
        attachmentsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        configuration: ObsidianVaultImportConfiguration = ObsidianVaultImportConfiguration(),
        encryptedNoteCipher: EncryptedNoteCiphering = EncryptedNoteCipher()
    ) {
        self.database = database
        self.pageRepository = PageRepository(database: database, encryptedNoteCipher: encryptedNoteCipher)
        self.tagRepository = TagRepository(database: database)
        self.attachmentRepository = attachmentsDirectory.map {
            AttachmentRepository(
                database: database,
                attachmentsDirectory: $0,
                fileManager: fileManager,
                encryptedNoteCipher: encryptedNoteCipher
            )
        }
        self.fileManager = fileManager
        self.configuration = configuration
    }

    func importConfiguredVault(
        workspaceID: String,
        vaultURL overrideVaultURL: URL? = nil
    ) throws -> ObsidianVaultImportSummary {
        guard let vaultURL = overrideVaultURL ?? configuration.defaultVaultURL else {
            throw ObsidianVaultImporterError.defaultVaultURLMissing
        }
        return try importVault(vaultURL: vaultURL, workspaceID: workspaceID)
    }

    func importVault(vaultURL: URL, workspaceID: String) throws -> ObsidianVaultImportSummary {
        let attachmentIndex = try makeAttachmentIndex(vaultURL: vaultURL)

        return try database.withImmediateTransaction("obsidian_vault_import") {
            var summary = ObsidianVaultImportSummary()
            let rootNotebookID = try ensureNotebookPath(
                workspaceID: workspaceID,
                components: [vaultURL.lastPathComponent]
            )

            guard let enumerator = fileManager.enumerator(
                at: vaultURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .creationDateKey, .contentModificationDateKey],
                options: [.skipsPackageDescendants]
            ) else {
                throw ObsidianVaultImporterError.unreadableVault(vaultURL.path)
            }

            while let item = enumerator.nextObject() as? URL {
                let relativePath = try self.relativePath(for: item, vaultURL: vaultURL)
                let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
                if values.isDirectory == true {
                    if isHidden(relativePath: relativePath) {
                        enumerator.skipDescendants()
                    }
                    continue
                }
                guard values.isRegularFile == true,
                      !isHidden(relativePath: relativePath) else {
                    continue
                }
                guard item.pathExtension.lowercased() == "md" else {
                    summary.ignoredNonMarkdownFileCount += 1
                    continue
                }
                guard Self.shouldImportMarkdownFile(relativePath: relativePath) else {
                    summary.ignoredNonMarkdownFileCount += 1
                    continue
                }

                summary.markdownFileCount += 1
                if configuration.skipsPreviouslyImportedSources,
                   try importedPageID(sourcePath: relativePath) != nil {
                    summary.skippedPageCount += 1
                    continue
                }

                let notebookID = try ensureNotebookPath(
                    workspaceID: workspaceID,
                    components: [vaultURL.lastPathComponent] + directoryComponents(relativePath: relativePath),
                    fallbackNotebookID: rootNotebookID
                )
                let importResult = try importMarkdownFile(
                    item,
                    relativePath: relativePath,
                    vaultURL: vaultURL,
                    workspaceID: workspaceID,
                    notebookID: notebookID,
                    attachmentIndex: attachmentIndex
                )
                summary.importedPageCount += 1
                summary.importedAttachmentCount += importResult.importedAttachmentCount
                if importResult.isEncrypted {
                    summary.encryptedPageCount += 1
                }
                if let diaryMatch = importResult.diaryMatch {
                    summary.diaryPatterns[diaryMatch.pattern, default: 0] += 1
                    if diaryMatch.dateString != nil {
                        summary.diaryPageCount += 1
                    }
                }
            }

            try pageRepository.relinkObsidianBlockReferenceBlocks()
            try SearchRepository(database: database).rebuildIndex()
            EditorLog.store.debug(
                "obsidian_vault_imported markdown_files=\(summary.markdownFileCount, privacy: .public) imported=\(summary.importedPageCount, privacy: .public) encrypted=\(summary.encryptedPageCount, privacy: .public) diary=\(summary.diaryPageCount, privacy: .public)"
            )
            return summary
        }
    }

    private func importMarkdownFile(
        _ markdownURL: URL,
        relativePath: String,
        vaultURL: URL,
        workspaceID: String,
        notebookID: String,
        attachmentIndex: [String: URL]
    ) throws -> (isEncrypted: Bool, diaryMatch: ObsidianDiaryMatch?, importedAttachmentCount: Int) {
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        let document = ObsidianMarkdownDocument.parse(markdown, configuration: configuration)
        let diaryMatch = ObsidianDiaryDateResolver.match(relativePath: relativePath)
        let sourceTimestamps = try sourceTimestamps(markdownURL: markdownURL, document: document)
        let title = Self.importedPageTitle(markdownURL: markdownURL, diaryMatch: diaryMatch)
        let page = try pageRepository.createPage(
            workspaceID: workspaceID,
            title: title,
            notebookID: notebookID,
            isEncrypted: document.isSecretNote,
            createdAt: sourceTimestamps.createdAt,
            updatedAt: sourceTimestamps.modifiedAt ?? sourceTimestamps.createdAt
        )
        var importedAttachmentCount = 0
        try pageRepository.importMarkdown(pageID: page.id, markdown: document.markdownForImport) { [attachmentRepository, configuration] draft in
            guard configuration.importsReferencedAttachments,
                  let attachmentRepository,
                  let attachmentRelativePath = draft.attachmentRelativePath,
                  let sourceURL = Self.attachmentSourceURL(
                    attachmentRelativePath: attachmentRelativePath,
                    markdownURL: markdownURL,
                    vaultURL: vaultURL,
                    attachmentIndex: attachmentIndex,
                    configuration: configuration
                  ) else {
                return nil
            }

            let result = try attachmentRepository.importAttachment(
                sourceURL: sourceURL,
                workspaceID: workspaceID,
                pageID: page.id,
                thumbnailPolicy: .deferred
            )
            importedAttachmentCount += 1
            return result
        }
        try pageRepository.applyImportedPageTimestamps(
            pageID: page.id,
            createdAt: sourceTimestamps.createdAt,
            updatedAt: sourceTimestamps.modifiedAt ?? sourceTimestamps.createdAt
        )

        let tagNames = tagNames(for: document)
        let tagIDs = try tagNames.map { tagName in
            try ensureTagPath(workspaceID: workspaceID, tagPath: tagName)
        }
        if !tagIDs.isEmpty {
            try tagRepository.assignTags(pageID: page.id, tagIDs: tagIDs)
        }

        if let diaryDate = diaryMatch?.dateString {
            let now = Self.timestamp()
            try database.execute(
                """
                INSERT OR IGNORE INTO diary_pages (page_id, workspace_id, diary_date, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(page.id),
                    .text(workspaceID),
                    .text(diaryDate),
                    .text(now),
                    .text(now)
                ]
            )
            let insertedRows = try database.query(
                "SELECT page_id FROM diary_pages WHERE page_id = ? LIMIT 1",
                bindings: [.text(page.id)]
            )
            if !insertedRows.isEmpty {
                try SyncRepository(database: database).enqueue(
                    entityType: "diaryPage",
                    entityID: page.id,
                    changeType: "create"
                )
            }
        }

        try insertImportMetadata(
            pageID: page.id,
            markdownURL: markdownURL,
            relativePath: relativePath,
            document: document,
            diaryMatch: diaryMatch,
            sourceTimestamps: sourceTimestamps
        )

        return (document.isEncrypted, diaryMatch, importedAttachmentCount)
    }

    private func tagNames(for document: ObsidianMarkdownDocument) -> [String] {
        var seen: Set<String> = []
        var tags = document.tags
        if document.isSecretNote {
            tags.append(configuration.secretNoteTagName)
        }
        return tags.compactMap { rawTag in
            let tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tag.isEmpty, !seen.contains(tag) else {
                return nil
            }
            seen.insert(tag)
            return tag
        }
    }

    private func insertImportMetadata(
        pageID: String,
        markdownURL: URL,
        relativePath: String,
        document: ObsidianMarkdownDocument,
        diaryMatch: ObsidianDiaryMatch?,
        sourceTimestamps: ObsidianSourceTimestamps
    ) throws {
        let now = Self.timestamp()
        let frontmatterFields = document.frontmatter?.fields ?? [:]
        let frontmatterJSON = try jsonString(
            Dictionary(uniqueKeysWithValues: frontmatterFields.map { key, value in
                (key, value.jsonValue)
            })
        )
        let customMetadataJSON = try jsonString(
            customMetadata(
                relativePath: relativePath,
                document: document,
                diaryMatch: diaryMatch
            )
        )
        try database.execute(
            """
            INSERT OR REPLACE INTO page_import_metadata (
                page_id,
                source_type,
                source_path,
                source_file_name,
                source_created_at,
                source_modified_at,
                frontmatter_json,
                custom_metadata_json,
                is_encrypted,
                encryption_scheme,
                encryption_password_hint,
                encryption_envelope_json,
                diary_date,
                diary_kind,
                diary_pattern,
                imported_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(pageID),
                .text(configuration.sourceType),
                .text(relativePath),
                .text(markdownURL.lastPathComponent),
                sourceTimestamps.createdAt.map(SQLiteValue.text) ?? .null,
                sourceTimestamps.modifiedAt.map(SQLiteValue.text) ?? .null,
                .text(frontmatterJSON),
                .text(customMetadataJSON),
                .integer(document.isEncrypted ? 1 : 0),
                document.encryptionEnvelope.map { .text($0.cipher) } ?? .null,
                document.isEncrypted ? .text(configuration.encryptedNoteDefaultPassword) : .null,
                document.encryptionEnvelopeJSON.map(SQLiteValue.text) ?? .null,
                diaryMatch?.dateString.map(SQLiteValue.text) ?? .null,
                diaryMatch.map { .text($0.kind) } ?? .null,
                diaryMatch.map { .text($0.pattern) } ?? .null,
                .text(now),
                .text(now)
            ]
        )
    }

    private func customMetadata(
        relativePath: String,
        document: ObsidianMarkdownDocument,
        diaryMatch: ObsidianDiaryMatch?
    ) -> [String: Any] {
        var metadata: [String: Any] = [
            "source_path": relativePath,
            "tags": document.tags
        ]
        if let rawFrontmatter = document.frontmatter?.raw {
            metadata["raw_frontmatter"] = rawFrontmatter
        }
        if document.isEncrypted {
            metadata["encryption_marker"] = ObsidianMarkdownDocument.encryptedBodyMarker
            metadata["secret_note"] = true
            metadata["decrypted_for_import"] = document.decryptedBodyMarkdown != nil
            metadata["stored_plaintext"] = !document.isSecretNote
        }
        if let diaryMatch {
            var diary: [String: Any] = [
                "kind": diaryMatch.kind,
                "pattern": diaryMatch.pattern
            ]
            if let dateString = diaryMatch.dateString {
                diary["date"] = dateString
            }
            metadata["diary"] = diary
        }
        return metadata
    }

    private func ensureNotebookPath(
        workspaceID: String,
        components: [String],
        fallbackNotebookID: String? = nil
    ) throws -> String {
        var parentNotebookID: String?
        var lastNotebookID = fallbackNotebookID
        for component in components where !component.isEmpty {
            if let existingID = try existingNotebookID(
                workspaceID: workspaceID,
                parentNotebookID: parentNotebookID,
                name: component
            ) {
                lastNotebookID = existingID
            } else {
                let notebook = try pageRepository.createNotebook(
                    workspaceID: workspaceID,
                    name: component,
                    parentNotebookID: parentNotebookID
                )
                lastNotebookID = notebook.id
            }
            parentNotebookID = lastNotebookID
        }

        guard let lastNotebookID else {
            throw ObsidianVaultImporterError.notebookPathEmpty
        }
        return lastNotebookID
    }

    private func existingNotebookID(
        workspaceID: String,
        parentNotebookID: String?,
        name: String
    ) throws -> String? {
        if let parentNotebookID {
            return try database.query(
                """
                SELECT id
                FROM notebooks
                WHERE workspace_id = ?
                  AND parent_notebook_id = ?
                  AND name = ?
                ORDER BY created_at ASC
                LIMIT 1
                """,
                bindings: [
                    .text(workspaceID),
                    .text(parentNotebookID),
                    .text(name)
                ]
            ).first?["id"] ?? nil
        }

        return try database.query(
            """
            SELECT id
            FROM notebooks
            WHERE workspace_id = ?
              AND parent_notebook_id IS NULL
              AND name = ?
            ORDER BY created_at ASC
            LIMIT 1
            """,
            bindings: [
                .text(workspaceID),
                .text(name)
            ]
        ).first?["id"] ?? nil
    }

    private func ensureTagPath(workspaceID: String, tagPath: String) throws -> String {
        let components = tagPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !components.isEmpty else {
            throw ObsidianVaultImporterError.emptyTagPath
        }

        var parentTagID: String?
        var lastTagID: String?
        for component in components {
            if let existingID = try existingTagID(
                workspaceID: workspaceID,
                parentTagID: parentTagID,
                name: component
            ) {
                lastTagID = existingID
            } else {
                let tag = try tagRepository.createTag(
                    workspaceID: workspaceID,
                    parentTagID: parentTagID,
                    name: component
                )
                lastTagID = tag.id
            }
            parentTagID = lastTagID
        }

        guard let lastTagID else {
            throw ObsidianVaultImporterError.emptyTagPath
        }
        return lastTagID
    }

    private func existingTagID(
        workspaceID: String,
        parentTagID: String?,
        name: String
    ) throws -> String? {
        if let parentTagID {
            return try database.query(
                """
                SELECT id
                FROM tags
                WHERE workspace_id = ?
                  AND parent_tag_id = ?
                  AND name = ?
                ORDER BY created_at ASC
                LIMIT 1
                """,
                bindings: [
                    .text(workspaceID),
                    .text(parentTagID),
                    .text(name)
                ]
            ).first?["id"] ?? nil
        }

        return try database.query(
            """
            SELECT id
            FROM tags
            WHERE workspace_id = ?
              AND parent_tag_id IS NULL
              AND name = ?
            ORDER BY created_at ASC
            LIMIT 1
            """,
            bindings: [
                .text(workspaceID),
                .text(name)
            ]
        ).first?["id"] ?? nil
    }

    private func importedPageID(sourcePath: String) throws -> String? {
        try database.query(
            """
            SELECT page_id
            FROM page_import_metadata
            WHERE source_type = ?
              AND source_path = ?
            LIMIT 1
            """,
            bindings: [
                .text(configuration.sourceType),
                .text(sourcePath)
            ]
        ).first?["page_id"] ?? nil
    }

    private static func importedPageTitle(
        markdownURL: URL,
        diaryMatch: ObsidianDiaryMatch?
    ) -> String {
        if let diaryDateString = diaryMatch?.dateString,
           let title = DiaryRepository.diaryTitle(
            diaryDateString: diaryDateString,
            calendar: diaryCalendar
           ) {
            return title
        }

        return markdownURL.deletingPathExtension().lastPathComponent
    }

    private func sourceTimestamps(
        markdownURL: URL,
        document: ObsidianMarkdownDocument
    ) throws -> ObsidianSourceTimestamps {
        let frontmatterFields = document.frontmatter?.fields ?? [:]
        let resourceValues = try markdownURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let sourceCreatedAt = firstMetadataTimestamp(
            fields: frontmatterFields,
            keys: ["创建时间", "created", "created_at", "created_day"]
        ) ?? resourceValues.creationDate.map(Self.timestamp(from:))
        let sourceModifiedAt = firstMetadataTimestamp(
            fields: frontmatterFields,
            keys: ["修改时间", "modified", "modified_at", "modified_day"]
        ) ?? resourceValues.contentModificationDate.map(Self.timestamp(from:))

        return ObsidianSourceTimestamps(
            createdAt: sourceCreatedAt,
            modifiedAt: sourceModifiedAt
        )
    }

    private func makeAttachmentIndex(vaultURL: URL) throws -> [String: URL] {
        guard let enumerator = fileManager.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else {
            return [:]
        }

        var index: [String: URL] = [:]
        while let item = enumerator.nextObject() as? URL {
            let relativePath = try self.relativePath(for: item, vaultURL: vaultURL)
            let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values.isDirectory == true {
                if isHidden(relativePath: relativePath) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard values.isRegularFile == true,
                  !isHidden(relativePath: relativePath) else {
                continue
            }

            for filenameKey in Self.attachmentFilenameCandidates(for: item.lastPathComponent) where index[filenameKey] == nil {
                index[filenameKey] = item
            }
        }
        return index
    }

    private static func attachmentSourceURL(
        attachmentRelativePath: String,
        markdownURL: URL,
        vaultURL: URL,
        attachmentIndex: [String: URL],
        configuration: ObsidianVaultImportConfiguration
    ) -> URL? {
        let decodedPath = (attachmentRelativePath.removingPercentEncoding ?? attachmentRelativePath)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !decodedPath.isEmpty,
              decodedPath.range(of: #"^[A-Za-z][A-Za-z0-9+.-]*:"#, options: .regularExpression) == nil,
              !decodedPath.hasPrefix("/") else {
            return nil
        }

        let pathComponents = decodedPath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard pathComponents.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            return nil
        }

        let filename = pathComponents.last ?? decodedPath
        let pathComponentCandidates = Self.attachmentPathComponentCandidates(pathComponents)
        let filenameCandidates = Self.attachmentFilenameCandidates(for: filename)
        let markdownDirectory = markdownURL.deletingLastPathComponent()
        var candidates: [URL] = pathComponentCandidates.map {
            url(byAppending: $0, to: markdownDirectory)
        }
        for directory in configuration.attachmentSearchDirectories {
            for components in pathComponentCandidates {
                candidates.append(url(byAppending: components, to: directory))
            }
            for filenameCandidate in filenameCandidates {
                candidates.append(directory.appendingPathComponent(filenameCandidate))
            }
        }
        for components in pathComponentCandidates {
            candidates.append(url(byAppending: components, to: vaultURL))
        }
        let vaultAttachmentsDirectory = vaultURL.appendingPathComponent("attachments", isDirectory: true)
        for filenameCandidate in filenameCandidates {
            candidates.append(vaultAttachmentsDirectory.appendingPathComponent(filenameCandidate))
        }
        for filenameCandidate in filenameCandidates {
            if let indexedURL = attachmentIndex[filenameCandidate] {
                candidates.append(indexedURL)
            }
        }

        return candidates.first { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                && !isDirectory.boolValue
        }
    }

    private static func shouldImportMarkdownFile(relativePath: String) -> Bool {
        !URL(fileURLWithPath: relativePath).lastPathComponent.lowercased().hasSuffix(".excalidraw.md")
    }

    private static func attachmentPathComponentCandidates(_ pathComponents: [String]) -> [[String]] {
        guard let filename = pathComponents.last else {
            return [pathComponents]
        }

        var candidates: [[String]] = []
        var seen: Set<String> = []
        for filenameCandidate in attachmentFilenameCandidates(for: filename) {
            var candidate = pathComponents
            candidate[candidate.count - 1] = filenameCandidate
            let key = candidate.joined(separator: "/")
            guard !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            candidates.append(candidate)
        }
        return candidates
    }

    private static func attachmentFilenameCandidates(for filename: String) -> [String] {
        var candidates: [String] = []
        var seen: Set<String> = []
        func append(_ value: String) {
            guard !seen.contains(value) else {
                return
            }
            seen.insert(value)
            candidates.append(value)
        }

        for value in [filename, filename.removingPercentEncoding ?? filename] {
            append(value)
            let lowercasedValue = value.lowercased()
            if lowercasedValue.hasSuffix(".excalidraw") {
                append(value + ".md")
            }
            if lowercasedValue.hasSuffix(".excalidraw.md") {
                append(String(value.dropLast(3)))
            }
            if let webPFallback = webPFallbackFilename(for: value) {
                append(webPFallback)
            }
        }
        return candidates
    }

    private static func webPFallbackFilename(for filename: String) -> String? {
        let lowercasedFilename = filename.lowercased()
        for imageExtension in ["png", "jpg", "jpeg"] where lowercasedFilename.hasSuffix(".\(imageExtension)") {
            return String(filename.dropLast(imageExtension.count + 1)) + ".webp"
        }
        return nil
    }

    private static func url(byAppending pathComponents: [String], to rootURL: URL) -> URL {
        pathComponents.reduce(rootURL) { partialURL, component in
            partialURL.appendingPathComponent(component)
        }
    }

    private func directoryComponents(relativePath: String) -> [String] {
        let components = relativePath.split(separator: "/").map(String.init)
        guard components.count > 1 else {
            return []
        }
        return Array(components.dropLast())
    }

    private func relativePath(for url: URL, vaultURL: URL) throws -> String {
        let rootPath = vaultURL.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else {
            throw ObsidianVaultImporterError.pathOutsideVault(filePath)
        }
        let relativeStart = filePath.index(filePath.startIndex, offsetBy: rootPath.count)
        return String(filePath[relativeStart...])
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func isHidden(relativePath: String) -> Bool {
        relativePath
            .split(separator: "/", omittingEmptySubsequences: true)
            .contains { $0.hasPrefix(".") }
    }

    private func firstMetadataValue(
        fields: [String: ObsidianFrontmatterValue],
        keys: [String]
    ) -> String? {
        for key in keys {
            guard let value = fields[key] else {
                continue
            }
            switch value {
            case .scalar(let scalar) where !scalar.isEmpty:
                return scalar
            case .list(let values):
                if let first = values.first(where: { !$0.isEmpty }) {
                    return first
                }
            default:
                continue
            }
        }
        return nil
    }

    private func firstMetadataTimestamp(
        fields: [String: ObsidianFrontmatterValue],
        keys: [String]
    ) -> String? {
        guard let value = firstMetadataValue(fields: fields, keys: keys) else {
            return nil
        }
        return Self.normalizedTimestamp(value)
    }

    private static func normalizedTimestamp(_ rawValue: String) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }

        let isoWithFractionalSeconds = ISO8601DateFormatter()
        isoWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFractionalSeconds.date(from: value) {
            return timestamp(from: date)
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) {
            return timestamp(from: date)
        }

        for format in metadataTimestampFormats {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return timestamp(from: date)
            }
        }

        return nil
    }

    private func jsonString(_ value: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        guard let string = String(data: data, encoding: .utf8) else {
            throw ObsidianVaultImporterError.invalidMetadataEncoding
        }
        return string
    }

    private static func timestamp() -> String {
        timestamp(from: Date())
    }

    private static func timestamp(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static var diaryCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static let metadataTimestampFormats = [
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd",
        "yyyy.M.d HH:mm:ss",
        "yyyy.M.d HH:mm",
        "yyyy.M.d",
        "yyyy年M月d日 HH:mm:ss",
        "yyyy年M月d日 HH:mm",
        "yyyy年M月d日"
    ]
}

enum ObsidianVaultImporterError: Error, Equatable {
    case unreadableVault(String)
    case pathOutsideVault(String)
    case defaultVaultURLMissing
    case notebookPathEmpty
    case emptyTagPath
    case invalidMetadataEncoding
}
