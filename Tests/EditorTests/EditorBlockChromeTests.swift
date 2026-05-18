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
        XCTAssertEqual(EditorBlockChrome.trailingInsertHitHeight, 28)
    }

    func testCraftTableChromeUsesEmbeddedDocumentGridMetrics() {
        XCTAssertEqual(TableBlockChrome.cellWidth, 136)
        XCTAssertEqual(TableBlockChrome.cellHeight, 42)
        XCTAssertEqual(TableBlockChrome.maxViewportWidth, 620)
        XCTAssertEqual(TableBlockChrome.cornerRadius, 8)
        XCTAssertEqual(TableBlockChrome.gridLineOpacity, 0.035)
        XCTAssertEqual(TableBlockChrome.outerBorderOpacity, 0.075)
        XCTAssertEqual(TableBlockChrome.primaryControlDiameter, 18)
        XCTAssertEqual(TableBlockChrome.insertControlVisibleDiameter, 2.5)
        XCTAssertEqual(TableBlockChrome.insertControlExpandedDiameter, 8)
        XCTAssertEqual(TableBlockChrome.insertControlIconFontSize, 5)
        XCTAssertEqual(TableBlockChrome.insertControlEdgeOffset, 5)
        XCTAssertEqual(TableBlockChrome.selectorWidth, 8)
        XCTAssertEqual(TableBlockChrome.selectorHeight, 8)
        XCTAssertEqual(TableBlockChrome.selectorIndicatorOpacity, 0)
        XCTAssertEqual(TableBlockChrome.selectorHitOpacity, 0.0001)
        XCTAssertEqual(TableBlockChrome.selectorSelectedIndicatorOpacity, 0.42)
        XCTAssertEqual(TableBlockChrome.selectorSelectedIndicatorThickness, 2)
        XCTAssertEqual(TableBlockChrome.selectorSelectedIndicatorInset, 9)
    }

    func testTableInsertControlChromeKeepsExpandedPlusInsideGridEdge() {
        let centerInsetFromEdge = TableBlockChrome.primaryControlDiameter / 2
            - TableBlockChrome.insertControlEdgeOffset
        let expandedRadius = TableBlockChrome.insertControlExpandedDiameter / 2

        XCTAssertGreaterThanOrEqual(
            centerInsetFromEdge,
            expandedRadius,
            "Hovered table insert controls should not be clipped halfway outside the table edge"
        )
    }

    func testTableSelectionChromeKeepsIdleSelectorsInvisibleButSelectedFeedbackVisible() {
        XCTAssertLessThan(
            TableBlockChrome.selectorHitOpacity,
            0.001,
            "Idle row and column selectors should stay quiet instead of showing permanent bars"
        )
        XCTAssertEqual(
            TableBlockChrome.selectorIndicatorOpacity,
            0,
            "Idle selector indicators should be hidden until a row or column is selected"
        )
        XCTAssertGreaterThan(
            TableBlockChrome.selectorSelectedIndicatorOpacity,
            0.4,
            "Selected rows and columns need a visible edge cue so border selection does not feel invisible"
        )
        XCTAssertLessThanOrEqual(
            TableBlockChrome.selectorSelectedIndicatorThickness,
            2,
            "Selected edge feedback should stay Craft-like and avoid heavy table bars"
        )
    }

    func testMobileBlockSwipeResolverSeparatesSelectionFromIndenting() {
        XCTAssertEqual(
            MobileBlockSwipeActionResolver.action(
                translation: CGSize(width: -72, height: 8),
                isEditingBlock: false,
                nestingLevel: 0
            ),
            .select
        )
        XCTAssertEqual(
            MobileBlockSwipeActionResolver.action(
                translation: CGSize(width: 72, height: 6),
                isEditingBlock: false,
                nestingLevel: 0
            ),
            .indent
        )
        XCTAssertEqual(
            MobileBlockSwipeActionResolver.action(
                translation: CGSize(width: 72, height: 6),
                isEditingBlock: true,
                nestingLevel: 1
            ),
            .indent
        )
        XCTAssertEqual(
            MobileBlockSwipeActionResolver.action(
                translation: CGSize(width: -72, height: 6),
                isEditingBlock: true,
                nestingLevel: 1
            ),
            .outdent
        )
        XCTAssertEqual(
            MobileBlockSwipeActionResolver.action(
                translation: CGSize(width: -72, height: 6),
                isEditingBlock: true,
                nestingLevel: 0
            ),
            .select
        )
        XCTAssertNil(
            MobileBlockSwipeActionResolver.action(
                translation: CGSize(width: -40, height: 6),
                isEditingBlock: false,
                nestingLevel: 0
            )
        )
        XCTAssertNil(
            MobileBlockSwipeActionResolver.action(
                translation: CGSize(width: 72, height: 72),
                isEditingBlock: false,
                nestingLevel: 0
            )
        )
    }

    func testMobileBlockSelectionReducerAddsAndTogglesBlocks() {
        XCTAssertEqual(
            MobileBlockSelectionReducer.selectionAfterSelecting(
                blockID: "block-b",
                current: ["block-a"]
            ),
            ["block-a", "block-b"]
        )
        XCTAssertEqual(
            MobileBlockSelectionReducer.selectionAfterSelecting(
                blockID: "block-a",
                current: ["block-a", "block-b"]
            ),
            ["block-b"]
        )
        XCTAssertEqual(
            MobileBlockSelectionReducer.selectionAfterSelecting(
                blockID: "block-a",
                current: []
            ),
            ["block-a"]
        )
    }

    func testMobileBlockSelectionChromeShowsSelectableCirclesInSelectionMode() {
        XCTAssertFalse(
            MobileBlockSelectionChromeResolver.isSelectionControlVisible(
                isSelectionModeActive: false
            )
        )
        XCTAssertTrue(
            MobileBlockSelectionChromeResolver.isSelectionControlVisible(
                isSelectionModeActive: true
            )
        )
        XCTAssertEqual(
            MobileBlockSelectionChromeResolver.symbolName(isSelected: false),
            "circle"
        )
        XCTAssertEqual(
            MobileBlockSelectionChromeResolver.symbolName(isSelected: true),
            "checkmark.circle.fill"
        )
    }

    func testMobileBlockSelectionBatchResolverKeepsVisibleDocumentOrder() {
        XCTAssertEqual(
            MobileBlockSelectionBatchResolver.orderedBlockIDs(
                selectedBlockIDs: ["third", "first", "missing"],
                visibleBlockIDs: ["first", "second", "third"]
            ),
            ["first", "third"]
        )
        XCTAssertEqual(
            MobileBlockSelectionBatchResolver.orderedBlockIDs(
                selectedBlockIDs: ["missing"],
                visibleBlockIDs: ["first", "second", "third"]
            ),
            []
        )
    }

    func testCompactInitialNavigationResolverStartsOnSelectedPageWhenAvailable() {
        XCTAssertEqual(
            CompactInitialNavigationResolver.initialPageID(
                selectedPageID: "recent-page",
                availablePageIDs: ["recent-page", "older-page"]
            ),
            "recent-page"
        )
        XCTAssertNil(
            CompactInitialNavigationResolver.initialPageID(
                selectedPageID: "missing-page",
                availablePageIDs: ["recent-page", "older-page"]
            )
        )
        XCTAssertEqual(
            CompactInitialNavigationResolver.initialPageID(
                selectedPageID: nil,
                availablePageIDs: ["recent-page", "older-page"]
            ),
            "recent-page"
        )
        XCTAssertNil(
            CompactInitialNavigationResolver.initialPageID(
                selectedPageID: nil,
                availablePageIDs: []
            )
        )
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

    func testSidebarNavigationModelShowsRecentCountsAndTagCounts() {
        let workspaceID = "workspace"
        let pages = [
            PageSummary(id: "page-recent", workspaceID: workspaceID, title: "最近文件"),
            PageSummary(id: "page-diary", workspaceID: workspaceID, title: "2026年5月18日 星期一"),
            PageSummary(id: "page-favorite", workspaceID: workspaceID, title: "收藏文件", isFavorite: true)
        ]
        let tags = [
            TagSummary(id: "tag-work", workspaceID: workspaceID, parentTagID: nil, name: "工作", path: "工作"),
            TagSummary(id: "tag-life", workspaceID: workspaceID, parentTagID: nil, name: "生活", path: "生活")
        ]
        let snapshot = WorkspaceSnapshot(
            workspaces: [WorkspaceSummary(id: workspaceID, name: "空间")],
            pages: pages,
            blocks: [],
            attachments: [],
            tags: tags,
            pageTags: [
                PageTagAssignment(pageID: "page-recent", tagID: "tag-work"),
                PageTagAssignment(pageID: "page-favorite", tagID: "tag-work"),
                PageTagAssignment(pageID: "page-diary", tagID: "tag-life")
            ],
            diaryPages: [
                DiaryPageSnapshot(pageID: "page-diary", workspaceID: workspaceID, diaryDate: "2026-05-18")
            ],
            selectedWorkspaceID: workspaceID,
            selectedPageID: "page-recent"
        )

        let model = SidebarNavigationModel(snapshot: snapshot, selectedCollection: .recent)

        XCTAssertEqual(
            model.primaryItems.map(\.title),
            ["近期文件", "全部文档", "日记", "收藏"]
        )
        XCTAssertEqual(model.primaryItems.map(\.count), [3, 2, 1, 1])
        XCTAssertEqual(model.primaryItems.first?.identifier, "editor.collection.recent")
        XCTAssertEqual(model.primaryItems.first?.isSelected, true)
        XCTAssertEqual(model.tagItems.map(\.title), ["工作", "生活"])
        XCTAssertEqual(model.tagItems.map(\.count), [2, 1])
    }

    func testSidebarChromeUsesCompactBearLikeRailMetrics() {
        XCTAssertEqual(SidebarChrome.horizontalPadding, 10)
        XCTAssertEqual(SidebarChrome.verticalPadding, 12)
        XCTAssertEqual(SidebarChrome.sectionSpacing, 10)
        XCTAssertEqual(SidebarChrome.rowSpacing, 3)
        XCTAssertEqual(SidebarChrome.rowCornerRadius, 14)
        XCTAssertEqual(SidebarChrome.rowVerticalPadding, 9)
        XCTAssertEqual(SidebarChrome.nestedItemIndent, 18)
        XCTAssertEqual(SidebarChrome.dividerOpacity, 0.07)
        XCTAssertEqual(SidebarChrome.selectedFillOpacity, 0.70)
        XCTAssertEqual(SidebarChrome.selectedStrokeOpacity, 0.025)
        XCTAssertEqual(SidebarChrome.headerBadgeSize, 30)
        XCTAssertEqual(SidebarChrome.headerBadgeCornerRadius, 8)
    }

    func testCompactLibraryNavigationRoutesRowsByCollectionAndIncludesDiary() {
        let workspaceID = "workspace"
        let snapshot = WorkspaceSnapshot(
            workspaces: [WorkspaceSummary(id: workspaceID, name: "空间")],
            pages: [
                PageSummary(id: "page-a", workspaceID: workspaceID, title: "A"),
                PageSummary(id: "page-diary", workspaceID: workspaceID, title: "2026年5月18日 星期一"),
                PageSummary(id: "page-favorite", workspaceID: workspaceID, title: "收藏", isFavorite: true)
            ],
            blocks: [],
            attachments: [],
            diaryPages: [
                DiaryPageSnapshot(pageID: "page-diary", workspaceID: workspaceID, diaryDate: "2026-05-18")
            ],
            selectedWorkspaceID: workspaceID,
            selectedPageID: "page-a"
        )

        let items = CompactLibraryNavigationModel.items(snapshot: snapshot)

        XCTAssertEqual(items.map(\.title), ["全部文档", "日记", "收藏"])
        XCTAssertEqual(items.map(\.collection), [.allDocuments, .diary, .favorites])
        XCTAssertEqual(items.map(\.count), [2, 1, 1])
        XCTAssertEqual(items.map(\.route), [.collection(.allDocuments), .collection(.diary), .collection(.favorites)])

        XCTAssertEqual(
            CompactCollectionPageListModel.pages(snapshot: snapshot, collection: .allDocuments).map(\.id),
            ["page-a", "page-favorite"]
        )
        XCTAssertEqual(
            CompactCollectionPageListModel.pages(snapshot: snapshot, collection: .diary).map(\.id),
            ["page-diary"]
        )
        XCTAssertEqual(
            CompactCollectionPageListModel.pages(snapshot: snapshot, collection: .favorites).map(\.id),
            ["page-favorite"]
        )
    }

    func testCompactCollectionPageListItemsIncludePreviewAndTags() {
        let workspaceID = "workspace"
        let page = PageSummary(
            id: "page-a",
            workspaceID: workspaceID,
            title: "带预览的文档",
            isFavorite: true
        )
        let tag = TagSummary(
            id: "tag-life",
            workspaceID: workspaceID,
            parentTagID: nil,
            name: "生活",
            path: "生活"
        )
        let snapshot = WorkspaceSnapshot(
            workspaces: [WorkspaceSummary(id: workspaceID, name: "空间")],
            pages: [page],
            blocks: [
                BlockSnapshot(
                    id: "block-text",
                    pageID: page.id,
                    parentBlockID: nil,
                    orderKey: "1",
                    type: .paragraph,
                    textPlain: "这是一段用于列表预览的正文"
                )
            ],
            attachments: [],
            tags: [tag],
            pageTags: [PageTagAssignment(pageID: page.id, tagID: tag.id)],
            selectedWorkspaceID: workspaceID,
            selectedPageID: page.id
        )

        let items = CompactCollectionPageListModel.items(
            snapshot: snapshot,
            collection: .favorites
        )

        XCTAssertEqual(items.map(\.page.id), [page.id])
        XCTAssertEqual(items.first?.tagNames, ["生活"])
        XCTAssertEqual(items.first?.preview.excerpt, "这是一段用于列表预览的正文")
    }

    func testPastedAttachmentAnchorPrefersTextSelectionThenFocusedBlockThenLastVisibleSelection() {
        let visibleBlockIDs = ["first", "middle", "last"]

        XCTAssertEqual(
            PastedAttachmentAnchorResolver.anchorBlockID(
                textSelection: EditorTextSelection(blockID: "middle", location: 0, length: 0),
                focusedBlockID: "first",
                selectedBlockIDs: ["last"],
                visibleBlockIDs: visibleBlockIDs
            ),
            "middle"
        )
        XCTAssertEqual(
            PastedAttachmentAnchorResolver.anchorBlockID(
                textSelection: nil,
                focusedBlockID: "middle",
                selectedBlockIDs: ["last"],
                visibleBlockIDs: visibleBlockIDs
            ),
            "middle"
        )
        XCTAssertEqual(
            PastedAttachmentAnchorResolver.anchorBlockID(
                textSelection: nil,
                focusedBlockID: nil,
                selectedBlockIDs: ["first", "last"],
                visibleBlockIDs: visibleBlockIDs
            ),
            "last"
        )
        XCTAssertNil(
            PastedAttachmentAnchorResolver.anchorBlockID(
                textSelection: nil,
                focusedBlockID: "missing",
                selectedBlockIDs: ["also-missing"],
                visibleBlockIDs: visibleBlockIDs
            )
        )
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
