import Foundation
import XCTest
import HighlightSwift
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

final class NativeTextBlockEditorTests: XCTestCase {
    @MainActor
    func testNativeTextBlockEditorKeepsBlockIdentityAndInitialText() {
        let session = EditorSession()
        let editor = NativeTextBlockEditor(
            blockID: "block-1",
            text: "Hello",
            blockType: .paragraph,
            session: session,
            onTextChange: { _ in }
        )

        XCTAssertEqual(editor.blockID, "block-1")
        XCTAssertEqual(editor.text, "Hello")
        XCTAssertEqual(editor.blockType, .paragraph)
        XCTAssertEqual(editor.contentFont, EditorContentFont.defaultFont)
    }

    @MainActor
    func testNativeTextBlockEditorKeepsLineWrappingConfiguration() {
        let session = EditorSession()
        let editor = NativeTextBlockEditor(
            blockID: "block-1",
            text: "let value = 1",
            blockType: .codeBlock,
            session: session,
            lineWrapping: false,
            onTextChange: { _ in }
        )

        XCTAssertFalse(editor.lineWrapping)
    }

    @MainActor
    func testNativeTextBlockEditorDoesNotShowSlashPlaceholderForFocusedEmptyBlock() {
        let session = EditorSession()
        let editor = NativeTextBlockEditor(
            blockID: "block-1",
            text: "",
            blockType: .paragraph,
            session: session,
            onTextChange: { _ in }
        )

        XCTAssertFalse(editor.showsPlaceholder)

        session.beginEditing(blockID: "block-1", reason: .programmatic)
        let focusedEditor = NativeTextBlockEditor(
            blockID: "block-1",
            text: "",
            blockType: .paragraph,
            session: session,
            onTextChange: { _ in }
        )
        XCTAssertFalse(focusedEditor.showsPlaceholder)

        let editorWithText = NativeTextBlockEditor(
            blockID: "block-1",
            text: "Already editable",
            blockType: .paragraph,
            session: session,
            onTextChange: { _ in }
        )
        XCTAssertFalse(editorWithText.showsPlaceholder)
    }

    func testNativeFocusRequestStateRetriesUntilFocusSucceeds() {
        let requestID = UUID()
        var state = NativeTextFocusRequestState()

        XCTAssertEqual(state.beginScheduling(requestID), requestID)
        state.finish(requestID: requestID, didFocus: false)

        XCTAssertEqual(state.beginScheduling(requestID), requestID)
        state.finish(requestID: requestID, didFocus: true)

        XCTAssertNil(state.beginScheduling(requestID))
    }

    func testNativeTextFocusConfirmationPolicyRetriesWhenFocusIsLostAfterFirstResponderCall() {
        XCTAssertFalse(
            NativeTextFocusConfirmationPolicy.shouldMarkRequestHandled(
                didPerformFocus: true,
                isFirstResponderAfterConfirmation: false
            )
        )
        XCTAssertTrue(
            NativeTextFocusConfirmationPolicy.shouldRetry(
                didPerformFocus: true,
                isFirstResponderAfterConfirmation: false,
                remainingAttempts: 1
            )
        )
        XCTAssertFalse(
            NativeTextFocusConfirmationPolicy.shouldRetry(
                didPerformFocus: true,
                isFirstResponderAfterConfirmation: false,
                remainingAttempts: 0
            )
        )
        XCTAssertTrue(
            NativeTextFocusConfirmationPolicy.shouldMarkRequestHandled(
                didPerformFocus: true,
                isFirstResponderAfterConfirmation: true
            )
        )
    }

    func testNativeTextModelUpdateGuardSuppressesProgrammaticTextChangeForwarding() {
        var guardState = NativeTextModelUpdateGuard()

        XCTAssertTrue(guardState.shouldForwardTextChange)

        guardState.beginApplyingModelText()
        XCTAssertFalse(guardState.shouldForwardTextChange)

        guardState.finishApplyingModelText()
        XCTAssertTrue(guardState.shouldForwardTextChange)
    }

    func testNativeTextCompositionPolicyDefersModelAndCommandWorkWhileIMEIsComposing() {
        XCTAssertFalse(NativeTextCompositionPolicy.shouldApplyModelText(isComposing: true))
        XCTAssertFalse(NativeTextCompositionPolicy.shouldApplyInlineMarkdownStyles(isComposing: true))
        XCTAssertFalse(NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: true))

        XCTAssertTrue(NativeTextCompositionPolicy.shouldApplyModelText(isComposing: false))
        XCTAssertTrue(NativeTextCompositionPolicy.shouldApplyInlineMarkdownStyles(isComposing: false))
        XCTAssertTrue(NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: false))
    }

    func testNativeTextStyleApplicationPolicySkipsUnchangedStyleWork() {
        let key = NativeTextStyleFingerprint(
            blockType: .paragraph,
            text: "Hello **world**",
            fontName: "System",
            fontSize: 14,
            lineHeightMultiple: 1.34
        )

        XCTAssertTrue(
            NativeTextStyleApplicationPolicy.shouldApplyStyle(
                cached: nil,
                next: key,
                isComposing: false
            )
        )
        XCTAssertFalse(
            NativeTextStyleApplicationPolicy.shouldApplyStyle(
                cached: key,
                next: key,
                isComposing: false
            )
        )
        XCTAssertFalse(
            NativeTextStyleApplicationPolicy.shouldApplyStyle(
                cached: nil,
                next: key,
                isComposing: true
            )
        )
        XCTAssertTrue(
            NativeTextStyleApplicationPolicy.shouldApplyStyle(
                cached: key,
                next: key,
                isComposing: false,
                baseAttributesWereReset: true
            )
        )
        XCTAssertFalse(
            NativeTextStyleApplicationPolicy.shouldApplyStyle(
                cached: key,
                next: key,
                isComposing: true,
                baseAttributesWereReset: true
            )
        )
        XCTAssertTrue(
            NativeTextStyleApplicationPolicy.shouldApplyStyle(
                cached: key,
                next: NativeTextStyleFingerprint(
                    blockType: .paragraph,
                    text: "Hello **world**!",
                    fontName: "System",
                    fontSize: 14,
                    lineHeightMultiple: 1.34
                ),
                isComposing: false
            )
        )
    }

    func testNativeTextHeightMeasurementPolicySkipsUnchangedMeasurementWork() {
        let key = NativeTextHeightMeasurementFingerprint(
            text: "Wrapped text",
            width: 320,
            lineWrapping: true,
            blockType: .paragraph,
            fontName: "System",
            fontSize: 14,
            minimumHeight: 20,
            lineHeightMultiple: 1.34
        )

        XCTAssertTrue(
            NativeTextHeightMeasurementPolicy.shouldMeasureHeight(
                cached: nil,
                next: key
            )
        )
        XCTAssertFalse(
            NativeTextHeightMeasurementPolicy.shouldMeasureHeight(
                cached: key,
                next: key
            )
        )
        XCTAssertTrue(
            NativeTextHeightMeasurementPolicy.shouldMeasureHeight(
                cached: key,
                next: NativeTextHeightMeasurementFingerprint(
                    text: "Wrapped text",
                    width: 500,
                    lineWrapping: true,
                    blockType: .paragraph,
                    fontName: "System",
                    fontSize: 14,
                    minimumHeight: 20,
                    lineHeightMultiple: 1.34
                )
            )
        )
    }

    func testNativeTextPlaceholderHidesWhileIMEIsComposing() {
        XCTAssertFalse(
            NativeTextPlaceholderVisibilityPolicy.showsPlaceholder(
                text: "",
                isFocused: true,
                isComposing: true
            )
        )
        XCTAssertFalse(
            NativeTextPlaceholderVisibilityPolicy.showsPlaceholder(
                text: "",
                isFocused: true,
                isComposing: false
            )
        )
        XCTAssertFalse(
            NativeTextPlaceholderVisibilityPolicy.showsPlaceholder(
                text: "分",
                isFocused: true,
                isComposing: false
            )
        )
    }

    func testNativeTextDropPolicyKeepsBlockDragsOutOfTextEditor() {
        XCTAssertFalse(NativeTextDropPolicy.acceptsDropIntoTextEditor)
    }

    func testEditorContentFontOnlyAppliesToReadableTextBlocks() {
        XCTAssertNil(EditorContentFont.system.postScriptName(for: .paragraph))
        XCTAssertEqual(
            EditorContentFont.lxgwWenKai.postScriptName(for: .paragraph),
            "LXGWWenKaiGBScreen"
        )
        XCTAssertEqual(
            EditorContentFont.lxgwWenKai.postScriptName(for: .heading1),
            "LXGWWenKaiGBScreen"
        )
        XCTAssertEqual(
            EditorContentFont.lxgwWenKai.postScriptName(for: .taskItem),
            "LXGWWenKaiGBScreen"
        )
        XCTAssertNil(EditorContentFont.lxgwWenKai.postScriptName(for: .codeBlock))
        XCTAssertNil(EditorContentFont.lxgwWenKai.postScriptName(for: .table))
    }

    func testEditorContentFontDefaultsToBundledLXGWWenKaiAndUsesStableStorageKey() {
        XCTAssertEqual(EditorContentFont.defaultFont, .lxgwWenKai)
        XCTAssertEqual(EditorContentFont.defaultRawValue, "lxgwWenKai")
        XCTAssertEqual(EditorContentFont.appStorageKey, "editor.content-font")
        XCTAssertEqual(EditorContentFont.lxgwWenKaiResourceName, "LXGW WenK")
        XCTAssertEqual(EditorContentFont.lxgwWenKaiPostScriptName, "LXGWWenKaiGBScreen")
    }

    func testEditorContentFontAppliesToContentPageTitle() {
        XCTAssertNil(EditorContentFont.system.pageTitlePostScriptName)
        XCTAssertEqual(
            EditorContentFont.lxgwWenKai.pageTitlePostScriptName,
            EditorContentFont.lxgwWenKaiPostScriptName
        )
    }

    func testMobileNativeTextDragUsesExplicitBlockPayloadWhenTextViewConsumesLongPress() {
        XCTAssertEqual(
            MobileNativeTextBlockDragPolicy.payloadText(blockID: "block-a", explicitPayloadText: "block-a\nblock-b"),
            "block-a\nblock-b"
        )
        XCTAssertEqual(
            MobileNativeTextBlockDragPolicy.payloadText(blockID: "block-a", explicitPayloadText: nil),
            "block-a"
        )
        XCTAssertTrue(MobileNativeTextBlockDragPolicy.installsUIDragInteraction)
        XCTAssertTrue(MobileNativeTextBlockDragPolicy.disablesSystemTextDragInteraction)
        XCTAssertTrue(MobileNativeTextBlockDragPolicy.disablesSystemTextDropInteraction)
    }

    func testNativeTextInsertionPointRectResolverClampsTallCaretToFontLineHeight() {
        let originalRect = CGRect(x: 12, y: 4, width: 2, height: 28)

        let resolved = NativeTextInsertionPointRectResolver.rect(
            original: originalRect,
            fontLineHeight: 16
        )

        XCTAssertEqual(resolved.origin.x, 12)
        XCTAssertEqual(resolved.size.width, 2)
        XCTAssertEqual(resolved.size.height, 18)
        XCTAssertEqual(resolved.midY, originalRect.midY, accuracy: 0.001)
    }

    func testNativeTextInsertionPointRectResolverCanOffsetCaretForPlatformAlignment() {
        let originalRect = CGRect(x: 12, y: 4, width: 2, height: 28)

        let resolved = NativeTextInsertionPointRectResolver.rect(
            original: originalRect,
            fontLineHeight: 16,
            verticalOffset: -1
        )

        XCTAssertEqual(resolved.size.height, 18)
        XCTAssertEqual(resolved.origin.y, 8)
    }

    #if os(macOS)
    func testNativeTextCursorChromeUsesEditorAccentColor() {
        let color = NativeTextCursorChrome.nsColor(for: .light)
        XCTAssertEqual(color.redComponent, EditorDesignTokens.Colors.accent.components(for: .light).red, accuracy: 0.0001)
        XCTAssertEqual(color.greenComponent, EditorDesignTokens.Colors.accent.components(for: .light).green, accuracy: 0.0001)
        XCTAssertEqual(color.blueComponent, EditorDesignTokens.Colors.accent.components(for: .light).blue, accuracy: 0.0001)
    }

    func testNativeTextCursorChromeResolvesDarkAccentColor() {
        let color = NativeTextCursorChrome.nsColor(for: .dark)
        XCTAssertEqual(color.redComponent, EditorDesignTokens.Colors.accent.components(for: .dark).red, accuracy: 0.0001)
        XCTAssertEqual(color.greenComponent, EditorDesignTokens.Colors.accent.components(for: .dark).green, accuracy: 0.0001)
        XCTAssertEqual(color.blueComponent, EditorDesignTokens.Colors.accent.components(for: .dark).blue, accuracy: 0.0001)
    }
    #elseif os(iOS)
    func testNativeTextCursorChromeUsesEditorAccentColor() {
        let color = NativeTextCursorChrome.uiColor(for: .light)
        XCTAssertEqual(color.cgColor.components?[0], EditorDesignTokens.Colors.accent.components(for: .light).red, accuracy: 0.0001)
        XCTAssertEqual(color.cgColor.components?[1], EditorDesignTokens.Colors.accent.components(for: .light).green, accuracy: 0.0001)
        XCTAssertEqual(color.cgColor.components?[2], EditorDesignTokens.Colors.accent.components(for: .light).blue, accuracy: 0.0001)
    }

    func testNativeTextCursorChromeResolvesDarkAccentColor() {
        let color = NativeTextCursorChrome.uiColor(for: .dark)
        XCTAssertEqual(color.cgColor.components?[0], EditorDesignTokens.Colors.accent.components(for: .dark).red, accuracy: 0.0001)
        XCTAssertEqual(color.cgColor.components?[1], EditorDesignTokens.Colors.accent.components(for: .dark).green, accuracy: 0.0001)
        XCTAssertEqual(color.cgColor.components?[2], EditorDesignTokens.Colors.accent.components(for: .dark).blue, accuracy: 0.0001)
    }
    #endif

    func testNativeInlineMarkdownChromeUsesAdaptiveInlineCodeBackground() {
        XCTAssertEqual(NativeInlineMarkdownStyleChrome.inlineCodeBackgroundToken, EditorDesignTokens.Colors.inlineCodeBackground)
    }

    func testNativeTextKeyboardRestorePolicyDoesNotStealFocusAfterResponderTransfer() {
        XCTAssertTrue(
            NativeTextKeyboardRestorePolicy.shouldRestoreSystemKeyboard(
                wasReplacingKeyboard: true,
                replacesKeyboard: false,
                isTextViewFirstResponder: true
            )
        )
        XCTAssertFalse(
            NativeTextKeyboardRestorePolicy.shouldRestoreSystemKeyboard(
                wasReplacingKeyboard: true,
                replacesKeyboard: false,
                isTextViewFirstResponder: false
            ),
            "When a title field has already become first responder, the old body text view must not asynchronously steal focus back"
        )
        XCTAssertFalse(
            NativeTextKeyboardRestorePolicy.shouldRestoreSystemKeyboard(
                wasReplacingKeyboard: false,
                replacesKeyboard: false,
                isTextViewFirstResponder: true
            )
        )
    }

    func testNativeTextEditorLayoutAddsVerticalInsetToAvoidSelectionClipping() {
        XCTAssertEqual(NativeTextEditorLayout.textContainerInset.height, 2)
        XCTAssertEqual(
            NativeTextEditorLayout.measuredHeight(contentHeight: 18, minimumHeight: 20),
            22
        )
    }

    func testNativeTextMeasurementWidthClampsLongContentToViewport() {
        XCTAssertEqual(
            NativeTextMeasurementWidthPolicy.width(
                boundsWidth: 900,
                viewportWidth: 393,
                horizontalMargin: 28,
                lineWrapping: true
            ),
            365
        )
        XCTAssertEqual(
            NativeTextMeasurementWidthPolicy.width(
                boundsWidth: 0,
                viewportWidth: 393,
                horizontalMargin: 28,
                lineWrapping: true
            ),
            365
        )
        XCTAssertEqual(
            NativeTextMeasurementWidthPolicy.width(
                boundsWidth: 220,
                viewportWidth: 393,
                horizontalMargin: 28,
                lineWrapping: true
            ),
            220
        )
        XCTAssertEqual(
            NativeTextMeasurementWidthPolicy.width(
                boundsWidth: 220,
                viewportWidth: 393,
                horizontalMargin: 28,
                lineWrapping: false
            ),
            10_000
        )
    }

    #if os(macOS)
    func testCodeBlockSyntaxHighlightApplicatorPreservesTextAndBaseFont() {
        let code = "let value = 1\nprint(value)"
        let highlighted = NSMutableAttributedString(string: code)
        highlighted.addAttribute(
            .foregroundColor,
            value: NSColor.systemPurple,
            range: NSRange(location: 0, length: 3)
        )
        let baseFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let applied = CodeBlockSyntaxHighlightApplicator.attributedString(
            text: code,
            highlighted: highlighted,
            baseAttributes: [
                .font: baseFont,
                .foregroundColor: NSColor.labelColor
            ],
            allowedAttributeKeys: [.foregroundColor]
        )

        XCTAssertEqual(applied.string, code)
        XCTAssertEqual(applied.attribute(.font, at: 0, effectiveRange: nil) as? NSFont, baseFont)
        XCTAssertEqual(applied.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, .systemPurple)
    }

    func testMarkdownSyntaxMarkerAttributesHideMarkers() {
        let attributes = NativeTextMarkdownSyntaxMarkerAttributes.appKit(
            baseFont: NSFont.systemFont(ofSize: 16)
        )
        let markerFont = attributes[.font] as? NSFont

        XCTAssertEqual(attributes[.foregroundColor] as? NSColor, .clear)
        XCTAssertLessThanOrEqual(markerFont?.pointSize ?? 16, 1)
    }
    #endif

    func testHighlightSwiftSupportsMultipleCodeLanguages() async throws {
        let highlighter = Highlight()

        let swift = try await highlighter.request("let value = 1", mode: .languageAlias("swift"))
        let python = try await highlighter.request("def value():\n    return 1", mode: .languageAlias("python"))

        XCTAssertEqual(swift.language, "swift")
        XCTAssertEqual(python.language, "python")
    }

    func testSlashCommandKeyboardResolverKeepsArrowKeysInsideOpenMenu() {
        XCTAssertEqual(
            SlashCommandKeyboardResolver.navigationDirection(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [],
                text: "/",
                selectedRange: NSRange(location: 1, length: 0)
            ),
            .down
        )
        XCTAssertEqual(
            SlashCommandKeyboardResolver.navigationDirection(
                keyCode: BlockKeyboardShortcutResolver.upArrowKeyCode,
                modifiers: [],
                text: "/表",
                selectedRange: NSRange(location: 2, length: 0)
            ),
            .up
        )
        XCTAssertNil(
            SlashCommandKeyboardResolver.navigationDirection(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [],
                text: "plain",
                selectedRange: NSRange(location: 5, length: 0)
            )
        )
    }

    func testSlashCommandKeyboardResolverSelectsCommandWithReturnOnlyInOpenMenu() {
        XCTAssertTrue(
            SlashCommandKeyboardResolver.requestsSelection(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: [],
                text: "/表",
                selectedRange: NSRange(location: 2, length: 0)
            )
        )
        XCTAssertFalse(
            SlashCommandKeyboardResolver.requestsSelection(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: [],
                text: "normal",
                selectedRange: NSRange(location: 6, length: 0)
            )
        )
    }

    func testNativeTextFocusSelectionUsesValidRequestedSelectionRange() {
        let range = NativeTextFocusSelection.range(
            from: EditorTextSelection(blockID: "block-1", location: 3, length: 2),
            blockID: "block-1",
            text: "Hello"
        )

        XCTAssertEqual(range, NSRange(location: 3, length: 2))
    }

    func testNativeTextFocusSelectionFallsBackToTextEndForInvalidSelection() {
        XCTAssertEqual(
            NativeTextFocusSelection.range(
                from: EditorTextSelection(blockID: "other", location: 1, length: 1),
                blockID: "block-1",
                text: "Hi 🧠"
            ),
            NSRange(location: ("Hi 🧠" as NSString).length, length: 0)
        )
        XCTAssertEqual(
            NativeTextFocusSelection.range(
                from: EditorTextSelection(blockID: "block-1", location: 20, length: 1),
                blockID: "block-1",
                text: "Short"
            ),
            NSRange(location: 5, length: 0)
        )
    }

    @MainActor
    func testNativeTextBlockEditorAcceptsInactiveWindowFirstMouseOnMac() {
#if os(macOS)
        XCTAssertTrue(NativeTextBlockEditor.acceptsInactiveWindowFirstMouse)
#endif
    }

    func testNativeTextMouseFocusPolicyMakesWindowKeyBeforeFocusingTextViewOnMac() {
#if os(macOS)
        XCTAssertTrue(NativeTextMouseFocusPolicy.makesWindowKeyBeforeFirstResponder)
#endif
    }

    func testMacWindowVisibilityPolicyRequestsMainWindowWhenNoneVisible() {
#if os(macOS)
        XCTAssertTrue(MacWindowVisibilityPolicy.shouldRequestMainWindow(hasVisibleWindows: false))
        XCTAssertFalse(MacWindowVisibilityPolicy.shouldRequestMainWindow(hasVisibleWindows: true))
#endif
    }

    func testMacPasteboardAttachmentResolverReadsFileURLs() throws {
#if os(macOS)
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("editor-pasteboard-\(UUID().uuidString).txt")
        try "附件".write(to: sourceURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("editor-test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([sourceURL as NSURL]))

        XCTAssertEqual(MacPasteboardAttachmentResolver.attachmentURLs(from: pasteboard), [sourceURL])
#endif
    }

    func testMacPasteboardAttachmentResolverMaterializesImagePaste() throws {
#if os(macOS)
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 4, height: 4)).fill()
        image.unlockFocus()

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("editor-test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([image]))

        let urls = MacPasteboardAttachmentResolver.attachmentURLs(from: pasteboard)

        let imageURL = try XCTUnwrap(urls.first)
        defer { try? FileManager.default.removeItem(at: imageURL) }
        XCTAssertEqual(imageURL.pathExtension, "png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path))
#endif
    }

    func testIOSPasteboardAttachmentResolverMaterializesImagePaste() throws {
#if os(iOS)
        let pasteboardName = UIPasteboard.Name("editor-test-\(UUID().uuidString)")
        let pasteboard = try XCTUnwrap(UIPasteboard(name: pasteboardName, create: true))
        defer { UIPasteboard.remove(withName: pasteboardName) }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        pasteboard.image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        let urls = IOSPasteboardAttachmentResolver.attachmentURLs(from: pasteboard)

        let imageURL = try XCTUnwrap(urls.first)
        defer { try? FileManager.default.removeItem(at: imageURL) }
        XCTAssertEqual(imageURL.pathExtension, "png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path))
#endif
    }

    func testMacPasteKeyboardShortcutResolverHandlesCommandVOnly() {
#if os(macOS)
        XCTAssertTrue(
            MacPasteKeyboardShortcutResolver.requestsAttachmentPaste(
                keyCode: MacPasteKeyboardShortcutResolver.vKeyCode,
                input: "v",
                modifiers: [.command]
            )
        )
        XCTAssertTrue(
            MacPasteKeyboardShortcutResolver.requestsAttachmentPaste(
                keyCode: MacPasteKeyboardShortcutResolver.vKeyCode,
                input: "V",
                modifiers: [.command]
            )
        )
        XCTAssertFalse(
            MacPasteKeyboardShortcutResolver.requestsAttachmentPaste(
                keyCode: MacPasteKeyboardShortcutResolver.vKeyCode,
                input: "v",
                modifiers: []
            )
        )
        XCTAssertFalse(
            MacPasteKeyboardShortcutResolver.requestsAttachmentPaste(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                input: "\r",
                modifiers: [.command]
            )
        )
#endif
    }

    func testCommandVPasteShortcutResolverRequiresOnlyCommandV() {
        XCTAssertTrue(
            CommandVPasteShortcutResolver.requestsAttachmentPaste(
                input: "v",
                modifiers: [.command]
            )
        )
        XCTAssertTrue(
            CommandVPasteShortcutResolver.requestsAttachmentPaste(
                input: "V",
                modifiers: [.command]
            )
        )
        XCTAssertFalse(
            CommandVPasteShortcutResolver.requestsAttachmentPaste(
                input: "v",
                modifiers: []
            )
        )
        XCTAssertFalse(
            CommandVPasteShortcutResolver.requestsAttachmentPaste(
                input: "v",
                modifiers: [.command, .shift]
            )
        )
    }

    func testBlockKeyboardShortcutResolverHandlesCommandOptionArrowsOnly() {
        XCTAssertEqual(
            BlockKeyboardShortcutResolver.moveDirection(
                keyCode: BlockKeyboardShortcutResolver.upArrowKeyCode,
                modifiers: [.command, .option]
            ),
            .up
        )
        XCTAssertEqual(
            BlockKeyboardShortcutResolver.moveDirection(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [.command, .option]
            ),
            .down
        )
        XCTAssertNil(
            BlockKeyboardShortcutResolver.moveDirection(
                keyCode: BlockKeyboardShortcutResolver.upArrowKeyCode,
                modifiers: [.command]
            )
        )
        XCTAssertNil(
            BlockKeyboardShortcutResolver.moveDirection(
                keyCode: 0,
                modifiers: [.command, .option]
            )
        )
    }

    func testBlockKeyboardShortcutResolverHandlesReturnAsInsertBlockOnlyWithoutModifiers() {
        XCTAssertTrue(
            BlockKeyboardShortcutResolver.insertsBlockAfter(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: [],
                blockType: .paragraph
            )
        )
        XCTAssertFalse(
            BlockKeyboardShortcutResolver.insertsBlockAfter(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: [.shift],
                blockType: .paragraph
            )
        )
        XCTAssertFalse(
            BlockKeyboardShortcutResolver.insertsBlockAfter(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: [.command],
                blockType: .paragraph
            )
        )
        XCTAssertFalse(
            BlockKeyboardShortcutResolver.insertsBlockAfter(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: [],
                blockType: .codeBlock
            )
        )
    }

    func testEmptyDecoratedTextBlocksDemoteToParagraphOnReturnInsteadOfInsertingNewBlock() {
        XCTAssertTrue(
            EmptyTextBlockReturnResolver.shouldDemoteToParagraph(
                blockType: .unorderedListItem,
                text: ""
            )
        )
        XCTAssertTrue(
            EmptyTextBlockReturnResolver.shouldDemoteToParagraph(
                blockType: .orderedListItem,
                text: "   "
            )
        )
        XCTAssertTrue(
            EmptyTextBlockReturnResolver.shouldDemoteToParagraph(
                blockType: .taskItem,
                text: ""
            )
        )
        XCTAssertTrue(
            EmptyTextBlockReturnResolver.shouldDemoteToParagraph(
                blockType: .toggle,
                text: ""
            )
        )
        XCTAssertFalse(
            EmptyTextBlockReturnResolver.shouldDemoteToParagraph(
                blockType: .unorderedListItem,
                text: "item"
            )
        )
        XCTAssertFalse(
            EmptyTextBlockReturnResolver.shouldDemoteToParagraph(
                blockType: .paragraph,
                text: ""
            )
        )
        XCTAssertFalse(
            EmptyTextBlockReturnResolver.shouldDemoteToParagraph(
                blockType: .codeBlock,
                text: ""
            )
        )
    }

    func testNativeTextNewlineReplacementResolverDetectsSingleReturnSeparately() {
        XCTAssertTrue(NativeTextNewlineReplacementResolver.isSingleNewline("\n"))
        XCTAssertTrue(NativeTextNewlineReplacementResolver.isSingleNewline("\r"))
        XCTAssertFalse(NativeTextNewlineReplacementResolver.isSingleNewline("Alpha\nBeta"))
        XCTAssertFalse(NativeTextNewlineReplacementResolver.isSingleNewline("A"))
    }

    func testNativeTextNewlineReplacementResolverMapsBatchedReturnInputToSplitRange() throws {
        let result = try XCTUnwrap(
            NativeTextNewlineReplacementResolver.replacement(
                currentText: "Hello",
                range: NSRange(location: 5, length: 0),
                replacementText: " Alpha\nBeta"
            )
        )

        XCTAssertEqual(result.updatedText, "Hello Alpha\nBeta")
        XCTAssertEqual(result.newlineRange, NSRange(location: ("Hello Alpha" as NSString).length, length: 1))
    }

    func testNativeTextNewlineReplacementResolverMapsSelectedReplacementToUpdatedText() throws {
        let result = try XCTUnwrap(
            NativeTextNewlineReplacementResolver.replacement(
                currentText: "Hello old text",
                range: NSRange(location: 6, length: 8),
                replacementText: "new\ntext"
            )
        )

        XCTAssertEqual(result.updatedText, "Hello new\ntext")
        XCTAssertEqual(result.newlineRange, NSRange(location: ("Hello new" as NSString).length, length: 1))
    }

    func testNativeTextNewlineReplacementResolverIgnoresNonNewlineAndInvalidRanges() {
        XCTAssertNil(
            NativeTextNewlineReplacementResolver.replacement(
                currentText: "Hello",
                range: NSRange(location: 5, length: 0),
                replacementText: " world"
            )
        )
        XCTAssertNil(
            NativeTextNewlineReplacementResolver.replacement(
                currentText: "Hello",
                range: NSRange(location: 8, length: 0),
                replacementText: "\n"
            )
        )
    }

    func testNativeTextPasteSplitPolicyRoutesMultilineTextForEditableBlocksOnly() {
        XCTAssertTrue(
            NativeTextPasteSplitPolicy.shouldRouteToBlockPaste(
                text: "Alpha\nBeta",
                blockType: .paragraph
            )
        )
        XCTAssertTrue(
            NativeTextPasteSplitPolicy.shouldRouteToBlockPaste(
                text: "Alpha\n\nBeta",
                blockType: .unorderedListItem
            )
        )
        XCTAssertFalse(
            NativeTextPasteSplitPolicy.shouldRouteToBlockPaste(
                text: "Alpha",
                blockType: .paragraph
            )
        )
        XCTAssertFalse(
            NativeTextPasteSplitPolicy.shouldRouteToBlockPaste(
                text: "let a = 1\nlet b = 2",
                blockType: .codeBlock
            )
        )
    }

    func testBlockKeyboardShortcutResolverHandlesTabIndentAndShiftTabOutdent() {
        XCTAssertEqual(
            BlockKeyboardShortcutResolver.indentationDirection(
                keyCode: BlockKeyboardShortcutResolver.tabKeyCode,
                modifiers: []
            ),
            .indent
        )
        XCTAssertEqual(
            BlockKeyboardShortcutResolver.indentationDirection(
                keyCode: BlockKeyboardShortcutResolver.tabKeyCode,
                modifiers: [.shift]
            ),
            .outdent
        )
        XCTAssertNil(
            BlockKeyboardShortcutResolver.indentationDirection(
                keyCode: BlockKeyboardShortcutResolver.tabKeyCode,
                modifiers: [.command]
            )
        )
        XCTAssertNil(
            BlockKeyboardShortcutResolver.indentationDirection(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: []
            )
        )
    }

    func testBlockSelectAllKeyboardResolverSelectsBlockBeforeAllBlocks() {
        XCTAssertFalse(
            BlockSelectAllKeyboardResolver.requestsSelectAll(
                input: "b",
                modifiers: [.command]
            )
        )
        XCTAssertEqual(
            BlockSelectAllKeyboardResolver.stage(
                blockType: .paragraph,
                selectedRange: NSRange(location: 2, length: 0),
                text: "Alpha"
            ),
            .currentBlock
        )
        XCTAssertEqual(
            BlockSelectAllKeyboardResolver.stage(
                blockType: .paragraph,
                selectedRange: NSRange(location: 0, length: 5),
                text: "Alpha"
            ),
            .allBlocks
        )
    }

    func testBlockSelectAllKeyboardResolverKeepsCodeBlocksInTextSelection() {
        XCTAssertEqual(
            BlockSelectAllKeyboardResolver.stage(
                blockType: .codeBlock,
                selectedRange: NSRange(location: 3, length: 0),
                text: "let a = 1\nlet b = 2"
            ),
            .currentText
        )
        XCTAssertEqual(
            BlockSelectAllKeyboardResolver.stage(
                blockType: .codeBlock,
                selectedRange: NSRange(location: 0, length: 19),
                text: "let a = 1\nlet b = 2"
            ),
            .currentText
        )
    }

    func testBlockSelectionCancelKeyboardResolverHandlesPlainEscapeOnly() {
        XCTAssertTrue(
            BlockSelectionCancelKeyboardResolver.requestsCancel(
                keyCode: BlockSelectionCancelKeyboardResolver.escapeKeyCode,
                input: "\u{1B}",
                modifiers: []
            )
        )
        XCTAssertTrue(
            BlockSelectionCancelKeyboardResolver.requestsCancel(
                keyCode: 0,
                input: "\u{1B}",
                modifiers: []
            )
        )
        XCTAssertFalse(
            BlockSelectionCancelKeyboardResolver.requestsCancel(
                keyCode: BlockSelectionCancelKeyboardResolver.escapeKeyCode,
                input: "\u{1B}",
                modifiers: [.command]
            )
        )
        XCTAssertFalse(
            BlockSelectionCancelKeyboardResolver.requestsCancel(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                input: "\r",
                modifiers: []
            )
        )
    }

    func testMacEditorKeyboardShortcutActionResolverCancelsSelectedBlocksWithEscape() {
        XCTAssertEqual(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: BlockSelectionCancelKeyboardResolver.escapeKeyCode,
                input: "\u{1B}",
                modifiers: [],
                hasBlockSelection: true,
                hasPasteableAttachments: false
            ),
            .cancelSelection
        )
        XCTAssertNil(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: BlockSelectionCancelKeyboardResolver.escapeKeyCode,
                input: "\u{1B}",
                modifiers: [],
                hasBlockSelection: false,
                hasPasteableAttachments: false
            )
        )
        XCTAssertNil(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: BlockSelectionCancelKeyboardResolver.escapeKeyCode,
                input: "\u{1B}",
                modifiers: [.command],
                hasBlockSelection: true,
                hasPasteableAttachments: false
            )
        )
    }

    func testMacEditorKeyboardShortcutActionResolverMovesFocusForSelectedBlocks() {
        XCTAssertEqual(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: BlockKeyboardShortcutResolver.upArrowKeyCode,
                input: nil,
                modifiers: [],
                hasBlockSelection: true,
                hasPasteableAttachments: false
            ),
            .moveFocus(.previous)
        )
        XCTAssertEqual(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                input: nil,
                modifiers: [],
                hasBlockSelection: true,
                hasPasteableAttachments: false
            ),
            .moveFocus(.next)
        )
        XCTAssertNil(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                input: nil,
                modifiers: [],
                hasBlockSelection: false,
                hasPasteableAttachments: false
            )
        )
        XCTAssertEqual(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                input: nil,
                modifiers: [.shift],
                hasBlockSelection: true,
                hasPasteableAttachments: false
            ),
            .extendBlockSelection(.next)
        )
    }

    func testMacEditorKeyboardShortcutActionResolverHandlesSelectedBlockBatchCommands() {
        XCTAssertEqual(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: 51,
                input: nil,
                modifiers: [],
                hasBlockSelection: true,
                hasPasteableAttachments: false
            ),
            .deleteSelection
        )
        XCTAssertEqual(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: BlockKeyboardShortcutResolver.tabKeyCode,
                input: nil,
                modifiers: [],
                hasBlockSelection: true,
                hasPasteableAttachments: false
            ),
            .indentSelection(.indent)
        )
        XCTAssertEqual(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: BlockKeyboardShortcutResolver.tabKeyCode,
                input: nil,
                modifiers: [.shift],
                hasBlockSelection: true,
                hasPasteableAttachments: false
            ),
            .indentSelection(.outdent)
        )
        XCTAssertNil(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: 51,
                input: nil,
                modifiers: [],
                hasBlockSelection: false,
                hasPasteableAttachments: false
            )
        )
    }

    func testMacEditorKeyboardShortcutActionResolverCopiesSelectedBlocks() {
        XCTAssertEqual(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: 8,
                input: "c",
                modifiers: [.command],
                hasBlockSelection: true,
                hasPasteableAttachments: false
            ),
            .copySelection
        )
        XCTAssertNil(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: 8,
                input: "c",
                modifiers: [.command],
                hasBlockSelection: false,
                hasPasteableAttachments: false
            )
        )
    }

    func testSelectedBlockMarkdownCopyResolverExportsSelectedBlocksInVisibleOrder() {
        let blocks = [
            block(id: "first", type: .paragraph, text: "Alpha"),
            block(id: "second", type: .taskItem, text: "Todo"),
            block(id: "third", type: .heading2, text: "Section")
        ]

        XCTAssertEqual(
            SelectedBlockMarkdownCopyResolver.markdown(
                selectedBlockIDs: ["third", "missing", "second"],
                visibleBlocks: blocks,
                attachments: []
            ),
            "- [ ] Todo\n\n## Section"
        )
    }

    func testMacEditorKeyboardShortcutActionResolverOffersCodeTextSelectAllFallback() {
        XCTAssertEqual(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: 0,
                input: "a",
                modifiers: [.command],
                hasBlockSelection: false,
                hasPasteableAttachments: false
            ),
            .selectFocusedCodeText
        )
    }

    func testMacEditorKeyboardShortcutActionResolverHandlesUndoRedo() {
        XCTAssertEqual(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: 0,
                input: "z",
                modifiers: [.command],
                hasBlockSelection: false,
                hasPasteableAttachments: false
            ),
            .undoEdit
        )
        XCTAssertEqual(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: 0,
                input: "z",
                modifiers: [.command, .shift],
                hasBlockSelection: false,
                hasPasteableAttachments: false
            ),
            .redoEdit
        )
    }

    func testMacEditorKeyboardShortcutActionResolverPromotesBlockWithCommandRightBracket() {
        XCTAssertEqual(
            MacEditorKeyboardShortcutActionResolver.action(
                keyCode: 0,
                input: "]",
                modifiers: [.command],
                hasBlockSelection: false,
                hasPasteableAttachments: false
            ),
            .promoteBlockToPage
        )
    }

    func testBlockKeyboardFocusResolverMovesAcrossSingleLineBlocksAndAtMultilineBoundaries() {
        XCTAssertEqual(
            BlockKeyboardFocusResolver.focusDirection(
                keyCode: BlockKeyboardShortcutResolver.upArrowKeyCode,
                modifiers: [],
                selectedRange: NSRange(location: 0, length: 0),
                text: "First line"
            ),
            .previous
        )
        XCTAssertEqual(
            BlockKeyboardFocusResolver.focusDirection(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [],
                selectedRange: NSRange(location: ("Last line" as NSString).length, length: 0),
                text: "Last line"
            ),
            .next
        )
        XCTAssertEqual(
            BlockKeyboardFocusResolver.focusDirection(
                keyCode: BlockKeyboardShortcutResolver.upArrowKeyCode,
                modifiers: [],
                selectedRange: NSRange(location: 2, length: 0),
                text: "Middle"
            ),
            .previous
        )
        XCTAssertEqual(
            BlockKeyboardFocusResolver.focusDirection(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [],
                selectedRange: NSRange(location: 2, length: 0),
                text: "Middle"
            ),
            .next
        )
        XCTAssertNil(
            BlockKeyboardFocusResolver.focusDirection(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [],
                selectedRange: NSRange(location: 2, length: 0),
                text: "First\nSecond"
            )
        )
        XCTAssertNil(
            BlockKeyboardFocusResolver.focusDirection(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [.shift],
                selectedRange: NSRange(location: 6, length: 0),
                text: "Middle"
            )
        )
        XCTAssertNil(
            BlockKeyboardFocusResolver.focusDirection(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [],
                selectedRange: NSRange(location: 0, length: 2),
                text: "Selected"
            )
        )
    }

    func testBlockKeyboardSelectionExtensionResolverUsesShiftArrowsAtTextBoundaries() {
        XCTAssertEqual(
            BlockKeyboardSelectionExtensionResolver.direction(
                keyCode: BlockKeyboardShortcutResolver.upArrowKeyCode,
                modifiers: [.shift],
                selectedRange: NSRange(location: 0, length: 0),
                text: "First line"
            ),
            .previous
        )
        XCTAssertEqual(
            BlockKeyboardSelectionExtensionResolver.direction(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [.shift],
                selectedRange: NSRange(location: ("Last line" as NSString).length, length: 0),
                text: "Last line"
            ),
            .next
        )
        XCTAssertNil(
            BlockKeyboardSelectionExtensionResolver.direction(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [.shift],
                selectedRange: NSRange(location: 0, length: 2),
                text: "Selected text"
            )
        )
        XCTAssertNil(
            BlockKeyboardSelectionExtensionResolver.direction(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [],
                selectedRange: NSRange(location: 4, length: 0),
                text: "Text"
            )
        )
    }

    func testNonEditableBlockKeyboardFocusResolverMovesOnPlainVerticalArrows() {
        XCTAssertEqual(
            NonEditableBlockKeyboardFocusResolver.focusDirection(
                keyCode: BlockKeyboardShortcutResolver.upArrowKeyCode,
                modifiers: []
            ),
            .previous
        )
        XCTAssertEqual(
            NonEditableBlockKeyboardFocusResolver.focusDirection(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: []
            ),
            .next
        )
        XCTAssertNil(
            NonEditableBlockKeyboardFocusResolver.focusDirection(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [.shift]
            )
        )
    }

    func testNonEditableBlockKeyboardBridgeActivationMatchesSelectedStructuredBlocks() {
        XCTAssertTrue(
            NonEditableBlockKeyboardBridgeActivationResolver.isEnabled(
                blockType: .table,
                isBlockSelected: true
            )
        )
        XCTAssertTrue(
            NonEditableBlockKeyboardBridgeActivationResolver.isEnabled(
                blockType: .pageReference,
                isBlockSelected: true
            )
        )
        XCTAssertTrue(
            NonEditableBlockKeyboardBridgeActivationResolver.isEnabled(
                blockType: .divider,
                isBlockSelected: true
            )
        )
        XCTAssertFalse(
            NonEditableBlockKeyboardBridgeActivationResolver.isEnabled(
                blockType: .paragraph,
                isBlockSelected: true
            )
        )
        XCTAssertFalse(
            NonEditableBlockKeyboardBridgeActivationResolver.isEnabled(
                blockType: .table,
                isBlockSelected: false
            )
        )
    }

    func testIOSEditorKeyboardShortcutActionResolverMovesFocusAndPastes() {
        XCTAssertEqual(
            IOSEditorKeyboardShortcutActionResolver.action(
                input: IOSEditorKeyboardShortcutActionResolver.upArrowInput,
                modifiers: []
            ),
            .moveFocus(.previous)
        )
        XCTAssertEqual(
            IOSEditorKeyboardShortcutActionResolver.action(
                input: IOSEditorKeyboardShortcutActionResolver.downArrowInput,
                modifiers: []
            ),
            .moveFocus(.next)
        )
        XCTAssertEqual(
            IOSEditorKeyboardShortcutActionResolver.action(
                input: "v",
                modifiers: [.command]
            ),
            .pasteAttachments
        )
        XCTAssertNil(
            IOSEditorKeyboardShortcutActionResolver.action(
                input: IOSEditorKeyboardShortcutActionResolver.downArrowInput,
                modifiers: [.shift]
            )
        )
    }

    func testIOSEditorKeyboardShortcutBridgeActivationSeparatesPasteFromFocusMoves() {
        XCTAssertTrue(
            IOSEditorKeyboardShortcutBridgeActivationResolver.capturesPaste(
                hasFocusedTextBlock: false,
                hasCurrentPage: true,
                hasFocusedPageTitle: false
            )
        )
        XCTAssertFalse(
            IOSEditorKeyboardShortcutBridgeActivationResolver.capturesPaste(
                hasFocusedTextBlock: true,
                hasCurrentPage: true,
                hasFocusedPageTitle: false
            )
        )
        XCTAssertFalse(
            IOSEditorKeyboardShortcutBridgeActivationResolver.capturesPaste(
                hasFocusedTextBlock: false,
                hasCurrentPage: false,
                hasFocusedPageTitle: false
            )
        )
        XCTAssertFalse(
            IOSEditorKeyboardShortcutBridgeActivationResolver.capturesPaste(
                hasFocusedTextBlock: false,
                hasCurrentPage: true,
                hasFocusedPageTitle: true
            )
        )
        XCTAssertTrue(
            IOSEditorKeyboardShortcutBridgeActivationResolver.capturesFocusMove(
                hasBlockSelection: true
            )
        )
        XCTAssertFalse(
            IOSEditorKeyboardShortcutBridgeActivationResolver.capturesFocusMove(
                hasBlockSelection: false
            )
        )
    }

    func testBlockSelectionKeyboardAnchorResolverUsesSelectedBlockInDocumentOrder() {
        XCTAssertEqual(
            BlockSelectionKeyboardAnchorResolver.anchorBlockID(
                selectedBlockIDs: ["second", "missing"],
                visibleBlockIDs: ["first", "second", "third"]
            ),
            "second"
        )
        XCTAssertNil(
            BlockSelectionKeyboardAnchorResolver.anchorBlockID(
                selectedBlockIDs: ["missing"],
                visibleBlockIDs: ["first", "second", "third"]
            )
        )
    }

    func testPageDragPayloadResolverUsesBatchSelectionWhenDraggingSelectedPage() {
        XCTAssertEqual(
            PageDragPayloadResolver.pageIDsForDrag(
                pageID: "second",
                selectedPageIDs: ["third", "second"],
                visiblePageIDs: ["first", "second", "third"]
            ),
            ["second", "third"]
        )
        XCTAssertEqual(
            PageDragPayloadResolver.pageIDsForDrag(
                pageID: "first",
                selectedPageIDs: ["third", "second"],
                visiblePageIDs: ["first", "second", "third"]
            ),
            ["first"]
        )
    }

    func testPageDragPayloadResolverEncodesAndDecodesPageIDs() {
        let payload = PageDragPayloadResolver.payloadText(pageIDs: ["first", "second"])

        XCTAssertEqual(
            PageDragPayloadResolver.pageIDs(from: [payload, "ignored"]),
            ["first", "second"]
        )
        XCTAssertEqual(PageDragPayloadResolver.pageIDs(from: ["plain text"]), [])
    }

    func testTableBlockKeyboardActionResolverMovesFocusWhenSelectionIsActive() {
        XCTAssertEqual(
            TableBlockKeyboardActionResolver.action(
                keyCode: BlockKeyboardShortcutResolver.upArrowKeyCode,
                modifiers: [],
                hasSelection: true
            ),
            .moveFocus(.previous)
        )
        XCTAssertEqual(
            TableBlockKeyboardActionResolver.action(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [],
                hasSelection: true
            ),
            .moveFocus(.next)
        )
        XCTAssertEqual(
            TableBlockKeyboardActionResolver.action(
                keyCode: TableBlockKeyboardActionResolver.deleteBackwardKeyCode,
                modifiers: [],
                hasSelection: true
            ),
            .deleteSelection
        )
        XCTAssertEqual(
            TableBlockKeyboardActionResolver.action(
                keyCode: BlockSelectionCancelKeyboardResolver.escapeKeyCode,
                modifiers: [],
                hasSelection: true
            ),
            .cancelSelection
        )
        XCTAssertNil(
            TableBlockKeyboardActionResolver.action(
                keyCode: BlockKeyboardShortcutResolver.downArrowKeyCode,
                modifiers: [.shift],
                hasSelection: true
            )
        )
        XCTAssertNil(
            TableBlockKeyboardActionResolver.action(
                keyCode: TableBlockKeyboardActionResolver.deleteBackwardKeyCode,
                modifiers: [],
                hasSelection: false
            )
        )
    }

    func testIOSTableBlockKeyboardActionResolverMovesFocusAndDeletesSelection() {
        XCTAssertEqual(
            IOSTableBlockKeyboardActionResolver.action(
                input: IOSEditorKeyboardShortcutActionResolver.upArrowInput,
                modifiers: [],
                hasSelection: true
            ),
            .moveFocus(.previous)
        )
        XCTAssertEqual(
            IOSTableBlockKeyboardActionResolver.action(
                input: IOSEditorKeyboardShortcutActionResolver.downArrowInput,
                modifiers: [],
                hasSelection: true
            ),
            .moveFocus(.next)
        )
        XCTAssertEqual(
            IOSTableBlockKeyboardActionResolver.action(
                input: IOSTableBlockKeyboardActionResolver.deleteBackwardInput,
                modifiers: [],
                hasSelection: true
            ),
            .deleteSelection
        )
        XCTAssertEqual(
            IOSTableBlockKeyboardActionResolver.action(
                input: IOSTableBlockKeyboardActionResolver.escapeInput,
                modifiers: [],
                hasSelection: true
            ),
            .cancelSelection
        )
        XCTAssertNil(
            IOSTableBlockKeyboardActionResolver.action(
                input: IOSEditorKeyboardShortcutActionResolver.downArrowInput,
                modifiers: [.shift],
                hasSelection: true
            )
        )
        XCTAssertNil(
            IOSTableBlockKeyboardActionResolver.action(
                input: IOSTableBlockKeyboardActionResolver.deleteBackwardInput,
                modifiers: [],
                hasSelection: false
            )
        )
    }

    func testBlockKeyboardFocusResolverTargetsAdjacentBlocksInDocumentOrder() {
        let blocks = [
            BlockSnapshot(
                id: "heading",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "a",
                type: .heading1,
                textPlain: "Heading"
            ),
            BlockSnapshot(
                id: "divider",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "b",
                type: .divider,
                textPlain: ""
            ),
            BlockSnapshot(
                id: "paragraph",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "c",
                type: .paragraph,
                textPlain: "Paragraph"
            )
        ]

        XCTAssertEqual(
            BlockKeyboardFocusResolver.target(
                currentBlockID: "paragraph",
                direction: .previous,
                blocks: blocks
            ),
            BlockKeyboardFocusTarget(
                blockID: "divider",
                selection: EditorTextSelection(blockID: "divider", location: 0, length: 0)
            )
        )
        XCTAssertEqual(
            BlockKeyboardFocusResolver.target(
                currentBlockID: "divider",
                direction: .previous,
                blocks: blocks
            ),
            BlockKeyboardFocusTarget(
                blockID: "heading",
                selection: EditorTextSelection(
                    blockID: "heading",
                    location: ("Heading" as NSString).length,
                    length: 0
                )
            )
        )
        XCTAssertEqual(
            BlockKeyboardFocusResolver.target(
                currentBlockID: "heading",
                direction: .next,
                blocks: blocks
            ),
            BlockKeyboardFocusTarget(
                blockID: "divider",
                selection: EditorTextSelection(blockID: "divider", location: 0, length: 0)
            )
        )
        XCTAssertEqual(
            BlockKeyboardFocusResolver.target(
                currentBlockID: "divider",
                direction: .next,
                blocks: blocks
            ),
            BlockKeyboardFocusTarget(
                blockID: "paragraph",
                selection: EditorTextSelection(
                    blockID: "paragraph",
                    location: 0,
                    length: 0
                )
            )
        )
        XCTAssertNil(
            BlockKeyboardFocusResolver.target(
                currentBlockID: "heading",
                direction: .previous,
                blocks: blocks
            )
        )
        XCTAssertNil(
            BlockKeyboardFocusResolver.target(
                currentBlockID: "paragraph",
                direction: .next,
                blocks: blocks
            )
        )
    }

    func testBlockKeyboardFocusResolverTargetsAdjacentStructuredBlocksForSelectionNavigation() {
        let blocks = [
            BlockSnapshot(
                id: "paragraph",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "a",
                type: .paragraph,
                textPlain: "Paragraph"
            ),
            BlockSnapshot(
                id: "table",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "b",
                type: .table,
                textPlain: "| A |\n| --- |"
            ),
            BlockSnapshot(
                id: "page-reference",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "c",
                type: .pageReference,
                textPlain: "Specs"
            )
        ]

        XCTAssertEqual(
            BlockKeyboardFocusResolver.target(
                currentBlockID: "paragraph",
                direction: .next,
                blocks: blocks
            ),
            BlockKeyboardFocusTarget(
                blockID: "table",
                selection: EditorTextSelection(blockID: "table", location: 0, length: 0)
            )
        )
        XCTAssertEqual(
            BlockKeyboardFocusResolver.target(
                currentBlockID: "table",
                direction: .next,
                blocks: blocks
            ),
            BlockKeyboardFocusTarget(
                blockID: "page-reference",
                selection: EditorTextSelection(blockID: "page-reference", location: 0, length: 0)
            )
        )
        XCTAssertEqual(
            BlockKeyboardFocusResolver.target(
                currentBlockID: "page-reference",
                direction: .previous,
                blocks: blocks
            ),
            BlockKeyboardFocusTarget(
                blockID: "table",
                selection: EditorTextSelection(blockID: "table", location: 0, length: 0)
            )
        )
    }

    func testQuoteBlockChromeDescriptorExposesSemanticContainer() {
        let block = BlockSnapshot(
            id: "quote-1",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "a",
            type: .quote,
            textPlain: "Quoted text"
        )

        let descriptor = QuoteBlockChromeDescriptor(block: block)

        XCTAssertEqual(descriptor.accessibilityLabel, "Quote block")
        XCTAssertEqual(descriptor.accessibilityValue, "Quoted text")
        XCTAssertEqual(descriptor.accessibilityIdentifier, "editor.quote.quote-1")
    }

    func testListBlockChromeDescriptorExposesSemanticContainersAndMarkers() {
        let unorderedBlock = BlockSnapshot(
            id: "unordered-1",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "a",
            type: .unorderedListItem,
            textPlain: "Bulleted text"
        )
        let orderedBlock = BlockSnapshot(
            id: "ordered-3",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "b",
            type: .orderedListItem,
            textPlain: "Numbered text"
        )

        let unorderedDescriptor = ListBlockChromeDescriptor(block: unorderedBlock, ordinal: nil)
        let orderedDescriptor = ListBlockChromeDescriptor(block: orderedBlock, ordinal: 3)

        XCTAssertEqual(unorderedDescriptor.marker, "•")
        XCTAssertEqual(unorderedDescriptor.accessibilityLabel, "Bulleted list block")
        XCTAssertEqual(unorderedDescriptor.accessibilityValue, "Bulleted text")
        XCTAssertEqual(unorderedDescriptor.accessibilityIdentifier, "editor.unordered-list.unordered-1")

        XCTAssertEqual(orderedDescriptor.marker, "3.")
        XCTAssertEqual(orderedDescriptor.accessibilityLabel, "Numbered list block")
        XCTAssertEqual(orderedDescriptor.accessibilityValue, "Numbered text")
        XCTAssertEqual(orderedDescriptor.accessibilityIdentifier, "editor.ordered-list.ordered-3")
    }

    func testOrderedListOrdinalResolverCountsContiguousSameParentItems() {
        let intro = BlockSnapshot(
            id: "intro",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "a",
            type: .paragraph,
            textPlain: "Intro"
        )
        let first = BlockSnapshot(
            id: "ordered-1",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "b",
            type: .orderedListItem,
            textPlain: "First"
        )
        let firstChild = BlockSnapshot(
            id: "ordered-1-child",
            pageID: "page",
            parentBlockID: "ordered-1",
            orderKey: "c",
            type: .paragraph,
            textPlain: "Nested detail"
        )
        let second = BlockSnapshot(
            id: "ordered-2",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "d",
            type: .orderedListItem,
            textPlain: "Second"
        )
        let breakBlock = BlockSnapshot(
            id: "break",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "e",
            type: .paragraph,
            textPlain: "Break"
        )
        let restarted = BlockSnapshot(
            id: "ordered-restart",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "f",
            type: .orderedListItem,
            textPlain: "Restart"
        )
        let blocks = [intro, first, firstChild, second, breakBlock, restarted]

        XCTAssertEqual(ListBlockOrdinalResolver.ordinal(for: first, at: 1, in: blocks), 1)
        XCTAssertEqual(ListBlockOrdinalResolver.ordinal(for: second, at: 3, in: blocks), 2)
        XCTAssertEqual(ListBlockOrdinalResolver.ordinal(for: restarted, at: 5, in: blocks), 1)
        XCTAssertNil(ListBlockOrdinalResolver.ordinal(for: intro, at: 0, in: blocks))
    }

    func testHeadingBlockChromeDescriptorExposesSemanticHeadingLevels() {
        let heading1 = BlockSnapshot(
            id: "heading-1",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "a",
            type: .heading1,
            textPlain: "Main heading"
        )
        let heading2 = BlockSnapshot(
            id: "heading-2",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "b",
            type: .heading2,
            textPlain: ""
        )
        let heading3 = BlockSnapshot(
            id: "heading-3",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "c",
            type: .heading3,
            textPlain: "Detail heading"
        )
        let heading4 = BlockSnapshot(
            id: "heading-4",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "d",
            type: .heading4,
            textPlain: "Fourth heading"
        )
        let heading5 = BlockSnapshot(
            id: "heading-5",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "e",
            type: .heading5,
            textPlain: "Fifth heading"
        )
        let heading6 = BlockSnapshot(
            id: "heading-6",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "f",
            type: .heading6,
            textPlain: "Sixth heading"
        )

        let heading1Descriptor = HeadingBlockChromeDescriptor(block: heading1)
        let heading2Descriptor = HeadingBlockChromeDescriptor(block: heading2)
        let heading3Descriptor = HeadingBlockChromeDescriptor(block: heading3)
        let heading4Descriptor = HeadingBlockChromeDescriptor(block: heading4)
        let heading5Descriptor = HeadingBlockChromeDescriptor(block: heading5)
        let heading6Descriptor = HeadingBlockChromeDescriptor(block: heading6)

        XCTAssertEqual(heading1Descriptor.level, 1)
        XCTAssertEqual(heading1Descriptor.accessibilityLabel, "一级标题块")
        XCTAssertEqual(heading1Descriptor.accessibilityValue, "Main heading")
        XCTAssertEqual(heading1Descriptor.accessibilityIdentifier, "editor.heading1.heading-1")

        XCTAssertEqual(heading2Descriptor.level, 2)
        XCTAssertEqual(heading2Descriptor.accessibilityLabel, "二级标题块")
        XCTAssertEqual(heading2Descriptor.accessibilityValue, "空")
        XCTAssertEqual(heading2Descriptor.accessibilityIdentifier, "editor.heading2.heading-2")

        XCTAssertEqual(heading3Descriptor.level, 3)
        XCTAssertEqual(heading3Descriptor.accessibilityLabel, "三级标题块")
        XCTAssertEqual(heading3Descriptor.accessibilityValue, "Detail heading")
        XCTAssertEqual(heading3Descriptor.accessibilityIdentifier, "editor.heading3.heading-3")

        XCTAssertEqual(heading4Descriptor.level, 4)
        XCTAssertEqual(heading4Descriptor.accessibilityLabel, "四级标题块")
        XCTAssertEqual(heading4Descriptor.accessibilityValue, "Fourth heading")
        XCTAssertEqual(heading4Descriptor.accessibilityIdentifier, "editor.heading4.heading-4")

        XCTAssertEqual(heading5Descriptor.level, 5)
        XCTAssertEqual(heading5Descriptor.accessibilityLabel, "五级标题块")
        XCTAssertEqual(heading5Descriptor.accessibilityValue, "Fifth heading")
        XCTAssertEqual(heading5Descriptor.accessibilityIdentifier, "editor.heading5.heading-5")

        XCTAssertEqual(heading6Descriptor.level, 6)
        XCTAssertEqual(heading6Descriptor.accessibilityLabel, "六级标题块")
        XCTAssertEqual(heading6Descriptor.accessibilityValue, "Sixth heading")
        XCTAssertEqual(heading6Descriptor.accessibilityIdentifier, "editor.heading6.heading-6")
    }

    func testDividerBlockChromeDescriptorExposesSemanticSeparator() {
        let divider = BlockSnapshot(
            id: "divider-1",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "a",
            type: .divider,
            textPlain: ""
        )

        let descriptor = DividerBlockChromeDescriptor(block: divider)

        XCTAssertEqual(descriptor.accessibilityLabel, "分割线块")
        XCTAssertEqual(descriptor.accessibilityValue, "分割线")
        XCTAssertEqual(descriptor.accessibilityIdentifier, "editor.divider.divider-1")
    }

    func testAttachmentBlockChromeDescriptorExposesKindAndPreviewState() {
        let imageBlock = BlockSnapshot(
            id: "image-block",
            pageID: "page",
            parentBlockID: nil,
            orderKey: "a",
            type: .attachmentImage,
            textPlain: "photo.png"
        )
        let imageAttachment = AttachmentSnapshot(
            id: "image-attachment",
            workspaceID: "workspace",
            originalFilename: "photo.png",
            utiType: "public.png",
            byteSize: 12,
            contentHash: "hash",
            localPath: "/tmp/photo.png",
            thumbnailPath: "/tmp/photo-thumb.jpg",
            kind: .image
        )
        let imageAttachmentWithoutThumbnail = AttachmentSnapshot(
            id: "image-attachment",
            workspaceID: "workspace",
            originalFilename: "photo.png",
            utiType: "public.png",
            byteSize: 12,
            contentHash: "hash",
            localPath: "/tmp/photo.png",
            thumbnailPath: nil,
            kind: .image
        )

        let readyDescriptor = AttachmentBlockChromeDescriptor(
            block: imageBlock,
            attachment: imageAttachment,
            generationStatus: .idle
        )
        let generatingDescriptor = AttachmentBlockChromeDescriptor(
            block: imageBlock,
            attachment: imageAttachmentWithoutThumbnail,
            generationStatus: .generating
        )
        let missingDescriptor = AttachmentBlockChromeDescriptor(
            block: imageBlock,
            attachment: nil,
            generationStatus: .idle
        )

        XCTAssertEqual(readyDescriptor.accessibilityLabel, "图片附件：photo.png")
        XCTAssertEqual(readyDescriptor.accessibilityValue, "图片, 预览就绪")
        XCTAssertEqual(readyDescriptor.accessibilityIdentifier, "editor.attachment.image-block")

        XCTAssertEqual(generatingDescriptor.accessibilityLabel, "图片附件：photo.png")
        XCTAssertEqual(generatingDescriptor.accessibilityValue, "图片, 正在生成预览")

        XCTAssertEqual(missingDescriptor.accessibilityLabel, "图片附件：photo.png")
        XCTAssertEqual(missingDescriptor.accessibilityValue, "图片, 附件不可用")
    }

    func testMarkdownInlineFormatKeyboardResolverHandlesBoldItalicStrikethroughAndCodeShortcutsOnly() {
        XCTAssertEqual(
            MarkdownInlineFormatKeyboardResolver.format(input: "b", modifiers: [.command]),
            .bold
        )
        XCTAssertEqual(
            MarkdownInlineFormatKeyboardResolver.format(input: "B", modifiers: [.command]),
            .bold
        )
        XCTAssertEqual(
            MarkdownInlineFormatKeyboardResolver.format(input: "i", modifiers: [.command]),
            .italic
        )
        XCTAssertEqual(
            MarkdownInlineFormatKeyboardResolver.format(input: "x", modifiers: [.command, .shift]),
            .strikethrough
        )
        XCTAssertEqual(
            MarkdownInlineFormatKeyboardResolver.format(input: "e", modifiers: [.command]),
            .code
        )
        XCTAssertEqual(
            MarkdownInlineFormatKeyboardResolver.format(input: "E", modifiers: [.command]),
            .code
        )
        XCTAssertNil(
            MarkdownInlineFormatKeyboardResolver.format(input: "b", modifiers: [.command, .option])
        )
        XCTAssertNil(
            MarkdownInlineFormatKeyboardResolver.format(input: "x", modifiers: [.command])
        )
        XCTAssertNil(
            MarkdownInlineFormatKeyboardResolver.format(input: "e", modifiers: [.command, .shift])
        )
        XCTAssertNil(
            MarkdownInlineFormatKeyboardResolver.format(input: "c", modifiers: [.command])
        )
        XCTAssertNil(
            MarkdownInlineFormatKeyboardResolver.format(input: nil, modifiers: [.command])
        )
    }

    func testMarkdownInlineLinkKeyboardResolverHandlesCommandKOnly() {
        XCTAssertTrue(
            MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(input: "k", modifiers: [.command])
        )
        XCTAssertTrue(
            MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(input: "K", modifiers: [.command])
        )
        XCTAssertFalse(
            MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(input: "k", modifiers: [.command, .option])
        )
        XCTAssertFalse(
            MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(input: "b", modifiers: [.command])
        )
        XCTAssertFalse(
            MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(input: nil, modifiers: [.command])
        )
    }

    func testDiaryPromotionKeyboardResolverHandlesCommandRightBracketOnly() {
        XCTAssertTrue(
            DiaryPromotionKeyboardResolver.requestsPromotion(
                input: "]",
                modifiers: [.command]
            )
        )
        XCTAssertFalse(
            DiaryPromotionKeyboardResolver.requestsPromotion(
                input: "]",
                modifiers: []
            )
        )
        XCTAssertFalse(
            DiaryPromotionKeyboardResolver.requestsPromotion(
                input: "[",
                modifiers: [.command]
            )
        )
    }

    func testBlockPromotionCommandResolverPrefersEditableSelectionBlock() {
        let blocks = [
            BlockSnapshot(
                id: "focused",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "a",
                type: .paragraph,
                textPlain: "Focused"
            ),
            BlockSnapshot(
                id: "selected",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "b",
                type: .heading2,
                textPlain: "Selected"
            )
        ]

        XCTAssertEqual(
            BlockPromotionCommandResolver.promotableBlockID(
                selection: EditorTextSelection(blockID: "selected", location: 0, length: 8),
                focusedBlockID: "focused",
                blocks: blocks
            ),
            "selected"
        )
    }

    func testBlockPromotionCommandResolverFallsBackToFocusedEditableBlock() {
        let blocks = [
            BlockSnapshot(
                id: "focused",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "a",
                type: .paragraph,
                textPlain: "Focused"
            ),
            BlockSnapshot(
                id: "divider",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "b",
                type: .divider,
                textPlain: ""
            )
        ]

        XCTAssertEqual(
            BlockPromotionCommandResolver.promotableBlockID(
                selection: EditorTextSelection(blockID: "divider", location: 0, length: 0),
                focusedBlockID: "focused",
                blocks: blocks
            ),
            "focused"
        )
    }

    func testBlockPromotionCommandResolverRejectsNonEditableBlocks() {
        let blocks = [
            BlockSnapshot(
                id: "divider",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "a",
                type: .divider,
                textPlain: ""
            )
        ]

        XCTAssertNil(
            BlockPromotionCommandResolver.promotableBlockID(
                selection: EditorTextSelection(blockID: "divider", location: 0, length: 0),
                focusedBlockID: "divider",
                blocks: blocks
            )
        )
    }

    func testBlockDragPayloadIndexMatchesResolverForNestedBlocks() {
        let blocks = [
            BlockSnapshot(
                id: "root",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "a",
                type: .paragraph,
                textPlain: "Root"
            ),
            BlockSnapshot(
                id: "child",
                pageID: "page",
                parentBlockID: "root",
                orderKey: "b",
                type: .paragraph,
                textPlain: "Child"
            ),
            BlockSnapshot(
                id: "grandchild",
                pageID: "page",
                parentBlockID: "child",
                orderKey: "c",
                type: .paragraph,
                textPlain: "Grandchild"
            ),
            BlockSnapshot(
                id: "sibling",
                pageID: "page",
                parentBlockID: nil,
                orderKey: "d",
                type: .paragraph,
                textPlain: "Sibling"
            )
        ]

        let index = BlockDragPayloadIndex(blocks: blocks)

        XCTAssertEqual(index.payloadBlockIDs(rootBlockID: "root"), ["root", "child", "grandchild"])
        XCTAssertEqual(index.payloadBlockIDs(rootBlockID: "child"), ["child", "grandchild"])
        XCTAssertEqual(index.payloadBlockIDs(rootBlockID: "sibling"), ["sibling"])
        XCTAssertEqual(
            index.payloadBlockIDs(rootBlockID: "root"),
            BlockDragPayloadResolver.payloadBlockIDs(rootBlockID: "root", blocks: blocks)
        )
    }

    func testBlockDragReorderResolverMovesBeforeDestinationBlock() {
        let visibleBlockIDs = ["a", "b", "c"]

        XCTAssertEqual(
            BlockDragReorderResolver.targetIndex(
                draggedBlockID: "a",
                destinationBlockID: "c",
                visibleBlockIDs: visibleBlockIDs
            ),
            1
        )
        XCTAssertEqual(
            BlockDragReorderResolver.targetIndex(
                draggedBlockID: "c",
                destinationBlockID: "a",
                visibleBlockIDs: visibleBlockIDs
            ),
            0
        )
        XCTAssertNil(
            BlockDragReorderResolver.targetIndex(
                draggedBlockID: "b",
                destinationBlockID: "c",
                visibleBlockIDs: visibleBlockIDs
            )
        )
    }

    func testBlockDragReorderResolverMovesAfterDestinationBlockForChildDrop() {
        let visibleBlockIDs = ["a", "b", "c", "d"]

        XCTAssertEqual(
            BlockDragReorderResolver.targetIndex(
                draggedBlockID: "d",
                destinationBlockID: "b",
                visibleBlockIDs: visibleBlockIDs,
                placement: .childAfter
            ),
            2
        )
        XCTAssertEqual(
            BlockDragReorderResolver.targetIndex(
                draggedBlockID: "a",
                destinationBlockID: "c",
                visibleBlockIDs: visibleBlockIDs,
                placement: .after
            ),
            2
        )
    }

    func testBlockDragReorderResolverAllowsChildDropWhenOnlyIndentationChanges() {
        let visibleBlockIDs = ["parent", "child"]

        XCTAssertEqual(
            BlockDragReorderResolver.targetIndex(
                draggedBlockID: "child",
                destinationBlockID: "parent",
                visibleBlockIDs: visibleBlockIDs,
                placement: .childAfter
            ),
            1
        )
    }

    func testBlockDragReorderResolverAllowsOutdentDropWhenOnlyParentChanges() {
        let visibleBlockIDs = ["parent", "child", "sibling"]

        XCTAssertEqual(
            BlockDragReorderResolver.targetIndex(
                draggedBlockID: "child",
                destinationBlockID: "child",
                visibleBlockIDs: visibleBlockIDs,
                placement: .outdentAfter
            ),
            1
        )
        XCTAssertEqual(
            BlockDragReorderResolver.targetIndex(
                draggedBlockID: "child",
                destinationBlockID: "parent",
                visibleBlockIDs: visibleBlockIDs,
                placement: .outdentAfter
            ),
            1
        )
    }

    func testNotebookHierarchyComputesNestingAndSiblingMovePositions() {
        let notebooks = [
            NotebookSummary(id: "root-a", workspaceID: "workspace", name: "Root A"),
            NotebookSummary(id: "parent", workspaceID: "workspace", name: "Parent"),
            NotebookSummary(
                id: "child-a",
                workspaceID: "workspace",
                parentNotebookID: "parent",
                name: "Child A"
            ),
            NotebookSummary(
                id: "child-b",
                workspaceID: "workspace",
                parentNotebookID: "parent",
                name: "Child B"
            ),
            NotebookSummary(id: "root-b", workspaceID: "workspace", name: "Root B")
        ]

        XCTAssertEqual(
            NotebookHierarchy.nestingLevel(for: notebooks[2], in: notebooks),
            1
        )
        XCTAssertFalse(NotebookHierarchy.canMoveUp(notebook: notebooks[2], in: notebooks))
        XCTAssertTrue(NotebookHierarchy.canMoveDown(notebook: notebooks[2], in: notebooks))
        XCTAssertEqual(
            NotebookHierarchy.siblingTargetIndex(
                for: notebooks[3],
                direction: .up,
                in: notebooks
            ),
            0
        )
        XCTAssertEqual(
            NotebookHierarchy.siblingTargetIndex(
                for: notebooks[1],
                direction: .down,
                in: notebooks
            ),
            2
        )
    }

    func testBlockDragReorderResolverMovesToEndRegion() {
        let visibleBlockIDs = ["a", "b", "c"]

        XCTAssertEqual(
            BlockDragReorderResolver.endTargetIndex(
                draggedBlockID: "a",
                visibleBlockIDs: visibleBlockIDs
            ),
            2
        )
        XCTAssertNil(
            BlockDragReorderResolver.endTargetIndex(
                draggedBlockID: "c",
                visibleBlockIDs: visibleBlockIDs
            )
        )
    }

    func testEditorCanvasRenderMetricsSummarizeRenderWorkload() {
        let metrics = EditorCanvasRenderMetrics(
            pageID: "page-1",
            blockCount: 1_000,
            attachmentCount: 3,
            backlinkCount: 2,
            conflictCount: 1
        )

        XCTAssertEqual(metrics.pageID, "page-1")
        XCTAssertEqual(metrics.blockCount, 1_000)
        XCTAssertEqual(metrics.attachmentCount, 3)
        XCTAssertEqual(metrics.backlinkCount, 2)
        XCTAssertEqual(metrics.conflictCount, 1)
        XCTAssertTrue(metrics.isLargePage)
        XCTAssertTrue(EditorCanvasRenderPolicy.usesLazyBlockStack)
    }

    func testEditorCanvasScrollMetricsTrackVisibleBlocksAndLargePageState() {
        var tracker = EditorCanvasScrollMetricsTracker(
            pageID: "page-1",
            blockCount: 1_000,
            nowNanoseconds: 10_000_000
        )

        tracker.blockAppeared("a", index: 0, nowNanoseconds: 20_000_000)
        tracker.blockAppeared("b", index: 4, nowNanoseconds: 40_000_000)
        tracker.blockAppeared("b", index: 4, nowNanoseconds: 60_000_000)
        tracker.blockDisappeared("a", nowNanoseconds: 80_000_000)

        XCTAssertEqual(
            tracker.metrics,
            EditorCanvasScrollMetrics(
                pageID: "page-1",
                blockCount: 1_000,
                visibleBlockCount: 1,
                peakVisibleBlockCount: 2,
                firstVisibleBlockIndex: 4,
                lastVisibleBlockIndex: 4,
                peakLastVisibleBlockIndex: 4,
                peakVisibleBlockIndexSpan: 5,
                scrollLifetimeMilliseconds: 70,
                blockAppearanceCount: 2,
                blockDisappearanceCount: 1
            )
        )
        XCTAssertTrue(tracker.metrics.isLargePage)
    }

    func testEditorCanvasScrollMetricsCaptureVisibleIndexWindow() {
        var tracker = EditorCanvasScrollMetricsTracker(pageID: "page-1", blockCount: 1_000)

        tracker.blockAppeared("a", index: 12)
        tracker.blockAppeared("b", index: 13)
        tracker.blockAppeared("c", index: 20)

        XCTAssertEqual(tracker.metrics.firstVisibleBlockIndex, 12)
        XCTAssertEqual(tracker.metrics.lastVisibleBlockIndex, 20)
        XCTAssertEqual(tracker.metrics.visibleBlockIndexSpan, 9)
        XCTAssertEqual(tracker.metrics.peakVisibleBlockIndexSpan, 9)

        tracker.blockDisappeared("c")

        XCTAssertEqual(tracker.metrics.firstVisibleBlockIndex, 12)
        XCTAssertEqual(tracker.metrics.lastVisibleBlockIndex, 13)
        XCTAssertEqual(tracker.metrics.visibleBlockIndexSpan, 2)
        XCTAssertEqual(tracker.metrics.peakVisibleBlockIndexSpan, 9)
    }

    func testEditorCanvasScrollMetricsCaptureLifecycleChurnSummary() {
        var tracker = EditorCanvasScrollMetricsTracker(
            pageID: "page-1",
            blockCount: 760,
            nowNanoseconds: 1_000_000_000
        )

        tracker.blockAppeared("a", index: 0, nowNanoseconds: 1_010_000_000)
        tracker.blockAppeared("b", index: 79, nowNanoseconds: 1_050_000_000)
        tracker.blockDisappeared("a", nowNanoseconds: 1_100_000_000)

        let metrics = tracker.metrics
        XCTAssertEqual(metrics.scrollLifetimeMilliseconds, 100)
        XCTAssertEqual(metrics.blockAppearanceCount, 2)
        XCTAssertEqual(metrics.blockDisappearanceCount, 1)
        XCTAssertEqual(metrics.visibleBlockChurnCount, 3)
        XCTAssertTrue(metrics.runtimeSummary.contains("scroll_lifetime_ms=100.000"))
        XCTAssertTrue(metrics.runtimeSummary.contains("block_appearance_count=2"))
        XCTAssertTrue(metrics.runtimeSummary.contains("block_disappearance_count=1"))
        XCTAssertTrue(metrics.runtimeSummary.contains("visible_block_churn_count=3"))
    }

    func testEditorCanvasScrollMetricsTracksFurthestVisibleBlockWithoutDuplicateChurn() {
        var tracker = EditorCanvasScrollMetricsTracker(
            pageID: "page-1",
            blockCount: 760,
            nowNanoseconds: 1_000_000_000
        )

        tracker.blockAppeared("a", index: 0, nowNanoseconds: 1_010_000_000)
        tracker.blockAppeared("b", index: 79, nowNanoseconds: 1_020_000_000)
        tracker.blockAppeared("b", index: 79, nowNanoseconds: 1_030_000_000)
        tracker.blockDisappeared("b", nowNanoseconds: 1_040_000_000)

        let metrics = tracker.metrics
        XCTAssertEqual(metrics.blockAppearanceCount, 2)
        XCTAssertEqual(metrics.blockDisappearanceCount, 1)
        XCTAssertEqual(metrics.visibleBlockChurnCount, 3)
        XCTAssertTrue(metrics.runtimeSummary.contains("peak_last_visible_block_index=79"))
    }

    private func block(
        id: String,
        type: BlockType,
        text: String,
        taskItemIsCompleted: Bool = false
    ) -> BlockSnapshot {
        BlockSnapshot(
            id: id,
            pageID: "page",
            parentBlockID: nil,
            orderKey: id,
            type: type,
            textPlain: text,
            taskItemIsCompleted: taskItemIsCompleted
        )
    }
}
