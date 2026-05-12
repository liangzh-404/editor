import XCTest

final class EditorIOSEditingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
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
