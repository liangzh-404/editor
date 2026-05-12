import Foundation
import XCTest

final class MarkdownTransformerTests: XCTestCase {
    func testShortcutTransformsCoreMarkdownMarkers() {
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "# "),
            MarkdownShortcutTransform(type: .heading1, textPlain: "")
        )
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "- "),
            MarkdownShortcutTransform(type: .unorderedListItem, textPlain: "")
        )
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "> "),
            MarkdownShortcutTransform(type: .quote, textPlain: "")
        )
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "- [ ] "),
            MarkdownShortcutTransform(type: .taskItem, textPlain: "")
        )
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "- [x] "),
            MarkdownShortcutTransform(type: .taskItem, textPlain: "", taskItemIsCompleted: true)
        )
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "---"),
            MarkdownShortcutTransform(type: .divider, textPlain: "")
        )
    }

    func testExportBlocksToMarkdown() {
        let blocks = [
            block(type: .heading1, text: "Title"),
            block(type: .paragraph, text: "Body"),
            block(type: .unorderedListItem, text: "Item"),
            block(type: .quote, text: "Quoted"),
            block(type: .divider, text: "")
        ]

        XCTAssertEqual(
            MarkdownTransformer.export(blocks: blocks),
            """
            # Title

            Body

            - Item

            > Quoted

            ---
            """
        )
    }

    func testImportMarkdownIntoBlockDrafts() {
        XCTAssertEqual(
            MarkdownTransformer.importBlocks(
                markdown:
                    """
                    # Title

                    Body paragraph

                    - Item

                    - [ ] Task

                    > Quote

                    ---
                    """
            ),
            [
                MarkdownBlockDraft(type: .heading1, textPlain: "Title"),
                MarkdownBlockDraft(type: .paragraph, textPlain: "Body paragraph"),
                MarkdownBlockDraft(type: .unorderedListItem, textPlain: "Item"),
                MarkdownBlockDraft(type: .taskItem, textPlain: "Task"),
                MarkdownBlockDraft(type: .quote, textPlain: "Quote"),
                MarkdownBlockDraft(type: .divider, textPlain: "")
            ]
        )
    }

    func testImportMarkdownSupportsCompletedTaskItems() {
        XCTAssertEqual(
            MarkdownTransformer.importBlocks(
                markdown:
                    """
                    - [x] Done

                    - [ ] Todo
                    """
            ),
            [
                MarkdownBlockDraft(type: .taskItem, textPlain: "Done", taskItemIsCompleted: true),
                MarkdownBlockDraft(type: .taskItem, textPlain: "Todo", taskItemIsCompleted: false)
            ]
        )
    }

    func testImportMarkdownSupportsOrderedListsAndFencedCodeBlocks() {
        XCTAssertEqual(
            MarkdownTransformer.importBlocks(
                markdown:
                    """
                    1. First

                    ```
                    let value = 1
                    print(value)
                    ```
                    """
            ),
            [
                MarkdownBlockDraft(type: .orderedListItem, textPlain: "First"),
                MarkdownBlockDraft(
                    type: .codeBlock,
                    textPlain:
                        """
                        let value = 1
                        print(value)
                        """
                )
            ]
        )
    }

    func testImportMarkdownSupportsTableCalloutAndToggleBlocks() {
        XCTAssertEqual(
            MarkdownTransformer.importBlocks(
                markdown:
                    """
                    | Name | Status |
                    | --- | --- |
                    | Editor | Local |

                    > [!NOTE] Keep local first

                    <details><summary>More</summary></details>
                    """
            ),
            [
                MarkdownBlockDraft(
                    type: .table,
                    textPlain:
                        """
                        | Name | Status |
                        | --- | --- |
                        | Editor | Local |
                        """
                ),
                MarkdownBlockDraft(type: .callout, textPlain: "Keep local first"),
                MarkdownBlockDraft(type: .toggle, textPlain: "More")
            ]
        )
    }

    func testImportMarkdownPreservesInlineSyntaxAcrossWrappedParagraphLines() {
        XCTAssertEqual(
            MarkdownTransformer.importBlocks(
                markdown:
                    """
                    This paragraph keeps **bold text**
                    and [a link](https://example.com) with `inline code`.

                    - Separate item
                    """
            ),
            [
                MarkdownBlockDraft(
                    type: .paragraph,
                    textPlain: "This paragraph keeps **bold text** and [a link](https://example.com) with `inline code`."
                ),
                MarkdownBlockDraft(type: .unorderedListItem, textPlain: "Separate item")
            ]
        )
    }

    func testMarkdownInlineLinkComposerTrimsLabelAndRequiresSchemeURL() {
        XCTAssertEqual(
            MarkdownInlineLinkComposer.markdown(label: " Swift ", url: " https://swift.org "),
            "[Swift](https://swift.org)"
        )
        XCTAssertNil(MarkdownInlineLinkComposer.markdown(label: "", url: "https://swift.org"))
        XCTAssertNil(MarkdownInlineLinkComposer.markdown(label: "Swift", url: "swift.org"))
    }

    func testMarkdownInlineLinkInserterReplacesSelectionAndSelectsLabel() throws {
        let result = try XCTUnwrap(
            MarkdownInlineLinkInserter.apply(
                label: "Swift",
                url: "https://swift.org",
                to: "Read docs today",
                selection: EditorTextSelection(blockID: "block-1", location: 5, length: 4)
            )
        )

        XCTAssertEqual(result.text, "Read [Swift](https://swift.org) today")
        XCTAssertEqual(
            result.selection,
            EditorTextSelection(blockID: "block-1", location: 6, length: 5)
        )
    }

    func testMarkdownInlineLinkInserterRejectsInvalidSelectionOrURL() {
        XCTAssertNil(
            MarkdownInlineLinkInserter.apply(
                label: "Swift",
                url: "swift.org",
                to: "Read docs",
                selection: EditorTextSelection(blockID: "block-1", location: 5, length: 4)
            )
        )
        XCTAssertNil(
            MarkdownInlineLinkInserter.apply(
                label: "Swift",
                url: "https://swift.org",
                to: "Read docs",
                selection: EditorTextSelection(blockID: "block-1", location: 40, length: 4)
            )
        )
    }

    func testMarkdownInlineStyleScannerFindsBoldCodeAndLinkLabelRanges() {
        let text = "Use **bold** and `code` from [Swift](https://swift.org)."

        XCTAssertEqual(
            MarkdownInlineStyleScanner.runs(in: text),
            [
                MarkdownInlineStyleRun(
                    kind: .bold,
                    range: NSRange(location: ("Use **" as NSString).length, length: 4)
                ),
                MarkdownInlineStyleRun(
                    kind: .code,
                    range: NSRange(location: ("Use **bold** and `" as NSString).length, length: 4)
                ),
                MarkdownInlineStyleRun(
                    kind: .link,
                    range: NSRange(location: ("Use **bold** and `code` from [" as NSString).length, length: 5)
                )
            ]
        )
    }

    func testMarkdownInlineStyleScannerFindsItalicRange() {
        let text = "Use *italic* and **bold**."

        XCTAssertEqual(
            MarkdownInlineStyleScanner.runs(in: text),
            [
                MarkdownInlineStyleRun(
                    kind: .italic,
                    range: NSRange(location: ("Use *" as NSString).length, length: 6)
                ),
                MarkdownInlineStyleRun(
                    kind: .bold,
                    range: NSRange(location: ("Use *italic* and **" as NSString).length, length: 4)
                )
            ]
        )
    }

    func testMarkdownInlineStyleScannerDoesNotStyleMarkersInsideCodeSpan() {
        let text = "Literal `**not bold**` then **bold**"

        XCTAssertEqual(
            MarkdownInlineStyleScanner.runs(in: text),
            [
                MarkdownInlineStyleRun(
                    kind: .code,
                    range: NSRange(location: ("Literal `" as NSString).length, length: 12)
                ),
                MarkdownInlineStyleRun(
                    kind: .bold,
                    range: NSRange(location: ("Literal `**not bold**` then **" as NSString).length, length: 4)
                )
            ]
        )
    }

    func testMarkdownInlineFormatterWrapsSelectionUsingTextViewRange() {
        let text = "Hi 🧠 Swift"
        let location = ("Hi 🧠 " as NSString).length
        let selection = EditorTextSelection(blockID: "block-1", location: location, length: 5)

        XCTAssertEqual(
            MarkdownInlineFormatter.apply(.bold, to: text, selection: selection),
            "Hi 🧠 **Swift**"
        )
        XCTAssertEqual(
            MarkdownInlineFormatter.apply(
                .code,
                to: "print value",
                selection: EditorTextSelection(blockID: "block-1", location: 0, length: 5)
            ),
            "`print` value"
        )
        XCTAssertEqual(
            MarkdownInlineFormatter.apply(
                .italic,
                to: "Make text stand out",
                selection: EditorTextSelection(blockID: "block-1", location: 5, length: 4)
            ),
            "Make *text* stand out"
        )
    }

    func testMarkdownInlineFormatterReturnsSelectionInsideInsertedMarkers() throws {
        let result = try XCTUnwrap(
            MarkdownInlineFormatter.applyResult(
                .bold,
                to: "Start writing",
                selection: EditorTextSelection(blockID: "block-1", location: 6, length: 7)
            )
        )

        XCTAssertEqual(result.text, "Start **writing**")
        XCTAssertEqual(
            result.selection,
            EditorTextSelection(blockID: "block-1", location: 8, length: 7)
        )
    }

    func testMarkdownInlineFormatterInsertsPlaceholderAtEmptySelection() {
        XCTAssertEqual(
            MarkdownInlineFormatter.apply(
                .bold,
                to: "Start ",
                selection: EditorTextSelection(blockID: "block-1", location: 6, length: 0)
            ),
            "Start **bold**"
        )
        XCTAssertEqual(
            MarkdownInlineFormatter.apply(
                .code,
                to: "",
                selection: EditorTextSelection(blockID: "block-1", location: 0, length: 0)
            ),
            "`code`"
        )
    }

    func testMarkdownInlineFormatterSelectsPlaceholderAfterEmptySelection() throws {
        let result = try XCTUnwrap(
            MarkdownInlineFormatter.applyResult(
                .code,
                to: "Use ",
                selection: EditorTextSelection(blockID: "block-1", location: 4, length: 0)
            )
        )

        XCTAssertEqual(result.text, "Use `code`")
        XCTAssertEqual(
            result.selection,
            EditorTextSelection(blockID: "block-1", location: 5, length: 4)
        )
    }

    func testMarkdownInlineFormatterRejectsInvalidSelectionRange() {
        XCTAssertNil(
            MarkdownInlineFormatter.apply(
                .bold,
                to: "Short",
                selection: EditorTextSelection(blockID: "block-1", location: 6, length: 1)
            )
        )
    }

    func testExportAdvancedBlocksToMarkdownFallbackSyntax() {
        let blocks = [
            block(type: .table, text: "| A | B |\n| --- | --- |\n| 1 | 2 |"),
            block(type: .callout, text: "Important"),
            block(type: .toggle, text: "Details")
        ]

        XCTAssertEqual(
            MarkdownTransformer.export(blocks: blocks),
            """
            | A | B |
            | --- | --- |
            | 1 | 2 |

            > [!NOTE] Important

            <details><summary>Details</summary></details>
            """
        )
    }

    func testExportCompletedTaskItemToMarkdown() {
        XCTAssertEqual(
            MarkdownTransformer.export(
                blocks: [
                    block(type: .taskItem, text: "Done", taskItemIsCompleted: true),
                    block(type: .taskItem, text: "Todo", taskItemIsCompleted: false)
                ]
            ),
            """
            - [x] Done

            - [ ] Todo
            """
        )
    }

    func testMarkdownTableDocumentParsesRowsWithoutSeparator() {
        let table = MarkdownTableDocument(
            markdown:
                """
                | Name | Status |
                | --- | --- |
                | Editor | Local |
                """
        )

        XCTAssertEqual(table.rows, [
            ["Name", "Status"],
            ["Editor", "Local"]
        ])
        XCTAssertEqual(table.columnCount, 2)
    }

    func testMarkdownTableDocumentUpdatesCellAndExportsMarkdownTable() {
        var table = MarkdownTableDocument(
            markdown:
                """
                | Name | Status |
                | --- | --- |
                | Editor | Local |
                """
        )

        table.updateCell(row: 1, column: 1, text: "Synced")

        XCTAssertEqual(
            table.markdown,
            """
            | Name | Status |
            | --- | --- |
            | Editor | Synced |
            """
        )
    }

    func testMarkdownTableDocumentAppendsRowAndColumn() {
        var table = MarkdownTableDocument(
            markdown:
                """
                | Name | Status |
                | --- | --- |
                | Editor | Local |
                """
        )

        table.appendRow()
        table.appendColumn()
        table.updateCell(row: 0, column: 2, text: "Owner")
        table.updateCell(row: 2, column: 0, text: "Notebook")
        table.updateCell(row: 2, column: 1, text: "Draft")
        table.updateCell(row: 2, column: 2, text: "Me")

        XCTAssertEqual(
            table.markdown,
            """
            | Name | Status | Owner |
            | --- | --- | --- |
            | Editor | Local |  |
            | Notebook | Draft | Me |
            """
        )
    }

    func testMarkdownTableDocumentRemovesRowAndColumnButKeepsMinimumCell() {
        var table = MarkdownTableDocument(
            markdown:
                """
                | Name | Status |
                | --- | --- |
                | Editor | Local |
                """
        )

        table.removeLastRow()
        table.removeLastColumn()

        XCTAssertEqual(
            table.markdown,
            """
            | Name |
            | --- |
            """
        )

        table.removeLastRow()
        table.removeLastColumn()

        XCTAssertEqual(
            table.markdown,
            """
            | Name |
            | --- |
            """
        )
    }

    func testExportPageReferenceBlockAsWikiLink() {
        let block = BlockSnapshot(
            id: UUID().uuidString,
            pageID: "page",
            parentBlockID: nil,
            orderKey: "000001",
            type: .pageReference,
            textPlain: "Specs",
            pageReferenceTargetPageID: "page-specs"
        )

        XCTAssertEqual(MarkdownTransformer.export(blocks: [block]), "[[Specs]]")
    }

    func testExportBlockReferenceBlockAsWikiBlockLink() {
        let block = BlockSnapshot(
            id: UUID().uuidString,
            pageID: "page",
            parentBlockID: nil,
            orderKey: "000001",
            type: .blockReference,
            textPlain: "API contract",
            pageReferenceTargetPageID: "page-specs",
            blockReferenceTargetBlockID: "block-specs"
        )

        XCTAssertEqual(MarkdownTransformer.export(blocks: [block]), "[[#API contract]]")
    }

    private func block(
        type: BlockType,
        text: String,
        taskItemIsCompleted: Bool = false
    ) -> BlockSnapshot {
        BlockSnapshot(
            id: UUID().uuidString,
            pageID: "page",
            parentBlockID: nil,
            orderKey: "000001",
            type: type,
            textPlain: text,
            taskItemIsCompleted: taskItemIsCompleted
        )
    }
}
