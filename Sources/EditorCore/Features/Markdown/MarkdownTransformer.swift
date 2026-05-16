import Foundation

struct MarkdownShortcutTransform: Equatable, Sendable {
    let type: BlockType
    let textPlain: String
    let taskItemIsCompleted: Bool

    init(type: BlockType, textPlain: String, taskItemIsCompleted: Bool = false) {
        self.type = type
        self.textPlain = textPlain
        self.taskItemIsCompleted = taskItemIsCompleted
    }
}

struct MarkdownBlockDraft: Equatable, Sendable {
    let type: BlockType
    let textPlain: String
    let taskItemIsCompleted: Bool

    init(type: BlockType, textPlain: String, taskItemIsCompleted: Bool = false) {
        self.type = type
        self.textPlain = textPlain
        self.taskItemIsCompleted = taskItemIsCompleted
    }
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

    init(rows: [[String]]) {
        self.rows = Self.normalizedRows(rows)
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

    private static func normalizedRows(_ rows: [[String]]) -> [[String]] {
        let columnCount = rows.map(\.count).max() ?? 0
        guard columnCount > 0 else {
            return [[""]]
        }

        return rows.map { row in
            row + Array(repeating: "", count: max(columnCount - row.count, 0))
        }
    }

    private func markdownLine(cells: [String]) -> String {
        "| \(cells.joined(separator: " | ")) |"
    }
}

enum MarkdownInlineLinkComposer {
    static func markdown(label: String, url: String) -> String? {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty,
              !trimmedURL.isEmpty,
              URLComponents(string: trimmedURL)?.scheme != nil else {
            return nil
        }

        return "[\(escapedLabel(trimmedLabel))](\(escapedURL(trimmedURL)))"
    }

    static func escapedLabelLength(label: String) -> Int? {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else {
            return nil
        }

        return (escapedLabel(trimmedLabel) as NSString).length
    }

    private static func escapedLabel(_ label: String) -> String {
        label
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "]", with: "\\]")
    }

    private static func escapedURL(_ url: String) -> String {
        url
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ")", with: "\\)")
    }
}

enum MarkdownInlineLinkInserter {
    static func apply(
        label: String,
        url: String,
        to text: String,
        selection: EditorTextSelection
    ) -> MarkdownInlineFormatResult? {
        guard let linkMarkdown = MarkdownInlineLinkComposer.markdown(label: label, url: url),
              let labelLength = MarkdownInlineLinkComposer.escapedLabelLength(label: label),
              selection.location >= 0,
              selection.length >= 0 else {
            return nil
        }

        let nsText = text as NSString
        guard selection.location <= nsText.length,
              selection.length <= nsText.length - selection.location else {
            return nil
        }

        let range = NSRange(location: selection.location, length: selection.length)
        let formattedText = nsText.replacingCharacters(in: range, with: linkMarkdown)
        let nextSelection = EditorTextSelection(
            blockID: selection.blockID,
            location: selection.location + 1,
            length: labelLength
        )

        return MarkdownInlineFormatResult(text: formattedText, selection: nextSelection)
    }
}

enum MarkdownInlineLinkRemover {
    static func apply(to text: String, target: MarkdownInlineLinkEditTarget) -> MarkdownInlineFormatResult? {
        let selection = target.replacementSelection
        guard selection.location >= 0,
              selection.length >= 0 else {
            return nil
        }

        let nsText = text as NSString
        guard selection.location <= nsText.length,
              selection.length <= nsText.length - selection.location else {
            return nil
        }

        let range = NSRange(location: selection.location, length: selection.length)
        let formattedText = nsText.replacingCharacters(in: range, with: target.label)
        let nextSelection = EditorTextSelection(
            blockID: selection.blockID,
            location: selection.location,
            length: (target.label as NSString).length
        )

        return MarkdownInlineFormatResult(text: formattedText, selection: nextSelection)
    }
}

struct MarkdownInlineLinkEditTarget: Equatable, Sendable {
    let label: String
    let url: String
    let replacementSelection: EditorTextSelection

    static func target(in text: String, selection: EditorTextSelection) -> MarkdownInlineLinkEditTarget? {
        let nsText = text as NSString
        guard selection.location >= 0,
              selection.length >= 0,
              selection.location <= nsText.length,
              selection.length <= nsText.length - selection.location else {
            return nil
        }

        let selectionRange = NSRange(location: selection.location, length: selection.length)
        let codeRanges = MarkdownInlineStyleScanner.runs(in: text).compactMap { run in
            run.kind == .code ? run.range : nil
        }
        var searchStart = text.startIndex

        while let labelStart = nextUnescaped("[", in: text, from: searchStart) {
            guard !isImageLink(labelStart: labelStart, in: text) else {
                searchStart = text.index(after: labelStart)
                continue
            }

            let labelContentStart = text.index(after: labelStart)
            guard let labelEnd = nextUnescaped("]", in: text, from: labelContentStart) else {
                break
            }

            let openingParenthesis = text.index(after: labelEnd)
            guard openingParenthesis < text.endIndex,
                  text[openingParenthesis] == "(" else {
                searchStart = labelContentStart
                continue
            }

            let urlContentStart = text.index(after: openingParenthesis)
            guard let urlEnd = nextUnescaped(")", in: text, from: urlContentStart) else {
                break
            }

            let fullRange = labelStart..<text.index(after: urlEnd)
            let fullNSRange = NSRange(fullRange, in: text)
            guard !codeRanges.contains(where: { NSIntersectionRange($0, fullNSRange).length > 0 }) else {
                searchStart = text.index(after: urlEnd)
                continue
            }

            if contains(selectionRange, in: fullNSRange) {
                let label = unescapedMarkdownText(
                    text[labelContentStart..<labelEnd],
                    escapedCharacters: Set<Character>(["\\", "]"])
                )
                let url = unescapedMarkdownText(
                    text[urlContentStart..<urlEnd],
                    escapedCharacters: Set<Character>(["\\", ")"])
                )
                let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedLabel.isEmpty,
                      !trimmedURL.isEmpty else {
                    return nil
                }

                return MarkdownInlineLinkEditTarget(
                    label: trimmedLabel,
                    url: trimmedURL,
                    replacementSelection: EditorTextSelection(
                        blockID: selection.blockID,
                        location: fullNSRange.location,
                        length: fullNSRange.length
                    )
                )
            }

            searchStart = text.index(after: urlEnd)
        }

        return nil
    }

    private static func nextUnescaped(
        _ target: Character,
        in text: String,
        from start: String.Index
    ) -> String.Index? {
        var index = start
        var isEscaping = false

        while index < text.endIndex {
            let character = text[index]
            if isEscaping {
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else if character == target {
                return index
            }
            index = text.index(after: index)
        }

        return nil
    }

    private static func isImageLink(labelStart: String.Index, in text: String) -> Bool {
        guard labelStart > text.startIndex else {
            return false
        }

        let previous = text.index(before: labelStart)
        return text[previous] == "!"
    }

    private static func contains(_ selectionRange: NSRange, in fullRange: NSRange) -> Bool {
        selectionRange.location >= fullRange.location &&
            NSMaxRange(selectionRange) <= NSMaxRange(fullRange)
    }

    private static func unescapedMarkdownText(
        _ text: Substring,
        escapedCharacters: Set<Character>
    ) -> String {
        var result = ""
        var isEscaping = false

        for character in text {
            if isEscaping {
                if escapedCharacters.contains(character) || character == "\\" {
                    result.append(character)
                } else {
                    result.append("\\")
                    result.append(character)
                }
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else {
                result.append(character)
            }
        }

        if isEscaping {
            result.append("\\")
        }
        return result
    }
}

enum MarkdownInlineStyleKind: Equatable {
    case syntax
    case bold
    case italic
    case strikethrough
    case code
    case link
}

struct MarkdownInlineStyleRun: Equatable {
    let kind: MarkdownInlineStyleKind
    let range: NSRange
}

enum MarkdownInlineStyleScanner {
    static func runs(in text: String, includingSyntaxMarkers: Bool = false) -> [MarkdownInlineStyleRun] {
        let nsText = text as NSString
        let codeRuns = codeStyleRuns(in: nsText)
        let codeRanges = codeRuns.map(\.range)
        var runs = codeRuns +
            boldStyleRuns(in: nsText, excluding: codeRanges) +
            italicStyleRuns(in: nsText, excluding: codeRanges) +
            strikethroughStyleRuns(in: nsText, excluding: codeRanges) +
            linkStyleRuns(in: nsText, excluding: codeRanges)
        if includingSyntaxMarkers {
            runs += codeSyntaxRuns(in: nsText)
            runs += pairedSyntaxRuns(marker: "**", in: nsText, excluding: codeRanges)
            runs += italicSyntaxRuns(in: nsText, excluding: codeRanges)
            runs += pairedSyntaxRuns(marker: "~~", in: nsText, excluding: codeRanges)
            runs += linkSyntaxRuns(in: nsText, excluding: codeRanges)
        }
        return runs.sorted { lhs, rhs in
            if lhs.range.location == rhs.range.location {
                return lhs.range.length < rhs.range.length
            }
            return lhs.range.location < rhs.range.location
        }
    }

    private static func codeStyleRuns(in text: NSString) -> [MarkdownInlineStyleRun] {
        var runs: [MarkdownInlineStyleRun] = []
        var searchStart = 0

        while searchStart < text.length {
            let opening = range(of: "`", in: text, from: searchStart)
            guard opening.location != NSNotFound else {
                break
            }

            let closing = range(of: "`", in: text, from: NSMaxRange(opening))
            guard closing.location != NSNotFound else {
                break
            }

            let contentRange = NSRange(
                location: NSMaxRange(opening),
                length: closing.location - NSMaxRange(opening)
            )
            if contentRange.length > 0 {
                runs.append(MarkdownInlineStyleRun(kind: .code, range: contentRange))
            }
            searchStart = NSMaxRange(closing)
        }

        return runs
    }

    private static func codeSyntaxRuns(in text: NSString) -> [MarkdownInlineStyleRun] {
        var runs: [MarkdownInlineStyleRun] = []
        var searchStart = 0

        while searchStart < text.length {
            let opening = range(of: "`", in: text, from: searchStart)
            guard opening.location != NSNotFound else {
                break
            }

            let closing = range(of: "`", in: text, from: NSMaxRange(opening))
            guard closing.location != NSNotFound else {
                break
            }

            let contentRange = NSRange(
                location: NSMaxRange(opening),
                length: closing.location - NSMaxRange(opening)
            )
            if contentRange.length > 0 {
                runs.append(MarkdownInlineStyleRun(kind: .syntax, range: opening))
                runs.append(MarkdownInlineStyleRun(kind: .syntax, range: closing))
            }
            searchStart = NSMaxRange(closing)
        }

        return runs
    }

    private static func boldStyleRuns(in text: NSString, excluding excludedRanges: [NSRange]) -> [MarkdownInlineStyleRun] {
        var runs: [MarkdownInlineStyleRun] = []
        var searchStart = 0

        while searchStart < text.length {
            let opening = nextRange(
                of: "**",
                in: text,
                from: searchStart,
                excluding: excludedRanges
            )
            guard opening.location != NSNotFound else {
                break
            }

            let closing = nextRange(
                of: "**",
                in: text,
                from: NSMaxRange(opening),
                excluding: excludedRanges
            )
            guard closing.location != NSNotFound else {
                break
            }

            let contentRange = NSRange(
                location: NSMaxRange(opening),
                length: closing.location - NSMaxRange(opening)
            )
            if contentRange.length > 0 {
                runs.append(MarkdownInlineStyleRun(kind: .bold, range: contentRange))
            }
            searchStart = NSMaxRange(closing)
        }

        return runs
    }

    private static func pairedSyntaxRuns(
        marker: String,
        in text: NSString,
        excluding excludedRanges: [NSRange]
    ) -> [MarkdownInlineStyleRun] {
        var runs: [MarkdownInlineStyleRun] = []
        var searchStart = 0

        while searchStart < text.length {
            let opening = nextRange(
                of: marker,
                in: text,
                from: searchStart,
                excluding: excludedRanges
            )
            guard opening.location != NSNotFound else {
                break
            }

            let closing = nextRange(
                of: marker,
                in: text,
                from: NSMaxRange(opening),
                excluding: excludedRanges
            )
            guard closing.location != NSNotFound else {
                break
            }

            let contentRange = NSRange(
                location: NSMaxRange(opening),
                length: closing.location - NSMaxRange(opening)
            )
            if contentRange.length > 0 {
                runs.append(MarkdownInlineStyleRun(kind: .syntax, range: opening))
                runs.append(MarkdownInlineStyleRun(kind: .syntax, range: closing))
            }
            searchStart = NSMaxRange(closing)
        }

        return runs
    }

    private static func italicStyleRuns(in text: NSString, excluding excludedRanges: [NSRange]) -> [MarkdownInlineStyleRun] {
        var runs: [MarkdownInlineStyleRun] = []
        var searchStart = 0

        while searchStart < text.length {
            let opening = nextRange(
                of: "*",
                in: text,
                from: searchStart,
                excluding: excludedRanges
            )
            guard opening.location != NSNotFound else {
                break
            }

            let closing = nextRange(
                of: "*",
                in: text,
                from: NSMaxRange(opening),
                excluding: excludedRanges
            )
            guard closing.location != NSNotFound else {
                break
            }

            let contentRange = NSRange(
                location: NSMaxRange(opening),
                length: closing.location - NSMaxRange(opening)
            )
            if contentRange.length > 0 {
                runs.append(MarkdownInlineStyleRun(kind: .italic, range: contentRange))
            }
            searchStart = NSMaxRange(closing)
        }

        return runs
    }

    private static func italicSyntaxRuns(in text: NSString, excluding excludedRanges: [NSRange]) -> [MarkdownInlineStyleRun] {
        var runs: [MarkdownInlineStyleRun] = []
        var searchStart = 0

        while searchStart < text.length {
            let opening = nextSingleAsteriskRange(in: text, from: searchStart, excluding: excludedRanges)
            guard opening.location != NSNotFound else {
                break
            }

            let closing = nextSingleAsteriskRange(in: text, from: NSMaxRange(opening), excluding: excludedRanges)
            guard closing.location != NSNotFound else {
                break
            }

            let contentRange = NSRange(
                location: NSMaxRange(opening),
                length: closing.location - NSMaxRange(opening)
            )
            if contentRange.length > 0 {
                runs.append(MarkdownInlineStyleRun(kind: .syntax, range: opening))
                runs.append(MarkdownInlineStyleRun(kind: .syntax, range: closing))
            }
            searchStart = NSMaxRange(closing)
        }

        return runs
    }

    private static func strikethroughStyleRuns(in text: NSString, excluding excludedRanges: [NSRange]) -> [MarkdownInlineStyleRun] {
        var runs: [MarkdownInlineStyleRun] = []
        var searchStart = 0

        while searchStart < text.length {
            let opening = nextRange(
                of: "~~",
                in: text,
                from: searchStart,
                excluding: excludedRanges
            )
            guard opening.location != NSNotFound else {
                break
            }

            let closing = nextRange(
                of: "~~",
                in: text,
                from: NSMaxRange(opening),
                excluding: excludedRanges
            )
            guard closing.location != NSNotFound else {
                break
            }

            let contentRange = NSRange(
                location: NSMaxRange(opening),
                length: closing.location - NSMaxRange(opening)
            )
            if contentRange.length > 0 {
                runs.append(MarkdownInlineStyleRun(kind: .strikethrough, range: contentRange))
            }
            searchStart = NSMaxRange(closing)
        }

        return runs
    }

    private static func linkStyleRuns(in text: NSString, excluding excludedRanges: [NSRange]) -> [MarkdownInlineStyleRun] {
        var runs: [MarkdownInlineStyleRun] = []
        var searchStart = 0

        while searchStart < text.length {
            let opening = nextRange(
                of: "[",
                in: text,
                from: searchStart,
                excluding: excludedRanges
            )
            guard opening.location != NSNotFound else {
                break
            }

            let labelEnd = range(of: "](", in: text, from: NSMaxRange(opening))
            guard labelEnd.location != NSNotFound else {
                searchStart = NSMaxRange(opening)
                continue
            }

            let urlEnd = range(of: ")", in: text, from: NSMaxRange(labelEnd))
            guard urlEnd.location != NSNotFound else {
                searchStart = NSMaxRange(labelEnd)
                continue
            }

            let labelRange = NSRange(
                location: NSMaxRange(opening),
                length: labelEnd.location - NSMaxRange(opening)
            )
            let urlLocation = NSMaxRange(labelEnd)
            let urlRange = NSRange(location: urlLocation, length: urlEnd.location - urlLocation)
            let url = text.substring(with: urlRange)
            if labelRange.length > 0,
               URLComponents(string: url)?.scheme != nil,
               !overlapsAny(labelRange, excludedRanges) {
                runs.append(MarkdownInlineStyleRun(kind: .link, range: labelRange))
            }
            searchStart = NSMaxRange(urlEnd)
        }

        return runs
    }

    private static func linkSyntaxRuns(in text: NSString, excluding excludedRanges: [NSRange]) -> [MarkdownInlineStyleRun] {
        var runs: [MarkdownInlineStyleRun] = []
        var searchStart = 0

        while searchStart < text.length {
            let opening = nextRange(
                of: "[",
                in: text,
                from: searchStart,
                excluding: excludedRanges
            )
            guard opening.location != NSNotFound else {
                break
            }

            let labelEnd = range(of: "](", in: text, from: NSMaxRange(opening))
            guard labelEnd.location != NSNotFound else {
                searchStart = NSMaxRange(opening)
                continue
            }

            let urlEnd = range(of: ")", in: text, from: NSMaxRange(labelEnd))
            guard urlEnd.location != NSNotFound else {
                searchStart = NSMaxRange(labelEnd)
                continue
            }

            let labelRange = NSRange(
                location: NSMaxRange(opening),
                length: labelEnd.location - NSMaxRange(opening)
            )
            let urlLocation = NSMaxRange(labelEnd)
            let urlRange = NSRange(location: urlLocation, length: urlEnd.location - urlLocation)
            let url = text.substring(with: urlRange)
            if labelRange.length > 0,
               URLComponents(string: url)?.scheme != nil,
               !overlapsAny(labelRange, excludedRanges) {
                runs.append(MarkdownInlineStyleRun(kind: .syntax, range: opening))
                runs.append(
                    MarkdownInlineStyleRun(
                        kind: .syntax,
                        range: NSRange(location: labelEnd.location, length: NSMaxRange(urlEnd) - labelEnd.location)
                    )
                )
            }
            searchStart = NSMaxRange(urlEnd)
        }

        return runs
    }

    private static func nextRange(
        of marker: String,
        in text: NSString,
        from location: Int,
        excluding excludedRanges: [NSRange]
    ) -> NSRange {
        var searchStart = location
        while searchStart < text.length {
            let foundRange = range(of: marker, in: text, from: searchStart)
            guard foundRange.location != NSNotFound else {
                return foundRange
            }
            if !overlapsAny(foundRange, excludedRanges) {
                return foundRange
            }
            searchStart = NSMaxRange(foundRange)
        }
        return NSRange(location: NSNotFound, length: 0)
    }

    private static func nextSingleAsteriskRange(
        in text: NSString,
        from location: Int,
        excluding excludedRanges: [NSRange]
    ) -> NSRange {
        var searchStart = location
        while searchStart < text.length {
            let foundRange = range(of: "*", in: text, from: searchStart)
            guard foundRange.location != NSNotFound else {
                return foundRange
            }
            if !overlapsAny(foundRange, excludedRanges),
               !isAdjacentToAsterisk(foundRange, in: text) {
                return foundRange
            }
            searchStart = NSMaxRange(foundRange)
        }
        return NSRange(location: NSNotFound, length: 0)
    }

    private static func range(of marker: String, in text: NSString, from location: Int) -> NSRange {
        guard location < text.length else {
            return NSRange(location: NSNotFound, length: 0)
        }
        return text.range(
            of: marker,
            options: [],
            range: NSRange(location: location, length: text.length - location)
        )
    }

    private static func overlapsAny(_ range: NSRange, _ ranges: [NSRange]) -> Bool {
        ranges.contains { NSIntersectionRange(range, $0).length > 0 }
    }

    private static func isAdjacentToAsterisk(_ range: NSRange, in text: NSString) -> Bool {
        let previousLocation = range.location - 1
        if previousLocation >= 0,
           text.substring(with: NSRange(location: previousLocation, length: 1)) == "*" {
            return true
        }
        let nextLocation = NSMaxRange(range)
        if nextLocation < text.length,
           text.substring(with: NSRange(location: nextLocation, length: 1)) == "*" {
            return true
        }
        return false
    }
}

enum MarkdownInlineFormat: Equatable, Sendable {
    case bold
    case italic
    case strikethrough
    case code

    var openingMarker: String {
        switch self {
        case .bold:
            return "**"
        case .italic:
            return "*"
        case .strikethrough:
            return "~~"
        case .code:
            return "`"
        }
    }

    var closingMarker: String {
        openingMarker
    }

    var placeholder: String {
        switch self {
        case .bold:
            return "bold"
        case .italic:
            return "italic"
        case .strikethrough:
            return "strikethrough"
        case .code:
            return "code"
        }
    }

    func wrapped(_ text: String) -> String {
        "\(openingMarker)\(text)\(closingMarker)"
    }
}

struct MarkdownInlineFormatResult: Equatable, Sendable {
    let text: String
    let selection: EditorTextSelection
}

enum MarkdownInlineFormatter {
    static func applyResult(
        _ format: MarkdownInlineFormat,
        to text: String,
        selection: EditorTextSelection
    ) -> MarkdownInlineFormatResult? {
        guard selection.location >= 0,
              selection.length >= 0 else {
            return nil
        }

        let nsText = text as NSString
        guard selection.location <= nsText.length,
              selection.length <= nsText.length - selection.location else {
            return nil
        }

        let range = NSRange(location: selection.location, length: selection.length)
        if let toggledResult = toggleOffSelectedFormattedText(
            format,
            in: nsText,
            selection: selection,
            range: range
        ) ?? toggleOffExistingMarkersAroundSelection(
            format,
            in: nsText,
            selection: selection,
            range: range
        ) {
            return toggledResult
        }

        let selectedText = selection.length > 0 ? nsText.substring(with: range) : format.placeholder
        let formattedText = nsText.replacingCharacters(in: range, with: format.wrapped(selectedText))
        let nextSelection = EditorTextSelection(
            blockID: selection.blockID,
            location: selection.location + (format.openingMarker as NSString).length,
            length: (selectedText as NSString).length
        )

        return MarkdownInlineFormatResult(text: formattedText, selection: nextSelection)
    }

    static func apply(_ format: MarkdownInlineFormat, to text: String, selection: EditorTextSelection) -> String? {
        applyResult(format, to: text, selection: selection)?.text
    }

    private static func toggleOffSelectedFormattedText(
        _ format: MarkdownInlineFormat,
        in text: NSString,
        selection: EditorTextSelection,
        range: NSRange
    ) -> MarkdownInlineFormatResult? {
        guard range.length > 0 else {
            return nil
        }

        let openingLength = (format.openingMarker as NSString).length
        let closingLength = (format.closingMarker as NSString).length
        guard range.length > openingLength + closingLength else {
            return nil
        }

        let openingRange = NSRange(location: range.location, length: openingLength)
        let closingRange = NSRange(location: NSMaxRange(range) - closingLength, length: closingLength)
        guard text.substring(with: openingRange) == format.openingMarker,
              text.substring(with: closingRange) == format.closingMarker,
              isExactMarkerRun(format.openingMarker, in: text, range: openingRange),
              isExactMarkerRun(format.closingMarker, in: text, range: closingRange) else {
            return nil
        }

        let contentRange = NSRange(
            location: NSMaxRange(openingRange),
            length: range.length - openingLength - closingLength
        )
        let selectedText = text.substring(with: contentRange)
        return MarkdownInlineFormatResult(
            text: text.replacingCharacters(in: range, with: selectedText),
            selection: EditorTextSelection(
                blockID: selection.blockID,
                location: range.location,
                length: contentRange.length
            )
        )
    }

    private static func toggleOffExistingMarkersAroundSelection(
        _ format: MarkdownInlineFormat,
        in text: NSString,
        selection: EditorTextSelection,
        range: NSRange
    ) -> MarkdownInlineFormatResult? {
        guard range.length > 0 else {
            return nil
        }

        let openingLength = (format.openingMarker as NSString).length
        let closingLength = (format.closingMarker as NSString).length
        let openingLocation = range.location - openingLength
        let closingLocation = NSMaxRange(range)
        guard openingLocation >= 0,
              closingLocation + closingLength <= text.length else {
            return nil
        }

        let openingRange = NSRange(location: openingLocation, length: openingLength)
        let closingRange = NSRange(location: closingLocation, length: closingLength)
        guard text.substring(with: openingRange) == format.openingMarker,
              text.substring(with: closingRange) == format.closingMarker,
              isExactMarkerRun(format.openingMarker, in: text, range: openingRange),
              isExactMarkerRun(format.closingMarker, in: text, range: closingRange) else {
            return nil
        }

        let selectedText = text.substring(with: range)
        let fullRange = NSRange(
            location: openingLocation,
            length: openingLength + range.length + closingLength
        )
        return MarkdownInlineFormatResult(
            text: text.replacingCharacters(in: fullRange, with: selectedText),
            selection: EditorTextSelection(
                blockID: selection.blockID,
                location: openingLocation,
                length: range.length
            )
        )
    }

    private static func isExactMarkerRun(_ marker: String, in text: NSString, range: NSRange) -> Bool {
        guard let markerCharacter = marker.first,
              marker.allSatisfy({ $0 == markerCharacter }) else {
            return true
        }

        let markerUnit = String(markerCharacter)
        let previousLocation = range.location - 1
        if previousLocation >= 0,
           text.substring(with: NSRange(location: previousLocation, length: 1)) == markerUnit {
            return false
        }

        let nextLocation = NSMaxRange(range)
        if nextLocation < text.length,
           text.substring(with: NSRange(location: nextLocation, length: 1)) == markerUnit {
            return false
        }

        return true
    }
}

enum MarkdownTransformer {
    static func shortcutTransform(for text: String) -> MarkdownShortcutTransform? {
        switch text {
        case "# ":
            return MarkdownShortcutTransform(type: .heading1, textPlain: "")
        case "## ":
            return MarkdownShortcutTransform(type: .heading2, textPlain: "")
        case "### ":
            return MarkdownShortcutTransform(type: .heading3, textPlain: "")
        case "- ":
            return MarkdownShortcutTransform(type: .unorderedListItem, textPlain: "")
        case "1. ":
            return MarkdownShortcutTransform(type: .orderedListItem, textPlain: "")
        case "> ":
            return MarkdownShortcutTransform(type: .quote, textPlain: "")
        case "- [ ] ":
            return MarkdownShortcutTransform(type: .taskItem, textPlain: "")
        case "- [x] ", "- [X] ":
            return MarkdownShortcutTransform(
                type: .taskItem,
                textPlain: "",
                taskItemIsCompleted: true
            )
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
        export(blocks: blocks, attachments: [])
    }

    static func export(blocks: [BlockSnapshot], attachments: [AttachmentSnapshot]) -> String {
        blocks
            .map { block in
                markdownLine(for: block, attachments: attachments)
            }
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

    private static func markdownLine(for block: BlockSnapshot, attachments: [AttachmentSnapshot]) -> String {
        switch block.type {
        case .paragraph:
            return block.textPlain
        case .heading1:
            return "# \(block.textPlain)"
        case .heading2:
            return "## \(block.textPlain)"
        case .heading3:
            return "### \(block.textPlain)"
        case .unorderedListItem:
            return "- \(block.textPlain)"
        case .orderedListItem:
            return "1. \(block.textPlain)"
        case .taskItem:
            return "\(block.taskItemIsCompleted ? "- [x]" : "- [ ]") \(block.textPlain)"
        case .quote:
            return "> \(block.textPlain)"
        case .codeBlock:
            return "```\n\(block.textPlain)\n```"
        case .table:
            if !block.tableRows.isEmpty {
                return MarkdownTableDocument(rows: block.tableRows).markdown
            }
            return block.textPlain
        case .callout:
            return "> [!NOTE] \(block.textPlain)"
        case .toggle:
            return "<details><summary>\(block.textPlain)</summary></details>"
        case .divider:
            return "---"
        case .pageReference:
            return "[[\(block.textPlain)]]"
        case .blockReference:
            return "[[#\(block.textPlain)]]"
        case .attachmentImage, .attachmentVideo, .attachmentFile:
            return attachmentMarkdown(for: block, attachments: attachments)
        }
    }

    private static func attachmentMarkdown(for block: BlockSnapshot, attachments: [AttachmentSnapshot]) -> String {
        guard let attachment = attachments.first(where: { $0.matches(block: block) }) else {
            return "[\(block.textPlain)](\(block.textPlain))"
        }

        let path = [
            "Attachments",
            markdownPathComponent(attachment.id),
            markdownPathComponent(attachment.originalFilename)
        ].joined(separator: "/")
        let label = attachment.originalFilename
        if attachment.kind == .image {
            return "![\(label)](\(path))"
        }
        return "[\(label)](\(path))"
    }

    private static func markdownPathComponent(_ component: String) -> String {
        var allowedCharacters = CharacterSet.urlPathAllowed
        allowedCharacters.remove(charactersIn: "()")
        return component.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? component
    }

    private static func importBlockDraft(for line: String) -> MarkdownBlockDraft {
        if line.hasPrefix("### ") {
            return MarkdownBlockDraft(type: .heading3, textPlain: String(line.dropFirst(4)))
        }
        if line.hasPrefix("## ") {
            return MarkdownBlockDraft(type: .heading2, textPlain: String(line.dropFirst(3)))
        }
        if line.hasPrefix("# ") {
            return MarkdownBlockDraft(type: .heading1, textPlain: String(line.dropFirst(2)))
        }
        if line.hasPrefix("- [ ] ") {
            return MarkdownBlockDraft(type: .taskItem, textPlain: String(line.dropFirst(6)))
        }
        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
            return MarkdownBlockDraft(
                type: .taskItem,
                textPlain: String(line.dropFirst(6)),
                taskItemIsCompleted: true
            )
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
        if let pageReferenceText = pageReferenceText(for: line) {
            return MarkdownBlockDraft(type: .pageReference, textPlain: pageReferenceText)
        }
        if let blockReferenceText = blockReferenceText(for: line) {
            return MarkdownBlockDraft(type: .blockReference, textPlain: blockReferenceText)
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

    private static func pageReferenceText(for line: String) -> String? {
        let prefix = "[["
        let suffix = "]]"
        guard line.hasPrefix(prefix),
              line.hasSuffix(suffix),
              !line.hasPrefix("[[#") else {
            return nil
        }

        let text = String(line.dropFirst(prefix.count).dropLast(suffix.count))
        return text.isEmpty ? nil : text
    }

    private static func blockReferenceText(for line: String) -> String? {
        let prefix = "[[#"
        let suffix = "]]"
        guard line.hasPrefix(prefix),
              line.hasSuffix(suffix) else {
            return nil
        }

        let text = String(line.dropFirst(prefix.count).dropLast(suffix.count))
        return text.isEmpty ? nil : text
    }
}
