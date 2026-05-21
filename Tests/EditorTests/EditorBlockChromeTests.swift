import XCTest

final class EditorBlockChromeTests: XCTestCase {
    func testCraftThingsDesignTokensMatchDesktopEditorialPalette() {
        assertColor(EditorDesignTokens.Colors.appBackground, red: 0xF7, green: 0xF7, blue: 0xF5)
        assertColor(EditorDesignTokens.Colors.sidebarBackground, red: 0xF2, green: 0xF2, blue: 0xEF)
        assertColor(EditorDesignTokens.Colors.documentListBackground, red: 0xFF, green: 0xFF, blue: 0xFF)
        assertColor(EditorDesignTokens.Colors.editorBackground, red: 0xFF, green: 0xFF, blue: 0xFF)
        assertColor(EditorDesignTokens.Colors.primaryText, red: 0x22, green: 0x21, blue: 0x1F)
        assertColor(EditorDesignTokens.Colors.secondaryText, red: 0x5F, green: 0x61, blue: 0x66)
        assertColor(EditorDesignTokens.Colors.tertiaryText, red: 0x8B, green: 0x8D, blue: 0x91)
        assertColor(EditorDesignTokens.Colors.border, red: 0xE6, green: 0xE5, blue: 0xE1)
        assertColor(EditorDesignTokens.Colors.accent, red: 0xE5, green: 0x45, blue: 0x4F)
    }

    func testCraftThingsDesignTokensKeepDocumentTypographyInRange() {
        XCTAssertEqual(EditorDesignTokens.Typography.documentTitleSize, 28)
        XCTAssertEqual(EditorDesignTokens.Typography.bodySize, 14)
        XCTAssertEqual(EditorDesignTokens.Typography.bodyLineHeightMultiple, 1.34)
        XCTAssertEqual(EditorDesignTokens.Layout.editorMaxWidth, 680)
        XCTAssertGreaterThan(EditorDesignTokens.Layout.editorExpandedMaxWidth, EditorDesignTokens.Layout.editorMaxWidth)
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
        XCTAssertEqual(EditorCanvasChromeLayout.horizontalPadding, 40)
        XCTAssertEqual(EditorCanvasChromeLayout.verticalPadding, 36)
        XCTAssertEqual(EditorCanvasChromeLayout.pageTitleLeadingPadding, 27)
        XCTAssertEqual(EditorCanvasChromeLayout.blockRowTitleAlignmentCompensation, 0)
#endif
    }

    func testMobileNavigationBarChromeKeepsCollapsedTitleVerticallyCentered() {
        XCTAssertEqual(MobileNavigationBarChrome.topMaskHeight, 72)
        XCTAssertEqual(MobileNavigationBarChrome.collapsedTitleVerticalOffset, 0)
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

    func testDesktopColumnDividerStaysVisualOnlyAndSubtle() {
        XCTAssertEqual(DesktopColumnDividerChrome.hitWidth, 9)
        XCTAssertEqual(DesktopColumnDividerChrome.lineWidth, 1)
        XCTAssertLessThan(DesktopColumnDividerChrome.idleOpacity, 0.05)
        XCTAssertGreaterThan(DesktopColumnDividerChrome.hoverOpacity, DesktopColumnDividerChrome.idleOpacity)
        XCTAssertGreaterThan(DesktopColumnDividerChrome.draggingOpacity, DesktopColumnDividerChrome.hoverOpacity)
    }

    func testDesktopColumnResizeUsesDragStartWidthWithoutAccumulatingMovingDividerDeltas() {
        let startWidth: CGFloat = 300

        XCTAssertEqual(
            DesktopColumnResizeDragResolver.width(
                startWidth: startWidth,
                translation: 20,
                min: EditorDesignTokens.Layout.sidebarMinWidth,
                max: EditorDesignTokens.Layout.sidebarMaxWidth
            ),
            320
        )
        XCTAssertEqual(
            DesktopColumnResizeDragResolver.width(
                startWidth: startWidth,
                translation: 25,
                min: EditorDesignTokens.Layout.sidebarMinWidth,
                max: EditorDesignTokens.Layout.sidebarMaxWidth
            ),
            325,
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

    func testEditorCanvasWidensWhenAuxiliaryRailIsHidden() {
        XCTAssertEqual(
            EditorCanvasWidthPolicy.maxWidth(hasVisibleAuxiliaryRail: true),
            EditorDesignTokens.Layout.editorMaxWidth
        )
        XCTAssertEqual(
            EditorCanvasWidthPolicy.maxWidth(hasVisibleAuxiliaryRail: false),
            EditorDesignTokens.Layout.editorExpandedMaxWidth
        )
    }

    func testEditorDisplayModesProgressivelyHideSecondaryChrome() {
        XCTAssertTrue(EditorDisplayMode.standard.showsSidebar)
        XCTAssertTrue(EditorDisplayMode.standard.showsDocumentList)
        XCTAssertTrue(EditorDisplayMode.standard.showsAuxiliaryRail)

        XCTAssertTrue(EditorDisplayMode.writing.showsSidebar)
        XCTAssertFalse(EditorDisplayMode.writing.showsDocumentList)
        XCTAssertFalse(EditorDisplayMode.writing.showsAuxiliaryRail)

        XCTAssertFalse(EditorDisplayMode.focus.showsSidebar)
        XCTAssertFalse(EditorDisplayMode.focus.showsDocumentList)
        XCTAssertFalse(EditorDisplayMode.focus.showsAuxiliaryRail)
    }

    func testCraftQuietChromeKeepsListRowsUnboxedAndCompact() {
        XCTAssertEqual(EditorBlockChrome.blockSpacing, 0)
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
        XCTAssertTrue(MobileBlockDragActivationPolicy.usesNativeTextViewDragInteraction)
    }

    func testMobileNativeTextRowsKeepUIKitTextMenuInsteadOfRowContextMenu() {
        XCTAssertFalse(MobileBlockContextMenuPolicy.enablesRowContextMenu(usesNativeTextEditor: true))
        XCTAssertTrue(MobileBlockContextMenuPolicy.enablesRowContextMenu(usesNativeTextEditor: false))
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

    func testPageListChromeUsesWhiteBearLikeSurface() {
        XCTAssertEqual(PageListChrome.backgroundRed, EditorDesignTokens.Colors.documentListBackground.red)
        XCTAssertEqual(PageListChrome.backgroundGreen, EditorDesignTokens.Colors.documentListBackground.green)
        XCTAssertEqual(PageListChrome.backgroundBlue, EditorDesignTokens.Colors.documentListBackground.blue)
        XCTAssertGreaterThan(PageListChrome.rowDividerOpacity, 0)
        XCTAssertLessThan(PageListChrome.selectedFillOpacity, 0.08)
    }

    func testCompactChromeUsesDocumentListBackgroundAcrossMobileLists() {
        XCTAssertEqual(CompactChrome.backgroundRed, PageListChrome.backgroundRed)
        XCTAssertEqual(CompactChrome.backgroundGreen, PageListChrome.backgroundGreen)
        XCTAssertEqual(CompactChrome.backgroundBlue, PageListChrome.backgroundBlue)
    }

    func testCompactLibraryChromeUsesLightAppSurface() {
        assertColor(CompactLibraryChrome.backgroundToken, red: 0xF7, green: 0xF7, blue: 0xF5)
        assertColor(CompactLibraryChrome.primaryForegroundToken, red: 0x22, green: 0x21, blue: 0x1F)
        assertColor(CompactLibraryChrome.mutedForegroundToken, red: 0x5F, green: 0x61, blue: 0x66)
        XCTAssertEqual(CompactLibraryChrome.rowCornerRadius, 13)
        XCTAssertEqual(CompactLibraryChrome.selectedRowOpacity, 0.08)
    }

    func testBearLikeLightThemeUsesNeutralWhiteWritingSurfaces() {
        assertColor(EditorDesignTokens.Colors.appBackground, red: 0xF7, green: 0xF7, blue: 0xF5)
        assertColor(EditorDesignTokens.Colors.sidebarBackground, red: 0xF2, green: 0xF2, blue: 0xEF)
        assertColor(EditorDesignTokens.Colors.documentListBackground, red: 0xFF, green: 0xFF, blue: 0xFF)
        assertColor(EditorDesignTokens.Colors.editorBackground, red: 0xFF, green: 0xFF, blue: 0xFF)
        XCTAssertLessThan(SidebarChrome.backgroundYellowBias, 0.015)
        XCTAssertLessThan(CompactChrome.backgroundYellowBias, 0.015)
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

    func testPageListKeyboardShortcutResolverScopesSelectAllAndShiftReturn() {
        XCTAssertEqual(
            PageListKeyboardShortcutActionResolver.action(
                keyCode: 0,
                input: "a",
                modifiers: [.command],
                hasVisiblePages: true,
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
                isTextEditing: false
            ),
            .selectRangeToSelectedPage
        )
        XCTAssertNil(
            PageListKeyboardShortcutActionResolver.action(
                keyCode: 0,
                input: "a",
                modifiers: [.command],
                hasVisiblePages: true,
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
                .heading3
            ]
        )
        XCTAssertEqual(actions.compactMap(\.inlineFormat), [.bold, .italic, .strikethrough, .code])
        XCTAssertTrue(actions.contains(.insertLink))
        XCTAssertTrue(actions.contains(.indent))
        XCTAssertTrue(actions.contains(.outdent))
        XCTAssertTrue(actions.contains(.dismissKeyboard))

        let labels = Set(actions.map(\.accessibilityLabel))
        XCTAssertFalse(labels.contains("下划线"))
        XCTAssertFalse(labels.contains("颜色"))
        XCTAssertFalse(labels.contains("高亮"))
        XCTAssertFalse(labels.contains("日历"))
        XCTAssertFalse(labels.contains("拍照"))
    }

    func testDesktopAuxiliaryRailButtonIsOfferedEvenBeforeRailHasContent() {
        XCTAssertTrue(
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

    func testCompactShellInitialPathRoutesThroughDocumentListToEditor() {
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
            [.collection(.allDocuments), .page(page.id)]
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
        XCTAssertEqual(sections.map { $0.pages.map(\.id) }, [["today"], ["yesterday"], ["older"], ["unknown"]])
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
            selectedWorkspaceID: workspaceID,
            selectedPageID: "page-recent"
        )

        let model = SidebarNavigationModel(snapshot: snapshot, selectedCollection: .allDocuments)

        XCTAssertEqual(
            model.primaryItems.map(\.title),
            ["全部文档", "日记", "加密"]
        )
        XCTAssertEqual(model.primaryItems.map(\.count), [3, 1, 1])
        XCTAssertEqual(model.primaryItems.first?.identifier, "editor.collection.all-documents")
        XCTAssertEqual(model.primaryItems.first?.isSelected, true)
        XCTAssertEqual(model.tagItems.map(\.title), ["工作", "项目", "生活"])
        XCTAssertEqual(model.tagItems.map(\.count), [2, 2, 2])
        XCTAssertEqual(model.tagItems.map(\.nestingLevel), [0, 1, 0])
        XCTAssertEqual(model.primaryItems.last?.identifier, "editor.collection.encrypted")
        XCTAssertEqual(model.primaryItems.last?.collection, .encrypted)
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
        red: Int,
        green: Int,
        blue: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(token.red, Double(red) / 255, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(token.green, Double(green) / 255, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(token.blue, Double(blue) / 255, accuracy: 0.0001, file: file, line: line)
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

        XCTAssertEqual(items.map(\.title), ["全部文档", "日记", "收藏", "加密", "搜索", "归档"])
        XCTAssertEqual(items.map(\.collection), [.allDocuments, .diary, .favorites, .encrypted, .search, .archive])
        XCTAssertEqual(items.map(\.count), [3, 1, 1, 1, 0, 1])
        XCTAssertEqual(
            items.map(\.route),
            [
                .collection(.allDocuments),
                .collection(.diary),
                .collection(.favorites),
                .collection(.encrypted),
                .collection(.search),
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
            [.collection(.search), .page("page-a")]
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
