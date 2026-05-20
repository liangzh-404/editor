import XCTest

final class EditorIOSEditingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func makeApp(extraEnvironment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_UI_TEST_RESET_STORE"] = "1"
        for (key, value) in extraEnvironment {
            app.launchEnvironment[key] = value
        }
        return app
    }

    @MainActor
    func testIPhoneLaunchOpensEditablePageImmediately() {
        let app = makeApp()
        app.launch()

        let firstTextView = app.textViews.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "editor.text.")
        ).firstMatch
        XCTAssertTrue(firstTextView.waitForExistence(timeout: 5), "iPhone first screen should open an editable document")

        firstTextView.tap()
        firstTextView.typeText(" 首屏输入")

        let value = firstTextView.value as? String ?? ""
        XCTAssertTrue(value.contains("首屏输入"), "Typing should work without navigating through document lists")
    }

    @MainActor
    func testIPhoneEditorDoesNotDuplicatePageTitleInNavigationBar() {
        let app = makeApp()
        app.launch()

        let pageTitle = app.textFields["editor.page-title"]
        XCTAssertTrue(pageTitle.waitForExistence(timeout: 5), "The editable page title should remain in the document body")

        let titleValue = (pageTitle.value as? String) ?? pageTitle.label
        XCTAssertFalse(titleValue.isEmpty, "The document body title should expose the selected page title")
        XCTAssertFalse(
            app.navigationBars.staticTexts[titleValue].exists,
            "iPhone editor should not render a second large navigation title above the editable document title"
        )

        let firstTextView = app.textViews.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "editor.text.")
        ).firstMatch
        XCTAssertTrue(firstTextView.waitForExistence(timeout: 5), "The first text block should still be tappable after hiding the duplicate title")

        firstTextView.tap()
        firstTextView.typeText(" 标题去重")

        let value = firstTextView.value as? String ?? ""
        XCTAssertTrue(value.contains("标题去重"), "Typing should still work after tapping the document canvas")
    }

    @MainActor
    func testIPhoneEditorTopBarKeepsOnlyPageActionsMenu() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(
            app.buttons["editor.page-actions"].waitForExistence(timeout: 5),
            "iPhone editor should keep the multifunction page actions menu"
        )
        XCTAssertFalse(app.buttons["editor.add-block"].exists, "iPhone editor should not show a separate add button")
        XCTAssertFalse(
            app.buttons["editor.insert-attachment"].exists,
            "iPhone editor should not show a separate attachment button"
        )
    }

    @MainActor
    func testIPhoneEditorKeepsPageActionsPinnedInNavigationBar() {
        let app = makeApp(extraEnvironment: ["EDITOR_UI_TEST_LARGE_PAGE_BLOCK_COUNT": "40"])
        app.launch()

        let pinnedActions = app.navigationBars.buttons["editor.page-actions"]
        XCTAssertTrue(
            pinnedActions.waitForExistence(timeout: 5),
            "The iPhone page actions menu should be fixed in the navigation bar next to Back"
        )
        let initialFrame = pinnedActions.frame

        let canvas = app.scrollViews["editor.canvas-scroll"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5), "The editor canvas should be scrollable")
        canvas.swipeUp()

        XCTAssertTrue(pinnedActions.waitForExistence(timeout: 3), "The page actions menu should remain visible after scrolling")
        XCTAssertEqual(
            pinnedActions.frame.minY,
            initialFrame.minY,
            accuracy: 2,
            "The fixed page actions menu should not move with the document title row"
        )
    }

    @MainActor
    func testIPhoneEditorShowsCollapsedNavigationTitleAfterBodyTitleScrollsAway() {
        let app = makeApp(extraEnvironment: ["EDITOR_UI_TEST_LARGE_PAGE_BLOCK_COUNT": "40"])
        app.launch()

        let pageTitle = app.textFields["editor.page-title"]
        XCTAssertTrue(pageTitle.waitForExistence(timeout: 5), "The editable page title should start in the document body")
        let collapsedTitle = app.staticTexts["editor.mobile-navigation-title"]
        XCTAssertFalse(
            collapsedTitle.exists,
            "The navigation title should stay hidden while the body title is visible"
        )

        let canvas = app.scrollViews["editor.canvas-scroll"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5), "The editor canvas should be scrollable")
        canvas.swipeUp()

        XCTAssertTrue(
            collapsedTitle.waitForExistence(timeout: 3),
            "The page title should appear in the blurred top bar once the body title scrolls away"
        )
        XCTAssertLessThanOrEqual(
            collapsedTitle.frame.minY,
            64,
            "The collapsed page title should be pinned in the top navigation bar"
        )
    }

    @MainActor
    func testIPhoneEditorKeepsTextColumnCloserToLeftEdge() {
        let app = makeApp()
        app.launch()

        let pageTitle = app.textFields["editor.page-title"]
        XCTAssertTrue(pageTitle.waitForExistence(timeout: 5), "The editable page title should be visible")
        XCTAssertLessThanOrEqual(
            pageTitle.frame.minX,
            43,
            "The page title should sit closer to the left edge to preserve writing space"
        )

        let firstTextView = app.textViews.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "editor.text.")
        ).firstMatch
        XCTAssertTrue(firstTextView.waitForExistence(timeout: 5), "The first text block should be visible")
        XCTAssertLessThanOrEqual(
            firstTextView.frame.minX,
            43,
            "The text column should sit closer to the left edge to preserve writing space"
        )
    }

    @MainActor
    func testIPhoneLongUnbrokenTextStaysInsideViewport() {
        let app = makeApp()
        app.launch()

        let firstTextView = app.textViews.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "editor.text.")
        ).firstMatch
        XCTAssertTrue(firstTextView.waitForExistence(timeout: 5), "The first text block should be editable")

        firstTextView.tap()
        firstTextView.typeText(" \(String(repeating: "longclipboardtoken", count: 10))")

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "The app window should be available for viewport checks")
        XCTAssertLessThanOrEqual(
            firstTextView.frame.maxX,
            window.frame.maxX - 8,
            "Long typed or pasted text should wrap inside the iPhone viewport instead of stretching to the right"
        )
    }

    @MainActor
    func testIPhoneEditorBackRevealsDocumentListThenLibrary() {
        let app = makeApp()
        app.launch()

        let firstTextView = app.textViews.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "editor.text.")
        ).firstMatch
        XCTAssertTrue(firstTextView.waitForExistence(timeout: 5), "iPhone should launch on the editor screen")

        let documentListBackButton = app.navigationBars.buttons["全部文档"]
        XCTAssertTrue(documentListBackButton.waitForExistence(timeout: 5), "The editor should expose the middle document-list screen as its back target")
        documentListBackButton.tap()

        XCTAssertTrue(
            app.scrollViews["editor.compact-document-list"].waitForExistence(timeout: 5),
            "Back from the editor should reveal the middle document-list screen"
        )
        XCTAssertTrue(app.buttons["editor.page.page-welcome"].waitForExistence(timeout: 5))

        let libraryBackButton = app.navigationBars.buttons["资料库"]
        XCTAssertTrue(libraryBackButton.waitForExistence(timeout: 5), "The document list should expose the left library screen as its back target")
        libraryBackButton.tap()

        XCTAssertTrue(
            app.scrollViews["editor.compact-library"].waitForExistence(timeout: 5),
            "Back from the document list should reveal the left library screen"
        )
        XCTAssertTrue(app.buttons["editor.compact.all-documents"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testIPhoneBlankCanvasRegionFocusesEditorAtDocumentEnd() {
        let app = makeApp()
        app.launch()

        let canvasRegion = app.descendants(matching: .any)["editor.canvas-edit-region"]
        XCTAssertTrue(canvasRegion.waitForExistence(timeout: 5), "The blank area below blocks should expose a focusable canvas region")
        XCTAssertGreaterThan(
            canvasRegion.frame.height,
            500,
            "The blank area below existing blocks should be large enough to tap comfortably like Craft"
        )
        canvasRegion.tap()

        XCTAssertTrue(
            app.otherElements["editor.mobile-keyboard-toolbar"].waitForExistence(timeout: 5),
            "Tapping the blank canvas area should focus the last editable block and show the keyboard toolbar"
        )
    }

    @MainActor
    func testIPhoneKeyboardToolbarKeepsRightSidebarAndMoreActionsOnly() {
        let app = makeApp()
        app.launch()

        let firstTextView = app.textViews.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "editor.text.")
        ).firstMatch
        XCTAssertTrue(firstTextView.waitForExistence(timeout: 5), "The first text block should be editable before checking the toolbar")
        firstTextView.tap()

        let toolbar = app.otherElements["editor.mobile-keyboard-toolbar"]
        XCTAssertTrue(toolbar.waitForExistence(timeout: 5), "The focused iPhone editor should show the compact keyboard toolbar")
        XCTAssertTrue(
            app.descendants(matching: .any)["editor.mobile-keyboard.outline"].waitForExistence(timeout: 5),
            "The compact keyboard toolbar should keep the right-sidebar outline action"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["editor.mobile-keyboard.more-format"].waitForExistence(timeout: 5),
            "The compact keyboard toolbar should keep the more-format action"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["editor.mobile-keyboard.copy"].waitForExistence(timeout: 5),
            "The compact keyboard toolbar should expose copy"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["editor.mobile-keyboard.paste"].waitForExistence(timeout: 5),
            "The compact keyboard toolbar should expose paste"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["editor.mobile-keyboard.undo"].waitForExistence(timeout: 5),
            "The compact keyboard toolbar should expose undo"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["editor.mobile-keyboard.heading"].waitForExistence(timeout: 5),
            "The compact keyboard toolbar should expose the heading picker"
        )
        XCTAssertFalse(app.descendants(matching: .any)["editor.mobile-keyboard.format"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["editor.mobile-keyboard.add-block"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["editor.mobile-keyboard.dismiss"].exists)
    }

    @MainActor
    func testIPhoneKeyboardHeadingButtonOpensH1H2H3Palette() {
        let app = makeApp()
        app.launch()

        let firstTextView = app.textViews.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "editor.text.")
        ).firstMatch
        XCTAssertTrue(firstTextView.waitForExistence(timeout: 5), "The first text block should be editable before checking the heading shortcut")
        firstTextView.tap()

        let headingButton = app.descendants(matching: .any)["editor.mobile-keyboard.heading"]
        XCTAssertTrue(headingButton.waitForExistence(timeout: 5), "The compact keyboard toolbar should expose 标题")
        headingButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["editor.mobile-format.H1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["editor.mobile-format.H2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["editor.mobile-format.H3"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testIPhoneFormatPaletteConvertsFocusedBlockToBulletedList() {
        let app = makeApp()
        app.launch()

        let firstTextView = app.textViews.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "editor.text.")
        ).firstMatch
        XCTAssertTrue(firstTextView.waitForExistence(timeout: 5), "The first text block should be editable before opening formatting")
        let blockID = firstTextView.identifier.replacingOccurrences(of: "editor.text.", with: "")

        firstTextView.tap()

        let toolbar = app.otherElements["editor.mobile-keyboard-toolbar"]
        XCTAssertTrue(
            toolbar.waitForExistence(timeout: 5),
            "The focused iPhone editor should first show Craft's compact keyboard toolbar"
        )
        XCTAssertFalse(
            app.otherElements["editor.mobile-format-palette"].exists,
            "Focusing a block should not flash or persist the expanded format palette before tapping 格式"
        )

        let moreButton = app.descendants(matching: .any)["editor.mobile-keyboard.more-format"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "The compact keyboard toolbar should expose 更多")
        moreButton.tap()

        let palette = app.otherElements["editor.mobile-format-palette"]
        XCTAssertTrue(
            palette.waitForExistence(timeout: 5),
            "The Craft-style format palette should appear in the lower half after tapping 格式"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["editor.mobile-format.Focus"].exists,
            "Chinese iPhone formatting should not expose the extra Focus concept"
        )

        let bullets = app.descendants(matching: .any)["editor.mobile-format.项目符号"]
        XCTAssertTrue(bullets.waitForExistence(timeout: 5), "The 正文 tab should expose a bulleted-list command")
        bullets.tap()

        let bulletRow = app.descendants(matching: .any)["editor.unordered-list.\(blockID)"]
        XCTAssertTrue(bulletRow.waitForExistence(timeout: 5), "Tapping Bullets should convert the focused block to a list item")
        XCTAssertTrue(
            app.otherElements["editor.mobile-keyboard-toolbar"].waitForExistence(timeout: 5),
            "Changing block type from the format palette should automatically return to the compact keyboard toolbar"
        )
        XCTAssertTrue(
            waitForNonExistence(palette, timeout: 5),
            "Changing block type should dismiss the expanded format palette without a second tap"
        )
    }

    @MainActor
    func testIPhoneLeftAndMiddleScreensSwipeLeftForward() {
        let app = makeApp()
        app.launch()

        let documentListBackButton = app.navigationBars.buttons["全部文档"]
        XCTAssertTrue(documentListBackButton.waitForExistence(timeout: 5), "Initial compact page should expose a back button to the document list")
        documentListBackButton.tap()

        let libraryBackButton = app.navigationBars.buttons["资料库"]
        XCTAssertTrue(libraryBackButton.waitForExistence(timeout: 5), "The document list should expose a back button to the library")
        libraryBackButton.tap()

        let library = app.scrollViews["editor.compact-library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5), "The left library screen should be visible")
        library.swipeLeft()

        let documentList = app.scrollViews["editor.compact-document-list"]
        XCTAssertTrue(documentList.waitForExistence(timeout: 5), "Swiping left from the library should reveal the middle document-list screen")
        documentList.swipeLeft()

        let firstTextView = app.textViews.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "editor.text.")
        ).firstMatch
        XCTAssertTrue(firstTextView.waitForExistence(timeout: 5), "Swiping left from the middle list should return to the editor screen")
    }

    @MainActor
    func testIPhoneFormatPaletteCollapsesBackToKeyboardToolbar() {
        let app = makeApp()
        app.launch()

        let firstTextView = app.textViews.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "editor.text.")
        ).firstMatch
        XCTAssertTrue(firstTextView.waitForExistence(timeout: 5), "The first text block should be editable before opening formatting")
        firstTextView.tap()

        let moreButton = app.descendants(matching: .any)["editor.mobile-keyboard.more-format"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "The compact keyboard toolbar should expose 更多")
        moreButton.tap()

        let palette = app.otherElements["editor.mobile-format-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 5), "The expanded format palette should appear after tapping 格式")

        let collapseButton = app.descendants(matching: .any)["editor.mobile-format.collapse"]
        XCTAssertTrue(collapseButton.waitForExistence(timeout: 5), "The expanded palette should expose a pull-down collapse affordance")
        collapseButton.tap()

        XCTAssertTrue(
            app.otherElements["editor.mobile-keyboard-toolbar"].waitForExistence(timeout: 5),
            "Collapsing the format palette should return to the compact keyboard toolbar"
        )
        XCTAssertTrue(
            waitForNonExistence(palette, timeout: 5),
            "The expanded format palette should not remain mounted after collapsing"
        )
    }

    @MainActor
    func testIPhoneHomeNewDocumentButtonOpensEditableBlankPage() {
        let app = makeApp()
        app.launch()

        let documentListBackButton = app.navigationBars.buttons["全部文档"]
        XCTAssertTrue(documentListBackButton.waitForExistence(timeout: 5), "Initial compact page should expose a back button to the document list")
        documentListBackButton.tap()

        let libraryBackButton = app.navigationBars.buttons["资料库"]
        XCTAssertTrue(libraryBackButton.waitForExistence(timeout: 5), "The document list should expose a back button to the library")
        libraryBackButton.tap()

        let newDocumentButton = app.buttons["editor.compact.new-document"]
        XCTAssertTrue(newDocumentButton.waitForExistence(timeout: 5), "The library screen should expose a direct new document button")
        newDocumentButton.tap()

        let blankTextView = app.textViews.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "editor.text.")
        ).firstMatch
        XCTAssertTrue(blankTextView.waitForExistence(timeout: 5), "New compact document should open directly on an editable block")

        blankTextView.tap()
        blankTextView.typeText(" 新文档输入")

        let value = blankTextView.value as? String ?? ""
        XCTAssertTrue(value.contains("新文档输入"), "Typing should work immediately after compact new document")
    }

    @MainActor
    func testIPhoneAllDocumentsShowsPreviewCardList() {
        let app = makeApp()
        app.launch()

        let documentListBackButton = app.navigationBars.buttons["全部文档"]
        XCTAssertTrue(documentListBackButton.waitForExistence(timeout: 5), "Initial compact page should expose a back button to the document list")
        documentListBackButton.tap()

        let libraryBackButton = app.navigationBars.buttons["资料库"]
        XCTAssertTrue(libraryBackButton.waitForExistence(timeout: 5), "The document list should expose a back button to the library")
        libraryBackButton.tap()

        let allDocuments = app.buttons["editor.compact.all-documents"]
        XCTAssertTrue(allDocuments.waitForExistence(timeout: 5), "The library screen should expose all documents")
        allDocuments.tap()

        XCTAssertTrue(
            app.scrollViews["editor.compact-document-list"].waitForExistence(timeout: 5),
            "All documents should open the middle document-list screen"
        )

        let welcomePage = app.buttons["editor.page.page-welcome"]
        XCTAssertTrue(welcomePage.waitForExistence(timeout: 5), "All documents should show the welcome page as a tappable preview card")

        let preview = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "开始用块写作")
        ).firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "All documents card should include the document text preview")
    }

    @MainActor
    func testIPhoneWelcomeBlockAcceptsTypedText() {
        let app = makeApp()
        app.launch()

        navigateToWelcomePage(in: app)

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible on iPhone")

        textView.tap()
        textView.typeText(" iOS edit")

        let value = textView.value as? String ?? ""
        XCTAssertTrue(value.contains("iOS edit"), "Typing on iPhone should update the native text view")
    }

    @MainActor
    private func navigateToWelcomePage(in app: XCUIApplication) {
        if app.textViews["editor.text.block-welcome-001"].waitForExistence(timeout: 1) {
            return
        }

        let documentListBackButton = app.navigationBars.buttons["全部文档"]
        XCTAssertTrue(documentListBackButton.waitForExistence(timeout: 5), "Editor should be able to reveal the document list")
        documentListBackButton.tap()

        let welcomePage = app.buttons["editor.page.page-welcome"]
        XCTAssertTrue(welcomePage.waitForExistence(timeout: 5), "Welcome page should be visible on iPhone")
        welcomePage.tap()
    }
}

private extension XCTestCase {
    func waitForNonExistence(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
