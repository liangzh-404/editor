import Foundation
import XCTest

final class MarkdownTransformerTests: XCTestCase {
    func testShortcutTransformsCoreMarkdownMarkers() {
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "# "),
            MarkdownShortcutTransform(type: .heading1, textPlain: "")
        )
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "## "),
            MarkdownShortcutTransform(type: .heading2, textPlain: "")
        )
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "### "),
            MarkdownShortcutTransform(type: .heading3, textPlain: "")
        )
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "- "),
            MarkdownShortcutTransform(type: .unorderedListItem, textPlain: "")
        )
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "* "),
            MarkdownShortcutTransform(type: .unorderedListItem, textPlain: "")
        )
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "+ "),
            MarkdownShortcutTransform(type: .unorderedListItem, textPlain: "")
        )
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "2. "),
            MarkdownShortcutTransform(type: .orderedListItem, textPlain: "")
        )
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "10. "),
            MarkdownShortcutTransform(type: .orderedListItem, textPlain: "")
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
            MarkdownTransformer.shortcutTransform(for: "* [ ] "),
            MarkdownShortcutTransform(type: .taskItem, textPlain: "")
        )
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "+ [ ] "),
            MarkdownShortcutTransform(type: .taskItem, textPlain: "")
        )
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "- [x] "),
            MarkdownShortcutTransform(type: .taskItem, textPlain: "", taskItemIsCompleted: true)
        )
        XCTAssertEqual(
            MarkdownTransformer.shortcutTransform(for: "* [X] "),
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
            block(type: .heading2, text: "Section"),
            block(type: .heading3, text: "Detail"),
            block(type: .paragraph, text: "Body"),
            block(type: .unorderedListItem, text: "Item"),
            block(type: .quote, text: "Quoted"),
            block(type: .divider, text: "")
        ]

        XCTAssertEqual(
            MarkdownTransformer.export(blocks: blocks),
            """
            # Title

            ## Section

            ### Detail

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

                    ## Section

                    ### Detail

                    Body paragraph

                    * Item

                    + Next item

                    - [ ] Task

                    * [x] Done

                    > Quote

                    ---
                    """
            ),
            [
                MarkdownBlockDraft(type: .heading1, textPlain: "Title"),
                MarkdownBlockDraft(type: .heading2, textPlain: "Section"),
                MarkdownBlockDraft(type: .heading3, textPlain: "Detail"),
                MarkdownBlockDraft(type: .paragraph, textPlain: "Body paragraph"),
                MarkdownBlockDraft(type: .unorderedListItem, textPlain: "Item"),
                MarkdownBlockDraft(type: .unorderedListItem, textPlain: "Next item"),
                MarkdownBlockDraft(type: .taskItem, textPlain: "Task"),
                MarkdownBlockDraft(type: .taskItem, textPlain: "Done", taskItemIsCompleted: true),
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

                    * [X] Done too

                    + [ ] Todo
                    """
            ),
            [
                MarkdownBlockDraft(type: .taskItem, textPlain: "Done", taskItemIsCompleted: true),
                MarkdownBlockDraft(type: .taskItem, textPlain: "Done too", taskItemIsCompleted: true),
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

    func testImportMarkdownSupportsFencedCodeInfoString() {
        XCTAssertEqual(
            MarkdownTransformer.importBlocks(
                markdown:
                    """
                    ```swift
                    let value = 1
                    print(value)
                    ```
                    """
            ),
            [
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

    func testImportMarkdownSupportsTildeFencedCodeBlocks() {
        XCTAssertEqual(
            MarkdownTransformer.importBlocks(
                markdown:
                    """
                    ~~~python
                    value = 1
                    print(value)
                    ~~~
                    """
            ),
            [
                MarkdownBlockDraft(
                    type: .codeBlock,
                    textPlain:
                        """
                        value = 1
                        print(value)
                        """
                )
            ]
        )
    }

    func testImportMarkdownSupportsSetextHeadings() {
        XCTAssertEqual(
            MarkdownTransformer.importBlocks(
                markdown:
                    """
                    Project Notes
                    ===

                    Section Title
                    ---

                    Body paragraph
                    """
            ),
            [
                MarkdownBlockDraft(type: .heading1, textPlain: "Project Notes"),
                MarkdownBlockDraft(type: .heading2, textPlain: "Section Title"),
                MarkdownBlockDraft(type: .paragraph, textPlain: "Body paragraph")
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

    func testImportMarkdownSupportsTablesWithoutOuterPipes() {
        XCTAssertEqual(
            MarkdownTransformer.importBlocks(
                markdown:
                    """
                    Name | Status
                    --- | ---
                    Editor | Ready
                    """
            ),
            [
                MarkdownBlockDraft(
                    type: .table,
                    textPlain:
                        """
                        Name | Status
                        --- | ---
                        Editor | Ready
                        """
                )
            ]
        )
    }

    func testImportMarkdownSupportsMultilineQuoteAndCalloutBlocks() {
        XCTAssertEqual(
            MarkdownTransformer.importBlocks(
                markdown:
                    """
                    > First quote line
                    > second quote line

                    > [!NOTE] First callout line
                    > second callout line

                    Body
                    """
            ),
            [
                MarkdownBlockDraft(type: .quote, textPlain: "First quote line\nsecond quote line"),
                MarkdownBlockDraft(type: .callout, textPlain: "First callout line\nsecond callout line"),
                MarkdownBlockDraft(type: .paragraph, textPlain: "Body")
            ]
        )
    }

    func testImportMarkdownSupportsPageAndBlockReferenceBlocks() {
        XCTAssertEqual(
            MarkdownTransformer.importBlocks(
                markdown:
                    """
                    [[Specs]]

                    [[#API contract]]
                    """
            ),
            [
                MarkdownBlockDraft(type: .pageReference, textPlain: "Specs"),
                MarkdownBlockDraft(type: .blockReference, textPlain: "API contract")
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

    func testMarkdownInlineLinkRemoverReplacesLinkWithLabelAndSelectsText() throws {
        let text = "Read [Swift](https://swift.org) today"
        let target = try XCTUnwrap(
            MarkdownInlineLinkEditTarget.target(
                in: text,
                selection: EditorTextSelection(
                    blockID: "block-1",
                    location: ("Read [Swift](https://swift" as NSString).length,
                    length: 0
                )
            )
        )

        let result = try XCTUnwrap(MarkdownInlineLinkRemover.apply(to: text, target: target))

        XCTAssertEqual(result.text, "Read Swift today")
        XCTAssertEqual(
            result.selection,
            EditorTextSelection(blockID: "block-1", location: 5, length: 5)
        )
    }

    func testMarkdownInlineLinkEditTargetFindsExistingLinkAroundSelection() throws {
        let text = "Read [Swift](https://swift.org) today"
        let labelSelection = EditorTextSelection(
            blockID: "block-1",
            location: ("Read [Sw" as NSString).length,
            length: 0
        )
        let urlSelection = EditorTextSelection(
            blockID: "block-1",
            location: ("Read [Swift](https://swift" as NSString).length,
            length: 0
        )

        let labelTarget = try XCTUnwrap(
            MarkdownInlineLinkEditTarget.target(in: text, selection: labelSelection)
        )
        let urlTarget = try XCTUnwrap(
            MarkdownInlineLinkEditTarget.target(in: text, selection: urlSelection)
        )

        let expectedReplacementSelection = EditorTextSelection(
            blockID: "block-1",
            location: ("Read " as NSString).length,
            length: ("[Swift](https://swift.org)" as NSString).length
        )
        XCTAssertEqual(labelTarget.label, "Swift")
        XCTAssertEqual(labelTarget.url, "https://swift.org")
        XCTAssertEqual(labelTarget.replacementSelection, expectedReplacementSelection)
        XCTAssertEqual(urlTarget, labelTarget)
    }

    func testMarkdownInlineLinkEditTargetIgnoresImagesAndCodeSpans() {
        let imageText = "Image ![Swift](https://swift.org)"
        let codeText = "Literal `[Swift](https://swift.org)`"

        XCTAssertNil(
            MarkdownInlineLinkEditTarget.target(
                in: imageText,
                selection: EditorTextSelection(
                    blockID: "block-1",
                    location: ("Image ![Swift](https://swift" as NSString).length,
                    length: 0
                )
            )
        )
        XCTAssertNil(
            MarkdownInlineLinkEditTarget.target(
                in: codeText,
                selection: EditorTextSelection(
                    blockID: "block-1",
                    location: ("Literal `[Swift](https://swift" as NSString).length,
                    length: 0
                )
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

    func testMarkdownInlineStyleScannerFindsStrikethroughRangeOutsideCodeSpan() {
        let text = "Use ~~deleted~~ and `~~literal~~`."

        let runs = MarkdownInlineStyleScanner.runs(in: text)

        XCTAssertEqual(
            runs.map { String(describing: $0.kind) },
            ["strikethrough", "code"]
        )
        XCTAssertEqual(
            runs.map(\.range),
            [
                NSRange(location: ("Use ~~" as NSString).length, length: 7),
                NSRange(location: ("Use ~~deleted~~ and `" as NSString).length, length: 11)
            ]
        )
    }

    func testMarkdownInlineStyleScannerCanIncludeSyntaxMarkerRangesForRenderingPolish() {
        let text = "Use **bold**, ~~gone~~, `code`, and [Swift](https://swift.org)."

        let runs = MarkdownInlineStyleScanner.runs(in: text, includingSyntaxMarkers: true)

        XCTAssertEqual(
            runs,
            [
                MarkdownInlineStyleRun(
                    kind: .syntax,
                    range: NSRange(location: ("Use " as NSString).length, length: 2)
                ),
                MarkdownInlineStyleRun(
                    kind: .bold,
                    range: NSRange(location: ("Use **" as NSString).length, length: 4)
                ),
                MarkdownInlineStyleRun(
                    kind: .syntax,
                    range: NSRange(location: ("Use **bold" as NSString).length, length: 2)
                ),
                MarkdownInlineStyleRun(
                    kind: .syntax,
                    range: NSRange(location: ("Use **bold**, " as NSString).length, length: 2)
                ),
                MarkdownInlineStyleRun(
                    kind: .strikethrough,
                    range: NSRange(location: ("Use **bold**, ~~" as NSString).length, length: 4)
                ),
                MarkdownInlineStyleRun(
                    kind: .syntax,
                    range: NSRange(location: ("Use **bold**, ~~gone" as NSString).length, length: 2)
                ),
                MarkdownInlineStyleRun(
                    kind: .syntax,
                    range: NSRange(location: ("Use **bold**, ~~gone~~, " as NSString).length, length: 1)
                ),
                MarkdownInlineStyleRun(
                    kind: .code,
                    range: NSRange(location: ("Use **bold**, ~~gone~~, `" as NSString).length, length: 4)
                ),
                MarkdownInlineStyleRun(
                    kind: .syntax,
                    range: NSRange(location: ("Use **bold**, ~~gone~~, `code" as NSString).length, length: 1)
                ),
                MarkdownInlineStyleRun(
                    kind: .syntax,
                    range: NSRange(location: ("Use **bold**, ~~gone~~, `code`, and " as NSString).length, length: 1)
                ),
                MarkdownInlineStyleRun(
                    kind: .link,
                    range: NSRange(location: ("Use **bold**, ~~gone~~, `code`, and [" as NSString).length, length: 5)
                ),
                MarkdownInlineStyleRun(
                    kind: .syntax,
                    range: NSRange(location: ("Use **bold**, ~~gone~~, `code`, and [Swift" as NSString).length, length: 20)
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

    func testMarkdownInlineFormatterTogglesOffExistingMarkersAroundSelection() throws {
        let result = try XCTUnwrap(
            MarkdownInlineFormatter.applyResult(
                .bold,
                to: "Use **bold** text",
                selection: EditorTextSelection(blockID: "block-1", location: 6, length: 4)
            )
        )

        XCTAssertEqual(result.text, "Use bold text")
        XCTAssertEqual(
            result.selection,
            EditorTextSelection(blockID: "block-1", location: 4, length: 4)
        )
    }

    func testMarkdownInlineFormatterTogglesOffSelectedTextIncludingMarkers() throws {
        let result = try XCTUnwrap(
            MarkdownInlineFormatter.applyResult(
                .bold,
                to: "Use **bold** text",
                selection: EditorTextSelection(blockID: "block-1", location: 4, length: 8)
            )
        )

        XCTAssertEqual(result.text, "Use bold text")
        XCTAssertEqual(
            result.selection,
            EditorTextSelection(blockID: "block-1", location: 4, length: 4)
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

    func testExportMultilineQuoteAndCalloutBlocksPrefixesEveryLine() {
        let blocks = [
            block(type: .quote, text: "First quote line\nsecond quote line"),
            block(type: .callout, text: "First callout line\nsecond callout line")
        ]

        XCTAssertEqual(
            MarkdownTransformer.export(blocks: blocks),
            """
            > First quote line
            > second quote line

            > [!NOTE] First callout line
            > second callout line
            """
        )
    }

    func testExportTableBlockUsesStructuredRowsWhenAvailable() {
        let blocks = [
            block(
                type: .table,
                text: "stale table text",
                tableRows: [["Name", "Status"], ["Editor", "Draft"]]
            )
        ]

        XCTAssertEqual(
            MarkdownTransformer.export(blocks: blocks),
            """
            | Name | Status |
            | --- | --- |
            | Editor | Draft |
            """
        )
    }

    func testExportAttachmentBlockUsesManagedRelativePathWhenAttachmentMetadataAvailable() {
        let attachment = AttachmentSnapshot(
            id: "attachment-photo",
            workspaceID: "workspace-local",
            originalFilename: "photo.png",
            utiType: "public.png",
            byteSize: 12,
            contentHash: "hash",
            localPath: "/tmp/photo.png",
            thumbnailPath: nil,
            kind: .image
        )
        let block = block(
            type: .attachmentImage,
            text: "photo.png",
            attachmentID: attachment.id
        )

        XCTAssertEqual(
            MarkdownTransformer.export(blocks: [block], attachments: [attachment]),
            "![photo.png](Attachments/attachment-photo/photo.png)"
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
        taskItemIsCompleted: Bool = false,
        tableRows: [[String]] = [],
        attachmentID: String? = nil
    ) -> BlockSnapshot {
        BlockSnapshot(
            id: UUID().uuidString,
            pageID: "page",
            parentBlockID: nil,
            orderKey: "000001",
            type: type,
            textPlain: text,
            taskItemIsCompleted: taskItemIsCompleted,
            tableRows: tableRows,
            attachmentID: attachmentID
        )
    }
}
