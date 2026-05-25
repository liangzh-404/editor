# Inline Links Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add stable inline internal links, clickable external inline links, and anchored back/forward navigation for the editor.

**Architecture:** Keep the visible document text portable with wiki syntax such as `[[Specs]]` and `[[Specs#API contract]]`, while storing selected page/block IDs in block payload metadata and the existing `links` index. Add one shared parser that feeds repository indexing, native text styling, native hit testing, and insertion UI; then extend `WorkspaceViewModel` navigation history so internal link jumps can return to the source block and selection.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSTextView`, UIKit `UITextView`, SQLite, XCTest, existing `EditorTests`, `EditorMacUITests`, and `EditorIOSUITests` schemes.

---

## File Structure

- `Sources/EditorCore/Features/Markdown/MarkdownTransformer.swift`
  - Add shared inline-link parser models and wiki-link style ranges beside existing Markdown inline helpers.
- `Sources/EditorCore/Models/EditorModels.swift`
  - Add `InlineInternalLinkTarget` and carry stable inline targets on `BlockSnapshot`.
- `Sources/EditorCore/Store/SchemaMigrator.swift`
  - Add optional link-index columns for source ranges and link kind.
- `Sources/EditorCore/Store/BacklinkRepository.swift`
  - Rebuild links with source ranges, link kind, stable inline internal targets, external Markdown links, and plain URL links.
- `Sources/EditorCore/Store/PageRepository.swift`
  - Decode and encode block payload `inline_links`; add repository methods that insert stable inline internal links at a text selection.
- `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`
  - Add stable inline-link insertion APIs, internal-link activation APIs, and block-anchor navigation history.
- `Sources/EditorCore/Features/Editing/NativeTextBlockEditor.swift`
  - Style wiki links and external links, detect clicked character ranges, and call back to the shell without disturbing IME composition.
- `Sources/EditorCore/Features/Shell/EditorShellView.swift`
  - Wire callbacks through rows/canvas, add the internal-link chooser, and pass platform URL opening to inline external links.
- Tests stay in the current suites:
  - `Tests/EditorTests/MarkdownTransformerTests.swift`
  - `Tests/EditorTests/SchemaMigratorTests.swift`
  - `Tests/EditorTests/BacklinkRepositoryTests.swift`
  - `Tests/EditorTests/PageRepositoryTests.swift`
  - `Tests/EditorTests/WorkspaceViewModelTests.swift`
  - `Tests/EditorTests/NativeTextBlockEditorTests.swift`
  - `Tests/EditorTests/EditorBlockChromeTests.swift`
  - `Tests/EditorMacUITests/EditorMacEditingUITests.swift`
  - `Tests/EditorIOSUITests/EditorIOSEditingUITests.swift`

## Task 1: Shared Inline Link Parser And Styling Ranges

**Files:**
- Modify: `Sources/EditorCore/Features/Markdown/MarkdownTransformer.swift`
- Test: `Tests/EditorTests/MarkdownTransformerTests.swift`

- [ ] **Step 1: Write failing parser tests**

Add these tests near the existing Markdown inline-link scanner tests:

```swift
func testInlineLinkScannerFindsWikiPageAndBlockLinks() {
    let text = "See [[Specs]] and [[Specs#API contract]] today"

    XCTAssertEqual(
        InlineLinkScanner.links(in: text),
        [
            InlineLinkRun(
                kind: .internalWiki(label: "Specs", pageTitle: "Specs", blockText: nil),
                fullRange: NSRange(location: ("See " as NSString).length, length: ("[[Specs]]" as NSString).length),
                activeRange: NSRange(location: ("See [[" as NSString).length, length: ("Specs" as NSString).length)
            ),
            InlineLinkRun(
                kind: .internalWiki(label: "Specs#API contract", pageTitle: "Specs", blockText: "API contract"),
                fullRange: NSRange(location: ("See [[Specs]] and " as NSString).length, length: ("[[Specs#API contract]]" as NSString).length),
                activeRange: NSRange(location: ("See [[Specs]] and [[" as NSString).length, length: ("Specs#API contract" as NSString).length)
            )
        ]
    )
}

func testInlineLinkScannerFindsMarkdownAndPlainExternalLinks() {
    let text = "Read [Swift](https://swift.org), <https://example.com>, and https://apple.com."

    XCTAssertEqual(
        InlineLinkScanner.links(in: text).map(\.kind),
        [
            .external(label: "Swift", url: "https://swift.org"),
            .external(label: "https://example.com", url: "https://example.com"),
            .external(label: "https://apple.com", url: "https://apple.com")
        ]
    )
}

func testInlineLinkScannerIgnoresCodeSpansAndImages() {
    let text = "`[[Specs]]` ![Logo](https://example.com/logo.png) [[Live]]"

    XCTAssertEqual(
        InlineLinkScanner.links(in: text).map(\.kind),
        [.internalWiki(label: "Live", pageTitle: "Live", blockText: nil)]
    )
}

func testMarkdownInlineStyleScannerStylesWikiLinks() {
    let text = "See [[Specs]] and [Swift](https://swift.org)"

    XCTAssertTrue(
        MarkdownInlineStyleScanner.runs(in: text).contains(
            MarkdownInlineStyleRun(
                kind: .link,
                range: NSRange(location: ("See [[" as NSString).length, length: ("Specs" as NSString).length)
            )
        )
    )
}
```

- [ ] **Step 2: Run tests to verify red**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/MarkdownTransformerTests/testInlineLinkScannerFindsWikiPageAndBlockLinks -only-testing:EditorTests/MarkdownTransformerTests/testInlineLinkScannerFindsMarkdownAndPlainExternalLinks -only-testing:EditorTests/MarkdownTransformerTests/testInlineLinkScannerIgnoresCodeSpansAndImages -only-testing:EditorTests/MarkdownTransformerTests/testMarkdownInlineStyleScannerStylesWikiLinks
```

Expected: fail because `InlineLinkScanner` and `InlineLinkRun` do not exist, and wiki links are not styled.

- [ ] **Step 3: Add minimal parser models and scanner**

Add this near the existing inline Markdown helpers in `MarkdownTransformer.swift`:

```swift
enum InlineLinkKind: Equatable, Sendable {
    case internalWiki(label: String, pageTitle: String, blockText: String?)
    case external(label: String, url: String)
}

struct InlineLinkRun: Equatable, Sendable {
    let kind: InlineLinkKind
    let fullRange: NSRange
    let activeRange: NSRange
}

enum InlineLinkScanner {
    static func links(in text: String) -> [InlineLinkRun] {
        let nsText = text as NSString
        let codeRanges = MarkdownInlineStyleScanner.runs(in: text)
            .compactMap { $0.kind == .code ? $0.range : nil }
        let wikiRuns = wikiLinks(in: nsText, excluding: codeRanges)
        let markdownRuns = markdownExternalLinks(in: nsText, excluding: codeRanges + wikiRuns.map(\.fullRange))
        let autolinkRuns = autolinks(in: nsText, excluding: codeRanges + wikiRuns.map(\.fullRange) + markdownRuns.map(\.fullRange))
        let plainRuns = plainExternalLinks(in: nsText, excluding: codeRanges + wikiRuns.map(\.fullRange) + markdownRuns.map(\.fullRange) + autolinkRuns.map(\.fullRange))
        return (wikiRuns + markdownRuns + autolinkRuns + plainRuns)
        .sorted { lhs, rhs in
            lhs.fullRange.location == rhs.fullRange.location
                ? lhs.fullRange.length < rhs.fullRange.length
                : lhs.fullRange.location < rhs.fullRange.location
        }
    }

    static func link(containing location: Int, in text: String) -> InlineLinkRun? {
        links(in: text).first { NSLocationInRange(location, $0.activeRange) || NSLocationInRange(location, $0.fullRange) }
    }

    private static func wikiLinks(in text: NSString, excluding excludedRanges: [NSRange]) -> [InlineLinkRun] {
        var runs: [InlineLinkRun] = []
        var searchStart = 0
        while searchStart < text.length {
            let opening = text.range(of: "[[", options: [], range: NSRange(location: searchStart, length: text.length - searchStart))
            guard opening.location != NSNotFound else { break }
            let contentStart = NSMaxRange(opening)
            let closing = text.range(of: "]]", options: [], range: NSRange(location: contentStart, length: text.length - contentStart))
            guard closing.location != NSNotFound else { break }
            let fullRange = NSRange(location: opening.location, length: NSMaxRange(closing) - opening.location)
            let activeRange = NSRange(location: contentStart, length: closing.location - contentStart)
            if activeRange.length > 0,
               !excludedRanges.contains(where: { NSIntersectionRange($0, fullRange).length > 0 }) {
                let label = text.substring(with: activeRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !label.isEmpty {
                    let parts = label.split(separator: "#", maxSplits: 1).map(String.init)
                    runs.append(
                        InlineLinkRun(
                            kind: .internalWiki(
                                label: label,
                                pageTitle: parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
                                blockText: parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
                            ),
                            fullRange: fullRange,
                            activeRange: activeRange
                        )
                    )
                }
            }
            searchStart = NSMaxRange(closing)
        }
        return runs
    }

    private static func markdownExternalLinks(in text: NSString, excluding excludedRanges: [NSRange]) -> [InlineLinkRun] {
        var runs: [InlineLinkRun] = []
        var searchStart = 0
        while searchStart < text.length {
            let closeLabel = text.range(of: "](", options: [], range: NSRange(location: searchStart, length: text.length - searchStart))
            guard closeLabel.location != NSNotFound else { break }
            let openLabelSearchRange = NSRange(location: searchStart, length: closeLabel.location - searchStart)
            let openLabel = text.range(of: "[", options: .backwards, range: openLabelSearchRange)
            guard openLabel.location != NSNotFound else {
                searchStart = NSMaxRange(closeLabel)
                continue
            }
            if openLabel.location > 0,
               text.substring(with: NSRange(location: openLabel.location - 1, length: 1)) == "!" {
                searchStart = NSMaxRange(closeLabel)
                continue
            }
            let urlStart = NSMaxRange(closeLabel)
            let closeURL = text.range(of: ")", options: [], range: NSRange(location: urlStart, length: text.length - urlStart))
            guard closeURL.location != NSNotFound else { break }
            let fullRange = NSRange(location: openLabel.location, length: NSMaxRange(closeURL) - openLabel.location)
            let activeRange = NSRange(location: openLabel.location + 1, length: closeLabel.location - openLabel.location - 1)
            let urlRange = NSRange(location: urlStart, length: closeURL.location - urlStart)
            let label = text.substring(with: activeRange)
            let url = text.substring(with: urlRange)
            if !label.isEmpty,
               hasValidScheme(url),
               !overlaps(fullRange, excludedRanges) {
                runs.append(InlineLinkRun(kind: .external(label: label, url: url), fullRange: fullRange, activeRange: activeRange))
            }
            searchStart = NSMaxRange(closeURL)
        }
        return runs
    }

    private static func autolinks(in text: NSString, excluding excludedRanges: [NSRange]) -> [InlineLinkRun] {
        var runs: [InlineLinkRun] = []
        var searchStart = 0
        while searchStart < text.length {
            let opening = text.range(of: "<", options: [], range: NSRange(location: searchStart, length: text.length - searchStart))
            guard opening.location != NSNotFound else { break }
            let contentStart = NSMaxRange(opening)
            let closing = text.range(of: ">", options: [], range: NSRange(location: contentStart, length: text.length - contentStart))
            guard closing.location != NSNotFound else { break }
            let fullRange = NSRange(location: opening.location, length: NSMaxRange(closing) - opening.location)
            let activeRange = NSRange(location: contentStart, length: closing.location - contentStart)
            let url = text.substring(with: activeRange)
            if hasValidScheme(url),
               !overlaps(fullRange, excludedRanges) {
                runs.append(InlineLinkRun(kind: .external(label: url, url: url), fullRange: fullRange, activeRange: activeRange))
            }
            searchStart = NSMaxRange(closing)
        }
        return runs
    }

    private static func plainExternalLinks(in text: NSString, excluding excludedRanges: [NSRange]) -> [InlineLinkRun] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let fullRange = NSRange(location: 0, length: text.length)
        return detector.matches(in: text as String, options: [], range: fullRange).compactMap { match in
            guard let urlString = match.url?.absoluteString,
                  hasValidScheme(urlString) else {
                return nil
            }
            let linkRange = trimmedPlainURLRange(match.range, in: text)
            guard linkRange.length > 0,
                  !overlaps(linkRange, excludedRanges) else {
                return nil
            }
            let label = text.substring(with: linkRange)
            return InlineLinkRun(kind: .external(label: label, url: urlString), fullRange: linkRange, activeRange: linkRange)
        }
    }

    private static func hasValidScheme(_ urlString: String) -> Bool {
        guard let scheme = URLComponents(string: urlString)?.scheme?.lowercased() else {
            return false
        }
        return ["http", "https", "mailto"].contains(scheme)
    }

    private static func overlaps(_ range: NSRange, _ excludedRanges: [NSRange]) -> Bool {
        excludedRanges.contains { NSIntersectionRange($0, range).length > 0 }
    }

    private static func trimmedPlainURLRange(_ range: NSRange, in text: NSString) -> NSRange {
        var end = NSMaxRange(range)
        while end > range.location {
            let trailing = text.substring(with: NSRange(location: end - 1, length: 1))
            if [".", ",", ")", "]", "}"].contains(trailing) {
                end -= 1
            } else {
                break
            }
        }
        return NSRange(location: range.location, length: end - range.location)
    }
}
```

- [ ] **Step 4: Add wiki style runs**

In `MarkdownInlineStyleScanner.runs`, add wiki style and syntax runs to the existing run lists:

```swift
var runs = codeRuns +
    boldStyleRuns(marker: "**", in: nsText, excluding: codeRanges) +
    boldStyleRuns(marker: "__", in: nsText, excluding: codeRanges) +
    italicStyleRuns(in: nsText, excluding: codeRanges) +
    underscoreItalicStyleRuns(in: nsText, excluding: codeRanges) +
    strikethroughStyleRuns(in: nsText, excluding: codeRanges) +
    highlightStyleRuns(in: nsText, excluding: codeRanges) +
    linkStyleRuns(in: nsText, excluding: codeRanges) +
    autolinkStyleRuns(in: nsText, excluding: codeRanges) +
    wikiLinkStyleRuns(in: nsText, excluding: codeRanges)
```

When `includingSyntaxMarkers` is true, add syntax runs for `[[` and `]]`.

- [ ] **Step 5: Run focused tests to verify green**

Run the same `xcodebuild ... MarkdownTransformerTests/...` command from Step 2.

Expected: pass.

- [ ] **Step 6: Commit Task 1**

```bash
git add Sources/EditorCore/Features/Markdown/MarkdownTransformer.swift Tests/EditorTests/MarkdownTransformerTests.swift
git commit -m "Add inline link scanner"
```

## Task 2: Link Schema, Models, And Repository Indexing

**Files:**
- Modify: `Sources/EditorCore/Store/SchemaMigrator.swift`
- Modify: `Sources/EditorCore/Models/EditorModels.swift`
- Modify: `Sources/EditorCore/Store/BacklinkRepository.swift`
- Modify: `Sources/EditorCore/Store/PageRepository.swift`
- Test: `Tests/EditorTests/SchemaMigratorTests.swift`
- Test: `Tests/EditorTests/BacklinkRepositoryTests.swift`
- Test: `Tests/EditorTests/PageRepositoryTests.swift`

- [ ] **Step 1: Write failing schema test**

Add this to `SchemaMigratorTests` near the current links-table test:

```swift
func testLinksTableTracksInlineSourceRangesAndKind() throws {
    let database = try migratedDatabase()
    defer { database.close() }

    let columns = Set(try database.queryStrings("SELECT name FROM pragma_table_info('links')"))

    XCTAssertTrue(columns.contains("source_range_location"))
    XCTAssertTrue(columns.contains("source_range_length"))
    XCTAssertTrue(columns.contains("link_kind"))
}
```

- [ ] **Step 2: Write failing repository tests**

Add these to `BacklinkRepositoryTests`:

```swift
func testBlockUpdateIndexesInlineWikiLinkWithSourceRange() throws {
    let database = try migratedDatabase()
    defer { database.close() }
    let pageRepository = PageRepository(database: database)
    let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
    let pageID = try XCTUnwrap(snapshot.selectedPageID)
    let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

    try pageRepository.updateBlockText(blockID: blockID, text: "See [[欢迎]]")

    let rows = try database.query(
        """
        SELECT target_page_id, link_text, source_range_location, source_range_length, link_kind
        FROM links
        WHERE source_block_id = ?
        """,
        bindings: [.text(blockID)]
    )
    XCTAssertEqual(rows.first?["target_page_id"], pageID)
    XCTAssertEqual(rows.first?["link_text"], "欢迎")
    XCTAssertEqual(rows.first?["source_range_location"], String(("See " as NSString).length))
    XCTAssertEqual(rows.first?["source_range_length"], String(("[[欢迎]]" as NSString).length))
    XCTAssertEqual(rows.first?["link_kind"], "inline_internal")
}

func testBlockUpdateIndexesPlainExternalURLs() throws {
    let database = try migratedDatabase()
    defer { database.close() }
    let pageRepository = PageRepository(database: database)
    let snapshot = try pageRepository.bootstrapWorkspaceIfNeeded()
    let pageID = try XCTUnwrap(snapshot.selectedPageID)
    let blockID = try XCTUnwrap(snapshot.blocks.first?.id)

    try pageRepository.updateBlockText(blockID: blockID, text: "Visit https://swift.org now")

    XCTAssertEqual(
        try BacklinkRepository(database: database).externalLinks(sourcePageID: pageID).map(\.targetURL),
        ["https://swift.org"]
    )
}
```

Add this to `PageRepositoryTests`:

```swift
func testLoadWorkspaceSnapshotCarriesInlineInternalLinkTargets() throws {
    let database = try migratedDatabase()
    defer { database.close() }
    let repository = PageRepository(database: database)
    let snapshot = try repository.bootstrapWorkspaceIfNeeded()
    let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
    let sourceBlockID = try XCTUnwrap(snapshot.blocks.first?.id)
    let targetPage = try repository.createPage(workspaceID: workspaceID, title: "Specs")
    let nextText = "[[Specs]]开始用块写作。"
    let payloadJSON = """
    {"inline_links":[{"label":"Specs","target_page_id":"\(targetPage.id)"}],"text":"\(nextText)"}
    """
    try database.execute(
        """
        UPDATE blocks
        SET text_plain = ?,
            payload_json = ?
        WHERE id = ?
        """,
        bindings: [.text(nextText), .text(payloadJSON), .text(sourceBlockID)]
    )

    let block = try XCTUnwrap(try repository.loadWorkspaceSnapshot().blocks.first { $0.id == sourceBlockID })
    XCTAssertEqual(block.inlineInternalLinks, [
        InlineInternalLinkTarget(label: "Specs", targetPageID: targetPage.id, targetBlockID: nil)
    ])
    XCTAssertEqual(block.textPlain, "[[Specs]]开始用块写作。")
}
```

- [ ] **Step 3: Run tests to verify red**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/SchemaMigratorTests/testLinksTableTracksInlineSourceRangesAndKind -only-testing:EditorTests/BacklinkRepositoryTests/testBlockUpdateIndexesInlineWikiLinkWithSourceRange -only-testing:EditorTests/BacklinkRepositoryTests/testBlockUpdateIndexesPlainExternalURLs -only-testing:EditorTests/PageRepositoryTests/testLoadWorkspaceSnapshotCarriesInlineInternalLinkTargets
```

Expected: fail because schema columns, `InlineInternalLinkTarget`, `BlockSnapshot.inlineInternalLinks`, inline payload decoding, and source-range link indexing do not exist.

- [ ] **Step 4: Add schema columns**

In `SchemaMigrator.migrate`, after the existing `target_url` add-column call, add:

```swift
try addColumnIfMissing(
    database: database,
    table: "links",
    column: "source_range_location",
    definition: "INTEGER"
)
try addColumnIfMissing(
    database: database,
    table: "links",
    column: "source_range_length",
    definition: "INTEGER"
)
try addColumnIfMissing(
    database: database,
    table: "links",
    column: "link_kind",
    definition: "TEXT NOT NULL DEFAULT 'inline'"
)
```

- [ ] **Step 5: Add model support**

In `EditorModels.swift`, add:

```swift
struct InlineInternalLinkTarget: Equatable, Sendable {
    let label: String
    let targetPageID: String
    let targetBlockID: String?
}
```

Add `let inlineInternalLinks: [InlineInternalLinkTarget]` to `BlockSnapshot`, default it to `[]` in the initializer, and pass it through every `BlockSnapshot(...)` copy method. In `replacing(type:text:)`, keep inline targets only when the destination type supports inline Markdown styling:

```swift
inlineInternalLinks: type.supportsInlineMarkdownStyling ? inlineInternalLinks : []
```

- [ ] **Step 6: Decode and encode payload `inline_links`**

In `PageRepository`, add private helpers:

```swift
private static func inlineInternalLinks(payloadJSON: String) -> [InlineInternalLinkTarget] {
    guard let data = payloadJSON.data(using: .utf8),
          let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let rows = payload["inline_links"] as? [[String: Any]] else {
        return []
    }
    return rows.compactMap { row in
        guard let label = row["label"] as? String,
              !label.isEmpty,
              let targetPageID = row["target_page_id"] as? String,
              !targetPageID.isEmpty else {
            return nil
        }
        return InlineInternalLinkTarget(
            label: label,
            targetPageID: targetPageID,
            targetBlockID: row["target_block_id"] as? String
        )
    }
}

private static func payloadRows(for inlineLinks: [InlineInternalLinkTarget]) -> [[String: Any]] {
    inlineLinks.map { link in
        var row: [String: Any] = [
            "label": link.label,
            "target_page_id": link.targetPageID
        ]
        if let targetBlockID = link.targetBlockID,
           !targetBlockID.isEmpty {
            row["target_block_id"] = targetBlockID
        }
        return row
    }
}
```

Then extend `blockPayloadJSON(...)` to accept `inlineInternalLinks: [InlineInternalLinkTarget] = []` and add `"inline_links"` when the array is not empty.

- [ ] **Step 7: Extend backlink rebuilding**

Change `BacklinkRepository.rebuildLinksForBlock` to accept `inlineInternalLinks: [InlineInternalLinkTarget] = []`. For each `InlineLinkScanner.links(in: text)` result:

```swift
switch run.kind {
case .internalWiki(let label, let pageTitle, let blockText):
    let stable = inlineInternalLinks.first { $0.label == label }
    let fallback = try resolveInlineTarget(pageTitle: pageTitle, blockText: blockText)
    try insertLink(
        sourcePageID: sourcePageID,
        sourceBlockID: blockID,
        targetPageID: stable?.targetPageID ?? fallback.pageID,
        targetBlockID: stable?.targetBlockID ?? fallback.blockID,
        targetURL: nil,
        linkText: label,
        sourceRange: run.fullRange,
        linkKind: "inline_internal"
    )
case .external(let label, let url):
    try insertLink(
        sourcePageID: sourcePageID,
        sourceBlockID: blockID,
        targetPageID: nil,
        targetBlockID: nil,
        targetURL: url,
        linkText: label,
        sourceRange: run.fullRange,
        linkKind: "inline_external"
    )
}
```

Keep existing page-reference and block-reference block behavior by inserting one `link_kind = "block_reference"` row when `pageReferenceTargetPageID` is passed.

- [ ] **Step 8: Run focused tests to verify green**

Run the same `xcodebuild ... SchemaMigratorTests/... BacklinkRepositoryTests/... PageRepositoryTests/...` command from Step 3.

Expected: pass.

- [ ] **Step 9: Commit Task 2**

```bash
git add Sources/EditorCore/Store/SchemaMigrator.swift Sources/EditorCore/Models/EditorModels.swift Sources/EditorCore/Store/BacklinkRepository.swift Sources/EditorCore/Store/PageRepository.swift Tests/EditorTests/SchemaMigratorTests.swift Tests/EditorTests/BacklinkRepositoryTests.swift Tests/EditorTests/PageRepositoryTests.swift
git commit -m "Index stable inline links"
```

## Task 3: Stable Inline Internal Link Insertion

**Files:**
- Modify: `Sources/EditorCore/Store/PageRepository.swift`
- Modify: `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`
- Test: `Tests/EditorTests/PageRepositoryTests.swift`
- Test: `Tests/EditorTests/WorkspaceViewModelTests.swift`

- [ ] **Step 1: Write failing repository insertion tests**

Add to `PageRepositoryTests`:

```swift
func testInsertInlineInternalBlockLinkStoresStableTargetAndReadableText() throws {
    let database = try migratedDatabase()
    defer { database.close() }
    let repository = PageRepository(database: database)
    let snapshot = try repository.bootstrapWorkspaceIfNeeded()
    let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
    let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
    let sourceBlockID = try XCTUnwrap(snapshot.blocks.first?.id)
    let targetPage = try repository.createPage(workspaceID: workspaceID, title: "Specs")
    let targetBlock = try repository.appendBlock(pageID: targetPage.id, type: .paragraph, text: "API contract")

    let selection = try XCTUnwrap(
        try repository.insertInlineInternalLink(
            blockID: sourceBlockID,
            targetPageID: targetPage.id,
            targetBlockID: targetBlock.id,
            selection: EditorTextSelection(blockID: sourceBlockID, location: 3, length: 1)
        )
    )

    let block = try XCTUnwrap(try repository.loadWorkspaceSnapshot().blocks.first { $0.id == sourceBlockID })
    XCTAssertEqual(block.textPlain, "开始[[Specs#API contract]]块写作。")
    XCTAssertEqual(block.inlineInternalLinks, [
        InlineInternalLinkTarget(label: "Specs#API contract", targetPageID: targetPage.id, targetBlockID: targetBlock.id)
    ])
    XCTAssertEqual(selection, EditorTextSelection(blockID: sourceBlockID, location: ("开始[[" as NSString).length, length: ("Specs#API contract" as NSString).length))
    XCTAssertEqual(
        try BacklinkRepository(database: database).backlinks(targetPageID: targetPage.id).first?.sourcePageID,
        sourcePageID
    )
}
```

- [ ] **Step 2: Write failing view-model insertion test**

Add to `WorkspaceViewModelTests`:

```swift
@MainActor
func testInsertInlineInternalLinkForUIRefreshesBacklinksAndFocus() throws {
    let database = try migratedDatabase()
    defer { database.close() }
    let repository = PageRepository(database: database)
    let snapshot = try repository.bootstrapWorkspaceIfNeeded()
    let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
    let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
    let targetPage = try repository.createPage(workspaceID: workspaceID, title: "Specs")
    let viewModel = WorkspaceViewModel(repository: repository, backlinkRepository: BacklinkRepository(database: database))
    try viewModel.load()
    let blockID = try XCTUnwrap(viewModel.visibleBlocks.first?.id)

    let selection = try XCTUnwrap(
        try viewModel.insertInlineInternalLink(
            blockID: blockID,
            targetPageID: targetPage.id,
            targetBlockID: nil,
            selection: EditorTextSelection(blockID: blockID, location: 0, length: 0)
        )
    )

    XCTAssertEqual(viewModel.visibleBlocks.first?.textPlain, "[[Specs]]开始用块写作。")
    XCTAssertEqual(selection, EditorTextSelection(blockID: blockID, location: 2, length: 5))
    XCTAssertEqual(viewModel.pendingFocusBlockID, blockID)
    viewModel.selectPage(id: targetPage.id)
    XCTAssertEqual(viewModel.selectedPageBacklinks.first?.sourcePageID, sourcePageID)
}
```

- [ ] **Step 3: Run tests to verify red**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/PageRepositoryTests/testInsertInlineInternalBlockLinkStoresStableTargetAndReadableText -only-testing:EditorTests/WorkspaceViewModelTests/testInsertInlineInternalLinkForUIRefreshesBacklinksAndFocus
```

Expected: fail because insertion APIs do not exist.

- [ ] **Step 4: Implement repository insertion**

Add `PageRepository.insertInlineInternalLink`:

```swift
@discardableResult
func insertInlineInternalLink(
    blockID: String,
    targetPageID: String,
    targetBlockID: String?,
    selection: EditorTextSelection
) throws -> EditorTextSelection? {
    guard selection.blockID == blockID else { return nil }
    let source = try blockInlineTextSource(blockID: blockID)
    guard source.type.supportsInlineMarkdownStyling else {
        return nil
    }
    let label = try inlineInternalLinkLabel(targetPageID: targetPageID, targetBlockID: targetBlockID)
    let markdown = "[[\(label)]]"
    let nsText = source.text as NSString
    guard selection.location >= 0,
          selection.length >= 0,
          selection.location <= nsText.length,
          selection.length <= nsText.length - selection.location else {
        return nil
    }
    let nextText = nsText.replacingCharacters(
        in: NSRange(location: selection.location, length: selection.length),
        with: markdown
    )
    var inlineLinks = Self.inlineInternalLinks(payloadJSON: source.payloadJSON)
    inlineLinks.removeAll { $0.label == label }
    inlineLinks.append(InlineInternalLinkTarget(label: label, targetPageID: targetPageID, targetBlockID: targetBlockID))
    try updateBlockText(blockID: blockID, text: nextText, inlineInternalLinks: inlineLinks)
    return EditorTextSelection(blockID: blockID, location: selection.location + 2, length: (label as NSString).length)
}
```

Add these concrete repository helpers in the same extension:

```swift
private struct BlockInlineTextSource {
    let type: BlockType
    let text: String
    let payloadJSON: String
    let isEncrypted: Bool
}

private func blockInlineTextSource(blockID: String) throws -> BlockInlineTextSource {
    let rows = try database.query(
        """
        SELECT blocks.type AS type,
               blocks.payload_json AS payload_json,
               blocks.text_plain AS text_plain,
               pages.is_encrypted AS is_encrypted
        FROM blocks
        INNER JOIN pages ON pages.id = blocks.page_id
        WHERE blocks.id = ? AND blocks.is_deleted = 0
        LIMIT 1
        """,
        bindings: [.text(blockID)]
    )
    guard let row = rows.first else {
        throw PageRepositoryError.blockNotFound
    }
    let isEncrypted = Self.sqliteBool(row["is_encrypted"])
    return BlockInlineTextSource(
        type: BlockType(rawValue: row["type"] ?? "") ?? .paragraph,
        text: try decryptedStoredValue(row["text_plain"] ?? "", isEncrypted: isEncrypted),
        payloadJSON: try decryptedStoredValue(row["payload_json"] ?? "", isEncrypted: isEncrypted),
        isEncrypted: isEncrypted
    )
}

private func inlineInternalLinkLabel(targetPageID: String, targetBlockID: String?) throws -> String {
    let pageRows = try database.query(
        """
        SELECT title, is_encrypted
        FROM pages
        WHERE id = ? AND is_archived = 0
        LIMIT 1
        """,
        bindings: [.text(targetPageID)]
    )
    guard let pageRow = pageRows.first else {
        throw PageRepositoryError.pageNotFound
    }
    let pageTitle = try decryptedStoredValue(
        pageRow["title"] ?? "",
        isEncrypted: Self.sqliteBool(pageRow["is_encrypted"])
    )
    guard let targetBlockID else {
        return pageTitle
    }
    let blockRows = try database.query(
        """
        SELECT blocks.text_plain AS text_plain,
               pages.is_encrypted AS is_encrypted
        FROM blocks
        INNER JOIN pages ON pages.id = blocks.page_id
        WHERE blocks.id = ? AND blocks.page_id = ? AND blocks.is_deleted = 0
        LIMIT 1
        """,
        bindings: [.text(targetBlockID), .text(targetPageID)]
    )
    guard let blockRow = blockRows.first else {
        throw PageRepositoryError.blockNotFound
    }
    let blockText = try decryptedStoredValue(
        blockRow["text_plain"] ?? "",
        isEncrypted: Self.sqliteBool(blockRow["is_encrypted"])
    )
    return "\(pageTitle)#\(blockText)"
}
```

Extend `updateBlockText(blockID:text:)`, `updateBlock(...)`, and `blockPayloadJSON(...)` with an `inlineInternalLinks: [InlineInternalLinkTarget] = []` parameter. Pass that parameter into the payload JSON for text-capable block types, and keep the existing call sites source-compatible through the default argument.

- [ ] **Step 5: Implement view-model insertion**

Add to `WorkspaceViewModel`:

```swift
@discardableResult
func insertInlineInternalLink(
    blockID: String,
    targetPageID: String,
    targetBlockID: String?,
    selection: EditorTextSelection
) throws -> EditorTextSelection? {
    guard let repository,
          let block = snapshot.blocks.first(where: { $0.id == blockID }),
          block.type.supportsInlineMarkdownStyling else {
        return nil
    }
    let nextSelection = try repository.insertInlineInternalLink(
        blockID: blockID,
        targetPageID: targetPageID,
        targetBlockID: targetBlockID,
        selection: selection
    )
    try hydrateBlocksForPageIfNeeded(block.pageID)
    let blocks = try repository.loadBlocks(pageID: block.pageID)
    snapshot = snapshot.replacingBlocks(pageID: block.pageID, blocks: blocks)
    pendingFocusBlockID = blockID
    pendingFocusRequestID = UUID()
    refreshBacklinksForSelectedPage()
    refreshExternalLinksForSelectedPage()
    return nextSelection
}

func insertInlineInternalLinkForUI(
    blockID: String,
    targetPageID: String,
    targetBlockID: String?,
    selection: EditorTextSelection
) -> EditorTextSelection? {
    do {
        return try insertInlineInternalLink(
            blockID: blockID,
            targetPageID: targetPageID,
            targetBlockID: targetBlockID,
            selection: selection
        )
    } catch {
        EditorLog.input.error("inline_internal_link_insert_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)")
        return nil
    }
}
```

- [ ] **Step 6: Run tests to verify green**

Run the same `xcodebuild ... PageRepositoryTests/... WorkspaceViewModelTests/...` command from Step 3.

Expected: pass.

- [ ] **Step 7: Commit Task 3**

```bash
git add Sources/EditorCore/Store/PageRepository.swift Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift Tests/EditorTests/PageRepositoryTests.swift Tests/EditorTests/WorkspaceViewModelTests.swift
git commit -m "Insert stable inline internal links"
```

## Task 4: Anchored Internal-Link Navigation History

**Files:**
- Modify: `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`
- Test: `Tests/EditorTests/WorkspaceViewModelTests.swift`

- [ ] **Step 1: Write failing navigation tests**

Add to `WorkspaceViewModelTests`:

```swift
@MainActor
func testOpenInlineInternalPageLinkRecordsSourceAnchorAndBackRestoresIt() throws {
    let database = try migratedDatabase()
    defer { database.close() }
    let repository = PageRepository(database: database)
    let snapshot = try repository.bootstrapWorkspaceIfNeeded()
    let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
    let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
    let sourceBlockID = try XCTUnwrap(snapshot.blocks.first?.id)
    let targetPage = try repository.createPage(workspaceID: workspaceID, title: "Specs")
    let viewModel = WorkspaceViewModel(repository: repository, backlinkRepository: BacklinkRepository(database: database))
    try viewModel.load()
    viewModel.selectPage(id: sourcePageID)

    XCTAssertTrue(
        viewModel.openInlineInternalLinkForUI(
            sourceBlockID: sourceBlockID,
            targetPageID: targetPage.id,
            targetBlockID: nil,
            sourceSelection: EditorTextSelection(blockID: sourceBlockID, location: 2, length: 0)
        )
    )

    XCTAssertEqual(viewModel.selectedPageID, targetPage.id)
    XCTAssertTrue(try viewModel.navigateBack())
    XCTAssertEqual(viewModel.selectedPageID, sourcePageID)
    XCTAssertEqual(viewModel.pendingFocusBlockID, sourceBlockID)
}

@MainActor
func testOpenInlineInternalBlockLinkQueuesTargetBlockAndForwardRestoresIt() throws {
    let database = try migratedDatabase()
    defer { database.close() }
    let repository = PageRepository(database: database)
    let snapshot = try repository.bootstrapWorkspaceIfNeeded()
    let workspaceID = try XCTUnwrap(snapshot.selectedWorkspaceID)
    let sourcePageID = try XCTUnwrap(snapshot.selectedPageID)
    let sourceBlockID = try XCTUnwrap(snapshot.blocks.first?.id)
    let targetPage = try repository.createPage(workspaceID: workspaceID, title: "Specs")
    let targetBlock = try repository.appendBlock(pageID: targetPage.id, type: .paragraph, text: "API contract")
    let viewModel = WorkspaceViewModel(repository: repository, backlinkRepository: BacklinkRepository(database: database))
    try viewModel.load()
    viewModel.selectPage(id: sourcePageID)

    XCTAssertTrue(
        viewModel.openInlineInternalLinkForUI(
            sourceBlockID: sourceBlockID,
            targetPageID: targetPage.id,
            targetBlockID: targetBlock.id,
            sourceSelection: EditorTextSelection(blockID: sourceBlockID, location: 0, length: 0)
        )
    )

    XCTAssertEqual(viewModel.selectedPageID, targetPage.id)
    XCTAssertEqual(viewModel.pendingFocusBlockID, targetBlock.id)
    XCTAssertTrue(try viewModel.navigateBack())
    XCTAssertEqual(viewModel.pendingFocusBlockID, sourceBlockID)
    XCTAssertTrue(viewModel.navigateForward())
    XCTAssertEqual(viewModel.selectedPageID, targetPage.id)
    XCTAssertEqual(viewModel.pendingFocusBlockID, targetBlock.id)
}
```

- [ ] **Step 2: Run tests to verify red**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/WorkspaceViewModelTests/testOpenInlineInternalPageLinkRecordsSourceAnchorAndBackRestoresIt -only-testing:EditorTests/WorkspaceViewModelTests/testOpenInlineInternalBlockLinkQueuesTargetBlockAndForwardRestoresIt
```

Expected: fail because `openInlineInternalLinkForUI` does not exist and navigation history only stores page plus collection.

- [ ] **Step 3: Extend navigation entry**

Change the private entry in `WorkspaceViewModel.swift`:

```swift
private struct PageNavigationHistoryEntry: Equatable {
    let pageID: String
    let collection: WorkspaceCollection
    let blockID: String?
    let selection: EditorTextSelection?

    init(
        pageID: String,
        collection: WorkspaceCollection,
        blockID: String? = nil,
        selection: EditorTextSelection? = nil
    ) {
        self.pageID = pageID
        self.collection = collection
        self.blockID = blockID
        self.selection = selection
    }
}
```

Add a private restore helper:

```swift
private func restoreNavigationEntry(_ entry: PageNavigationHistoryEntry) {
    selectPage(id: entry.pageID, collection: entry.collection, recordHistory: false)
    guard let blockID = entry.blockID,
          snapshot.blocks.contains(where: { $0.id == blockID }) else {
        return
    }
    pendingFocusBlockID = blockID
    pendingFocusRequestID = UUID()
    if let selection = entry.selection {
        pendingNavigationFocusSelection = selection
    }
}
```

Add the stored-selection bridge beside the existing pending focus properties and consumers:

```swift
@Published private(set) var pendingNavigationFocusSelection: EditorTextSelection?

@discardableResult
func consumePendingNavigationFocusSelection(for blockID: String) -> EditorTextSelection? {
    guard pendingNavigationFocusSelection?.blockID == blockID else {
        return nil
    }
    defer {
        pendingNavigationFocusSelection = nil
    }
    return pendingNavigationFocusSelection
}
```

Wire this through `EditorShellView` where `pendingFocusBlockID` is scheduled. Add a closure parameter to `EditorCanvasView`:

```swift
let onConsumePendingNavigationFocusSelection: (String) -> EditorTextSelection?
```

Pass it from `EditorShellView` as:

```swift
onConsumePendingNavigationFocusSelection: { blockID in
    viewModel.consumePendingNavigationFocusSelection(for: blockID)
}
```

In `setPendingFocusRequest(blockID:reason:)`, use the stored selection when creating the row focus request:

```swift
private func setPendingFocusRequest(
    blockID: String,
    reason: EditorPendingBlockFocusScheduleReason
) {
    let selection = onConsumePendingNavigationFocusSelection(blockID)
    pendingFocusRequest = BlockFocusRequest(blockID: blockID, selection: selection)
    EditorLog.focus.debug("editor_pending_focus_scheduled block_id=\(blockID, privacy: .public)")
}
```

- [ ] **Step 4: Add inline internal link activation API**

Add:

```swift
func openInlineInternalLinkForUI(
    sourceBlockID: String,
    targetPageID: String,
    targetBlockID: String?,
    sourceSelection: EditorTextSelection?
) -> Bool {
    guard snapshot.pages.contains(where: { $0.id == targetPageID }) else {
        EditorLog.render.debug("inline_internal_link_open_failed reason=target_page_unavailable target_page_id=\(targetPageID, privacy: .public)")
        return false
    }
    let sourceEntry = PageNavigationHistoryEntry(
        pageID: selectedPageID ?? snapshot.blocks.first { $0.id == sourceBlockID }?.pageID ?? "",
        collection: selectedCollection,
        blockID: sourceBlockID,
        selection: sourceSelection
    )
    guard !sourceEntry.pageID.isEmpty else { return false }
    pageNavigationBackStack.append(sourceEntry)
    pageNavigationForwardStack.removeAll()
    selectPage(id: targetPageID, collection: defaultCollectionForOpeningPage(id: targetPageID), recordHistory: false)
    pendingCompactPageNavigationID = targetPageID
    if let targetBlockID,
       snapshot.blocks.contains(where: { $0.id == targetBlockID }) {
        pendingFocusBlockID = targetBlockID
        pendingFocusRequestID = UUID()
    }
    EditorLog.render.debug("inline_internal_link_opened target_page_id=\(targetPageID, privacy: .public) target_block_id=\(targetBlockID ?? "none", privacy: .public)")
    return true
}
```

Update `navigateBack()` and `navigateForward()` to call `restoreNavigationEntry(_:)` and to push current entries with current block selection when available.

- [ ] **Step 5: Preserve parent-page fallback**

Keep the existing parent-page fallback at the end of `navigateBack()`. The final branch still calls:

```swift
return try openParentPageForCurrentPage()
```

Only the stack-backed history entries gain anchors.

- [ ] **Step 6: Run focused tests to verify green**

Run the same `xcodebuild ... WorkspaceViewModelTests/...` command from Step 2.

Expected: pass.

- [ ] **Step 7: Commit Task 4**

```bash
git add Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift Tests/EditorTests/WorkspaceViewModelTests.swift
git commit -m "Restore anchors for inline link navigation"
```

## Task 5: Native Text Link Hit Testing And External Opening

**Files:**
- Modify: `Sources/EditorCore/Features/Editing/NativeTextBlockEditor.swift`
- Modify: `Sources/EditorCore/Features/Shell/EditorShellView.swift`
- Test: `Tests/EditorTests/NativeTextBlockEditorTests.swift`
- Test: `Tests/EditorTests/EditorBlockChromeTests.swift`

- [ ] **Step 1: Write failing native resolver tests**

Add to `NativeTextBlockEditorTests`:

```swift
func testNativeInlineLinkResolverFindsInternalWikiLinkAtCharacterIndex() {
    let text = "See [[Specs]] today"
    let activation = NativeInlineLinkActivationResolver.activation(
        text: text,
        characterIndex: ("See [[Spe" as NSString).length
    )

    XCTAssertEqual(
        activation,
        NativeInlineLinkActivation(
            range: NSRange(location: ("See " as NSString).length, length: ("[[Specs]]" as NSString).length),
            destination: .internalLink(label: "Specs", pageTitle: "Specs", blockText: nil)
        )
    )
}

func testNativeInlineLinkResolverFindsExternalURLAtCharacterIndex() {
    let text = "Read [Swift](https://swift.org)"
    let activation = NativeInlineLinkActivationResolver.activation(
        text: text,
        characterIndex: ("Read [Sw" as NSString).length
    )

    XCTAssertEqual(
        activation?.destination,
        .externalURL("https://swift.org")
    )
}

func testNativeInlineLinkResolverIgnoresNonLinkCharacter() {
    XCTAssertNil(
        NativeInlineLinkActivationResolver.activation(
            text: "See [[Specs]] today",
            characterIndex: ("See [[Specs]] to" as NSString).length
        )
    )
}
```

- [ ] **Step 2: Write failing shell wiring test**

Add to `EditorBlockChromeTests` a small closure-capture test around the row/link action seam:

```swift
func testInlineLinkActivationRoutesInternalAndExternalDestinations() {
    var openedInternal: (String, String?)?
    var openedExternal: URL?

    InlineLinkActivationRouter.route(
        .internalLink(targetPageID: "page-specs", targetBlockID: "block-api"),
        openInternal: { pageID, blockID in openedInternal = (pageID, blockID) },
        openExternal: { url in openedExternal = url }
    )

    XCTAssertEqual(openedInternal?.0, "page-specs")
    XCTAssertEqual(openedInternal?.1, "block-api")
    XCTAssertNil(openedExternal)

    InlineLinkActivationRouter.route(
        .externalURL(URL(string: "https://swift.org")!),
        openInternal: { pageID, blockID in openedInternal = (pageID, blockID) },
        openExternal: { url in openedExternal = url }
    )

    XCTAssertEqual(openedExternal?.absoluteString, "https://swift.org")
}
```

- [ ] **Step 3: Run tests to verify red**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/NativeTextBlockEditorTests/testNativeInlineLinkResolverFindsInternalWikiLinkAtCharacterIndex -only-testing:EditorTests/NativeTextBlockEditorTests/testNativeInlineLinkResolverFindsExternalURLAtCharacterIndex -only-testing:EditorTests/NativeTextBlockEditorTests/testNativeInlineLinkResolverIgnoresNonLinkCharacter -only-testing:EditorTests/EditorBlockChromeTests/testInlineLinkActivationRoutesInternalAndExternalDestinations
```

Expected: fail because resolver/router types do not exist.

- [ ] **Step 4: Add resolver types**

In `NativeTextBlockEditor.swift`, near existing keyboard resolver enums, add:

```swift
enum NativeInlineLinkDestination: Equatable, Sendable {
    case internalLink(label: String, pageTitle: String, blockText: String?)
    case externalURL(String)
}

struct NativeInlineLinkActivation: Equatable, Sendable {
    let range: NSRange
    let destination: NativeInlineLinkDestination
}

enum NativeInlineLinkActivationResolver {
    static func activation(text: String, characterIndex: Int) -> NativeInlineLinkActivation? {
        guard characterIndex >= 0 else { return nil }
        guard let run = InlineLinkScanner.link(containing: characterIndex, in: text) else {
            return nil
        }
        switch run.kind {
        case .internalWiki(let label, let pageTitle, let blockText):
            return NativeInlineLinkActivation(
                range: run.fullRange,
                destination: .internalLink(label: label, pageTitle: pageTitle, blockText: blockText)
            )
        case .external(let label, let url):
            return NativeInlineLinkActivation(
                range: run.fullRange,
                destination: .externalURL(url)
            )
        }
    }
}
```

Remove unused local names if the compiler flags them.

- [ ] **Step 5: Wire AppKit and UIKit hit testing**

Add `onInlineLinkActivation: ((NativeInlineLinkActivation, NSRange) -> Bool)?` to `NativeTextBlockEditor` and its platform coordinators/text views.

For AppKit `NSTextView` subclass:

```swift
override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    guard let characterIndex = characterIndex(at: point),
          let activation = NativeInlineLinkActivationResolver.activation(text: string, characterIndex: characterIndex),
          onInlineLinkActivation?(activation, selectedRange()) == true else {
        super.mouseDown(with: event)
        return
    }
}
```

For UIKit `UITextView` subclass, handle a single tap by converting to a character index through the layout manager and call the same closure. Keep `gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:) -> true` so existing cursor and swipe behavior stay available when no link is activated.

- [ ] **Step 6: Add shell router and callbacks**

In `EditorShellView.swift`, add a tiny router:

```swift
enum InlineLinkActivationRoute: Equatable {
    case internalLink(targetPageID: String, targetBlockID: String?)
    case externalURL(URL)
}

enum InlineLinkActivationRouter {
    static func route(
        _ route: InlineLinkActivationRoute,
        openInternal: (String, String?) -> Void,
        openExternal: (URL) -> Void
    ) {
        switch route {
        case .internalLink(let targetPageID, let targetBlockID):
            openInternal(targetPageID, targetBlockID)
        case .externalURL(let url):
            openExternal(url)
        }
    }
}
```

Resolve a native activation by matching its label against `block.inlineInternalLinks`. If the payload metadata is absent, use the parsed page title/block text and call a view-model resolver added in Task 4 or 6. External URLs call `openURL`.

- [ ] **Step 7: Run focused tests to verify green**

Run the same `xcodebuild ... NativeTextBlockEditorTests/... EditorBlockChromeTests/...` command from Step 3.

Expected: pass.

- [ ] **Step 8: Commit Task 5**

```bash
git add Sources/EditorCore/Features/Editing/NativeTextBlockEditor.swift Sources/EditorCore/Features/Shell/EditorShellView.swift Tests/EditorTests/NativeTextBlockEditorTests.swift Tests/EditorTests/EditorBlockChromeTests.swift
git commit -m "Activate inline links from native text"
```

## Task 6: Internal Link Search Chooser And UI Regression Coverage

**Files:**
- Modify: `Sources/EditorCore/Features/Shell/EditorShellView.swift`
- Modify: `Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift`
- Test: `Tests/EditorTests/EditorBlockChromeTests.swift`
- Test: `Tests/EditorMacUITests/EditorMacEditingUITests.swift`
- Test: `Tests/EditorIOSUITests/EditorIOSEditingUITests.swift`

- [ ] **Step 1: Write failing chooser policy tests**

Add to `EditorBlockChromeTests`:

```swift
func testInternalLinkTriggerDetectsOpenWikiPrefixAtCaret() {
    XCTAssertEqual(
        InlineInternalLinkTrigger.query(text: "See [[Spe", selection: EditorTextSelection(blockID: "block", location: ("See [[Spe" as NSString).length, length: 0)),
        "Spe"
    )
    XCTAssertNil(
        InlineInternalLinkTrigger.query(text: "See [[Specs]]", selection: EditorTextSelection(blockID: "block", location: ("See [[Specs]]" as NSString).length, length: 0))
    )
}

func testInternalLinkChoiceBuildsReadableLabels() {
    let page = PageSummary(id: "page-specs", workspaceID: "workspace", title: "Specs")
    let block = BlockSnapshot(id: "block-api", pageID: "page-specs", parentBlockID: nil, orderKey: "000001", type: .paragraph, textPlain: "API contract")

    XCTAssertEqual(InlineInternalLinkChoice.label(page: page, block: nil), "Specs")
    XCTAssertEqual(InlineInternalLinkChoice.label(page: page, block: block), "Specs#API contract")
}
```

- [ ] **Step 2: Write failing macOS UI test**

Add to `EditorMacEditingUITests`:

```swift
func testInlineInternalLinkInsertionNavigationAndBackReturn() {
    let app = launchFreshApp()
    openWelcomePageForPageToolbarActions(in: app)
    let textView = app.textViews["editor.text.block-welcome"]
    XCTAssertTrue(textView.waitForExistence(timeout: 5))

    textView.click()
    textView.typeText(" [[")

    let chooser = app.popovers["editor.inline-internal-link.chooser"]
    XCTAssertTrue(chooser.waitForExistence(timeout: 5))
    let firstResult = chooser.buttons.element(boundBy: 0)
    XCTAssertTrue(firstResult.waitForExistence(timeout: 5))
    firstResult.click()

    XCTAssertTrue(textView.waitForValue(containing: "[[", timeout: 5))
    let inlineLink = app.links.element(matching: NSPredicate(format: "identifier BEGINSWITH %@", "editor.inline-link."))
    XCTAssertTrue(inlineLink.waitForExistence(timeout: 5))
    inlineLink.click()

    app.typeKey("[", modifierFlags: [.command])
    XCTAssertTrue(textView.waitForExistence(timeout: 5))
}
```

Use the repo's existing UI helpers for launching and opening the Welcome page. If `app.links` is not exposed by the native text view, use a stable accessibility element exposed by the overlay/action layer.

- [ ] **Step 3: Run tests to verify red**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/EditorBlockChromeTests/testInternalLinkTriggerDetectsOpenWikiPrefixAtCaret -only-testing:EditorTests/EditorBlockChromeTests/testInternalLinkChoiceBuildsReadableLabels
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorMacUITests -destination 'platform=macOS,arch=arm64' -only-testing:EditorMacUITests/EditorMacEditingUITests/testInlineInternalLinkInsertionNavigationAndBackReturn
```

Expected: unit tests fail because trigger/choice helpers do not exist; UI test fails because there is no inline internal-link chooser or accessible inline link.

- [ ] **Step 4: Add trigger and choice helpers**

In `EditorShellView.swift`, add:

```swift
enum InlineInternalLinkTrigger {
    static func query(text: String, selection: EditorTextSelection) -> String? {
        guard selection.length == 0 else { return nil }
        let nsText = text as NSString
        guard selection.location <= nsText.length else { return nil }
        let prefix = nsText.substring(to: selection.location) as NSString
        let openingRange = prefix.range(of: "[[", options: [.backwards])
        guard openingRange.location != NSNotFound else { return nil }
        let queryLocation = NSMaxRange(openingRange)
        let query = prefix.substring(from: queryLocation)
        guard !query.contains("]]") else { return nil }
        return query
    }
}

struct InlineInternalLinkChoice: Identifiable, Equatable {
    let id: String
    let targetPageID: String
    let targetBlockID: String?
    let title: String
    let subtitle: String

    static func label(page: PageSummary, block: BlockSnapshot?) -> String {
        guard let block else { return page.title }
        let summary = block.textPlain.trimmingCharacters(in: .whitespacesAndNewlines)
        return summary.isEmpty ? page.title : "\(page.title)#\(summary)"
    }
}
```

- [ ] **Step 5: Add chooser state and insertion wiring**

In `EditableBlockRow`, track the current trigger query from `editorSession.textSelection` and show a popover or compact overlay when `InlineInternalLinkTrigger.query(...)` returns a string. Build choices from:

```swift
let pageChoices = pages
    .filter { $0.title.localizedCaseInsensitiveContains(query) }
    .map { InlineInternalLinkChoice(id: "page:\($0.id)", targetPageID: $0.id, targetBlockID: nil, title: $0.title, subtitle: "Page") }

let blockChoices = allBlocks
    .filter { $0.type.isTextEditable && $0.textPlain.localizedCaseInsensitiveContains(query) }
    .compactMap { block -> InlineInternalLinkChoice? in
        guard let page = pages.first(where: { $0.id == block.pageID }) else { return nil }
        return InlineInternalLinkChoice(
            id: "block:\(block.id)",
            targetPageID: page.id,
            targetBlockID: block.id,
            title: block.textPlain,
            subtitle: page.title
        )
    }
```

Selecting a choice calls `onInsertInlineInternalLinkAtSelection(block.id, choice.targetPageID, choice.targetBlockID, selectionForOpenWikiPrefix)`. The replacement selection should cover the typed `[[query` prefix so the inserted text becomes exactly `[[Label]]`.

- [ ] **Step 6: Add page action menu command**

Add a "Internal Link" command next to the existing "Link" command. It opens the same chooser using `mobileInlineFormatSelection` or current desktop selection. Keep `Cmd+K` mapped only to external Markdown links.

- [ ] **Step 7: Add iOS smoke test**

Add an iOS UI smoke test that starts from seeded content with an existing inline internal link, taps it, and asserts compact page navigation changes to the target page. Use accessibility identifiers before coordinates:

```swift
func testInlineInternalLinkTapNavigatesOnIOS() {
    let app = launchFreshApp()
    openWelcomePageForPageToolbarActions(in: app)
    let inlineLink = app.links.element(matching: NSPredicate(format: "identifier BEGINSWITH %@", "editor.inline-link."))
    XCTAssertTrue(inlineLink.waitForExistence(timeout: 5))
    inlineLink.tap()
    XCTAssertTrue(app.otherElements["editor.compact.page"].waitForExistence(timeout: 5))
}
```

- [ ] **Step 8: Run focused UI and policy tests**

Run:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/EditorBlockChromeTests/testInternalLinkTriggerDetectsOpenWikiPrefixAtCaret -only-testing:EditorTests/EditorBlockChromeTests/testInternalLinkChoiceBuildsReadableLabels
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorMacUITests -destination 'platform=macOS,arch=arm64' -only-testing:EditorMacUITests/EditorMacEditingUITests/testInlineInternalLinkInsertionNavigationAndBackReturn
```

Run iOS smoke if the simulator is available:

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorIOSUITests -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:EditorIOSUITests/EditorIOSEditingUITests/testInlineInternalLinkTapNavigatesOnIOS
```

Expected: policy tests and macOS UI test pass. If the iOS simulator is unavailable or locked, record the exact failure and keep the unit/macOS coverage as the checked gate.

- [ ] **Step 9: Commit Task 6**

```bash
git add Sources/EditorCore/Features/Shell/EditorShellView.swift Sources/EditorCore/Features/Shell/WorkspaceViewModel.swift Tests/EditorTests/EditorBlockChromeTests.swift Tests/EditorMacUITests/EditorMacEditingUITests.swift Tests/EditorIOSUITests/EditorIOSEditingUITests.swift
git commit -m "Add inline internal link chooser"
```

## Task 7: Final Regression And Build Gate

**Files:**
- All touched files.

- [ ] **Step 1: Run parser, repository, view-model, native, and chrome tests**

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorTests -destination 'platform=macOS,arch=arm64' -only-testing:EditorTests/MarkdownTransformerTests -only-testing:EditorTests/BacklinkRepositoryTests -only-testing:EditorTests/PageRepositoryTests -only-testing:EditorTests/WorkspaceViewModelTests -only-testing:EditorTests/NativeTextBlockEditorTests -only-testing:EditorTests/EditorBlockChromeTests
```

Expected: pass.

- [ ] **Step 2: Run existing focused UI regressions around links and references**

```bash
xcodebuild -quiet test -project Editor.xcodeproj -scheme EditorMacUITests -destination 'platform=macOS,arch=arm64' -only-testing:EditorMacUITests/EditorMacEditingUITests/testInlineLinkPanelReplacesSelectionAndKeepsLabelSelected -only-testing:EditorMacUITests/EditorMacEditingUITests/testPageActionsMenuUpdatesExistingInlineLinkUnderSelection -only-testing:EditorMacUITests/EditorMacEditingUITests/testPageActionsMenuRemovesExistingInlineLinkUnderSelection -only-testing:EditorMacUITests/EditorMacEditingUITests/testPageReferenceRowClickNavigatesToTargetPageAndMarksSelection -only-testing:EditorMacUITests/EditorMacEditingUITests/testBlockReferenceRowClickNavigatesAndFocusesTargetBlock
```

Expected: pass.

- [ ] **Step 3: Run both platform builds**

```bash
xcodebuild -quiet build -project Editor.xcodeproj -scheme EditorMac -destination 'platform=macOS,arch=arm64'
xcodebuild -quiet build -project Editor.xcodeproj -scheme EditorIOS -destination 'generic/platform=iOS Simulator'
```

Expected: both builds pass.

- [ ] **Step 4: Run diff hygiene**

```bash
git diff --check
git status --short
```

Expected: `git diff --check` prints no output; `git status --short` only shows intentional uncommitted files before the final commit.

- [ ] **Step 5: Commit final verification changes shown by status**

When `git status --short` prints intentional verification changes, commit exactly those files:

```bash
git diff --name-only
git add <paths printed by git diff --name-only>
git commit -m "Stabilize inline link regressions"
```

When `git status --short` prints nothing, record `no final stabilization commit required` in the final implementation report and do not create an empty commit.
