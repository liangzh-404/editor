import Foundation
import XCTest

final class NativeTextBlockEditorTests: XCTestCase {
    @MainActor
    func testNativeTextBlockEditorKeepsBlockIdentityAndInitialText() {
        let session = EditorSession()
        let editor = NativeTextBlockEditor(
            blockID: "block-1",
            text: "Hello",
            blockType: .paragraph,
            session: session,
            onTextChange: { _ in }
        )

        XCTAssertEqual(editor.blockID, "block-1")
        XCTAssertEqual(editor.text, "Hello")
        XCTAssertEqual(editor.blockType, .paragraph)
    }

    @MainActor
    func testNativeTextBlockEditorKeepsLineWrappingConfiguration() {
        let session = EditorSession()
        let editor = NativeTextBlockEditor(
            blockID: "block-1",
            text: "let value = 1",
            blockType: .codeBlock,
            session: session,
            lineWrapping: false,
            onTextChange: { _ in }
        )

        XCTAssertFalse(editor.lineWrapping)
    }

    @MainActor
    func testNativeTextBlockEditorShowsPlaceholderForEmptyUnfocusedBlock() {
        let session = EditorSession()
        let editor = NativeTextBlockEditor(
            blockID: "block-1",
            text: "",
            blockType: .paragraph,
            session: session,
            onTextChange: { _ in }
        )

        XCTAssertTrue(editor.showsPlaceholder)

        session.beginEditing(blockID: "block-1", reason: .programmatic)
        let focusedEditor = NativeTextBlockEditor(
            blockID: "block-1",
            text: "",
            blockType: .paragraph,
            session: session,
            onTextChange: { _ in }
        )
        XCTAssertFalse(focusedEditor.showsPlaceholder)

        let editorWithText = NativeTextBlockEditor(
            blockID: "block-1",
            text: "Already editable",
            blockType: .paragraph,
            session: session,
            onTextChange: { _ in }
        )
        XCTAssertFalse(editorWithText.showsPlaceholder)
    }

    func testNativeFocusRequestStateRetriesUntilFocusSucceeds() {
        let requestID = UUID()
        var state = NativeTextFocusRequestState()

        XCTAssertEqual(state.beginScheduling(requestID), requestID)
        state.finish(requestID: requestID, didFocus: false)

        XCTAssertEqual(state.beginScheduling(requestID), requestID)
        state.finish(requestID: requestID, didFocus: true)

        XCTAssertNil(state.beginScheduling(requestID))
    }

    func testNativeTextModelUpdateGuardSuppressesProgrammaticTextChangeForwarding() {
        var guardState = NativeTextModelUpdateGuard()

        XCTAssertTrue(guardState.shouldForwardTextChange)

        guardState.beginApplyingModelText()
        XCTAssertFalse(guardState.shouldForwardTextChange)

        guardState.finishApplyingModelText()
        XCTAssertTrue(guardState.shouldForwardTextChange)
    }

    func testNativeTextFocusSelectionUsesValidRequestedSelectionRange() {
        let range = NativeTextFocusSelection.range(
            from: EditorTextSelection(blockID: "block-1", location: 3, length: 2),
            blockID: "block-1",
            text: "Hello"
        )

        XCTAssertEqual(range, NSRange(location: 3, length: 2))
    }

    func testNativeTextFocusSelectionFallsBackToTextEndForInvalidSelection() {
        XCTAssertEqual(
            NativeTextFocusSelection.range(
                from: EditorTextSelection(blockID: "other", location: 1, length: 1),
                blockID: "block-1",
                text: "Hi 🧠"
            ),
            NSRange(location: ("Hi 🧠" as NSString).length, length: 0)
        )
        XCTAssertEqual(
            NativeTextFocusSelection.range(
                from: EditorTextSelection(blockID: "block-1", location: 20, length: 1),
                blockID: "block-1",
                text: "Short"
            ),
            NSRange(location: 5, length: 0)
        )
    }

    @MainActor
    func testNativeTextBlockEditorAcceptsInactiveWindowFirstMouseOnMac() {
#if os(macOS)
        XCTAssertTrue(NativeTextBlockEditor.acceptsInactiveWindowFirstMouse)
#endif
    }

    func testNativeTextMouseFocusPolicyMakesWindowKeyBeforeFocusingTextViewOnMac() {
#if os(macOS)
        XCTAssertTrue(NativeTextMouseFocusPolicy.makesWindowKeyBeforeFirstResponder)
#endif
    }

    func testMacWindowVisibilityPolicyRequestsMainWindowWhenNoneVisible() {
#if os(macOS)
        XCTAssertTrue(MacWindowVisibilityPolicy.shouldRequestMainWindow(hasVisibleWindows: false))
        XCTAssertFalse(MacWindowVisibilityPolicy.shouldRequestMainWindow(hasVisibleWindows: true))
#endif
    }

    func testBlockKeyboardShortcutResolverHandlesCommandOptionArrowsOnly() {
        XCTAssertEqual(
            BlockKeyboardShortcutResolver.moveDirection(
                keyCode: BlockKeyboardShortcutResolver.upArrowKeyCode,
                modifiers: [.command, .option]
            ),
            .up
        )
        XCTAssertEqual(
            BlockKeyboardShortcutResolver.moveDirection(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [.command, .option]
            ),
            .down
        )
        XCTAssertNil(
            BlockKeyboardShortcutResolver.moveDirection(
                keyCode: BlockKeyboardShortcutResolver.upArrowKeyCode,
                modifiers: [.command]
            )
        )
        XCTAssertNil(
            BlockKeyboardShortcutResolver.moveDirection(
                keyCode: 0,
                modifiers: [.command, .option]
            )
        )
    }

    func testBlockKeyboardShortcutResolverHandlesReturnAsInsertBlockOnlyWithoutModifiers() {
        XCTAssertTrue(
            BlockKeyboardShortcutResolver.insertsBlockAfter(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: []
            )
        )
        XCTAssertFalse(
            BlockKeyboardShortcutResolver.insertsBlockAfter(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: [.shift]
            )
        )
        XCTAssertFalse(
            BlockKeyboardShortcutResolver.insertsBlockAfter(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: [.command]
            )
        )
    }

    func testBlockKeyboardShortcutResolverHandlesTabIndentAndShiftTabOutdent() {
        XCTAssertEqual(
            BlockKeyboardShortcutResolver.indentationDirection(
                keyCode: BlockKeyboardShortcutResolver.tabKeyCode,
                modifiers: []
            ),
            .indent
        )
        XCTAssertEqual(
            BlockKeyboardShortcutResolver.indentationDirection(
                keyCode: BlockKeyboardShortcutResolver.tabKeyCode,
                modifiers: [.shift]
            ),
            .outdent
        )
        XCTAssertNil(
            BlockKeyboardShortcutResolver.indentationDirection(
                keyCode: BlockKeyboardShortcutResolver.tabKeyCode,
                modifiers: [.command]
            )
        )
        XCTAssertNil(
            BlockKeyboardShortcutResolver.indentationDirection(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: []
            )
        )
    }

    func testBlockKeyboardFocusResolverMovesOnlyAtTextBoundaries() {
        XCTAssertEqual(
            BlockKeyboardFocusResolver.focusDirection(
                keyCode: BlockKeyboardShortcutResolver.upArrowKeyCode,
                modifiers: [],
                selectedRange: NSRange(location: 0, length: 0),
                text: "First line"
            ),
            .previous
        )
        XCTAssertEqual(
            BlockKeyboardFocusResolver.focusDirection(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [],
                selectedRange: NSRange(location: ("Last line" as NSString).length, length: 0),
                text: "Last line"
            ),
            .next
        )
        XCTAssertNil(
            BlockKeyboardFocusResolver.focusDirection(
                keyCode: BlockKeyboardShortcutResolver.upArrowKeyCode,
                modifiers: [],
                selectedRange: NSRange(location: 2, length: 0),
                text: "Middle"
            )
        )
        XCTAssertNil(
            BlockKeyboardFocusResolver.focusDirection(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [.shift],
                selectedRange: NSRange(location: 6, length: 0),
                text: "Middle"
            )
        )
        XCTAssertNil(
            BlockKeyboardFocusResolver.focusDirection(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [],
                selectedRange: NSRange(location: 0, length: 2),
                text: "Selected"
            )
        )
    }

    func testBlockKeyboardFocusResolverTargetsAdjacentEditableBlocks() {
        let blocks = [
            BlockSnapshot(
                id: "heading",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "a",
                type: .heading1,
                textPlain: "Heading"
            ),
            BlockSnapshot(
                id: "divider",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "b",
                type: .divider,
                textPlain: ""
            ),
            BlockSnapshot(
                id: "paragraph",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "c",
                type: .paragraph,
                textPlain: "Paragraph"
            )
        ]

        XCTAssertEqual(
            BlockKeyboardFocusResolver.target(
                currentBlockID: "paragraph",
                direction: .previous,
                blocks: blocks
            ),
            BlockKeyboardFocusTarget(
                blockID: "heading",
                selection: EditorTextSelection(
                    blockID: "heading",
                    location: ("Heading" as NSString).length,
                    length: 0
                )
            )
        )
        XCTAssertEqual(
            BlockKeyboardFocusResolver.target(
                currentBlockID: "heading",
                direction: .next,
                blocks: blocks
            ),
            BlockKeyboardFocusTarget(
                blockID: "paragraph",
                selection: EditorTextSelection(
                    blockID: "paragraph",
                    location: 0,
                    length: 0
                )
            )
        )
        XCTAssertNil(
            BlockKeyboardFocusResolver.target(
                currentBlockID: "heading",
                direction: .previous,
                blocks: blocks
            )
        )
        XCTAssertNil(
            BlockKeyboardFocusResolver.target(
                currentBlockID: "paragraph",
                direction: .next,
                blocks: blocks
            )
        )
    }

    func testQuoteBlockChromeDescriptorExposesSemanticContainer() {
        let block = BlockSnapshot(
            id: "quote-1",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "a",
            type: .quote,
            textPlain: "Quoted text"
        )

        let descriptor = QuoteBlockChromeDescriptor(block: block)

        XCTAssertEqual(descriptor.accessibilityLabel, "Quote block")
        XCTAssertEqual(descriptor.accessibilityValue, "Quoted text")
        XCTAssertEqual(descriptor.accessibilityIdentifier, "editor.quote.quote-1")
    }

    func testListBlockChromeDescriptorExposesSemanticContainersAndMarkers() {
        let unorderedBlock = BlockSnapshot(
            id: "unordered-1",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "a",
            type: .unorderedListItem,
            textPlain: "Bulleted text"
        )
        let orderedBlock = BlockSnapshot(
            id: "ordered-3",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "b",
            type: .orderedListItem,
            textPlain: "Numbered text"
        )

        let unorderedDescriptor = ListBlockChromeDescriptor(block: unorderedBlock, ordinal: nil)
        let orderedDescriptor = ListBlockChromeDescriptor(block: orderedBlock, ordinal: 3)

        XCTAssertEqual(unorderedDescriptor.marker, "•")
        XCTAssertEqual(unorderedDescriptor.accessibilityLabel, "Bulleted list block")
        XCTAssertEqual(unorderedDescriptor.accessibilityValue, "Bulleted text")
        XCTAssertEqual(unorderedDescriptor.accessibilityIdentifier, "editor.unordered-list.unordered-1")

        XCTAssertEqual(orderedDescriptor.marker, "3.")
        XCTAssertEqual(orderedDescriptor.accessibilityLabel, "Numbered list block")
        XCTAssertEqual(orderedDescriptor.accessibilityValue, "Numbered text")
        XCTAssertEqual(orderedDescriptor.accessibilityIdentifier, "editor.ordered-list.ordered-3")
    }

    func testOrderedListOrdinalResolverCountsContiguousSameParentItems() {
        let intro = BlockSnapshot(
            id: "intro",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "a",
            type: .paragraph,
            textPlain: "Intro"
        )
        let first = BlockSnapshot(
            id: "ordered-1",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "b",
            type: .orderedListItem,
            textPlain: "First"
        )
        let firstChild = BlockSnapshot(
            id: "ordered-1-child",
            pageID: "page",
            parentBlockID: "ordered-1",
            orderKey: "c",
            type: .paragraph,
            textPlain: "Nested detail"
        )
        let second = BlockSnapshot(
            id: "ordered-2",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "d",
            type: .orderedListItem,
            textPlain: "Second"
        )
        let breakBlock = BlockSnapshot(
            id: "break",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "e",
            type: .paragraph,
            textPlain: "Break"
        )
        let restarted = BlockSnapshot(
            id: "ordered-restart",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "f",
            type: .orderedListItem,
            textPlain: "Restart"
        )
        let blocks = [intro, first, firstChild, second, breakBlock, restarted]

        XCTAssertEqual(ListBlockOrdinalResolver.ordinal(for: first, at: 1, in: blocks), 1)
        XCTAssertEqual(ListBlockOrdinalResolver.ordinal(for: second, at: 3, in: blocks), 2)
        XCTAssertEqual(ListBlockOrdinalResolver.ordinal(for: restarted, at: 5, in: blocks), 1)
        XCTAssertNil(ListBlockOrdinalResolver.ordinal(for: intro, at: 0, in: blocks))
    }

    func testHeadingBlockChromeDescriptorExposesSemanticHeadingLevels() {
        let heading1 = BlockSnapshot(
            id: "heading-1",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "a",
            type: .heading1,
            textPlain: "Main heading"
        )
        let heading2 = BlockSnapshot(
            id: "heading-2",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "b",
            type: .heading2,
            textPlain: ""
        )
        let heading3 = BlockSnapshot(
            id: "heading-3",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "c",
            type: .heading3,
            textPlain: "Detail heading"
        )

        let heading1Descriptor = HeadingBlockChromeDescriptor(block: heading1)
        let heading2Descriptor = HeadingBlockChromeDescriptor(block: heading2)
        let heading3Descriptor = HeadingBlockChromeDescriptor(block: heading3)

        XCTAssertEqual(heading1Descriptor.level, 1)
        XCTAssertEqual(heading1Descriptor.accessibilityLabel, "Heading 1 block")
        XCTAssertEqual(heading1Descriptor.accessibilityValue, "Main heading")
        XCTAssertEqual(heading1Descriptor.accessibilityIdentifier, "editor.heading1.heading-1")

        XCTAssertEqual(heading2Descriptor.level, 2)
        XCTAssertEqual(heading2Descriptor.accessibilityLabel, "Heading 2 block")
        XCTAssertEqual(heading2Descriptor.accessibilityValue, "Empty")
        XCTAssertEqual(heading2Descriptor.accessibilityIdentifier, "editor.heading2.heading-2")

        XCTAssertEqual(heading3Descriptor.level, 3)
        XCTAssertEqual(heading3Descriptor.accessibilityLabel, "Heading 3 block")
        XCTAssertEqual(heading3Descriptor.accessibilityValue, "Detail heading")
        XCTAssertEqual(heading3Descriptor.accessibilityIdentifier, "editor.heading3.heading-3")
    }

    func testMarkdownInlineFormatKeyboardResolverHandlesBoldItalicStrikethroughAndCodeShortcutsOnly() {
        XCTAssertEqual(
            MarkdownInlineFormatKeyboardResolver.format(input: "b", modifiers: [.command]),
            .bold
        )
        XCTAssertEqual(
            MarkdownInlineFormatKeyboardResolver.format(input: "B", modifiers: [.command]),
            .bold
        )
        XCTAssertEqual(
            MarkdownInlineFormatKeyboardResolver.format(input: "i", modifiers: [.command]),
            .italic
        )
        XCTAssertEqual(
            MarkdownInlineFormatKeyboardResolver.format(input: "x", modifiers: [.command, .shift]),
            .strikethrough
        )
        XCTAssertEqual(
            MarkdownInlineFormatKeyboardResolver.format(input: "e", modifiers: [.command]),
            .code
        )
        XCTAssertEqual(
            MarkdownInlineFormatKeyboardResolver.format(input: "E", modifiers: [.command]),
            .code
        )
        XCTAssertNil(
            MarkdownInlineFormatKeyboardResolver.format(input: "b", modifiers: [.command, .option])
        )
        XCTAssertNil(
            MarkdownInlineFormatKeyboardResolver.format(input: "x", modifiers: [.command])
        )
        XCTAssertNil(
            MarkdownInlineFormatKeyboardResolver.format(input: "e", modifiers: [.command, .shift])
        )
        XCTAssertNil(
            MarkdownInlineFormatKeyboardResolver.format(input: "c", modifiers: [.command])
        )
        XCTAssertNil(
            MarkdownInlineFormatKeyboardResolver.format(input: nil, modifiers: [.command])
        )
    }

    func testMarkdownInlineLinkKeyboardResolverHandlesCommandKOnly() {
        XCTAssertTrue(
            MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(input: "k", modifiers: [.command])
        )
        XCTAssertTrue(
            MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(input: "K", modifiers: [.command])
        )
        XCTAssertFalse(
            MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(input: "k", modifiers: [.command, .option])
        )
        XCTAssertFalse(
            MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(input: "b", modifiers: [.command])
        )
        XCTAssertFalse(
            MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(input: nil, modifiers: [.command])
        )
    }

    func testDiaryPromotionKeyboardResolverHandlesCommandRightBracketOnly() {
        XCTAssertTrue(
            DiaryPromotionKeyboardResolver.requestsPromotion(
                input: "]",
                modifiers: [.command]
            )
        )
        XCTAssertFalse(
            DiaryPromotionKeyboardResolver.requestsPromotion(
                input: "]",
                modifiers: []
            )
        )
        XCTAssertFalse(
            DiaryPromotionKeyboardResolver.requestsPromotion(
                input: "[",
                modifiers: [.command]
            )
        )
    }

    func testBlockDragReorderResolverMovesBeforeDestinationBlock() {
        let visibleBlockIDs = ["a", "b", "c"]

        XCTAssertEqual(
            BlockDragReorderResolver.targetIndex(
                draggedBlockID: "a",
                destinationBlockID: "c",
                visibleBlockIDs: visibleBlockIDs
            ),
            1
        )
        XCTAssertEqual(
            BlockDragReorderResolver.targetIndex(
                draggedBlockID: "c",
                destinationBlockID: "a",
                visibleBlockIDs: visibleBlockIDs
            ),
            0
        )
        XCTAssertNil(
            BlockDragReorderResolver.targetIndex(
                draggedBlockID: "b",
                destinationBlockID: "c",
                visibleBlockIDs: visibleBlockIDs
            )
        )
    }

    func testNotebookHierarchyComputesNestingAndSiblingMovePositions() {
        let notebooks = [
            NotebookSummary(id: "root-a", workspaceID: "workspace", name: "Root A"),
            NotebookSummary(id: "parent", workspaceID: "workspace", name: "Parent"),
            NotebookSummary(
                id: "child-a",
                workspaceID: "workspace",
                parentNotebookID: "parent",
                name: "Child A"
            ),
            NotebookSummary(
                id: "child-b",
                workspaceID: "workspace",
                parentNotebookID: "parent",
                name: "Child B"
            ),
            NotebookSummary(id: "root-b", workspaceID: "workspace", name: "Root B")
        ]

        XCTAssertEqual(
            NotebookHierarchy.nestingLevel(for: notebooks[2], in: notebooks),
            1
        )
        XCTAssertFalse(NotebookHierarchy.canMoveUp(notebook: notebooks[2], in: notebooks))
        XCTAssertTrue(NotebookHierarchy.canMoveDown(notebook: notebooks[2], in: notebooks))
        XCTAssertEqual(
            NotebookHierarchy.siblingTargetIndex(
                for: notebooks[3],
                direction: .up,
                in: notebooks
            ),
            0
        )
        XCTAssertEqual(
            NotebookHierarchy.siblingTargetIndex(
                for: notebooks[1],
                direction: .down,
                in: notebooks
            ),
            2
        )
    }

    func testBlockDragReorderResolverMovesToEndRegion() {
        let visibleBlockIDs = ["a", "b", "c"]

        XCTAssertEqual(
            BlockDragReorderResolver.endTargetIndex(
                draggedBlockID: "a",
                visibleBlockIDs: visibleBlockIDs
            ),
            2
        )
        XCTAssertNil(
            BlockDragReorderResolver.endTargetIndex(
                draggedBlockID: "c",
                visibleBlockIDs: visibleBlockIDs
            )
        )
    }

    func testEditorCanvasRenderMetricsSummarizeRenderWorkload() {
        let metrics = EditorCanvasRenderMetrics(
            pageID: "page-1",
            blockCount: 1_000,
            attachmentCount: 3,
            backlinkCount: 2,
            conflictCount: 1
        )

        XCTAssertEqual(metrics.pageID, "page-1")
        XCTAssertEqual(metrics.blockCount, 1_000)
        XCTAssertEqual(metrics.attachmentCount, 3)
        XCTAssertEqual(metrics.backlinkCount, 2)
        XCTAssertEqual(metrics.conflictCount, 1)
        XCTAssertTrue(metrics.isLargePage)
        XCTAssertTrue(EditorCanvasRenderPolicy.usesLazyBlockStack)
    }

    func testEditorCanvasScrollMetricsTrackVisibleBlocksAndLargePageState() {
        var tracker = EditorCanvasScrollMetricsTracker(
            pageID: "page-1",
            blockCount: 1_000,
            nowNanoseconds: 10_000_000
        )

        tracker.blockAppeared("a", index: 0, nowNanoseconds: 20_000_000)
        tracker.blockAppeared("b", index: 4, nowNanoseconds: 40_000_000)
        tracker.blockAppeared("b", index: 4, nowNanoseconds: 60_000_000)
        tracker.blockDisappeared("a", nowNanoseconds: 80_000_000)

        XCTAssertEqual(
            tracker.metrics,
            EditorCanvasScrollMetrics(
                pageID: "page-1",
                blockCount: 1_000,
                visibleBlockCount: 1,
                peakVisibleBlockCount: 2,
                firstVisibleBlockIndex: 4,
                lastVisibleBlockIndex: 4,
                peakVisibleBlockIndexSpan: 5,
                scrollLifetimeMilliseconds: 70,
                blockAppearanceCount: 3,
                blockDisappearanceCount: 1
            )
        )
        XCTAssertTrue(tracker.metrics.isLargePage)
    }

    func testEditorCanvasScrollMetricsCaptureVisibleIndexWindow() {
        var tracker = EditorCanvasScrollMetricsTracker(pageID: "page-1", blockCount: 1_000)

        tracker.blockAppeared("a", index: 12)
        tracker.blockAppeared("b", index: 13)
        tracker.blockAppeared("c", index: 20)

        XCTAssertEqual(tracker.metrics.firstVisibleBlockIndex, 12)
        XCTAssertEqual(tracker.metrics.lastVisibleBlockIndex, 20)
        XCTAssertEqual(tracker.metrics.visibleBlockIndexSpan, 9)
        XCTAssertEqual(tracker.metrics.peakVisibleBlockIndexSpan, 9)

        tracker.blockDisappeared("c")

        XCTAssertEqual(tracker.metrics.firstVisibleBlockIndex, 12)
        XCTAssertEqual(tracker.metrics.lastVisibleBlockIndex, 13)
        XCTAssertEqual(tracker.metrics.visibleBlockIndexSpan, 2)
        XCTAssertEqual(tracker.metrics.peakVisibleBlockIndexSpan, 9)
    }

    func testEditorCanvasScrollMetricsCaptureLifecycleChurnSummary() {
        var tracker = EditorCanvasScrollMetricsTracker(
            pageID: "page-1",
            blockCount: 760,
            nowNanoseconds: 1_000_000_000
        )

        tracker.blockAppeared("a", index: 0, nowNanoseconds: 1_010_000_000)
        tracker.blockAppeared("b", index: 79, nowNanoseconds: 1_050_000_000)
        tracker.blockDisappeared("a", nowNanoseconds: 1_100_000_000)

        let metrics = tracker.metrics
        XCTAssertEqual(metrics.scrollLifetimeMilliseconds, 100)
        XCTAssertEqual(metrics.blockAppearanceCount, 2)
        XCTAssertEqual(metrics.blockDisappearanceCount, 1)
        XCTAssertEqual(metrics.visibleBlockChurnCount, 3)
        XCTAssertTrue(metrics.runtimeSummary.contains("scroll_lifetime_ms=100.000"))
        XCTAssertTrue(metrics.runtimeSummary.contains("block_appearance_count=2"))
        XCTAssertTrue(metrics.runtimeSummary.contains("block_disappearance_count=1"))
        XCTAssertTrue(metrics.runtimeSummary.contains("visible_block_churn_count=3"))
    }
}
