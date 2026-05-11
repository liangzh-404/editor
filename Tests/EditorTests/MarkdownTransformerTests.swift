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

    private func block(type: BlockType, text: String) -> BlockSnapshot {
        BlockSnapshot(
            id: UUID().uuidString,
            pageID: "page",
            parentBlockID: nil,
            orderKey: "000001",
            type: type,
            textPlain: text
        )
    }
}
