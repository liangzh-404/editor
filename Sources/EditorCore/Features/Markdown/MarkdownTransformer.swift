import Foundation

struct MarkdownShortcutTransform: Equatable, Sendable {
    let type: BlockType
    let textPlain: String
}

struct MarkdownBlockDraft: Equatable, Sendable {
    let type: BlockType
    let textPlain: String
}

struct MarkdownTableDocument: Equatable, Sendable {
    private(set) var rows: [[String]]

    init(markdown: String) {
        rows = markdown
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap(Self.cells(from:))
            .filter { !Self.isSeparatorRow($0) }

        let columnCount = rows.map(\.count).max() ?? 0
        if columnCount > 0 {
            rows = rows.map { row in
                row + Array(repeating: "", count: max(columnCount - row.count, 0))
            }
        }
    }

    var columnCount: Int {
        rows.map(\.count).max() ?? 0
    }

    var markdown: String {
        guard !rows.isEmpty else {
            return ""
        }

        var lines: [String] = []
        for (index, row) in rows.enumerated() {
            lines.append(markdownLine(cells: row))
            if index == 0 {
                lines.append(markdownLine(cells: Array(repeating: "---", count: max(row.count, 1))))
            }
        }
        return lines.joined(separator: "\n")
    }

    mutating func updateCell(row rowIndex: Int, column columnIndex: Int, text: String) {
        guard rows.indices.contains(rowIndex),
              rows[rowIndex].indices.contains(columnIndex) else {
            return
        }

        rows[rowIndex][columnIndex] = text
    }

    mutating func appendRow() {
        rows.append(Array(repeating: "", count: max(columnCount, 1)))
    }

    mutating func appendColumn() {
        guard !rows.isEmpty else {
            rows = [[""]]
            return
        }

        rows = rows.map { row in
            row + [""]
        }
    }

    mutating func removeLastRow() {
        guard rows.count > 1 else {
            return
        }

        rows.removeLast()
    }

    mutating func removeLastColumn() {
        guard columnCount > 1 else {
            return
        }

        rows = rows.map { row in
            Array(row.dropLast())
        }
    }

    private static func cells(from line: String) -> [String]? {
        guard line.contains("|") else {
            return nil
        }

        var content = line
        if content.hasPrefix("|") {
            content.removeFirst()
        }
        if content.hasSuffix("|") {
            content.removeLast()
        }

        return content
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func isSeparatorRow(_ cells: [String]) -> Bool {
        !cells.isEmpty && cells.allSatisfy { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && trimmed.allSatisfy { character in
                character == "-" || character == ":"
            }
        }
    }

    private func markdownLine(cells: [String]) -> String {
        "| \(cells.joined(separator: " | ")) |"
    }
}

enum MarkdownTransformer {
    static func shortcutTransform(for text: String) -> MarkdownShortcutTransform? {
        switch text {
        case "# ":
            return MarkdownShortcutTransform(type: .heading1, textPlain: "")
        case "- ":
            return MarkdownShortcutTransform(type: .unorderedListItem, textPlain: "")
        case "1. ":
            return MarkdownShortcutTransform(type: .orderedListItem, textPlain: "")
        case "> ":
            return MarkdownShortcutTransform(type: .quote, textPlain: "")
        case "- [ ] ":
            return MarkdownShortcutTransform(type: .taskItem, textPlain: "")
        case "```":
            return MarkdownShortcutTransform(type: .codeBlock, textPlain: "")
        case "> [!NOTE] ":
            return MarkdownShortcutTransform(type: .callout, textPlain: "")
        case "<details>":
            return MarkdownShortcutTransform(type: .toggle, textPlain: "")
        case "---":
            return MarkdownShortcutTransform(type: .divider, textPlain: "")
        default:
            return nil
        }
    }

    static func export(blocks: [BlockSnapshot]) -> String {
        blocks
            .map(markdownLine(for:))
            .joined(separator: "\n\n")
    }

    static func importBlocks(markdown: String) -> [MarkdownBlockDraft] {
        var drafts: [MarkdownBlockDraft] = []
        var codeLines: [String]?
        var tableLines: [String] = []
        var paragraphLines: [String] = []

        for line in markdown.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if codeLines != nil {
                flushParagraphLines(&paragraphLines, into: &drafts)
                flushTableLines(&tableLines, into: &drafts)
                if trimmedLine == "```" {
                    drafts.append(
                        MarkdownBlockDraft(
                            type: .codeBlock,
                            textPlain: codeLines?.joined(separator: "\n") ?? ""
                        )
                    )
                    codeLines = nil
                } else {
                    codeLines?.append(line)
                }
                continue
            }

            if trimmedLine == "```" {
                flushParagraphLines(&paragraphLines, into: &drafts)
                flushTableLines(&tableLines, into: &drafts)
                codeLines = []
                continue
            }

            guard !trimmedLine.isEmpty else {
                flushParagraphLines(&paragraphLines, into: &drafts)
                flushTableLines(&tableLines, into: &drafts)
                continue
            }

            if isTableLine(trimmedLine) {
                flushParagraphLines(&paragraphLines, into: &drafts)
                tableLines.append(trimmedLine)
                continue
            }

            flushTableLines(&tableLines, into: &drafts)
            let draft = importBlockDraft(for: trimmedLine)
            if draft.type == .paragraph {
                if shouldContinueParagraph(with: trimmedLine, existingLines: paragraphLines) {
                    paragraphLines.append(trimmedLine)
                } else {
                    flushParagraphLines(&paragraphLines, into: &drafts)
                    paragraphLines.append(trimmedLine)
                }
            } else {
                flushParagraphLines(&paragraphLines, into: &drafts)
                drafts.append(draft)
            }
        }

        if let codeLines {
            flushParagraphLines(&paragraphLines, into: &drafts)
            drafts.append(
                MarkdownBlockDraft(
                    type: .codeBlock,
                    textPlain: codeLines.joined(separator: "\n")
                )
            )
        }
        flushParagraphLines(&paragraphLines, into: &drafts)
        flushTableLines(&tableLines, into: &drafts)

        return drafts
    }

    private static func markdownLine(for block: BlockSnapshot) -> String {
        switch block.type {
        case .paragraph:
            return block.textPlain
        case .heading1:
            return "# \(block.textPlain)"
        case .unorderedListItem:
            return "- \(block.textPlain)"
        case .orderedListItem:
            return "1. \(block.textPlain)"
        case .taskItem:
            return "- [ ] \(block.textPlain)"
        case .quote:
            return "> \(block.textPlain)"
        case .codeBlock:
            return "```\n\(block.textPlain)\n```"
        case .table:
            return block.textPlain
        case .callout:
            return "> [!NOTE] \(block.textPlain)"
        case .toggle:
            return "<details><summary>\(block.textPlain)</summary></details>"
        case .divider:
            return "---"
        case .attachmentImage, .attachmentVideo, .attachmentFile:
            return "[\(block.textPlain)](\(block.textPlain))"
        }
    }

    private static func importBlockDraft(for line: String) -> MarkdownBlockDraft {
        if line.hasPrefix("# ") {
            return MarkdownBlockDraft(type: .heading1, textPlain: String(line.dropFirst(2)))
        }
        if line.hasPrefix("- [ ] ") {
            return MarkdownBlockDraft(type: .taskItem, textPlain: String(line.dropFirst(6)))
        }
        if line.hasPrefix("- ") {
            return MarkdownBlockDraft(type: .unorderedListItem, textPlain: String(line.dropFirst(2)))
        }
        if let orderedListText = orderedListItemText(for: line) {
            return MarkdownBlockDraft(type: .orderedListItem, textPlain: orderedListText)
        }
        if line.hasPrefix("> [!NOTE] ") {
            return MarkdownBlockDraft(type: .callout, textPlain: String(line.dropFirst(10)))
        }
        if line.hasPrefix("> ") {
            return MarkdownBlockDraft(type: .quote, textPlain: String(line.dropFirst(2)))
        }
        if let toggleText = toggleText(for: line) {
            return MarkdownBlockDraft(type: .toggle, textPlain: toggleText)
        }
        if line == "---" {
            return MarkdownBlockDraft(type: .divider, textPlain: "")
        }

        return MarkdownBlockDraft(type: .paragraph, textPlain: line)
    }

    private static func orderedListItemText(for line: String) -> String? {
        let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2,
              let marker = parts.first,
              marker.hasSuffix("."),
              marker.dropLast().allSatisfy(\.isNumber) else {
            return nil
        }

        return String(parts[1])
    }

    private static func isTableLine(_ line: String) -> Bool {
        line.contains("|") && line.trimmingCharacters(in: .whitespaces).hasPrefix("|")
    }

    private static func flushTableLines(
        _ tableLines: inout [String],
        into drafts: inout [MarkdownBlockDraft]
    ) {
        guard !tableLines.isEmpty else {
            return
        }
        drafts.append(
            MarkdownBlockDraft(
                type: .table,
                textPlain: tableLines.joined(separator: "\n")
            )
        )
        tableLines.removeAll()
    }

    private static func flushParagraphLines(
        _ paragraphLines: inout [String],
        into drafts: inout [MarkdownBlockDraft]
    ) {
        guard !paragraphLines.isEmpty else {
            return
        }

        drafts.append(
            MarkdownBlockDraft(
                type: .paragraph,
                textPlain: paragraphLines.joined(separator: " ")
            )
        )
        paragraphLines.removeAll()
    }

    private static func shouldContinueParagraph(
        with line: String,
        existingLines: [String]
    ) -> Bool {
        guard !existingLines.isEmpty,
              let firstCharacter = line.first else {
            return false
        }

        return firstCharacter.isLowercase
    }

    private static func toggleText(for line: String) -> String? {
        let prefix = "<details><summary>"
        let suffix = "</summary></details>"
        guard line.hasPrefix(prefix), line.hasSuffix(suffix) else {
            return nil
        }

        return String(line.dropFirst(prefix.count).dropLast(suffix.count))
    }
}
