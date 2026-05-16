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
    func testBoundaryArrowKeysMoveFocusBetweenTextBlocks() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let firstTextView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(firstTextView.waitForExistence(timeout: 5), "Welcome text block should be visible")
        let initialTextViewCount = app.textViews.count

        firstTextView.click()
        firstTextView.typeKey(.return, modifierFlags: [])

        let secondTextView = app.textViews.element(boundBy: initialTextViewCount)
        XCTAssertTrue(secondTextView.waitForExistence(timeout: 5), "Return should create a second editable block")
        app.typeText("Second block")

        secondTextView.typeKey(.leftArrow, modifierFlags: [.command])
        secondTextView.typeKey(.upArrow, modifierFlags: [])

        XCTAssertTrue(
            firstTextView.waitForKeyboardFocus(timeout: 5),
            "Up at the start of the second block should focus the previous text block"
        )
        app.typeText(" Prev")
        XCTAssertTrue(
            firstTextView.waitForValue(containing: "Prev", timeout: 5),
            "Typing after boundary Up should edit the previous block"
        )

        firstTextView.typeKey(.downArrow, modifierFlags: [])

        XCTAssertTrue(
            secondTextView.waitForKeyboardFocus(timeout: 5),
            "Down at the end of the first block should focus the next text block"
        )
        app.typeText("Next ")
        XCTAssertTrue(
            secondTextView.waitForValue(containing: "Next Second block", timeout: 5),
            "Typing after boundary Down should resume in the next block at its beginning"
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
    func testNotebookActionControlsExposeSemanticLabelsAndAvailability() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let notebookName = app.element(identifier: "editor.notebook.notebook-local.name")
        let moveUpButton = app.element(identifier: "editor.notebook.notebook-local.move-up")
        let moveDownButton = app.element(identifier: "editor.notebook.notebook-local.move-down")
        let outdentButton = app.element(identifier: "editor.notebook.notebook-local.outdent")
        let indentButton = app.element(identifier: "editor.notebook.notebook-local.indent")
        let addChildNotebookButton = app.element(identifier: "editor.notebook.notebook-local.add-child-notebook")
        let addPageButton = app.element(identifier: "editor.notebook.notebook-local.add-page")

        XCTAssertTrue(notebookName.waitForExistence(timeout: 5), "Default notebook row should be visible")
        XCTAssertTrue(moveUpButton.waitForExistence(timeout: 5), "Notebook row should expose move controls")
        XCTAssertEqual(moveUpButton.label, "Move notebook up")
        XCTAssertEqual(moveDownButton.label, "Move notebook down")
        XCTAssertEqual(outdentButton.label, "Outdent notebook")
        XCTAssertEqual(indentButton.label, "Indent notebook")
        XCTAssertEqual(addChildNotebookButton.label, "Add child notebook")
        XCTAssertEqual(addPageButton.label, "Add page to notebook")
        XCTAssertTrue(moveUpButton.waitForValue(containing: "Unavailable", timeout: 5))
        XCTAssertTrue(moveDownButton.waitForValue(containing: "Unavailable", timeout: 5))
        XCTAssertTrue(outdentButton.waitForValue(containing: "Unavailable", timeout: 5))
        XCTAssertTrue(indentButton.waitForValue(containing: "Unavailable", timeout: 5))
        XCTAssertTrue(addChildNotebookButton.waitForValue(containing: "Available", timeout: 5))
        XCTAssertTrue(addPageButton.waitForValue(containing: "Available", timeout: 5))
    }

    @MainActor
    func testFavoritePageAppearsInSidebarAndPageRowState() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_FAVORITE_PAGE"] = "1"
        app.launch()

        let favoritePageButton = app.element(identifier: "editor.favorite-page.page-welcome")
        let pageRow = app.element(identifier: "editor.page-row.page-welcome")

        XCTAssertTrue(favoritePageButton.waitForExistence(timeout: 5), "Favorited pages should appear in the sidebar")
        XCTAssertEqual(favoritePageButton.label, "Welcome")
        XCTAssertTrue(pageRow.waitForExistence(timeout: 5), "Page list row should expose favorite state")
        XCTAssertTrue(pageRow.waitForValue(containing: "Favorite", timeout: 5))
    }

    @MainActor
    func testPageFavoriteToggleUpdatesSidebarAndRowState() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let favoriteToggle = app.buttons["editor.page.page-welcome.favorite"]
        let favoritePageButton = app.element(identifier: "editor.favorite-page.page-welcome")
        let pageRow = app.element(identifier: "editor.page-row.page-welcome")

        XCTAssertTrue(pageRow.waitForExistence(timeout: 5), "Page list row should be visible before toggling favorite state")
        XCTAssertTrue(favoriteToggle.waitForExistence(timeout: 5), "Page rows should expose a direct favorite toggle")
        XCTAssertTrue(
            favoriteToggle.waitForLabelOrValue(containing: "Add page to favorites", timeout: 5),
            "Initial favorite toggle should describe the add action"
        )
        XCTAssertTrue(pageRow.waitForValue(containing: "Not favorite", timeout: 5))
        XCTAssertFalse(favoritePageButton.exists, "Fresh default page should not appear in Favorites before toggling")

        favoriteToggle.click()

        XCTAssertTrue(
            favoriteToggle.waitForLabelOrValue(containing: "Remove page from favorites", timeout: 5),
            "Favorite toggle should describe the remove action after adding"
        )
        XCTAssertTrue(pageRow.waitForValue(containing: "Favorite", timeout: 5))
        XCTAssertTrue(favoritePageButton.waitForExistence(timeout: 5), "Favorited page should appear in the sidebar")

        favoriteToggle.click()

        XCTAssertTrue(
            favoriteToggle.waitForLabelOrValue(containing: "Add page to favorites", timeout: 5),
            "Favorite toggle should return to the add action after removing"
        )
        XCTAssertTrue(pageRow.waitForValue(containing: "Not favorite", timeout: 5))
        XCTAssertTrue(favoritePageButton.waitForNonExistence(timeout: 5), "Removed favorite should leave the sidebar")
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
    func testCommandBFormatsSelectionAndKeepsSelectionInEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before keyboard formatting")

        textView.click()
        textView.typeKey("a", modifierFlags: [.command])
        textView.typeKey("b", modifierFlags: [.command])

        XCTAssertTrue(
            textView.waitForValue(containing: "**Start writing in blocks.**", timeout: 5),
            "Cmd-B should wrap the selected block text in Markdown bold markers"
        )

        app.typeText("strong")

        let didReplaceSelection = textView.waitForValue(containing: "**strong**", timeout: 5)
        let value = textView.value as? String ?? ""
        XCTAssertTrue(
            didReplaceSelection,
            "Typing after Cmd-B should replace the still-selected bold text; value=\(value)"
        )
    }

    @MainActor
    func testCommandBTogglesOffExistingBoldMarkersAndKeepsSelectionInEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before keyboard formatting")

        textView.click()
        textView.typeKey("a", modifierFlags: [.command])
        textView.typeKey("b", modifierFlags: [.command])
        XCTAssertTrue(
            textView.waitForValue(containing: "**Start writing in blocks.**", timeout: 5),
            "First Cmd-B should wrap the selected block text in Markdown bold markers"
        )

        textView.typeKey("b", modifierFlags: [.command])
        XCTAssertTrue(
            textView.waitForValue(containing: "Start writing in blocks.", timeout: 5),
            "Second Cmd-B should remove the surrounding Markdown bold markers"
        )

        app.typeText("plain")

        let value = textView.value as? String ?? ""
        XCTAssertEqual(
            value,
            "plain",
            "Typing after toggling bold off should replace the still-selected plain text without Markdown markers"
        )
    }

    @MainActor
    func testCommandBTogglesOffFullySelectedBoldMarkdownSpan() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before keyboard formatting")

        textView.click()
        textView.typeKey("a", modifierFlags: [.command])
        app.typeText("Bold sample")
        XCTAssertTrue(
            textView.waitForValue(containing: "Bold sample", timeout: 5),
            "Typing should replace the default welcome text before formatting"
        )

        textView.typeKey("a", modifierFlags: [.command])
        textView.typeKey("b", modifierFlags: [.command])
        XCTAssertTrue(
            textView.waitForValue(containing: "**Bold sample**", timeout: 5),
            "Cmd-B should wrap the full selected text in Markdown bold markers"
        )

        textView.typeKey("a", modifierFlags: [.command])
        textView.typeKey("b", modifierFlags: [.command])
        XCTAssertTrue(
            textView.waitForValue(containing: "Bold sample", timeout: 5),
            "Cmd-B should remove markers when the whole Markdown span is selected"
        )

        app.typeText("plain")

        let value = textView.value as? String ?? ""
        XCTAssertEqual(
            value,
            "plain",
            "Typing after toggling a fully selected Markdown span off should replace plain selected text"
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
    func testCommandEFormatsSelectionAsInlineCodeAndKeepsSelectionInEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before keyboard formatting")

        textView.click()
        textView.typeKey("a", modifierFlags: [.command])
        textView.typeKey("e", modifierFlags: [.command])

        XCTAssertTrue(
            textView.waitForValue(containing: "`Start writing in blocks.`", timeout: 5),
            "Cmd-E should wrap the selected block text in inline-code Markdown markers"
        )

        app.typeText("literal")

        let didReplaceSelection = textView.waitForValue(containing: "`literal`", timeout: 5)
        let value = textView.value as? String ?? ""
        XCTAssertTrue(
            didReplaceSelection,
            "Typing after Cmd-E should replace the still-selected inline-code text; value=\(value)"
        )
    }

    @MainActor
    func testStrikethroughToolbarInsertsPlaceholderAndKeepsTypingInEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before formatting")

        let strikethroughButton = app.buttons["editor.inline-format.strikethrough"]
        XCTAssertTrue(strikethroughButton.waitForExistence(timeout: 5), "Strikethrough toolbar button should be visible")
        strikethroughButton.click()

        XCTAssertTrue(
            textView.waitForValue(containing: "~~strikethrough~~", timeout: 5),
            "Strikethrough toolbar button should insert a strikethrough Markdown placeholder"
        )

        app.typeText("removed")

        let didReplacePlaceholder = textView.waitForValue(containing: "~~removed~~", timeout: 5)
        let value = textView.value as? String ?? ""
        XCTAssertTrue(
            didReplacePlaceholder,
            "Typing after the strikethrough toolbar action should replace the placeholder inside Markdown markers; value=\(value)"
        )
    }

    @MainActor
    func testCommandShiftXFormatsSelectionAndKeepsSelectionInEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before keyboard formatting")

        textView.click()
        textView.typeKey("a", modifierFlags: [.command])
        textView.typeKey("x", modifierFlags: [.command, .shift])

        XCTAssertTrue(
            textView.waitForValue(containing: "~~Start writing in blocks.~~", timeout: 5),
            "Cmd-Shift-X should wrap the selected block text in Markdown strikethrough markers"
        )

        app.typeText("removed")

        let didReplaceSelection = textView.waitForValue(containing: "~~removed~~", timeout: 5)
        let value = textView.value as? String ?? ""
        XCTAssertTrue(
            didReplaceSelection,
            "Typing after Cmd-Shift-X should replace the still-selected strikethrough text; value=\(value)"
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
    func testCommandKOpensInlineLinkPanelForSelection() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 10), "Welcome text block should be visible before keyboard link insertion")

        textView.click()
        textView.typeKey("a", modifierFlags: [.command])
        textView.typeKey("k", modifierFlags: [.command])

        let labelField = app.textFields["editor.insert-markdown-link.label"]
        XCTAssertTrue(labelField.waitForExistence(timeout: 5), "Cmd-K should open the inline link panel")
        labelField.click()
        labelField.typeText("Swift")

        let urlField = app.textFields["editor.insert-markdown-link.url"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 5), "Inline link panel should expose a URL field after Cmd-K")
        urlField.click()
        urlField.typeText("https://swift.org")

        let confirmButton = app.buttons["editor.insert-markdown-link.confirm"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "Inline link panel should expose a confirm button after Cmd-K")
        confirmButton.click()

        XCTAssertTrue(
            textView.waitForValue(containing: "[Swift](https://swift.org)", timeout: 5),
            "Confirming the Cmd-K link panel should replace the selected text with inline Markdown"
        )
    }

    @MainActor
    func testCommandKUpdatesExistingInlineLinkUnderSelection() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 10), "Welcome text block should be visible before link update")

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
            "Initial link insertion should place an editable inline Markdown link"
        )

        textView.typeKey("k", modifierFlags: [.command])

        XCTAssertTrue(
            labelField.waitForValue(containing: "Swift", timeout: 5),
            "Cmd-K from inside an existing inline link should prefill the current label"
        )
        XCTAssertTrue(
            urlField.waitForValue(containing: "https://swift.org", timeout: 5),
            "Cmd-K from inside an existing inline link should prefill the current URL"
        )

        labelField.click()
        labelField.typeKey("a", modifierFlags: [.command])
        labelField.typeText("Apple Docs")

        urlField.click()
        urlField.typeKey("a", modifierFlags: [.command])
        urlField.typeText("https://developer.apple.com")

        confirmButton.click()

        let didUpdateExistingLink = textView.waitForValue(
            containing: "[Apple Docs](https://developer.apple.com)",
            timeout: 5
        )
        let value = textView.value as? String ?? ""
        XCTAssertTrue(
            didUpdateExistingLink,
            "Updating from the prefilled link panel should replace the existing inline link; value=\(value)"
        )
    }

    @MainActor
    func testPastedMultilineTextExpandsNativeTextViewHeight() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before paste")
        let initialHeight = textView.frame.height
        let multilineText = (1...8)
            .map { "Pasted line \($0)" }
            .joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(multilineText, forType: .string)

        textView.click()
        XCTAssertTrue(
            textView.waitForKeyboardFocus(timeout: 5),
            "Native text view should be focused before paste"
        )
        textView.typeKey("a", modifierFlags: .command)
        textView.typeKey("v", modifierFlags: .command)

        XCTAssertTrue(
            textView.waitForValue(containing: "Pasted line 8", timeout: 5),
            "Pasting multiline text should update the native text view value"
        )
        XCTAssertGreaterThan(
            textView.frame.height,
            initialHeight + 72,
            "Native text view should grow enough to show multiline pasted text without internal clipping"
        )
    }

    @MainActor
    func testTaskBlockToggleExposesAndUpdatesCompletionState() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let blockTypeMenu = app.element(identifier: "editor.block.block-welcome-001.type-menu")
        XCTAssertTrue(blockTypeMenu.waitForExistence(timeout: 5), "Welcome block should expose its block type menu")
        blockTypeMenu.click()

        let taskMenuItem = app.menuItems["Task"]
        XCTAssertTrue(taskMenuItem.waitForExistence(timeout: 5), "Block type menu should expose the Task type")
        taskMenuItem.click()

        let taskToggle = app.buttons["editor.block.block-welcome-001.task-toggle"]
        XCTAssertTrue(taskToggle.waitForExistence(timeout: 5), "Changing a block to Task should expose the task toggle")
        XCTAssertEqual(taskToggle.label, "Mark task complete")
        XCTAssertTrue(
            taskToggle.waitForValue(containing: "Incomplete", timeout: 5),
            "Task toggle should expose the initial incomplete state"
        )

        taskToggle.click()

        XCTAssertEqual(taskToggle.label, "Mark task incomplete")
        XCTAssertTrue(
            taskToggle.waitForValue(containing: "Completed", timeout: 5),
            "Clicking the task toggle should expose the completed state"
        )
    }

    @MainActor
    func testToggleBlockButtonExposesAndUpdatesExpansionState() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let blockTypeMenu = app.element(identifier: "editor.block.block-welcome-001.type-menu")
        XCTAssertTrue(blockTypeMenu.waitForExistence(timeout: 5), "Welcome block should expose its block type menu")
        blockTypeMenu.click()

        let toggleMenuItem = app.menuItems["Toggle"]
        XCTAssertTrue(toggleMenuItem.waitForExistence(timeout: 5), "Block type menu should expose the Toggle type")
        toggleMenuItem.click()

        let toggleButton = app.buttons["editor.block.block-welcome-001.toggle-expansion"]
        XCTAssertTrue(toggleButton.waitForExistence(timeout: 5), "Changing a block to Toggle should expose expansion control")
        XCTAssertEqual(toggleButton.label, "Collapse toggle block")
        XCTAssertTrue(
            toggleButton.waitForValue(containing: "Expanded", timeout: 5),
            "Toggle control should expose the initial expanded state"
        )

        toggleButton.click()

        XCTAssertEqual(toggleButton.label, "Expand toggle block")
        XCTAssertTrue(
            toggleButton.waitForValue(containing: "Collapsed", timeout: 5),
            "Clicking the toggle control should expose the collapsed state"
        )
    }

    @MainActor
    func testCodeBlockWrapButtonExposesAndUpdatesLineWrapState() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let blockTypeMenu = app.element(identifier: "editor.block.block-welcome-001.type-menu")
        XCTAssertTrue(blockTypeMenu.waitForExistence(timeout: 5), "Welcome block should expose its block type menu")
        blockTypeMenu.click()

        let codeMenuItem = app.menuItems["Code"]
        XCTAssertTrue(codeMenuItem.waitForExistence(timeout: 5), "Block type menu should expose the Code type")
        codeMenuItem.click()

        let codeWrapButton = app.buttons["editor.block.block-welcome-001.code-wrap"]
        XCTAssertTrue(codeWrapButton.waitForExistence(timeout: 5), "Changing a block to Code should expose line-wrap control")
        XCTAssertEqual(codeWrapButton.label, "Disable code line wrap")
        XCTAssertTrue(
            codeWrapButton.waitForValue(containing: "Line wrap enabled", timeout: 5),
            "Code wrap control should expose the initial enabled state"
        )

        codeWrapButton.click()

        XCTAssertEqual(codeWrapButton.label, "Enable code line wrap")
        XCTAssertTrue(
            codeWrapButton.waitForValue(containing: "Line wrap disabled", timeout: 5),
            "Clicking the code wrap control should expose the disabled state"
        )
    }

    @MainActor
    func testBlockActionControlsExposeSemanticLabelsAndAvailability() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let dragHandle = app.element(identifier: "editor.block.block-welcome-001.drag-handle")
        let blockTypeMenu = app.element(identifier: "editor.block.block-welcome-001.type-menu")
        let moveUpButton = app.element(identifier: "editor.block.block-welcome-001.move-up")
        let moveDownButton = app.element(identifier: "editor.block.block-welcome-001.move-down")
        let outdentButton = app.element(identifier: "editor.block.block-welcome-001.outdent")
        let indentButton = app.element(identifier: "editor.block.block-welcome-001.indent")
        let deleteButton = app.element(identifier: "editor.block.block-welcome-001.delete")

        XCTAssertTrue(dragHandle.waitForExistence(timeout: 5), "Welcome block should expose a drag handle")
        XCTAssertEqual(dragHandle.label, "Block drag handle")
        XCTAssertTrue(
            dragHandle.waitForValue(containing: "Paragraph", timeout: 5),
            "Drag handle should expose the current block type"
        )

        XCTAssertTrue(blockTypeMenu.waitForExistence(timeout: 5), "Welcome block should expose its block type menu")
        XCTAssertEqual(blockTypeMenu.label, "Change block type")
        XCTAssertTrue(
            blockTypeMenu.waitForValue(containing: "Paragraph", timeout: 5),
            "Block type menu should expose the current block type"
        )

        XCTAssertEqual(moveUpButton.label, "Move block up")
        XCTAssertEqual(moveDownButton.label, "Move block down")
        XCTAssertEqual(outdentButton.label, "Outdent block")
        XCTAssertEqual(indentButton.label, "Indent block")
        XCTAssertEqual(deleteButton.label, "Delete block")
        XCTAssertTrue(moveUpButton.waitForValue(containing: "Unavailable", timeout: 5))
        XCTAssertTrue(moveDownButton.waitForValue(containing: "Unavailable", timeout: 5))
        XCTAssertTrue(outdentButton.waitForValue(containing: "Unavailable", timeout: 5))
        XCTAssertTrue(indentButton.waitForValue(containing: "Unavailable", timeout: 5))
        XCTAssertTrue(deleteButton.waitForValue(containing: "Available", timeout: 5))
    }

    @MainActor
    func testTableControlsExposeSemanticLabelsAndDimensions() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let blockTypeMenu = app.element(identifier: "editor.block.block-welcome-001.type-menu")
        XCTAssertTrue(blockTypeMenu.waitForExistence(timeout: 5), "Welcome block should expose its block type menu")
        blockTypeMenu.click()

        let tableMenuItem = app.menuItems["Table"]
        XCTAssertTrue(tableMenuItem.waitForExistence(timeout: 5), "Block type menu should expose the Table type")
        tableMenuItem.click()

        let addRowButton = app.element(identifier: "editor.table.block-welcome-001.add-row")
        let addColumnButton = app.element(identifier: "editor.table.block-welcome-001.add-column")
        let removeRowButton = app.element(identifier: "editor.table.block-welcome-001.remove-row")
        let removeColumnButton = app.element(identifier: "editor.table.block-welcome-001.remove-column")

        XCTAssertTrue(addRowButton.waitForExistence(timeout: 5), "Changing a block to Table should expose row controls")
        XCTAssertEqual(addRowButton.label, "Add table row")
        XCTAssertEqual(addColumnButton.label, "Add table column")
        XCTAssertEqual(removeRowButton.label, "Remove last table row")
        XCTAssertEqual(removeColumnButton.label, "Remove last table column")
        XCTAssertTrue(
            addRowButton.waitForValue(containing: "1 row, 1 column", timeout: 5),
            "Table controls should expose the initial table dimensions"
        )

        addRowButton.click()
        XCTAssertTrue(
            addRowButton.waitForValue(containing: "2 rows, 1 column", timeout: 5),
            "Adding a row should update the exposed table dimensions"
        )

        addColumnButton.click()
        XCTAssertTrue(
            addColumnButton.waitForValue(containing: "2 rows, 2 columns", timeout: 5),
            "Adding a column should update the exposed table dimensions"
        )

        removeRowButton.click()
        XCTAssertTrue(
            removeRowButton.waitForValue(containing: "1 row, 2 columns", timeout: 5),
            "Removing a row should update the exposed table dimensions"
        )

        removeColumnButton.click()
        XCTAssertTrue(
            removeColumnButton.waitForValue(containing: "1 row, 1 column", timeout: 5),
            "Removing a column should update the exposed table dimensions"
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
    func testMarkdownImportToolbarImportsFixtureFile() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_MARKDOWN_IMPORT_TEXT"] = "# Imported Heading\n\nImported paragraph from toolbar"
        app.launch()

        let importButton = app.buttons["editor.import-markdown"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5), "Markdown import toolbar button should be visible")
        importButton.click()

        let importedParagraph = app.textViews
            .matching(NSPredicate(format: "value CONTAINS %@", "Imported paragraph from toolbar"))
            .firstMatch
        XCTAssertTrue(
            importedParagraph.waitForExistence(timeout: 5),
            "Clicking the Markdown import toolbar button should import the fixture file into the editor"
        )
    }

    @MainActor
    func testOutlinePanelExposesHeadingLevelAndFocusesHeading() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_MARKDOWN_IMPORT_TEXT"] =
            "# Imported Heading\n\n## Imported Section\n\n### Imported Detail\n\nImported paragraph from toolbar"
        app.launch()

        let importButton = app.buttons["editor.import-markdown"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5), "Markdown import toolbar button should be visible")
        importButton.click()

        let outlinePanel = app.element(identifier: "editor.outline")
        XCTAssertTrue(outlinePanel.waitForExistence(timeout: 5), "Imported heading should create an Outline panel")

        let outlineRow = app.element(identifierPrefix: "editor.outline.")
        XCTAssertTrue(outlineRow.waitForExistence(timeout: 5), "Outline panel should expose the imported heading")
        XCTAssertEqual(outlineRow.label, "Outline heading Imported Heading")
        XCTAssertTrue(outlineRow.waitForValue(containing: "Level 1", timeout: 5))

        let sectionRow = app.buttons["Outline heading Imported Section"]
        XCTAssertTrue(sectionRow.waitForExistence(timeout: 5), "Outline panel should expose imported level-two headings")
        XCTAssertTrue(sectionRow.waitForValue(containing: "Level 2", timeout: 5))

        let detailRow = app.buttons["Outline heading Imported Detail"]
        XCTAssertTrue(detailRow.waitForExistence(timeout: 5), "Outline panel should expose imported level-three headings")
        XCTAssertTrue(detailRow.waitForValue(containing: "Level 3", timeout: 5))

        let headingTextView = app.textViews
            .matching(NSPredicate(format: "value CONTAINS %@", "Imported Heading"))
            .firstMatch
        XCTAssertTrue(headingTextView.waitForExistence(timeout: 5), "Imported heading text view should be visible")

        outlineRow.click()

        XCTAssertTrue(
            headingTextView.waitForKeyboardFocus(timeout: 5),
            "Clicking an Outline heading should focus the corresponding editor heading block"
        )
    }

    @MainActor
    func testMarkdownExportToolbarCapturesCurrentPageMarkdown() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_MARKDOWN_EXPORT_CAPTURE"] = "1"
        app.launch()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome block should be loaded before exporting")
        XCTAssertTrue(
            textView.waitForValue(containing: "Start writing in blocks.", timeout: 5),
            "Welcome block text should be loaded before exporting"
        )

        let exportButton = app.buttons["editor.export-markdown"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5), "Markdown export toolbar button should be visible")
        exportButton.click()

        let exportedMarkdown = app.staticTexts["editor.markdown-export-test-output"]
        XCTAssertTrue(exportedMarkdown.waitForExistence(timeout: 5), "Markdown export should publish captured test output")
        let exportedLabel = exportedMarkdown.label
        let exportedValue = exportedMarkdown.value as? String ?? ""
        XCTAssertTrue(
            exportedMarkdown.waitForLabelOrValue(containing: "Start writing in blocks.", timeout: 5),
            "Clicking the Markdown export toolbar button should capture the current page Markdown; label=\(exportedLabel) value=\(exportedValue)"
        )
    }

    @MainActor
    func testAttachmentToolbarImportsFixtureAndRendersAttachmentRow() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_ATTACHMENT_IMPORT_FILENAME"] = "toolbar-attachment.txt"
        app.launchEnvironment["EDITOR_UI_TEST_ATTACHMENT_IMPORT_CONTENTS"] = "Attachment imported through the toolbar"
        app.launch()

        let attachmentButton = app.buttons["editor.insert-attachment"]
        XCTAssertTrue(attachmentButton.waitForExistence(timeout: 5), "Attachment toolbar button should be visible")
        attachmentButton.click()

        let insertedAttachment = app.element(identifierPrefix: "editor.attachment.")
        XCTAssertTrue(insertedAttachment.waitForExistence(timeout: 10), "Toolbar attachment import should render an attachment row")
        XCTAssertTrue(
            insertedAttachment.waitForLabelOrValue(containing: "toolbar-attachment.txt", timeout: 5),
            "Toolbar attachment row should expose the imported filename"
        )
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
    func testConflictDraftButtonsSeedManualMergeEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_CONFLICT"] = "1"
        app.launch()

        let mergeText = app.textViews
            .matching(NSPredicate(format: "identifier ENDSWITH %@", ".merge-text"))
            .firstMatch
        XCTAssertTrue(mergeText.waitForExistence(timeout: 5), "Seeded conflict should expose a manual merge editor")
        XCTAssertTrue(
            mergeText.waitForValue(containing: "Local conflict draft", timeout: 5),
            "Conflict merge editor should start from the local text"
        )

        let remoteDraftButton = app.buttons
            .matching(NSPredicate(format: "identifier ENDSWITH %@", ".draft-remote"))
            .firstMatch
        XCTAssertTrue(remoteDraftButton.waitForExistence(timeout: 5), "Conflict row should expose a remote draft button")
        remoteDraftButton.click()
        XCTAssertTrue(
            mergeText.waitForValue(containing: "Remote conflict draft", timeout: 5),
            "Remote draft button should copy the remote text into the manual merge editor"
        )

        let applyMergeButton = app.buttons
            .matching(NSPredicate(format: "identifier ENDSWITH %@", ".apply-merge"))
            .firstMatch
        XCTAssertTrue(
            applyMergeButton.waitForExistence(timeout: 5),
            "Copying a conflict draft should not resolve or remove the conflict row"
        )

        let localDraftButton = app.buttons
            .matching(NSPredicate(format: "identifier ENDSWITH %@", ".draft-local"))
            .firstMatch
        XCTAssertTrue(localDraftButton.waitForExistence(timeout: 5), "Conflict row should expose a local draft button")
        localDraftButton.click()
        XCTAssertTrue(
            mergeText.waitForValue(containing: "Local conflict draft", timeout: 5),
            "Local draft button should copy the local text back into the manual merge editor"
        )
    }

    @MainActor
    func testConflictDraftAllButtonsSeedEveryManualMergeEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_CONFLICT"] = "1"
        app.launchEnvironment["EDITOR_UI_TEST_CONFLICT_COUNT"] = "2"
        app.launch()

        let mergeTexts = app.textViews
            .matching(NSPredicate(format: "identifier ENDSWITH %@", ".merge-text"))
        let firstMergeText = mergeTexts.element(boundBy: 0)
        let secondMergeText = mergeTexts.element(boundBy: 1)
        XCTAssertTrue(firstMergeText.waitForExistence(timeout: 5), "First seeded conflict should expose a merge editor")
        XCTAssertTrue(secondMergeText.waitForExistence(timeout: 5), "Second seeded conflict should expose a merge editor")
        XCTAssertTrue(
            firstMergeText.waitForValue(containing: "Local conflict draft", timeout: 5),
            "The first merge editor should start from its local text"
        )
        XCTAssertTrue(
            secondMergeText.waitForValue(containing: "Local conflict draft 2", timeout: 5),
            "The second merge editor should start from its local text"
        )

        let draftAllRemoteButton = app.buttons["editor.conflict.draft-all-remote"]
        XCTAssertTrue(draftAllRemoteButton.waitForExistence(timeout: 5), "Conflict panel should expose a remote batch draft button")
        draftAllRemoteButton.click()
        XCTAssertTrue(
            firstMergeText.waitForValue(containing: "Remote conflict draft", timeout: 5),
            "Batch remote draft should copy the first remote text into its merge editor"
        )
        XCTAssertTrue(
            secondMergeText.waitForValue(containing: "Remote conflict draft 2", timeout: 5),
            "Batch remote draft should copy the second remote text into its merge editor"
        )

        let secondApplyMergeButton = app.buttons
            .matching(NSPredicate(format: "identifier ENDSWITH %@", ".apply-merge"))
            .element(boundBy: 1)
        XCTAssertTrue(
            secondApplyMergeButton.waitForExistence(timeout: 5),
            "Batch draft seeding should keep both conflict rows unresolved"
        )

        let draftAllLocalButton = app.buttons["editor.conflict.draft-all-local"]
        XCTAssertTrue(draftAllLocalButton.waitForExistence(timeout: 5), "Conflict panel should expose a local batch draft button")
        draftAllLocalButton.click()
        XCTAssertTrue(
            firstMergeText.waitForValue(containing: "Local conflict draft", timeout: 5),
            "Batch local draft should copy the first local text back into its merge editor"
        )
        XCTAssertTrue(
            secondMergeText.waitForValue(containing: "Local conflict draft 2", timeout: 5),
            "Batch local draft should copy the second local text back into its merge editor"
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
        let scrollMetrics = app.element(identifier: "editor.scroll-metrics-test-output")
        for _ in 0..<30 where !distantBlock.exists {
            canvas.swipeUp()
        }

        let scrollMetricsValueAfterSwipes = scrollMetrics.stringValue
        XCTAssertTrue(
            distantBlock.waitForExistence(timeout: 5),
            "Scrolling the editor canvas should realize distant blocks in a large page; metrics=\(scrollMetricsValueAfterSwipes)"
        )
        XCTAssertTrue(
            distantBlock.waitForValue(containing: "Large block 80 searchable content", timeout: 5),
            "The realized distant block should expose the expected seeded text"
        )

        XCTAssertTrue(
            scrollMetrics.waitForLabelOrValue(containing: "block_count=760", timeout: 5),
            "Large-page runtime scroll capture should expose seeded page size"
        )
        XCTAssertTrue(
            scrollMetrics.waitForLabelOrValue(containing: "large_page=true", timeout: 5),
            "Large-page runtime scroll capture should mark the page as large"
        )

        let scrollMetricsValue = scrollMetrics.stringValue
        XCTAssertGreaterThanOrEqual(
            scrollMetricsValue.integerField("last_visible_block_index") ?? -1,
            79,
            "Runtime scroll capture should prove the realized visible window reached the distant block; value=\(scrollMetricsValue)"
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

    var stringValue: String {
        let valueText = value as? String ?? ""
        return valueText.isEmpty ? label : valueText
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

private extension String {
    func integerField(_ name: String) -> Int? {
        let prefix = "\(name)="
        guard let field = split(separator: " ").first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        return Int(field.dropFirst(prefix.count))
    }
}
