import SwiftUI

enum BlockKeyboardMoveDirection: Equatable, Sendable {
    case up
    case down
}

enum BlockKeyboardIndentationDirection: Equatable, Sendable {
    case indent
    case outdent
}

enum BlockKeyboardFocusDirection: Equatable, Sendable {
    case previous
    case next

    var debugName: String {
        switch self {
        case .previous:
            return "previous"
        case .next:
            return "next"
        }
    }
}

struct BlockKeyboardFocusTarget: Equatable, Sendable {
    let blockID: String
    let selection: EditorTextSelection
}

enum BlockKeyboardShortcutModifier: Equatable, Hashable, Sendable {
    case command
    case option
    case shift
    case control
}

enum BlockKeyboardShortcutResolver {
    static let upArrowKeyCode: UInt16 = 126
    static let downArrowKeyCode: UInt16 = 125
    static let returnKeyCode: UInt16 = 36
    static let tabKeyCode: UInt16 = 48

    static func moveDirection(
        keyCode: UInt16,
        modifiers: Set<BlockKeyboardShortcutModifier>
    ) -> BlockKeyboardMoveDirection? {
        guard modifiers.contains(.command),
              modifiers.contains(.option) else {
            return nil
        }

        switch keyCode {
        case upArrowKeyCode:
            return .up
        case downArrowKeyCode:
            return .down
        default:
            return nil
        }
    }

    static func insertsBlockAfter(
        keyCode: UInt16,
        modifiers: Set<BlockKeyboardShortcutModifier>
    ) -> Bool {
        keyCode == returnKeyCode && modifiers.isEmpty
    }

    static func indentationDirection(
        keyCode: UInt16,
        modifiers: Set<BlockKeyboardShortcutModifier>
    ) -> BlockKeyboardIndentationDirection? {
        guard keyCode == tabKeyCode else {
            return nil
        }

        if modifiers.isEmpty {
            return .indent
        }
        if modifiers == [.shift] {
            return .outdent
        }
        return nil
    }
}

enum MarkdownInlineFormatKeyboardResolver {
    static func format(
        input: String?,
        modifiers: Set<BlockKeyboardShortcutModifier>
    ) -> MarkdownInlineFormat? {
        guard let input = input?.lowercased() else {
            return nil
        }

        if modifiers == [.command], input == "b" {
            return .bold
        }
        if modifiers == [.command], input == "i" {
            return .italic
        }
        if modifiers == [.command, .shift], input == "x" {
            return .strikethrough
        }
        if modifiers == [.command], input == "e" {
            return .code
        }
        return nil
    }
}

enum MarkdownInlineLinkKeyboardResolver {
    static func requestsLinkInsertion(
        input: String?,
        modifiers: Set<BlockKeyboardShortcutModifier>
    ) -> Bool {
        guard modifiers == [.command],
              let input = input?.lowercased() else {
            return false
        }

        return input == "k"
    }
}

enum BlockKeyboardFocusResolver {
    static func focusDirection(
        keyCode: UInt16,
        modifiers: Set<BlockKeyboardShortcutModifier>,
        selectedRange: NSRange,
        text: String
    ) -> BlockKeyboardFocusDirection? {
        guard modifiers.isEmpty,
              selectedRange.length == 0 else {
            return nil
        }

        let textLength = (text as NSString).length
        switch keyCode {
        case BlockKeyboardShortcutResolver.upArrowKeyCode where selectedRange.location == 0:
            return .previous
        case BlockKeyboardShortcutResolver.downArrowKeyCode where selectedRange.location == textLength:
            return .next
        default:
            return nil
        }
    }

    static func target(
        currentBlockID: String,
        direction: BlockKeyboardFocusDirection,
        blocks: [BlockSnapshot]
    ) -> BlockKeyboardFocusTarget? {
        guard let currentIndex = blocks.firstIndex(where: { $0.id == currentBlockID }) else {
            return nil
        }

        let candidates: [BlockSnapshot]
        switch direction {
        case .previous:
            candidates = Array(blocks[..<currentIndex].reversed())
        case .next:
            candidates = Array(blocks[(currentIndex + 1)...])
        }

        guard let targetBlock = candidates.first(where: { $0.type.isTextEditable }) else {
            return nil
        }

        let location: Int
        switch direction {
        case .previous:
            location = (targetBlock.textPlain as NSString).length
        case .next:
            location = 0
        }

        return BlockKeyboardFocusTarget(
            blockID: targetBlock.id,
            selection: EditorTextSelection(
                blockID: targetBlock.id,
                location: location,
                length: 0
            )
        )
    }
}

enum BlockDragReorderResolver {
    static func targetIndex(
        draggedBlockID: String,
        destinationBlockID: String,
        visibleBlockIDs: [String]
    ) -> Int? {
        guard draggedBlockID != destinationBlockID,
              let currentIndex = visibleBlockIDs.firstIndex(of: draggedBlockID),
              let destinationIndex = visibleBlockIDs.firstIndex(of: destinationBlockID) else {
            return nil
        }

        let adjustedTargetIndex = destinationIndex - (currentIndex < destinationIndex ? 1 : 0)
        guard adjustedTargetIndex != currentIndex else {
            return nil
        }
        return adjustedTargetIndex
    }

    static func endTargetIndex(
        draggedBlockID: String,
        visibleBlockIDs: [String]
    ) -> Int? {
        guard let currentIndex = visibleBlockIDs.firstIndex(of: draggedBlockID) else {
            return nil
        }

        let targetIndex = visibleBlockIDs.count - 1
        guard currentIndex != targetIndex else {
            return nil
        }
        return targetIndex
    }
}

struct NativeTextFocusRequestState {
    private var handledFocusRequestID: UUID?
    private var scheduledFocusRequestID: UUID?

    mutating func beginScheduling(_ focusRequestID: UUID?) -> UUID? {
        guard let focusRequestID,
              handledFocusRequestID != focusRequestID,
              scheduledFocusRequestID != focusRequestID else {
            return nil
        }

        scheduledFocusRequestID = focusRequestID
        return focusRequestID
    }

    mutating func finish(requestID: UUID, didFocus: Bool) {
        if scheduledFocusRequestID == requestID {
            scheduledFocusRequestID = nil
        }

        if didFocus {
            handledFocusRequestID = requestID
        }
    }
}

struct NativeTextModelUpdateGuard {
    private var isApplyingModelText = false

    var shouldForwardTextChange: Bool {
        !isApplyingModelText
    }

    mutating func beginApplyingModelText() {
        isApplyingModelText = true
    }

    mutating func finishApplyingModelText() {
        isApplyingModelText = false
    }
}

enum NativeTextFocusSelection {
    static func range(from selection: EditorTextSelection?, blockID: String, text: String) -> NSRange {
        let textLength = (text as NSString).length
        guard let selection,
              selection.blockID == blockID,
              selection.location >= 0,
              selection.length >= 0,
              selection.location <= textLength,
              selection.length <= textLength - selection.location else {
            return NSRange(location: textLength, length: 0)
        }

        return NSRange(location: selection.location, length: selection.length)
    }
}

struct NativeTextBlockEditor: View {
    static let acceptsInactiveWindowFirstMouse = true

    let blockID: String
    let text: String
    let blockType: BlockType
    @ObservedObject var session: EditorSession
    let lineWrapping: Bool
    let focusRequestID: UUID?
    let focusSelection: EditorTextSelection?
    let onFocusRequestHandled: () -> Void
    let onMoveByKeyboard: (BlockKeyboardMoveDirection) -> Bool
    let onIndentationByKeyboard: (BlockKeyboardIndentationDirection) -> Bool
    let onMoveFocusByKeyboard: (BlockKeyboardFocusDirection) -> Bool
    let onApplyInlineFormatByKeyboard: (MarkdownInlineFormat, EditorTextSelection) -> Bool
    let onInsertLinkByKeyboard: (EditorTextSelection) -> Bool
    let onInsertBlockAfter: (EditorTextSelection) -> Bool
    let onTextChange: (String) -> Void
    @State private var measuredHeight: CGFloat = 0

    init(
        blockID: String,
        text: String,
        blockType: BlockType,
        session: EditorSession,
        lineWrapping: Bool = true,
        focusRequestID: UUID? = nil,
        focusSelection: EditorTextSelection? = nil,
        onFocusRequestHandled: @escaping () -> Void = {},
        onMoveByKeyboard: @escaping (BlockKeyboardMoveDirection) -> Bool = { _ in false },
        onIndentationByKeyboard: @escaping (BlockKeyboardIndentationDirection) -> Bool = { _ in false },
        onMoveFocusByKeyboard: @escaping (BlockKeyboardFocusDirection) -> Bool = { _ in false },
        onApplyInlineFormatByKeyboard: @escaping (MarkdownInlineFormat, EditorTextSelection) -> Bool = { _, _ in false },
        onInsertLinkByKeyboard: @escaping (EditorTextSelection) -> Bool = { _ in false },
        onInsertBlockAfter: @escaping (EditorTextSelection) -> Bool = { _ in false },
        onTextChange: @escaping (String) -> Void
    ) {
        self.blockID = blockID
        self.text = text
        self.blockType = blockType
        self.session = session
        self.lineWrapping = lineWrapping
        self.focusRequestID = focusRequestID
        self.focusSelection = focusSelection
        self.onFocusRequestHandled = onFocusRequestHandled
        self.onMoveByKeyboard = onMoveByKeyboard
        self.onIndentationByKeyboard = onIndentationByKeyboard
        self.onMoveFocusByKeyboard = onMoveFocusByKeyboard
        self.onApplyInlineFormatByKeyboard = onApplyInlineFormatByKeyboard
        self.onInsertLinkByKeyboard = onInsertLinkByKeyboard
        self.onInsertBlockAfter = onInsertBlockAfter
        self.onTextChange = onTextChange
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PlatformNativeTextView(
                blockID: blockID,
                text: text,
                blockType: blockType,
                session: session,
                lineWrapping: lineWrapping,
                focusRequestID: focusRequestID,
                focusSelection: focusSelection,
                onFocusRequestHandled: onFocusRequestHandled,
                onMoveByKeyboard: onMoveByKeyboard,
                onIndentationByKeyboard: onIndentationByKeyboard,
                onMoveFocusByKeyboard: onMoveFocusByKeyboard,
                onApplyInlineFormatByKeyboard: onApplyInlineFormatByKeyboard,
                onInsertLinkByKeyboard: onInsertLinkByKeyboard,
                onInsertBlockAfter: onInsertBlockAfter,
                minimumHeight: minimumHeight,
                onContentHeightChange: updateMeasuredHeight,
                onTextChange: onTextChange
            )

            if showsPlaceholder {
                Text("Start writing...")
                    .font(placeholderFont)
                    .foregroundStyle(.secondary.opacity(0.72))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: effectiveHeight)
    }

    var showsPlaceholder: Bool {
        text.isEmpty && session.focusedBlockID != blockID
    }

    private var placeholderFont: Font {
        switch blockType {
        case .heading1:
            return .title2.weight(.semibold)
        case .heading2:
            return .title3.weight(.semibold)
        case .heading3:
            return .headline
        case .codeBlock, .table:
            return .system(.body, design: .monospaced)
        default:
            return .body
        }
    }

    private var minimumHeight: CGFloat {
        switch blockType {
        case .heading1:
            return 34
        case .heading2:
            return 30
        case .heading3:
            return 28
        case .codeBlock, .table:
            return 28
        default:
            return 24
        }
    }

    private var effectiveHeight: CGFloat {
        max(minimumHeight, measuredHeight)
    }

    private func updateMeasuredHeight(_ height: CGFloat) {
        let clampedHeight = max(minimumHeight, ceil(height))
        guard abs(measuredHeight - clampedHeight) > 0.5 else {
            return
        }
        measuredHeight = clampedHeight
    }
}

#if os(macOS)
import AppKit

enum NativeTextMouseFocusPolicy {
    static let makesWindowKeyBeforeFirstResponder = true
}

enum MacWindowVisibilityPolicy {
    static func shouldRequestMainWindow(hasVisibleWindows: Bool) -> Bool {
        !hasVisibleWindows
    }
}

private struct PlatformNativeTextView: NSViewRepresentable {
    let blockID: String
    let text: String
    let blockType: BlockType
    @ObservedObject var session: EditorSession
    let lineWrapping: Bool
    let focusRequestID: UUID?
    let focusSelection: EditorTextSelection?
    let onFocusRequestHandled: () -> Void
    let onMoveByKeyboard: (BlockKeyboardMoveDirection) -> Bool
    let onIndentationByKeyboard: (BlockKeyboardIndentationDirection) -> Bool
    let onMoveFocusByKeyboard: (BlockKeyboardFocusDirection) -> Bool
    let onApplyInlineFormatByKeyboard: (MarkdownInlineFormat, EditorTextSelection) -> Bool
    let onInsertLinkByKeyboard: (EditorTextSelection) -> Bool
    let onInsertBlockAfter: (EditorTextSelection) -> Bool
    let minimumHeight: CGFloat
    let onContentHeightChange: (CGFloat) -> Void
    let onTextChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextView {
        let textContentStorage = NSTextContentStorage()
        let textLayoutManager = NSTextLayoutManager()
        let textContainer = NSTextContainer(
            size: CGSize(
                width: lineWrapping ? 0 : CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        textContainer.widthTracksTextView = lineWrapping
        textContainer.lineFragmentPadding = 0
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textLayoutManager.textContainer = textContainer
        context.coordinator.textContentStorage = textContentStorage
        context.coordinator.textLayoutManager = textLayoutManager

        let textView = EditorNSTextView(frame: .zero, textContainer: textContainer)
        textView.onMouseDown = {
            EditorLog.focus.debug("editor_native_text_mouse_down block_id=\(blockID, privacy: .public)")
        }
        textView.onMouseFocusResult = { didFocus in
            EditorLog.focus.debug(
                "editor_native_text_mouse_focus block_id=\(blockID, privacy: .public) did_focus=\(didFocus, privacy: .public)"
            )
        }
        textView.onKeyboardMove = onMoveByKeyboard
        textView.onKeyboardIndentation = onIndentationByKeyboard
        textView.onKeyboardFocusMove = onMoveFocusByKeyboard
        textView.onKeyboardInlineFormat = { format, selectedRange in
            onApplyInlineFormatByKeyboard(
                format,
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                )
            )
        }
        textView.onKeyboardLinkInsertion = { selectedRange in
            onInsertLinkByKeyboard(
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                )
            )
        }
        textView.onInsertBlockAfter = { selectedRange in
            onInsertBlockAfter(
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                )
            )
        }
        textView.setAccessibilityIdentifier("editor.text.\(blockID)")
        textView.delegate = context.coordinator
        context.coordinator.applyModelText(text, to: textView)
        textView.font = nsFont
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isHorizontallyResizable = !lineWrapping
        textView.isVerticallyResizable = true
        textView.textContainerInset = .zero
        textView.autoresizingMask = [.width]
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        configureLineWrapping(textView: textView)
        context.coordinator.scheduleHeightMeasurement(for: textView)
        if textView.textLayoutManager == nil {
            EditorLog.input.error("textkit2_unavailable platform=macOS block_id=\(blockID, privacy: .public)")
        }
        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        context.coordinator.parent = self
        if let textView = textView as? EditorNSTextView {
            textView.onMouseDown = {
                EditorLog.focus.debug("editor_native_text_mouse_down block_id=\(blockID, privacy: .public)")
            }
            textView.onMouseFocusResult = { didFocus in
                EditorLog.focus.debug(
                    "editor_native_text_mouse_focus block_id=\(blockID, privacy: .public) did_focus=\(didFocus, privacy: .public)"
                )
            }
            textView.onKeyboardMove = onMoveByKeyboard
            textView.onKeyboardIndentation = onIndentationByKeyboard
            textView.onKeyboardFocusMove = onMoveFocusByKeyboard
            textView.onKeyboardInlineFormat = { format, selectedRange in
                onApplyInlineFormatByKeyboard(
                    format,
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    )
                )
            }
            textView.onKeyboardLinkInsertion = { selectedRange in
                onInsertLinkByKeyboard(
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    )
                )
            }
            textView.onInsertBlockAfter = { selectedRange in
                onInsertBlockAfter(
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    )
                )
            }
        }
        if textView.string != text {
            context.coordinator.applyModelText(text, to: textView)
        }
        textView.font = nsFont
        configureLineWrapping(textView: textView)
        context.coordinator.applyInlineMarkdownStyles(to: textView)
        context.coordinator.scheduleHeightMeasurement(for: textView)
        context.coordinator.handleFocusRequestIfNeeded(textView: textView)
    }

    private func configureLineWrapping(textView: NSTextView) {
        textView.textContainer?.widthTracksTextView = lineWrapping
        textView.isHorizontallyResizable = !lineWrapping
        textView.textContainer?.containerSize = CGSize(
            width: lineWrapping ? textView.bounds.width : CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
    }

    private var nsFont: NSFont {
        switch blockType {
        case .heading1:
            return .systemFont(ofSize: 22, weight: .semibold)
        case .heading2:
            return .systemFont(ofSize: 19, weight: .semibold)
        case .heading3:
            return .systemFont(ofSize: 16, weight: .semibold)
        case .codeBlock, .table:
            return .monospacedSystemFont(ofSize: 14, weight: .regular)
        default:
            return .systemFont(ofSize: 15, weight: .regular)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlatformNativeTextView
        var textContentStorage: NSTextContentStorage?
        var textLayoutManager: NSTextLayoutManager?
        private var focusRequestState = NativeTextFocusRequestState()
        private var modelUpdateGuard = NativeTextModelUpdateGuard()

        init(parent: PlatformNativeTextView) {
            self.parent = parent
        }

        func applyModelText(_ text: String, to textView: NSTextView) {
            modelUpdateGuard.beginApplyingModelText()
            defer {
                modelUpdateGuard.finishApplyingModelText()
            }
            textView.string = text
            applyInlineMarkdownStyles(to: textView)
            scheduleHeightMeasurement(for: textView)
        }

        func applyInlineMarkdownStyles(to textView: NSTextView) {
            guard parent.blockType.supportsInlineMarkdownStyling else {
                return
            }
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            guard fullRange.length > 0,
                  let textStorage = textView.textStorage else {
                return
            }

            let selectedRange = textView.selectedRange()
            modelUpdateGuard.beginApplyingModelText()
            defer {
                modelUpdateGuard.finishApplyingModelText()
            }

            textStorage.beginEditing()
            textStorage.setAttributes(baseTextAttributes, range: fullRange)
            for run in MarkdownInlineStyleScanner.runs(in: textView.string, includingSyntaxMarkers: true)
                where NSMaxRange(run.range) <= fullRange.length {
                textStorage.addAttributes(attributes(for: run.kind), range: run.range)
            }
            textStorage.endEditing()
            textView.typingAttributes = baseTextAttributes
            if NSMaxRange(selectedRange) <= fullRange.length {
                textView.setSelectedRange(selectedRange)
            }
        }

        private var baseTextAttributes: [NSAttributedString.Key: Any] {
            [
                .font: parent.nsFont,
                .foregroundColor: NSColor.labelColor
            ]
        }

        private func attributes(for kind: MarkdownInlineStyleKind) -> [NSAttributedString.Key: Any] {
            switch kind {
            case .syntax:
                return [.foregroundColor: NSColor.secondaryLabelColor]
            case .bold:
                return [.font: boldFont]
            case .italic:
                return [.font: italicFont]
            case .strikethrough:
                return [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
            case .code:
                return [
                    .font: NSFont.monospacedSystemFont(ofSize: parent.nsFont.pointSize, weight: .regular),
                    .backgroundColor: NSColor.textBackgroundColor.withAlphaComponent(0.86)
                ]
            case .link:
                return [
                    .foregroundColor: NSColor.linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            }
        }

        private var boldFont: NSFont {
            NSFontManager.shared.convert(parent.nsFont, toHaveTrait: .boldFontMask)
        }

        private var italicFont: NSFont {
            NSFontManager.shared.convert(parent.nsFont, toHaveTrait: .italicFontMask)
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.session.beginEditing(blockID: parent.blockID, reason: .userTap)
            if let textView = notification.object as? NSTextView {
                updateSessionSelection(textView: textView)
                updateSessionComposition(textView: textView)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard modelUpdateGuard.shouldForwardTextChange else {
                return
            }
            guard let textView = notification.object as? NSTextView else {
                return
            }
            parent.session.updateDraft(blockID: parent.blockID, text: textView.string)
            updateSessionSelection(textView: textView)
            updateSessionComposition(textView: textView)
            parent.onTextChange(textView.string)
            applyInlineMarkdownStyles(to: textView)
            scheduleHeightMeasurement(for: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard modelUpdateGuard.shouldForwardTextChange else {
                return
            }
            guard let textView = notification.object as? NSTextView else {
                return
            }
            updateSessionSelection(textView: textView)
            updateSessionComposition(textView: textView)
        }

        func textDidEndEditing(_ notification: Notification) {
            _ = parent.session.commitDraft(blockID: parent.blockID)
            parent.session.endEditing(blockID: parent.blockID)
        }

        func handleFocusRequestIfNeeded(textView: NSTextView) {
            guard let focusRequestID = focusRequestState.beginScheduling(parent.focusRequestID) else {
                return
            }

            scheduleFocusAttempt(
                textView: textView,
                focusRequestID: focusRequestID,
                remainingAttempts: 8
            )
        }

        private func scheduleFocusAttempt(
            textView: NSTextView,
            focusRequestID: UUID,
            remainingAttempts: Int
        ) {
            DispatchQueue.main.asyncAfter(deadline: .now() + focusDelay(for: remainingAttempts)) { [weak textView, weak self] in
                guard let textView, let self else {
                    return
                }

                if self.performFocus(textView: textView) {
                    self.focusRequestState.finish(requestID: focusRequestID, didFocus: true)
                    self.parent.session.beginEditing(blockID: self.parent.blockID, reason: .programmatic)
                    self.parent.onFocusRequestHandled()
                    return
                }

                guard remainingAttempts > 0 else {
                    self.focusRequestState.finish(requestID: focusRequestID, didFocus: false)
                    EditorLog.focus.debug(
                        "editor_focus_request_retry_exhausted block_id=\(self.parent.blockID, privacy: .public)"
                    )
                    return
                }

                self.scheduleFocusAttempt(
                    textView: textView,
                    focusRequestID: focusRequestID,
                    remainingAttempts: remainingAttempts - 1
                )
            }
        }

        private func performFocus(textView: NSTextView) -> Bool {
            guard let window = textView.window else {
                return false
            }

            window.makeKeyAndOrderFront(nil)
            guard window.makeFirstResponder(textView) else {
                return false
            }

            textView.setSelectedRange(
                NativeTextFocusSelection.range(
                    from: parent.focusSelection,
                    blockID: parent.blockID,
                    text: textView.string
                )
            )
            return true
        }

        private func updateSessionSelection(textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            parent.session.updateSelection(
                blockID: parent.blockID,
                location: selectedRange.location,
                length: selectedRange.length
            )
        }

        private func updateSessionComposition(textView: NSTextView) {
            parent.session.updateComposition(
                blockID: parent.blockID,
                isComposing: textView.hasMarkedText()
            )
        }

        func scheduleHeightMeasurement(for textView: NSTextView) {
            DispatchQueue.main.async { [weak textView, weak self] in
                guard let textView, let self else {
                    return
                }
                self.parent.onContentHeightChange(self.measuredHeight(for: textView))
            }
        }

        private func measuredHeight(for textView: NSTextView) -> CGFloat {
            let width = parent.lineWrapping ? max(textView.bounds.width, 320) : 10_000
            let boundingRect = textView.attributedString().boundingRect(
                with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            let verticalInset = textView.textContainerInset.height * 2
            return max(parent.minimumHeight, ceil(boundingRect.height + verticalInset + 2))
        }

        private func focusDelay(for remainingAttempts: Int) -> DispatchTimeInterval {
            remainingAttempts == 8 ? .milliseconds(0) : .milliseconds(35)
        }
    }
}

private final class EditorNSTextView: NSTextView {
    var onMouseDown: (() -> Void)?
    var onMouseFocusResult: ((Bool) -> Void)?
    var onKeyboardMove: ((BlockKeyboardMoveDirection) -> Bool)?
    var onKeyboardIndentation: ((BlockKeyboardIndentationDirection) -> Bool)?
    var onKeyboardFocusMove: ((BlockKeyboardFocusDirection) -> Bool)?
    var onKeyboardInlineFormat: ((MarkdownInlineFormat, NSRange) -> Bool)?
    var onKeyboardLinkInsertion: ((NSRange) -> Bool)?
    var onInsertBlockAfter: ((NSRange) -> Bool)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        NativeTextBlockEditor.acceptsInactiveWindowFirstMouse
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        if let window {
            if NativeTextMouseFocusPolicy.makesWindowKeyBeforeFirstResponder {
                window.makeKeyAndOrderFront(nil)
            }
            if window.firstResponder !== self {
                window.makeFirstResponder(self)
            }
        }
        super.mouseDown(with: event)
        onMouseFocusResult?(window?.firstResponder === self)
    }

    override func keyDown(with event: NSEvent) {
        if let direction = BlockKeyboardShortcutResolver.moveDirection(
            keyCode: event.keyCode,
            modifiers: event.blockKeyboardShortcutModifiers
        ), onKeyboardMove?(direction) == true {
            return
        }

        if let direction = BlockKeyboardShortcutResolver.indentationDirection(
            keyCode: event.keyCode,
            modifiers: event.blockKeyboardShortcutModifiers
        ), onKeyboardIndentation?(direction) == true {
            return
        }

        if let format = MarkdownInlineFormatKeyboardResolver.format(
            input: event.charactersIgnoringModifiers,
            modifiers: event.blockKeyboardShortcutModifiers
        ), onKeyboardInlineFormat?(format, selectedRange()) == true {
            return
        }

        if MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(
            input: event.charactersIgnoringModifiers,
            modifiers: event.blockKeyboardShortcutModifiers
        ), onKeyboardLinkInsertion?(selectedRange()) == true {
            return
        }

        if let direction = BlockKeyboardFocusResolver.focusDirection(
            keyCode: event.keyCode,
            modifiers: event.blockKeyboardShortcutModifiers,
            selectedRange: selectedRange(),
            text: string
        ), onKeyboardFocusMove?(direction) == true {
            return
        }

        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let format = MarkdownInlineFormatKeyboardResolver.format(
            input: event.charactersIgnoringModifiers,
            modifiers: event.blockKeyboardShortcutModifiers
        ), onKeyboardInlineFormat?(format, selectedRange()) == true {
            return true
        }

        if MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(
            input: event.charactersIgnoringModifiers,
            modifiers: event.blockKeyboardShortcutModifiers
        ), onKeyboardLinkInsertion?(selectedRange()) == true {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func orderFrontLinkPanel(_ sender: Any?) {
        if onKeyboardLinkInsertion?(selectedRange()) == true {
            return
        }

        super.orderFrontLinkPanel(sender)
    }

    override func insertNewline(_ sender: Any?) {
        if onInsertBlockAfter?(selectedRange()) == true {
            return
        }

        super.insertNewline(sender)
    }
}

extension NSEvent {
    var blockKeyboardShortcutModifiers: Set<BlockKeyboardShortcutModifier> {
        var modifiers: Set<BlockKeyboardShortcutModifier> = []
        if modifierFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if modifierFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if modifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if modifierFlags.contains(.control) {
            modifiers.insert(.control)
        }
        return modifiers
    }
}
#elseif os(iOS)
import UIKit

private struct PlatformNativeTextView: UIViewRepresentable {
    let blockID: String
    let text: String
    let blockType: BlockType
    @ObservedObject var session: EditorSession
    let lineWrapping: Bool
    let focusRequestID: UUID?
    let focusSelection: EditorTextSelection?
    let onFocusRequestHandled: () -> Void
    let onMoveByKeyboard: (BlockKeyboardMoveDirection) -> Bool
    let onIndentationByKeyboard: (BlockKeyboardIndentationDirection) -> Bool
    let onMoveFocusByKeyboard: (BlockKeyboardFocusDirection) -> Bool
    let onApplyInlineFormatByKeyboard: (MarkdownInlineFormat, EditorTextSelection) -> Bool
    let onInsertLinkByKeyboard: (EditorTextSelection) -> Bool
    let onInsertBlockAfter: (EditorTextSelection) -> Bool
    let minimumHeight: CGFloat
    let onContentHeightChange: (CGFloat) -> Void
    let onTextChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = EditorUITextView(usingTextLayoutManager: true)
        textView.onKeyboardMove = onMoveByKeyboard
        textView.onKeyboardIndentation = onIndentationByKeyboard
        textView.onKeyboardFocusMove = onMoveFocusByKeyboard
        textView.onKeyboardInlineFormat = { format, selectedRange in
            onApplyInlineFormatByKeyboard(
                format,
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                )
            )
        }
        textView.onKeyboardLinkInsertion = { selectedRange in
            onInsertLinkByKeyboard(
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                )
            )
        }
        textView.onInsertBlockAfter = { selectedRange in
            onInsertBlockAfter(
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                )
            )
        }
        textView.accessibilityIdentifier = "editor.text.\(blockID)"
        textView.delegate = context.coordinator
        context.coordinator.applyModelText(text, to: textView)
        textView.font = uiFont
        textView.textColor = .label
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        configureLineWrapping(textView: textView)
        textView.adjustsFontForContentSizeCategory = true
        context.coordinator.scheduleHeightMeasurement(for: textView)
        if textView.textLayoutManager == nil {
            EditorLog.input.error("textkit2_unavailable platform=iOS block_id=\(blockID, privacy: .public)")
        }
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        if let textView = textView as? EditorUITextView {
            textView.onKeyboardMove = onMoveByKeyboard
            textView.onKeyboardIndentation = onIndentationByKeyboard
            textView.onKeyboardFocusMove = onMoveFocusByKeyboard
            textView.onKeyboardInlineFormat = { format, selectedRange in
                onApplyInlineFormatByKeyboard(
                    format,
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    )
                )
            }
            textView.onKeyboardLinkInsertion = { selectedRange in
                onInsertLinkByKeyboard(
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    )
                )
            }
            textView.onInsertBlockAfter = { selectedRange in
                onInsertBlockAfter(
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    )
                )
            }
        }
        if textView.text != text {
            context.coordinator.applyModelText(text, to: textView)
        }
        textView.font = uiFont
        configureLineWrapping(textView: textView)
        context.coordinator.applyInlineMarkdownStyles(to: textView)
        context.coordinator.scheduleHeightMeasurement(for: textView)
        context.coordinator.handleFocusRequestIfNeeded(textView: textView)
    }

    private func configureLineWrapping(textView: UITextView) {
        textView.textContainer.lineBreakMode = lineWrapping ? .byWordWrapping : .byClipping
    }

    private var uiFont: UIFont {
        switch blockType {
        case .heading1:
            return .preferredFont(forTextStyle: .title2)
        case .heading2:
            return .preferredFont(forTextStyle: .title3)
        case .heading3:
            return .preferredFont(forTextStyle: .headline)
        case .codeBlock, .table:
            return .monospacedSystemFont(ofSize: 15, weight: .regular)
        default:
            return .preferredFont(forTextStyle: .body)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: PlatformNativeTextView
        private var focusRequestState = NativeTextFocusRequestState()
        private var modelUpdateGuard = NativeTextModelUpdateGuard()

        init(parent: PlatformNativeTextView) {
            self.parent = parent
        }

        func applyModelText(_ text: String, to textView: UITextView) {
            modelUpdateGuard.beginApplyingModelText()
            defer {
                modelUpdateGuard.finishApplyingModelText()
            }
            textView.text = text
            applyInlineMarkdownStyles(to: textView)
            scheduleHeightMeasurement(for: textView)
        }

        func applyInlineMarkdownStyles(to textView: UITextView) {
            guard parent.blockType.supportsInlineMarkdownStyling else {
                return
            }
            let fullRange = NSRange(location: 0, length: (textView.text as NSString).length)
            guard fullRange.length > 0 else {
                return
            }

            let selectedRange = textView.selectedRange
            modelUpdateGuard.beginApplyingModelText()
            defer {
                modelUpdateGuard.finishApplyingModelText()
            }

            textView.textStorage.beginEditing()
            textView.textStorage.setAttributes(baseTextAttributes, range: fullRange)
            for run in MarkdownInlineStyleScanner.runs(in: textView.text, includingSyntaxMarkers: true)
                where NSMaxRange(run.range) <= fullRange.length {
                textView.textStorage.addAttributes(attributes(for: run.kind), range: run.range)
            }
            textView.textStorage.endEditing()
            textView.typingAttributes = baseTextAttributes
            if NSMaxRange(selectedRange) <= fullRange.length {
                textView.selectedRange = selectedRange
            }
        }

        private var baseTextAttributes: [NSAttributedString.Key: Any] {
            [
                .font: parent.uiFont,
                .foregroundColor: UIColor.label
            ]
        }

        private func attributes(for kind: MarkdownInlineStyleKind) -> [NSAttributedString.Key: Any] {
            switch kind {
            case .syntax:
                return [.foregroundColor: UIColor.secondaryLabel]
            case .bold:
                return [.font: boldFont]
            case .italic:
                return [.font: italicFont]
            case .strikethrough:
                return [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
            case .code:
                return [
                    .font: UIFont.monospacedSystemFont(ofSize: parent.uiFont.pointSize, weight: .regular),
                    .backgroundColor: UIColor.secondarySystemBackground
                ]
            case .link:
                return [
                    .foregroundColor: UIColor.link,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            }
        }

        private var boldFont: UIFont {
            guard let descriptor = parent.uiFont.fontDescriptor.withSymbolicTraits(.traitBold) else {
                return .boldSystemFont(ofSize: parent.uiFont.pointSize)
            }
            return UIFont(descriptor: descriptor, size: parent.uiFont.pointSize)
        }

        private var italicFont: UIFont {
            guard let descriptor = parent.uiFont.fontDescriptor.withSymbolicTraits(.traitItalic) else {
                return .italicSystemFont(ofSize: parent.uiFont.pointSize)
            }
            return UIFont(descriptor: descriptor, size: parent.uiFont.pointSize)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.session.beginEditing(blockID: parent.blockID, reason: .userTap)
            updateSessionSelection(textView: textView)
            updateSessionComposition(textView: textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            guard modelUpdateGuard.shouldForwardTextChange else {
                return
            }
            parent.session.updateDraft(blockID: parent.blockID, text: textView.text)
            updateSessionSelection(textView: textView)
            updateSessionComposition(textView: textView)
            parent.onTextChange(textView.text)
            applyInlineMarkdownStyles(to: textView)
            scheduleHeightMeasurement(for: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard modelUpdateGuard.shouldForwardTextChange else {
                return
            }
            updateSessionSelection(textView: textView)
            updateSessionComposition(textView: textView)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            guard text == "\n" else {
                return true
            }
            return !parent.onInsertBlockAfter(
                EditorTextSelection(
                    blockID: parent.blockID,
                    location: range.location,
                    length: range.length
                )
            )
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            _ = parent.session.commitDraft(blockID: parent.blockID)
            parent.session.endEditing(blockID: parent.blockID)
        }

        func handleFocusRequestIfNeeded(textView: UITextView) {
            guard let focusRequestID = focusRequestState.beginScheduling(parent.focusRequestID) else {
                return
            }

            scheduleFocusAttempt(
                textView: textView,
                focusRequestID: focusRequestID,
                remainingAttempts: 8
            )
        }

        private func scheduleFocusAttempt(
            textView: UITextView,
            focusRequestID: UUID,
            remainingAttempts: Int
        ) {
            DispatchQueue.main.asyncAfter(deadline: .now() + focusDelay(for: remainingAttempts)) { [weak textView, weak self] in
                guard let textView, let self else {
                    return
                }

                if self.performFocus(textView: textView) {
                    self.focusRequestState.finish(requestID: focusRequestID, didFocus: true)
                    self.parent.session.beginEditing(blockID: self.parent.blockID, reason: .programmatic)
                    self.parent.onFocusRequestHandled()
                    return
                }

                guard remainingAttempts > 0 else {
                    self.focusRequestState.finish(requestID: focusRequestID, didFocus: false)
                    EditorLog.focus.debug(
                        "editor_focus_request_retry_exhausted block_id=\(self.parent.blockID, privacy: .public)"
                    )
                    return
                }

                self.scheduleFocusAttempt(
                    textView: textView,
                    focusRequestID: focusRequestID,
                    remainingAttempts: remainingAttempts - 1
                )
            }
        }

        private func performFocus(textView: UITextView) -> Bool {
            guard textView.window != nil,
                  textView.becomeFirstResponder() else {
                return false
            }

            textView.selectedRange = NativeTextFocusSelection.range(
                from: parent.focusSelection,
                blockID: parent.blockID,
                text: textView.text
            )
            return true
        }

        private func updateSessionSelection(textView: UITextView) {
            parent.session.updateSelection(
                blockID: parent.blockID,
                location: textView.selectedRange.location,
                length: textView.selectedRange.length
            )
        }

        private func updateSessionComposition(textView: UITextView) {
            parent.session.updateComposition(
                blockID: parent.blockID,
                isComposing: textView.markedTextRange != nil
            )
        }

        func scheduleHeightMeasurement(for textView: UITextView) {
            DispatchQueue.main.async { [weak textView, weak self] in
                guard let textView, let self else {
                    return
                }
                self.parent.onContentHeightChange(self.measuredHeight(for: textView))
            }
        }

        private func measuredHeight(for textView: UITextView) -> CGFloat {
            let fallbackWidth = UIScreen.main.bounds.width - 32
            let width = parent.lineWrapping ? max(textView.bounds.width, fallbackWidth) : 10_000
            let fittingSize = textView.sizeThatFits(
                CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            )
            return max(parent.minimumHeight, ceil(fittingSize.height))
        }

        private func focusDelay(for remainingAttempts: Int) -> DispatchTimeInterval {
            remainingAttempts == 8 ? .milliseconds(0) : .milliseconds(35)
        }
    }
}

private final class EditorUITextView: UITextView {
    var onKeyboardMove: ((BlockKeyboardMoveDirection) -> Bool)?
    var onKeyboardIndentation: ((BlockKeyboardIndentationDirection) -> Bool)?
    var onKeyboardFocusMove: ((BlockKeyboardFocusDirection) -> Bool)?
    var onKeyboardInlineFormat: ((MarkdownInlineFormat, NSRange) -> Bool)?
    var onKeyboardLinkInsertion: ((NSRange) -> Bool)?
    var onInsertBlockAfter: ((NSRange) -> Bool)?

    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(
                input: UIKeyCommand.inputUpArrow,
                modifierFlags: [.command, .alternate],
                action: #selector(moveBlockUp)
            ),
            UIKeyCommand(
                input: UIKeyCommand.inputDownArrow,
                modifierFlags: [.command, .alternate],
                action: #selector(moveBlockDown)
            ),
            UIKeyCommand(
                input: "\r",
                modifierFlags: [],
                action: #selector(insertBlockAfter)
            ),
            UIKeyCommand(
                input: "\t",
                modifierFlags: [],
                action: #selector(indentBlock)
            ),
            UIKeyCommand(
                input: "\t",
                modifierFlags: [.shift],
                action: #selector(outdentBlock)
            ),
            UIKeyCommand(
                input: "b",
                modifierFlags: [.command],
                action: #selector(applyBoldFormat)
            ),
            UIKeyCommand(
                input: "i",
                modifierFlags: [.command],
                action: #selector(applyItalicFormat)
            ),
            UIKeyCommand(
                input: "x",
                modifierFlags: [.command, .shift],
                action: #selector(applyStrikethroughFormat)
            ),
            UIKeyCommand(
                input: "e",
                modifierFlags: [.command],
                action: #selector(applyCodeFormat)
            ),
            UIKeyCommand(
                input: "k",
                modifierFlags: [.command],
                action: #selector(insertLink)
            )
        ]
    }

    @objc private func moveBlockUp() {
        _ = onKeyboardMove?(.up)
    }

    @objc private func moveBlockDown() {
        _ = onKeyboardMove?(.down)
    }

    @objc private func insertBlockAfter() {
        _ = onInsertBlockAfter?(selectedRange)
    }

    @objc private func indentBlock() {
        _ = onKeyboardIndentation?(.indent)
    }

    @objc private func outdentBlock() {
        _ = onKeyboardIndentation?(.outdent)
    }

    @objc private func applyBoldFormat() {
        applyInlineFormat(.bold)
    }

    @objc private func applyItalicFormat() {
        applyInlineFormat(.italic)
    }

    @objc private func applyStrikethroughFormat() {
        applyInlineFormat(.strikethrough)
    }

    @objc private func applyCodeFormat() {
        applyInlineFormat(.code)
    }

    private func applyInlineFormat(_ format: MarkdownInlineFormat) {
        _ = onKeyboardInlineFormat?(format, selectedRange)
    }

    @objc private func insertLink() {
        _ = onKeyboardLinkInsertion?(selectedRange)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first,
              let keyCode = press.key?.blockKeyboardArrowKeyCode else {
            super.pressesBegan(presses, with: event)
            return
        }

        if let direction = BlockKeyboardFocusResolver.focusDirection(
            keyCode: keyCode,
            modifiers: press.key?.modifierFlags.blockKeyboardShortcutModifiers ?? [],
            selectedRange: selectedRange,
            text: text
        ), onKeyboardFocusMove?(direction) == true {
            return
        }

        super.pressesBegan(presses, with: event)
    }
}

private extension UIKey {
    var blockKeyboardArrowKeyCode: UInt16? {
        switch keyCode {
        case .keyboardUpArrow:
            return BlockKeyboardShortcutResolver.upArrowKeyCode
        case .keyboardDownArrow:
            return BlockKeyboardShortcutResolver.downArrowKeyCode
        default:
            return nil
        }
    }
}

private extension UIKeyModifierFlags {
    var blockKeyboardShortcutModifiers: Set<BlockKeyboardShortcutModifier> {
        var modifiers: Set<BlockKeyboardShortcutModifier> = []
        if contains(.command) {
            modifiers.insert(.command)
        }
        if contains(.alternate) {
            modifiers.insert(.option)
        }
        if contains(.shift) {
            modifiers.insert(.shift)
        }
        if contains(.control) {
            modifiers.insert(.control)
        }
        return modifiers
    }
}
#endif
