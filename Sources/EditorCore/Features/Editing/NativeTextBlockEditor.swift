import SwiftUI

enum BlockKeyboardMoveDirection: Equatable, Sendable {
    case up
    case down
}

enum BlockKeyboardShortcutModifier: Equatable, Hashable, Sendable {
    case command
    case option
}

enum BlockKeyboardShortcutResolver {
    static let upArrowKeyCode: UInt16 = 126
    static let downArrowKeyCode: UInt16 = 125

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

struct NativeTextBlockEditor: View {
    static let acceptsInactiveWindowFirstMouse = true

    let blockID: String
    let text: String
    let blockType: BlockType
    @ObservedObject var session: EditorSession
    let focusRequestID: UUID?
    let onFocusRequestHandled: () -> Void
    let onMoveByKeyboard: (BlockKeyboardMoveDirection) -> Bool
    let onTextChange: (String) -> Void

    init(
        blockID: String,
        text: String,
        blockType: BlockType,
        session: EditorSession,
        focusRequestID: UUID? = nil,
        onFocusRequestHandled: @escaping () -> Void = {},
        onMoveByKeyboard: @escaping (BlockKeyboardMoveDirection) -> Bool = { _ in false },
        onTextChange: @escaping (String) -> Void
    ) {
        self.blockID = blockID
        self.text = text
        self.blockType = blockType
        self.session = session
        self.focusRequestID = focusRequestID
        self.onFocusRequestHandled = onFocusRequestHandled
        self.onMoveByKeyboard = onMoveByKeyboard
        self.onTextChange = onTextChange
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PlatformNativeTextView(
                blockID: blockID,
                text: text,
                blockType: blockType,
                session: session,
                focusRequestID: focusRequestID,
                onFocusRequestHandled: onFocusRequestHandled,
                onMoveByKeyboard: onMoveByKeyboard,
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
        .frame(minHeight: minimumHeight)
    }

    var showsPlaceholder: Bool {
        text.isEmpty && session.focusedBlockID != blockID
    }

    private var placeholderFont: Font {
        switch blockType {
        case .heading1:
            return .title2.weight(.semibold)
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
        case .codeBlock, .table:
            return 28
        default:
            return 24
        }
    }
}

#if os(macOS)
import AppKit

private struct PlatformNativeTextView: NSViewRepresentable {
    let blockID: String
    let text: String
    let blockType: BlockType
    @ObservedObject var session: EditorSession
    let focusRequestID: UUID?
    let onFocusRequestHandled: () -> Void
    let onMoveByKeyboard: (BlockKeyboardMoveDirection) -> Bool
    let onTextChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextView {
        let textContentStorage = NSTextContentStorage()
        let textLayoutManager = NSTextLayoutManager()
        let textContainer = NSTextContainer(
            size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        )
        textContainer.widthTracksTextView = true
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
        textView.setAccessibilityIdentifier("editor.text.\(blockID)")
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = nsFont
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = .zero
        textView.autoresizingMask = [.width]
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
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
        }
        if textView.string != text {
            textView.string = text
        }
        textView.font = nsFont
        context.coordinator.handleFocusRequestIfNeeded(textView: textView)
    }

    private var nsFont: NSFont {
        switch blockType {
        case .heading1:
            return .systemFont(ofSize: 22, weight: .semibold)
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

        init(parent: PlatformNativeTextView) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.session.beginEditing(blockID: parent.blockID, reason: .userTap)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            parent.session.updateDraft(blockID: parent.blockID, text: textView.string)
            parent.onTextChange(textView.string)
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

            textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
            return true
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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        NativeTextBlockEditor.acceptsInactiveWindowFirstMouse
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        if let window, window.firstResponder !== self {
            window.makeFirstResponder(self)
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

        super.keyDown(with: event)
    }
}

private extension NSEvent {
    var blockKeyboardShortcutModifiers: Set<BlockKeyboardShortcutModifier> {
        var modifiers: Set<BlockKeyboardShortcutModifier> = []
        if modifierFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if modifierFlags.contains(.option) {
            modifiers.insert(.option)
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
    let focusRequestID: UUID?
    let onFocusRequestHandled: () -> Void
    let onMoveByKeyboard: (BlockKeyboardMoveDirection) -> Bool
    let onTextChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = EditorUITextView(usingTextLayoutManager: true)
        textView.onKeyboardMove = onMoveByKeyboard
        textView.accessibilityIdentifier = "editor.text.\(blockID)"
        textView.delegate = context.coordinator
        textView.text = text
        textView.font = uiFont
        textView.textColor = .label
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        if textView.textLayoutManager == nil {
            EditorLog.input.error("textkit2_unavailable platform=iOS block_id=\(blockID, privacy: .public)")
        }
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        if let textView = textView as? EditorUITextView {
            textView.onKeyboardMove = onMoveByKeyboard
        }
        if textView.text != text {
            textView.text = text
        }
        textView.font = uiFont
        context.coordinator.handleFocusRequestIfNeeded(textView: textView)
    }

    private var uiFont: UIFont {
        switch blockType {
        case .heading1:
            return .preferredFont(forTextStyle: .title2)
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

        init(parent: PlatformNativeTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.session.beginEditing(blockID: parent.blockID, reason: .userTap)
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.session.updateDraft(blockID: parent.blockID, text: textView.text)
            parent.onTextChange(textView.text)
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

            textView.selectedRange = NSRange(location: textView.text.count, length: 0)
            return true
        }

        private func focusDelay(for remainingAttempts: Int) -> DispatchTimeInterval {
            remainingAttempts == 8 ? .milliseconds(0) : .milliseconds(35)
        }
    }
}

private final class EditorUITextView: UITextView {
    var onKeyboardMove: ((BlockKeyboardMoveDirection) -> Bool)?

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
            )
        ]
    }

    @objc private func moveBlockUp() {
        _ = onKeyboardMove?(.up)
    }

    @objc private func moveBlockDown() {
        _ = onKeyboardMove?(.down)
    }
}
#endif
