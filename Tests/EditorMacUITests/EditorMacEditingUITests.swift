import Darwin
import AppKit
import XCTest

final class EditorMacEditingUITests: XCTestCase {
    private var appSupportDirectory: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        Self.terminateRunningEditorMacApplications()
        let appContainerApplicationSupport = try Self.currentUserHomeDirectory()
            .appendingPathComponent(
                "Library/Containers/com.liangzhang.editor.mac/Data/Library/Application Support",
                isDirectory: true
            )
        appSupportDirectory = appContainerApplicationSupport
            .appendingPathComponent("EditorMacUITests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        Self.terminateRunningEditorMacApplications()
        if let appSupportDirectory {
            try? FileManager.default.removeItem(at: appSupportDirectory)
        }
        appSupportDirectory = nil
    }

    private static func currentUserHomeDirectory() throws -> URL {
        guard let passwordEntry = getpwuid(getuid()),
              let homeDirectory = passwordEntry.pointee.pw_dir else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        return URL(fileURLWithPath: String(cString: homeDirectory), isDirectory: true)
    }

    private static func terminateRunningEditorMacApplications() {
        let runningApplications = NSRunningApplication.runningApplications(withBundleIdentifier: "com.liangzhang.editor.mac")
        guard !runningApplications.isEmpty else {
            return
        }

        runningApplications.forEach { application in
            application.terminate()
        }

        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            let isStillRunning = NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.liangzhang.editor.mac")
                .contains { !$0.isTerminated }
            if !isStillRunning {
                return
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.liangzhang.editor.mac")
            .forEach { $0.forceTerminate() }
        waitForEditorMacTermination(until: Date().addingTimeInterval(3))
    }

    @discardableResult
    private static func waitForEditorMacTermination(until deadline: Date) -> Bool {
        while Date() < deadline {
            let isStillRunning = NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.liangzhang.editor.mac")
                .contains { !$0.isTerminated }
            if !isStillRunning {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return false
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

    @MainActor
    func testClickingBlockRowFocusesEditorForTyping() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let blockRow = app.groups["editor.block.block-welcome-001"]
        XCTAssertTrue(blockRow.waitForExistence(timeout: 5), "Welcome block row should be visible and tappable")
        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before row focus")

        blockRow.click()
        XCTAssertTrue(
            textView.waitForKeyboardFocus(timeout: 5),
            "Clicking the block row should move keyboard focus into the native text view"
        )
        app.typeText(" Row focus")

        let value = textView.value as? String ?? ""
        XCTAssertTrue(value.contains("Row focus"), "Typing after clicking the block row should edit the native text view")
    }

    @MainActor
    func testReturnCreatesNextBlockAndKeepsTypingInEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible and addressable")
        let initialTextViewCount = app.textViews.count

        textView.click()
        textView.typeKey(.return, modifierFlags: [])

        let insertedTextView = app.textViews.element(boundBy: initialTextViewCount)
        XCTAssertTrue(insertedTextView.waitForExistence(timeout: 5), "Return should insert a new editable text block")

        app.typeText("After return")

        let insertedValue = insertedTextView.value as? String ?? ""
        XCTAssertTrue(
            insertedValue.contains("After return"),
            "Typing after Return should continue in the inserted block"
        )
    }

    @MainActor
    func testAddButtonCreatesNextBlockAndKeepsTypingInEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before adding")
        let initialTextViewCount = app.textViews.count

        app.buttons["editor.add-block"].click()

        let insertedTextView = app.textViews.element(boundBy: initialTextViewCount)
        XCTAssertTrue(insertedTextView.waitForExistence(timeout: 5), "Add should insert a new editable text block")

        app.typeText("Added with toolbar")

        let insertedValue = insertedTextView.value as? String ?? ""
        XCTAssertTrue(
            insertedValue.contains("Added with toolbar"),
            "Typing after Add should continue in the inserted block"
        )
    }

    @MainActor
    func testItalicToolbarInsertsPlaceholderAndKeepsTypingInEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before formatting")

        let italicButton = app.buttons["editor.inline-format.italic"]
        XCTAssertTrue(italicButton.waitForExistence(timeout: 5), "Italic toolbar button should be visible")
        italicButton.click()

        XCTAssertTrue(
            textView.waitForValue(containing: "*italic*", timeout: 5),
            "Italic toolbar button should insert an italic Markdown placeholder"
        )

        app.typeText("styled")

        let didReplacePlaceholder = textView.waitForValue(containing: "*styled*", timeout: 5)
        let value = textView.value as? String ?? ""
        XCTAssertTrue(
            didReplacePlaceholder,
            "Typing after the italic toolbar action should replace the placeholder inside Markdown markers; value=\(value)"
        )
    }

    @MainActor
    func testBoldToolbarInsertsPlaceholderAndKeepsTypingInEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before formatting")

        let boldButton = app.buttons["editor.inline-format.bold"]
        XCTAssertTrue(boldButton.waitForExistence(timeout: 5), "Bold toolbar button should be visible")
        boldButton.click()

        XCTAssertTrue(
            textView.waitForValue(containing: "**bold**", timeout: 5),
            "Bold toolbar button should insert a bold Markdown placeholder"
        )

        app.typeText("strong")

        let didReplacePlaceholder = textView.waitForValue(containing: "**strong**", timeout: 5)
        let value = textView.value as? String ?? ""
        XCTAssertTrue(
            didReplacePlaceholder,
            "Typing after the bold toolbar action should replace the placeholder inside Markdown markers; value=\(value)"
        )
    }

    @MainActor
    func testCodeToolbarInsertsPlaceholderAndKeepsTypingInEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before formatting")

        let codeButton = app.buttons["editor.inline-format.code"]
        XCTAssertTrue(codeButton.waitForExistence(timeout: 5), "Inline code toolbar button should be visible")
        codeButton.click()

        XCTAssertTrue(
            textView.waitForValue(containing: "`code`", timeout: 5),
            "Inline code toolbar button should insert a code Markdown placeholder"
        )

        app.typeText("literal")

        let didReplacePlaceholder = textView.waitForValue(containing: "`literal`", timeout: 5)
        let value = textView.value as? String ?? ""
        XCTAssertTrue(
            didReplacePlaceholder,
            "Typing after the inline code toolbar action should replace the placeholder inside Markdown markers; value=\(value)"
        )
    }

    @MainActor
    func testInlineLinkPanelReplacesSelectionAndKeepsLabelSelected() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 10), "Welcome text block should be visible before link insertion")

        textView.click()
        textView.typeKey("a", modifierFlags: [.command])

        let linkButton = app.buttons["editor.insert-markdown-link"]
        XCTAssertTrue(linkButton.waitForExistence(timeout: 5), "Inline link toolbar button should be visible")
        linkButton.click()

        let labelField = app.textFields["editor.insert-markdown-link.label"]
        XCTAssertTrue(labelField.waitForExistence(timeout: 5), "Inline link panel should expose a label field")
        labelField.click()
        labelField.typeText("Swift")

        let urlField = app.textFields["editor.insert-markdown-link.url"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 5), "Inline link panel should expose a URL field")
        urlField.click()
        urlField.typeText("https://swift.org")

        let confirmButton = app.buttons["editor.insert-markdown-link.confirm"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "Inline link panel should expose a confirm button")
        confirmButton.click()

        XCTAssertTrue(
            textView.waitForValue(containing: "[Swift](https://swift.org)", timeout: 5),
            "Confirming the link panel should replace the selected text with inline Markdown"
        )

        app.typeText("Docs")

        let didReplaceLabel = textView.waitForValue(containing: "[Docs](https://swift.org)", timeout: 5)
        let value = textView.value as? String ?? ""
        XCTAssertTrue(
            didReplaceLabel,
            "Typing after selected-range link insertion should replace the link label; value=\(value)"
        )
    }

    @MainActor
    func testReferenceMenusInsertPageAndBlockReferenceRows() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_REFERENCE_TARGETS"] = "1"
        app.launch()

        let pageReferenceMenu = app.element(identifier: "editor.insert-page-reference")
        XCTAssertTrue(pageReferenceMenu.waitForExistence(timeout: 5), "Page reference menu should be visible")
        XCTAssertTrue(pageReferenceMenu.isEnabled, "Seeded reference targets should enable the page reference menu")
        pageReferenceMenu.click()

        let targetPageItem = app.menuItems["Reference Target"]
        XCTAssertTrue(targetPageItem.waitForExistence(timeout: 5), "Page reference menu should include the seeded target page")
        targetPageItem.click()

        let insertedPageReference = app.element(identifierPrefix: "editor.page-reference.")
        XCTAssertTrue(insertedPageReference.waitForExistence(timeout: 5), "Selecting a target page should insert a page-reference row")

        let blockReferenceMenu = app.element(identifier: "editor.insert-block-reference")
        XCTAssertTrue(blockReferenceMenu.waitForExistence(timeout: 5), "Block reference menu should be visible")
        XCTAssertTrue(blockReferenceMenu.isEnabled, "Seeded reference targets should enable the block reference menu")
        blockReferenceMenu.click()

        let targetBlockItem = app.menuItems["Reference Target: Reference target block"]
        XCTAssertTrue(targetBlockItem.waitForExistence(timeout: 5), "Block reference menu should include the seeded target block")
        targetBlockItem.click()

        let insertedBlockReference = app.element(identifierPrefix: "editor.block-reference.")
        XCTAssertTrue(insertedBlockReference.waitForExistence(timeout: 5), "Selecting a target block should insert a block-reference row")
    }

    @MainActor
    func testAttachmentSeedImportsAndRendersAttachmentRow() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_ATTACHMENT_FILENAME"] = "ui-attachment.txt"
        app.launch()

        let insertedAttachment = app.element(identifierPrefix: "editor.attachment.")
        XCTAssertTrue(insertedAttachment.waitForExistence(timeout: 10), "Seeded attachment source should render an attachment row")
        XCTAssertTrue(
            insertedAttachment.waitForLabelOrValue(containing: "ui-attachment.txt", timeout: 5),
            "Attachment row should expose the imported filename"
        )
    }

    @MainActor
    func testLargePageScrollLoadsDistantBlocks() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_LARGE_PAGE_BLOCK_COUNT"] = "760"
        app.launch()

        let firstBlock = app.textViews["editor.text.block-ui-large-001"]
        XCTAssertTrue(
            firstBlock.waitForExistence(timeout: 10),
            "A seeded large page should render the first block before scrolling"
        )
        XCTAssertTrue(
            firstBlock.waitForValue(containing: "Large block 1 searchable content", timeout: 5),
            "The first seeded large-page block should expose its text value"
        )

        let canvas = app.scrollViews["editor.canvas-scroll"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5), "The editor canvas scroll view should be addressable")

        let distantBlock = app.textViews["editor.text.block-ui-large-080"]
        for _ in 0..<30 where !distantBlock.exists {
            canvas.swipeUp()
        }

        XCTAssertTrue(
            distantBlock.waitForExistence(timeout: 5),
            "Scrolling the editor canvas should realize distant blocks in a large page"
        )
        XCTAssertTrue(
            distantBlock.waitForValue(containing: "Large block 80 searchable content", timeout: 5),
            "The realized distant block should expose the expected seeded text"
        )
    }

}

private extension XCUIElement {
    func waitForKeyboardFocus(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "hasKeyboardFocus == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    func waitForValue(containing text: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { element, _ in
            guard let element = element as? XCUIElement,
                  let value = element.value as? String else {
                return false
            }
            return value.contains(text)
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    func waitForLabelOrValue(containing text: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { element, _ in
            guard let element = element as? XCUIElement else {
                return false
            }
            let value = element.value as? String ?? ""
            return element.label.contains(text) || value.contains(text)
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}

private extension XCUIApplication {
    func element(identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier]
    }

    func element(identifierPrefix: String) -> XCUIElement {
        descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", identifierPrefix))
            .firstMatch
    }
}
