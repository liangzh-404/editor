import XCTest

final class EditorBlockChromeTests: XCTestCase {
    func testCraftThingsDesignTokensMatchDesktopEditorialPalette() {
        assertColor(EditorDesignTokens.Colors.appBackground, red: 0xF7, green: 0xF7, blue: 0xF5)
        assertColor(EditorDesignTokens.Colors.sidebarBackground, red: 0xF2, green: 0xF2, blue: 0xEF)
        assertColor(EditorDesignTokens.Colors.documentListBackground, red: 0xF8, green: 0xF8, blue: 0xF6)
        assertColor(EditorDesignTokens.Colors.editorBackground, red: 0xFF, green: 0xFF, blue: 0xFF)
        assertColor(EditorDesignTokens.Colors.primaryText, red: 0x22, green: 0x21, blue: 0x1F)
        assertColor(EditorDesignTokens.Colors.secondaryText, red: 0x5F, green: 0x61, blue: 0x66)
        assertColor(EditorDesignTokens.Colors.tertiaryText, red: 0x8B, green: 0x8D, blue: 0x91)
        assertColor(EditorDesignTokens.Colors.border, red: 0xE6, green: 0xE5, blue: 0xE1)
        assertColor(EditorDesignTokens.Colors.accent, red: 0xE5, green: 0x45, blue: 0x4F)
    }

    func testDarkDesignTokensProvideLayeredReadableEditorialPalette() {
        assertColor(EditorDesignTokens.Colors.appBackground, scheme: .dark, red: 0x15, green: 0x15, blue: 0x14)
        assertColor(EditorDesignTokens.Colors.sidebarBackground, scheme: .dark, red: 0x1D, green: 0x1B, blue: 0x19)
        assertColor(EditorDesignTokens.Colors.documentListBackground, scheme: .dark, red: 0x18, green: 0x18, blue: 0x17)
        assertColor(EditorDesignTokens.Colors.editorBackground, scheme: .dark, red: 0x10, green: 0x11, blue: 0x11)
        assertColor(EditorDesignTokens.Colors.primaryText, scheme: .dark, red: 0xEF, green: 0xED, blue: 0xEA)
        assertColor(EditorDesignTokens.Colors.secondaryText, scheme: .dark, red: 0xB8, green: 0xB2, blue: 0xAA)
        assertColor(EditorDesignTokens.Colors.tertiaryText, scheme: .dark, red: 0x81, green: 0x7C, blue: 0x73)
        assertColor(EditorDesignTokens.Colors.border, scheme: .dark, red: 0x37, green: 0x32, blue: 0x2C)
        assertColor(EditorDesignTokens.Colors.accent, scheme: .dark, red: 0xFF, green: 0x63, blue: 0x6E)
        XCTAssertNotEqual(
            EditorDesignTokens.Colors.documentListBackground.components(for: .dark),
            EditorDesignTokens.Colors.editorBackground.components(for: .dark)
        )
        XCTAssertGreaterThan(EditorDesignTokens.Colors.primaryText.components(for: .dark).red, 0.85)
        XCTAssertLessThan(EditorDesignTokens.Colors.editorBackground.components(for: .dark).red, 0.08)
    }

    func testDarkModeSemanticSurfacesCoverEditorSpecialCases() {
        assertColor(EditorDesignTokens.Colors.elevatedSurface, scheme: .dark, red: 0x20, green: 0x1F, blue: 0x1D)
        assertColor(EditorDesignTokens.Colors.controlBackground, scheme: .dark, red: 0x26, green: 0x24, blue: 0x21)
        assertColor(EditorDesignTokens.Colors.codeBlockBackground, scheme: .dark, red: 0x1A, green: 0x1C, blue: 0x1E)
        assertColor(EditorDesignTokens.Colors.calloutBackground, scheme: .dark, red: 0x1B, green: 0x20, blue: 0x26)
        assertColor(EditorDesignTokens.Colors.quoteBackground, scheme: .dark, red: 0x23, green: 0x20, blue: 0x1B)
        assertColor(EditorDesignTokens.Colors.attachmentBackground, scheme: .dark, red: 0x1B, green: 0x1D, blue: 0x1F)
        assertColor(EditorDesignTokens.Colors.tableHeaderBackground, scheme: .dark, red: 0x21, green: 0x20, blue: 0x1E)
        assertColor(EditorDesignTokens.Colors.drawingCanvasBackground, scheme: .dark, red: 0x18, green: 0x19, blue: 0x1A)
        assertColor(EditorDesignTokens.Colors.inlineCodeBackground, scheme: .dark, red: 0x27, green: 0x25, blue: 0x22)
        assertColor(EditorDesignTokens.Colors.searchHighlightFill, scheme: .dark, red: 0xF4, green: 0xBC, blue: 0x44)
        assertColor(EditorDesignTokens.Colors.searchHighlightStroke, scheme: .dark, red: 0xFF, green: 0xD1, blue: 0x63)
        assertColor(EditorDesignTokens.Colors.warningText, scheme: .dark, red: 0xFF, green: 0xB8, blue: 0x4D)
        assertColor(EditorDesignTokens.Colors.warningFill, scheme: .dark, red: 0x33, green: 0x25, blue: 0x13)
        assertColor(EditorDesignTokens.Colors.warningStroke, scheme: .dark, red: 0x7A, green: 0x58, blue: 0x22)
        assertColor(EditorDesignTokens.Colors.successText, scheme: .dark, red: 0x7F, green: 0xDA, blue: 0x8A)
        assertColor(EditorDesignTokens.Colors.successFill, scheme: .dark, red: 0x14, green: 0x28, blue: 0x1A)
        assertColor(EditorDesignTokens.Colors.dangerFill, scheme: .dark, red: 0x32, green: 0x18, blue: 0x1C)
    }

    func testCraftThingsDesignTokensKeepDocumentTypographyInRange() {
        XCTAssertEqual(EditorDesignTokens.Typography.documentTitleSize, 28)
        XCTAssertEqual(EditorDesignTokens.Typography.bodySize, 14)
        XCTAssertEqual(EditorDesignTokens.Typography.bodyLineHeightMultiple, 1.34)
        XCTAssertEqual(EditorDesignTokens.Layout.editorMaxWidth, 560)
        XCTAssertEqual(EditorDesignTokens.Layout.editorExpandedMaxWidth, 560)
    }

    func testPopoverShadowTokensStayLightAndWarmNeutral() {
        XCTAssertEqual(EditorDesignTokens.Shadows.popoverLarge.opacity, 0.10)
        XCTAssertEqual(EditorDesignTokens.Shadows.popoverLarge.radius, 48)
        XCTAssertEqual(EditorDesignTokens.Shadows.popoverLarge.y, 16)
        XCTAssertEqual(EditorDesignTokens.Shadows.popoverSmall.opacity, 0.06)
        XCTAssertEqual(EditorDesignTokens.Shadows.popoverSmall.radius, 8)
        XCTAssertEqual(EditorDesignTokens.Shadows.popoverSmall.y, 2)
    }

    func testSecondRoundComponentHierarchyTokensMatchCraftThingsDensity() {
        XCTAssertEqual(EditorDesignTokens.Layout.sidebarMinWidth, 240)
        XCTAssertEqual(EditorDesignTokens.Layout.sidebarIdealWidth, 288)
        XCTAssertEqual(EditorDesignTokens.Layout.sidebarMaxWidth, 360)
        XCTAssertEqual(EditorDesignTokens.Layout.documentListMinWidth, 300)
        XCTAssertEqual(EditorDesignTokens.Layout.documentListIdealWidth, 360)
        XCTAssertEqual(EditorDesignTokens.Layout.documentListMaxWidth, 460)
        XCTAssertEqual(EditorDesignTokens.Layout.documentListRowMinHeight, 72)
        XCTAssertEqual(EditorDesignTokens.Layout.documentListSelectedAccentWidth, 3)
        XCTAssertEqual(EditorDesignTokens.Layout.pageLinkCornerRadius, 13)
        XCTAssertEqual(EditorDesignTokens.Layout.slashMenuWidth, 380)
        XCTAssertEqual(EditorDesignTokens.Layout.slashMenuRowHeight, 48)
        XCTAssertEqual(EditorDesignTokens.Layout.slashMenuCornerRadius, 14)
        XCTAssertEqual(EditorDesignTokens.Layout.auxiliaryRailWidth, 285)
    }

    func testEditorCanvasChromeKeepsContentCloseToPhoneEdges() {
        XCTAssertEqual(EditorCanvasChromeLayout.compactHorizontalPadding, 14)
#if os(iOS)
        XCTAssertEqual(EditorCanvasChromeLayout.horizontalPadding, EditorCanvasChromeLayout.compactHorizontalPadding)
        XCTAssertEqual(EditorCanvasChromeLayout.verticalPadding, 18)
        XCTAssertEqual(EditorCanvasChromeLayout.pageTitleLeadingPadding, 27)
#else
        XCTAssertEqual(EditorCanvasChromeLayout.horizontalPadding, 34)
        XCTAssertEqual(EditorCanvasChromeLayout.verticalPadding, 36)
        XCTAssertEqual(EditorCanvasChromeLayout.pageTitleLeadingPadding, 27)
        XCTAssertEqual(EditorCanvasChromeLayout.blockRowTitleAlignmentCompensation, 0)
#endif
    }

    func testMobileNavigationBarChromeKeepsCollapsedTitleVerticallyCentered() {
        XCTAssertEqual(MobileNavigationBarChrome.topMaskHeight, 72)
        XCTAssertEqual(MobileNavigationBarChrome.collapsedTitleVerticalOffset, 0)
    }

    func testCompactIOSPageActionsMenuHidesDesktopAndTransferActions() {
        let hiddenCommands: [PageActionsMenuCommand] = [
            .writingMode,
            .focusMode,
            .importMarkdown,
            .importObsidian,
            .exportMarkdown
        ]
        hiddenCommands.forEach { command in
            XCTAssertFalse(
                PageActionsMenuVisibilityPolicy.isVisible(command, in: .compactIOS),
                "\(command) should stay out of the compact iOS page actions menu"
            )
        }

        XCTAssertTrue(PageActionsMenuVisibilityPolicy.isVisible(.addParagraphBlock, in: .compactIOS))
        XCTAssertTrue(PageActionsMenuVisibilityPolicy.isVisible(.attachment, in: .compactIOS))
        XCTAssertTrue(PageActionsMenuVisibilityPolicy.isVisible(.bold, in: .compactIOS))
        XCTAssertTrue(PageActionsMenuVisibilityPolicy.isVisible(.undoTextEdit, in: .compactIOS))
    }

    func testRegularPageActionsMenuKeepsDesktopAndTransferActions() {
        XCTAssertTrue(PageActionsMenuVisibilityPolicy.isVisible(.writingMode, in: .regular))
        XCTAssertTrue(PageActionsMenuVisibilityPolicy.isVisible(.focusMode, in: .regular))
        XCTAssertTrue(PageActionsMenuVisibilityPolicy.isVisible(.importMarkdown, in: .regular))
        XCTAssertTrue(PageActionsMenuVisibilityPolicy.isVisible(.importObsidian, in: .regular))
        XCTAssertTrue(PageActionsMenuVisibilityPolicy.isVisible(.exportMarkdown, in: .regular))
    }

    func testPageActionsDefersLargeReferenceTargetMenus() {
        XCTAssertEqual(
            PageActionsReferencePresentationPolicy.presentation(
                targetCount: PageActionsReferencePresentationPolicy.compactInlineTargetLimit,
                scope: .compactIOS
            ),
            .inlineMenu
        )
        XCTAssertEqual(
            PageActionsReferencePresentationPolicy.presentation(
                targetCount: PageActionsReferencePresentationPolicy.compactInlineTargetLimit + 1,
                scope: .compactIOS
            ),
            .deferredPicker
        )
        XCTAssertEqual(
            PageActionsReferencePresentationPolicy.presentation(
                targetCount: PageActionsReferencePresentationPolicy.regularInlineTargetLimit,
                scope: .regular
            ),
            .inlineMenu
        )
        XCTAssertEqual(
            PageActionsReferencePresentationPolicy.presentation(
                targetCount: PageActionsReferencePresentationPolicy.regularInlineTargetLimit + 1,
                scope: .regular
            ),
            .deferredPicker
        )
    }

    func testPageVersionDiffBuilderComparesHistoricalSnapshotWithCurrentPage() {
        let version = PageVersionSnapshot(
            pageID: "page-1",
            title: "Old title",
            pageCreatedAt: "2026-05-24T01:00:00.000Z",
            pageUpdatedAt: "2026-05-24T01:05:00.000Z",
            capturedAt: "2026-05-24T01:10:00.000Z",
            blocks: [
                PageVersionBlockSnapshot(
                    id: "block-1",
                    pageID: "page-1",
                    parentBlockID: nil,
                    orderKey: "a",
                    typeRawValue: BlockType.paragraph.rawValue,
                    textPlain: "Old body",
                    payloadJSON: "{}"
                ),
                PageVersionBlockSnapshot(
                    id: "block-2",
                    pageID: "page-1",
                    parentBlockID: nil,
                    orderKey: "b",
                    typeRawValue: BlockType.paragraph.rawValue,
                    textPlain: "Shared",
                    payloadJSON: "{}"
                )
            ]
        )
        let currentPage = PageSummary(
            id: "page-1",
            workspaceID: "workspace-1",
            title: "New title"
        )
        let currentBlocks = [
            BlockSnapshot(
                id: "block-1",
                pageID: "page-1",
                parentBlockID: nil,
                orderKey: "a",
                type: .paragraph,
                textPlain: "New body"
            ),
            BlockSnapshot(
                id: "block-2",
                pageID: "page-1",
                parentBlockID: nil,
                orderKey: "b",
                type: .paragraph,
                textPlain: "Shared"
            )
        ]

        let lines = PageVersionDiffBuilder.lines(
            version: version,
            currentPage: currentPage,
            currentBlocks: currentBlocks
        )

        XCTAssertEqual(lines.map(\.kind), [.removed, .added, .removed, .added, .unchanged])
        XCTAssertEqual(lines.map(\.text), ["标题：Old title", "标题：New title", "Old body", "New body", "Shared"])
    }

    func testPageTitleDisplayPolicyUsesPlaceholderOnlyForEmptyDisplaySurfaces() {
        XCTAssertEqual(PageTitleDisplayPolicy.emptyTitlePlaceholder, "未命名")
        XCTAssertEqual(PageTitleDisplayPolicy.listTitle(for: ""), "未命名")
        XCTAssertEqual(PageTitleDisplayPolicy.listTitle(for: "   "), "未命名")
        XCTAssertEqual(PageTitleDisplayPolicy.listTitle(for: "真实标题"), "真实标题")
        XCTAssertEqual(PageTitleDisplayPolicy.editingText(for: ""), "")
        XCTAssertEqual(PageTitleDisplayPolicy.editingText(for: "真实标题"), "真实标题")
    }

    func testSearchHighlightOverlayPolicyMapsVisionRectsOntoDisplayedImage() {
        let rects = SearchHighlightOverlayPolicy.displayRects(
            highlightRects: [
                SearchResultHighlightRect(x: 0.10, y: 0.20, width: 0.30, height: 0.10)
            ],
            imageSize: CGSize(width: 200, height: 100)
        )

        XCTAssertEqual(rects, [
            CGRect(x: 20, y: 70, width: 60, height: 10)
        ])
        XCTAssertFalse(SearchHighlightOverlayPolicy.highlightsWholeRow(rectCount: 1))
        XCTAssertTrue(SearchHighlightOverlayPolicy.highlightsWholeRow(rectCount: 0))
    }

    func testPageTitleFieldChromeUsesAccentCursorAndHidesPlaceholderWhileEditing() {
        XCTAssertEqual(PageTitleFieldChrome.cursorColorToken, EditorDesignTokens.Colors.accent)
        XCTAssertEqual(PageTitleFieldChrome.placeholderText(isFocused: false, text: ""), "未命名")
        XCTAssertNil(PageTitleFieldChrome.placeholderText(isFocused: true, text: ""))
        XCTAssertNil(PageTitleFieldChrome.placeholderText(isFocused: false, text: "真实标题"))
    }

    func testMobileNavigationBarChromeUsesSolidEditorBackground() {
        XCTAssertTrue(
            MobileNavigationBarChrome.usesSolidEditorBackground,
            "The compact editor navigation bar should not use translucent material that flashes a mask over page transitions"
        )
    }

    func testEditorBlockChromeKeepsReadableParagraphSpacing() {
        XCTAssertGreaterThanOrEqual(
            EditorBlockChrome.blockSpacing,
            8,
            "Long documents need visible breathing room between paragraph blocks."
        )
        XCTAssertEqual(
            EditorBlockChrome.listMarkerTopPadding,
            3,
            "List marker alignment is a guarded visual seam and should stay pinned while increasing paragraph spacing."
        )
        XCTAssertEqual(
            InlineLeadingControlFrameDescriptor().textVerticalOffset,
            -4,
            "Task and toggle body text still need the established vertical compensation."
        )
    }

    func testTopBarTitleUsesScrollAwareVisibilityAndLargerDesktopChrome() {
        XCTAssertGreaterThanOrEqual(TopBarPageTitleChrome.desktopFontSize, 16)

        var state = TopBarPageTitleVisibilityState()
        state = state.updated(
            titleFrame: CGRect(x: 0, y: 118, width: 480, height: 44),
            scrollOffsetY: 0,
            topMaskHeight: MobileNavigationBarChrome.topMaskHeight
        )
        XCTAssertFalse(state.isVisible)

        state = state.updated(
            scrollOffsetY: 180,
            topMaskHeight: MobileNavigationBarChrome.topMaskHeight
        )
        XCTAssertTrue(
            state.isVisible,
            "The top-bar title should appear after the body title has scrolled under the toolbar."
        )
    }

    func testMobileOutlineDrawerKeepsVerticalScrollAndRendersMarkdownTitles() throws {
        XCTAssertFalse(OutlinePanelScrollPolicy.showsScrollIndicators)
        XCTAssertGreaterThanOrEqual(OutlinePanelScrollPolicy.maxHeight(for: .standard), 520)
        XCTAssertGreaterThanOrEqual(OutlinePanelScrollPolicy.maxHeight(for: .inline), 620)
        XCTAssertTrue(MobileOutlineDrawerScrollPolicy.allowsParentCloseGestureSimultaneously)
        XCTAssertTrue(MobileOutlineDrawerScrollPolicy.showsScrollIndicators)

        let display = try OutlineTitleMarkdownRenderer.displayText(for: "**重点**章节")
        XCTAssertEqual(display, "重点章节")
    }

    func testPageTitleFocusSchedulingStartsImmediatelyOnCompact() {
        XCTAssertEqual(PageTitleFocusSchedulingPolicy.compactRetryDelays.first, 0)
        XCTAssertLessThanOrEqual(
            PageTitleFocusSchedulingPolicy.compactRetryDelays.first ?? 1,
            0.05,
            "Quick-create title focus should start without a visible no-focus pause"
        )
    }

    func testPageTitleFocusSchedulingSkipsCancelledOrStaleAttempts() {
        XCTAssertTrue(
            PageTitleFocusSchedulingPolicy.shouldRunScheduledAttempt(
                scheduledPageID: "page-a",
                requestedPageID: "page-a",
                currentPageID: "page-a"
            )
        )
        XCTAssertFalse(
            PageTitleFocusSchedulingPolicy.shouldRunScheduledAttempt(
                scheduledPageID: nil,
                requestedPageID: "page-a",
                currentPageID: "page-a"
            ),
            "Cancelling a pending title focus before body focus should stop the delayed resign/refocus task"
        )
        XCTAssertFalse(
            PageTitleFocusSchedulingPolicy.shouldRunScheduledAttempt(
                scheduledPageID: "page-b",
                requestedPageID: "page-a",
                currentPageID: "page-a"
            )
        )
        XCTAssertFalse(
            PageTitleFocusSchedulingPolicy.shouldRunScheduledAttempt(
                scheduledPageID: "page-a",
                requestedPageID: "page-a",
                currentPageID: "page-b"
            )
        )
    }

    func testMobileNavigationTitleAppearsOnlyAfterBodyTitleEntersTopMask() {
        XCTAssertFalse(
            MobileNavigationTitleVisibilityResolver.isNavigationTitleVisible(
                titleFrame: .zero,
                topMaskHeight: 72
            ),
            "The default preference value should not make the top title flash on first render"
        )
        XCTAssertFalse(
            MobileNavigationTitleVisibilityResolver.isNavigationTitleVisible(
                titleFrame: CGRect(x: 14, y: 96, width: 320, height: 40),
                topMaskHeight: 72
            )
        )
        XCTAssertTrue(
            MobileNavigationTitleVisibilityResolver.isNavigationTitleVisible(
                titleFrame: CGRect(x: 14, y: 20, width: 320, height: 40),
                topMaskHeight: 72
            ),
            "The top title should appear once the body title is fully inside the blurred top mask"
        )
        XCTAssertTrue(
            MobileNavigationTitleVisibilityResolver.isNavigationTitleVisible(
                titleFrame: CGRect(x: 14, y: -20, width: 320, height: 40),
                topMaskHeight: 72
            )
        )
        XCTAssertTrue(
            MobileNavigationTitleVisibilityResolver.isNavigationTitleVisible(
                titleFrame: CGRect(x: 14, y: -48, width: 320, height: 40),
                topMaskHeight: 72
            )
        )
        XCTAssertFalse(
            MobileNavigationTitleScrollVisibilityResolver.isNavigationTitleVisible(
                baselineMaxY: 169,
                scrollOffsetY: 16,
                topMaskHeight: 72
            ),
            "The top title should stay hidden before the user has clearly scrolled the page"
        )
        XCTAssertFalse(
            MobileNavigationTitleScrollVisibilityResolver.isNavigationTitleVisible(
                baselineMaxY: 169,
                scrollOffsetY: 32,
                topMaskHeight: 72
            ),
            "When the title frame is known, the top title should wait until the body title actually reaches the top mask"
        )
        XCTAssertTrue(
            MobileNavigationTitleScrollVisibilityResolver.isNavigationTitleVisible(
                baselineMaxY: 169,
                scrollOffsetY: 681,
                topMaskHeight: 72
            ),
            "The top title should remain visible after the body title has fully scrolled away"
        )
        XCTAssertTrue(
            MobileNavigationTitleScrollVisibilityResolver.isNavigationTitleVisible(
                baselineMaxY: nil,
                scrollOffsetY: 32,
                topMaskHeight: 72
            ),
            "The top title should still appear after a real scroll even if the title frame preference is delayed"
        )
    }

    func testMobileNavigationTitleStateUsesScrollFallbackWhenTitleFrameIsDelayed() {
        let state = MobileNavigationTitleVisibilityState().updated(
            scrollOffsetY: 0,
            topMaskHeight: MobileNavigationBarChrome.topMaskHeight
        )

        let updatedState = state.updated(
            scrollOffsetY: 32,
            topMaskHeight: MobileNavigationBarChrome.topMaskHeight
        )

        XCTAssertTrue(
            updatedState.isVisible,
            "The top title should not wait forever for a title-frame preference once scrolling proves the body title is off the current viewport"
        )
    }

    func testMobileNavigationTitleStateIgnoresInitialContentOffset() {
        let state = MobileNavigationTitleVisibilityState().updated(
            scrollOffsetY: 96,
            topMaskHeight: MobileNavigationBarChrome.topMaskHeight
        )

        XCTAssertFalse(
            state.isVisible,
            "The top title should not appear just because iOS reports a non-zero initial content offset"
        )

        let barelyScrolledState = state.updated(
            titleFrame: CGRect(x: 0, y: 120, width: 320, height: 48),
            scrollOffsetY: 128,
            topMaskHeight: MobileNavigationBarChrome.topMaskHeight
        )

        XCTAssertFalse(
            barelyScrolledState.isVisible,
            "The top title should stay hidden while the measured body title is still visible below the top mask"
        )

        let titleScrolledAwayState = barelyScrolledState.updated(
            scrollOffsetY: 224,
            topMaskHeight: MobileNavigationBarChrome.topMaskHeight
        )

        XCTAssertTrue(
            titleScrolledAwayState.isVisible,
            "The top title should appear after the measured body title scrolls into the top mask"
        )
    }

    func testMobileNavigationTitleStateDoesNotShowTopTitleBeforeRealScroll() {
        let state = MobileNavigationTitleVisibilityState().updated(
            titleFrame: CGRect(x: 0, y: 20, width: 320, height: 48),
            scrollOffsetY: 0,
            topMaskHeight: MobileNavigationBarChrome.topMaskHeight
        )

        XCTAssertFalse(
            state.isVisible,
            "The top title should stay hidden on first render even when the body title starts near the navigation bar"
        )
    }

    func testMobileNavigationTitleStateKeepsRepeatedPreferenceUpdatesStable() {
        let state = MobileNavigationTitleVisibilityState().updated(
            titleFrame: CGRect(x: 0, y: 120, width: 320, height: 48),
            scrollOffsetY: 0,
            topMaskHeight: MobileNavigationBarChrome.topMaskHeight
        )

        let repeatedState = state.updated(
            titleFrame: CGRect(x: 0, y: 120, width: 320, height: 48),
            scrollOffsetY: 0,
            topMaskHeight: MobileNavigationBarChrome.topMaskHeight
        )

        XCTAssertEqual(
            repeatedState,
            state,
            "Repeated geometry preference delivery should not create a new navigation-title state and keep SwiftUI layouts from churning"
        )
    }

    func testMobileNavigationTitleStateEqualityIgnoresScrollOffsetChurnWhenVisibilityIsStable() {
        let state = MobileNavigationTitleVisibilityState().updated(
            titleFrame: CGRect(x: 0, y: 280, width: 320, height: 48),
            scrollOffsetY: 0,
            topMaskHeight: MobileNavigationBarChrome.topMaskHeight
        )

        let offsetOnlyUpdate = state.updated(
            scrollOffsetY: 20,
            topMaskHeight: MobileNavigationBarChrome.topMaskHeight
        )

        XCTAssertEqual(
            offsetOnlyUpdate,
            state,
            "Scroll offset changes that do not change top-title visibility should not invalidate the whole editor canvas"
        )
        XCTAssertFalse(offsetOnlyUpdate.isVisible)
    }

    func testMobileKeyboardToolbarPutsDismissKeyboardWithRightSideActions() {
        XCTAssertEqual(
            MobileKeyboardToolbarUtilityActionResolver.leadingActions,
            [.paste, .undo]
        )
        XCTAssertEqual(
            MobileKeyboardToolbarTrailingActionResolver.visibleActions,
            [.outline, .moreFormat, .dismissKeyboard]
        )
    }

    func testCompactEditorInitialFocusKeepsContentPagesAtTop() {
        let blocks = [
            BlockSnapshot(
                id: "block-1",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "1",
                type: .paragraph,
                textPlain: "Existing content"
            ),
            BlockSnapshot(
                id: "block-2",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "2",
                type: .paragraph,
                textPlain: "More content"
            )
        ]

        XCTAssertFalse(
            CompactEditorInitialFocusPolicy.shouldFocusCanvasOnAppear(blocks: blocks),
            "Opening an existing content page should not auto-focus the bottom block and scroll the title away."
        )
    }

    func testCompactEditorInitialFocusKeepsSingleEmptyPageEditable() {
        let blocks = [
            BlockSnapshot(
                id: "block-empty",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "1",
                type: .paragraph,
                textPlain: ""
            )
        ]

        XCTAssertTrue(CompactEditorInitialFocusPolicy.shouldFocusCanvasOnAppear(blocks: blocks))
    }

    func testDesktopColumnDividerCreatesVisibleColumnBoundary() {
        XCTAssertEqual(DesktopColumnDividerChrome.hitWidth, 9)
        XCTAssertEqual(DesktopColumnDividerChrome.lineWidth, 1)
        XCTAssertGreaterThanOrEqual(
            DesktopColumnDividerChrome.idleOpacity,
            0.24,
            "The middle and editor columns need a visible Bear-like boundary even while idle."
        )
        XCTAssertGreaterThan(DesktopColumnDividerChrome.hoverOpacity, DesktopColumnDividerChrome.idleOpacity)
        XCTAssertGreaterThan(DesktopColumnDividerChrome.draggingOpacity, DesktopColumnDividerChrome.hoverOpacity)
    }

    func testDesktopColumnResizeUsesDragStartWidthWithoutAccumulatingMovingDividerDeltas() {
        let startWidth: CGFloat = 260

        XCTAssertEqual(
            DesktopColumnResizeDragResolver.width(
                startWidth: startWidth,
                translation: 20,
                min: EditorDesignTokens.Layout.sidebarMinWidth,
                max: EditorDesignTokens.Layout.sidebarMaxWidth
            ),
            280
        )
        XCTAssertEqual(
            DesktopColumnResizeDragResolver.width(
                startWidth: startWidth,
                translation: 25,
                min: EditorDesignTokens.Layout.sidebarMinWidth,
                max: EditorDesignTokens.Layout.sidebarMaxWidth
            ),
            285,
            "A later drag event reports the total translation; it should not add the previous frame again."
        )
        XCTAssertEqual(
            DesktopColumnResizeDragResolver.width(
                startWidth: startWidth,
                translation: -200,
                min: EditorDesignTokens.Layout.sidebarMinWidth,
                max: EditorDesignTokens.Layout.sidebarMaxWidth
            ),
            CGFloat(EditorDesignTokens.Layout.sidebarMinWidth)
        )
        XCTAssertEqual(
            DesktopColumnResizeDragResolver.width(
                startWidth: startWidth,
                translation: 200,
                min: EditorDesignTokens.Layout.sidebarMinWidth,
                max: EditorDesignTokens.Layout.sidebarMaxWidth
            ),
            CGFloat(EditorDesignTokens.Layout.sidebarMaxWidth)
        )
    }

    func testEditorCanvasKeepsAControlledCenteredWidthWithoutRightRail() {
        XCTAssertEqual(
            EditorCanvasWidthPolicy.maxWidth(hasVisibleAuxiliaryRail: true),
            EditorDesignTokens.Layout.editorExpandedMaxWidth
        )
        XCTAssertEqual(
            EditorCanvasWidthPolicy.maxWidth(hasVisibleAuxiliaryRail: false),
            EditorDesignTokens.Layout.editorExpandedMaxWidth
        )
    }

    func testEditorCanvasCentersContentFrameInsideWideDetailColumn() {
        let frameWidth = EditorCanvasWidthPolicy.centeredContentFrameWidth(
            containerWidth: 1_420,
            horizontalPadding: 34,
            editorMaxWidth: CGFloat(EditorDesignTokens.Layout.editorExpandedMaxWidth)
        )

        XCTAssertEqual(frameWidth, 628)
        XCTAssertEqual(
            EditorCanvasWidthPolicy.centeredSideInset(
                containerWidth: 1_420,
                contentFrameWidth: frameWidth
            ),
            396
        )
        XCTAssertEqual(
            EditorCanvasWidthPolicy.editorColumnWidth(
                containerWidth: 1_420,
                horizontalPadding: 34,
                editorMaxWidth: CGFloat(EditorDesignTokens.Layout.editorExpandedMaxWidth)
            ),
            560
        )
    }

    func testDesktopInlineOutlineDefaultsToExpandedOnlyWhenLeftGutterCanHostIt() {
        XCTAssertEqual(DesktopInlineOutlinePlacementPolicy.expandedWidth, 188)
        XCTAssertEqual(DesktopInlineOutlinePlacementPolicy.collapsedWidth, 34)
        XCTAssertEqual(DesktopInlineOutlinePlacementPolicy.minimumReadableLeftGap, 224)
        XCTAssertEqual(
            DesktopInlineOutlinePlacementPolicy.presentation(
                outlineItemCount: 3,
                leadingGap: 236,
                userPreference: .automatic
            ),
            .expanded
        )
        XCTAssertEqual(
            DesktopInlineOutlinePlacementPolicy.presentation(
                outlineItemCount: 3,
                leadingGap: 220,
                userPreference: .automatic
            ),
            .collapsed
        )
        XCTAssertEqual(
            DesktopInlineOutlinePlacementPolicy.presentation(
                outlineItemCount: 3,
                leadingGap: DesktopInlineOutlinePlacementPolicy.leadingGap(
                    containerWidth: 1_208,
                    horizontalPadding: 34,
                    editorMaxWidth: CGFloat(EditorDesignTokens.Layout.editorExpandedMaxWidth)
                ),
                userPreference: .automatic
            ),
            .expanded
        )
    }

    func testDesktopInlineOutlineUsesLargerCompactTypography() {
        XCTAssertEqual(DesktopInlineOutlineTypography.inlineTitleFontSize, 13.5)
        XCTAssertEqual(DesktopInlineOutlineTypography.inlineTitleWeight, .medium)
    }

    func testDesktopInlineOutlinePersistsClosedAndClickingWideTriggerPinsItOpen() {
        XCTAssertEqual(
            DesktopInlineOutlinePlacementPolicy.presentation(
                outlineItemCount: 2,
                leadingGap: 236,
                userPreference: .collapsed
            ),
            .collapsed
        )
        XCTAssertEqual(
            DesktopInlineOutlineTogglePolicy.triggerAction(leadingGap: 236),
            .persist(.expanded)
        )
        XCTAssertEqual(
            DesktopInlineOutlineTogglePolicy.triggerAction(leadingGap: 220),
            .togglePopover
        )
    }

    func testDesktopInlineOutlineSitsNearTopOfReadingArea() {
        XCTAssertEqual(
            DesktopInlineOutlinePlacementPolicy.topOffset(containerHeight: 1_000),
            86
        )
    }

    func testEditorDisplayModesProgressivelyHideSecondaryChrome() {
        XCTAssertTrue(EditorDisplayMode.standard.showsSidebar)
        XCTAssertTrue(EditorDisplayMode.standard.showsDocumentList)
        XCTAssertFalse(EditorDisplayMode.standard.showsAuxiliaryRail)

        XCTAssertTrue(EditorDisplayMode.writing.showsSidebar)
        XCTAssertFalse(EditorDisplayMode.writing.showsDocumentList)
        XCTAssertFalse(EditorDisplayMode.writing.showsAuxiliaryRail)

        XCTAssertFalse(EditorDisplayMode.focus.showsSidebar)
        XCTAssertFalse(EditorDisplayMode.focus.showsDocumentList)
        XCTAssertFalse(EditorDisplayMode.focus.showsAuxiliaryRail)
    }

    func testDesktopInlineOutlineActivatesScrolledSectionHeading() {
        let outlineItems = [
            PageOutlineItem(blockID: "heading-1", title: "Intro", level: 1),
            PageOutlineItem(blockID: "heading-2", title: "Details", level: 2),
            PageOutlineItem(blockID: "heading-3", title: "Wrap", level: 2)
        ]
        let visibleBlockFrames: [String: CGRect] = [
            "paragraph-2": CGRect(x: 0, y: 12, width: 400, height: 28),
            "paragraph-3": CGRect(x: 0, y: 52, width: 400, height: 28),
            "heading-3": CGRect(x: 0, y: 190, width: 400, height: 36)
        ]

        XCTAssertEqual(
            DesktopInlineOutlineActiveHeadingResolver.activeBlockID(
                outlineItems: outlineItems,
                visibleBlockFrames: visibleBlockFrames,
                blockIDsInDocumentOrder: [
                    "heading-1",
                    "paragraph-1",
                    "heading-2",
                    "paragraph-2",
                    "paragraph-3",
                    "heading-3"
                ],
                focusedBlockID: nil
            ),
            "heading-2",
            "When the user scrolls past a heading, the inline outline should keep the current section highlighted."
        )
    }

    func testDesktopInlineOutlineActivatesHeadingBeforeItReachesTopEdge() {
        let outlineItems = [
            PageOutlineItem(blockID: "heading-1", title: "Intro", level: 1),
            PageOutlineItem(blockID: "heading-2", title: "Details", level: 2)
        ]
        let visibleBlockFrames: [String: CGRect] = [
            "heading-1": CGRect(x: 0, y: -220, width: 400, height: 36),
            "heading-2": CGRect(x: 0, y: 148, width: 400, height: 36)
        ]

        XCTAssertEqual(
            DesktopInlineOutlineActiveHeadingResolver.activeBlockID(
                outlineItems: outlineItems,
                visibleBlockFrames: visibleBlockFrames,
                blockIDsInDocumentOrder: ["heading-1", "paragraph-1", "heading-2"],
                focusedBlockID: nil
            ),
            "heading-2",
            "The current section should advance once a heading is near the reading band, not only after it sticks to the top edge."
        )
    }

    func testDesktopInlineOutlineManualSelectionOverridesVisibleScrollHeading() {
        let outlineItems = [
            PageOutlineItem(blockID: "heading-1", title: "Intro", level: 1),
            PageOutlineItem(blockID: "heading-2", title: "Details", level: 2)
        ]
        let visibleBlockFrames: [String: CGRect] = [
            "heading-1": CGRect(x: 0, y: 12, width: 400, height: 36),
            "heading-2": CGRect(x: 0, y: 132, width: 400, height: 36)
        ]

        XCTAssertEqual(
            DesktopInlineOutlineActiveHeadingResolver.activeBlockID(
                outlineItems: outlineItems,
                visibleBlockFrames: visibleBlockFrames,
                blockIDsInDocumentOrder: ["heading-1", "heading-2"],
                selectedBlockID: "heading-2",
                focusedBlockID: "heading-2"
            ),
            "heading-2",
            "Clicking an outline heading should highlight the selected heading even while an earlier heading remains above the scroll activation line."
        )
    }

    func testBlockRowFrameUpdatePolicySkipsScrollFrameChurnWhenActiveHeadingIsStable() {
        let currentFrames = [
            "heading-1": CGRect(x: 0, y: 10, width: 400, height: 36),
            "heading-2": CGRect(x: 0, y: 240, width: 400, height: 36)
        ]
        let nextFrames = [
            "heading-1": CGRect(x: 0, y: -6, width: 400, height: 36),
            "heading-2": CGRect(x: 0, y: 224, width: 400, height: 36)
        ]

        XCTAssertFalse(
            BlockRowFrameUpdatePolicy.shouldUpdate(
                currentFrames: currentFrames,
                nextFrames: nextFrames,
                currentActiveBlockID: "heading-1",
                nextActiveBlockID: "heading-1",
                isBlockSelectionMarqueeActive: false,
                hasPinnedOutlineSelection: false
            ),
            "Scroll-driven heading frame drift should not invalidate the editor canvas while the active outline section is unchanged."
        )
    }

    func testBlockRowFrameUpdatePolicyUpdatesWhenActiveHeadingChanges() {
        XCTAssertTrue(
            BlockRowFrameUpdatePolicy.shouldUpdate(
                currentFrames: [
                    "heading-1": CGRect(x: 0, y: -120, width: 400, height: 36),
                    "heading-2": CGRect(x: 0, y: 220, width: 400, height: 36)
                ],
                nextFrames: [
                    "heading-1": CGRect(x: 0, y: -260, width: 400, height: 36),
                    "heading-2": CGRect(x: 0, y: 80, width: 400, height: 36)
                ],
                currentActiveBlockID: "heading-1",
                nextActiveBlockID: "heading-2",
                isBlockSelectionMarqueeActive: false,
                hasPinnedOutlineSelection: false
            ),
            "The outline must still refresh when scrolling crosses into a new heading section."
        )
    }

    func testBlockRowFrameUpdatePolicyKeepsSelectionAndMarqueeGeometryLive() {
        let currentFrames = [
            "heading-1": CGRect(x: 0, y: 10, width: 400, height: 36)
        ]
        let nextFrames = [
            "heading-1": CGRect(x: 0, y: 20, width: 400, height: 36)
        ]

        XCTAssertTrue(
            BlockRowFrameUpdatePolicy.shouldUpdate(
                currentFrames: currentFrames,
                nextFrames: nextFrames,
                currentActiveBlockID: "heading-1",
                nextActiveBlockID: "heading-1",
                isBlockSelectionMarqueeActive: true,
                hasPinnedOutlineSelection: false
            ),
            "Drag selection needs fresh row frames for hit testing."
        )
        XCTAssertTrue(
            BlockRowFrameUpdatePolicy.shouldUpdate(
                currentFrames: currentFrames,
                nextFrames: nextFrames,
                currentActiveBlockID: "heading-1",
                nextActiveBlockID: "heading-1",
                isBlockSelectionMarqueeActive: false,
                hasPinnedOutlineSelection: true
            ),
            "A pinned outline selection still needs geometry updates so the visible highlight stays aligned."
        )
    }

    func testCraftQuietChromeKeepsListRowsUnboxedWithReadableParagraphSpacing() {
        XCTAssertEqual(EditorBlockChrome.blockSpacing, 8)
        XCTAssertEqual(EditorBlockChrome.rowVerticalPadding, 0)
        XCTAssertEqual(EditorBlockChrome.listVerticalPadding, 0)
        XCTAssertEqual(EditorBlockChrome.listBackgroundOpacity, 0)
        XCTAssertEqual(EditorBlockChrome.listMarkerWidth, 18)
        XCTAssertEqual(EditorBlockChrome.listTextSpacing, 4)
        XCTAssertEqual(
            EditorBlockChrome.listMarkerTopPadding,
            3,
            "List rows use explicit top alignment because NSTextView does not expose a reliable SwiftUI firstTextBaseline; do not reset this to 0."
        )
        XCTAssertEqual(EditorBlockChrome.listMarkerLineHeight, 18)
        XCTAssertEqual(EditorBlockChrome.canvasTrailingFocusHitHeight, 760)
        XCTAssertEqual(EditorBlockChrome.listNestingIndentWidth, 24)
        XCTAssertEqual(EditorBlockChrome.actionColumnWidth, 18)
        XCTAssertEqual(EditorBlockChrome.actionColumnSpacing, 5)
        XCTAssertEqual(EditorBlockChrome.inactiveHandleOpacity, 0)
        XCTAssertEqual(EditorBlockChrome.inlineControlTopPadding, 1)
        XCTAssertEqual(EditorBlockChrome.taskControlIconSize, 16)
        XCTAssertEqual(EditorBlockChrome.dropTargetHeight, 32)
        XCTAssertEqual(EditorBlockChrome.dropSlotHeight, 4)
        XCTAssertEqual(EditorBlockChrome.dropIndicatorAfterOffset, 0)
        XCTAssertEqual(EditorBlockChrome.trailingInsertHitHeight, 64)
    }

    func testBlockDragHandleOnlyAppearsWhenPointerHoversTheRow() {
        XCTAssertEqual(BlockDragHandleVisibilityPolicy.opacity(isHovered: false), 0)
        XCTAssertEqual(BlockDragHandleVisibilityPolicy.opacity(isHovered: true), 1)
    }

    func testMobileBlockDragHandleStaysHiddenWhileRowSupportsLongPressReordering() {
        XCTAssertEqual(
            MobileBlockDragHandleVisibilityPolicy.opacity(isSelectionModeActive: false),
            0
        )
        XCTAssertEqual(
            MobileBlockDragHandleVisibilityPolicy.opacity(isSelectionModeActive: true),
            0
        )
        XCTAssertFalse(MobileBlockDragActivationPolicy.usesVisibleDragHandle)
        XCTAssertTrue(MobileBlockDragActivationPolicy.usesLongPressDraggableRow)
        XCTAssertTrue(MobileBlockDragActivationPolicy.usesWholeRowDropTarget)
        XCTAssertFalse(MobileBlockDragActivationPolicy.usesDedicatedRowDropSlots)
        XCTAssertTrue(MobileBlockDragActivationPolicy.usesNativeTextViewDragInteraction)
    }

    func testMobileNativeTextRowsKeepUIKitTextMenuInsteadOfRowContextMenu() {
        XCTAssertFalse(MobileBlockContextMenuPolicy.enablesRowContextMenu(usesNativeTextEditor: true))
        XCTAssertTrue(MobileBlockContextMenuPolicy.enablesRowContextMenu(usesNativeTextEditor: false))
    }

    func testLargePageAccessibilityTextIsSummarized() {
        let text = String(repeating: "a", count: BlockAccessibilityTextPolicy.largePageTextLimit + 24)
        let summarized = BlockAccessibilityTextPolicy.summarizedText(text, isLargePage: true)

        XCTAssertEqual(summarized.count, BlockAccessibilityTextPolicy.largePageTextLimit + 3)
        XCTAssertTrue(summarized.hasSuffix("..."))
        XCTAssertEqual(BlockAccessibilityTextPolicy.summarizedText(text, isLargePage: false), text)
        XCTAssertTrue(
            BlockAccessibilityTextPolicy.rowValue(
                blockText: text,
                isSelected: false,
                isLargePage: true
            ).contains("当前块未选中")
        )
    }

    func testStructuredTablePreviewDescriptorPreservesFullPreviewGeometry() {
        let descriptor = StructuredTableBlockPreviewDescriptor(rows: [
            ["Name", "Status", "Owner"],
            ["Alpha", "Running"],
            ["Beta", "Blocked", "Team", "Extra"]
        ])

        XCTAssertEqual(descriptor.rowCount, 3)
        XCTAssertEqual(descriptor.columnCount, 4)
        XCTAssertEqual(descriptor.contentWidth, CGFloat(4 * TableBlockChrome.cellWidth))
        XCTAssertEqual(descriptor.contentHeight, CGFloat(3 * TableBlockChrome.cellHeight))
        XCTAssertEqual(descriptor.accessibilityValue, "3 行，4 列")
    }

    func testMobileWholeRowDropTargetKeepsReorderTouchableWithoutVisibleHandle() {
        XCTAssertEqual(MobileBlockDropTargetPolicy.estimatedRowDropSize.height, 44)
        XCTAssertEqual(MobileBlockDropTargetPolicy.placement(
            location: CGPoint(x: 72, y: 6),
            destinationLevel: 1
        ), .before)
        XCTAssertEqual(MobileBlockDropTargetPolicy.placement(
            location: CGPoint(x: 72, y: 28),
            destinationLevel: 1
        ), .after)
    }

    func testMobileQuickCreateLongPressMenuKeepsDiaryBeforeNewDocument() {
        XCTAssertEqual(
            MobileQuickCreateMenuModel.longPressActions,
            [.dailyDiary, .newDocument]
        )
    }

    func testCompactLibraryRowsHaveEnoughSeparationForTouchAccuracy() {
        XCTAssertGreaterThanOrEqual(CompactLibraryChrome.navigationRowMinHeight, 52)
        XCTAssertGreaterThanOrEqual(CompactLibraryChrome.navigationRowSpacing, 10)
        XCTAssertGreaterThanOrEqual(CompactLibraryChrome.navigationRowVerticalPadding, 14)
        XCTAssertGreaterThanOrEqual(CompactLibraryChrome.tagRowVerticalPadding, 12)
    }

    func testNestedListVerticalRhythmKeepsDropSlotsSubtleLikeCraft() {
        XCTAssertLessThanOrEqual(EditorBlockChrome.dropSlotHeight, 4)
        XCTAssertLessThanOrEqual(
            EditorBlockChrome.dropSlotHeight + EditorBlockChrome.rowVerticalPadding * 2,
            4
        )
    }

    func testListMarkerFrameKeepsBulletAndNumberedMarkersLeftAligned() {
        let descriptor = ListMarkerGlyphFrameDescriptor()
        let bulletDescriptor = ListMarkerBulletGlyphDescriptor()

        XCTAssertEqual(descriptor.width, EditorBlockChrome.listMarkerWidth)
        XCTAssertEqual(descriptor.height, EditorBlockChrome.listMarkerLineHeight)
        XCTAssertEqual(descriptor.horizontalAlignment, .leading)
        XCTAssertEqual(bulletDescriptor.diameter, 6)
        XCTAssertEqual(bulletDescriptor.strokeLineWidth, 1.4)
        XCTAssertEqual(bulletDescriptor.visibleLeadingOffset, 0)
        XCTAssertEqual(bulletDescriptor.visibleTopOffset, 0)
        XCTAssertEqual(
            ListMarkerColumnAlignmentResolver.leadingOffset(markerWidth: 4, columnWidth: descriptor.width),
            0
        )
        XCTAssertEqual(
            ListMarkerColumnAlignmentResolver.leadingOffset(markerWidth: 14, columnWidth: descriptor.width),
            0
        )
    }

    func testListBulletStyleAlternatesByNestingLevelLikeCraft() {
        XCTAssertFalse(ListMarkerBulletStyleResolver.isHollow(nestingLevel: 0))
        XCTAssertTrue(ListMarkerBulletStyleResolver.isHollow(nestingLevel: 1))
        XCTAssertFalse(ListMarkerBulletStyleResolver.isHollow(nestingLevel: 2))
        XCTAssertTrue(ListMarkerBulletStyleResolver.isHollow(nestingLevel: 3))
        XCTAssertEqual(BlockRowNestingIndentResolver.leadingPadding(nestingLevel: 2, blockType: .unorderedListItem), 48)
        XCTAssertEqual(BlockRowNestingIndentResolver.leadingPadding(nestingLevel: 2, blockType: .paragraph), 48)
    }

    func testFocusedRowBackgroundStaysOffWhenSlashMenuIsVisible() {
        XCTAssertEqual(
            BlockRowBackgroundPolicy.opacity(
                blockType: .paragraph,
                isSelected: false,
                isFocused: true,
                isSlashCommandMenuVisible: true
            ),
            0
        )
        XCTAssertGreaterThan(
            BlockRowBackgroundPolicy.opacity(
                blockType: .paragraph,
                isSelected: false,
                isFocused: true,
                isSlashCommandMenuVisible: false
            ),
            0
        )
    }

    func testDividerRowsNeverShowSelectionBackgroundAndDoNotAutoSelectAfterInsertion() {
        XCTAssertEqual(
            BlockRowBackgroundPolicy.opacity(
                blockType: .divider,
                isSelected: true,
                isFocused: true,
                isSlashCommandMenuVisible: false
            ),
            0
        )
        XCTAssertEqual(
            BlockRowSelectionBorderPolicy.opacity(blockType: .divider, isSelected: true),
            0
        )
        XCTAssertFalse(NonEditableBlockSelectionPolicy.selectsBlockOnFocusRequest(blockType: .divider))
    }

    func testDividerBlockUsesHorizontalCraftSeparatorMetrics() {
        let descriptor = DividerBlockChromeDescriptor(
            block: block(id: "divider", parentBlockID: nil, type: .divider, text: "")
        )

        XCTAssertEqual(descriptor.axis, .horizontal)
        XCTAssertEqual(descriptor.height, 56)
        XCTAssertGreaterThanOrEqual(descriptor.waveAmplitude, 12)
        XCTAssertEqual(descriptor.loopCount, 5)
        XCTAssertGreaterThan(descriptor.casualVariance, 0)
        XCTAssertGreaterThan(descriptor.strokeOpacity, 0.45)
    }

    func testAttachmentImageCaptionHidesOriginalFilenameUntilRenamed() {
        XCTAssertFalse(
            AttachmentImageCaptionVisibilityPolicy.isVisible(
                blockText: "screen.png",
                originalFilename: "screen.png"
            ),
            "Imported images use the original filename as backing block text, but the visible caption should start hidden."
        )
        XCTAssertTrue(
            AttachmentImageCaptionVisibilityPolicy.isVisible(
                blockText: "Product sketch",
                originalFilename: "screen.png"
            ),
            "A user-provided display name should become a visible image caption."
        )
        XCTAssertFalse(
            AttachmentImageCaptionVisibilityPolicy.isVisible(
                blockText: "   ",
                originalFilename: "screen.png"
            )
        )
    }

    func testAttachmentImageResizePolicyUsesCanvasWidthAndDragDelta() {
        XCTAssertEqual(
            AttachmentImageDisplayWidthPolicy.resolvedWidth(
                storedWidth: nil,
                availableWidth: 320
            ),
            320
        )
        XCTAssertEqual(
            AttachmentImageDisplayWidthPolicy.resolvedWidth(
                storedWidth: 520,
                availableWidth: 420
            ),
            420
        )
        XCTAssertEqual(
            AttachmentImageDisplayWidthPolicy.widthAfterDrag(
                startWidth: 300,
                translation: CGSize(width: 80, height: 40),
                availableWidth: 500
            ),
            380
        )
        XCTAssertEqual(
            AttachmentImageDisplayWidthPolicy.widthAfterDrag(
                startWidth: 300,
                translation: CGSize(width: -400, height: 0),
                availableWidth: 500
            ),
            AttachmentImageDisplayWidthPolicy.minimumWidth
        )
    }

    func testAttachmentImageResizeGestureUsesStableCoordinates() {
        XCTAssertEqual(AttachmentImageResizeGesturePolicy.minimumDistance, 2)
        XCTAssertEqual(
            AttachmentImageResizeGesturePolicy.coordinateSpace,
            .stableGlobal,
            "The resize handle moves as the image width changes, so the drag delta must be measured in a stable coordinate space."
        )
    }

    func testAttachmentImageResizeSuppressesSelectedRowRedChromeDuringDrag() {
        XCTAssertEqual(
            BlockRowBackgroundPolicy.opacity(
                blockType: .attachmentImage,
                isSelected: true,
                isFocused: false,
                isSlashCommandMenuVisible: false,
                suppressesSelectionChrome: true
            ),
            0
        )
        XCTAssertEqual(
            BlockRowBackgroundPolicy.opacity(
                blockType: .attachmentImage,
                isSelected: true,
                isFocused: false,
                isSlashCommandMenuVisible: false,
                suppressesSelectionChrome: false
            ),
            0
        )
        XCTAssertEqual(
            BlockRowSelectionBorderPolicy.opacity(
                blockType: .attachmentImage,
                isSelected: true,
                suppressesSelectionChrome: false
            ),
            0
        )
    }

    func testAttachmentImageSelectionChromeUsesNeutralImageFrameInsteadOfRedRowBox() {
        XCTAssertEqual(AttachmentImageSelectionChrome.rowBackgroundOpacity(isSelected: true), 0)
        XCTAssertEqual(AttachmentImageSelectionChrome.rowBorderOpacity(isSelected: true), 0)
        XCTAssertGreaterThan(AttachmentImageSelectionChrome.imageBorderOpacity(isSelected: true), 0)
        XCTAssertEqual(AttachmentImageSelectionChrome.imageBorderRed, EditorDesignTokens.Colors.border.red)
        XCTAssertEqual(AttachmentImageSelectionChrome.imageBorderGreen, EditorDesignTokens.Colors.border.green)
        XCTAssertEqual(AttachmentImageSelectionChrome.imageBorderBlue, EditorDesignTokens.Colors.border.blue)
    }

    func testAttachmentImagePreviewDiagnosticExplainsMissingOrUnreadableImages() {
        XCTAssertEqual(
            AttachmentImagePreviewDiagnosticResolver.reason(
                attachmentAvailable: false,
                candidatePathStates: [],
                isPending: false,
                isGenerationFailed: false
            ),
            .missingAttachment
        )
        XCTAssertEqual(
            AttachmentImagePreviewDiagnosticResolver.reason(
                attachmentAvailable: true,
                candidatePathStates: [],
                isPending: true,
                isGenerationFailed: false
            ),
            .waitingForSync
        )
        XCTAssertEqual(
            AttachmentImagePreviewDiagnosticResolver.reason(
                attachmentAvailable: true,
                candidatePathStates: [.missing],
                isPending: false,
                isGenerationFailed: false
            ),
            .fileMissing
        )
        XCTAssertEqual(
            AttachmentImagePreviewDiagnosticResolver.reason(
                attachmentAvailable: true,
                candidatePathStates: [.undecodable],
                isPending: false,
                isGenerationFailed: false
            ),
            .decodeFailed
        )
        XCTAssertNil(
            AttachmentImagePreviewDiagnosticResolver.reason(
                attachmentAvailable: true,
                candidatePathStates: [.loadable],
                isPending: false,
                isGenerationFailed: false
            )
        )
        XCTAssertEqual(
            AttachmentImagePreviewDiagnosticResolver.message(for: .fileMissing).title,
            "图片文件缺失"
        )
    }

    func testAttachmentImagePreviewZoomPolicyClampsScaleAndClearsOffsetAtRest() {
        XCTAssertEqual(AttachmentImagePreviewZoomPolicy.clampedScale(0.4), 1)
        XCTAssertEqual(AttachmentImagePreviewZoomPolicy.clampedScale(6.8), 5)
        XCTAssertEqual(AttachmentImagePreviewZoomPolicy.clampedScale(2.25), 2.25)
        XCTAssertEqual(
            AttachmentImagePreviewZoomPolicy.persistedOffset(
                currentOffset: CGSize(width: 20, height: 10),
                scale: 1
            ),
            .zero
        )
        XCTAssertEqual(
            AttachmentImagePreviewZoomPolicy.persistedOffset(
                currentOffset: CGSize(width: 20, height: 10),
                scale: 2
            ),
            CGSize(width: 20, height: 10)
        )
    }

    func testInlineLeadingControlsKeepTaskAndToggleTextBaselineCompensation() {
        let descriptor = InlineLeadingControlFrameDescriptor()
        let compactControlDescriptor = InlineLeadingControlFrameDescriptor(
            topPadding: EditorBlockChrome.inlineControlTopPadding
        )

        XCTAssertEqual(descriptor.width, EditorBlockChrome.listMarkerWidth)
        XCTAssertEqual(descriptor.height, EditorBlockChrome.listMarkerLineHeight)
        XCTAssertEqual(descriptor.topPadding, EditorBlockChrome.listMarkerTopPadding)
        XCTAssertEqual(descriptor.textSpacing, EditorBlockChrome.listTextSpacing)
        XCTAssertEqual(
            descriptor.textVerticalOffset,
            -4,
            "Task/toggle body text must sit high enough to visually align with the control baseline; list rows share this explicit NSTextView compensation."
        )
        XCTAssertEqual(compactControlDescriptor.topPadding, 1)
        XCTAssertEqual(compactControlDescriptor.textVerticalOffset, -4)
        XCTAssertEqual(TextEditableBlockChromePolicy.backgroundOpacity(blockType: .taskItem), 0)
        XCTAssertEqual(TextEditableBlockChromePolicy.backgroundOpacity(blockType: .toggle), 0)
    }

    func testHeadingBlockChromeUsesLevelSensitiveAccentStrip() {
        let heading1 = HeadingBlockChromeDescriptor(
            block: block(id: "h1", parentBlockID: nil, type: .heading1, text: "一级标题")
        )
        let heading3 = HeadingBlockChromeDescriptor(
            block: block(id: "h3", parentBlockID: nil, type: .heading3, text: "三级标题")
        )

        XCTAssertEqual(heading1.accentWidth, 5)
        XCTAssertEqual(heading3.accentWidth, 3)
        XCTAssertGreaterThan(heading1.backgroundOpacity, heading3.backgroundOpacity)
        XCTAssertGreaterThan(heading1.textLeadingPadding, heading3.textLeadingPadding)
        XCTAssertEqual(heading1.accessibilityIdentifier, "editor.heading1.h1")
    }

    func testDragPreviewChromeOffsetsVisibleCardAwayFromPointerAndDropIndicator() {
        let descriptor = DragPreviewLayoutDescriptor()

        XCTAssertGreaterThan(descriptor.pointerHorizontalOffset, descriptor.visibleCardWidth)
        XCTAssertGreaterThan(descriptor.pointerVerticalOffset, descriptor.visibleCardMaxHeight)
        XCTAssertEqual(descriptor.visibleCardLeadingFromCenteredPointer, 14)
        XCTAssertEqual(descriptor.visibleCardTopFromCenteredPointer, 12)
        XCTAssertGreaterThan(
            descriptor.visibleCardLeadingFromCenteredPointer,
            0,
            "The drag preview should stay to the lower-right of the pointer."
        )
        XCTAssertGreaterThanOrEqual(
            descriptor.visibleCardTopFromCenteredPointer,
            EditorBlockChrome.dropSlotHeight + 8,
            "The drag preview should stay below the blue drop line instead of covering it."
        )
    }

    func testPageTagEditorVisibilityHidesEmptyTagRow() {
        XCTAssertFalse(
            PageTagEditorVisibilityPolicy.isVisible(
                selectedTagIDs: [],
                selectedTagNames: []
            )
        )
        XCTAssertTrue(
            PageTagEditorVisibilityPolicy.isVisible(
                selectedTagIDs: ["tag-work"],
                selectedTagNames: []
            )
        )
        XCTAssertTrue(
            PageTagEditorVisibilityPolicy.isVisible(
                selectedTagIDs: [],
                selectedTagNames: ["工作"]
            )
        )
    }

    func testPageTagEditorChromeKeepsExplicitCreation() {
        XCTAssertTrue(PageTagEditorChromePolicy.showsCreateField)
    }

    func testPageRowDragVisualPolicyMakesDraggedSourceFeelLifted() {
        XCTAssertEqual(PageRowDragVisualPolicy.opacity(isBeingDragged: false), 1)
        XCTAssertEqual(PageRowDragVisualPolicy.scale(isBeingDragged: false), 1)
        XCTAssertEqual(PageRowDragVisualPolicy.shadowOpacity(isBeingDragged: false), 0)
        XCTAssertLessThan(
            PageRowDragVisualPolicy.opacity(isBeingDragged: true),
            PageRowDragVisualPolicy.opacity(isBeingDragged: false)
        )
        XCTAssertLessThan(
            PageRowDragVisualPolicy.scale(isBeingDragged: true),
            PageRowDragVisualPolicy.scale(isBeingDragged: false)
        )
        XCTAssertGreaterThan(
            PageRowDragVisualPolicy.shadowOpacity(isBeingDragged: true),
            PageRowDragVisualPolicy.shadowOpacity(isBeingDragged: false)
        )
    }

    func testSidebarDropTargetChromeHighlightsDropTargetsWithoutSelection() {
        XCTAssertEqual(
            SidebarDropTargetChromePolicy.fillOpacity(isSelected: false, isDropTargeted: false),
            0
        )
        XCTAssertGreaterThan(
            SidebarDropTargetChromePolicy.fillOpacity(isSelected: false, isDropTargeted: true),
            SidebarDropTargetChromePolicy.fillOpacity(isSelected: false, isDropTargeted: false)
        )
        XCTAssertGreaterThan(
            SidebarDropTargetChromePolicy.strokeOpacity(isSelected: false, isDropTargeted: true),
            SidebarDropTargetChromePolicy.strokeOpacity(isSelected: false, isDropTargeted: false)
        )
        XCTAssertGreaterThan(
            SidebarDropTargetChromePolicy.fillOpacity(isSelected: true, isDropTargeted: true),
            SidebarDropTargetChromePolicy.fillOpacity(isSelected: true, isDropTargeted: false)
        )
    }

    func testBlockDropIndicatorChromeKeepsBlueLineClearButQuiet() {
        XCTAssertEqual(BlockDropIndicatorChrome.lineHeight, 1.5)
        XCTAssertGreaterThanOrEqual(BlockDropIndicatorChrome.standardOpacity, 0.55)
        XCTAssertGreaterThan(BlockDropIndicatorChrome.emphasizedOpacity, BlockDropIndicatorChrome.standardOpacity)
    }

    func testPageListChromeUsesBearLikeTintedSurfaceAndVisibleBoundary() {
        XCTAssertEqual(PageListChrome.backgroundRed, EditorDesignTokens.Colors.documentListBackground.red)
        XCTAssertEqual(PageListChrome.backgroundGreen, EditorDesignTokens.Colors.documentListBackground.green)
        XCTAssertEqual(PageListChrome.backgroundBlue, EditorDesignTokens.Colors.documentListBackground.blue)
        XCTAssertNotEqual(
            EditorDesignTokens.Colors.documentListBackground,
            EditorDesignTokens.Colors.editorBackground,
            "The middle column should read as a separate Bear-like surface from the writing canvas"
        )
        XCTAssertGreaterThan(PageListChrome.rowDividerOpacity, 0)
        XCTAssertLessThan(PageListChrome.selectedFillOpacity, 0.08)
    }

    func testCompactChromeUsesDocumentListBackgroundAcrossMobileLists() {
        XCTAssertEqual(CompactChrome.backgroundRed, PageListChrome.backgroundRed)
        XCTAssertEqual(CompactChrome.backgroundGreen, PageListChrome.backgroundGreen)
        XCTAssertEqual(CompactChrome.backgroundBlue, PageListChrome.backgroundBlue)
    }

    func testCompactDocumentListChromeUsesBearLikeSpacingAndInlineTitle() {
        XCTAssertEqual(CompactDocumentListChrome.horizontalPadding, 24)
        XCTAssertEqual(CompactDocumentListChrome.verticalPadding, 10)
        XCTAssertEqual(CompactDocumentListChrome.rowMinHeight, 86)
        XCTAssertTrue(CompactDocumentListChrome.prefersInlineNavigationTitle)
    }

    func testCompactLibraryChromeUsesLightAppSurface() {
        assertColor(CompactLibraryChrome.backgroundToken, red: 0xF7, green: 0xF7, blue: 0xF5)
        assertColor(CompactLibraryChrome.primaryForegroundToken, red: 0x22, green: 0x21, blue: 0x1F)
        assertColor(CompactLibraryChrome.mutedForegroundToken, red: 0x5F, green: 0x61, blue: 0x66)
        XCTAssertEqual(CompactLibraryChrome.rowCornerRadius, 13)
        XCTAssertEqual(CompactLibraryChrome.selectedRowOpacity, 0.08)
    }

    func testBearLikeLightThemeUsesTintedMiddleColumnAndWhiteWritingSurface() {
        assertColor(EditorDesignTokens.Colors.appBackground, red: 0xF7, green: 0xF7, blue: 0xF5)
        assertColor(EditorDesignTokens.Colors.sidebarBackground, red: 0xF2, green: 0xF2, blue: 0xEF)
        assertColor(EditorDesignTokens.Colors.documentListBackground, red: 0xF8, green: 0xF8, blue: 0xF6)
        assertColor(EditorDesignTokens.Colors.editorBackground, red: 0xFF, green: 0xFF, blue: 0xFF)
        XCTAssertNotEqual(EditorDesignTokens.Colors.documentListBackground, EditorDesignTokens.Colors.editorBackground)
        XCTAssertLessThan(SidebarChrome.backgroundYellowBias, 0.015)
        XCTAssertLessThan(CompactChrome.backgroundYellowBias, 0.015)
    }

    func testDarkThemeKeepsMiddleColumnAndWritingSurfaceSeparated() {
        XCTAssertNotEqual(
            PageListChrome.backgroundToken.components(for: .dark),
            EditorDesignTokens.Colors.editorBackground.components(for: .dark)
        )
        XCTAssertNotEqual(
            SidebarChrome.backgroundToken.components(for: .dark),
            PageListChrome.backgroundToken.components(for: .dark)
        )
        XCTAssertEqual(CompactChrome.backgroundToken, PageListChrome.backgroundToken)
        XCTAssertEqual(CompactLibraryChrome.backgroundToken, EditorDesignTokens.Colors.appBackground)
    }

    func testCompactProgrammaticPagePushDisablesDefaultNavigationAnimation() {
        XCTAssertTrue(CompactPagePushAnimationPolicy.disablesProgrammaticPushAnimation)
    }

    func testCraftTableChromeUsesEmbeddedDocumentGridMetrics() {
        XCTAssertEqual(TableBlockChrome.cellWidth, 168)
        XCTAssertEqual(TableBlockChrome.cellHeight, 44)
        XCTAssertEqual(TableBlockChrome.maxViewportWidth, 520)
        XCTAssertEqual(TableBlockChrome.cornerRadius, 8)
        XCTAssertEqual(TableBlockChrome.gridLineOpacity, 0.070)
        XCTAssertEqual(TableBlockChrome.outerBorderOpacity, 0.120)
        XCTAssertEqual(TableBlockChrome.primaryControlDiameter, 18)
        XCTAssertEqual(TableBlockChrome.insertControlVisibleDiameter, 4)
        XCTAssertEqual(TableBlockChrome.insertControlExpandedDiameter, 10)
        XCTAssertEqual(TableBlockChrome.insertControlIconFontSize, 6)
        XCTAssertEqual(TableBlockChrome.insertControlEdgeOffset, 0)
        XCTAssertEqual(TableBlockChrome.insertControlIdleOpacity, 0.28)
        XCTAssertEqual(TableBlockChrome.insertControlHoverOpacity, 0.9)
        XCTAssertEqual(TableBlockChrome.selectorWidth, 8)
        XCTAssertEqual(TableBlockChrome.selectorHeight, 8)
        XCTAssertEqual(TableBlockChrome.selectorIndicatorOpacity, 0)
        XCTAssertEqual(TableBlockChrome.selectorHitOpacity, 0.0001)
        XCTAssertEqual(TableBlockChrome.selectorSelectedIndicatorOpacity, 0.38)
        XCTAssertEqual(TableBlockChrome.selectorSelectedIndicatorThickness, 1.5)
        XCTAssertEqual(TableBlockChrome.selectorSelectedIndicatorInset, 10)
    }

    func testSpecialBlockChromeUsesSemanticAdaptiveBackgroundTokens() {
        XCTAssertEqual(SpecialBlockSurfaceChrome.codeBackgroundToken, EditorDesignTokens.Colors.codeBlockBackground)
        XCTAssertEqual(SpecialBlockSurfaceChrome.calloutBackgroundToken, EditorDesignTokens.Colors.calloutBackground)
        XCTAssertEqual(SpecialBlockSurfaceChrome.quoteBackgroundToken, EditorDesignTokens.Colors.quoteBackground)
        XCTAssertEqual(SpecialBlockSurfaceChrome.attachmentBackgroundToken, EditorDesignTokens.Colors.attachmentBackground)
        XCTAssertEqual(SpecialBlockSurfaceChrome.drawingCanvasBackgroundToken, EditorDesignTokens.Colors.drawingCanvasBackground)
        XCTAssertEqual(TableBlockChrome.headerBackgroundToken, EditorDesignTokens.Colors.tableHeaderBackground)
        XCTAssertEqual(StatusChrome.warningTextToken, EditorDesignTokens.Colors.warningText)
        XCTAssertEqual(StatusChrome.warningFillToken, EditorDesignTokens.Colors.warningFill)
        XCTAssertEqual(StatusChrome.warningStrokeToken, EditorDesignTokens.Colors.warningStroke)
        XCTAssertEqual(ConflictDiffChrome.addedTextToken, EditorDesignTokens.Colors.successText)
        XCTAssertEqual(ConflictDiffChrome.addedFillToken, EditorDesignTokens.Colors.successFill)
        XCTAssertEqual(ConflictDiffChrome.removedTextToken, EditorDesignTokens.Colors.danger)
        XCTAssertEqual(ConflictDiffChrome.removedFillToken, EditorDesignTokens.Colors.dangerFill)
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

    func testTableViewportWidthShrinksToAvailableEditorWidth() {
        XCTAssertEqual(TableBlockChrome.viewportWidth(columnCount: 6, availableWidth: 320), 320)
        XCTAssertEqual(TableBlockChrome.viewportWidth(columnCount: 1, availableWidth: 320), TableBlockChrome.cellWidth)
        XCTAssertEqual(TableBlockChrome.viewportWidth(columnCount: 8, availableWidth: 720), TableBlockChrome.maxViewportWidth)
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
            0.3,
            "Selected rows and columns need a visible edge cue so border selection does not feel invisible"
        )
        XCTAssertLessThanOrEqual(
            TableBlockChrome.selectorSelectedIndicatorThickness,
            2,
            "Selected edge feedback should stay Craft-like and avoid heavy table bars"
        )
    }

    func testTableInsertControlChromeKeepsIdleDotQuietUntilHover() {
        XCTAssertLessThan(
            TableBlockChrome.insertControlIdleOpacity,
            TableBlockChrome.insertControlHoverOpacity,
            "Default table insert affordances should read as quiet dots until hover reveals the plus"
        )
        XCTAssertLessThanOrEqual(
            TableBlockChrome.gridLineOpacity,
            0.08,
            "Document tables should use readable but quiet grid lines instead of a heavy spreadsheet frame"
        )
        XCTAssertLessThanOrEqual(
            TableBlockChrome.outerBorderOpacity,
            0.12,
            "The table shell should stay subtle and embedded in the document"
        )
    }

    func testEmptyTableBlocksStartAsTwoByTwoDocumentGrid() {
        XCTAssertEqual(
            TableBlockDefaultGridResolver.editableRows(text: "", rows: []),
            [["", ""], ["", ""]]
        )
        XCTAssertEqual(
            TableBlockDefaultGridResolver.editableRows(text: "单元格", rows: []),
            [["单元格", ""], ["", ""]]
        )
        XCTAssertEqual(
            TableBlockDefaultGridResolver.editableRows(text: "", rows: [["已有"]]),
            [["已有"]]
        )
    }

    func testEmptyTableSnapshotsStartAsTwoByTwoDocumentGrid() {
        let block = BlockSnapshot(
            id: "table",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "a",
            type: .table,
            textPlain: ""
        )

        XCTAssertEqual(block.tableRows, [["", ""], ["", ""]])
    }

    func testTextConvertedToTableStartsAsTwoByTwoGridWithTextInFirstCell() {
        let block = BlockSnapshot(
            id: "table",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "a",
            type: .table,
            textPlain: "单元格"
        )

        XCTAssertEqual(block.tableRows, [["单元格", ""], ["", ""]])
    }

    func testMobileBlockSwipeResolverSeparatesCursorIndentingFromPanelNavigation() {
        XCTAssertEqual(
            MobileBlockSwipeActionResolver.action(
                translation: CGSize(width: -72, height: 8),
                isEditingBlock: false,
                nestingLevel: 0
            ),
            .selectBlock
        )
        XCTAssertEqual(
            MobileBlockSwipeActionResolver.action(
                translation: CGSize(width: 72, height: 8),
                isEditingBlock: false,
                nestingLevel: 0,
                isOutlinePresented: true
            ),
            .closeOutline
        )
        XCTAssertEqual(
            MobileBlockSwipeActionResolver.action(
                translation: CGSize(width: 72, height: 8),
                isEditingBlock: false,
                nestingLevel: 0
            ),
            .selectBlock
        )
        XCTAssertEqual(
            MobileBlockSwipeActionResolver.action(
                translation: CGSize(width: 72, height: 6),
                isEditingBlock: true,
                nestingLevel: 0,
                isOutlinePresented: true
            ),
            .closeOutline
        )
        XCTAssertEqual(
            MobileBlockSwipeActionResolver.action(
                translation: CGSize(width: 72, height: 6),
                isEditingBlock: true,
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
        XCTAssertNil(
            MobileBlockSwipeActionResolver.action(
                translation: CGSize(width: -72, height: 6),
                isEditingBlock: true,
                nestingLevel: 0
            )
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

    func testMobileRowSwipeGestureAttachmentKeepsTextAndStructuredBlocksSeparate() {
        XCTAssertEqual(
            MobileBlockRowSwipeGestureAttachmentResolver.attachment(usesNativeTextEditor: true),
            .nativeTextEditorOnly
        )
        XCTAssertEqual(
            MobileBlockRowSwipeGestureAttachmentResolver.attachment(usesNativeTextEditor: false),
            .rowHighPriority
        )
    }

    func testMobileCanvasTailSwipeRevealsPageListOnlyOnHorizontalRightSwipe() {
        XCTAssertEqual(
            MobileCanvasTailSwipeActionResolver.action(translation: CGSize(width: 72, height: 8)),
            .revealPageList
        )
        XCTAssertNil(MobileCanvasTailSwipeActionResolver.action(translation: CGSize(width: -72, height: 8)))
        XCTAssertNil(MobileCanvasTailSwipeActionResolver.action(translation: CGSize(width: 40, height: 4)))
        XCTAssertNil(MobileCanvasTailSwipeActionResolver.action(translation: CGSize(width: 72, height: 72)))
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

    func testMobileBlockTapSelectsRowsInsteadOfFocusingCursorDuringSelectionMode() {
        XCTAssertEqual(
            MobileBlockTapActionResolver.action(isSelectionModeActive: true),
            .toggleBlockSelection
        )
        XCTAssertEqual(
            MobileBlockTapActionResolver.action(isSelectionModeActive: false),
            .focusCursor
        )
    }

    func testMobileBlockSelectionDragOnlyRunsAfterSelectionModeStarts() {
        XCTAssertFalse(
            MobileBlockSelectionDragPolicy.isEnabled(isSelectionModeActive: false)
        )
        XCTAssertTrue(
            MobileBlockSelectionDragPolicy.isEnabled(isSelectionModeActive: true)
        )
    }

    func testBlockSelectionRangeResolverSelectsContiguousVisibleBlocks() {
        let visibleBlockIDs = ["first", "second", "third", "fourth"]

        XCTAssertEqual(
            BlockSelectionRangeResolver.selection(
                anchorBlockID: "second",
                targetBlockID: "fourth",
                visibleBlockIDs: visibleBlockIDs
            ),
            ["second", "third", "fourth"]
        )
        XCTAssertEqual(
            BlockSelectionRangeResolver.selection(
                anchorBlockID: "third",
                targetBlockID: "first",
                visibleBlockIDs: visibleBlockIDs
            ),
            ["first", "second", "third"]
        )
        XCTAssertTrue(
            BlockSelectionRangeResolver.selection(
                anchorBlockID: "missing",
                targetBlockID: "first",
                visibleBlockIDs: visibleBlockIDs
            ).isEmpty
        )
    }

    func testBlockSelectionRangeResolverExtendsSelectionFromEdges() {
        let visibleBlockIDs = ["first", "second", "third", "fourth"]

        XCTAssertEqual(
            BlockSelectionRangeResolver.selectionAfterExtending(
                from: "second",
                direction: .next,
                currentSelection: [],
                visibleBlockIDs: visibleBlockIDs
            ),
            ["second", "third"]
        )
        XCTAssertEqual(
            BlockSelectionRangeResolver.selectionAfterExtending(
                from: "second",
                direction: .next,
                currentSelection: ["second", "third"],
                visibleBlockIDs: visibleBlockIDs
            ),
            ["second", "third", "fourth"]
        )
        XCTAssertEqual(
            BlockSelectionRangeResolver.selectionAfterExtending(
                from: "third",
                direction: .previous,
                currentSelection: ["second", "third"],
                visibleBlockIDs: visibleBlockIDs
            ),
            ["first", "second", "third"]
        )
    }

    func testPageListSelectionRangeResolverSelectsContiguousVisiblePages() {
        let visiblePageIDs = ["first", "second", "third", "fourth"]

        XCTAssertEqual(
            PageListSelectionRangeResolver.selection(
                anchorPageID: "second",
                targetPageID: "fourth",
                visiblePageIDs: visiblePageIDs
            ),
            ["second", "third", "fourth"]
        )
        XCTAssertEqual(
            PageListSelectionRangeResolver.selection(
                anchorPageID: "third",
                targetPageID: "first",
                visiblePageIDs: visiblePageIDs
            ),
            ["first", "second", "third"]
        )
        XCTAssertTrue(
            PageListSelectionRangeResolver.selection(
                anchorPageID: "missing",
                targetPageID: "first",
                visiblePageIDs: visiblePageIDs
            ).isEmpty
        )
    }

    func testPageListSelectAllResolverStaysInsideVisibleScope() {
        XCTAssertEqual(
            PageListSelectAllResolver.selection(visiblePageIDs: ["tag-a", "tag-b"]),
            ["tag-a", "tag-b"],
            "Cmd+A in a tag collection should select only the pages visible in that tag scope."
        )
        XCTAssertEqual(PageListSelectAllResolver.selection(visiblePageIDs: []), [])
    }

    func testPageListMarqueeSelectsPagesIntersectingSelectionRectInVisibleOrder() {
        let visiblePageIDs = ["first", "second", "third"]
        let pageFrames: [String: CGRect] = [
            "first": CGRect(x: 18, y: 40, width: 320, height: 72),
            "second": CGRect(x: 18, y: 120, width: 320, height: 72),
            "third": CGRect(x: 18, y: 200, width: 320, height: 72)
        ]

        XCTAssertEqual(
            PageListMarqueeSelectionResolver.selectedPageIDs(
                selectionRect: CGRect(x: 40, y: 110, width: 120, height: 100),
                pageFrames: pageFrames,
                visiblePageIDs: visiblePageIDs
            ),
            ["first", "second", "third"]
        )
        XCTAssertEqual(
            PageListMarqueeSelectionResolver.selectedPageIDs(
                selectionRect: CGRect(x: 360, y: 110, width: 80, height: 100),
                pageFrames: pageFrames,
                visiblePageIDs: visiblePageIDs
            ),
            []
        )
    }

    func testPageListMarqueeStartUsesGapsInsteadOfRowsSoDragRowsStillDrag() {
        let pageFrames = [
            "first": CGRect(x: 18, y: 40, width: 320, height: 72)
        ]

        XCTAssertFalse(
            PageListMarqueeStartPolicy.isAllowed(
                location: CGPoint(x: 40, y: 60),
                pageFrames: pageFrames
            ),
            "Starting on a page row must keep the existing row drag behavior."
        )
        XCTAssertTrue(
            PageListMarqueeStartPolicy.isAllowed(
                location: CGPoint(x: 40, y: 118),
                pageFrames: pageFrames
            )
        )
    }

    func testPageListKeyboardShortcutResolverScopesSelectAllShiftReturnAndDeleteArchive() {
        XCTAssertEqual(
            PageListKeyboardShortcutActionResolver.action(
                keyCode: 0,
                input: "a",
                modifiers: [.command],
                hasVisiblePages: true,
                hasArchiveTargets: false,
                isTextEditing: false
            ),
            .selectAllVisiblePages
        )
        XCTAssertEqual(
            PageListKeyboardShortcutActionResolver.action(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                input: "\r",
                modifiers: [.shift],
                hasVisiblePages: true,
                hasArchiveTargets: false,
                isTextEditing: false
            ),
            .selectRangeToSelectedPage
        )
        XCTAssertEqual(
            PageListKeyboardShortcutActionResolver.action(
                keyCode: PageListKeyboardShortcutActionResolver.deleteBackwardKeyCode,
                input: nil,
                modifiers: [],
                hasVisiblePages: true,
                hasArchiveTargets: true,
                isTextEditing: false
            ),
            .archiveSelectedPages
        )
        XCTAssertEqual(
            PageListKeyboardShortcutActionResolver.action(
                keyCode: PageListKeyboardShortcutActionResolver.deleteForwardKeyCode,
                input: nil,
                modifiers: [],
                hasVisiblePages: true,
                hasArchiveTargets: true,
                isTextEditing: false
            ),
            .archiveSelectedPages
        )
        XCTAssertNil(
            PageListKeyboardShortcutActionResolver.action(
                keyCode: PageListKeyboardShortcutActionResolver.deleteBackwardKeyCode,
                input: nil,
                modifiers: [],
                hasVisiblePages: true,
                hasArchiveTargets: false,
                isTextEditing: false
            ),
            "Delete should only archive when the middle column has a selected row target."
        )
        XCTAssertNil(
            PageListKeyboardShortcutActionResolver.action(
                keyCode: 0,
                input: "a",
                modifiers: [.command],
                hasVisiblePages: true,
                hasArchiveTargets: false,
                isTextEditing: true
            ),
            "Text editing keeps Cmd+A for text/block selection instead of stealing it for the middle list."
        )
    }

    func testPageRowChromeRemovesLeadingDocumentIconAndShowsStatusBadges() {
        let page = PageSummary(
            id: "page-pinned-favorite",
            workspaceID: "workspace",
            title: "Pinned Favorite",
            isFavorite: true,
            isPinned: true,
            isEncrypted: true
        )

        XCTAssertFalse(PageRowLeadingGlyphPolicy.showsDocumentIcon)
        XCTAssertEqual(
            PageRowStatusBadgeModel.badges(for: page).map(\.accessibilityLabel),
            ["已置顶", "已收藏", "已加密"]
        )
    }

    func testPageRowSwipeActionsIncludeArchiveFavoriteAndPin() {
        let page = PageSummary(
            id: "page-actions",
            workspaceID: "workspace",
            title: "Actions",
            isFavorite: false,
            isPinned: false
        )

        XCTAssertEqual(
            PageRowSwipeActionModel.actions(for: page).map(\.kind),
            [.archive, .favorite, .pin]
        )
        XCTAssertEqual(
            PageRowSwipeActionModel.actions(for: page).map(\.title),
            ["归档", "收藏", "置顶"]
        )

        let pinnedFavorite = PageSummary(
            id: "page-actions-on",
            workspaceID: "workspace",
            title: "Actions On",
            isFavorite: true,
            isPinned: true
        )

        XCTAssertEqual(
            PageRowSwipeActionModel.actions(for: pinnedFavorite).map(\.title),
            ["归档", "取消收藏", "取消置顶"]
        )
    }

    func testPageListRowActionTargetResolverUsesBatchSelectionWhenRowIsSelected() {
        XCTAssertEqual(
            PageListRowActionTargetResolver.pageIDs(
                rowPageID: "second",
                selectedPageIDs: ["third", "second"],
                visiblePageIDs: ["first", "second", "third"]
            ),
            ["second", "third"]
        )
        XCTAssertEqual(
            PageListRowActionTargetResolver.pageIDs(
                rowPageID: "first",
                selectedPageIDs: ["third", "second"],
                visiblePageIDs: ["first", "second", "third"]
            ),
            ["first"]
        )
    }

    func testCompactPageSwipeActionsUseLighterPlayfulBearLikeChrome() {
        XCTAssertEqual(CompactPageSwipeActionChrome.actionWidth, 62)
        XCTAssertEqual(CompactPageSwipeActionChrome.actionHeight, CompactDocumentListChrome.rowMinHeight)
        XCTAssertEqual(CompactPageSwipeActionChrome.cornerRadius, 14)
        XCTAssertEqual(CompactPageSwipeActionChrome.iconSize, 21)
        XCTAssertEqual(CompactPageSwipeActionChrome.iconWeight, .medium)
        XCTAssertEqual(CompactPageSwipeActionChrome.releaseSpringResponse, 0.28)
        XCTAssertEqual(CompactPageSwipeActionChrome.releaseSpringDampingFraction, 0.72)
        XCTAssertEqual(CompactPageSwipeActionChrome.releaseSpringBlendDuration, 0.08)
        assertColor(CompactPageSwipeActionChrome.colorToken(for: .archive), red: 0xEF, green: 0x6F, blue: 0x63)
        assertColor(CompactPageSwipeActionChrome.colorToken(for: .favorite), red: 0xF1, green: 0xC9, blue: 0x55)
        assertColor(CompactPageSwipeActionChrome.colorToken(for: .pin), red: 0x7D, green: 0x97, blue: 0xE8)
    }

    func testCompactPageSwipeRevealPolicyShrinksWidthOnlyBeforeFadingOut() {
        let maximumRevealWidth = CompactPageSwipeActionChrome.actionWidth * 3
        let partiallyVisibleWidth: CGFloat = 40

        XCTAssertEqual(
            CompactPageSwipeRevealPolicy.visibleWidth(horizontalOffset: -partiallyVisibleWidth, maximumRevealWidth: maximumRevealWidth),
            partiallyVisibleWidth
        )
        XCTAssertEqual(
            CompactPageSwipeRevealPolicy.visibleWidth(horizontalOffset: -maximumRevealWidth, maximumRevealWidth: maximumRevealWidth),
            maximumRevealWidth
        )
        XCTAssertEqual(CompactPageSwipeRevealPolicy.minimumActionWidthScale, 0.62)
        XCTAssertEqual(CompactPageSwipeRevealPolicy.fadeSlideDistance, 18)
        XCTAssertEqual(
            CompactPageSwipeRevealPolicy.actionWidthScale(visibleWidth: partiallyVisibleWidth, maximumRevealWidth: maximumRevealWidth),
            CompactPageSwipeRevealPolicy.minimumActionWidthScale,
            accuracy: 0.001
        )
        XCTAssertEqual(
            CompactPageSwipeRevealPolicy.actionGroupWidth(visibleWidth: partiallyVisibleWidth, maximumRevealWidth: maximumRevealWidth),
            maximumRevealWidth * CompactPageSwipeRevealPolicy.minimumActionWidthScale,
            accuracy: 0.001
        )
        XCTAssertEqual(
            CompactPageSwipeRevealPolicy.actionHeight(visibleWidth: partiallyVisibleWidth),
            CompactPageSwipeActionChrome.actionHeight,
            accuracy: 0.001
        )
        XCTAssertEqual(
            CompactPageSwipeRevealPolicy.cornerRadius(visibleWidth: partiallyVisibleWidth),
            CompactPageSwipeActionChrome.cornerRadius,
            accuracy: 0.001
        )
        XCTAssertEqual(
            CompactPageSwipeRevealPolicy.iconScale(visibleWidth: partiallyVisibleWidth, maximumRevealWidth: maximumRevealWidth),
            CompactPageSwipeRevealPolicy.minimumActionWidthScale,
            accuracy: 0.001
        )
        XCTAssertLessThan(
            CompactPageSwipeRevealPolicy.opacity(visibleWidth: partiallyVisibleWidth, maximumRevealWidth: maximumRevealWidth),
            1
        )
        XCTAssertEqual(
            CompactPageSwipeRevealPolicy.trailingOffset(visibleWidth: maximumRevealWidth, maximumRevealWidth: maximumRevealWidth),
            0,
            accuracy: 0.001
        )
        XCTAssertGreaterThan(
            CompactPageSwipeRevealPolicy.trailingOffset(visibleWidth: partiallyVisibleWidth, maximumRevealWidth: maximumRevealWidth),
            0
        )
        XCTAssertEqual(CompactPageSwipeRevealPolicy.openThresholdRatio, 0.42)
        XCTAssertEqual(CompactPageSwipeRevealPolicy.closeThresholdRatio, 0.58)
        XCTAssertFalse(
            CompactPageSwipeRevealPolicy.shouldStayOpen(
                startOffset: 0,
                translationWidth: -40,
                projectedOffset: -40,
                maximumRevealWidth: maximumRevealWidth
            ),
            "A small left drag should reveal partially instead of snapping the whole action group open."
        )
        XCTAssertTrue(
            CompactPageSwipeRevealPolicy.shouldStayOpen(
                startOffset: 0,
                translationWidth: -120,
                projectedOffset: -120,
                maximumRevealWidth: maximumRevealWidth
            )
        )
    }

    func testCompactPageSwipeRevealPolicyOnlyTracksIntentionalHorizontalReveal() {
        XCTAssertFalse(
            CompactPageSwipeRevealPolicy.shouldTrackDrag(
                translation: CGSize(width: -24, height: 22),
                currentOffset: 0
            ),
            "Diagonal drags in the list should keep vertical scrolling responsive."
        )
        XCTAssertFalse(
            CompactPageSwipeRevealPolicy.shouldTrackDrag(
                translation: CGSize(width: 42, height: 4),
                currentOffset: 0
            ),
            "A closed row should not track right drags; those belong to navigation or vertical scrolling."
        )
        XCTAssertTrue(
            CompactPageSwipeRevealPolicy.shouldTrackDrag(
                translation: CGSize(width: -54, height: 12),
                currentOffset: 0
            )
        )
        XCTAssertTrue(
            CompactPageSwipeRevealPolicy.shouldTrackDrag(
                translation: CGSize(width: 32, height: 6),
                currentOffset: -CompactPageSwipeActionChrome.actionWidth
            ),
            "An already open row still needs right drags so the user can close the actions."
        )
    }

    func testIOSInteractivePopGesturePolicyAllowsPageDepthPopEvenWhenBackButtonIsHidden() {
        XCTAssertFalse(IOSInteractivePopGesturePolicy.shouldBegin(isEnabled: false, navigationDepth: 2))
        XCTAssertFalse(IOSInteractivePopGesturePolicy.shouldBegin(isEnabled: true, navigationDepth: 1))
        XCTAssertTrue(
            IOSInteractivePopGesturePolicy.shouldBegin(isEnabled: true, navigationDepth: 2),
            "The compact editor hides the system back button, so the edge-swipe bridge must not inherit SwiftUI's disabled delegate decision."
        )
    }

    func testArchiveUndoVisibilityStaysOutOfSearchAndArchiveSections() {
        XCTAssertFalse(
            ArchiveUndoVisibilityPolicy.isVisible(canUndoPageArchive: true, selectedCollection: .search),
            "Search results should not keep showing an unrelated archive undo action."
        )
        XCTAssertFalse(
            ArchiveUndoVisibilityPolicy.isVisible(canUndoPageArchive: true, selectedCollection: .archive)
        )
        XCTAssertTrue(
            ArchiveUndoVisibilityPolicy.isVisible(canUndoPageArchive: true, selectedCollection: .recent)
        )
        XCTAssertFalse(
            ArchiveUndoVisibilityPolicy.isVisible(canUndoPageArchive: false, selectedCollection: .recent)
        )
    }

    func testEditorPendingBlockFocusSchedulePolicyRetriesAfterPageChange() {
        XCTAssertFalse(
            EditorPendingBlockFocusSchedulePolicy.shouldSchedule(
                blockID: "today-empty",
                existingRequestBlockID: "today-empty",
                requestID: nil,
                reason: .pendingValueChanged
            ),
            "A repeated pending value without a fresh request should not churn focus."
        )
        XCTAssertTrue(
            EditorPendingBlockFocusSchedulePolicy.shouldSchedule(
                blockID: "today-empty",
                existingRequestBlockID: "today-empty",
                requestID: nil,
                reason: .pageChanged
            ),
            "After Cmd+R changes from a normal document to today's diary, the canvas must retry the pending focus once the new rows are mounted."
        )
        XCTAssertTrue(
            EditorPendingBlockFocusSchedulePolicy.shouldSchedule(
                blockID: "today-empty",
                existingRequestBlockID: "today-empty",
                requestID: UUID(),
                reason: .pendingValueChanged
            )
        )
        XCTAssertTrue(
            EditorPendingBlockFocusSchedulePolicy.shouldSchedule(
                blockID: "today-empty",
                existingRequestBlockID: "today-empty",
                requestID: nil,
                reason: .retry
            ),
            "A retry tick should be allowed to re-issue focus even when the previous request targeted the same block."
        )
    }

    func testBlockSelectionMarqueeRectNormalizesAnyDragDirection() {
        XCTAssertEqual(
            BlockSelectionMarqueeRectResolver.rect(
                start: CGPoint(x: 180, y: 220),
                current: CGPoint(x: 80, y: 100)
            ),
            CGRect(x: 80, y: 100, width: 100, height: 120)
        )
        XCTAssertTrue(
            BlockSelectionMarqueeRectResolver.isVisible(
                CGRect(x: 0, y: 0, width: 2, height: 2)
            )
        )
        XCTAssertFalse(
            BlockSelectionMarqueeRectResolver.isVisible(
                CGRect(x: 0, y: 0, width: 1, height: 0.5)
            )
        )
    }

    func testBlockSelectionMarqueeSelectsBlocksIntersectingBlueAreaInVisibleOrder() {
        let visibleBlockIDs = ["first", "second", "third"]
        let blockFrames: [String: CGRect] = [
            "first": CGRect(x: 40, y: 40, width: 400, height: 24),
            "second": CGRect(x: 40, y: 80, width: 400, height: 24),
            "third": CGRect(x: 40, y: 120, width: 400, height: 24)
        ]

        XCTAssertEqual(
            BlockSelectionMarqueeSelectionResolver.selectedBlockIDs(
                selectionRect: CGRect(x: 160, y: 70, width: 80, height: 68),
                blockFrames: blockFrames,
                visibleBlockIDs: visibleBlockIDs
            ),
            ["second", "third"]
        )
        XCTAssertEqual(
            BlockSelectionMarqueeSelectionResolver.selectedBlockIDs(
                selectionRect: CGRect(x: 470, y: 70, width: 80, height: 68),
                blockFrames: blockFrames,
                visibleBlockIDs: visibleBlockIDs
            ),
            []
        )
    }

    func testBlockSelectionMarqueeChromeMatchesCraftBlueArea() {
        XCTAssertEqual(BlockSelectionMarqueeChrome.fillOpacity, 0.10)
        XCTAssertEqual(BlockSelectionMarqueeChrome.strokeOpacity, 0.42)
        XCTAssertEqual(BlockSelectionMarqueeChrome.strokeWidth, 1)
        XCTAssertEqual(BlockSelectionMarqueeChrome.cornerRadius, 4)
        XCTAssertEqual(BlockSelectionMarqueeChrome.minimumVisibleDimension, 2)
    }

    func testBlockSelectionMarqueeStartIgnoresHandles() {
        let blockFrames = [
            "image": CGRect(x: 40, y: 80, width: 520, height: 260)
        ]
        let resizeHandleFrame = CGRect(x: 522, y: 300, width: 30, height: 30)

        XCTAssertFalse(
            BlockSelectionMarqueeStartPolicy.isAllowed(
                location: CGPoint(x: 48, y: 120),
                blockFrames: blockFrames,
                blockedInteractionFrames: [resizeHandleFrame]
            ),
            "Dragging the block action column should keep using block drag/reorder, not marquee selection."
        )
        XCTAssertFalse(
            BlockSelectionMarqueeStartPolicy.isAllowed(
                location: CGPoint(x: 536, y: 314),
                blockFrames: blockFrames,
                blockedInteractionFrames: [resizeHandleFrame]
            ),
            "Dragging the image resize handle must not also start canvas marquee selection."
        )
        XCTAssertTrue(
            BlockSelectionMarqueeStartPolicy.isAllowed(
                location: CGPoint(x: 420, y: 314),
                blockFrames: blockFrames,
                blockedInteractionFrames: [resizeHandleFrame]
            )
        )
    }

    func testBlockSelectionMarqueeBlockedFramesIncludeMediaAttachmentRows() {
        let imageBlock = BlockSnapshot(
            id: "image",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "1",
            type: .attachmentImage,
            textPlain: "cover.png"
        )
        let videoBlock = BlockSnapshot(
            id: "video",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "2",
            type: .attachmentVideo,
            textPlain: "clip.mov"
        )
        let fileBlock = BlockSnapshot(
            id: "file",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "3",
            type: .attachmentFile,
            textPlain: "guide.pdf"
        )
        let imageFrame = CGRect(x: 40, y: 80, width: 520, height: 260)
        let videoFrame = CGRect(x: 40, y: 360, width: 520, height: 220)
        let fileFrame = CGRect(x: 40, y: 360, width: 520, height: 64)

        XCTAssertEqual(
            BlockSelectionMarqueeInteractionFrameResolver.blockedFrames(
                blocks: [imageBlock, videoBlock, fileBlock],
                blockFrames: [
                    imageBlock.id: imageFrame,
                    videoBlock.id: videoFrame,
                    fileBlock.id: fileFrame
                ]
            ),
            [imageFrame, videoFrame]
        )
    }

    func testMobileActionChromeUsesThemeAccentInsteadOfSystemBlue() {
        assertColor(
            MobileActionChrome.accentToken,
            red: 0xE5,
            green: 0x45,
            blue: 0x4F
        )
        XCTAssertEqual(MobileActionChrome.selectedFillOpacity, 0.12)
        XCTAssertEqual(MobileActionChrome.selectedButtonFillOpacity, 0.13)
        XCTAssertEqual(MobileActionChrome.selectionBorderOpacity, 0.24)
    }

    func testMobileQuickCreateButtonUsesPencilGlyphLikeBear() {
        XCTAssertEqual(MobileQuickCreateButtonChrome.iconSystemName, "pencil")
        XCTAssertEqual(MobileQuickCreateButtonChrome.diameter, 54)
        XCTAssertEqual(MobileQuickCreateButtonChrome.iconSize, 23)
        XCTAssertEqual(MobileQuickCreateButtonChrome.shadowOpacity, 0.16)
    }

    func testMobileKeyboardToolbarChromeIsLowerAndLighterWeight() {
        XCTAssertEqual(MobileKeyboardToolbarChrome.height, 44)
        XCTAssertEqual(MobileKeyboardToolbarChrome.buttonSize, 34)
        XCTAssertEqual(MobileKeyboardToolbarChrome.iconSize, 19)
        XCTAssertEqual(MobileKeyboardToolbarChrome.primaryIconWeight, .regular)
        XCTAssertEqual(MobileKeyboardToolbarChrome.secondaryIconWeight, .medium)
    }

    func testMobileKeyboardToolbarPrioritizesListAndHeadingFormatActions() {
        XCTAssertEqual(
            MobileKeyboardToolbarFormatActionResolver.visibleActions,
            [.unorderedList, .orderedList, .heading]
        )
    }

    func testMobileKeyboardToolbarReplacesCopyWithDismissKeyboard() {
        XCTAssertEqual(
            MobileKeyboardToolbarUtilityActionResolver.visibleActions,
            [.paste, .undo]
        )
        XCTAssertFalse(MobileKeyboardToolbarUtilityActionResolver.visibleActions.contains(.copy))
        XCTAssertTrue(MobileKeyboardToolbarTrailingActionResolver.visibleActions.contains(.dismissKeyboard))
    }

    func testMobileFormatPaletteOmitsRedundantCraftTabs() {
        XCTAssertTrue(MobileFormatPaletteTabResolver.visibleTabs.isEmpty)
    }

    func testMobileFormatPaletteUsesSingleBearStyleGrid() {
        XCTAssertEqual(MobileFormatPaletteChrome.columnCount, 6)
        XCTAssertEqual(MobileFormatPaletteChrome.buttonHeight, 62)
        XCTAssertGreaterThan(NativeTextEditorLayout.keyboardFormatPanelHeight, 300)
        XCTAssertEqual(
            Array(MobileFormatPaletteActionResolver.visibleActions.prefix(6)),
            [.collapsePanel, .paragraph, .table, .quote, .codeBlock, .callout]
        )
    }

    func testMobileFormatPaletteIncludesSupportedFormatsAndOmitsUnsupportedFillers() {
        let actions = MobileFormatPaletteActionResolver.visibleActions

        XCTAssertEqual(
            actions.compactMap(\.blockType),
            [
                .paragraph,
                .table,
                .quote,
                .codeBlock,
                .callout,
                .heading1,
                .unorderedListItem,
                .orderedListItem,
                .taskItem,
                .toggle,
                .divider,
                .heading2,
                .heading3,
                .heading4,
                .heading5,
                .heading6
            ]
        )
        XCTAssertEqual(actions.compactMap(\.inlineFormat), [.bold, .italic, .strikethrough, .code])
        XCTAssertTrue(actions.contains(.insertLink))
        XCTAssertTrue(actions.contains(.indent))
        XCTAssertTrue(actions.contains(.outdent))
        XCTAssertTrue(actions.contains(.dismissKeyboard))

        let labels = Set(actions.map(\.accessibilityLabel))
        XCTAssertTrue(labels.contains("H4"))
        XCTAssertTrue(labels.contains("H5"))
        XCTAssertTrue(labels.contains("H6"))
        XCTAssertFalse(labels.contains("下划线"))
        XCTAssertFalse(labels.contains("颜色"))
        XCTAssertFalse(labels.contains("高亮"))
        XCTAssertFalse(labels.contains("日历"))
        XCTAssertFalse(labels.contains("拍照"))
    }

    func testDesktopAuxiliaryRailButtonStaysHiddenAfterRightRailRemoval() {
        XCTAssertFalse(
            DesktopAuxiliaryRailButtonPolicy.isOffered(
                showsAuxiliaryRail: true,
                displayMode: .standard
            )
        )
        XCTAssertFalse(
            DesktopAuxiliaryRailButtonPolicy.isOffered(
                showsAuxiliaryRail: false,
                displayMode: .standard
            )
        )
        XCTAssertFalse(
            DesktopAuxiliaryRailButtonPolicy.isOffered(
                showsAuxiliaryRail: true,
                displayMode: .focus
            )
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

    func testCompactShellScreenOrderDefaultsToEditorAsThirdScreen() {
        XCTAssertEqual(CompactShellScreen.library.rawValue, 1)
        XCTAssertEqual(CompactShellScreen.documentList.rawValue, 2)
        XCTAssertEqual(CompactShellScreen.editor.rawValue, 3)
        XCTAssertEqual(CompactShellRoutePlanner.defaultActiveScreen, .editor)
    }

    func testCompactShellInitialPathRoutesDirectlyToEditorForColdLaunchSpeed() {
        let workspaceID = "workspace"
        let page = PageSummary(id: "page-a", workspaceID: workspaceID, title: "A")
        let snapshot = WorkspaceSnapshot(
            workspaces: [WorkspaceSummary(id: workspaceID, name: "空间")],
            pages: [page],
            blocks: [],
            attachments: [],
            selectedWorkspaceID: workspaceID,
            selectedPageID: page.id
        )

        XCTAssertEqual(
            CompactShellRoutePlanner.initialPath(snapshot: snapshot, selectedCollection: .recent),
            [.page(page.id)]
        )
    }

    func testCompactShellInitialPathUsesRuntimeSelectionDirectlyWhenSnapshotSelectionIsStale() {
        let workspaceID = "workspace"
        let stalePage = PageSummary(id: "page-stale", workspaceID: workspaceID, title: "Stale")
        let diaryPage = PageSummary(id: "page-diary", workspaceID: workspaceID, title: "Diary")
        let snapshot = WorkspaceSnapshot(
            workspaces: [WorkspaceSummary(id: workspaceID, name: "空间")],
            pages: [stalePage, diaryPage],
            blocks: [],
            attachments: [],
            diaryPages: [
                DiaryPageSnapshot(
                    pageID: diaryPage.id,
                    workspaceID: workspaceID,
                    diaryDate: "2026-05-22"
                )
            ],
            selectedWorkspaceID: workspaceID,
            selectedPageID: stalePage.id
        )

        XCTAssertEqual(
            CompactShellRoutePlanner.initialPath(
                snapshot: snapshot,
                selectedPageID: diaryPage.id,
                selectedCollection: .diary
            ),
            [.page(diaryPage.id)]
        )
    }

    func testCompactShellOnAppearInitialPendingPageSkipsDocumentListForColdLaunchSpeed() {
        let workspaceID = "workspace"
        let diaryPage = PageSummary(id: "page-diary", workspaceID: workspaceID, title: "Diary")
        let snapshot = WorkspaceSnapshot(
            workspaces: [WorkspaceSummary(id: workspaceID, name: "空间")],
            pages: [diaryPage],
            blocks: [],
            attachments: [],
            diaryPages: [
                DiaryPageSnapshot(
                    pageID: diaryPage.id,
                    workspaceID: workspaceID,
                    diaryDate: "2026-05-22"
                )
            ],
            selectedWorkspaceID: workspaceID,
            selectedPageID: diaryPage.id
        )

        XCTAssertEqual(
            CompactShellPendingNavigationPlanner.onAppearPath(
                snapshot: snapshot,
                selectedPageID: diaryPage.id,
                selectedCollection: .diary,
                pendingCollection: nil,
                pendingPageID: diaryPage.id,
                didPushInitialPage: false
            ),
            [.page(diaryPage.id)]
        )
    }

    func testCompactShellOnAppearConsumesPendingPageEvenAfterInitialPathWasPushed() {
        let workspaceID = "workspace"
        let currentPage = PageSummary(id: "page-current", workspaceID: workspaceID, title: "Current")
        let diaryPage = PageSummary(id: "page-diary", workspaceID: workspaceID, title: "Diary")
        let snapshot = WorkspaceSnapshot(
            workspaces: [WorkspaceSummary(id: workspaceID, name: "空间")],
            pages: [currentPage, diaryPage],
            blocks: [],
            attachments: [],
            diaryPages: [
                DiaryPageSnapshot(
                    pageID: diaryPage.id,
                    workspaceID: workspaceID,
                    diaryDate: "2026-05-22"
                )
            ],
            selectedWorkspaceID: workspaceID,
            selectedPageID: currentPage.id
        )

        XCTAssertEqual(
            CompactShellPendingNavigationPlanner.onAppearPath(
                snapshot: snapshot,
                selectedPageID: currentPage.id,
                selectedCollection: .recent,
                pendingCollection: nil,
                pendingPageID: diaryPage.id,
                didPushInitialPage: true
            ),
            [.collection(.diary), .page(diaryPage.id)]
        )
    }

    func testCompactShellOnAppearPrefersPendingCollectionOverStalePendingPage() {
        let workspaceID = "workspace"
        let diaryPage = PageSummary(id: "page-diary", workspaceID: workspaceID, title: "Diary")
        let snapshot = WorkspaceSnapshot(
            workspaces: [WorkspaceSummary(id: workspaceID, name: "空间")],
            pages: [diaryPage],
            blocks: [],
            attachments: [],
            diaryPages: [
                DiaryPageSnapshot(
                    pageID: diaryPage.id,
                    workspaceID: workspaceID,
                    diaryDate: "2026-05-22"
                )
            ],
            selectedWorkspaceID: workspaceID,
            selectedPageID: diaryPage.id
        )

        XCTAssertEqual(
            CompactShellPendingNavigationPlanner.onAppearPath(
                snapshot: snapshot,
                selectedPageID: diaryPage.id,
                selectedCollection: .diary,
                pendingCollection: .search,
                pendingPageID: diaryPage.id,
                didPushInitialPage: true
            ),
            [.collection(.allDocuments)]
        )
    }

    func testCompactShellRevealPageListUsesCurrentDocumentCollection() {
        XCTAssertEqual(
            CompactShellRoutePlanner.documentListRoute(selectedCollection: .favorites),
            .collection(.favorites)
        )
        XCTAssertEqual(
            CompactShellRoutePlanner.documentListRoute(selectedCollection: .recent),
            .collection(.allDocuments)
        )
    }

    func testCompactShellRevealPageListFindsOwningCollectionAfterDirectEditorLaunch() {
        let workspaceID = "workspace"
        let diaryPage = PageSummary(id: "page-diary", workspaceID: workspaceID, title: "Diary")
        let snapshot = WorkspaceSnapshot(
            workspaces: [WorkspaceSummary(id: workspaceID, name: "空间")],
            pages: [diaryPage],
            blocks: [],
            attachments: [],
            diaryPages: [
                DiaryPageSnapshot(
                    pageID: diaryPage.id,
                    workspaceID: workspaceID,
                    diaryDate: "2026-05-22"
                )
            ],
            selectedWorkspaceID: workspaceID,
            selectedPageID: diaryPage.id
        )

        XCTAssertEqual(
            CompactShellRoutePlanner.documentListPathForPage(
                diaryPage.id,
                snapshot: snapshot,
                selectedCollection: .recent
            ),
            [.collection(.diary)]
        )
    }

    func testCompactShellPathCanStepBackOneColumnAtATimeForSwipeNavigation() {
        XCTAssertEqual(
            CompactShellRoutePlanner.previousScreenPath(
                currentPath: [.collection(.allDocuments), .page("page-a")]
            ),
            [.collection(.allDocuments)]
        )
        XCTAssertEqual(
            CompactShellRoutePlanner.previousScreenPath(
                currentPath: [.collection(.allDocuments)]
            ),
            []
        )
        XCTAssertEqual(
            CompactShellRoutePlanner.previousScreenPath(currentPath: []),
            []
        )
    }

    func testCompactShellPathCanStepForwardOneColumnAtATimeForSwipeNavigation() {
        let workspaceID = "workspace"
        let page = PageSummary(id: "page-a", workspaceID: workspaceID, title: "A")
        let snapshot = WorkspaceSnapshot(
            workspaces: [WorkspaceSummary(id: workspaceID, name: "空间")],
            pages: [page],
            blocks: [],
            attachments: [],
            selectedWorkspaceID: workspaceID,
            selectedPageID: page.id
        )

        XCTAssertEqual(
            CompactShellRoutePlanner.nextScreenPath(
                currentPath: [],
                snapshot: snapshot,
                selectedCollection: .recent
            ),
            [.collection(.allDocuments)]
        )
        XCTAssertEqual(
            CompactShellRoutePlanner.nextScreenPath(
                currentPath: [.collection(.allDocuments)],
                snapshot: snapshot,
                selectedCollection: .recent
            ),
            [.collection(.allDocuments), .page(page.id)]
        )
        XCTAssertEqual(
            CompactShellRoutePlanner.nextScreenPath(
                currentPath: [.collection(.allDocuments), .page(page.id)],
                snapshot: snapshot,
                selectedCollection: .recent
            ),
            [.collection(.allDocuments), .page(page.id)]
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

    func testTableSelectionClearsOnExternalInteraction() {
        let selection = TableSelection(rows: [0], columns: [1])

        XCTAssertEqual(
            TableSelectionReducer.selectionAfterExternalInteraction(selection),
            .empty
        )
    }

    func testDropTargetLifecycleClearsWhenEditorReceivesNormalInteraction() {
        let target = BlockDropTarget(blockID: "block-a", placement: .after)

        XCTAssertNil(BlockDropTargetLifecycleReducer.targetAfterEditorInteraction(current: target))
        XCTAssertNil(BlockDropTargetLifecycleReducer.targetAfterDragEnded(current: target))
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
            BlockDropPlacementResolver.resolution(
                location: CGPoint(x: 72, y: 20),
                rowSize: CGSize(width: 480, height: 48),
                destinationLevel: 0
            ),
            BlockDropPlacementResolution(placement: .after, targetLevel: 0)
        )
        XCTAssertEqual(
            BlockDropPlacementResolver.resolution(
                location: CGPoint(x: 96, y: 20),
                rowSize: CGSize(width: 480, height: 48),
                destinationLevel: 0
            ),
            BlockDropPlacementResolution(placement: .childAfter, targetLevel: 1)
        )
        XCTAssertEqual(
            BlockDropPlacementResolver.resolution(
                location: CGPoint(x: 128, y: 20),
                rowSize: CGSize(width: 480, height: 48),
                destinationLevel: 0
            ),
            BlockDropPlacementResolution(placement: .childAfter, targetLevel: 1)
        )
        XCTAssertEqual(
            BlockDropPlacementResolver.resolution(
                location: CGPoint(x: 72, y: 20),
                rowSize: CGSize(width: 480, height: 48),
                destinationLevel: 1
            ),
            BlockDropPlacementResolution(placement: .after, targetLevel: 1)
        )
        XCTAssertEqual(
            BlockDropPlacementResolver.resolution(
                location: CGPoint(x: 48, y: 20),
                rowSize: CGSize(width: 480, height: 48),
                destinationLevel: 2
            ),
            BlockDropPlacementResolution(placement: .outdentAfter, targetLevel: 0)
        )
        XCTAssertEqual(
            BlockDropPlacementResolver.resolution(
                location: CGPoint(x: 72, y: 20),
                rowSize: CGSize(width: 480, height: 48),
                destinationLevel: 2
            ),
            BlockDropPlacementResolution(placement: .outdentAfter, targetLevel: 1)
        )
        XCTAssertEqual(
            BlockDropPlacementResolver.resolution(
                location: CGPoint(x: 96, y: 20),
                rowSize: CGSize(width: 480, height: 48),
                destinationLevel: 2
            ),
            BlockDropPlacementResolution(placement: .after, targetLevel: 2)
        )
        XCTAssertEqual(
            BlockDropPlacementResolver.resolution(
                location: CGPoint(x: 10, y: 8),
                rowSize: CGSize(width: 480, height: 48),
                destinationLevel: 2
            ),
            BlockDropPlacementResolution(placement: .before, targetLevel: 2)
        )
    }

    func testDropParentResolverSupportsBeforeAndEndDropsChangingHierarchy() {
        let blocks = [
            block(id: "root", parentBlockID: nil, text: "Root"),
            block(id: "child", parentBlockID: "root", text: "Child"),
            block(id: "grandchild", parentBlockID: "child", text: "Grandchild")
        ]

        XCTAssertEqual(
            BlockDropParentResolver.parentBlockID(
                destinationBlockID: "grandchild",
                targetLevel: 2,
                blocks: blocks
            ),
            "child"
        )
        XCTAssertNil(BlockDropParentResolver.parentBlockIDForEndDrop())
    }

    func testSlashCommandMenuOnlyAutoScrollsForKeyboardSelection() {
        XCTAssertTrue(
            SlashCommandMenuScrollPolicy.shouldScrollSelectionIntoView(source: .keyboard)
        )
        XCTAssertFalse(
            SlashCommandMenuScrollPolicy.shouldScrollSelectionIntoView(source: .hover)
        )
    }

    func testBlockDropParentResolverMapsTargetLevelsToDestinationAncestors() {
        let blocks = [
            block(id: "root", parentBlockID: nil, text: "Root"),
            block(id: "child", parentBlockID: "root", text: "Child"),
            block(id: "grandchild", parentBlockID: "child", text: "Grandchild")
        ]

        XCTAssertNil(
            BlockDropParentResolver.parentBlockID(
                destinationBlockID: "grandchild",
                targetLevel: 0,
                blocks: blocks
            )
        )
        XCTAssertEqual(
            BlockDropParentResolver.parentBlockID(
                destinationBlockID: "grandchild",
                targetLevel: 1,
                blocks: blocks
            ),
            "root"
        )
        XCTAssertEqual(
            BlockDropParentResolver.parentBlockID(
                destinationBlockID: "grandchild",
                targetLevel: 2,
                blocks: blocks
            ),
            "child"
        )
        XCTAssertEqual(
            BlockDropParentResolver.parentBlockID(
                destinationBlockID: "grandchild",
                targetLevel: 3,
                blocks: blocks
            ),
            "grandchild"
        )
    }

    func testBlockDropIndicatorDescriptorUsesDotsInsteadOfVisibleTextForHierarchy() {
        XCTAssertEqual(
            BlockDropIndicatorDescriptor(placement: .outdentAfter, targetLevel: 0).levelDotCount,
            1
        )
        XCTAssertEqual(
            BlockDropIndicatorDescriptor(placement: .after, targetLevel: 2).levelDotCount,
            3
        )
        XCTAssertEqual(
            BlockDropIndicatorDescriptor(placement: .childAfter, targetLevel: 3).levelDotCount,
            4
        )
        XCTAssertNil(BlockDropIndicatorDescriptor(placement: .childAfter, targetLevel: 3).visibleText)
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

    func testPageListPreviewResolverUsesFirstTextAndSingleAttachmentBlock() {
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
        XCTAssertNil(preview.fileAttachment)
    }

    func testPageListPreviewResolverFallsBackToFileAttachmentWhenNoImageExists() {
        let pageID = "page"
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
                BlockSnapshot(id: "text", pageID: pageID, parentBlockID: nil, orderKey: "1", type: .paragraph, textPlain: "正文"),
                BlockSnapshot(id: "file", pageID: pageID, parentBlockID: nil, orderKey: "2", type: .attachmentFile, textPlain: "guide.pdf", attachmentID: file.id)
            ],
            attachments: [file]
        )

        XCTAssertEqual(preview.excerpt, "正文")
        XCTAssertNil(preview.imageAttachment)
        XCTAssertEqual(preview.fileAttachment?.id, file.id)
    }

    func testPageRowLayoutKeepsFavoriteControlsTrailingAligned() {
        XCTAssertEqual(PageRowLayoutPolicy.maxWidth, .infinity)
        XCTAssertEqual(PageRowLayoutPolicy.favoriteButtonSize, 22)
    }

    func testImageAttachmentPreviewCandidatesPreferOriginalFileBeforeThumbnail() {
        let block = BlockSnapshot(
            id: "image-block",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "1",
            type: .attachmentImage,
            textPlain: "photo.png",
            attachmentID: "attachment-photo"
        )
        let attachment = AttachmentSnapshot(
            id: "attachment-photo",
            workspaceID: "workspace",
            originalFilename: "photo.png",
            utiType: "public.png",
            byteSize: 12,
            contentHash: "hash",
            localPath: "/tmp/photo.png",
            thumbnailPath: "/tmp/missing-thumbnail.jpg",
            kind: .image
        )

        XCTAssertEqual(
            attachment.previewCandidatePaths(for: block),
            ["/tmp/photo.png", "/tmp/missing-thumbnail.jpg"]
        )
    }

    func testPageListPreviewResolverHidesEncryptedPagePreviewContent() {
        let preview = PageListPreviewResolver.preview(
            pageID: "encrypted-page",
            blocks: [
                BlockSnapshot(
                    id: "secret",
                    pageID: "encrypted-page",
                    parentBlockID: nil,
                    orderKey: "1",
                    type: .paragraph,
                    textPlain: "不要出现在中栏"
                )
            ],
            attachments: [],
            isEncrypted: true
        )

        XCTAssertNil(preview.excerpt)
        XCTAssertNil(preview.imageAttachment)
        XCTAssertNil(preview.fileAttachment)
        XCTAssertEqual(PageRowIconResolver.systemName(isEncrypted: true), "lock.doc")
        XCTAssertEqual(PageRowIconResolver.systemName(isEncrypted: false), "doc.text")
    }

    func testPageListDateSectionsGroupRecentPagesByLocalDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_779_171_600) // 2026-05-19T06:20:00Z
        let pages = [
            PageSummary(
                id: "today",
                workspaceID: "workspace",
                title: "今天",
                updatedAt: "2026-05-19T08:00:00.000Z"
            ),
            PageSummary(
                id: "today-no-fraction",
                workspaceID: "workspace",
                title: "今天，无毫秒",
                updatedAt: "2026-05-19T08:00:00Z"
            ),
            PageSummary(
                id: "today-offset",
                workspaceID: "workspace",
                title: "今天，时区偏移",
                updatedAt: "2026-05-19T16:00:00+08:00"
            ),
            PageSummary(
                id: "yesterday",
                workspaceID: "workspace",
                title: "昨天",
                updatedAt: "2026-05-18T21:30:00.000Z"
            ),
            PageSummary(
                id: "older",
                workspaceID: "workspace",
                title: "较早",
                updatedAt: "2026-05-12T09:00:00.000Z"
            ),
            PageSummary(id: "unknown", workspaceID: "workspace", title: "未知")
        ]

        let sections = PageListDateSectionModel.sections(
            pages: pages,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(sections.map(\.title), ["今天", "昨天", "5月12日", "较早"])
        XCTAssertEqual(
            sections.map { $0.pages.map(\.id) },
            [["today", "today-no-fraction", "today-offset"], ["yesterday"], ["older"], ["unknown"]]
        )
    }

    func testSidebarNavigationModelOmitsRecentAndFavoritesAndShowsHierarchicalTagCounts() {
        let workspaceID = "workspace"
        let pages = [
            PageSummary(id: "page-recent", workspaceID: workspaceID, title: "最近文件"),
            PageSummary(id: "page-diary", workspaceID: workspaceID, title: "2026年5月18日 星期一"),
            PageSummary(id: "page-favorite", workspaceID: workspaceID, title: "收藏文件", isFavorite: true),
            PageSummary(id: "page-encrypted", workspaceID: workspaceID, title: "加密文件", isEncrypted: true)
        ]
        let tags = [
            TagSummary(id: "tag-work", workspaceID: workspaceID, parentTagID: nil, name: "工作", path: "工作"),
            TagSummary(id: "tag-project", workspaceID: workspaceID, parentTagID: "tag-work", name: "项目", path: "工作/项目"),
            TagSummary(id: "tag-life", workspaceID: workspaceID, parentTagID: nil, name: "生活", path: "生活")
        ]
        let snapshot = WorkspaceSnapshot(
            workspaces: [WorkspaceSummary(id: workspaceID, name: "空间")],
            pages: pages,
            blocks: [],
            attachments: [],
            tags: tags,
            pageTags: [
                PageTagAssignment(pageID: "page-recent", tagID: "tag-project"),
                PageTagAssignment(pageID: "page-favorite", tagID: "tag-project"),
                PageTagAssignment(pageID: "page-diary", tagID: "tag-life"),
                PageTagAssignment(pageID: "page-encrypted", tagID: "tag-life")
            ],
            diaryPages: [
                DiaryPageSnapshot(pageID: "page-diary", workspaceID: workspaceID, diaryDate: "2026-05-18")
            ],
            emptyDiaryPageIDs: ["page-diary"],
            selectedWorkspaceID: workspaceID,
            selectedPageID: "page-recent"
        )

        let model = SidebarNavigationModel(snapshot: snapshot, selectedCollection: .allDocuments)

        XCTAssertEqual(
            model.primaryItems.map(\.title),
            ["全部文档", "日记", "加密"]
        )
        XCTAssertEqual(model.primaryItems.map(\.count), [3, 0, 1])
        XCTAssertEqual(model.primaryItems.first?.identifier, "editor.collection.all-documents")
        XCTAssertEqual(model.primaryItems.first?.isSelected, true)
        XCTAssertEqual(model.tagItems.map(\.title), ["工作", "项目", "生活"])
        XCTAssertEqual(model.tagItems.map(\.count), [2, 2, 1])
        XCTAssertEqual(model.tagItems.map(\.nestingLevel), [0, 1, 0])
        XCTAssertEqual(model.tagItems.map(\.parentTagID), [nil, "tag-work", nil])
        XCTAssertEqual(model.tagItems.map(\.hasChildren), [true, false, false])
        XCTAssertEqual(model.primaryItems.last?.identifier, "editor.collection.encrypted")
        XCTAssertEqual(model.primaryItems.last?.collection, .encrypted)
        XCTAssertEqual(model.utilityItems.map(\.identifier), ["editor.collection.archive"])
        XCTAssertFalse(model.utilityItems.contains { $0.collection == .search })
    }

    func testSidebarTagSectionDefaultsCollapsedAndStaysUserControlled() {
        XCTAssertFalse(SidebarTagSectionExpansionPolicy.defaultIsExpanded)
        XCTAssertFalse(SidebarTagSectionExpansionPolicy.shouldAutoExpand(selectedPageTagIDs: []))
        XCTAssertFalse(SidebarTagSectionExpansionPolicy.shouldAutoExpand(selectedPageTagIDs: ["tag-work"]))
    }

    func testSidebarTagVisibilityDefaultsToRootTagsAndRevealsExpandedBranches() {
        let workspaceID = "workspace"
        let tags = [
            TagSummary(id: "tag-work", workspaceID: workspaceID, parentTagID: nil, name: "工作", path: "工作"),
            TagSummary(id: "tag-project", workspaceID: workspaceID, parentTagID: "tag-work", name: "项目", path: "工作/项目"),
            TagSummary(id: "tag-sprint", workspaceID: workspaceID, parentTagID: "tag-project", name: "冲刺", path: "工作/项目/冲刺"),
            TagSummary(id: "tag-life", workspaceID: workspaceID, parentTagID: nil, name: "生活", path: "生活")
        ]
        let snapshot = WorkspaceSnapshot(
            workspaces: [WorkspaceSummary(id: workspaceID, name: "空间")],
            pages: [],
            blocks: [],
            attachments: [],
            tags: tags,
            selectedWorkspaceID: workspaceID,
            selectedPageID: nil
        )
        let model = SidebarNavigationModel(snapshot: snapshot, selectedCollection: .allDocuments)

        XCTAssertEqual(
            SidebarTagVisibilityPolicy.visibleItems(model.tagItems, expandedTagIDs: []).map(\.title),
            ["工作", "生活"]
        )
        XCTAssertEqual(
            SidebarTagVisibilityPolicy.visibleItems(model.tagItems, expandedTagIDs: ["tag-work"]).map(\.title),
            ["工作", "项目", "生活"]
        )
        XCTAssertEqual(
            SidebarTagVisibilityPolicy.visibleItems(
                model.tagItems,
                expandedTagIDs: ["tag-work", "tag-project"]
            ).map(\.title),
            ["工作", "项目", "冲刺", "生活"]
        )
        XCTAssertEqual(
            SidebarTagVisibilityPolicy.visibleItems(model.tagItems, expandedTagIDs: ["tag-project"]).map(\.title),
            ["工作", "生活"],
            "Expanding a hidden child should not reveal it until its parent branch is open."
        )
    }

    func testSidebarHighlightsTagsAttachedToTheSelectedPage() {
        let relatedItem = SidebarNavigationItem(
            id: "tag-work",
            title: "工作",
            systemImage: "tag",
            count: 1,
            collection: .tag("tag-work"),
            identifier: "editor.collection.tag.tag-work",
            isSelected: false
        )
        let unrelatedItem = SidebarNavigationItem(
            id: "tag-life",
            title: "生活",
            systemImage: "tag",
            count: 1,
            collection: .tag("tag-life"),
            identifier: "editor.collection.tag.tag-life",
            isSelected: false
        )

        XCTAssertTrue(
            SidebarTagHighlightPolicy.isHighlighted(
                item: relatedItem,
                selectedPageTagIDs: ["tag-work"]
            )
        )
        XCTAssertFalse(
            SidebarTagHighlightPolicy.isHighlighted(
                item: unrelatedItem,
                selectedPageTagIDs: ["tag-work"]
            )
        )
    }

    func testSidebarChromeUsesCompactBearLikeRailMetrics() {
        XCTAssertEqual(SidebarChrome.horizontalPadding, 8)
        XCTAssertEqual(SidebarChrome.verticalPadding, 10)
        XCTAssertEqual(SidebarChrome.sectionSpacing, 6)
        XCTAssertEqual(SidebarChrome.rowSpacing, 1)
        XCTAssertEqual(SidebarChrome.rowCornerRadius, 12)
        XCTAssertEqual(SidebarChrome.rowVerticalPadding, 6)
        XCTAssertEqual(SidebarChrome.nestedItemIndent, 12)
        XCTAssertEqual(SidebarChrome.dividerOpacity, 0.05)
        XCTAssertEqual(SidebarChrome.selectedFillOpacity, 0.44)
        XCTAssertEqual(SidebarChrome.selectedStrokeOpacity, 0.025)
        XCTAssertEqual(SidebarChrome.headerBadgeSize, 30)
        XCTAssertEqual(SidebarChrome.headerBadgeCornerRadius, 8)
        XCTAssertEqual(SidebarChrome.backgroundRed, EditorDesignTokens.Colors.sidebarBackground.red)
        XCTAssertEqual(SidebarChrome.backgroundGreen, EditorDesignTokens.Colors.sidebarBackground.green)
        XCTAssertEqual(SidebarChrome.backgroundBlue, EditorDesignTokens.Colors.sidebarBackground.blue)
        XCTAssertEqual(SidebarChrome.selectedFillRed, EditorDesignTokens.Colors.border.red)
        XCTAssertEqual(SidebarChrome.selectedFillGreen, EditorDesignTokens.Colors.border.green)
        XCTAssertEqual(SidebarChrome.selectedFillBlue, EditorDesignTokens.Colors.border.blue)
    }

    private func assertColor(
        _ token: EditorColorToken,
        scheme: EditorThemeScheme = .light,
        red: Int,
        green: Int,
        blue: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let components = token.components(for: scheme)
        XCTAssertEqual(components.red, Double(red) / 255, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(components.green, Double(green) / 255, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(components.blue, Double(blue) / 255, accuracy: 0.0001, file: file, line: line)
    }

    func testCompactLibraryNavigationRoutesRowsByCollectionAndIncludesDiary() {
        let workspaceID = "workspace"
        let snapshot = WorkspaceSnapshot(
            workspaces: [WorkspaceSummary(id: workspaceID, name: "空间")],
            pages: [
                PageSummary(id: "page-a", workspaceID: workspaceID, title: "A"),
                PageSummary(id: "page-diary", workspaceID: workspaceID, title: "2026年5月18日 星期一"),
                PageSummary(id: "page-favorite", workspaceID: workspaceID, title: "收藏", isFavorite: true),
                PageSummary(id: "page-encrypted", workspaceID: workspaceID, title: "密文", isEncrypted: true)
            ],
            archivedPages: [
                PageSummary(id: "page-archived", workspaceID: workspaceID, title: "归档文档")
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

        XCTAssertEqual(items.map(\.title), ["全部文档", "日记", "收藏", "加密", "归档"])
        XCTAssertEqual(items.map(\.collection), [.allDocuments, .diary, .favorites, .encrypted, .archive])
        XCTAssertEqual(items.map(\.count), [3, 1, 1, 1, 1])
        XCTAssertEqual(
            items.map(\.route),
            [
                .collection(.allDocuments),
                .collection(.diary),
                .collection(.favorites),
                .collection(.encrypted),
                .collection(.archive)
            ]
        )

        XCTAssertEqual(
            CompactCollectionPageListModel.pages(snapshot: snapshot, collection: .allDocuments).map(\.id),
            ["page-a", "page-favorite", "page-encrypted"]
        )
        XCTAssertEqual(
            CompactCollectionPageListModel.pages(snapshot: snapshot, collection: .diary).map(\.id),
            ["page-diary"]
        )
        XCTAssertEqual(
            CompactCollectionPageListModel.pages(snapshot: snapshot, collection: .favorites).map(\.id),
            ["page-favorite"]
        )
        XCTAssertEqual(
            CompactCollectionPageListModel.pages(snapshot: snapshot, collection: .encrypted).map(\.id),
            ["page-encrypted"]
        )
        XCTAssertEqual(
            CompactCollectionPageListModel.pages(snapshot: snapshot, collection: .archive).map(\.id),
            ["page-archived"]
        )
        XCTAssertEqual(
            CompactShellRoutePlanner.pathForPage(
                "page-a",
                snapshot: snapshot,
                selectedCollection: .search
            ),
            [.collection(.allDocuments), .page("page-a")]
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
        let tagParent = TagSummary(
            id: "tag-life",
            workspaceID: workspaceID,
            parentTagID: nil,
            name: "生活",
            path: "生活"
        )
        let tagChild = TagSummary(
            id: "tag-garden",
            workspaceID: workspaceID,
            parentTagID: tagParent.id,
            name: "园艺",
            path: "生活/园艺"
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
            tags: [tagParent, tagChild],
            pageTags: [PageTagAssignment(pageID: page.id, tagID: tagChild.id)],
            selectedWorkspaceID: workspaceID,
            selectedPageID: page.id
        )

        let items = CompactCollectionPageListModel.items(
            snapshot: snapshot,
            collection: .favorites
        )

        XCTAssertEqual(items.map(\.page.id), [page.id])
        XCTAssertEqual(items.first?.tagNames, ["生活/园艺"])
        XCTAssertEqual(items.first?.preview.excerpt, "这是一段用于列表预览的正文")
    }

    func testPageListRenderIndexMatchesStoredAndLoadedPreviewRules() {
        let workspaceID = "workspace"
        let loadedPage = PageSummary(id: "loaded-page", workspaceID: workspaceID, title: "Loaded")
        let storedOnlyPage = PageSummary(id: "stored-page", workspaceID: workspaceID, title: "Stored")
        let encryptedPage = PageSummary(
            id: "encrypted-page",
            workspaceID: workspaceID,
            title: "Secret",
            isEncrypted: true
        )
        let image = AttachmentSnapshot(
            id: "image-attachment",
            workspaceID: workspaceID,
            originalFilename: "cover.png",
            utiType: "public.png",
            byteSize: 42,
            contentHash: "image-hash",
            localPath: "/tmp/cover.png",
            thumbnailPath: nil,
            kind: .image
        )
        let tag = TagSummary(
            id: "tag-work",
            workspaceID: workspaceID,
            parentTagID: nil,
            name: "工作",
            path: "工作"
        )
        let snapshot = WorkspaceSnapshot(
            workspaces: [WorkspaceSummary(id: workspaceID, name: "空间")],
            pages: [loadedPage, storedOnlyPage, encryptedPage],
            blocks: [
                BlockSnapshot(
                    id: "loaded-text",
                    pageID: loadedPage.id,
                    parentBlockID: nil,
                    orderKey: "1",
                    type: .paragraph,
                    textPlain: "Loaded excerpt"
                ),
                BlockSnapshot(
                    id: "loaded-image",
                    pageID: loadedPage.id,
                    parentBlockID: nil,
                    orderKey: "2",
                    type: .attachmentImage,
                    textPlain: "cover.png",
                    attachmentID: image.id
                ),
                BlockSnapshot(
                    id: "encrypted-text",
                    pageID: encryptedPage.id,
                    parentBlockID: nil,
                    orderKey: "1",
                    type: .paragraph,
                    textPlain: "Hidden"
                )
            ],
            pageListPreviews: [
                storedOnlyPage.id: PageListPreview(
                    excerpt: "Stored excerpt",
                    imageAttachment: nil,
                    fileAttachment: nil
                )
            ],
            attachments: [image],
            tags: [tag],
            pageTags: [PageTagAssignment(pageID: loadedPage.id, tagID: tag.id)],
            selectedWorkspaceID: workspaceID,
            selectedPageID: loadedPage.id
        )
        let index = PageListRenderIndex(snapshot: snapshot)

        XCTAssertEqual(index.preview(for: loadedPage).excerpt, "Loaded excerpt")
        XCTAssertEqual(index.preview(for: loadedPage).imageAttachment?.id, image.id)
        XCTAssertEqual(index.preview(for: storedOnlyPage).excerpt, "Stored excerpt")
        XCTAssertNil(index.preview(for: encryptedPage).excerpt)
        XCTAssertEqual(index.tagNames(for: loadedPage), ["工作"])
    }

    func testPageListRenderWindowPolicyKeepsInitialWindowSmallAndIncludesSelectedPage() {
        let pages = (0..<200).map { index in
            PageSummary(id: "page-\(index)", workspaceID: "workspace", title: "Page \(index)")
        }

        let renderedPages = PageListRenderWindowPolicy.renderedPages(
            pages,
            selectedPageID: "page-150",
            limit: PageListRenderWindowPolicy.initialLimit
        )

        XCTAssertEqual(renderedPages.count, PageListRenderWindowPolicy.initialLimit + 1)
        XCTAssertEqual(renderedPages.prefix(PageListRenderWindowPolicy.initialLimit).map(\.id), pages.prefix(PageListRenderWindowPolicy.initialLimit).map(\.id))
        XCTAssertEqual(renderedPages.last?.id, "page-150")
    }

    func testPageListRenderWindowPolicyWarmsAndExpandsInBatches() {
#if os(iOS)
        XCTAssertFalse(PageListRenderWindowPolicy.allowsAutomaticWarmup)
#else
        XCTAssertTrue(PageListRenderWindowPolicy.allowsAutomaticWarmup)
#endif
        XCTAssertEqual(
            PageListRenderWindowPolicy.warmedLimit(
                currentLimit: PageListRenderWindowPolicy.initialLimit,
                visibleCount: 2_000
            ),
            PageListRenderWindowPolicy.warmupLimit
        )
        XCTAssertEqual(
            PageListRenderWindowPolicy.expandedLimit(
                currentLimit: PageListRenderWindowPolicy.warmupLimit,
                visibleCount: 2_000
            ),
            PageListRenderWindowPolicy.warmupLimit + PageListRenderWindowPolicy.expansionBatchSize
        )
    }

    func testPageListRenderWindowPolicyStopsAtVisibleCount() {
        XCTAssertEqual(
            PageListRenderWindowPolicy.warmedLimit(currentLimit: 4, visibleCount: 12),
            12
        )
        XCTAssertEqual(
            PageListRenderWindowPolicy.expandedLimit(currentLimit: 180, visibleCount: 200),
            200
        )
        XCTAssertFalse(
            PageListRenderWindowPolicy.canExpand(renderedCount: 200, visibleCount: 200)
        )
        XCTAssertTrue(
            PageListRenderWindowPolicy.canExpand(renderedCount: 96, visibleCount: 200)
        )
    }

    func testCompactPageRouteUpdatePolicySkipsDuplicateTopPagePush() {
        XCTAssertFalse(
            CompactPageRouteUpdatePolicy.shouldPush(
                pageID: "page-a",
                currentPath: [.page("page-a")]
            )
        )
        XCTAssertFalse(
            CompactPageRouteUpdatePolicy.shouldPush(
                pageID: "page-a",
                currentPath: [.collection(.allDocuments), .page("page-a")]
            )
        )
        XCTAssertTrue(
            CompactPageRouteUpdatePolicy.shouldPush(
                pageID: "page-b",
                currentPath: [.collection(.allDocuments), .page("page-a")]
            )
        )
    }

    func testCompactRoutePathUpdatePolicySkipsReplacingSameTopPageWithBackStack() {
        XCTAssertFalse(
            CompactRoutePathUpdatePolicy.shouldApply(
                plannedPath: [.collection(.allDocuments), .page("page-a")],
                currentPath: [.page("page-a")]
            )
        )
        XCTAssertTrue(
            CompactRoutePathUpdatePolicy.shouldApply(
                plannedPath: [.collection(.allDocuments), .page("page-b")],
                currentPath: [.page("page-a")]
            )
        )
        XCTAssertTrue(
            CompactRoutePathUpdatePolicy.shouldApply(
                plannedPath: [.collection(.allDocuments)],
                currentPath: []
            )
        )
    }

    func testDeferredTableBlockEditorPolicyOnlyDefersInactiveLargePageTables() {
        XCTAssertTrue(
            DeferredTableBlockEditorPolicy.usesPreview(
                blockType: .table,
                isLargePage: true,
                isEditing: false
            )
        )
        XCTAssertFalse(
            DeferredTableBlockEditorPolicy.usesPreview(
                blockType: .paragraph,
                isLargePage: true,
                isEditing: false
            )
        )
        XCTAssertFalse(
            DeferredTableBlockEditorPolicy.usesPreview(
                blockType: .table,
                isLargePage: false,
                isEditing: false
            )
        )
        XCTAssertFalse(
            DeferredTableBlockEditorPolicy.usesPreview(
                blockType: .table,
                isLargePage: true,
                isEditing: true
            )
        )
    }

    func testDeferredTextBlockEditorPolicyOnlyDefersIdleLargePageText() {
        XCTAssertTrue(
            DeferredTextBlockEditorPolicy.usesPreview(
                blockType: .paragraph,
                isLargePage: true,
                isFocused: false,
                hasFocusRequest: false,
                hasSearchHighlight: false,
                isEditing: false
            )
        )
        XCTAssertFalse(
            DeferredTextBlockEditorPolicy.usesPreview(
                blockType: .paragraph,
                isLargePage: false,
                isFocused: false,
                hasFocusRequest: false,
                hasSearchHighlight: false,
                isEditing: false
            )
        )
        XCTAssertFalse(
            DeferredTextBlockEditorPolicy.usesPreview(
                blockType: .paragraph,
                isLargePage: true,
                isFocused: true,
                hasFocusRequest: false,
                hasSearchHighlight: false,
                isEditing: false
            )
        )
        XCTAssertFalse(
            DeferredTextBlockEditorPolicy.usesPreview(
                blockType: .paragraph,
                isLargePage: true,
                isFocused: false,
                hasFocusRequest: true,
                hasSearchHighlight: false,
                isEditing: false
            )
        )
        XCTAssertFalse(
            DeferredTextBlockEditorPolicy.usesPreview(
                blockType: .paragraph,
                isLargePage: true,
                isFocused: false,
                hasFocusRequest: false,
                hasSearchHighlight: true,
                isEditing: false
            )
        )
        XCTAssertFalse(
            DeferredTextBlockEditorPolicy.usesPreview(
                blockType: .table,
                isLargePage: true,
                isFocused: false,
                hasFocusRequest: false,
                hasSearchHighlight: false,
                isEditing: false
            )
        )
    }

    func testMobileLargePageTextPreviewRowPolicyUsesOnlyIdlePlainTextLikeBlocks() {
        XCTAssertTrue(
            MobileLargePageTextPreviewRowPolicy.usesPreview(
                blockType: .paragraph,
                isLargePage: true,
                isFocused: false,
                hasFocusRequest: false,
                hasSearchHighlight: false,
                isSelectionModeActive: false,
                isBlockSelected: false,
                hasDraftText: false
            )
        )
        XCTAssertTrue(
            MobileLargePageTextPreviewRowPolicy.usesPreview(
                blockType: .orderedListItem,
                isLargePage: true,
                isFocused: false,
                hasFocusRequest: false,
                hasSearchHighlight: false,
                isSelectionModeActive: false,
                isBlockSelected: false,
                hasDraftText: false
            )
        )
        XCTAssertFalse(
            MobileLargePageTextPreviewRowPolicy.usesPreview(
                blockType: .paragraph,
                isLargePage: false,
                isFocused: false,
                hasFocusRequest: false,
                hasSearchHighlight: false,
                isSelectionModeActive: false,
                isBlockSelected: false,
                hasDraftText: false
            )
        )
        XCTAssertFalse(
            MobileLargePageTextPreviewRowPolicy.usesPreview(
                blockType: .paragraph,
                isLargePage: true,
                isFocused: true,
                hasFocusRequest: false,
                hasSearchHighlight: false,
                isSelectionModeActive: false,
                isBlockSelected: false,
                hasDraftText: false
            )
        )
        XCTAssertFalse(
            MobileLargePageTextPreviewRowPolicy.usesPreview(
                blockType: .paragraph,
                isLargePage: true,
                isFocused: false,
                hasFocusRequest: true,
                hasSearchHighlight: false,
                isSelectionModeActive: false,
                isBlockSelected: false,
                hasDraftText: false
            )
        )
        XCTAssertFalse(
            MobileLargePageTextPreviewRowPolicy.usesPreview(
                blockType: .table,
                isLargePage: true,
                isFocused: false,
                hasFocusRequest: false,
                hasSearchHighlight: false,
                isSelectionModeActive: false,
                isBlockSelected: false,
                hasDraftText: false
            )
        )
        XCTAssertFalse(
            MobileLargePageTextPreviewRowPolicy.usesPreview(
                blockType: .taskItem,
                isLargePage: true,
                isFocused: false,
                hasFocusRequest: false,
                hasSearchHighlight: false,
                isSelectionModeActive: false,
                isBlockSelected: false,
                hasDraftText: false
            )
        )
    }

    func testMobileLargePageTablePreviewRowPolicyDefersOnlyInactiveLargePageTables() {
        XCTAssertTrue(
            MobileLargePageTablePreviewRowPolicy.usesPreview(
                blockType: .table,
                isLargePage: true,
                hasSearchHighlight: false,
                isSelectionModeActive: false,
                isBlockSelected: false,
                isEditorActive: false
            )
        )
        XCTAssertFalse(
            MobileLargePageTablePreviewRowPolicy.usesPreview(
                blockType: .paragraph,
                isLargePage: true,
                hasSearchHighlight: false,
                isSelectionModeActive: false,
                isBlockSelected: false,
                isEditorActive: false
            )
        )
        XCTAssertFalse(
            MobileLargePageTablePreviewRowPolicy.usesPreview(
                blockType: .table,
                isLargePage: false,
                hasSearchHighlight: false,
                isSelectionModeActive: false,
                isBlockSelected: false,
                isEditorActive: false
            )
        )
        XCTAssertFalse(
            MobileLargePageTablePreviewRowPolicy.usesPreview(
                blockType: .table,
                isLargePage: true,
                hasSearchHighlight: false,
                isSelectionModeActive: false,
                isBlockSelected: false,
                isEditorActive: true
            )
        )
    }

    func testForegroundSyncActivationPolicySkipsWhenPostLaunchMaintenanceIsDisabled() {
        let policy = ForegroundSyncActivationPolicy()

        XCTAssertTrue(
            policy.shouldSkipActivationSync(
                environment: ["EDITOR_DISABLE_POST_LAUNCH_MAINTENANCE": "1"]
            )
        )
        XCTAssertFalse(policy.shouldSkipActivationSync(environment: [:]))
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

    private func block(
        id: String,
        parentBlockID: String?,
        type: BlockType = .paragraph,
        text: String
    ) -> BlockSnapshot {
        BlockSnapshot(
            id: id,
            pageID: "page",
            parentBlockID: parentBlockID,
            orderKey: id,
            type: type,
            textPlain: text
        )
    }
}
