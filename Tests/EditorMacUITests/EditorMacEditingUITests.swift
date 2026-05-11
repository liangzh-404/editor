import XCTest

final class EditorMacEditingUITests: XCTestCase {
    private var appSupportDirectory: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        appSupportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorMacUITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: appSupportDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let appSupportDirectory {
            try? FileManager.default.removeItem(at: appSupportDirectory)
        }
        appSupportDirectory = nil
    }

    @MainActor
    func testWelcomeBlockAcceptsTypedText() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible and addressable")

        textView.click()
        textView.typeText(" Editable")

        let value = textView.value as? String ?? ""
        XCTAssertTrue(value.contains("Editable"), "Typing into the welcome block should update the native text view value")
    }
}
