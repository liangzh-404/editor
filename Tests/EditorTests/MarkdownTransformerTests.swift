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
