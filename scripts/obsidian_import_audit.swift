import Foundation
import UniformTypeIdentifiers

struct AuditArguments {
    var vaultURL = ObsidianVaultImportConfiguration.defaultObsidianVaultURL
    var databasePath: String?
    var attachmentsDirectory: URL?
    var workspaceID = "workspace-local"
    var keepTemporaryStore = false
}

struct SourceMarkdownNote {
    let relativePath: String
    let url: URL
    let document: ObsidianMarkdownDocument
}

struct AttachmentReference {
    let sourcePath: String
    let rawPath: String
    let resolvedURL: URL?
}

struct BlockSignature: Equatable {
    let type: String
    let text: String
}

@main
enum ObsidianImportAudit {
    static func main() throws {
        let arguments = try parseArguments(Array(CommandLine.arguments.dropFirst()))
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent("editor-obsidian-import-audit-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer {
            if !arguments.keepTemporaryStore, arguments.databasePath == nil {
                try? fileManager.removeItem(at: temporaryRoot)
            }
        }

        let databasePath = arguments.databasePath ?? temporaryRoot.appendingPathComponent("editor.sqlite").path
        let attachmentsDirectory = arguments.attachmentsDirectory
            ?? temporaryRoot.appendingPathComponent("Attachments", isDirectory: true)
        try fileManager.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)

        let database = try SQLiteDatabase.open(path: databasePath)
        defer { database.close() }
        try SchemaMigrator.migrate(database: database)
        let repository = PageRepository(database: database)
        let snapshot = try repository.bootstrapWorkspaceIfNeeded()
        let workspaceID = snapshot.workspaces.contains { $0.id == arguments.workspaceID }
            ? arguments.workspaceID
            : snapshot.selectedWorkspaceID ?? arguments.workspaceID

        let sourceNotes = try enumerateSourceMarkdown(vaultURL: arguments.vaultURL)
        let nonMarkdownFileCount = try countNonMarkdownFiles(vaultURL: arguments.vaultURL)
        let attachmentIndex = try makeAttachmentIndex(vaultURL: arguments.vaultURL)
        let expectedAttachmentReferences = collectAttachmentReferences(
            sourceNotes: sourceNotes,
            vaultURL: arguments.vaultURL,
            attachmentIndex: attachmentIndex
        )
        let expectedResolvedAttachmentCount = expectedAttachmentReferences.filter { $0.resolvedURL != nil }.count
        let unresolvedAttachmentReferences = expectedAttachmentReferences.filter { $0.resolvedURL == nil }

        let existingImportedPageCount = try database.queryInt(
            "SELECT COUNT(*) FROM page_import_metadata WHERE source_type = 'obsidian'"
        )
        let existingAttachmentCount = try database.queryInt("SELECT COUNT(*) FROM attachments")

        let summary = try ObsidianVaultImporter(
            database: database,
            attachmentsDirectory: attachmentsDirectory
        ).importVaultInBatches(
            vaultURL: arguments.vaultURL,
            workspaceID: workspaceID
        )

        let importedRows = try database.query(
            """
            SELECT page_id,
                   source_path
            FROM page_import_metadata
            WHERE source_type = 'obsidian'
            ORDER BY source_path ASC
            """
        )
        let importedByPath = Dictionary<String, String>(
            uniqueKeysWithValues: importedRows.compactMap { row -> (String, String)? in
                guard let sourcePath = row["source_path"], let pageID = row["page_id"] else {
                    return nil
                }
                return (sourcePath, pageID)
            }
        )
        let sourcePaths = Set(sourceNotes.map { $0.relativePath })
        let importedPaths = Set(importedByPath.keys)
        let missingSourcePaths = sourcePaths.subtracting(importedPaths).sorted()
        let extraImportedPaths = importedPaths.subtracting(sourcePaths).sorted()
        let attachmentCountAfterImport = try database.queryInt("SELECT COUNT(*) FROM attachments")
        let importedAttachmentDelta = attachmentCountAfterImport - existingAttachmentCount

        let textMismatches = try sourceNotes.compactMap { note -> String? in
            guard let pageID = importedByPath[note.relativePath] else {
                return nil
            }
            let expected = expectedBlockSignatures(
                for: note,
                vaultURL: arguments.vaultURL,
                attachmentIndex: attachmentIndex
            )
            let actual = try actualBlockSignatures(pageID: pageID, database: database)
            guard expected != actual else {
                return nil
            }
            return mismatchDescription(path: note.relativePath, expected: expected, actual: actual)
        }

        print("vault=\(arguments.vaultURL.path)")
        print("database=\(databasePath)")
        print("attachments=\(attachmentsDirectory.path)")
        print("workspace=\(workspaceID)")
        print("source_markdown_files=\(sourceNotes.count)")
        print("source_non_markdown_files=\(nonMarkdownFileCount)")
        print("summary_markdown_files=\(summary.markdownFileCount)")
        print("summary_imported_pages=\(summary.importedPageCount)")
        print("summary_skipped_pages=\(summary.skippedPageCount)")
        print("summary_encrypted_pages=\(summary.encryptedPageCount)")
        print("summary_diary_pages=\(summary.diaryPageCount)")
        print("summary_imported_attachments=\(summary.importedAttachmentCount)")
        print("expected_resolved_attachment_references=\(expectedResolvedAttachmentCount)")
        print("imported_attachment_delta=\(importedAttachmentDelta)")
        print("existing_obsidian_imports_before=\(existingImportedPageCount)")
        print("missing_source_pages=\(missingSourcePaths.count)")
        print("extra_imported_pages=\(extraImportedPaths.count)")
        print("unresolved_attachment_references=\(unresolvedAttachmentReferences.count)")
        print("text_mismatched_pages=\(textMismatches.count)")
        print("diary_patterns=\(summary.diaryPatterns.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: ","))")

        printSample("missing_source_page", values: missingSourcePaths)
        printSample("extra_imported_page", values: extraImportedPaths)
        printSample(
            "unresolved_attachment",
            values: unresolvedAttachmentReferences.map { "\($0.sourcePath) -> \($0.rawPath)" }
        )
        printSample("text_mismatch", values: textMismatches, limit: 10)
    }

    private static func parseArguments(_ rawArguments: [String]) throws -> AuditArguments {
        var arguments = AuditArguments()
        var index = 0
        while index < rawArguments.count {
            let argument = rawArguments[index]
            switch argument {
            case "--vault":
                arguments.vaultURL = URL(fileURLWithPath: try value(after: argument, rawArguments, &index), isDirectory: true)
            case "--database":
                arguments.databasePath = try value(after: argument, rawArguments, &index)
            case "--attachments":
                arguments.attachmentsDirectory = URL(
                    fileURLWithPath: try value(after: argument, rawArguments, &index),
                    isDirectory: true
                )
            case "--workspace":
                arguments.workspaceID = try value(after: argument, rawArguments, &index)
            case "--keep-temporary-store":
                arguments.keepTemporaryStore = true
            case "--help", "-h":
                printUsageAndExit()
            default:
                throw AuditError.unknownArgument(argument)
            }
            index += 1
        }
        return arguments
    }

    private static func value(after argument: String, _ arguments: [String], _ index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw AuditError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }

    private static func printUsageAndExit() -> Never {
        print(
            """
            usage: obsidian_import_audit [--vault PATH] [--database PATH] [--attachments PATH] [--workspace ID] [--keep-temporary-store]
            """
        )
        Foundation.exit(0)
    }

    private static func enumerateSourceMarkdown(vaultURL: URL) throws -> [SourceMarkdownNote] {
        guard let enumerator = FileManager.default.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else {
            throw AuditError.unreadableVault(vaultURL.path)
        }

        var notes: [SourceMarkdownNote] = []
        while let item = enumerator.nextObject() as? URL {
            let relativePath = try relativePath(for: item, vaultURL: vaultURL)
            let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values.isDirectory == true {
                if isHidden(relativePath: relativePath) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard values.isRegularFile == true,
                  item.pathExtension.lowercased() == "md",
                  shouldImportMarkdownFile(relativePath: relativePath),
                  !isHidden(relativePath: relativePath) else {
                continue
            }
            let markdown = try String(contentsOf: item, encoding: .utf8)
            notes.append(
                SourceMarkdownNote(
                    relativePath: relativePath,
                    url: item,
                    document: ObsidianMarkdownDocument.parse(markdown)
                )
            )
        }
        return notes.sorted { $0.relativePath < $1.relativePath }
    }

    private static func countNonMarkdownFiles(vaultURL: URL) throws -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else {
            throw AuditError.unreadableVault(vaultURL.path)
        }

        var count = 0
        while let item = enumerator.nextObject() as? URL {
            let relativePath = try relativePath(for: item, vaultURL: vaultURL)
            let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values.isDirectory == true {
                if isHidden(relativePath: relativePath) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard values.isRegularFile == true, !isHidden(relativePath: relativePath) else {
                continue
            }
            if item.pathExtension.lowercased() != "md" || !shouldImportMarkdownFile(relativePath: relativePath) {
                count += 1
            }
        }
        return count
    }

    private static func makeAttachmentIndex(vaultURL: URL) throws -> [String: URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else {
            return [:]
        }

        var index: [String: URL] = [:]
        while let item = enumerator.nextObject() as? URL {
            let relativePath = try relativePath(for: item, vaultURL: vaultURL)
            let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values.isDirectory == true {
                if isHidden(relativePath: relativePath) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard values.isRegularFile == true, !isHidden(relativePath: relativePath) else {
                continue
            }
            for filenameKey in attachmentFilenameCandidates(for: item.lastPathComponent) where index[filenameKey] == nil {
                index[filenameKey] = item
            }
        }
        return index
    }

    private static func collectAttachmentReferences(
        sourceNotes: [SourceMarkdownNote],
        vaultURL: URL,
        attachmentIndex: [String: URL]
    ) -> [AttachmentReference] {
        sourceNotes.flatMap { note in
            MarkdownTransformer.importBlocks(markdown: note.document.markdownForImport)
                .compactMap { draft -> AttachmentReference? in
                    guard let rawPath = draft.attachmentRelativePath else {
                        return nil
                    }
                    return AttachmentReference(
                        sourcePath: note.relativePath,
                        rawPath: rawPath,
                        resolvedURL: resolveAttachment(
                            rawPath: rawPath,
                            markdownURL: note.url,
                            vaultURL: vaultURL,
                            attachmentIndex: attachmentIndex
                        )
                    )
                }
        }
    }

    private static func expectedBlockSignatures(
        for note: SourceMarkdownNote,
        vaultURL: URL,
        attachmentIndex: [String: URL]
    ) -> [BlockSignature] {
        MarkdownTransformer.importBlocks(markdown: note.document.markdownForImport).map { draft in
            guard let rawPath = draft.attachmentRelativePath else {
                return BlockSignature(type: draft.type.rawValue, text: draft.textPlain)
            }
            guard let sourceURL = resolveAttachment(
                rawPath: rawPath,
                markdownURL: note.url,
                vaultURL: vaultURL,
                attachmentIndex: attachmentIndex
            ) else {
                let markdownText = draft.type == .attachmentImage
                    ? "![\(draft.textPlain)](\(rawPath))"
                    : "[\(draft.textPlain)](\(rawPath))"
                return BlockSignature(type: BlockType.paragraph.rawValue, text: markdownText)
            }
            let utiType = UTType(filenameExtension: sourceURL.pathExtension)?.identifier ?? UTType.data.identifier
            return BlockSignature(
                type: AttachmentKind(utiType: utiType).blockType.rawValue,
                text: sourceURL.lastPathComponent
            )
        }
    }

    private static func actualBlockSignatures(pageID: String, database: SQLiteDatabase) throws -> [BlockSignature] {
        try database.query(
            """
            SELECT type,
                   text_plain
            FROM blocks
            WHERE page_id = ?
              AND is_deleted = 0
            ORDER BY order_key ASC
            """,
            bindings: [.text(pageID)]
        ).map {
            BlockSignature(type: $0["type"] ?? "", text: $0["text_plain"] ?? "")
        }
    }

    private static func resolveAttachment(
        rawPath: String,
        markdownURL: URL,
        vaultURL: URL,
        attachmentIndex: [String: URL]
    ) -> URL? {
        let decodedPath = (rawPath.removingPercentEncoding ?? rawPath)
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
        let pathComponentCandidates = attachmentPathComponentCandidates(pathComponents)
        let filenameCandidates = attachmentFilenameCandidates(for: filename)
        let markdownDirectory = markdownURL.deletingLastPathComponent()
        var candidates: [URL] = pathComponentCandidates.map {
            url(byAppending: $0, to: markdownDirectory)
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

    private static func relativePath(for url: URL, vaultURL: URL) throws -> String {
        let rootPath = vaultURL.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else {
            throw AuditError.pathOutsideVault(filePath)
        }
        let relativeStart = filePath.index(filePath.startIndex, offsetBy: rootPath.count)
        return String(filePath[relativeStart...])
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func isHidden(relativePath: String) -> Bool {
        relativePath
            .split(separator: "/", omittingEmptySubsequences: true)
            .contains { $0.hasPrefix(".") }
    }

    private static func mismatchDescription(
        path: String,
        expected: [BlockSignature],
        actual: [BlockSignature]
    ) -> String {
        let limit = min(expected.count, actual.count)
        let firstDifferentIndex = (0..<limit).first { expected[$0] != actual[$0] } ?? limit
        let expectedValue = firstDifferentIndex < expected.count
            ? "\(expected[firstDifferentIndex].type):\(expected[firstDifferentIndex].text)"
            : "<missing>"
        let actualValue = firstDifferentIndex < actual.count
            ? "\(actual[firstDifferentIndex].type):\(actual[firstDifferentIndex].text)"
            : "<missing>"
        return "\(path) @\(firstDifferentIndex + 1) expected=\(expectedValue) actual=\(actualValue) expected_count=\(expected.count) actual_count=\(actual.count)"
    }

    private static func printSample(_ label: String, values: [String], limit: Int = 20) {
        for value in values.prefix(limit) {
            print("\(label)=\(value)")
        }
        if values.count > limit {
            print("\(label)_remaining=\(values.count - limit)")
        }
    }
}

enum AuditError: Error, CustomStringConvertible {
    case missingValue(String)
    case unknownArgument(String)
    case unreadableVault(String)
    case pathOutsideVault(String)

    var description: String {
        switch self {
        case .missingValue(let argument):
            return "Missing value after \(argument)"
        case .unknownArgument(let argument):
            return "Unknown argument \(argument)"
        case .unreadableVault(let path):
            return "Unreadable vault \(path)"
        case .pathOutsideVault(let path):
            return "Path outside vault \(path)"
        }
    }
}
