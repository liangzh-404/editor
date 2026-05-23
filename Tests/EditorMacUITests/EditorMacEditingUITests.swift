import Darwin
import XCTest
import AppKit

final class EditorMacEditingUITests: XCTestCase {
    private static let editorMacBundleIdentifier = "com.liangzhang.editor.mac"

    private var appSupportDirectory: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        addSystemPermissionInterruptionMonitor()
        MainActor.assumeIsolated {
            Self.terminateRunningEditorMacApplications()
        }
        let appContainerApplicationSupport = try Self.currentUserHomeDirectory()
            .appendingPathComponent(
                "Library/Containers/com.liangzhang.editor.mac/Data/Library/Application Support",
                isDirectory: true
            )
        appSupportDirectory = appContainerApplicationSupport
            .appendingPathComponent("EditorMacUITests-\(UUID().uuidString)", isDirectory: true)
        try Self.removeSavedWindowState()
    }

    override func tearDownWithError() throws {
        MainActor.assumeIsolated {
            Self.terminateRunningEditorMacApplications()
        }
        if let appSupportDirectory {
            try? FileManager.default.removeItem(at: appSupportDirectory)
        }
        appSupportDirectory = nil
    }

    private func addSystemPermissionInterruptionMonitor() {
        addUIInterruptionMonitor(withDescription: "系统权限弹窗") { alert in
            let hasChineseAppDataPrompt = alert.staticTexts
                .matching(NSPredicate(format: "label CONTAINS %@", "访问其他App的数据"))
                .firstMatch
                .exists
            let hasEnglishAppDataPrompt = alert.staticTexts
                .matching(NSPredicate(format: "label CONTAINS[c] %@", "access data from other apps"))
                .firstMatch
                .exists
            guard hasChineseAppDataPrompt || hasEnglishAppDataPrompt else {
                return false
            }

            let allowButton = alert.buttons["允许"].exists
                ? alert.buttons["允许"]
                : alert.buttons["Allow"]
            guard allowButton.exists else {
                return false
            }
            allowButton.click()
            return true
        }
    }

    @MainActor
    private func clickElementByIdentifierCenter(_ element: XCUIElement) {
        if element.isHittable {
            element.click()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        }
    }

    private static func currentUserHomeDirectory() throws -> URL {
        guard let passwordEntry = getpwuid(getuid()),
              let homeDirectory = passwordEntry.pointee.pw_dir else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        return URL(fileURLWithPath: String(cString: homeDirectory), isDirectory: true)
    }

    private static func todayDiaryTitle() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: Date())
    }

    private static func removeSavedWindowState() throws {
        let home = try currentUserHomeDirectory()
        let savedStatePaths = [
            home.appendingPathComponent(
                "Library/Saved Application State/com.liangzhang.editor.mac.savedState",
                isDirectory: true
            ),
            home.appendingPathComponent(
                "Library/Containers/com.liangzhang.editor.mac/Data/Library/Saved Application State/com.liangzhang.editor.mac.savedState",
                isDirectory: true
            )
        ]

        for savedStatePath in savedStatePaths {
            try? FileManager.default.removeItem(at: savedStatePath)
        }
    }

    @MainActor
    private func waitForPageTitle(
        in app: XCUIApplication,
        equalTo expectedTitle: String,
        timeout: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let titleFields = app.textFields.matching(identifier: "editor.page-title")
        repeat {
            for index in 0..<titleFields.count {
                let titleField = titleFields.element(boundBy: index)
                if (titleField.value as? String) == expectedTitle {
                    return true
                }
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        } while Date() < deadline

        return false
    }

    @MainActor
    private static func terminateRunningEditorMacApplications() {
        let application = XCUIApplication(bundleIdentifier: editorMacBundleIdentifier)
        guard application.state != .notRunning && application.state != .unknown else {
            return
        }

        application.terminate()
        _ = waitForEditorMacTermination(application, until: Date().addingTimeInterval(3))
    }

    @discardableResult
    @MainActor
    private static func waitForEditorMacTermination(
        _ application: XCUIApplication,
        until deadline: Date
    ) -> Bool {
        while Date() < deadline {
            if application.state == .notRunning {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return false
    }

    @MainActor
    private func openWelcomePageForPageToolbarActions(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let allDocuments = app.buttons
            .matching(identifier: "editor.collection.all-documents")
            .firstMatch
        XCTAssertTrue(
            allDocuments.waitForExistence(timeout: 5),
            "All Documents should be visible before using page toolbar actions",
            file: file,
            line: line
        )
        allDocuments.click()

        let welcome = app.descendants(matching: .any)
            .matching(identifier: "editor.page-row.page-welcome")
            .firstMatch
        XCTAssertTrue(
            welcome.waitForExistence(timeout: 5),
            "Welcome page row should be visible before using page toolbar actions",
            file: file,
            line: line
        )
        welcome.click()

        let textView = app.textViews
            .matching(identifier: "editor.text.block-welcome-001")
            .firstMatch
        XCTAssertTrue(
            textView.waitForExistence(timeout: 5),
            "Welcome block should be loaded before using page toolbar actions",
            file: file,
            line: line
        )
    }

    @MainActor
    private func openInlineLinkPanelFromPageActions(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let pageActions = app.element(identifier: "editor.page-actions")
        XCTAssertTrue(
            pageActions.waitForExistence(timeout: 5),
            "Page actions menu should be visible before opening the inline link panel",
            file: file,
            line: line
        )
        pageActions.click()

        let linkItem = app.menuItems["链接"]
        XCTAssertTrue(
            linkItem.waitForExistence(timeout: 5),
            "Page actions menu should expose the link command",
            file: file,
            line: line
        )
        linkItem.click()
    }

    @MainActor
    private func clickPageActionMenuItem(
        _ title: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let pageActions = app.element(identifier: "editor.page-actions")
        XCTAssertTrue(
            pageActions.waitForExistence(timeout: 5),
            "Page actions menu should be visible before selecting \(title)",
            file: file,
            line: line
        )
        pageActions.click()

        let menuItem = app.menuItems[title]
        XCTAssertTrue(
            menuItem.waitForExistence(timeout: 5),
            "Page actions menu should expose \(title)",
            file: file,
            line: line
        )
        menuItem.click()
    }

    @MainActor
    func testLaunchStartsInDailyPageBlockEditorForFastTyping() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let legacyDiaryEditor = app.textViews["editor.diary.text"]
        XCTAssertFalse(
            legacyDiaryEditor.waitForExistence(timeout: 1),
            "Launch should no longer expose the legacy plain diary editor"
        )
        let pageTitle = app.textFields
            .matching(identifier: "editor.page-title")
            .firstMatch
        XCTAssertTrue(pageTitle.waitForExistence(timeout: 5), "Launch should expose the daily page editor")
        let dailyBlockEditor = app.textViews
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.text."))
            .firstMatch
        XCTAssertTrue(dailyBlockEditor.waitForExistence(timeout: 5), "Daily page should expose a normal block editor")
        dailyBlockEditor.click()
        app.typeText("Captured immediately")

        XCTAssertTrue(
            dailyBlockEditor.waitForValue(containing: "Captured immediately", timeout: 5),
            "Typing after launch should write into the daily page block"
        )
    }

    @MainActor
    func testAllDocumentsListShowsPagesSortedByUpdatedTime() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_FAVORITE_PAGE"] = "1"
        app.launch()

        let allDocuments = app.buttons["editor.collection.all-documents"]
        XCTAssertTrue(allDocuments.waitForExistence(timeout: 5), "All Documents should be visible in the rail")
        allDocuments.click()

        let welcome = app.staticTexts["editor.page-row.page-welcome"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 5), "Existing pages should appear in All Documents")
        XCTAssertFalse(
            app.staticTexts[Self.todayDiaryTitle()].waitForExistence(timeout: 1),
            "Daily diary pages should stay in Diary instead of appearing in All Documents"
        )
    }

    @MainActor
    func testCommandRightBracketPromotesSelectedDiaryTextToPage() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let diaryEditor = app.textViews
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.text."))
            .firstMatch
        XCTAssertTrue(diaryEditor.waitForExistence(timeout: 5), "Daily page block editor should be visible at launch")
        diaryEditor.click()
        app.typeText("Promote this text")
        diaryEditor.typeKey("a", modifierFlags: [.command])
        diaryEditor.typeKey("]", modifierFlags: [.command])

        let pageTitle = app.textFields
            .matching(identifier: "editor.page-title")
            .firstMatch
        XCTAssertTrue(
            pageTitle.waitForValue(equalTo: "Promote this text", timeout: 5),
            "Cmd+] should create and open a page from selected diary text"
        )

        let promotedBlock = app.textViews
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.text."))
            .firstMatch
        XCTAssertTrue(promotedBlock.waitForExistence(timeout: 5), "Converted page should open with a normal editable block")
    }

    @MainActor
    func testCraftDocumentNavigationShortcuts() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)
        XCTAssertTrue(waitForPageTitle(in: app, equalTo: "欢迎", timeout: 5))

        app.typeKey("n", modifierFlags: [.command])
        XCTAssertTrue(
            waitForPageTitle(in: app, equalTo: "未命名", timeout: 5),
            "⌘N should create a normal untitled document in the current workspace"
        )

        app.typeKey("[", modifierFlags: [.command])
        XCTAssertTrue(
            waitForPageTitle(in: app, equalTo: "欢迎", timeout: 5),
            "⌘[ should navigate back to the previous page"
        )

        app.typeKey("n", modifierFlags: [.command, .option])
        XCTAssertTrue(
            waitForPageTitle(in: app, equalTo: Self.todayDiaryTitle(), timeout: 5),
            "⌥⌘N should open today's daily page"
        )

        app.typeKey("[", modifierFlags: [.command])
        XCTAssertTrue(
            waitForPageTitle(in: app, equalTo: "欢迎", timeout: 5),
            "⌘[ should navigate back from today's daily page"
        )

        app.typeKey(.rightArrow, modifierFlags: [.command])
        XCTAssertTrue(
            waitForPageTitle(in: app, equalTo: Self.todayDiaryTitle(), timeout: 5),
            "⌘→ should navigate forward to the page we backed out of"
        )
    }

    @MainActor
    func testShortcutSettingsRecorderRejectsConflictsAndStoresRecordedShortcut() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        app.typeKey(",", modifierFlags: [.command])
        let recordButton = app.buttons["editor.shortcut.record.openToday"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5), "Settings should expose the today shortcut recorder")

        recordButton.click()
        app.typeKey("n", modifierFlags: [.command])

        let conflictStatus = app.descendants(matching: .any)["editor.shortcut.status.openToday"]
        XCTAssertTrue(
            conflictStatus.waitForLabelOrValue(containing: "新建文档", timeout: 5),
            "Recording ⌘N for Today should be rejected as a New Document conflict"
        )
        let shortcutValue = app.descendants(matching: .any)["editor.shortcut.value.openToday"]
        XCTAssertTrue(
            shortcutValue.waitForLabelOrValue(containing: "⌘⌥N", timeout: 5),
            "Conflict rejection should leave the Today shortcut unchanged"
        )

        recordButton.click()
        app.typeKey("t", modifierFlags: [.command, .option])
        XCTAssertTrue(
            shortcutValue.waitForLabelOrValue(containing: "⌘⌥T", timeout: 5),
            "Recording a non-conflicting shortcut should update the displayed Today shortcut"
        )

        app.buttons["editor.shortcut.reset.openToday"].click()
        XCTAssertTrue(
            shortcutValue.waitForLabelOrValue(containing: "⌘⌥N", timeout: 5),
            "Reset should restore the Today shortcut default after the recorder flow"
        )
    }

    @MainActor
    func testPageRowsExposeTagChipsInAllDocuments() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_TAGGED_PAGE"] = "1"
        app.launch()

        app.buttons["editor.collection.all-documents"].click()
        let pageRow = app.staticTexts["editor.page-row.page-welcome"]
        XCTAssertTrue(pageRow.waitForExistence(timeout: 5))
        XCTAssertTrue(pageRow.waitForLabelOrValue(containing: "Writing", timeout: 5))
    }

    @MainActor
    func testWelcomeBlockAcceptsTypedText() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible and addressable")

        textView.click()
        textView.typeText(" Editable")

        let value = textView.value as? String ?? ""
        XCTAssertTrue(value.contains("Editable"), "Typing into the welcome block should update the native text view value")
    }

    @MainActor
    func testHashPrefixedBodyTextDoesNotAutoCreatePageTag() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_TAGGED_PAGE"] = "1"
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        XCTAssertTrue(
            app.textFields["editor.page-tag.add-field"].waitForExistence(timeout: 5),
            "The explicit page tag field should remain the only add-tag entry point"
        )
        XCTAssertFalse(
            app.element(identifier: "editor.page-tag.add-existing").exists,
            "The old add-existing tag picker should not be exposed above the editor"
        )

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible")

        textView.click()
        textView.typeText(" #f")

        XCTAssertTrue(
            textView.waitForValue(containing: "#f", timeout: 5),
            "Typing #f in the note body should stay in the body instead of becoming a page tag"
        )
    }

    @MainActor
    func testTypingAfterClickingTextBeginningKeepsCaretLocation() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.text."))
            .firstMatch
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "An empty daily block should be visible before editing")
        textView.click()
        app.typeText("AlphaBeta")
        XCTAssertTrue(textView.waitForValue(equalTo: "AlphaBeta", timeout: 5))

        textView.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).click()
        app.typeText("X")

        XCTAssertTrue(textView.waitForValue(containing: "X", timeout: 5))
        let valueAfterLeadingClick = textView.value as? String ?? ""
        XCTAssertTrue(
            valueAfterLeadingClick != "AlphaBetaX",
            "Typing after a leading click should insert near the clicked caret location instead of jumping to the end; value=\(valueAfterLeadingClick)"
        )
    }

    @MainActor
    func testCommandASelectsCurrentBlockThenAllBlocks() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        let firstTextView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(firstTextView.waitForExistence(timeout: 5))
        firstTextView.click()
        firstTextView.typeKey(.return, modifierFlags: [])
        app.typeText("Second")

        let firstBlock = app.groups["editor.block.block-welcome-001"]
        XCTAssertTrue(firstBlock.waitForExistence(timeout: 5))
        let secondBlock = app.groups
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.block."))
            .element(boundBy: 1)
        XCTAssertTrue(secondBlock.waitForExistence(timeout: 5))

        firstTextView.click()
        firstTextView.typeKey("a", modifierFlags: [.command])
        XCTAssertTrue(firstBlock.waitForLabelOrValue(containing: "当前块已选中", timeout: 5))
        XCTAssertFalse(secondBlock.waitForLabelOrValue(containing: "当前块已选中", timeout: 1))

        firstTextView.typeKey("a", modifierFlags: [.command])
        XCTAssertTrue(firstBlock.waitForLabelOrValue(containing: "当前块已选中", timeout: 5))
        XCTAssertTrue(secondBlock.waitForLabelOrValue(containing: "当前块已选中", timeout: 5))

        firstTextView.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(firstBlock.waitForLabelOrValue(containing: "当前块未选中", timeout: 5))
        XCTAssertTrue(secondBlock.waitForLabelOrValue(containing: "当前块未选中", timeout: 5))
    }

    @MainActor
    func testCommandCWhileBlockSelectedCopiesBlockMarkdown() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)
        openWelcomeBlockContextMenu(in: app)
        app.menuItems["任务"].click()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5))
        textView.click()
        textView.typeKey("a", modifierFlags: [.command])

        NSPasteboard.general.clearContents()
        textView.typeKey("c", modifierFlags: [.command])

        XCTAssertEqual(
            NSPasteboard.general.string(forType: .string),
            "- [ ] 开始用块写作。",
            "Cmd+C with a selected task block should copy block Markdown, not just the text view contents"
        )
    }

    @MainActor
    func testClickingBlockRowFocusesEditorForTyping() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

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

        openWelcomePageForPageToolbarActions(in: app)

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
    func testReturnSplitsTextBlockAtCaretAndFocusesInsertedRemainder() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before splitting")
        let initialTextViewCount = app.textViews.count

        textView.click()
        textView.typeKey("a", modifierFlags: [.command])
        app.typeText("AlphaBeta")
        XCTAssertTrue(
            textView.waitForValue(equalTo: "AlphaBeta", timeout: 5),
            "Test setup should replace the welcome text before moving the caret"
        )

        for _ in 0..<4 {
            textView.typeKey(.leftArrow, modifierFlags: [])
        }
        textView.typeKey(.return, modifierFlags: [])

        let insertedTextView = app.textViews.element(boundBy: initialTextViewCount)
        XCTAssertTrue(insertedTextView.waitForExistence(timeout: 5), "Return should insert a text block for the trailing text")
        XCTAssertTrue(
            textView.waitForValue(equalTo: "Alpha", timeout: 5),
            "The original block should keep text before the caret"
        )
        XCTAssertTrue(
            insertedTextView.waitForValue(equalTo: "Beta", timeout: 5),
            "The inserted block should receive text after the caret"
        )
        XCTAssertTrue(
            insertedTextView.waitForKeyboardFocus(timeout: 5),
            "The inserted remainder block should receive keyboard focus"
        )

        app.typeText("New ")
        XCTAssertTrue(
            insertedTextView.waitForValue(equalTo: "New Beta", timeout: 5),
            "Typing after split should continue at the start of the inserted remainder"
        )
    }

    @MainActor
    func testBackspaceAtStartMergesTextBlockWithPreviousBlock() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before merging")
        let initialTextViewCount = app.textViews.count

        textView.click()
        textView.typeKey("a", modifierFlags: [.command])
        app.typeText("AlphaBeta")
        XCTAssertTrue(
            textView.waitForValue(equalTo: "AlphaBeta", timeout: 5),
            "Test setup should replace the welcome text before splitting"
        )

        for _ in 0..<4 {
            textView.typeKey(.leftArrow, modifierFlags: [])
        }
        textView.typeKey(.return, modifierFlags: [])

        let insertedTextView = app.textViews.element(boundBy: initialTextViewCount)
        XCTAssertTrue(insertedTextView.waitForExistence(timeout: 5), "Return should create the second block to merge")
        XCTAssertTrue(
            insertedTextView.waitForValue(equalTo: "Beta", timeout: 5),
            "The second block should contain the trailing text before Backspace"
        )
        XCTAssertTrue(
            insertedTextView.waitForKeyboardFocus(timeout: 5),
            "The second block should be focused at its start before Backspace"
        )

        insertedTextView.typeKey(.delete, modifierFlags: [])

        XCTAssertTrue(
            app.waitForTextViewCount(initialTextViewCount, timeout: 5),
            "Backspace at the start of the second block should remove that block"
        )
        XCTAssertTrue(
            textView.waitForValue(equalTo: "AlphaBeta", timeout: 5),
            "Backspace at block start should merge the second block text into the first block"
        )
        XCTAssertTrue(
            textView.waitForKeyboardFocus(timeout: 5),
            "The merged first block should regain keyboard focus"
        )
        app.typeText(" Joined")
        XCTAssertTrue(
            textView.waitForValue(equalTo: "Alpha JoinedBeta", timeout: 5),
            "Typing after merge should continue at the original join point"
        )
    }

    @MainActor
    func testForwardDeleteAtEndMergesTextBlockWithNextBlock() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before merging")
        let initialTextViewCount = app.textViews.count

        textView.click()
        textView.typeKey("a", modifierFlags: [.command])
        app.typeText("AlphaBeta")
        XCTAssertTrue(
            textView.waitForValue(equalTo: "AlphaBeta", timeout: 5),
            "Test setup should replace the welcome text before splitting"
        )

        for _ in 0..<4 {
            textView.typeKey(.leftArrow, modifierFlags: [])
        }
        textView.typeKey(.return, modifierFlags: [])

        let insertedTextView = app.textViews.element(boundBy: initialTextViewCount)
        XCTAssertTrue(insertedTextView.waitForExistence(timeout: 5), "Return should create the second block to merge")
        XCTAssertTrue(
            textView.waitForValue(equalTo: "Alpha", timeout: 5),
            "The first block should contain the leading text before Forward Delete"
        )
        XCTAssertTrue(
            insertedTextView.waitForValue(equalTo: "Beta", timeout: 5),
            "The second block should contain the trailing text before Forward Delete"
        )

        textView.click()
        textView.typeKey(.rightArrow, modifierFlags: [.command])
        textView.typeKey(.forwardDelete, modifierFlags: [])

        XCTAssertTrue(
            app.waitForTextViewCount(initialTextViewCount, timeout: 5),
            "Forward Delete at the end of the first block should remove the next block"
        )
        XCTAssertTrue(
            textView.waitForValue(equalTo: "AlphaBeta", timeout: 5),
            "Forward Delete at block end should merge the next block text into the current block"
        )
        XCTAssertTrue(
            textView.waitForKeyboardFocus(timeout: 5),
            "The merged first block should retain keyboard focus"
        )
        app.typeText(" Joined")
        XCTAssertTrue(
            textView.waitForValue(equalTo: "Alpha JoinedBeta", timeout: 5),
            "Typing after merge should continue at the original join point"
        )
    }

    @MainActor
    func testBoundaryArrowKeysMoveFocusBetweenTextBlocks() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        let firstTextView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(firstTextView.waitForExistence(timeout: 5), "Welcome text block should be visible")
        let initialTextViewCount = app.textViews.count

        firstTextView.click()
        firstTextView.typeKey(.return, modifierFlags: [])

        let secondTextView = app.textViews.element(boundBy: initialTextViewCount)
        XCTAssertTrue(secondTextView.waitForExistence(timeout: 5), "Return should create a second editable block")
        app.typeText("Second block")
        XCTAssertTrue(
            secondTextView.waitForKeyboardFocus(timeout: 5),
            "The inserted second block should keep keyboard focus before boundary arrow navigation"
        )

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

        openWelcomePageForPageToolbarActions(in: app)

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before adding")
        let initialTextViewCount = app.textViews.count

        clickPageActionMenuItem("新增文本块", in: app)

        let insertedTextView = app.textViews.element(boundBy: initialTextViewCount)
        XCTAssertTrue(insertedTextView.waitForExistence(timeout: 5), "Add should insert a new editable text block")
        XCTAssertTrue(
            insertedTextView.waitForKeyboardFocus(timeout: 5),
            "Add should focus the inserted block before typing continues"
        )

        insertedTextView.typeText("abc")

        let typedValuePredicate = NSPredicate { element, _ in
            guard let element = element as? XCUIElement,
                  let value = element.value as? String else {
                return false
            }
            return value.localizedCaseInsensitiveContains("abc")
        }
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(predicate: typedValuePredicate, object: insertedTextView)],
                timeout: 5
            ),
            .completed,
            "Typing after Add should continue in the inserted block; value=\(insertedTextView.value as? String ?? "")"
        )
    }

    @MainActor
    func testBlockContextMenuShowsChineseCoreActions() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before opening block actions")
        textView.click()

        openWelcomeBlockContextMenu(in: app)

        XCTAssertTrue(app.menuItems["下方新增"].waitForExistence(timeout: 5), "Block menu should include add-below")
        XCTAssertTrue(app.menuItems["一级标题"].waitForExistence(timeout: 5), "Block menu should include type conversion")
        XCTAssertTrue(app.menuItems["删除"].waitForExistence(timeout: 5), "Block menu should include delete without showing it as permanent chrome")
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testBlockContextMenuConvertsTextBlockToPage() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before conversion")
        textView.click()

        openWelcomeBlockContextMenu(in: app)

        let pageMenuItem = app.menuItems["页面"]
        XCTAssertTrue(pageMenuItem.waitForExistence(timeout: 5), "Conversion menu should expose text-block-to-page")
        pageMenuItem.click()

        let pageTitle = app.textFields["editor.page-title"]
        XCTAssertTrue(
            pageTitle.waitForValue(containing: "开始用块写作。", timeout: 5),
            "Converting a text block to a page should open the created page with the block text as title"
        )
        XCTAssertTrue(
            app.staticTexts["开始用块写作。"].waitForExistence(timeout: 5)
                || app.buttons["开始用块写作。"].waitForExistence(timeout: 5),
            "The created page should appear in the page list"
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
    func testMacPageListHidesSelectionCircleAndFavoriteControls() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_FAVORITE_PAGE"] = "1"
        app.launch()

        let favoritePageButton = app.element(identifier: "editor.favorite-page.page-welcome")
        let favoritesCollection = app.element(identifier: "editor.collection.favorites")
        let selectionToggle = app.element(identifier: "editor.page-row.page-welcome.selection-toggle")
        let favoriteToggle = app.buttons["editor.page.page-welcome.favorite"]
        let pageRow = app.element(identifier: "editor.page-row.page-welcome")

        XCTAssertTrue(pageRow.waitForExistence(timeout: 5), "Page list row should be visible before checking removed controls")
        XCTAssertFalse(selectionToggle.exists, "The macOS middle-column page row should not expose the unexplained selection circle")
        XCTAssertFalse(favoriteToggle.exists, "The macOS middle-column page row should not expose a favorite toggle")
        XCTAssertFalse(favoritesCollection.exists, "The macOS sidebar should not expose the Favorites collection")
        XCTAssertFalse(favoritePageButton.exists, "The macOS sidebar should not expose individual favorite shortcuts")
    }

    @MainActor
    func testMacPageListCommandASelectsVisibleMiddleColumnRows() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let allDocuments = app.buttons["editor.collection.all-documents"]
        XCTAssertTrue(allDocuments.waitForExistence(timeout: 5), "All Documents should be visible before selecting middle-column rows")
        allDocuments.click()

        let pageRow = app.element(identifier: "editor.page-row.page-welcome")
        XCTAssertTrue(pageRow.waitForExistence(timeout: 5), "Welcome page row should be visible before Cmd+A")
        XCTAssertTrue(
            pageRow.waitForValue(containing: "未加入批量选择", timeout: 5),
            "Page row should start outside the page-list batch selection"
        )

        app.typeKey("a", modifierFlags: [.command])

        XCTAssertTrue(
            pageRow.waitForValue(containing: "已加入批量选择", timeout: 5),
            "Cmd+A in the middle column should select visible page rows in the current collection scope"
        )
    }

    @MainActor
    func testItalicToolbarInsertsPlaceholderAndKeepsTypingInEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

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

        openWelcomePageForPageToolbarActions(in: app)

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
            textView.waitForValue(containing: "**开始用块写作。**", timeout: 5),
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
            textView.waitForValue(containing: "**开始用块写作。**", timeout: 5),
            "First Cmd-B should wrap the selected block text in Markdown bold markers"
        )

        textView.typeKey("b", modifierFlags: [.command])
        XCTAssertTrue(
            textView.waitForValue(containing: "开始用块写作。", timeout: 5),
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

        openWelcomePageForPageToolbarActions(in: app)

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
            textView.waitForValue(containing: "`开始用块写作。`", timeout: 5),
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

        openWelcomePageForPageToolbarActions(in: app)

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
            textView.waitForValue(containing: "~~开始用块写作。~~", timeout: 5),
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

        openWelcomePageForPageToolbarActions(in: app)

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
    func testPageActionsMenuOpensInlineLinkPanelForSelection() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 10), "Welcome text block should be visible before page action link insertion")

        textView.click()
        XCTAssertTrue(textView.waitForKeyboardFocus(timeout: 5), "Welcome text block should be focused before opening the page actions link panel")
        textView.typeKey("a", modifierFlags: [.command])
        openInlineLinkPanelFromPageActions(in: app)

        let labelField = app.textFields["editor.insert-markdown-link.label"]
        XCTAssertTrue(labelField.waitForExistence(timeout: 5), "The page actions menu should open the inline link panel")
        labelField.click()
        labelField.typeText("Swift")

        let urlField = app.textFields["editor.insert-markdown-link.url"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 5), "Inline link panel should expose a URL field after opening from page actions")
        urlField.click()
        urlField.typeText("https://swift.org")

        let confirmButton = app.buttons["editor.insert-markdown-link.confirm"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "Inline link panel should expose a confirm button after opening from page actions")
        confirmButton.click()

        XCTAssertTrue(
            textView.waitForValue(containing: "[Swift](https://swift.org)", timeout: 5),
            "Confirming the page action link panel should replace the selected text with inline Markdown"
        )
    }

    @MainActor
    func testPageActionsMenuUpdatesExistingInlineLinkUnderSelection() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 10), "Welcome text block should be visible before link update")

        textView.click()
        XCTAssertTrue(textView.waitForKeyboardFocus(timeout: 5), "Welcome text block should be focused before creating the initial link")
        textView.typeKey("a", modifierFlags: [.command])
        openInlineLinkPanelFromPageActions(in: app)

        let labelField = app.textFields["editor.insert-markdown-link.label"]
        XCTAssertTrue(labelField.waitForExistence(timeout: 5), "Page actions should expose a label field")
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

        openInlineLinkPanelFromPageActions(in: app)

        XCTAssertTrue(
            labelField.waitForValue(containing: "Swift", timeout: 5),
            "Opening link editing from page actions inside an existing inline link should prefill the current label"
        )
        XCTAssertTrue(
            urlField.waitForValue(containing: "https://swift.org", timeout: 5),
            "Opening link editing from page actions inside an existing inline link should prefill the current URL"
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
    func testPageActionsMenuRemovesExistingInlineLinkUnderSelection() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 10), "Welcome text block should be visible before link removal")

        textView.click()
        XCTAssertTrue(textView.waitForKeyboardFocus(timeout: 5), "Welcome text block should be focused before creating the initial link")
        textView.typeKey("a", modifierFlags: [.command])
        openInlineLinkPanelFromPageActions(in: app)

        let labelField = app.textFields["editor.insert-markdown-link.label"]
        XCTAssertTrue(labelField.waitForExistence(timeout: 5), "Page actions should expose a label field")
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

        openInlineLinkPanelFromPageActions(in: app)

        let removeButton = app.buttons["editor.insert-markdown-link.remove"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 5), "Editing an existing inline link should expose Remove Link")
        removeButton.click()

        let didRemoveExistingLink = textView.waitForValue(equalTo: "Swift", timeout: 5)
        let value = textView.value as? String ?? ""
        XCTAssertTrue(
            didRemoveExistingLink,
            "Removing from the prefilled link panel should preserve only the label text; value=\(value)"
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

        openWelcomePageForPageToolbarActions(in: app)
        openWelcomeBlockContextMenu(in: app)

        let taskMenuItem = app.menuItems["任务"]
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
    func testTaskBlockTypeRendersTaskChromeAndKeepsTextEditable() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)
        openWelcomeBlockContextMenu(in: app)

        let taskMenuItem = app.menuItems["任务"]
        XCTAssertTrue(taskMenuItem.waitForExistence(timeout: 5), "Block type menu should expose the Task type")
        taskMenuItem.click()

        let taskBlock = app.element(identifier: "editor.task.block-welcome-001")
        XCTAssertTrue(taskBlock.waitForExistence(timeout: 5), "Changing a text block to Task should render visible task chrome")
        XCTAssertTrue(
            taskBlock.waitForLabelOrValue(containing: "Task block", timeout: 5),
            "Task chrome should expose a semantic container label"
        )
        XCTAssertTrue(
            taskBlock.waitForLabelOrValue(containing: "Incomplete", timeout: 5),
            "Task chrome should expose the initial completion state"
        )

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Task blocks should keep the native text editor")
        textView.click()
        XCTAssertTrue(textView.waitForKeyboardFocus(timeout: 5), "Task text should be directly editable")
        app.typeText(" Done")
        XCTAssertTrue(
            textView.waitForValue(containing: "Done", timeout: 5),
            "Typing in a task should still update the native text view"
        )

        let taskToggle = app.buttons["editor.block.block-welcome-001.task-toggle"]
        taskToggle.click()
        XCTAssertTrue(
            taskBlock.waitForLabelOrValue(containing: "Completed", timeout: 5),
            "Completing the task should update the block chrome state"
        )
    }

    @MainActor
    func testToggleBlockButtonExposesAndUpdatesExpansionState() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)
        openWelcomeBlockContextMenu(in: app)

        let toggleMenuItem = app.menuItems["折叠"]
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
    func testToggleBlockTypeRendersToggleChromeAndKeepsTextEditable() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)
        openWelcomeBlockContextMenu(in: app)

        let toggleMenuItem = app.menuItems["折叠"]
        XCTAssertTrue(toggleMenuItem.waitForExistence(timeout: 5), "Block type menu should expose the Toggle type")
        toggleMenuItem.click()

        let toggleBlock = app.element(identifier: "editor.toggle.block-welcome-001")
        XCTAssertTrue(toggleBlock.waitForExistence(timeout: 5), "Changing a text block to Toggle should render visible toggle chrome")
        XCTAssertTrue(
            toggleBlock.waitForLabelOrValue(containing: "Toggle block", timeout: 5),
            "Toggle chrome should expose a semantic container label"
        )
        XCTAssertTrue(
            toggleBlock.waitForLabelOrValue(containing: "Expanded", timeout: 5),
            "Toggle chrome should expose the initial expansion state"
        )

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Toggle blocks should keep the native text editor")
        textView.click()
        XCTAssertTrue(textView.waitForKeyboardFocus(timeout: 5), "Toggle text should be directly editable")
        app.typeText(" Details")
        XCTAssertTrue(
            textView.waitForValue(containing: "Details", timeout: 5),
            "Typing in a toggle should still update the native text view"
        )

        let toggleButton = app.buttons["editor.block.block-welcome-001.toggle-expansion"]
        toggleButton.click()
        XCTAssertTrue(
            toggleBlock.waitForLabelOrValue(containing: "Collapsed", timeout: 5),
            "Collapsing the toggle should update the block chrome state"
        )
    }

    @MainActor
    func testCodeBlockWrapButtonExposesAndUpdatesLineWrapState() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)
        openWelcomeBlockContextMenu(in: app)

        let codeMenuItem = app.menuItems["代码"]
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
    func testCodeBlockTypeRendersCodeChromeAndKeepsTextEditable() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)
        openWelcomeBlockContextMenu(in: app)

        let codeMenuItem = app.menuItems["代码"]
        XCTAssertTrue(codeMenuItem.waitForExistence(timeout: 5), "Block type menu should expose the Code type")
        codeMenuItem.click()

        let codeBlock = app.element(identifier: "editor.code.block-welcome-001")
        XCTAssertTrue(codeBlock.waitForExistence(timeout: 5), "Changing a text block to Code should render visible code chrome")
        XCTAssertTrue(
            codeBlock.waitForLabelOrValue(containing: "Code block", timeout: 5),
            "Code chrome should expose a semantic container label"
        )
        XCTAssertTrue(
            codeBlock.waitForLabelOrValue(containing: "Line wrap enabled", timeout: 5),
            "Code chrome should expose the current line-wrap state"
        )

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Code blocks should keep the native text editor")
        textView.click()
        XCTAssertTrue(textView.waitForKeyboardFocus(timeout: 5), "Code text should be directly editable")
        app.typeText(" let value = 1")
        XCTAssertTrue(
            textView.waitForValue(containing: "let value = 1", timeout: 5),
            "Typing in a code block should still update the native text view"
        )
    }

    @MainActor
    func testCodeBlockReturnInsertsNewlineAndCommandAStaysInText() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)
        openWelcomeBlockContextMenu(in: app)

        let codeMenuItem = app.menuItems["代码"]
        XCTAssertTrue(codeMenuItem.waitForExistence(timeout: 5), "Block type menu should expose the Code type")
        codeMenuItem.click()

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Code blocks should keep the native text editor")
        textView.click()
        XCTAssertTrue(textView.waitForKeyboardFocus(timeout: 5), "Code text should receive keyboard focus")

        textView.typeKey("a", modifierFlags: [.command])
        app.typeText("let a = 1")
        XCTAssertTrue(textView.waitForValue(equalTo: "let a = 1", timeout: 5))

        let textViewCountBeforeReturn = app.textViews.count
        textView.typeKey(.return, modifierFlags: [])
        app.typeText("let b = 2")

        XCTAssertEqual(
            app.textViews.count,
            textViewCountBeforeReturn,
            "Return inside a code block should insert a newline instead of creating another block"
        )
        XCTAssertTrue(
            textView.waitForValue(equalTo: "let a = 1\nlet b = 2", timeout: 5),
            "Return inside a code block should keep editing the same multiline text view"
        )

        let blockRow = app.groups["editor.block.block-welcome-001"]
        textView.typeKey("a", modifierFlags: [.command])
        XCTAssertFalse(
            blockRow.waitForLabelOrValue(containing: "当前块已选中", timeout: 1),
            "Cmd+A in a code block should select text only, not enter block selection"
        )
        app.typeText("let c = 3")
        XCTAssertTrue(
            textView.waitForValue(equalTo: "let c = 3", timeout: 5),
            "Typing after Cmd+A in a code block should replace the code text"
        )
    }

    @MainActor
    func testBlockActionControlsExposeSemanticLabelsAndAvailability() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)
        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5))
        textView.click()
        let dragHandle = app.element(identifier: "editor.block.block-welcome-001.drag-handle")

        XCTAssertTrue(dragHandle.waitForExistence(timeout: 5), "Welcome block should expose a drag handle")
        XCTAssertEqual(dragHandle.label, "块拖拽手柄")
        XCTAssertTrue(
            dragHandle.waitForValue(containing: "正文", timeout: 5),
            "Drag handle should expose the current block type"
        )

        XCTAssertFalse(
            app.element(identifier: "editor.block.block-welcome-001.type-menu").exists,
            "Block rows should not show a second permanent type/menu button next to the drag handle"
        )
        openWelcomeBlockContextMenu(in: app)
        XCTAssertTrue(app.menuItems["删除"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.menuItems["一级标题"].waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testBlockTypeMenuCanConvertTextBlockToDivider() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)
        openWelcomeBlockContextMenu(in: app)

        let dividerMenuItem = app.menuItems["分割线"]
        XCTAssertTrue(dividerMenuItem.waitForExistence(timeout: 5), "Block type menu should expose the Divider type")
        dividerMenuItem.click()

        let divider = app.element(identifier: "editor.divider.block-welcome-001")
        XCTAssertTrue(divider.waitForExistence(timeout: 5), "Changing a text block to Divider should render a divider row")

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForNonExistence(timeout: 5), "Divider blocks should not leave an editable text view behind")

    }

    @MainActor
    func testCalloutBlockTypeRendersCalloutChromeAndKeepsTextEditable() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)
        openWelcomeBlockContextMenu(in: app)

        let calloutMenuItem = app.menuItems["提示"]
        XCTAssertTrue(calloutMenuItem.waitForExistence(timeout: 5), "Block type menu should expose the Callout type")
        calloutMenuItem.click()

        let callout = app.element(identifier: "editor.callout.block-welcome-001")
        XCTAssertTrue(callout.waitForExistence(timeout: 5), "Changing a text block to Callout should render visible callout chrome")
        XCTAssertTrue(
            callout.waitForLabelOrValue(containing: "Callout block", timeout: 5),
            "Callout chrome should expose a semantic container label"
        )

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Callout blocks should keep the native text editor")
        textView.click()
        XCTAssertTrue(textView.waitForKeyboardFocus(timeout: 5), "Callout text should be directly editable")
        app.typeText(" Note")
        XCTAssertTrue(
            textView.waitForValue(containing: "Note", timeout: 5),
            "Typing in a callout should still update the native text view"
        )
    }

    @MainActor
    func testTableControlsExposeSemanticLabelsAndDimensions() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)
        openWelcomeBlockContextMenu(in: app)

        let tableMenuItem = app.menuItems["表格"]
        XCTAssertTrue(tableMenuItem.waitForExistence(timeout: 5), "Block type menu should expose the Table type")
        tableMenuItem.click()

        let addRowButton = app.element(identifier: "editor.table.block-welcome-001.add-row")
        let addColumnButton = app.element(identifier: "editor.table.block-welcome-001.add-column")
        let removeRowButton = app.element(identifier: "editor.table.block-welcome-001.remove-row")
        let removeColumnButton = app.element(identifier: "editor.table.block-welcome-001.remove-column")
        let secondRowSelector = app.element(identifier: "editor.table.block-welcome-001.row-selector.1")
        let secondColumnSelector = app.element(identifier: "editor.table.block-welcome-001.column-selector.1")

        XCTAssertTrue(addRowButton.waitForExistence(timeout: 5), "Changing a block to Table should expose row controls")
        XCTAssertEqual(addRowButton.label, "新增表格行")
        XCTAssertEqual(addColumnButton.label, "新增表格列")
        XCTAssertFalse(removeRowButton.exists, "Table rows should not show permanent remove-row chrome")
        XCTAssertFalse(removeColumnButton.exists, "Table columns should not show permanent remove-column chrome")
        XCTAssertTrue(
            addRowButton.waitForValue(containing: "2 行，2 列", timeout: 5),
            "Table controls should expose the initial table dimensions"
        )

        clickElementByIdentifierCenter(addRowButton)
        XCTAssertTrue(
            addRowButton.waitForValue(containing: "3 行，2 列", timeout: 5),
            "Adding a row should update the exposed table dimensions"
        )

        clickElementByIdentifierCenter(addColumnButton)
        XCTAssertTrue(
            addColumnButton.waitForValue(containing: "3 行，3 列", timeout: 5),
            "Adding a column should update the exposed table dimensions"
        )

        XCTAssertTrue(secondRowSelector.waitForExistence(timeout: 5), "Added row should expose a quiet row selector")
        secondRowSelector.click()
        XCTAssertTrue(
            secondRowSelector.waitForValue(containing: "已选择", timeout: 5),
            "Clicking a row selector should select that row before Delete"
        )
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(
            addRowButton.waitForValue(containing: "2 行，3 列", timeout: 5),
            "Deleting a selected row should update the exposed table dimensions"
        )

        XCTAssertTrue(secondColumnSelector.waitForExistence(timeout: 5), "Added column should expose a quiet column selector")
        secondColumnSelector.click()
        XCTAssertTrue(
            secondColumnSelector.waitForValue(containing: "已选择", timeout: 5),
            "Clicking a column selector should select that column before Delete"
        )
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(
            addColumnButton.waitForValue(containing: "2 行，2 列", timeout: 5),
            "Deleting a selected column should update the exposed table dimensions"
        )
    }

    @MainActor
    func testTableBlockTypeRendersTableChromeAndKeepsCellsEditable() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)
        openWelcomeBlockContextMenu(in: app)

        let tableMenuItem = app.menuItems["表格"]
        XCTAssertTrue(tableMenuItem.waitForExistence(timeout: 5), "Block type menu should expose the Table type")
        tableMenuItem.click()

        let tableBlock = app.element(identifier: "editor.table.block-welcome-001")
        XCTAssertTrue(tableBlock.waitForExistence(timeout: 5), "Changing a text block to Table should render visible table chrome")
        XCTAssertTrue(
            tableBlock.waitForLabelOrValue(containing: "表格块", timeout: 5),
            "Table chrome should expose a semantic container label"
        )
        XCTAssertTrue(
            tableBlock.waitForLabelOrValue(containing: "2 行，2 列", timeout: 5),
            "Table chrome should expose its current dimensions"
        )

        let firstCell = app.textFields["editor.table.block-welcome-001.cell.0.0"]
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "Table blocks should expose editable cells")
        firstCell.click()
        app.typeText(" Cell")
        XCTAssertTrue(
            firstCell.waitForValue(containing: "Cell", timeout: 5),
            "Typing in a table cell should update the cell text"
        )

        let addColumnButton = app.element(identifier: "editor.table.block-welcome-001.add-column")
        addColumnButton.click()
        XCTAssertTrue(
            tableBlock.waitForLabelOrValue(containing: "2 行，3 列", timeout: 5),
            "Table chrome should update dimensions after adding a column"
        )
    }

    @MainActor
    func testSlashCommandMenuKeyboardCanReachTableCommand() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome text block should be visible before opening slash menu")
        textView.click()
        textView.typeKey("a", modifierFlags: [.command])
        app.typeText("/")

        let slashMenu = app.element(identifier: "editor.slash-command-menu")
        XCTAssertTrue(slashMenu.waitForExistence(timeout: 5), "Typing / should show the scrollable slash command menu")
        XCTAssertTrue(
            app.element(identifier: "editor.slash-command.table").waitForExistence(timeout: 5),
            "Scrollable slash menu should contain the table command"
        )

        for _ in 0..<10 {
            textView.typeKey(.downArrow, modifierFlags: [])
        }
        textView.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(
            app.element(identifier: "editor.table.block-welcome-001").waitForExistence(timeout: 5),
            "Down-arrow navigation plus Return should convert the block to an embedded table"
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
    func testReferenceRowsExposeSemanticChrome() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_REFERENCE_TARGETS"] = "1"
        app.launch()

        app.element(identifier: "editor.insert-page-reference").click()
        let targetPageItem = app.menuItems["Reference Target"]
        XCTAssertTrue(targetPageItem.waitForExistence(timeout: 5), "Page reference menu should include the seeded target page")
        targetPageItem.click()

        let insertedPageReference = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.page-reference."))
            .firstMatch
        XCTAssertTrue(insertedPageReference.waitForExistence(timeout: 5), "Inserted page reference should expose a button row")
        XCTAssertTrue(
            insertedPageReference.waitForLabelOrValue(containing: "Page reference", timeout: 5),
            "Page reference rows should identify the reference type"
        )
        XCTAssertTrue(
            insertedPageReference.waitForLabelOrValue(containing: "Open page", timeout: 5),
            "Page reference rows should expose the open-page action"
        )

        app.element(identifier: "editor.insert-block-reference").click()
        let targetBlockItem = app.menuItems["Reference Target: Reference target block"]
        XCTAssertTrue(targetBlockItem.waitForExistence(timeout: 5), "Block reference menu should include the seeded target block")
        targetBlockItem.click()

        let insertedBlockReference = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.block-reference."))
            .firstMatch
        XCTAssertTrue(insertedBlockReference.waitForExistence(timeout: 5), "Inserted block reference should expose a button row")
        XCTAssertTrue(
            insertedBlockReference.waitForLabelOrValue(containing: "Block reference", timeout: 5),
            "Block reference rows should identify the reference type"
        )
        XCTAssertTrue(
            insertedBlockReference.waitForLabelOrValue(containing: "Open referenced block", timeout: 5),
            "Block reference rows should expose the open-block action"
        )
    }

    @MainActor
    func testPageReferenceRowClickNavigatesToTargetPageAndMarksSelection() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_REFERENCE_TARGETS"] = "1"
        app.launch()

        app.element(identifier: "editor.insert-page-reference").click()
        let targetPageItem = app.menuItems["Reference Target"]
        XCTAssertTrue(targetPageItem.waitForExistence(timeout: 5), "Page reference menu should include the seeded target page")
        targetPageItem.click()

        let insertedPageReference = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.page-reference."))
            .firstMatch
        XCTAssertTrue(insertedPageReference.waitForExistence(timeout: 5), "Inserted page reference should expose a clickable row")
        insertedPageReference.click()

        let pageTitle = app.textFields["editor.page-title"]
        XCTAssertTrue(
            pageTitle.waitForValue(equalTo: "Reference Target", timeout: 5),
            "Clicking a page reference should navigate the editor to the target page"
        )

        let targetPageRow = app.staticTexts
            .matching(NSPredicate(format: "label == %@", "Reference Target"))
            .firstMatch
        XCTAssertTrue(
            targetPageRow.waitForLabelOrValue(containing: "Selected", timeout: 5),
            "Navigating through a page reference should expose the selected page row state"
        )

        let targetBlockText = app.textViews
            .matching(NSPredicate(format: "value CONTAINS %@", "Reference target block"))
            .firstMatch
        XCTAssertTrue(
            targetBlockText.waitForExistence(timeout: 5),
            "The target page should show its seeded reference target block"
        )
    }

    @MainActor
    func testBlockReferenceRowClickNavigatesAndFocusesTargetBlock() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_REFERENCE_TARGETS"] = "1"
        app.launch()

        app.element(identifier: "editor.insert-block-reference").click()
        let targetBlockItem = app.menuItems["Reference Target: Reference target block"]
        XCTAssertTrue(targetBlockItem.waitForExistence(timeout: 5), "Block reference menu should include the seeded target block")
        targetBlockItem.click()

        let insertedBlockReference = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.block-reference."))
            .firstMatch
        XCTAssertTrue(insertedBlockReference.waitForExistence(timeout: 5), "Inserted block reference should expose a clickable row")
        insertedBlockReference.click()

        let pageTitle = app.textFields["editor.page-title"]
        XCTAssertTrue(
            pageTitle.waitForValue(equalTo: "Reference Target", timeout: 5),
            "Clicking a block reference should navigate the editor to the target page"
        )

        let targetBlockText = app.textViews
            .matching(NSPredicate(format: "value CONTAINS %@", "Reference target block"))
            .firstMatch
        XCTAssertTrue(
            targetBlockText.waitForExistence(timeout: 5),
            "The target page should show the referenced block"
        )
        XCTAssertTrue(
            targetBlockText.waitForKeyboardFocus(timeout: 5),
            "Clicking a block reference should focus the referenced block"
        )
    }

    @MainActor
    func testMarkdownImportToolbarImportsFixtureFile() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_MARKDOWN_IMPORT_TEXT"] = "# Imported Heading\n\nImported paragraph from toolbar"
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        clickPageActionMenuItem("导入 Markdown", in: app)

        let importedParagraph = app.textViews
            .matching(NSPredicate(format: "value CONTAINS %@", "Imported paragraph from toolbar"))
            .firstMatch
        XCTAssertTrue(
            importedParagraph.waitForExistence(timeout: 5),
            "Clicking the Markdown import toolbar button should import the fixture file into the editor; textViews=\(textViewValues(in: app))"
        )
    }

    @MainActor
    func testMarkdownImportToolbarRendersAndExportsMultilineQuoteAndCalloutBlocks() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_MARKDOWN_IMPORT_TEXT"] = """
        > First quote line
        > second quote line

        > [!NOTE] First callout line
        > second callout line

        Body after blocks
        """
        app.launchEnvironment["EDITOR_UI_TEST_MARKDOWN_EXPORT_CAPTURE"] = "1"
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        clickPageActionMenuItem("导入 Markdown", in: app)

        let quote = app.element(identifierPrefix: "editor.quote.")
        XCTAssertTrue(
            quote.waitForExistence(timeout: 5),
            "Markdown import should render a semantic quote block; textViews=\(textViewValues(in: app))"
        )
        XCTAssertTrue(
            quote.waitForLabelOrValue(containing: "Quote block", timeout: 5),
            "Imported quote block should expose semantic quote chrome"
        )

        let quoteText = app.textViews
            .matching(NSPredicate(format: "value CONTAINS %@", "First quote line"))
            .firstMatch
        XCTAssertTrue(
            quoteText.waitForExistence(timeout: 5),
            "Imported quote block should keep its first line in the native text view; textViews=\(textViewValues(in: app))"
        )
        XCTAssertTrue(
            quoteText.waitForValue(containing: "second quote line", timeout: 5),
            "Imported quote block should preserve its continuation line"
        )

        let callout = app.element(identifierPrefix: "editor.callout.")
        XCTAssertTrue(callout.waitForExistence(timeout: 5), "Markdown import should render a semantic callout block")
        XCTAssertTrue(
            callout.waitForLabelOrValue(containing: "Callout block", timeout: 5),
            "Imported callout block should expose semantic callout chrome"
        )

        let calloutText = app.textViews
            .matching(NSPredicate(format: "value CONTAINS %@", "First callout line"))
            .firstMatch
        XCTAssertTrue(
            calloutText.waitForExistence(timeout: 5),
            "Imported callout block should keep its first line in the native text view; textViews=\(textViewValues(in: app))"
        )
        XCTAssertTrue(
            calloutText.waitForValue(containing: "second callout line", timeout: 5),
            "Imported callout block should preserve its continuation line"
        )

        let body = app.textViews
            .matching(NSPredicate(format: "value CONTAINS %@", "Body after blocks"))
            .firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 5), "Markdown import should keep following body text")

        clickPageActionMenuItem("导出 Markdown", in: app)

        let exportedMarkdown = app.staticTexts["editor.markdown-export-test-output"]
        XCTAssertTrue(exportedMarkdown.waitForExistence(timeout: 5), "Markdown export should publish captured test output")
        XCTAssertTrue(
            exportedMarkdown.waitForLabelOrValue(containing: "> First quote line", timeout: 5),
            "Exported Markdown should keep the quote prefix on the first line"
        )
        XCTAssertTrue(
            exportedMarkdown.waitForLabelOrValue(containing: "> second quote line", timeout: 5),
            "Exported Markdown should keep the quote prefix on continuation lines"
        )
        XCTAssertTrue(
            exportedMarkdown.waitForLabelOrValue(containing: "> [!NOTE] First callout line", timeout: 5),
            "Exported Markdown should keep the callout marker on the first line"
        )
        XCTAssertTrue(
            exportedMarkdown.waitForLabelOrValue(containing: "> second callout line", timeout: 5),
            "Exported Markdown should keep the callout prefix on continuation lines"
        )
    }

    @MainActor
    func testOutlinePanelExposesHeadingLevelAndFocusesHeading() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_MARKDOWN_IMPORT_TEXT"] =
            "# Imported Heading\n\n## Imported Section\n\n### Imported Detail\n\nImported paragraph from toolbar"
        app.launch()

        openWelcomePageForPageToolbarActions(in: app)

        clickPageActionMenuItem("导入 Markdown", in: app)

        let inlineOutline = app.element(identifier: "editor.desktop-inline-outline")
        if !inlineOutline.waitForExistence(timeout: 2) {
            let outlineTrigger = app.element(identifier: "editor.desktop-inline-outline-trigger")
            XCTAssertTrue(
                outlineTrigger.waitForExistence(timeout: 5),
                "A narrowed editor should hide the outline behind a left-side trigger"
            )
            outlineTrigger.click()
            XCTAssertTrue(
                app.element(identifier: "editor.desktop-inline-outline-popover").waitForExistence(timeout: 5),
                "Clicking the collapsed left-side outline trigger should reveal the floating outline"
            )
        }
        let outlinePanel = app.element(identifier: "editor.outline")
        XCTAssertTrue(outlinePanel.waitForExistence(timeout: 5), "Imported heading should create an Outline panel")
        XCTAssertFalse(
            app.element(identifier: "editor.auxiliary-rail").exists,
            "Desktop outline should no longer create a fourth right-side column"
        )

        let outlineRow = app.element(identifierPrefix: "editor.outline.")
        XCTAssertTrue(outlineRow.waitForExistence(timeout: 5), "Outline panel should expose the imported heading")
        XCTAssertEqual(outlineRow.label, "Outline heading Imported Heading")
        XCTAssertTrue(outlineRow.waitForValue(containing: "Level 1", timeout: 5))

        let sectionRow = app.buttons["Outline heading Imported Section"]
        XCTAssertTrue(sectionRow.waitForExistence(timeout: 5), "Outline panel should expose imported level-two headings")

        let detailRow = app.buttons["Outline heading Imported Detail"]
        XCTAssertTrue(detailRow.waitForExistence(timeout: 5), "Outline panel should expose imported level-three headings")

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

        openWelcomePageForPageToolbarActions(in: app)

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Welcome block should be loaded before exporting")
        XCTAssertTrue(
            textView.waitForValue(containing: "开始用块写作。", timeout: 5),
            "Welcome block text should be loaded before exporting"
        )

        clickPageActionMenuItem("导出 Markdown", in: app)

        let exportedMarkdown = app.staticTexts["editor.markdown-export-test-output"]
        XCTAssertTrue(exportedMarkdown.waitForExistence(timeout: 5), "Markdown export should publish captured test output")
        let exportedLabel = exportedMarkdown.label
        let exportedValue = exportedMarkdown.value as? String ?? ""
        XCTAssertTrue(
            exportedMarkdown.waitForLabelOrValue(containing: "开始用块写作。", timeout: 5),
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

        clickPageActionMenuItem("附件", in: app)

        let insertedAttachment = app.element(identifierPrefix: "editor.attachment.")
        XCTAssertTrue(insertedAttachment.waitForExistence(timeout: 10), "Toolbar attachment import should render an attachment row")
        XCTAssertTrue(
            insertedAttachment.waitForLabelOrValue(containing: "toolbar-attachment.txt", timeout: 5),
            "Toolbar attachment row should expose the imported filename"
        )
    }

    @MainActor
    func testClickingImmediatelyBelowTrailingNonEditableBlockCreatesEditableBlock() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_ATTACHMENT_IMPORT_FILENAME"] = "trailing-attachment.txt"
        app.launchEnvironment["EDITOR_UI_TEST_ATTACHMENT_IMPORT_CONTENTS"] = "Attachment before trailing editor hit area"
        app.launch()

        clickPageActionMenuItem("附件", in: app)

        let insertedAttachment = app.element(identifierPrefix: "editor.attachment.")
        XCTAssertTrue(insertedAttachment.waitForExistence(timeout: 10), "Toolbar attachment import should render a trailing non-editable row")
        let initialTextViewCount = app.textViews.count

        let trailingInsertRegion = app.element(identifier: "editor.canvas-trailing-insert-region")
        XCTAssertTrue(
            trailingInsertRegion.waitForExistence(timeout: 5),
            "The area immediately below the trailing block should be an addressable insert/focus hit region"
        )
        trailingInsertRegion.click()

        let insertedTextView = app.textViews.element(boundBy: initialTextViewCount)
        XCTAssertTrue(
            insertedTextView.waitForExistence(timeout: 5),
            "Clicking immediately below a trailing non-editable block should create a new editable block"
        )
        XCTAssertTrue(
            insertedTextView.waitForKeyboardFocus(timeout: 5),
            "The newly created trailing block should receive keyboard focus"
        )

        app.typeText("After attachment")
        XCTAssertTrue(
            insertedTextView.waitForValue(containing: "After attachment", timeout: 5),
            "Typing after clicking the trailing hit region should continue in the new block"
        )
    }

    @MainActor
    func testCommandVPastesImageFileAsAttachmentRow() throws {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launch()

        let textView = app.textViews
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.text."))
            .firstMatch
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Daily page text block should be visible before pasting an image")

        let imageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("editor-ui-paste-\(UUID().uuidString)")
            .appendingPathComponent("pasted-image.png")
        try FileManager.default.createDirectory(
            at: imageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: imageURL.deletingLastPathComponent()) }
        let imageData = try XCTUnwrap(
            Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==")
        )
        try imageData.write(to: imageURL, options: .atomic)
        NSPasteboard.general.clearContents()
        XCTAssertTrue(NSPasteboard.general.writeObjects([imageURL as NSURL]))

        textView.click()
        textView.typeKey("v", modifierFlags: .command)

        let insertedAttachment = app.element(identifierPrefix: "editor.attachment.")
        XCTAssertTrue(insertedAttachment.waitForExistence(timeout: 10), "Cmd+V should import the pasted image file as an attachment block")
        XCTAssertTrue(
            insertedAttachment.waitForLabelOrValue(containing: "pasted-image.png", timeout: 5),
            "Pasted image attachment should expose the source filename"
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
    func testSeededConflictAutoResolvesWithoutManualMergeEditor() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_CONFLICT"] = "1"
        app.launch()

        let mergeText = app.textViews
            .matching(NSPredicate(format: "identifier ENDSWITH %@", ".merge-text"))
            .firstMatch
        XCTAssertFalse(mergeText.waitForExistence(timeout: 2), "Seeded conflict should be auto-resolved without exposing the manual merge editor")

        let textView = app.textViews["editor.text.block-welcome-001"]
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "Auto-resolved conflict should keep the original block visible")
        XCTAssertTrue(
            textView.waitForValue(containing: "Local conflict draft\nRemote conflict draft", timeout: 5),
            "Auto-resolved conflict should preserve both local and remote text in the block"
        )
    }

    @MainActor
    func testMultipleSeededConflictsAutoResolveWithoutBatchControls() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_CONFLICT"] = "1"
        app.launchEnvironment["EDITOR_UI_TEST_CONFLICT_COUNT"] = "2"
        app.launch()

        let draftAllRemoteButton = app.buttons["editor.conflict.draft-all-remote"]
        let draftAllLocalButton = app.buttons["editor.conflict.draft-all-local"]
        XCTAssertFalse(draftAllRemoteButton.waitForExistence(timeout: 2), "Auto-resolved conflicts should not expose remote batch controls")
        XCTAssertFalse(draftAllLocalButton.exists, "Auto-resolved conflicts should not expose local batch controls")

        let textViews = app.textViews.matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.text."))
        XCTAssertTrue(
            textViews.firstMatch.waitForValue(containing: "Local conflict draft\nRemote conflict draft", timeout: 5),
            "First auto-resolved conflict should preserve local and remote text"
        )
    }

    @MainActor
    func testLargePageScrollLoadsDistantBlocks() {
        let app = XCUIApplication()
        app.launchEnvironment["EDITOR_APP_SUPPORT_DIR"] = appSupportDirectory.path
        app.launchEnvironment["EDITOR_UI_TEST_LARGE_PAGE_BLOCK_COUNT"] = "760"
        app.launch()

        let allDocuments = app.buttons["editor.collection.all-documents"]
        XCTAssertTrue(allDocuments.waitForExistence(timeout: 5), "All Documents should expose the seeded large page")
        allDocuments.click()

        let largePage = app.element(identifier: "editor.page-row.page-welcome")
        XCTAssertTrue(largePage.waitForExistence(timeout: 5), "The seeded large page should be visible in All Documents")
        largePage.click()

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
        for _ in 0..<12 {
            let visiblePeakIndex = scrollMetrics.stringValue.integerField("peak_last_visible_block_index") ?? -1
            if distantBlock.exists || visiblePeakIndex >= 79 {
                break
            }
            canvas.swipeUp()
            _ = scrollMetrics.waitForIntegerField("peak_last_visible_block_index", atLeast: 79, timeout: 1)
        }

        let scrollMetricsValueAfterSwipes = scrollMetrics.stringValue
        XCTAssertTrue(
            scrollMetrics.waitForIntegerField("peak_last_visible_block_index", atLeast: 79, timeout: 5),
            "Scrolling the editor canvas should realize distant blocks in a large page; metrics=\(scrollMetricsValueAfterSwipes)"
        )
        if distantBlock.exists {
            XCTAssertTrue(
                distantBlock.waitForValue(containing: "Large block 80 searchable content", timeout: 5),
                "The realized distant block should expose the expected seeded text"
            )
        }

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
            scrollMetricsValue.integerField("peak_last_visible_block_index") ?? -1,
            79,
            "Runtime scroll capture should prove the realized visible window reached the distant block at least once; value=\(scrollMetricsValue)"
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

    func waitForValue(equalTo text: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { element, _ in
            guard let element = element as? XCUIElement,
                  let value = element.value as? String else {
                return false
            }
            return value == text
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

    func waitForIntegerField(_ name: String, atLeast minimumValue: Int, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { element, _ in
            guard let element = element as? XCUIElement else {
                return false
            }
            return (element.stringValue.integerField(name) ?? -1) >= minimumValue
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

    func waitForTextViewCount(_ count: Int, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { application, _ in
            guard let application = application as? XCUIApplication else {
                return false
            }
            return application.textViews.count == count
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}

@MainActor
private func textViewValues(in application: XCUIApplication) -> String {
    application.textViews.allElementsBoundByIndex
        .map { element in
            let identifier = element.identifier.isEmpty ? "<no-id>" : element.identifier
            let value = element.value as? String ?? element.label
            return "\(identifier)=\(value)"
        }
        .joined(separator: " | ")
}

@MainActor
private func openWelcomeBlockContextMenu(in application: XCUIApplication) {
    let textView = application.textViews["editor.text.block-welcome-001"]
    if textView.waitForExistence(timeout: 2) {
        textView.click()
    }

    let handle = application.element(identifier: "editor.block.block-welcome-001.drag-handle")
    XCTAssertTrue(handle.waitForExistence(timeout: 5), "Welcome block drag handle should exist before opening its context menu")
    handle.rightClick()
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
