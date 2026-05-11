import SwiftUI

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
    let blockID: String
    let text: String
    let blockType: BlockType
    @ObservedObject var session: EditorSession
    let focusRequestID: UUID?
    let onFocusRequestHandled: () -> Void
    let onTextChange: (String) -> Void

    init(
        blockID: String,
        text: String,
        blockType: BlockType,
        session: EditorSession,
        focusRequestID: UUID? = nil,
        onFocusRequestHandled: @escaping () -> Void = {},
        onTextChange: @escaping (String) -> Void
    ) {
        self.blockID = blockID
        self.text = text
        self.blockType = blockType
        self.session = session
        self.focusRequestID = focusRequestID
        self.onFocusRequestHandled = onFocusRequestHandled
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

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
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
#elseif os(iOS)
import UIKit

private struct PlatformNativeTextView: UIViewRepresentable {
    let blockID: String
    let text: String
    let blockType: BlockType
    @ObservedObject var session: EditorSession
    let focusRequestID: UUID?
    let onFocusRequestHandled: () -> Void
    let onTextChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(usingTextLayoutManager: true)
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
#endif
