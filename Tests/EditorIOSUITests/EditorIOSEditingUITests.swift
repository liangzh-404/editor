import XCTest

final class EditorIOSEditingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testIPhoneLaunchOpensEditablePageImmediately() {
        let app = XCUIApplication()
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
        let app = XCUIApplication()
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
    func testIPhoneHomeNewDocumentButtonOpensEditableBlankPage() {
        let app = XCUIApplication()
        app.launch()

        let homeBackButton = app.navigationBars.buttons["近期打开"]
        XCTAssertTrue(homeBackButton.waitForExistence(timeout: 5), "Initial compact page should expose a back button to recent home")
        homeBackButton.tap()

        let newDocumentButton = app.buttons["editor.compact.new-document"]
        XCTAssertTrue(newDocumentButton.waitForExistence(timeout: 5), "Recent home should expose a direct new document button")
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
        let app = XCUIApplication()
        app.launch()

        let homeBackButton = app.navigationBars.buttons["近期打开"]
        XCTAssertTrue(homeBackButton.waitForExistence(timeout: 5), "Initial compact page should expose a back button to recent home")
        homeBackButton.tap()

        let allDocuments = app.buttons["editor.compact.all-documents"]
        XCTAssertTrue(allDocuments.waitForExistence(timeout: 5), "Recent home should expose all documents")
        allDocuments.tap()

        let welcomePage = app.buttons["editor.page.page-welcome"]
        XCTAssertTrue(welcomePage.waitForExistence(timeout: 5), "All documents should show the welcome page as a tappable preview card")

        let preview = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "开始用块写作")
        ).firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "All documents card should include the document text preview")
    }

    @MainActor
    func testIPhoneWelcomeBlockAcceptsTypedText() {
        let app = XCUIApplication()
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

        let workspace = app.buttons["editor.workspace.workspace-local"]
        XCTAssertTrue(workspace.waitForExistence(timeout: 5), "Local workspace should be visible on iPhone")
        workspace.tap()

        let welcomePage = app.buttons["editor.page.page-welcome"]
        XCTAssertTrue(welcomePage.waitForExistence(timeout: 5), "Welcome page should be visible on iPhone")
        welcomePage.tap()
    }
}
