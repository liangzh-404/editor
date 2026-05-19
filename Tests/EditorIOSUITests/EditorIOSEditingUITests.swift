import XCTest

final class EditorIOSEditingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_UI_TEST_RESET_STORE"] = "1"
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

        let formatButton = app.descendants(matching: .any)["editor.mobile-keyboard.format"]
        XCTAssertTrue(formatButton.waitForExistence(timeout: 5), "The compact keyboard toolbar should expose 格式")
        formatButton.tap()

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
            palette.waitForExistence(timeout: 3),
            "Changing block type from the format palette should keep the editor focused with the palette available"
        )

        let collapseButton = app.descendants(matching: .any)["editor.mobile-format.collapse"]
        XCTAssertTrue(collapseButton.waitForExistence(timeout: 5), "The palette should still be able to return to the keyboard after a type change")
        collapseButton.tap()
        XCTAssertTrue(
            app.otherElements["editor.mobile-keyboard-toolbar"].waitForExistence(timeout: 5),
            "Returning from the palette after a type change should restore the compact keyboard toolbar"
        )
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

        let formatButton = app.descendants(matching: .any)["editor.mobile-keyboard.format"]
        XCTAssertTrue(formatButton.waitForExistence(timeout: 5), "The compact keyboard toolbar should expose 格式")
        formatButton.tap()

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
