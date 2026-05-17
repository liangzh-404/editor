import XCTest

final class EditorBlockChromeTests: XCTestCase {
    func testCraftQuietChromeKeepsListRowsUnboxedAndCompact() {
        XCTAssertEqual(EditorBlockChrome.blockSpacing, 0)
        XCTAssertEqual(EditorBlockChrome.rowVerticalPadding, 0)
        XCTAssertEqual(EditorBlockChrome.listVerticalPadding, 0)
        XCTAssertEqual(EditorBlockChrome.listBackgroundOpacity, 0)
        XCTAssertEqual(EditorBlockChrome.listMarkerWidth, 18)
        XCTAssertEqual(EditorBlockChrome.listTextSpacing, 6)
        XCTAssertEqual(EditorBlockChrome.actionColumnWidth, 18)
        XCTAssertEqual(EditorBlockChrome.actionColumnSpacing, 5)
        XCTAssertEqual(EditorBlockChrome.inactiveHandleOpacity, 0)
        XCTAssertEqual(EditorBlockChrome.dropTargetHeight, 32)
        XCTAssertEqual(EditorBlockChrome.dropSlotHeight, 8)
    }

    func testCraftTableChromeUsesEmbeddedDocumentGridMetrics() {
        XCTAssertEqual(TableBlockChrome.cellWidth, 142)
        XCTAssertEqual(TableBlockChrome.cellHeight, 46)
        XCTAssertEqual(TableBlockChrome.maxViewportWidth, 620)
        XCTAssertEqual(TableBlockChrome.cornerRadius, 9)
        XCTAssertEqual(TableBlockChrome.gridLineOpacity, 0.13)
        XCTAssertEqual(TableBlockChrome.outerBorderOpacity, 0.18)
        XCTAssertEqual(TableBlockChrome.primaryControlDiameter, 20)
        XCTAssertEqual(TableBlockChrome.insertControlVisibleDiameter, 4)
        XCTAssertEqual(TableBlockChrome.insertControlExpandedDiameter, 14)
        XCTAssertEqual(TableBlockChrome.selectorIndicatorOpacity, 0)
    }

    func testTableSelectionDeletesRowsAndColumnsButKeepsOneCell() {
        let rows = [
            ["A", "B", "C"],
            ["D", "E", "F"],
            ["G", "H", "I"]
        ]

        XCTAssertEqual(
            TableSelectionReducer.rowsAfterDeletingSelection(
                TableSelection(rows: [1], columns: []),
                from: rows
            ),
            [
                ["A", "B", "C"],
                ["G", "H", "I"]
            ]
        )
        XCTAssertEqual(
            TableSelectionReducer.rowsAfterDeletingSelection(
                TableSelection(rows: [], columns: [0, 2]),
                from: rows
            ),
            [
                ["B"],
                ["E"],
                ["H"]
            ]
        )
        XCTAssertEqual(
            TableSelectionReducer.rowsAfterDeletingSelection(
                TableSelection(rows: [0, 1, 2], columns: []),
                from: rows
            ),
            [[""]]
        )
    }

    func testDropTargetLifecycleClearsWhenEditorReceivesNormalInteraction() {
        let target = BlockDropTarget(blockID: "block-a", placement: .after)

        XCTAssertNil(BlockDropTargetLifecycleReducer.targetAfterEditorInteraction(current: target))
    }

    func testPageReferencePreviewUsesFirstNonEmptyChildBlock() {
        let pageID = "page-child"
        let blocks = [
            BlockSnapshot(id: "empty", pageID: pageID, parentBlockID: nil, orderKey: "a", type: .paragraph, textPlain: "   "),
            BlockSnapshot(id: "preview", pageID: pageID, parentBlockID: nil, orderKey: "b", type: .paragraph, textPlain: "第一行预览"),
            BlockSnapshot(id: "other", pageID: "other-page", parentBlockID: nil, orderKey: "c", type: .paragraph, textPlain: "忽略")
        ]

        XCTAssertEqual(PageReferencePreviewResolver.previewText(targetPageID: pageID, blocks: blocks), "第一行预览")
    }

    func testBlockDropPlacementResolverSupportsIndentedAfterTarget() {
        XCTAssertEqual(
            BlockDropPlacementResolver.placement(
                location: CGPoint(x: 72, y: 20),
                rowSize: CGSize(width: 480, height: 48)
            ),
            .after
        )
        XCTAssertEqual(
            BlockDropPlacementResolver.placement(
                location: CGPoint(x: 128, y: 20),
                rowSize: CGSize(width: 480, height: 48)
            ),
            .after
        )
        XCTAssertEqual(
            BlockDropPlacementResolver.placement(
                location: CGPoint(x: 204, y: 20),
                rowSize: CGSize(width: 480, height: 48)
            ),
            .childAfter
        )
        XCTAssertEqual(
            BlockDropPlacementResolver.placement(
                location: CGPoint(x: 10, y: 20),
                rowSize: CGSize(width: 480, height: 48)
            ),
            .after
        )
        XCTAssertEqual(
            BlockDropPlacementResolver.placement(
                location: CGPoint(x: 10, y: 8),
                rowSize: CGSize(width: 480, height: 48)
            ),
            .before
        )
    }

    func testBlockDragPayloadIncludesIndentedDescendants() {
        let blocks = [
            block(id: "parent", parentBlockID: nil, text: "Parent"),
            block(id: "child", parentBlockID: "parent", text: "Child"),
            block(id: "grandchild", parentBlockID: "child", text: "Grandchild"),
            block(id: "sibling", parentBlockID: nil, text: "Sibling")
        ]

        XCTAssertEqual(
            BlockDragPayloadResolver.payloadBlockIDs(rootBlockID: "parent", blocks: blocks),
            ["parent", "child", "grandchild"]
        )
    }

    func testBlockDragReorderResolverTreatsPayloadAsContiguousGroup() {
        let visibleBlockIDs = ["a", "a-child", "b", "c"]

        XCTAssertEqual(
            BlockDragReorderResolver.targetIndex(
                draggedBlockIDs: ["a", "a-child"],
                destinationBlockID: "c",
                visibleBlockIDs: visibleBlockIDs,
                placement: .after
            ),
            2
        )
        XCTAssertNil(
            BlockDragReorderResolver.targetIndex(
                draggedBlockIDs: ["a", "a-child"],
                destinationBlockID: "a-child",
                visibleBlockIDs: visibleBlockIDs,
                placement: .after
            )
        )
    }

    func testPageListPreviewResolverUsesFirstTextAndAttachmentBlocks() {
        let pageID = "page"
        let image = AttachmentSnapshot(
            id: "attachment-image",
            workspaceID: "workspace",
            originalFilename: "cover.png",
            utiType: "public.png",
            byteSize: 12,
            contentHash: "hash",
            localPath: "/tmp/cover.png",
            thumbnailPath: "/tmp/thumb.png",
            kind: .image
        )
        let file = AttachmentSnapshot(
            id: "attachment-file",
            workspaceID: "workspace",
            originalFilename: "guide.pdf",
            utiType: "com.adobe.pdf",
            byteSize: 42,
            contentHash: "hash2",
            localPath: "/tmp/guide.pdf",
            thumbnailPath: nil,
            kind: .file
        )
        let preview = PageListPreviewResolver.preview(
            pageID: pageID,
            blocks: [
                BlockSnapshot(id: "title", pageID: pageID, parentBlockID: nil, orderKey: "1", type: .heading1, textPlain: "标题不进摘要"),
                BlockSnapshot(id: "text", pageID: pageID, parentBlockID: nil, orderKey: "2", type: .paragraph, textPlain: "这里是正文摘要 #tag"),
                BlockSnapshot(id: "image", pageID: pageID, parentBlockID: nil, orderKey: "3", type: .attachmentImage, textPlain: "cover.png", attachmentID: image.id),
                BlockSnapshot(id: "file", pageID: pageID, parentBlockID: nil, orderKey: "4", type: .attachmentFile, textPlain: "guide.pdf", attachmentID: file.id)
            ],
            attachments: [image, file]
        )

        XCTAssertEqual(preview.excerpt, "这里是正文摘要 #tag")
        XCTAssertEqual(preview.imageAttachment?.id, image.id)
        XCTAssertEqual(preview.fileAttachment?.id, file.id)
    }

    private func block(id: String, parentBlockID: String?, text: String) -> BlockSnapshot {
        BlockSnapshot(
            id: id,
            pageID: "page",
            parentBlockID: parentBlockID,
            orderKey: id,
            type: .paragraph,
            textPlain: text
        )
    }
}
