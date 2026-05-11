import Foundation

struct MarkdownShortcutTransform: Equatable, Sendable {
    let type: BlockType
    let textPlain: String
}

struct MarkdownBlockDraft: Equatable, Sendable {
    let type: BlockType
    let textPlain: String
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

        for line in markdown.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if codeLines != nil {
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
                codeLines = []
                continue
            }

            guard !trimmedLine.isEmpty else {
                continue
            }

            drafts.append(importBlockDraft(for: trimmedLine))
        }

        if let codeLines {
            drafts.append(
                MarkdownBlockDraft(
                    type: .codeBlock,
                    textPlain: codeLines.joined(separator: "\n")
                )
            )
        }

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
        if line.hasPrefix("> ") {
            return MarkdownBlockDraft(type: .quote, textPlain: String(line.dropFirst(2)))
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
}
