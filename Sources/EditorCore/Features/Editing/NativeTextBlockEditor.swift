import Foundation
import CoreText
import SwiftUI
import HighlightSwift

enum EditorContentFont: String, CaseIterable, Identifiable, Sendable {
    case system
    case lxgwWenKai

    static let appStorageKey = "editor.content-font"
    static let defaultFont: EditorContentFont = .lxgwWenKai
    static let defaultRawValue = defaultFont.rawValue
    static let lxgwWenKaiPostScriptName = "LXGWWenKaiGBScreen"
    static let lxgwWenKaiResourceName = "LXGW WenK"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .system:
            return "系统"
        case .lxgwWenKai:
            return "霞鹜文楷"
        }
    }

    var pageTitlePostScriptName: String? {
        switch self {
        case .system:
            return nil
        case .lxgwWenKai:
            return Self.lxgwWenKaiPostScriptName
        }
    }

    func postScriptName(for blockType: BlockType) -> String? {
        guard self == .lxgwWenKai else {
            return nil
        }

        switch blockType {
        case .codeBlock, .table:
            return nil
        default:
            return Self.lxgwWenKaiPostScriptName
        }
    }
}

@MainActor
enum EditorBundledFontRegistry {
    private static var didAttemptRegistration = false

    static func registerBundledFontsIfNeeded() {
        guard !didAttemptRegistration else {
            return
        }
        didAttemptRegistration = true

        guard let fontURL = bundledFontURL() else {
            return
        }

        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
    }

    private static func bundledFontURL() -> URL? {
        Bundle.main.url(
            forResource: EditorContentFont.lxgwWenKaiResourceName,
            withExtension: "ttf"
        ) ?? Bundle.main.url(
            forResource: EditorContentFont.lxgwWenKaiResourceName,
            withExtension: "ttf",
            subdirectory: "Fonts"
        )
    }
}

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
        modifiers: Set<BlockKeyboardShortcutModifier>,
        blockType: BlockType
    ) -> Bool {
        keyCode == returnKeyCode && modifiers.isEmpty && blockType != .codeBlock
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

enum EmptyTextBlockReturnResolver {
    static func shouldDemoteToParagraph(blockType: BlockType, text: String) -> Bool {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        switch blockType {
        case .unorderedListItem,
             .orderedListItem,
             .taskItem,
             .toggle:
            return true
        default:
            return false
        }
    }
}

struct NativeTextNewlineReplacement: Equatable {
    let updatedText: String
    let newlineRange: NSRange
}

enum NativeTextNewlineReplacementResolver {
    static func isSingleNewline(_ replacementText: String) -> Bool {
        guard (replacementText as NSString).length == 1 else {
            return false
        }
        return replacementText.rangeOfCharacter(from: .newlines) != nil
    }

    static func replacement(
        currentText: String,
        range: NSRange,
        replacementText: String
    ) -> NativeTextNewlineReplacement? {
        guard replacementText.rangeOfCharacter(from: .newlines) != nil else {
            return nil
        }

        let current = currentText as NSString
        guard range.location >= 0,
              range.length >= 0,
              range.location <= current.length,
              range.length <= current.length - range.location else {
            return nil
        }

        let updatedText = current.replacingCharacters(in: range, with: replacementText)
        let newlineRange = (updatedText as NSString).rangeOfCharacter(from: .newlines)
        guard newlineRange.location != NSNotFound else {
            return nil
        }

        return NativeTextNewlineReplacement(
            updatedText: updatedText,
            newlineRange: newlineRange
        )
    }
}

enum NativeTextPasteSplitPolicy {
    static func shouldRouteToBlockPaste(text: String, blockType: BlockType) -> Bool {
        text.rangeOfCharacter(from: .newlines) != nil
            && !PastedTextBlockLineResolver.lines(from: text).isEmpty
            && BlockKeyboardShortcutResolver.insertsBlockAfter(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: [],
                blockType: blockType
            )
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

enum NativeInlineLinkDestination: Equatable, Sendable {
    case internalLink(label: String, pageTitle: String, blockText: String?)
    case externalURL(String)
}

struct NativeInlineLinkActivation: Equatable, Sendable {
    let range: NSRange
    let destination: NativeInlineLinkDestination
}

enum NativeInlineLinkActivationResolver {
    static func activation(text: String, characterIndex: Int) -> NativeInlineLinkActivation? {
        guard characterIndex >= 0 else { return nil }
        guard let run = InlineLinkScanner.link(containing: characterIndex, in: text) else {
            return nil
        }
        switch run.kind {
        case .internalWiki(let label, let pageTitle, let blockText):
            return NativeInlineLinkActivation(
                range: run.fullRange,
                destination: .internalLink(label: label, pageTitle: pageTitle, blockText: blockText)
            )
        case .external(_, let url):
            return NativeInlineLinkActivation(
                range: run.fullRange,
                destination: .externalURL(url)
            )
        }
    }
}

enum NativeInlineLinkPointHitGuard {
    static func contains(point: CGPoint, linkBounds: CGRect?) -> Bool {
        guard let linkBounds,
              !linkBounds.isNull,
              !linkBounds.isEmpty else {
            return false
        }
        return linkBounds.contains(point)
    }

    static func contains(point: CGPoint, fragmentBounds: [CGRect]) -> Bool {
        fragmentBounds.contains {
            !$0.isNull && !$0.isEmpty && $0.contains(point)
        }
    }
}

enum NativeTextMarkdownSyntaxMarkerAttributes {
#if os(macOS)
    static func appKit(baseFont: NSFont) -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: NSColor.clear,
            .font: NSFont.systemFont(ofSize: min(1, max(0.1, baseFont.pointSize * 0.05)))
        ]
    }
#endif

#if os(iOS)
    static func uiKit(baseFont: UIFont) -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: UIColor.clear,
            .font: UIFont.systemFont(ofSize: min(1, max(0.1, baseFont.pointSize * 0.05)))
        ]
    }
#endif
}

enum BlockSelectAllStage: Equatable, Sendable {
    case currentText
    case currentBlock
    case allBlocks
}

enum BlockSelectAllKeyboardResolver {
    static func requestsSelectAll(
        input: String?,
        modifiers: Set<BlockKeyboardShortcutModifier>
    ) -> Bool {
        modifiers == [.command] && input?.lowercased() == "a"
    }

    static func stage(blockType: BlockType, selectedRange: NSRange, text: String) -> BlockSelectAllStage {
        if blockType == .codeBlock {
            return .currentText
        }

        let textLength = (text as NSString).length
        if selectedRange.location == 0,
           selectedRange.length == textLength {
            return .allBlocks
        }
        return .currentBlock
    }
}

enum BlockSelectionCancelKeyboardResolver {
    static let escapeKeyCode: UInt16 = 53
    private static let escapeInput = "\u{1B}"

    static func requestsCancel(
        keyCode: UInt16,
        input: String?,
        modifiers: Set<BlockKeyboardShortcutModifier>
    ) -> Bool {
        guard modifiers.isEmpty else {
            return false
        }
        return keyCode == escapeKeyCode || input == escapeInput
    }
}

enum SlashCommandKeyboardResolver {
    static func navigationDirection(
        keyCode: UInt16,
        modifiers: Set<BlockKeyboardShortcutModifier>,
        text: String,
        selectedRange: NSRange
    ) -> BlockKeyboardMoveDirection? {
        guard isOpenSlashCommand(text: text, selectedRange: selectedRange),
              modifiers.isEmpty else {
            return nil
        }

        switch keyCode {
        case BlockKeyboardShortcutResolver.upArrowKeyCode:
            return .up
        case BlockKeyboardShortcutResolver.downArrowKeyCode:
            return .down
        default:
            return nil
        }
    }

    static func requestsSelection(
        keyCode: UInt16,
        modifiers: Set<BlockKeyboardShortcutModifier>,
        text: String,
        selectedRange: NSRange
    ) -> Bool {
        keyCode == BlockKeyboardShortcutResolver.returnKeyCode
            && modifiers.isEmpty
            && isOpenSlashCommand(text: text, selectedRange: selectedRange)
    }

    private static func isOpenSlashCommand(text: String, selectedRange: NSRange) -> Bool {
        text.hasPrefix("/") && selectedRange.length == 0
    }
}

enum DiaryPromotionKeyboardResolver {
    static func requestsPromotion(
        input: String?,
        modifiers: Set<BlockKeyboardShortcutModifier>
    ) -> Bool {
        modifiers == [.command] && input == "]"
    }
}

enum BlockPromotionCommandResolver {
    static func promotableBlockID(
        selection: EditorTextSelection?,
        focusedBlockID: String?,
        blocks: [BlockSnapshot]
    ) -> String? {
        if let selection,
           isPromotableBlock(id: selection.blockID, blocks: blocks) {
            return selection.blockID
        }

        if let focusedBlockID,
           isPromotableBlock(id: focusedBlockID, blocks: blocks) {
            return focusedBlockID
        }

        return nil
    }

    private static func isPromotableBlock(id: String, blocks: [BlockSnapshot]) -> Bool {
        blocks.first { $0.id == id }?.type.isTextEditable == true
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
        let isSingleLine = text.rangeOfCharacter(from: .newlines) == nil
        switch keyCode {
        case BlockKeyboardShortcutResolver.upArrowKeyCode where isSingleLine || selectedRange.location == 0:
            return .previous
        case BlockKeyboardShortcutResolver.downArrowKeyCode where isSingleLine || selectedRange.location == textLength:
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

        guard let targetBlock = candidates.first(where: acceptsKeyboardNavigationFocus(_:)) else {
            return nil
        }

        let location: Int
        switch direction {
        case .previous:
            location = targetBlock.type.isTextEditable && targetBlock.type != .table
                ? (targetBlock.textPlain as NSString).length
                : 0
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

    private static func acceptsKeyboardNavigationFocus(_ block: BlockSnapshot) -> Bool {
        switch block.type {
        case .paragraph,
             .heading1,
             .heading2,
             .heading3,
             .heading4,
             .heading5,
             .heading6,
             .unorderedListItem,
             .orderedListItem,
             .taskItem,
             .quote,
             .codeBlock,
             .callout,
             .toggle,
             .table,
             .divider,
             .pageReference,
             .blockReference,
             .attachmentImage,
             .attachmentVideo,
             .attachmentFile,
             .drawing:
            return true
        }
    }
}

enum BlockKeyboardSelectionExtensionResolver {
    static func direction(
        keyCode: UInt16,
        modifiers: Set<BlockKeyboardShortcutModifier>
    ) -> BlockKeyboardFocusDirection? {
        guard modifiers == [.shift] else {
            return nil
        }

        switch keyCode {
        case BlockKeyboardShortcutResolver.upArrowKeyCode:
            return .previous
        case BlockKeyboardShortcutResolver.downArrowKeyCode:
            return .next
        default:
            return nil
        }
    }

    static func direction(
        keyCode: UInt16,
        modifiers: Set<BlockKeyboardShortcutModifier>,
        selectedRange: NSRange,
        text: String
    ) -> BlockKeyboardFocusDirection? {
        guard selectedRange.length == 0,
              let direction = direction(keyCode: keyCode, modifiers: modifiers) else {
            return nil
        }

        let textLength = (text as NSString).length
        switch direction {
        case .previous where selectedRange.location == 0:
            return .previous
        case .next where selectedRange.location == textLength:
            return .next
        default:
            return nil
        }
    }
}

enum NonEditableBlockKeyboardFocusResolver {
    static func focusDirection(
        keyCode: UInt16,
        modifiers: Set<BlockKeyboardShortcutModifier>
    ) -> BlockKeyboardFocusDirection? {
        guard modifiers.isEmpty else {
            return nil
        }

        switch keyCode {
        case BlockKeyboardShortcutResolver.upArrowKeyCode:
            return .previous
        case BlockKeyboardShortcutResolver.downArrowKeyCode:
            return .next
        default:
            return nil
        }
    }
}

enum NonEditableBlockKeyboardBridgeActivationResolver {
    static func isEnabled(
        blockType: BlockType,
        isBlockSelected: Bool
    ) -> Bool {
        let usesNativeTextEditor = blockType.isTextEditable && blockType != .table
        return isBlockSelected && !usesNativeTextEditor
    }
}

enum TableBlockKeyboardAction: Equatable, Sendable {
    case deleteSelection
    case cancelSelection
    case moveFocus(BlockKeyboardFocusDirection)
}

enum TableBlockKeyboardActionResolver {
    static let deleteBackwardKeyCode: UInt16 = 51
    static let deleteForwardKeyCode: UInt16 = 117
    static let escapeKeyCode: UInt16 = BlockSelectionCancelKeyboardResolver.escapeKeyCode

    static func action(
        keyCode: UInt16,
        modifiers: Set<BlockKeyboardShortcutModifier>,
        hasSelection: Bool
    ) -> TableBlockKeyboardAction? {
        guard hasSelection, modifiers.isEmpty else {
            return nil
        }

        switch keyCode {
        case deleteBackwardKeyCode, deleteForwardKeyCode:
            return .deleteSelection
        case escapeKeyCode:
            return .cancelSelection
        default:
            guard let direction = NonEditableBlockKeyboardFocusResolver.focusDirection(
                keyCode: keyCode,
                modifiers: modifiers
            ) else {
                return nil
            }
            return .moveFocus(direction)
        }
    }
}

enum BlockDragPayloadResolver {
    static func payloadBlockIDs(rootBlockID: String, blocks: [BlockSnapshot]) -> [String] {
        let blocksByID = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })
        return blocks.compactMap { block in
            guard block.id == rootBlockID || isDescendant(block, of: rootBlockID, blocksByID: blocksByID) else {
                return nil
            }
            return block.id
        }
    }

    private static func isDescendant(
        _ block: BlockSnapshot,
        of rootBlockID: String,
        blocksByID: [String: BlockSnapshot]
    ) -> Bool {
        var parentBlockID = block.parentBlockID
        var visitedBlockIDs = Set<String>()

        while let parentID = parentBlockID, !visitedBlockIDs.contains(parentID) {
            if parentID == rootBlockID {
                return true
            }
            visitedBlockIDs.insert(parentID)
            parentBlockID = blocksByID[parentID]?.parentBlockID
        }

        return false
    }
}

struct BlockDragPayloadIndex {
    private let payloadBlockIDsByRootID: [String: [String]]

    init(blocks: [BlockSnapshot]) {
        guard blocks.contains(where: { $0.parentBlockID != nil }) else {
            payloadBlockIDsByRootID = [:]
            return
        }

        let parentBlockIDsByID = Dictionary(
            uniqueKeysWithValues: blocks.map { ($0.id, $0.parentBlockID) }
        )
        var payloadBlockIDsByRootID: [String: [String]] = [:]

        for block in blocks {
            payloadBlockIDsByRootID[block.id, default: []].append(block.id)

            var parentBlockID = block.parentBlockID
            var visitedBlockIDs = Set<String>()
            while let parentID = parentBlockID, !visitedBlockIDs.contains(parentID) {
                payloadBlockIDsByRootID[parentID, default: []].append(block.id)
                visitedBlockIDs.insert(parentID)
                parentBlockID = parentBlockIDsByID[parentID] ?? nil
            }
        }

        self.payloadBlockIDsByRootID = payloadBlockIDsByRootID
    }

    func payloadBlockIDs(rootBlockID: String) -> [String] {
        payloadBlockIDsByRootID[rootBlockID] ?? []
    }
}

enum BlockDragReorderResolver {
    static func targetIndex(
        draggedBlockID: String,
        destinationBlockID: String,
        visibleBlockIDs: [String],
        placement: BlockDropPlacement = .before
    ) -> Int? {
        targetIndex(
            draggedBlockIDs: [draggedBlockID],
            destinationBlockID: destinationBlockID,
            visibleBlockIDs: visibleBlockIDs,
            placement: placement
        )
    }

    static func targetIndex(
        draggedBlockIDs: [String],
        destinationBlockID: String,
        visibleBlockIDs: [String],
        placement: BlockDropPlacement = .before
    ) -> Int? {
        let draggedBlockIDSet = Set(draggedBlockIDs)
        guard let destinationIndex = visibleBlockIDs.firstIndex(of: destinationBlockID) else {
            return nil
        }
        if draggedBlockIDSet.contains(destinationBlockID) {
            return placement == .outdentAfter ? destinationIndex : nil
        }

        let insertionIndex = destinationIndex + (placement == .before ? 0 : 1)
        let movingBlockIDs = visibleBlockIDs.filter { draggedBlockIDSet.contains($0) }
        guard !movingBlockIDs.isEmpty else {
            return nil
        }

        let movingBeforeInsertionCount = visibleBlockIDs
            .prefix(insertionIndex)
            .filter { draggedBlockIDSet.contains($0) }
            .count
        let adjustedTargetIndex = insertionIndex - movingBeforeInsertionCount
        let remainingBlockIDs = visibleBlockIDs.filter { !draggedBlockIDSet.contains($0) }
        var reorderedBlockIDs = remainingBlockIDs
        reorderedBlockIDs.insert(contentsOf: movingBlockIDs, at: min(max(adjustedTargetIndex, 0), remainingBlockIDs.count))

        guard reorderedBlockIDs != visibleBlockIDs else {
            if placement == .childAfter || placement == .outdentAfter {
                return adjustedTargetIndex
            }
            return nil
        }
        return adjustedTargetIndex
    }

    static func endTargetIndex(
        draggedBlockID: String,
        visibleBlockIDs: [String]
    ) -> Int? {
        endTargetIndex(draggedBlockIDs: [draggedBlockID], visibleBlockIDs: visibleBlockIDs)
    }

    static func endTargetIndex(
        draggedBlockIDs: [String],
        visibleBlockIDs: [String]
    ) -> Int? {
        let draggedBlockIDSet = Set(draggedBlockIDs)
        let movingBlockIDs = visibleBlockIDs.filter { draggedBlockIDSet.contains($0) }
        guard !movingBlockIDs.isEmpty else {
            return nil
        }

        let remainingBlockIDs = visibleBlockIDs.filter { !draggedBlockIDSet.contains($0) }
        let targetIndex = remainingBlockIDs.count
        let reorderedBlockIDs = remainingBlockIDs + movingBlockIDs
        guard reorderedBlockIDs != visibleBlockIDs else {
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

enum NativeTextFocusConfirmationPolicy {
    static let confirmationDelay: TimeInterval = 0.05

    static func shouldMarkRequestHandled(
        didPerformFocus: Bool,
        isFirstResponderAfterConfirmation: Bool
    ) -> Bool {
        didPerformFocus && isFirstResponderAfterConfirmation
    }

    static func shouldRetry(
        didPerformFocus: Bool,
        isFirstResponderAfterConfirmation: Bool,
        remainingAttempts: Int
    ) -> Bool {
        !shouldMarkRequestHandled(
            didPerformFocus: didPerformFocus,
            isFirstResponderAfterConfirmation: isFirstResponderAfterConfirmation
        ) && remainingAttempts > 0
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

enum NativeTextAcceptedChangeFallbackSelectionPolicy {
    static func selectionRange(
        actualSelection: NSRange,
        acceptedRange: NSRange,
        replacementText: String,
        nextTextLength: Int
    ) -> NSRange {
        selectionRange(
            actualSelection: actualSelection,
            expectedCaretLocation: acceptedRange.location + (replacementText as NSString).length,
            nextTextLength: nextTextLength,
            shouldRepair: !replacementText.isEmpty && acceptedRange.location >= 0 && acceptedRange.length >= 0
        )
    }

    static func selectionRange(
        actualSelection: NSRange,
        expectedCaretLocation: Int,
        nextTextLength: Int,
        shouldRepair: Bool
    ) -> NSRange {
        guard shouldRepair,
              actualSelection.length == 0 else {
            return actualSelection
        }

        let expectedLocation = min(nextTextLength, max(0, expectedCaretLocation))
        guard actualSelection.location < expectedLocation else {
            return actualSelection
        }

        return NSRange(location: expectedLocation, length: 0)
    }
}

struct NativeTextAcceptedChangeFallbackProposal: Equatable {
    let text: String
    let caretLocation: Int
}

enum NativeTextAcceptedChangeFallbackTextPolicy {
    static func proposal(
        currentText: String,
        mirrorText: String?,
        acceptedRange: NSRange,
        replacementText: String
    ) -> NativeTextAcceptedChangeFallbackProposal? {
        let currentNSString = currentText as NSString
        let replacementLength = (replacementText as NSString).length
        let currentLength = currentNSString.length
        var baseText = currentText
        var replacementRange = acceptedRange

        if let mirrorText {
            let mirrorLength = (mirrorText as NSString).length
            if mirrorLength > currentLength,
               acceptedRange.location == currentLength,
               acceptedRange.length == 0,
               !replacementText.isEmpty {
                baseText = mirrorText
                replacementRange = NSRange(location: mirrorLength, length: 0)
            }
        }

        let baseNSString = baseText as NSString
        guard replacementRange.location >= 0,
              replacementRange.length >= 0,
              replacementRange.location <= baseNSString.length,
              replacementRange.length <= baseNSString.length - replacementRange.location else {
            return nil
        }

        let proposedText = baseNSString.replacingCharacters(in: replacementRange, with: replacementText)
        let proposedLength = (proposedText as NSString).length
        let caretLocation = min(proposedLength, replacementRange.location + replacementLength)
        return NativeTextAcceptedChangeFallbackProposal(text: proposedText, caretLocation: caretLocation)
    }

    static func resolvedText(actualText: String, proposedText: String) -> String {
        let actualLength = (actualText as NSString).length
        let proposedLength = (proposedText as NSString).length
        return actualLength >= proposedLength ? actualText : proposedText
    }
}

enum NativeTextDisplayTextPolicy {
    static func effectiveText(
        modelText: String,
        draftText: String?,
        acceptedTextInputMirror: String?
    ) -> String {
        acceptedTextInputMirror ?? draftText ?? modelText
    }
}

#if os(iOS)
@MainActor
enum MobileKeyboardPerformanceState {
    private(set) static var isVisible = false
    private(set) static var lastKeyboardFrame: CGRect = .zero

    static func update(isVisible: Bool, frame: CGRect) {
        self.isVisible = isVisible
        lastKeyboardFrame = frame
    }

    static var metadata: [String: String] {
        [
            "keyboard_visible": "\(isVisible)",
            "keyboard_min_y": String(format: "%.1f", lastKeyboardFrame.minY),
            "keyboard_height": String(format: "%.1f", lastKeyboardFrame.height)
        ]
    }
}
#endif

enum NativeTextCompositionPolicy {
    static func shouldApplyModelText(isComposing: Bool) -> Bool {
        !isComposing
    }

    static func shouldApplyInlineMarkdownStyles(isComposing: Bool) -> Bool {
        !isComposing
    }

    static func shouldHandleBlockCommand(isComposing: Bool) -> Bool {
        !isComposing
    }
}

struct NativeTextStyleFingerprint: Equatable {
    let blockType: BlockType
    let text: String
    let fontName: String
    let fontSize: CGFloat
    let lineHeightMultiple: CGFloat
}

enum NativeTextStyleApplicationPolicy {
    static func shouldApplyStyle(
        cached: NativeTextStyleFingerprint?,
        next: NativeTextStyleFingerprint,
        isComposing: Bool,
        baseAttributesWereReset: Bool = false
    ) -> Bool {
        !isComposing && (baseAttributesWereReset || cached != next)
    }
}

struct NativeTextHeightMeasurementFingerprint: Equatable {
    let text: String
    let width: CGFloat
    let lineWrapping: Bool
    let blockType: BlockType
    let fontName: String
    let fontSize: CGFloat
    let minimumHeight: CGFloat
    let lineHeightMultiple: CGFloat
}

enum NativeTextHeightMeasurementPolicy {
    static func shouldMeasureHeight(
        cached: NativeTextHeightMeasurementFingerprint?,
        next: NativeTextHeightMeasurementFingerprint
    ) -> Bool {
        cached != next
    }
}

enum NativeTextPlaceholderVisibilityPolicy {
    static func showsPlaceholder(text: String, isFocused: Bool, isComposing: Bool) -> Bool {
        false
    }
}

enum NativeTextDropPolicy {
    static let acceptsDropIntoTextEditor = false
}

enum NativeTextInsertionPointRectResolver {
    static let verticalPadding: CGFloat = 2

    static func rect(
        original: CGRect,
        fontLineHeight: CGFloat?,
        verticalOffset: CGFloat = 0
    ) -> CGRect {
        guard let fontLineHeight, fontLineHeight > 0 else {
            return original
        }

        let clampedHeight = min(original.height, ceil(fontLineHeight + verticalPadding))
        let originY = original.midY - clampedHeight / 2 + verticalOffset
        return CGRect(
            x: original.origin.x,
            y: originY,
            width: original.width,
            height: clampedHeight
        )
    }
}

enum NativeTextCursorChrome {
#if os(macOS)
    static var nsColor: NSColor {
        EditorDesignTokens.Colors.accent.nsColor
    }

    static func nsColor(for scheme: EditorThemeScheme) -> NSColor {
        EditorDesignTokens.Colors.accent.nsColor(for: scheme)
    }
#elseif os(iOS)
    static var uiColor: UIColor {
        EditorDesignTokens.Colors.accent.uiColor
    }

    static func uiColor(for scheme: EditorThemeScheme) -> UIColor {
        EditorDesignTokens.Colors.accent.uiColor(for: scheme)
    }
#endif
}

enum NativeInlineMarkdownStyleChrome {
    static let inlineCodeBackgroundToken = EditorDesignTokens.Colors.inlineCodeBackground
}

enum NativeInlineMarkdownFontVariantResolver {
    static let syntheticBoldStrokeWidth: CGFloat = -2
    static let syntheticItalicObliqueness: CGFloat = 0.12

    static func usesSyntheticVariant(fontName: String) -> Bool {
        fontName == EditorContentFont.lxgwWenKaiPostScriptName
    }

#if os(macOS)
    static func appKitBoldAttributes(baseFont: NSFont) -> [NSAttributedString.Key: Any] {
        guard !usesSyntheticVariant(fontName: baseFont.fontName) else {
            return [
                .font: baseFont,
                .strokeWidth: syntheticBoldStrokeWidth
            ]
        }
        return [.font: NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)]
    }

    static func appKitItalicAttributes(baseFont: NSFont) -> [NSAttributedString.Key: Any] {
        guard !usesSyntheticVariant(fontName: baseFont.fontName) else {
            return [
                .font: baseFont,
                .obliqueness: syntheticItalicObliqueness
            ]
        }
        return [.font: NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)]
    }
#endif

#if os(iOS)
    static func uiKitBoldAttributes(baseFont: UIFont) -> [NSAttributedString.Key: Any] {
        guard !usesSyntheticVariant(fontName: baseFont.fontName) else {
            return [
                .font: baseFont,
                .strokeWidth: syntheticBoldStrokeWidth
            ]
        }
        guard let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitBold) else {
            return [.font: UIFont.boldSystemFont(ofSize: baseFont.pointSize)]
        }
        return [.font: UIFont(descriptor: descriptor, size: baseFont.pointSize)]
    }

    static func uiKitItalicAttributes(baseFont: UIFont) -> [NSAttributedString.Key: Any] {
        guard !usesSyntheticVariant(fontName: baseFont.fontName) else {
            return [
                .font: baseFont,
                .obliqueness: syntheticItalicObliqueness
            ]
        }
        guard let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) else {
            return [.font: UIFont.italicSystemFont(ofSize: baseFont.pointSize)]
        }
        return [.font: UIFont(descriptor: descriptor, size: baseFont.pointSize)]
    }
#endif
}

enum NativeCodeSyntaxHighlightChrome {
    static func colors(for scheme: EditorThemeScheme) -> HighlightColors {
        switch scheme {
        case .light:
            return .light(.xcode)
        case .dark:
            return .dark(.xcode)
        }
    }
}

enum NativeTextKeyboardRestorePolicy {
    static func shouldRestoreSystemKeyboard(
        wasReplacingKeyboard: Bool,
        replacesKeyboard: Bool,
        isTextViewFirstResponder: Bool
    ) -> Bool {
        wasReplacingKeyboard && !replacesKeyboard && isTextViewFirstResponder
    }
}

enum NativeTextEditorLayout {
    static let verticalTextInset: CGFloat = 2
    static let textContainerInset = CGSize(width: 0, height: verticalTextInset)
    static let keyboardFormatPanelHeight: CGFloat = MobileFormatPaletteChrome.height
#if os(iOS)
    static let uiTextContainerInset = UIEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
    static let uiVerticalTextInset = uiTextContainerInset.top + uiTextContainerInset.bottom
    static let uiCaretVerticalOffset: CGFloat = 0
    static let placeholderTopPadding: CGFloat = 4
    static let keyboardToolbarHeight: CGFloat = MobileKeyboardToolbarChrome.height
#endif

    static func measuredHeight(contentHeight: CGFloat, minimumHeight: CGFloat) -> CGFloat {
        measuredHeight(
            contentHeight: contentHeight,
            minimumHeight: minimumHeight,
            verticalInset: verticalTextInset * 2
        )
    }

    static func measuredHeight(
        contentHeight: CGFloat,
        minimumHeight: CGFloat,
        verticalInset: CGFloat
    ) -> CGFloat {
        max(minimumHeight, ceil(contentHeight + verticalInset))
    }
}

enum NativeTextMeasurementWidthPolicy {
    static let unwrappedWidth: CGFloat = 10_000
    static let minimumWrappedWidth: CGFloat = 10

    static func width(
        boundsWidth: CGFloat,
        viewportWidth: CGFloat,
        horizontalMargin: CGFloat,
        lineWrapping: Bool
    ) -> CGFloat {
        guard lineWrapping else {
            return unwrappedWidth
        }

        let viewportWidth = max(minimumWrappedWidth, viewportWidth - horizontalMargin)
        let proposedWidth = boundsWidth > 0 ? boundsWidth : viewportWidth
        return min(max(proposedWidth, minimumWrappedWidth), viewportWidth)
    }
}

enum CodeBlockSyntaxHighlightApplicator {
    static func attributedString(
        text: String,
        highlighted: NSAttributedString,
        baseAttributes: [NSAttributedString.Key: Any],
        allowedAttributeKeys: Set<NSAttributedString.Key>
    ) -> NSMutableAttributedString {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        let result = NSMutableAttributedString(string: text, attributes: baseAttributes)
        guard highlighted.string == text,
              highlighted.length == fullRange.length,
              fullRange.length > 0 else {
            return result
        }

        highlighted.enumerateAttributes(in: fullRange) { attributes, range, _ in
            let syntaxAttributes = attributes.filter { key, _ in
                allowedAttributeKeys.contains(key)
            }
            if !syntaxAttributes.isEmpty {
                result.addAttributes(syntaxAttributes, range: range)
            }
        }
        return result
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

enum MobileNativeTextBlockDragPolicy {
    static let installsUIDragInteraction = true
    static let disablesSystemTextDragInteraction = true
    static let disablesSystemTextDropInteraction = true

    static func payloadText(blockID: String, explicitPayloadText: String?) -> String {
        guard let explicitPayloadText,
              !explicitPayloadText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return blockID
        }
        return explicitPayloadText
    }
}

enum NativeTextModelPropagationPolicy {
    static let debounceNanoseconds: UInt64 = 180_000_000
    static let debounceMilliseconds = 180
}

struct NativeTextBlockEditor: View {
    static let acceptsInactiveWindowFirstMouse = true

    let blockID: String
    let text: String
    let blockType: BlockType
    let contentFont: EditorContentFont
    let session: EditorSession
    let lineWrapping: Bool
    let focusRequestID: UUID?
    let focusSelection: EditorTextSelection?
    let onFocusRequestHandled: () -> Void
    let onMoveByKeyboard: (BlockKeyboardMoveDirection) -> Bool
    let onIndentationByKeyboard: (BlockKeyboardIndentationDirection) -> Bool
    let onMoveFocusByKeyboard: (BlockKeyboardFocusDirection) -> Bool
    let onExtendBlockSelectionByKeyboard: (BlockKeyboardFocusDirection) -> Bool
    let onApplyInlineFormatByKeyboard: (MarkdownInlineFormat, EditorTextSelection) -> Bool
    let onInsertLinkByKeyboard: (EditorTextSelection) -> Bool
    let onInlineLinkActivation: ((NativeInlineLinkActivation, NSRange) -> Bool)?
    let onInsertBlockAfter: (EditorTextSelection) -> EditorTextSelection?
    let onReplaceTextAtSelection: (EditorTextSelection, String) -> EditorTextSelection?
    let onPasteTextAtSelection: (EditorTextSelection, String) -> EditorTextSelection?
    let onMergeBlockWithPrevious: (EditorTextSelection) -> Bool
    let onMergeBlockWithNext: (EditorTextSelection) -> Bool
    let onSlashCommandNavigationByKeyboard: (BlockKeyboardMoveDirection) -> Bool
    let onSlashCommandSelectionByKeyboard: () -> Bool
    let onPasteAttachmentURLs: ([URL]) -> Bool
    let onSelectAllBlocksByKeyboard: () -> Bool
    let onCancelSelectionByKeyboard: () -> Bool
    let onPromoteBlockToPageByKeyboard: () -> Bool
    let onHorizontalSwipe: (CGFloat) -> Bool
    let dragPayloadText: String?
    let keyboardAccessory: AnyView?
    let keyboardAccessoryHeight: CGFloat?
    let keyboardAccessoryReplacesKeyboard: Bool
    let onTextChange: (String) -> Void
    let onEditingEnded: () -> Void
    @State private var measuredHeight: CGFloat = 0

    init(
        blockID: String,
        text: String,
        blockType: BlockType,
        contentFont: EditorContentFont = EditorContentFont.defaultFont,
        session: EditorSession,
        lineWrapping: Bool = true,
        focusRequestID: UUID? = nil,
        focusSelection: EditorTextSelection? = nil,
        onFocusRequestHandled: @escaping () -> Void = {},
        onMoveByKeyboard: @escaping (BlockKeyboardMoveDirection) -> Bool = { _ in false },
        onIndentationByKeyboard: @escaping (BlockKeyboardIndentationDirection) -> Bool = { _ in false },
        onMoveFocusByKeyboard: @escaping (BlockKeyboardFocusDirection) -> Bool = { _ in false },
        onExtendBlockSelectionByKeyboard: @escaping (BlockKeyboardFocusDirection) -> Bool = { _ in false },
        onApplyInlineFormatByKeyboard: @escaping (MarkdownInlineFormat, EditorTextSelection) -> Bool = { _, _ in false },
        onInsertLinkByKeyboard: @escaping (EditorTextSelection) -> Bool = { _ in false },
        onInlineLinkActivation: ((NativeInlineLinkActivation, NSRange) -> Bool)? = nil,
        onInsertBlockAfter: @escaping (EditorTextSelection) -> EditorTextSelection? = { _ in nil },
        onReplaceTextAtSelection: @escaping (EditorTextSelection, String) -> EditorTextSelection? = { _, _ in nil },
        onPasteTextAtSelection: @escaping (EditorTextSelection, String) -> EditorTextSelection? = { _, _ in nil },
        onMergeBlockWithPrevious: @escaping (EditorTextSelection) -> Bool = { _ in false },
        onMergeBlockWithNext: @escaping (EditorTextSelection) -> Bool = { _ in false },
        onSlashCommandNavigationByKeyboard: @escaping (BlockKeyboardMoveDirection) -> Bool = { _ in false },
        onSlashCommandSelectionByKeyboard: @escaping () -> Bool = { false },
        onPasteAttachmentURLs: @escaping ([URL]) -> Bool = { _ in false },
        onSelectAllBlocksByKeyboard: @escaping () -> Bool = { false },
        onCancelSelectionByKeyboard: @escaping () -> Bool = { false },
        onPromoteBlockToPageByKeyboard: @escaping () -> Bool = { false },
        onHorizontalSwipe: @escaping (CGFloat) -> Bool = { _ in false },
        dragPayloadText: String? = nil,
        keyboardAccessory: AnyView? = nil,
        keyboardAccessoryHeight: CGFloat? = nil,
        keyboardAccessoryReplacesKeyboard: Bool = false,
        onTextChange: @escaping (String) -> Void,
        onEditingEnded: @escaping () -> Void = {}
    ) {
        self.blockID = blockID
        self.text = text
        self.blockType = blockType
        self.contentFont = contentFont
        self.session = session
        self.lineWrapping = lineWrapping
        self.focusRequestID = focusRequestID
        self.focusSelection = focusSelection
        self.onFocusRequestHandled = onFocusRequestHandled
        self.onMoveByKeyboard = onMoveByKeyboard
        self.onIndentationByKeyboard = onIndentationByKeyboard
        self.onMoveFocusByKeyboard = onMoveFocusByKeyboard
        self.onExtendBlockSelectionByKeyboard = onExtendBlockSelectionByKeyboard
        self.onApplyInlineFormatByKeyboard = onApplyInlineFormatByKeyboard
        self.onInsertLinkByKeyboard = onInsertLinkByKeyboard
        self.onInlineLinkActivation = onInlineLinkActivation
        self.onInsertBlockAfter = onInsertBlockAfter
        self.onReplaceTextAtSelection = onReplaceTextAtSelection
        self.onPasteTextAtSelection = onPasteTextAtSelection
        self.onMergeBlockWithPrevious = onMergeBlockWithPrevious
        self.onMergeBlockWithNext = onMergeBlockWithNext
        self.onSlashCommandNavigationByKeyboard = onSlashCommandNavigationByKeyboard
        self.onSlashCommandSelectionByKeyboard = onSlashCommandSelectionByKeyboard
        self.onPasteAttachmentURLs = onPasteAttachmentURLs
        self.onSelectAllBlocksByKeyboard = onSelectAllBlocksByKeyboard
        self.onCancelSelectionByKeyboard = onCancelSelectionByKeyboard
        self.onPromoteBlockToPageByKeyboard = onPromoteBlockToPageByKeyboard
        self.onHorizontalSwipe = onHorizontalSwipe
        self.dragPayloadText = dragPayloadText
        self.keyboardAccessory = keyboardAccessory
        self.keyboardAccessoryHeight = keyboardAccessoryHeight
        self.keyboardAccessoryReplacesKeyboard = keyboardAccessoryReplacesKeyboard
        self.onTextChange = onTextChange
        self.onEditingEnded = onEditingEnded
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PlatformNativeTextView(
                blockID: blockID,
                text: text,
                blockType: blockType,
                contentFont: contentFont,
                session: session,
                lineWrapping: lineWrapping,
                focusRequestID: focusRequestID,
                focusSelection: focusSelection,
                onFocusRequestHandled: onFocusRequestHandled,
                onMoveByKeyboard: onMoveByKeyboard,
                onIndentationByKeyboard: onIndentationByKeyboard,
                onMoveFocusByKeyboard: onMoveFocusByKeyboard,
                onExtendBlockSelectionByKeyboard: onExtendBlockSelectionByKeyboard,
                onApplyInlineFormatByKeyboard: onApplyInlineFormatByKeyboard,
                onInsertLinkByKeyboard: onInsertLinkByKeyboard,
                onInlineLinkActivation: onInlineLinkActivation,
                onInsertBlockAfter: onInsertBlockAfter,
                onReplaceTextAtSelection: onReplaceTextAtSelection,
                onPasteTextAtSelection: onPasteTextAtSelection,
                onMergeBlockWithPrevious: onMergeBlockWithPrevious,
                onMergeBlockWithNext: onMergeBlockWithNext,
                onSlashCommandNavigationByKeyboard: onSlashCommandNavigationByKeyboard,
                onSlashCommandSelectionByKeyboard: onSlashCommandSelectionByKeyboard,
                onPasteAttachmentURLs: onPasteAttachmentURLs,
                onSelectAllBlocksByKeyboard: onSelectAllBlocksByKeyboard,
                onCancelSelectionByKeyboard: onCancelSelectionByKeyboard,
                onPromoteBlockToPageByKeyboard: onPromoteBlockToPageByKeyboard,
                onHorizontalSwipe: onHorizontalSwipe,
                dragPayloadText: dragPayloadText,
                keyboardAccessory: keyboardAccessory,
                keyboardAccessoryHeight: keyboardAccessoryHeight,
                keyboardAccessoryReplacesKeyboard: keyboardAccessoryReplacesKeyboard,
                minimumHeight: minimumHeight,
                onContentHeightChange: updateMeasuredHeight,
                onTextChange: onTextChange,
                onEditingEnded: onEditingEnded
            )

            if showsPlaceholder {
                Text("按 \"/\" 快速操作")
                    .font(placeholderFont)
                    .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)
#if os(iOS)
                    .padding(.top, NativeTextEditorLayout.placeholderTopPadding)
#else
                    .padding(.top, NativeTextEditorLayout.verticalTextInset)
#endif
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: effectiveHeight)
    }

    var showsPlaceholder: Bool {
        NativeTextPlaceholderVisibilityPolicy.showsPlaceholder(
            text: text,
            isFocused: session.focusedBlockID == blockID,
            isComposing: session.composingBlockID == blockID
        )
    }

    private var placeholderFont: Font {
        switch blockType {
        case .heading1:
#if os(iOS)
            return .system(size: 28, weight: .semibold)
#else
            return .title2.weight(.semibold)
#endif
        case .heading2:
#if os(iOS)
            return .system(size: 24, weight: .semibold)
#else
            return .title3.weight(.semibold)
#endif
        case .heading3:
#if os(iOS)
            return .system(size: 20, weight: .semibold)
#else
            return .headline
#endif
        case .heading4, .heading5, .heading6:
#if os(iOS)
            return .system(size: 18, weight: .semibold)
#else
            return .subheadline.weight(.semibold)
#endif
        case .codeBlock, .table:
#if os(iOS)
            return .system(size: 16, weight: .regular, design: .monospaced)
#else
            return .system(.body, design: .monospaced)
#endif
        default:
#if os(iOS)
            return .system(size: 18)
#else
            return .system(size: EditorDesignTokens.Typography.bodySize)
#endif
        }
    }

    private var minimumHeight: CGFloat {
#if os(iOS)
        switch blockType {
        case .heading1:
            return 36
        case .heading2:
            return 32
        case .heading3:
            return 28
        case .heading4, .heading5, .heading6:
            return 26
        case .codeBlock, .table:
            return 24
        default:
            return 26
        }
#else
        switch blockType {
        case .heading1:
            return 27
        case .heading2:
            return 24
        case .heading3:
            return 22
        case .heading4, .heading5, .heading6:
            return 21
        case .codeBlock, .table:
            return 21
        default:
            return 20
        }
#endif
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

enum CommandVPasteShortcutResolver {
    static func requestsAttachmentPaste(
        input: String?,
        modifiers: Set<BlockKeyboardShortcutModifier>
    ) -> Bool {
        modifiers == [.command] && input?.lowercased() == "v"
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

enum MacPasteboardAttachmentResolver {
    static func attachmentURLs(from pasteboard: NSPasteboard) -> [URL] {
        let fileURLs = fileURLsFromPasteboardObjects(pasteboard)
        if !fileURLs.isEmpty {
            return fileURLs
        }

        if let fileURL = fileURLFromPasteboardString(pasteboard) {
            return [fileURL]
        }

        guard let image = NSImage(pasteboard: pasteboard),
              let imageURL = writeTemporaryClipboardImage(image) else {
            return []
        }
        return [imageURL]
    }

    private static func fileURLsFromPasteboardObjects(_ pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: options
        ) as? [NSURL] ?? []

        return objects
            .map { $0 as URL }
            .filter(\.isFileURL)
    }

    private static func fileURLFromPasteboardString(_ pasteboard: NSPasteboard) -> URL? {
        guard let value = pasteboard.string(forType: .fileURL) else {
            return nil
        }

        if let url = URL(string: value),
           url.isFileURL {
            return url
        }

        let fallbackURL = URL(fileURLWithPath: value)
        return fallbackURL.path.isEmpty ? nil : fallbackURL
    }

    private static func writeTemporaryClipboardImage(_ image: NSImage) -> URL? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("editor-clipboard-\(UUID().uuidString.lowercased()).png")
        do {
            try pngData.write(to: url, options: .atomic)
            return url
        } catch {
            EditorLog.attachment.error(
                "clipboard_image_write_failed error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }
}

enum MacPasteKeyboardShortcutResolver {
    static let vKeyCode: UInt16 = 9

    static func requestsAttachmentPaste(
        keyCode: UInt16,
        input: String?,
        modifiers: Set<BlockKeyboardShortcutModifier>
    ) -> Bool {
        if modifiers == [.command], keyCode == vKeyCode {
            return true
        }

        return CommandVPasteShortcutResolver.requestsAttachmentPaste(
            input: input,
            modifiers: modifiers
        )
    }
}

private struct PlatformNativeTextView: NSViewRepresentable {
    let blockID: String
    let text: String
    let blockType: BlockType
    let contentFont: EditorContentFont
    let session: EditorSession
    let lineWrapping: Bool
    let focusRequestID: UUID?
    let focusSelection: EditorTextSelection?
    let onFocusRequestHandled: () -> Void
    let onMoveByKeyboard: (BlockKeyboardMoveDirection) -> Bool
    let onIndentationByKeyboard: (BlockKeyboardIndentationDirection) -> Bool
    let onMoveFocusByKeyboard: (BlockKeyboardFocusDirection) -> Bool
    let onExtendBlockSelectionByKeyboard: (BlockKeyboardFocusDirection) -> Bool
    let onApplyInlineFormatByKeyboard: (MarkdownInlineFormat, EditorTextSelection) -> Bool
    let onInsertLinkByKeyboard: (EditorTextSelection) -> Bool
    let onInlineLinkActivation: ((NativeInlineLinkActivation, NSRange) -> Bool)?
    let onInsertBlockAfter: (EditorTextSelection) -> EditorTextSelection?
    let onReplaceTextAtSelection: (EditorTextSelection, String) -> EditorTextSelection?
    let onPasteTextAtSelection: (EditorTextSelection, String) -> EditorTextSelection?
    let onMergeBlockWithPrevious: (EditorTextSelection) -> Bool
    let onMergeBlockWithNext: (EditorTextSelection) -> Bool
    let onSlashCommandNavigationByKeyboard: (BlockKeyboardMoveDirection) -> Bool
    let onSlashCommandSelectionByKeyboard: () -> Bool
    let onPasteAttachmentURLs: ([URL]) -> Bool
    let onSelectAllBlocksByKeyboard: () -> Bool
    let onCancelSelectionByKeyboard: () -> Bool
    let onPromoteBlockToPageByKeyboard: () -> Bool
    let onHorizontalSwipe: (CGFloat) -> Bool
    let dragPayloadText: String?
    let keyboardAccessory: AnyView?
    let keyboardAccessoryHeight: CGFloat?
    let keyboardAccessoryReplacesKeyboard: Bool
    let minimumHeight: CGFloat
    let onContentHeightChange: (CGFloat) -> Void
    let onTextChange: (String) -> Void
    let onEditingEnded: () -> Void

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
        textView.blockID = blockID
        textView.blockType = blockType
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
        textView.onExtendBlockSelectionByKeyboard = onExtendBlockSelectionByKeyboard
        textView.onSlashCommandNavigationByKeyboard = onSlashCommandNavigationByKeyboard
        textView.onSlashCommandSelectionByKeyboard = onSlashCommandSelectionByKeyboard
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
        textView.onInlineLinkActivation = onInlineLinkActivation
        textView.onInsertBlockAfter = { selectedRange in
            onInsertBlockAfter(
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                )
            ) != nil
        }
        textView.onPasteTextAtSelection = { selectedRange, pasteText in
            onPasteTextAtSelection(
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                ),
                pasteText
            ) != nil
        }
        textView.onMergeBlockWithPrevious = { selectedRange in
            onMergeBlockWithPrevious(
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                )
            )
        }
        textView.onMergeBlockWithNext = { selectedRange in
            onMergeBlockWithNext(
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                )
            )
        }
        textView.onPasteAttachmentURLs = onPasteAttachmentURLs
        textView.onSelectCurrentTextByKeyboard = {
            context.coordinator.syncCurrentTextSelection(in: textView)
            return true
        }
        textView.onSelectCurrentBlockByKeyboard = {
            context.coordinator.selectCurrentBlock(in: textView)
            return true
        }
        textView.onSelectAllBlocksByKeyboard = onSelectAllBlocksByKeyboard
        textView.onCancelSelectionByKeyboard = onCancelSelectionByKeyboard
        textView.onPromoteBlockToPageByKeyboard = onPromoteBlockToPageByKeyboard
        textView.setAccessibilityIdentifier("editor.text.\(blockID)")
        textView.delegate = context.coordinator
        textView.font = nsFont
        textView.textColor = EditorDesignTokens.Colors.primaryText.nsColor
        textView.insertionPointColor = NativeTextCursorChrome.nsColor
        textView.defaultParagraphStyle = paragraphStyle
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isHorizontallyResizable = !lineWrapping
        textView.isVerticallyResizable = true
        textView.textContainerInset = NativeTextEditorLayout.textContainerInset
        textView.autoresizingMask = [.width]
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        configureLineWrapping(textView: textView)
        context.coordinator.applyModelText(
            context.coordinator.effectiveDisplayText(modelText: text),
            to: textView
        )
        context.coordinator.scheduleHeightMeasurement(for: textView)
        context.coordinator.handleFocusRequestIfNeeded(textView: textView)
        if textView.textLayoutManager == nil {
            EditorLog.input.error("textkit2_unavailable platform=macOS block_id=\(blockID, privacy: .public)")
        }
        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        context.coordinator.parent = self
        if let textView = textView as? EditorNSTextView {
            textView.blockID = blockID
            textView.blockType = blockType
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
            textView.onExtendBlockSelectionByKeyboard = onExtendBlockSelectionByKeyboard
            textView.onSlashCommandNavigationByKeyboard = onSlashCommandNavigationByKeyboard
            textView.onSlashCommandSelectionByKeyboard = onSlashCommandSelectionByKeyboard
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
            textView.onInlineLinkActivation = onInlineLinkActivation
            textView.onInsertBlockAfter = { selectedRange in
                onInsertBlockAfter(
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    )
                ) != nil
            }
            textView.onPasteTextAtSelection = { selectedRange, pasteText in
                onPasteTextAtSelection(
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    ),
                    pasteText
                ) != nil
            }
            textView.onMergeBlockWithPrevious = { selectedRange in
                onMergeBlockWithPrevious(
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    )
                )
            }
            textView.onMergeBlockWithNext = { selectedRange in
                onMergeBlockWithNext(
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    )
                )
            }
            textView.onPasteAttachmentURLs = onPasteAttachmentURLs
            textView.onSelectCurrentTextByKeyboard = {
                context.coordinator.syncCurrentTextSelection(in: textView)
                return true
            }
            textView.onSelectCurrentBlockByKeyboard = {
                context.coordinator.selectCurrentBlock(in: textView)
                return true
            }
            textView.onSelectAllBlocksByKeyboard = onSelectAllBlocksByKeyboard
            textView.onCancelSelectionByKeyboard = onCancelSelectionByKeyboard
            textView.onPromoteBlockToPageByKeyboard = onPromoteBlockToPageByKeyboard
        }
        let didResetBaseAttributes = applyBaseTextAttributes(to: textView)
        textView.insertionPointColor = NativeTextCursorChrome.nsColor
        textView.defaultParagraphStyle = paragraphStyle
        configureLineWrapping(textView: textView)
        let displayText = context.coordinator.effectiveDisplayText(modelText: text)
        if NativeTextCompositionPolicy.shouldApplyModelText(isComposing: textView.hasMarkedText()),
           textView.string != displayText {
            context.coordinator.applyModelText(displayText, to: textView)
        }
        if NativeTextCompositionPolicy.shouldApplyInlineMarkdownStyles(isComposing: textView.hasMarkedText()) {
            context.coordinator.applyTextStyles(to: textView, baseAttributesWereReset: didResetBaseAttributes)
        }
        context.coordinator.scheduleHeightMeasurement(for: textView)
        context.coordinator.handleFocusRequestIfNeeded(textView: textView)
    }

    @discardableResult
    private func applyBaseTextAttributes(to textView: NSTextView) -> Bool {
        var didResetAttributes = false
        if textView.font?.fontName != nsFont.fontName || textView.font?.pointSize != nsFont.pointSize {
            textView.font = nsFont
            didResetAttributes = true
        }
        let primaryTextColor = EditorDesignTokens.Colors.primaryText.nsColor
        if textView.textColor?.isEqual(primaryTextColor) != true {
            textView.textColor = primaryTextColor
            didResetAttributes = true
        }
        return didResetAttributes
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
        if let customFont = customNSFont {
            return customFont
        }

        switch blockType {
        case .heading1:
            return .systemFont(ofSize: 18, weight: .semibold)
        case .heading2:
            return .systemFont(ofSize: 16, weight: .semibold)
        case .heading3:
            return .systemFont(ofSize: 14, weight: .semibold)
        case .heading4:
            return .systemFont(ofSize: 13, weight: .semibold)
        case .heading5, .heading6:
            return .systemFont(ofSize: 12, weight: .semibold)
        case .codeBlock, .table:
            return .monospacedSystemFont(ofSize: 13, weight: .regular)
        default:
            return .systemFont(ofSize: EditorDesignTokens.Typography.bodySize, weight: .regular)
        }
    }

    private var customNSFont: NSFont? {
        guard let postScriptName = contentFont.postScriptName(for: blockType) else {
            return nil
        }
        EditorBundledFontRegistry.registerBundledFontsIfNeeded()
        return NSFont(name: postScriptName, size: nsFontSize)
    }

    private var nsFontSize: CGFloat {
        switch blockType {
        case .heading1:
            return 18
        case .heading2:
            return 16
        case .heading3:
            return 14
        case .heading4:
            return 13
        case .heading5, .heading6:
            return 12
        case .codeBlock, .table:
            return 13
        default:
            return CGFloat(EditorDesignTokens.Typography.bodySize)
        }
    }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = CGFloat(EditorDesignTokens.Typography.bodyLineHeightMultiple)
        return style
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlatformNativeTextView
        var textContentStorage: NSTextContentStorage?
        var textLayoutManager: NSTextLayoutManager?
        private var focusRequestState = NativeTextFocusRequestState()
        private var modelUpdateGuard = NativeTextModelUpdateGuard()
        private var isHeightMeasurementScheduled = false
        private var appliedStyleFingerprint: NativeTextStyleFingerprint?
        private var measuredHeightFingerprint: NativeTextHeightMeasurementFingerprint?
        private let codeSyntaxHighlighter = Highlight()
        private var codeSyntaxHighlightTask: Task<Void, Never>?
        private var deferredTextChangeSequence = 0

        init(parent: PlatformNativeTextView) {
            self.parent = parent
        }

        func applyModelText(_ text: String, to textView: NSTextView) {
            modelUpdateGuard.beginApplyingModelText()
            defer {
                modelUpdateGuard.finishApplyingModelText()
            }
            textView.string = text
            applyTextStyles(to: textView)
            scheduleHeightMeasurement(for: textView)
        }

        func effectiveDisplayText(modelText: String) -> String {
            NativeTextDisplayTextPolicy.effectiveText(
                modelText: modelText,
                draftText: parent.session.draftText(for: parent.blockID),
                acceptedTextInputMirror: parent.session.acceptedTextInputMirror(for: parent.blockID)
            )
        }

        func applyTextStyles(to textView: NSTextView, baseAttributesWereReset: Bool = false) {
            let nextFingerprint = styleFingerprint(for: textView)
            guard NativeTextStyleApplicationPolicy.shouldApplyStyle(
                cached: appliedStyleFingerprint,
                next: nextFingerprint,
                isComposing: textView.hasMarkedText(),
                baseAttributesWereReset: baseAttributesWereReset
            ) else {
                return
            }
            appliedStyleFingerprint = nextFingerprint

            guard parent.blockType == .codeBlock else {
                codeSyntaxHighlightTask?.cancel()
                applyInlineMarkdownStyles(to: textView)
                return
            }

            applyCodeBlockSyntaxHighlight(to: textView)
        }

        func applyInlineMarkdownStyles(to textView: NSTextView) {
            guard NativeTextCompositionPolicy.shouldApplyInlineMarkdownStyles(isComposing: textView.hasMarkedText()) else {
                return
            }
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

        private func styleFingerprint(for textView: NSTextView) -> NativeTextStyleFingerprint {
            NativeTextStyleFingerprint(
                blockType: parent.blockType,
                text: textView.string,
                fontName: parent.nsFont.fontName,
                fontSize: parent.nsFont.pointSize,
                lineHeightMultiple: CGFloat(EditorDesignTokens.Typography.bodyLineHeightMultiple)
            )
        }

        private func applyCodeBlockSyntaxHighlight(to textView: NSTextView) {
            guard NativeTextCompositionPolicy.shouldApplyInlineMarkdownStyles(isComposing: textView.hasMarkedText()),
                  let textStorage = textView.textStorage else {
                return
            }

            codeSyntaxHighlightTask?.cancel()
            let code = textView.string
            let fullRange = NSRange(location: 0, length: (code as NSString).length)
            guard fullRange.length > 0 else {
                modelUpdateGuard.beginApplyingModelText()
                textStorage.setAttributes(baseTextAttributes, range: fullRange)
                modelUpdateGuard.finishApplyingModelText()
                return
            }

            let baseAttributes = baseTextAttributes
            let colors = NativeCodeSyntaxHighlightChrome.colors(
                for: EditorThemeScheme(appearance: textView.effectiveAppearance)
            )
            codeSyntaxHighlightTask = Task { [weak self, weak textView, codeSyntaxHighlighter, colors] in
                do {
                    let highlighted = try await codeSyntaxHighlighter.attributedText(
                        code,
                        colors: colors
                    )
                    let highlightedString = try NSAttributedString(highlighted, including: \.appKit)
                    await MainActor.run { [weak self, weak textView] in
                        guard let self,
                              let textView,
                              !Task.isCancelled,
                              textView.string == code,
                              let textStorage = textView.textStorage else {
                            return
                        }

                        let selectedRange = textView.selectedRange()
                        let styled = CodeBlockSyntaxHighlightApplicator.attributedString(
                            text: code,
                            highlighted: highlightedString,
                            baseAttributes: baseAttributes,
                            allowedAttributeKeys: [.foregroundColor]
                        )
                        self.modelUpdateGuard.beginApplyingModelText()
                        textStorage.setAttributedString(styled)
                        textView.typingAttributes = baseAttributes
                        if NSMaxRange(selectedRange) <= styled.length {
                            textView.setSelectedRange(selectedRange)
                        }
                        self.modelUpdateGuard.finishApplyingModelText()
                    }
                } catch {
                    await MainActor.run { [weak self, weak textView] in
                        guard let self,
                              let textView,
                              textView.string == code,
                              let textStorage = textView.textStorage else {
                            return
                        }
                        self.modelUpdateGuard.beginApplyingModelText()
                        textStorage.setAttributes(baseAttributes, range: fullRange)
                        textView.typingAttributes = baseAttributes
                        self.modelUpdateGuard.finishApplyingModelText()
                    }
                }
            }
        }

        private var baseTextAttributes: [NSAttributedString.Key: Any] {
            [
                .font: parent.nsFont,
                .foregroundColor: EditorDesignTokens.Colors.primaryText.nsColor,
                .paragraphStyle: parent.paragraphStyle
            ]
        }

        private func attributes(for kind: MarkdownInlineStyleKind) -> [NSAttributedString.Key: Any] {
            switch kind {
            case .syntax:
                return NativeTextMarkdownSyntaxMarkerAttributes.appKit(baseFont: parent.nsFont)
            case .bold:
                return NativeInlineMarkdownFontVariantResolver.appKitBoldAttributes(baseFont: parent.nsFont)
            case .italic:
                return NativeInlineMarkdownFontVariantResolver.appKitItalicAttributes(baseFont: parent.nsFont)
            case .strikethrough:
                return [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
            case .highlight:
                return [.backgroundColor: NSColor.systemYellow.withAlphaComponent(0.35)]
            case .code:
                return [
                    .font: NSFont.monospacedSystemFont(ofSize: parent.nsFont.pointSize, weight: .regular),
                    .backgroundColor: NativeInlineMarkdownStyleChrome.inlineCodeBackgroundToken.nsColor
                ]
            case .link:
                return [
                    .foregroundColor: NSColor.linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.session.beginEditing(blockID: parent.blockID, reason: .userTap)
            parent.session.clearBlockSelection()
            if let textView = notification.object as? NSTextView {
                if updateSessionSelection(textView: textView) {
                    traceNativeSelectionPainted(textView: textView, source: "begin_editing")
                }
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
            let trace = EditorPerformanceTrace.begin("native_text_did_change") {
                [
                    "platform": "macOS",
                    "block_id": parent.blockID,
                    "text_length": "\(textView.string.count)",
                    "is_composing": "\(textView.hasMarkedText())"
                ]
            }
            if updateSessionSelection(textView: textView) {
                traceNativeSelectionPainted(textView: textView, source: "text_change")
            }
            updateSessionComposition(textView: textView)
            guard !textView.hasMarkedText() else {
                EditorPerformanceTrace.point("ime_composition_update") {
                    [
                        "platform": "macOS",
                        "block_id": parent.blockID,
                        "text_length": "\(textView.string.count)"
                    ]
                }
                scheduleHeightMeasurement(for: textView)
                EditorPerformanceTrace.end(trace, as: "native_text_did_change_composing_done")
                return
            }
            let nextText = textView.string
            let textLength = nextText.count
            parent.session.updateDraft(blockID: parent.blockID, text: nextText)
            EditorPerformanceTrace.point("character_painted") {
                [
                    "platform": "macOS",
                    "block_id": parent.blockID,
                    "text_length": "\(textLength)",
                    "source": "native_text_delegate"
                ]
            }
            EditorPerformanceTrace.nextRunLoopPoint("character_next_runloop_painted") {
                [
                    "platform": "macOS",
                    "block_id": parent.blockID,
                    "text_length": "\(textLength)",
                    "source": "main_queue_async"
                ]
            }
            EditorPerformanceTrace.end(trace)
            scheduleDeferredModelTextChange(nextText, textView: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard modelUpdateGuard.shouldForwardTextChange else {
                return
            }
            guard let textView = notification.object as? NSTextView else {
                return
            }
            if updateSessionSelection(textView: textView) {
                traceNativeSelectionPainted(textView: textView, source: "selection_change")
            }
            updateSessionComposition(textView: textView)
        }

        func textDidEndEditing(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                flushDeferredModelTextChange(textView.string)
            }
            parent.onEditingEnded()
            _ = parent.session.commitDraft(blockID: parent.blockID)
            parent.session.endEditing(blockID: parent.blockID)
        }

        private func scheduleDeferredModelTextChange(_ text: String, textView: NSTextView) {
            deferredTextChangeSequence += 1
            let sequence = deferredTextChangeSequence
            let blockID = parent.blockID
            Task { @MainActor [weak self, weak textView] in
                do {
                    try await Task.sleep(nanoseconds: NativeTextModelPropagationPolicy.debounceNanoseconds)
                } catch {
                    return
                }
                guard let self,
                      sequence == self.deferredTextChangeSequence else {
                    return
                }
                let trace = EditorPerformanceTrace.begin("native_text_model_update") {
                    [
                        "platform": "macOS",
                        "block_id": blockID,
                        "text_length": "\(text.count)",
                        "deferred": "true",
                        "debounce_ms": "\(NativeTextModelPropagationPolicy.debounceMilliseconds)"
                    ]
                }
                self.parent.onTextChange(text)
                if let textView {
                    self.applyTextStyles(to: textView)
                    self.scheduleHeightMeasurement(for: textView)
                }
                EditorPerformanceTrace.end(trace)
            }
        }

        private func flushDeferredModelTextChange(_ text: String) {
            deferredTextChangeSequence += 1
            parent.onTextChange(text)
        }

        func syncCurrentTextSelection(in textView: NSTextView) {
            if updateSessionSelection(textView: textView) {
                traceNativeSelectionPainted(textView: textView, source: "sync_selection")
            }
            parent.session.clearBlockSelection()
        }

        func selectCurrentBlock(in textView: NSTextView) {
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            textView.setSelectedRange(fullRange)
            if updateSessionSelection(textView: textView) {
                traceNativeSelectionPainted(textView: textView, source: "select_current_block")
            }
            parent.session.selectBlocks([parent.blockID])
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
                    self.scheduleFocusConfirmation(
                        textView: textView,
                        focusRequestID: focusRequestID,
                        remainingAttempts: remainingAttempts
                    )
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

        private func scheduleFocusConfirmation(
            textView: NSTextView,
            focusRequestID: UUID,
            remainingAttempts: Int
        ) {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + NativeTextFocusConfirmationPolicy.confirmationDelay
            ) { [weak textView, weak self] in
                guard let textView, let self else {
                    return
                }

                let isConfirmedFocused = self.isFocused(textView: textView)
                if NativeTextFocusConfirmationPolicy.shouldMarkRequestHandled(
                    didPerformFocus: true,
                    isFirstResponderAfterConfirmation: isConfirmedFocused
                ) {
                    self.focusRequestState.finish(requestID: focusRequestID, didFocus: true)
                    self.parent.session.beginEditing(blockID: self.parent.blockID, reason: .programmatic)
                    self.parent.onFocusRequestHandled()
                    return
                }

                guard NativeTextFocusConfirmationPolicy.shouldRetry(
                    didPerformFocus: true,
                    isFirstResponderAfterConfirmation: isConfirmedFocused,
                    remainingAttempts: remainingAttempts
                ) else {
                    self.focusRequestState.finish(requestID: focusRequestID, didFocus: false)
                    EditorLog.focus.debug(
                        "editor_focus_request_confirmation_failed block_id=\(self.parent.blockID, privacy: .public)"
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

        private func isFocused(textView: NSTextView) -> Bool {
            textView.window?.firstResponder === textView
        }

        private func updateSessionSelection(textView: NSTextView) -> Bool {
            let selectedRange = textView.selectedRange()
            return parent.session.updateSelection(
                blockID: parent.blockID,
                location: selectedRange.location,
                length: selectedRange.length
            )
        }

        private func traceNativeSelectionPainted(textView: NSTextView, source: String) {
            let selectedRange = textView.selectedRange()
            let eventName = selectedRange.length == 0 ? "cursor_painted" : "selection_painted"
            EditorPerformanceTrace.point(eventName) {
                [
                    "platform": "macOS",
                    "block_id": parent.blockID,
                    "location": "\(selectedRange.location)",
                    "length": "\(selectedRange.length)",
                    "source": source
                ]
            }
        }

        private func updateSessionComposition(textView: NSTextView) {
            parent.session.updateComposition(
                blockID: parent.blockID,
                isComposing: textView.hasMarkedText()
            )
        }

        func scheduleHeightMeasurement(for textView: NSTextView) {
            guard !isHeightMeasurementScheduled else {
                return
            }
            isHeightMeasurementScheduled = true
            DispatchQueue.main.async { [weak textView, weak self] in
                guard let textView, let self else {
                    return
                }
                self.isHeightMeasurementScheduled = false
                let nextFingerprint = self.heightMeasurementFingerprint(for: textView)
                guard NativeTextHeightMeasurementPolicy.shouldMeasureHeight(
                    cached: self.measuredHeightFingerprint,
                    next: nextFingerprint
                ) else {
                    return
                }
                self.measuredHeightFingerprint = nextFingerprint
                self.parent.onContentHeightChange(
                    self.measuredHeight(
                        for: textView,
                        width: nextFingerprint.width
                    )
                )
            }
        }

        private func heightMeasurementFingerprint(for textView: NSTextView) -> NativeTextHeightMeasurementFingerprint {
            NativeTextHeightMeasurementFingerprint(
                text: textView.string,
                width: measurementWidth(for: textView),
                lineWrapping: parent.lineWrapping,
                blockType: parent.blockType,
                fontName: parent.nsFont.fontName,
                fontSize: parent.nsFont.pointSize,
                minimumHeight: parent.minimumHeight,
                lineHeightMultiple: CGFloat(EditorDesignTokens.Typography.bodyLineHeightMultiple)
            )
        }

        private func measurementWidth(for textView: NSTextView) -> CGFloat {
            parent.lineWrapping ? max(textView.bounds.width, 320) : 10_000
        }

        private func measuredHeight(for textView: NSTextView, width: CGFloat) -> CGFloat {
            guard !textView.string.isEmpty else {
                return parent.minimumHeight
            }
            let boundingRect = textView.attributedString().boundingRect(
                with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            return NativeTextEditorLayout.measuredHeight(
                contentHeight: boundingRect.height,
                minimumHeight: parent.minimumHeight
            )
        }

        private func focusDelay(for remainingAttempts: Int) -> DispatchTimeInterval {
            remainingAttempts == 8 ? .milliseconds(0) : .milliseconds(35)
        }
    }
}

private final class EditorNSTextView: NSTextView {
    var blockID: String = ""
    var blockType: BlockType = .paragraph
    var onMouseDown: (() -> Void)?
    var onMouseFocusResult: ((Bool) -> Void)?
    var onKeyboardMove: ((BlockKeyboardMoveDirection) -> Bool)?
    var onKeyboardIndentation: ((BlockKeyboardIndentationDirection) -> Bool)?
    var onKeyboardFocusMove: ((BlockKeyboardFocusDirection) -> Bool)?
    var onExtendBlockSelectionByKeyboard: ((BlockKeyboardFocusDirection) -> Bool)?
    var onSlashCommandNavigationByKeyboard: ((BlockKeyboardMoveDirection) -> Bool)?
    var onSlashCommandSelectionByKeyboard: (() -> Bool)?
    var onKeyboardInlineFormat: ((MarkdownInlineFormat, NSRange) -> Bool)?
    var onKeyboardLinkInsertion: ((NSRange) -> Bool)?
    var onInlineLinkActivation: ((NativeInlineLinkActivation, NSRange) -> Bool)?
    var onInsertBlockAfter: ((NSRange) -> Bool)?
    var onPasteTextAtSelection: ((NSRange, String) -> Bool)?
    var onMergeBlockWithPrevious: ((NSRange) -> Bool)?
    var onMergeBlockWithNext: ((NSRange) -> Bool)?
    var onPasteAttachmentURLs: (([URL]) -> Bool)?
    var onSelectCurrentTextByKeyboard: (() -> Bool)?
    var onSelectCurrentBlockByKeyboard: (() -> Bool)?
    var onSelectAllBlocksByKeyboard: (() -> Bool)?
    var onCancelSelectionByKeyboard: (() -> Bool)?
    var onPromoteBlockToPageByKeyboard: (() -> Bool)?

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
        if handleInlineLinkActivation(at: event) {
            onMouseFocusResult?(window?.firstResponder === self)
            return
        }
        super.mouseDown(with: event)
        onMouseFocusResult?(window?.firstResponder === self)
    }

    private func handleInlineLinkActivation(at event: NSEvent) -> Bool {
        guard let onInlineLinkActivation else {
            return false
        }
        let point = convert(event.locationInWindow, from: nil)
        let characterIndex = characterIndexForInsertion(at: point)
        guard let activation = NativeInlineLinkActivationResolver.activation(
            text: string,
            characterIndex: characterIndex
        ) else {
            return false
        }
        guard NativeInlineLinkPointHitGuard.contains(
            point: point,
            linkBounds: renderedBounds(for: activation.range)
        ) else {
            return false
        }
        return onInlineLinkActivation(activation, selectedRange())
    }

    private func renderedBounds(for characterRange: NSRange) -> CGRect? {
        guard characterRange.length > 0 else {
            return nil
        }
        // AppKit only exposes the first rect here; this intentionally prefers false negatives for wrapped links.
        var actualRange = NSRange(location: NSNotFound, length: 0)
        let screenRect = firstRect(forCharacterRange: characterRange, actualRange: &actualRange)
        guard actualRange.location != NSNotFound,
              !screenRect.isNull,
              !screenRect.isEmpty,
              let window else {
            return nil
        }
        return convert(window.convertFromScreen(screenRect), from: nil)
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        super.drawInsertionPoint(
            in: NativeTextInsertionPointRectResolver.rect(
                original: rect,
                fontLineHeight: font?.boundingRectForFont.height
            ),
            color: NativeTextCursorChrome.nsColor,
            turnedOn: flag
        )
    }

    override func keyDown(with event: NSEvent) {
        EditorPerformanceTrace.point("keydown_start") {
            [
                "platform": "macOS",
                "block_id": blockID,
                "key_code": "\(event.keyCode)",
                "is_composing": "\(hasMarkedText())",
                "selection_location": "\(selectedRange().location)",
                "selection_length": "\(selectedRange().length)",
                "text_length": "\(string.count)"
            ]
        }
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: hasMarkedText()) else {
            super.keyDown(with: event)
            return
        }

        if BlockSelectAllKeyboardResolver.requestsSelectAll(
            input: event.charactersIgnoringModifiers,
            modifiers: event.blockKeyboardShortcutModifiers
        ), handleSelectAllByKeyboard() {
            return
        }

        if BlockSelectionCancelKeyboardResolver.requestsCancel(
            keyCode: event.keyCode,
            input: event.charactersIgnoringModifiers,
            modifiers: event.blockKeyboardShortcutModifiers
        ), handleCancelSelectionByKeyboard() {
            return
        }

        if let direction = BlockKeyboardShortcutResolver.moveDirection(
            keyCode: event.keyCode,
            modifiers: event.blockKeyboardShortcutModifiers
        ), onKeyboardMove?(direction) == true {
            return
        }

        if let direction = SlashCommandKeyboardResolver.navigationDirection(
            keyCode: event.keyCode,
            modifiers: event.blockKeyboardShortcutModifiers,
            text: string,
            selectedRange: selectedRange()
        ), onSlashCommandNavigationByKeyboard?(direction) == true {
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

        if DiaryPromotionKeyboardResolver.requestsPromotion(
            input: event.charactersIgnoringModifiers,
            modifiers: event.blockKeyboardShortcutModifiers
        ), onPromoteBlockToPageByKeyboard?() == true {
            return
        }

        if let direction = BlockKeyboardSelectionExtensionResolver.direction(
            keyCode: event.keyCode,
            modifiers: event.blockKeyboardShortcutModifiers,
            selectedRange: selectedRange(),
            text: string
        ), onExtendBlockSelectionByKeyboard?(direction) == true {
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
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: hasMarkedText()) else {
            return super.performKeyEquivalent(with: event)
        }

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

        if DiaryPromotionKeyboardResolver.requestsPromotion(
            input: event.charactersIgnoringModifiers,
            modifiers: event.blockKeyboardShortcutModifiers
        ), onPromoteBlockToPageByKeyboard?() == true {
            return true
        }

        if BlockSelectAllKeyboardResolver.requestsSelectAll(
            input: event.charactersIgnoringModifiers,
            modifiers: event.blockKeyboardShortcutModifiers
        ), handleSelectAllByKeyboard() {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func selectAll(_ sender: Any?) {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: hasMarkedText()) else {
            super.selectAll(sender)
            return
        }

        if handleSelectAllByKeyboard() {
            return
        }

        super.selectAll(sender)
    }

    private func handleSelectAllByKeyboard() -> Bool {
        switch BlockSelectAllKeyboardResolver.stage(blockType: blockType, selectedRange: selectedRange(), text: string) {
        case .currentText:
            super.selectAll(nil)
            _ = onSelectCurrentTextByKeyboard?()
            return true
        case .currentBlock:
            return onSelectCurrentBlockByKeyboard?() == true
        case .allBlocks:
            return onSelectAllBlocksByKeyboard?() == true
        }
    }

    private func handleCancelSelectionByKeyboard() -> Bool {
        var handled = false
        let currentRange = selectedRange()
        if currentRange.length > 0 {
            setSelectedRange(NSRange(location: currentRange.location + currentRange.length, length: 0))
            handled = true
        }
        if onCancelSelectionByKeyboard?() == true {
            handled = true
        }
        return handled
    }

    override func orderFrontLinkPanel(_ sender: Any?) {
        if onKeyboardLinkInsertion?(selectedRange()) == true {
            return
        }

        super.orderFrontLinkPanel(sender)
    }

    override func insertNewline(_ sender: Any?) {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: hasMarkedText()) else {
            super.insertNewline(sender)
            return
        }

        guard BlockKeyboardShortcutResolver.insertsBlockAfter(
            keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
            modifiers: [],
            blockType: blockType
        ) else {
            super.insertNewline(sender)
            return
        }

        if SlashCommandKeyboardResolver.requestsSelection(
            keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
            modifiers: [],
            text: string,
            selectedRange: selectedRange()
        ), onSlashCommandSelectionByKeyboard?() == true {
            return
        }

        if onInsertBlockAfter?(selectedRange()) == true {
            return
        }

        super.insertNewline(sender)
    }

    override func deleteBackward(_ sender: Any?) {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: hasMarkedText()) else {
            super.deleteBackward(sender)
            return
        }

        if onMergeBlockWithPrevious?(selectedRange()) == true {
            return
        }

        super.deleteBackward(sender)
    }

    override func deleteForward(_ sender: Any?) {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: hasMarkedText()) else {
            super.deleteForward(sender)
            return
        }

        if onMergeBlockWithNext?(selectedRange()) == true {
            return
        }

        super.deleteForward(sender)
    }

    override func paste(_ sender: Any?) {
        let attachmentURLs = MacPasteboardAttachmentResolver.attachmentURLs(from: NSPasteboard.general)
        if !attachmentURLs.isEmpty,
           onPasteAttachmentURLs?(attachmentURLs) == true {
            return
        }

        if let pasteText = NSPasteboard.general.string(forType: .string),
           NativeTextPasteSplitPolicy.shouldRouteToBlockPaste(text: pasteText, blockType: blockType),
           onPasteTextAtSelection?(selectedRange(), pasteText) == true {
            return
        }

        super.paste(sender)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        NativeTextDropPolicy.acceptsDropIntoTextEditor ? super.draggingEntered(sender) : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        NativeTextDropPolicy.acceptsDropIntoTextEditor ? super.draggingUpdated(sender) : []
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        NativeTextDropPolicy.acceptsDropIntoTextEditor && super.prepareForDragOperation(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        NativeTextDropPolicy.acceptsDropIntoTextEditor && super.performDragOperation(sender)
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

enum IOSPasteboardAttachmentResolver {
    static func attachmentURLs(from pasteboard: UIPasteboard) -> [URL] {
        let fileURLs = fileURLs(from: pasteboard)
        if !fileURLs.isEmpty {
            return fileURLs
        }

        let images = pasteboard.images ?? pasteboard.image.map { [$0] } ?? []
        return images.compactMap(writeTemporaryClipboardImage)
    }

    private static func fileURLs(from pasteboard: UIPasteboard) -> [URL] {
        let urls = pasteboard.urls ?? pasteboard.url.map { [$0] } ?? []
        return urls.filter(\.isFileURL)
    }

    private static func writeTemporaryClipboardImage(_ image: UIImage) -> URL? {
        guard let pngData = image.pngData() else {
            return nil
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("editor-clipboard-\(UUID().uuidString.lowercased()).png")
        do {
            try pngData.write(to: url, options: .atomic)
            return url
        } catch {
            EditorLog.attachment.error(
                "ios_clipboard_image_write_failed error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }
}

private final class EditorKeyboardAccessoryContainerView: UIInputView {
    private var heightConstraint: NSLayoutConstraint?

    var accessoryHeight: CGFloat {
        didSet {
            heightConstraint?.constant = accessoryHeight
            invalidateIntrinsicContentSize()
        }
    }

    init(height: CGFloat) {
        accessoryHeight = height
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height), inputViewStyle: .keyboard)
        allowsSelfSizing = true
        autoresizingMask = [.flexibleWidth]
        backgroundColor = .clear
        let constraint = heightAnchor.constraint(equalToConstant: height)
        constraint.priority = .required
        constraint.isActive = true
        heightConstraint = constraint
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: accessoryHeight)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width > 0 ? size.width : UIScreen.main.bounds.width, height: accessoryHeight)
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        CGSize(width: targetSize.width > 0 ? targetSize.width : UIScreen.main.bounds.width, height: accessoryHeight)
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        CGSize(width: targetSize.width > 0 ? targetSize.width : UIScreen.main.bounds.width, height: accessoryHeight)
    }
}

private struct PlatformNativeTextView: UIViewRepresentable {
    let blockID: String
    let text: String
    let blockType: BlockType
    let contentFont: EditorContentFont
    let session: EditorSession
    let lineWrapping: Bool
    let focusRequestID: UUID?
    let focusSelection: EditorTextSelection?
    let onFocusRequestHandled: () -> Void
    let onMoveByKeyboard: (BlockKeyboardMoveDirection) -> Bool
    let onIndentationByKeyboard: (BlockKeyboardIndentationDirection) -> Bool
    let onMoveFocusByKeyboard: (BlockKeyboardFocusDirection) -> Bool
    let onExtendBlockSelectionByKeyboard: (BlockKeyboardFocusDirection) -> Bool
    let onApplyInlineFormatByKeyboard: (MarkdownInlineFormat, EditorTextSelection) -> Bool
    let onInsertLinkByKeyboard: (EditorTextSelection) -> Bool
    let onInlineLinkActivation: ((NativeInlineLinkActivation, NSRange) -> Bool)?
    let onInsertBlockAfter: (EditorTextSelection) -> EditorTextSelection?
    let onReplaceTextAtSelection: (EditorTextSelection, String) -> EditorTextSelection?
    let onPasteTextAtSelection: (EditorTextSelection, String) -> EditorTextSelection?
    let onMergeBlockWithPrevious: (EditorTextSelection) -> Bool
    let onMergeBlockWithNext: (EditorTextSelection) -> Bool
    let onSlashCommandNavigationByKeyboard: (BlockKeyboardMoveDirection) -> Bool
    let onSlashCommandSelectionByKeyboard: () -> Bool
    let onPasteAttachmentURLs: ([URL]) -> Bool
    let onSelectAllBlocksByKeyboard: () -> Bool
    let onCancelSelectionByKeyboard: () -> Bool
    let onPromoteBlockToPageByKeyboard: () -> Bool
    let onHorizontalSwipe: (CGFloat) -> Bool
    let dragPayloadText: String?
    let keyboardAccessory: AnyView?
    let keyboardAccessoryHeight: CGFloat?
    let keyboardAccessoryReplacesKeyboard: Bool
    let minimumHeight: CGFloat
    let onContentHeightChange: (CGFloat) -> Void
    let onTextChange: (String) -> Void
    let onEditingEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = EditorUITextView(usingTextLayoutManager: true)
        textView.blockID = blockID
        textView.blockType = blockType
        textView.onKeyboardMove = onMoveByKeyboard
        textView.onKeyboardIndentation = onIndentationByKeyboard
        textView.onKeyboardFocusMove = onMoveFocusByKeyboard
        textView.onExtendBlockSelectionByKeyboard = onExtendBlockSelectionByKeyboard
        textView.onSlashCommandNavigationByKeyboard = onSlashCommandNavigationByKeyboard
        textView.onSlashCommandSelectionByKeyboard = onSlashCommandSelectionByKeyboard
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
        textView.onInlineLinkActivation = onInlineLinkActivation
        textView.onInsertBlockAfter = { selectedRange in
            onInsertBlockAfter(
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                )
            ) != nil
        }
        textView.onPasteTextAtSelection = { selectedRange, pasteText in
            onPasteTextAtSelection(
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                ),
                pasteText
            ) != nil
        }
        textView.onMergeBlockWithPrevious = { selectedRange in
            onMergeBlockWithPrevious(
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                )
            )
        }
        textView.onMergeBlockWithNext = { selectedRange in
            onMergeBlockWithNext(
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                )
            )
        }
        textView.onSelectCurrentTextByKeyboard = {
            context.coordinator.syncCurrentTextSelection(in: textView)
            return true
        }
        textView.onSelectCurrentBlockByKeyboard = {
            context.coordinator.selectCurrentBlock(in: textView)
            return true
        }
        textView.onSelectAllBlocksByKeyboard = onSelectAllBlocksByKeyboard
        textView.onCancelSelectionByKeyboard = onCancelSelectionByKeyboard
        textView.onPromoteBlockToPageByKeyboard = onPromoteBlockToPageByKeyboard
        textView.onPasteAttachmentURLs = onPasteAttachmentURLs
        textView.onHorizontalSwipe = onHorizontalSwipe
        textView.installHorizontalSwipeRecognizersIfNeeded()
        textView.installInlineLinkTapRecognizerIfNeeded()
        textView.textDragDelegate = context.coordinator
        if MobileNativeTextBlockDragPolicy.disablesSystemTextDragInteraction {
            textView.textDragInteraction?.isEnabled = false
        } else {
            textView.textDragInteraction?.isEnabled = true
        }
        if MobileNativeTextBlockDragPolicy.disablesSystemTextDropInteraction {
            textView.disableSystemTextDropInteractionIfNeeded()
        }
        if MobileNativeTextBlockDragPolicy.installsUIDragInteraction {
            textView.installBlockDragInteractionIfNeeded(delegate: context.coordinator)
        }
        textView.accessibilityIdentifier = "editor.text.\(blockID)"
        textView.delegate = context.coordinator
        textView.font = uiFont
        textView.textColor = EditorDesignTokens.Colors.primaryText.uiColor
        textView.tintColor = NativeTextCursorChrome.uiColor
        textView.typingAttributes = baseTextAttributes
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = NativeTextEditorLayout.uiTextContainerInset
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.showsHorizontalScrollIndicator = false
        textView.alwaysBounceHorizontal = false
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        configureLineWrapping(textView: textView)
        textView.adjustsFontForContentSizeCategory = true
        context.coordinator.applyModelText(text, to: textView)
        context.coordinator.configureKeyboardAccessory(
            keyboardAccessory,
            height: keyboardAccessoryHeight,
            replacesKeyboard: keyboardAccessoryReplacesKeyboard,
            for: textView
        )
        context.coordinator.scheduleHeightMeasurement(for: textView)
        if textView.textLayoutManager == nil {
            EditorLog.input.error("textkit2_unavailable platform=iOS block_id=\(blockID, privacy: .public)")
        }
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        if let textView = textView as? EditorUITextView {
            textView.blockID = blockID
            textView.blockType = blockType
            textView.onKeyboardMove = onMoveByKeyboard
            textView.onKeyboardIndentation = onIndentationByKeyboard
            textView.onKeyboardFocusMove = onMoveFocusByKeyboard
            textView.onExtendBlockSelectionByKeyboard = onExtendBlockSelectionByKeyboard
            textView.onSlashCommandNavigationByKeyboard = onSlashCommandNavigationByKeyboard
            textView.onSlashCommandSelectionByKeyboard = onSlashCommandSelectionByKeyboard
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
            textView.onInlineLinkActivation = onInlineLinkActivation
            textView.onInsertBlockAfter = { selectedRange in
                onInsertBlockAfter(
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    )
                ) != nil
            }
            textView.onPasteTextAtSelection = { selectedRange, pasteText in
                onPasteTextAtSelection(
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    ),
                    pasteText
                ) != nil
            }
            textView.onMergeBlockWithPrevious = { selectedRange in
                onMergeBlockWithPrevious(
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    )
                )
            }
            textView.onMergeBlockWithNext = { selectedRange in
                onMergeBlockWithNext(
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    )
                )
            }
            textView.onSelectCurrentTextByKeyboard = {
                context.coordinator.syncCurrentTextSelection(in: textView)
                return true
            }
            textView.onSelectCurrentBlockByKeyboard = {
                context.coordinator.selectCurrentBlock(in: textView)
                return true
            }
            textView.onSelectAllBlocksByKeyboard = onSelectAllBlocksByKeyboard
            textView.onCancelSelectionByKeyboard = onCancelSelectionByKeyboard
            textView.onPromoteBlockToPageByKeyboard = onPromoteBlockToPageByKeyboard
            textView.onPasteAttachmentURLs = onPasteAttachmentURLs
            textView.onHorizontalSwipe = onHorizontalSwipe
            textView.installHorizontalSwipeRecognizersIfNeeded()
            textView.installInlineLinkTapRecognizerIfNeeded()
            textView.textDragDelegate = context.coordinator
            if MobileNativeTextBlockDragPolicy.disablesSystemTextDragInteraction {
                textView.textDragInteraction?.isEnabled = false
            } else {
                textView.textDragInteraction?.isEnabled = true
            }
            if MobileNativeTextBlockDragPolicy.disablesSystemTextDropInteraction {
                textView.disableSystemTextDropInteractionIfNeeded()
            }
            if MobileNativeTextBlockDragPolicy.installsUIDragInteraction {
                textView.installBlockDragInteractionIfNeeded(delegate: context.coordinator)
            }
        }
        let didResetBaseAttributes = applyBaseTextAttributes(to: textView)
        textView.tintColor = NativeTextCursorChrome.uiColor
        textView.typingAttributes = baseTextAttributes
        configureLineWrapping(textView: textView)
        let displayText = context.coordinator.effectiveDisplayText(modelText: text)
        if NativeTextCompositionPolicy.shouldApplyModelText(isComposing: textView.markedTextRange != nil),
           textView.text != displayText {
            context.coordinator.applyModelText(displayText, to: textView)
        }
        context.coordinator.configureKeyboardAccessory(
            keyboardAccessory,
            height: keyboardAccessoryHeight,
            replacesKeyboard: keyboardAccessoryReplacesKeyboard,
            for: textView
        )
        if NativeTextCompositionPolicy.shouldApplyInlineMarkdownStyles(isComposing: textView.markedTextRange != nil) {
            context.coordinator.applyTextStyles(to: textView, baseAttributesWereReset: didResetBaseAttributes)
        }
        context.coordinator.scheduleHeightMeasurement(for: textView)
        context.coordinator.handleFocusRequestIfNeeded(textView: textView)
    }

    @discardableResult
    private func applyBaseTextAttributes(to textView: UITextView) -> Bool {
        var didResetAttributes = false
        if textView.font?.fontName != uiFont.fontName || textView.font?.pointSize != uiFont.pointSize {
            textView.font = uiFont
            didResetAttributes = true
        }
        let primaryTextColor = EditorDesignTokens.Colors.primaryText.uiColor
        if textView.textColor?.isEqual(primaryTextColor) != true {
            textView.textColor = primaryTextColor
            didResetAttributes = true
        }
        return didResetAttributes
    }

    private func configureLineWrapping(textView: UITextView) {
        textView.textContainer.lineBreakMode = lineWrapping ? .byCharWrapping : .byClipping
        if lineWrapping {
            textView.textContainer.widthTracksTextView = true
        }
    }

    private var uiFont: UIFont {
        if let customFont = customUIFont {
            return customFont
        }

        switch blockType {
        case .heading1:
            return .systemFont(ofSize: 28, weight: .semibold)
        case .heading2:
            return .systemFont(ofSize: 24, weight: .semibold)
        case .heading3:
            return .systemFont(ofSize: 20, weight: .semibold)
        case .heading4:
            return .systemFont(ofSize: 18, weight: .semibold)
        case .heading5, .heading6:
            return .systemFont(ofSize: 17, weight: .semibold)
        case .codeBlock, .table:
            return .monospacedSystemFont(ofSize: 16, weight: .regular)
        default:
            return .systemFont(ofSize: 18, weight: .regular)
        }
    }

    private var customUIFont: UIFont? {
        guard let postScriptName = contentFont.postScriptName(for: blockType) else {
            return nil
        }
        EditorBundledFontRegistry.registerBundledFontsIfNeeded()
        return UIFont(name: postScriptName, size: uiFontSize)
    }

    private var uiFontSize: CGFloat {
        switch blockType {
        case .heading1:
            return 28
        case .heading2:
            return 24
        case .heading3:
            return 20
        case .heading4:
            return 18
        case .heading5, .heading6:
            return 17
        case .codeBlock, .table:
            return 16
        default:
            return 18
        }
    }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = CGFloat(EditorDesignTokens.Typography.bodyLineHeightMultiple)
        return style
    }

    private var baseTextAttributes: [NSAttributedString.Key: Any] {
        [
            .font: uiFont,
            .foregroundColor: EditorDesignTokens.Colors.primaryText.uiColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate, UITextDragDelegate, UIDragInteractionDelegate {
        var parent: PlatformNativeTextView
        private var focusRequestState = NativeTextFocusRequestState()
        private var modelUpdateGuard = NativeTextModelUpdateGuard()
        private var isHeightMeasurementScheduled = false
        private var appliedStyleFingerprint: NativeTextStyleFingerprint?
        private var measuredHeightFingerprint: NativeTextHeightMeasurementFingerprint?
        private let codeSyntaxHighlighter = Highlight()
        private var codeSyntaxHighlightTask: Task<Void, Never>?
        private var keyboardAccessoryHostingController: UIHostingController<AnyView>?
        private var keyboardAccessoryContainer: EditorKeyboardAccessoryContainerView?
        private var configuredKeyboardAccessoryHeight: CGFloat?
        private var configuredKeyboardReplacesKeyboard = false
        private var pendingPostSplitTextSelection: EditorTextSelection?
        private var deferredTextChangeSequence = 0
        private var acceptedTextFallbackMirror: String?

        init(parent: PlatformNativeTextView) {
            self.parent = parent
        }

        func configureKeyboardAccessory(
            _ accessory: AnyView?,
            height: CGFloat?,
            replacesKeyboard: Bool,
            for textView: UITextView
        ) {
            guard let accessory else {
                let needsReload = textView.inputAccessoryView != nil || textView.inputView != nil
                if let container = keyboardAccessoryContainer,
                   textView.inputAccessoryView === container {
                    textView.inputAccessoryView = nil
                }
                if textView.inputView != nil {
                    textView.inputView = nil
                }
                keyboardAccessoryHostingController = nil
                keyboardAccessoryContainer = nil
                configuredKeyboardAccessoryHeight = nil
                configuredKeyboardReplacesKeyboard = false
                if needsReload, textView.isFirstResponder {
                    textView.reloadInputViews()
                }
                return
            }

            let effectiveHeight = height ?? NativeTextEditorLayout.keyboardToolbarHeight
            let wasReplacingKeyboard = configuredKeyboardReplacesKeyboard
            let keyboardModeChanged = wasReplacingKeyboard != replacesKeyboard
            let shouldRestoreSystemKeyboard = NativeTextKeyboardRestorePolicy.shouldRestoreSystemKeyboard(
                wasReplacingKeyboard: wasReplacingKeyboard,
                replacesKeyboard: replacesKeyboard,
                isTextViewFirstResponder: textView.isFirstResponder
            )
            let container: EditorKeyboardAccessoryContainerView
            if let hostingController = keyboardAccessoryHostingController, !keyboardModeChanged {
                hostingController.rootView = accessory
                container = keyboardAccessoryContainer ?? EditorKeyboardAccessoryContainerView(height: effectiveHeight)
            } else {
                let newContainer = EditorKeyboardAccessoryContainerView(height: effectiveHeight)
                newContainer.accessibilityIdentifier = "editor.mobile-format-accessory"
                let hostingController = UIHostingController(rootView: accessory)
                hostingController.view.backgroundColor = .clear
                hostingController.view.translatesAutoresizingMaskIntoConstraints = false
                newContainer.addSubview(hostingController.view)
                NSLayoutConstraint.activate([
                    hostingController.view.leadingAnchor.constraint(equalTo: newContainer.leadingAnchor),
                    hostingController.view.trailingAnchor.constraint(equalTo: newContainer.trailingAnchor),
                    hostingController.view.topAnchor.constraint(equalTo: newContainer.topAnchor),
                    hostingController.view.bottomAnchor.constraint(equalTo: newContainer.bottomAnchor)
                ])
                keyboardAccessoryHostingController = hostingController
                keyboardAccessoryContainer = newContainer
                container = newContainer
            }

            let heightChanged = configuredKeyboardAccessoryHeight != effectiveHeight
            if heightChanged {
                container.accessoryHeight = effectiveHeight
                container.frame.size.height = effectiveHeight
            }

            var needsReload = heightChanged || keyboardModeChanged
            if replacesKeyboard {
                if textView.inputAccessoryView != nil {
                    textView.inputAccessoryView = nil
                    needsReload = true
                }
                if textView.inputView !== container || heightChanged {
                    if textView.inputView === container {
                        textView.inputView = nil
                    }
                    textView.inputView = container
                    needsReload = true
                }
            } else {
                if textView.inputView != nil {
                    textView.inputView = nil
                    needsReload = true
                }
                let accessoryChanged = textView.inputAccessoryView !== container
                if accessoryChanged || heightChanged {
                    if heightChanged, !accessoryChanged {
                        textView.inputAccessoryView = nil
                    }
                    textView.inputAccessoryView = container
                    needsReload = true
                }
            }

            configuredKeyboardAccessoryHeight = effectiveHeight
            configuredKeyboardReplacesKeyboard = replacesKeyboard

            if textView.isFirstResponder, needsReload {
                textView.reloadInputViews()
            }
            if shouldRestoreSystemKeyboard {
                DispatchQueue.main.async { [weak textView] in
                    guard let textView, textView.window != nil else {
                        return
                    }
                    guard NativeTextKeyboardRestorePolicy.shouldRestoreSystemKeyboard(
                        wasReplacingKeyboard: true,
                        replacesKeyboard: false,
                        isTextViewFirstResponder: textView.isFirstResponder
                    ) else {
                        return
                    }
                    textView.resignFirstResponder()
                    textView.becomeFirstResponder()
                }
            }
        }

        func applyModelText(_ text: String, to textView: UITextView) {
            modelUpdateGuard.beginApplyingModelText()
            defer {
                modelUpdateGuard.finishApplyingModelText()
            }
            acceptedTextFallbackMirror = text
            textView.text = text
            applyTextStyles(to: textView)
            scheduleHeightMeasurement(for: textView)
        }

        func effectiveDisplayText(modelText: String) -> String {
            NativeTextDisplayTextPolicy.effectiveText(
                modelText: modelText,
                draftText: parent.session.draftText(for: parent.blockID),
                acceptedTextInputMirror: parent.session.acceptedTextInputMirror(for: parent.blockID)
            )
        }

        func applyTextStyles(to textView: UITextView, baseAttributesWereReset: Bool = false) {
            let nextFingerprint = styleFingerprint(for: textView)
            guard NativeTextStyleApplicationPolicy.shouldApplyStyle(
                cached: appliedStyleFingerprint,
                next: nextFingerprint,
                isComposing: textView.markedTextRange != nil,
                baseAttributesWereReset: baseAttributesWereReset
            ) else {
                return
            }
            appliedStyleFingerprint = nextFingerprint

            guard parent.blockType == .codeBlock else {
                codeSyntaxHighlightTask?.cancel()
                applyInlineMarkdownStyles(to: textView)
                return
            }

            applyCodeBlockSyntaxHighlight(to: textView)
        }

        func applyInlineMarkdownStyles(to textView: UITextView) {
            guard NativeTextCompositionPolicy.shouldApplyInlineMarkdownStyles(isComposing: textView.markedTextRange != nil) else {
                return
            }
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

        private func styleFingerprint(for textView: UITextView) -> NativeTextStyleFingerprint {
            NativeTextStyleFingerprint(
                blockType: parent.blockType,
                text: textView.text ?? "",
                fontName: parent.uiFont.fontName,
                fontSize: parent.uiFont.pointSize,
                lineHeightMultiple: CGFloat(EditorDesignTokens.Typography.bodyLineHeightMultiple)
            )
        }

        private func applyCodeBlockSyntaxHighlight(to textView: UITextView) {
            guard NativeTextCompositionPolicy.shouldApplyInlineMarkdownStyles(isComposing: textView.markedTextRange != nil) else {
                return
            }

            codeSyntaxHighlightTask?.cancel()
            let code = textView.text ?? ""
            let fullRange = NSRange(location: 0, length: (code as NSString).length)
            guard fullRange.length > 0 else {
                modelUpdateGuard.beginApplyingModelText()
                textView.textStorage.setAttributes(baseTextAttributes, range: fullRange)
                modelUpdateGuard.finishApplyingModelText()
                return
            }

            let baseAttributes = baseTextAttributes
            let colors = NativeCodeSyntaxHighlightChrome.colors(
                for: textView.traitCollection.userInterfaceStyle == .dark ? .dark : .light
            )
            codeSyntaxHighlightTask = Task { [weak self, weak textView, codeSyntaxHighlighter, colors] in
                do {
                    let highlighted = try await codeSyntaxHighlighter.attributedText(
                        code,
                        colors: colors
                    )
                    let highlightedString = try NSAttributedString(highlighted, including: \.uiKit)
                    await MainActor.run { [weak self, weak textView] in
                        guard let self,
                              let textView,
                              !Task.isCancelled,
                              textView.text == code else {
                            return
                        }

                        let selectedRange = textView.selectedRange
                        let styled = CodeBlockSyntaxHighlightApplicator.attributedString(
                            text: code,
                            highlighted: highlightedString,
                            baseAttributes: baseAttributes,
                            allowedAttributeKeys: [.foregroundColor]
                        )
                        self.modelUpdateGuard.beginApplyingModelText()
                        textView.textStorage.setAttributedString(styled)
                        textView.typingAttributes = baseAttributes
                        if NSMaxRange(selectedRange) <= styled.length {
                            textView.selectedRange = selectedRange
                        }
                        self.modelUpdateGuard.finishApplyingModelText()
                    }
                } catch {
                    await MainActor.run { [weak self, weak textView] in
                        guard let self,
                              let textView,
                              textView.text == code else {
                            return
                        }
                        self.modelUpdateGuard.beginApplyingModelText()
                        textView.textStorage.setAttributes(baseAttributes, range: fullRange)
                        textView.typingAttributes = baseAttributes
                        self.modelUpdateGuard.finishApplyingModelText()
                    }
                }
            }
        }

        private var baseTextAttributes: [NSAttributedString.Key: Any] {
            [
                .font: parent.uiFont,
                .foregroundColor: EditorDesignTokens.Colors.primaryText.uiColor,
                .paragraphStyle: parent.paragraphStyle
            ]
        }

        private func attributes(for kind: MarkdownInlineStyleKind) -> [NSAttributedString.Key: Any] {
            switch kind {
            case .syntax:
                return NativeTextMarkdownSyntaxMarkerAttributes.uiKit(baseFont: parent.uiFont)
            case .bold:
                return NativeInlineMarkdownFontVariantResolver.uiKitBoldAttributes(baseFont: parent.uiFont)
            case .italic:
                return NativeInlineMarkdownFontVariantResolver.uiKitItalicAttributes(baseFont: parent.uiFont)
            case .strikethrough:
                return [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
            case .highlight:
                return [.backgroundColor: UIColor.systemYellow.withAlphaComponent(0.35)]
            case .code:
                return [
                    .font: UIFont.monospacedSystemFont(ofSize: parent.uiFont.pointSize, weight: .regular),
                    .backgroundColor: NativeInlineMarkdownStyleChrome.inlineCodeBackgroundToken.uiColor
                ]
            case .link:
                return [
                    .foregroundColor: UIColor.link,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            EditorPerformanceTrace.point("mobile_editor_focus_start") {
                [
                    "block_id": parent.blockID,
                    "view": "native_text_view"
                ].merging(MobileKeyboardPerformanceState.metadata) { _, new in new }
            }
            parent.session.beginEditing(blockID: parent.blockID, reason: .userTap)
            parent.session.clearBlockSelection()
            if updateSessionSelection(textView: textView) {
                traceNativeSelectionPainted(textView: textView, source: "begin_editing")
            }
            updateSessionComposition(textView: textView)
            traceMobileCursorVisibility(textView: textView, source: "begin_editing")
        }

        func textViewDidChange(_ textView: UITextView) {
            guard modelUpdateGuard.shouldForwardTextChange else {
                return
            }
            let trace = EditorPerformanceTrace.begin("native_text_did_change") {
                [
                    "platform": "iOS",
                    "block_id": parent.blockID,
                    "text_length": "\(textView.text.count)",
                    "is_composing": "\(textView.markedTextRange != nil)"
                ]
            }
            if updateSessionSelection(textView: textView) {
                traceNativeSelectionPainted(textView: textView, source: "text_change")
            }
            updateSessionComposition(textView: textView)
            guard textView.markedTextRange == nil else {
                EditorPerformanceTrace.point("ime_composition_update") {
                    [
                        "platform": "iOS",
                        "block_id": parent.blockID,
                        "text_length": "\(textView.text.count)"
                    ]
                }
                scheduleHeightMeasurement(for: textView)
                EditorPerformanceTrace.end(trace, as: "native_text_did_change_composing_done")
                return
            }
            let nextText = textView.text ?? ""
            let textLength = nextText.count
            acceptedTextFallbackMirror = nextText
            parent.session.updateAcceptedTextInputMirror(blockID: parent.blockID, text: nextText)
            parent.session.updateDraft(blockID: parent.blockID, text: nextText)
            EditorPerformanceTrace.point("character_painted") {
                [
                    "platform": "iOS",
                    "block_id": parent.blockID,
                    "text_length": "\(textLength)",
                    "source": "native_text_delegate"
                ]
            }
            EditorPerformanceTrace.nextRunLoopPoint("character_next_runloop_painted") {
                [
                    "platform": "iOS",
                    "block_id": parent.blockID,
                    "text_length": "\(textLength)",
                    "source": "main_queue_async"
                ]
            }
            EditorPerformanceTrace.end(trace)
            scheduleDeferredModelTextChange(nextText, textView: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard modelUpdateGuard.shouldForwardTextChange else {
                return
            }
            if updateSessionSelection(textView: textView) {
                traceNativeSelectionPainted(textView: textView, source: "selection_change")
            }
            updateSessionComposition(textView: textView)
            traceMobileCursorVisibility(textView: textView, source: "selection_change")
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            EditorPerformanceTrace.point("keydown_start") {
                [
                    "platform": "iOS",
                    "block_id": parent.blockID,
                    "is_composing": "\(textView.markedTextRange != nil)",
                    "replacement_length": "\((text as NSString).length)",
                    "selection_location": "\(range.location)",
                    "selection_length": "\(range.length)",
                    "text_length": "\(textView.text.count)"
                ]
            }
            guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: textView.markedTextRange != nil) else {
                return true
            }
            if let redirectSelection = pendingPostSplitTextSelection,
               !text.isEmpty,
               text.rangeOfCharacter(from: .newlines) == nil {
                guard let nextSelection = parent.onReplaceTextAtSelection(redirectSelection, text) else {
                    pendingPostSplitTextSelection = nil
                    return true
                }
                pendingPostSplitTextSelection = nextSelection
                return false
            }
            if text.isEmpty, range.location == 0, range.length == 0 {
                return !parent.onMergeBlockWithPrevious(
                    EditorTextSelection(
                        blockID: parent.blockID,
                        location: range.location,
                        length: range.length
                    )
                )
            }
            if text.rangeOfCharacter(from: .newlines) == nil {
                scheduleAcceptedTextChangeFallback(textView: textView, range: range, replacementText: text)
                return true
            }
            guard NativeTextNewlineReplacementResolver.isSingleNewline(text)
                    || text.rangeOfCharacter(from: .newlines) != nil else {
                return true
            }
            guard BlockKeyboardShortcutResolver.insertsBlockAfter(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: [],
                blockType: parent.blockType
            ) else {
                return true
            }

            if SlashCommandKeyboardResolver.requestsSelection(
                keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
                modifiers: [],
                text: textView.text,
                selectedRange: range
            ), parent.onSlashCommandSelectionByKeyboard() {
                return false
            }

            if !NativeTextNewlineReplacementResolver.isSingleNewline(text),
               let nextSelection = parent.onPasteTextAtSelection(
                   EditorTextSelection(
                       blockID: parent.blockID,
                       location: range.location,
                       length: range.length
                   ),
                   text
               ) {
                pendingPostSplitTextSelection = nextSelection
                return false
            }

            guard let nextSelection = parent.onInsertBlockAfter(
                EditorTextSelection(
                    blockID: parent.blockID,
                    location: range.location,
                    length: range.length
                )
            ) else {
                return true
            }
            pendingPostSplitTextSelection = nextSelection
            return false
        }

        private func scheduleAcceptedTextChangeFallback(
            textView: UITextView,
            range: NSRange,
            replacementText text: String
        ) {
            let currentText = (textView.text ?? "") as NSString
            guard range.location >= 0,
                  range.length >= 0,
                  range.location <= currentText.length,
                  range.length <= currentText.length - range.location else {
                return
            }

            guard let proposal = NativeTextAcceptedChangeFallbackTextPolicy.proposal(
                currentText: currentText as String,
                mirrorText: acceptedTextFallbackMirror
                    ?? parent.session.acceptedTextInputMirror(for: parent.blockID)
                    ?? parent.session.draftText(for: parent.blockID),
                acceptedRange: range,
                replacementText: text
            ) else {
                return
            }
            acceptedTextFallbackMirror = proposal.text
            parent.session.updateAcceptedTextInputMirror(blockID: parent.blockID, text: proposal.text)
            EditorPerformanceTrace.point("native_text_accepted_change_fallback_scheduled") {
                [
                    "platform": "iOS",
                    "block_id": parent.blockID,
                    "replacement_length": "\((text as NSString).length)",
                    "range_location": "\(range.location)",
                    "range_length": "\(range.length)",
                    "proposed_text_length": "\(proposal.text.count)"
                ]
            }
            DispatchQueue.main.async { [self, textView] in
                guard self.modelUpdateGuard.shouldForwardTextChange else {
                    self.traceAcceptedTextChangeFallbackSkipped(reason: "model_update_guard")
                    return
                }
                guard textView.markedTextRange == nil else {
                    self.traceAcceptedTextChangeFallbackSkipped(reason: "composing")
                    return
                }

                let actualText = textView.text ?? ""
                let nextText = NativeTextAcceptedChangeFallbackTextPolicy.resolvedText(
                    actualText: actualText,
                    proposedText: proposal.text
                )
                if !text.isEmpty,
                   range.length == 0,
                   let currentDraft = self.parent.session.draftText(for: self.parent.blockID),
                   nextText.count < currentDraft.count {
                    self.traceAcceptedTextChangeFallbackSkipped(reason: "shorter_than_draft")
                    return
                }

                let draftAlreadyUpdated = self.parent.session.draftText(for: self.parent.blockID) == nextText
                let didRepairText = actualText != nextText
                if actualText != nextText {
                    textView.text = nextText
                }
                self.acceptedTextFallbackMirror = nextText
                self.parent.session.updateAcceptedTextInputMirror(blockID: self.parent.blockID, text: nextText)
                let fallbackSelection = NativeTextAcceptedChangeFallbackSelectionPolicy.selectionRange(
                    actualSelection: textView.selectedRange,
                    expectedCaretLocation: proposal.caretLocation,
                    nextTextLength: (nextText as NSString).length,
                    shouldRepair: !text.isEmpty
                )
                if textView.selectedRange != fallbackSelection {
                    textView.selectedRange = fallbackSelection
                }
                if self.updateSessionSelection(textView: textView) {
                    self.traceNativeSelectionPainted(textView: textView, source: "should_change_fallback")
                }
                self.updateSessionComposition(textView: textView)
                guard !draftAlreadyUpdated else {
                    self.traceAcceptedTextChangeFallbackSkipped(reason: didRepairText ? "view_repaired" : "up_to_date")
                    return
                }
                self.parent.session.updateDraft(blockID: self.parent.blockID, text: nextText)
                EditorPerformanceTrace.point("native_text_accepted_change_fallback_applied") {
                    [
                        "platform": "iOS",
                        "block_id": self.parent.blockID,
                        "repaired_text": "\(didRepairText)",
                        "text_length": "\(nextText.count)"
                    ]
                }
                EditorPerformanceTrace.point("character_painted") {
                    [
                        "platform": "iOS",
                        "block_id": self.parent.blockID,
                        "text_length": "\(nextText.count)",
                        "source": "should_change_fallback"
                    ]
                }
                EditorPerformanceTrace.nextRunLoopPoint("character_next_runloop_painted") {
                    [
                        "platform": "iOS",
                        "block_id": self.parent.blockID,
                        "text_length": "\(nextText.count)",
                        "source": "should_change_fallback"
                    ]
                }
                self.scheduleDeferredModelTextChange(nextText, textView: textView)
            }
        }

        private func traceAcceptedTextChangeFallbackSkipped(reason: String) {
            EditorPerformanceTrace.point("native_text_accepted_change_fallback_skipped") {
                [
                    "platform": "iOS",
                    "block_id": parent.blockID,
                    "reason": reason
                ]
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            pendingPostSplitTextSelection = nil
            acceptedTextFallbackMirror = nil
            parent.session.clearAcceptedTextInputMirror(blockID: parent.blockID)
            flushDeferredModelTextChange(textView.text ?? "")
            parent.onEditingEnded()
            _ = parent.session.commitDraft(blockID: parent.blockID)
            parent.session.endEditing(blockID: parent.blockID)
        }

        private func scheduleDeferredModelTextChange(_ text: String, textView: UITextView) {
            deferredTextChangeSequence += 1
            let sequence = deferredTextChangeSequence
            let blockID = parent.blockID
            Task { @MainActor [weak self, weak textView] in
                do {
                    try await Task.sleep(nanoseconds: NativeTextModelPropagationPolicy.debounceNanoseconds)
                } catch {
                    return
                }
                guard let self,
                      sequence == self.deferredTextChangeSequence else {
                    return
                }
                let trace = EditorPerformanceTrace.begin("native_text_model_update") {
                    [
                        "platform": "iOS",
                        "block_id": blockID,
                        "text_length": "\(text.count)",
                        "deferred": "true",
                        "debounce_ms": "\(NativeTextModelPropagationPolicy.debounceMilliseconds)"
                    ]
                }
                self.parent.onTextChange(text)
                if let textView {
                    self.applyTextStyles(to: textView)
                    self.scheduleHeightMeasurement(for: textView)
                }
                EditorPerformanceTrace.end(trace)
            }
        }

        private func flushDeferredModelTextChange(_ text: String) {
            deferredTextChangeSequence += 1
            parent.onTextChange(text)
        }

        func textDraggableView(
            _ textDraggableView: UIView & UITextDraggable,
            itemsForDrag dragRequest: UITextDragRequest
        ) -> [UIDragItem] {
            [blockDragItem()]
        }

        func dragInteraction(
            _ interaction: UIDragInteraction,
            itemsForBeginning session: UIDragSession
        ) -> [UIDragItem] {
            [blockDragItem()]
        }

        func dragInteraction(
            _ interaction: UIDragInteraction,
            sessionAllowsMoveOperation session: UIDragSession
        ) -> Bool {
            true
        }

        func dragInteraction(
            _ interaction: UIDragInteraction,
            sessionIsRestrictedToDraggingApplication session: UIDragSession
        ) -> Bool {
            true
        }

        private func blockDragItem() -> UIDragItem {
            let payload = MobileNativeTextBlockDragPolicy.payloadText(
                blockID: parent.blockID,
                explicitPayloadText: parent.dragPayloadText
            )
            let itemProvider = NSItemProvider(object: payload as NSString)
            let dragItem = UIDragItem(itemProvider: itemProvider)
            dragItem.localObject = payload
            return dragItem
        }

        func syncCurrentTextSelection(in textView: UITextView) {
            if updateSessionSelection(textView: textView) {
                traceNativeSelectionPainted(textView: textView, source: "sync_selection")
            }
            parent.session.clearBlockSelection()
        }

        func selectCurrentBlock(in textView: UITextView) {
            let fullRange = NSRange(location: 0, length: (textView.text as NSString).length)
            textView.selectedRange = fullRange
            if updateSessionSelection(textView: textView) {
                traceNativeSelectionPainted(textView: textView, source: "select_current_block")
            }
            parent.session.selectBlocks([parent.blockID])
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
                    self.scheduleFocusConfirmation(
                        textView: textView,
                        focusRequestID: focusRequestID,
                        remainingAttempts: remainingAttempts
                    )
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

        private func scheduleFocusConfirmation(
            textView: UITextView,
            focusRequestID: UUID,
            remainingAttempts: Int
        ) {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + NativeTextFocusConfirmationPolicy.confirmationDelay
            ) { [weak textView, weak self] in
                guard let textView, let self else {
                    return
                }

                let isConfirmedFocused = textView.isFirstResponder
                if NativeTextFocusConfirmationPolicy.shouldMarkRequestHandled(
                    didPerformFocus: true,
                    isFirstResponderAfterConfirmation: isConfirmedFocused
                ) {
                    self.focusRequestState.finish(requestID: focusRequestID, didFocus: true)
                    self.parent.session.beginEditing(blockID: self.parent.blockID, reason: .programmatic)
                    self.parent.onFocusRequestHandled()
                    return
                }

                guard NativeTextFocusConfirmationPolicy.shouldRetry(
                    didPerformFocus: true,
                    isFirstResponderAfterConfirmation: isConfirmedFocused,
                    remainingAttempts: remainingAttempts
                ) else {
                    self.focusRequestState.finish(requestID: focusRequestID, didFocus: false)
                    EditorLog.focus.debug(
                        "editor_focus_request_confirmation_failed block_id=\(self.parent.blockID, privacy: .public)"
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

        private func updateSessionSelection(textView: UITextView) -> Bool {
            parent.session.updateSelection(
                blockID: parent.blockID,
                location: textView.selectedRange.location,
                length: textView.selectedRange.length
            )
        }

        private func traceNativeSelectionPainted(textView: UITextView, source: String) {
            let selectedRange = textView.selectedRange
            let eventName = selectedRange.length == 0 ? "cursor_painted" : "selection_painted"
            EditorPerformanceTrace.point(eventName) {
                [
                    "platform": "iOS",
                    "block_id": parent.blockID,
                    "location": "\(selectedRange.location)",
                    "length": "\(selectedRange.length)",
                    "source": source
                ]
            }
        }

        private func traceMobileCursorVisibility(textView: UITextView, source: String) {
            guard EditorPerformanceTrace.isEnabled else {
                return
            }

            DispatchQueue.main.async { [weak textView, blockID = parent.blockID] in
                guard let textView else {
                    return
                }
                let selectedTextRange = textView.selectedTextRange
                let caretRect = selectedTextRange.map { textView.caretRect(for: $0.end) } ?? .zero
                let visibleBounds = textView.bounds.insetBy(dx: 0, dy: -8)
                var metadata = MobileKeyboardPerformanceState.metadata
                metadata["block_id"] = blockID
                metadata["source"] = source
                metadata["cursor_visible"] = "\(visibleBounds.intersects(caretRect))"
                metadata["caret_min_y"] = String(format: "%.1f", caretRect.minY)
                metadata["caret_max_y"] = String(format: "%.1f", caretRect.maxY)
                metadata["visible_min_y"] = String(format: "%.1f", visibleBounds.minY)
                metadata["visible_max_y"] = String(format: "%.1f", visibleBounds.maxY)
                EditorPerformanceTrace.point("mobile_editor_cursor_visible", metadata: metadata)
            }
        }

        private func updateSessionComposition(textView: UITextView) {
            parent.session.updateComposition(
                blockID: parent.blockID,
                isComposing: textView.markedTextRange != nil
            )
        }

        func scheduleHeightMeasurement(for textView: UITextView) {
            guard !isHeightMeasurementScheduled else {
                return
            }
            isHeightMeasurementScheduled = true
            DispatchQueue.main.async { [weak textView, weak self] in
                guard let textView, let self else {
                    return
                }
                self.isHeightMeasurementScheduled = false
                let nextFingerprint = self.heightMeasurementFingerprint(for: textView)
                guard NativeTextHeightMeasurementPolicy.shouldMeasureHeight(
                    cached: self.measuredHeightFingerprint,
                    next: nextFingerprint
                ) else {
                    return
                }
                self.measuredHeightFingerprint = nextFingerprint
                self.parent.onContentHeightChange(
                    self.measuredHeight(
                        for: textView,
                        width: nextFingerprint.width
                    )
                )
            }
        }

        private func heightMeasurementFingerprint(for textView: UITextView) -> NativeTextHeightMeasurementFingerprint {
            NativeTextHeightMeasurementFingerprint(
                text: textView.text ?? "",
                width: measurementWidth(for: textView),
                lineWrapping: parent.lineWrapping,
                blockType: parent.blockType,
                fontName: parent.uiFont.fontName,
                fontSize: parent.uiFont.pointSize,
                minimumHeight: parent.minimumHeight,
                lineHeightMultiple: CGFloat(EditorDesignTokens.Typography.bodyLineHeightMultiple)
            )
        }

        private func measurementWidth(for textView: UITextView) -> CGFloat {
            NativeTextMeasurementWidthPolicy.width(
                boundsWidth: textView.bounds.width,
                viewportWidth: UIScreen.main.bounds.width,
                horizontalMargin: CGFloat(EditorCanvasChromeLayout.compactHorizontalPadding * 2),
                lineWrapping: parent.lineWrapping
            )
        }

        private func measuredHeight(for textView: UITextView, width: CGFloat) -> CGFloat {
            guard !textView.text.isEmpty else {
                return parent.minimumHeight
            }
            let fittingSize = textView.sizeThatFits(
                CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            )
            let contentHeight = max(0, fittingSize.height - NativeTextEditorLayout.uiVerticalTextInset)
            return NativeTextEditorLayout.measuredHeight(
                contentHeight: contentHeight,
                minimumHeight: parent.minimumHeight,
                verticalInset: NativeTextEditorLayout.uiVerticalTextInset
            )
        }

        private func focusDelay(for remainingAttempts: Int) -> DispatchTimeInterval {
            remainingAttempts == 8 ? .milliseconds(0) : .milliseconds(35)
        }
    }
}

private final class EditorUITextView: UITextView, UIGestureRecognizerDelegate {
    var blockID: String = ""
    var blockType: BlockType = .paragraph
    var onKeyboardMove: ((BlockKeyboardMoveDirection) -> Bool)?
    var onKeyboardIndentation: ((BlockKeyboardIndentationDirection) -> Bool)?
    var onKeyboardFocusMove: ((BlockKeyboardFocusDirection) -> Bool)?
    var onExtendBlockSelectionByKeyboard: ((BlockKeyboardFocusDirection) -> Bool)?
    var onSlashCommandNavigationByKeyboard: ((BlockKeyboardMoveDirection) -> Bool)?
    var onSlashCommandSelectionByKeyboard: (() -> Bool)?
    var onKeyboardInlineFormat: ((MarkdownInlineFormat, NSRange) -> Bool)?
    var onKeyboardLinkInsertion: ((NSRange) -> Bool)?
    var onInlineLinkActivation: ((NativeInlineLinkActivation, NSRange) -> Bool)?
    var onInsertBlockAfter: ((NSRange) -> Bool)?
    var onPasteTextAtSelection: ((NSRange, String) -> Bool)?
    var onMergeBlockWithPrevious: ((NSRange) -> Bool)?
    var onMergeBlockWithNext: ((NSRange) -> Bool)?
    var onSelectCurrentTextByKeyboard: (() -> Bool)?
    var onSelectCurrentBlockByKeyboard: (() -> Bool)?
    var onSelectAllBlocksByKeyboard: (() -> Bool)?
    var onCancelSelectionByKeyboard: (() -> Bool)?
    var onPromoteBlockToPageByKeyboard: (() -> Bool)?
    var onPasteAttachmentURLs: (([URL]) -> Bool)?
    var onHorizontalSwipe: ((CGFloat) -> Bool)?
    private var didInstallHorizontalSwipeRecognizers = false
    private var didInstallInlineLinkTapRecognizer = false
    private var blockDragInteraction: UIDragInteraction?

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textContainer.size = CGSize(
            width: max(1, bounds.width),
            height: CGFloat.greatestFiniteMagnitude
        )
    }

    override func caretRect(for position: UITextPosition) -> CGRect {
        NativeTextInsertionPointRectResolver.rect(
            original: super.caretRect(for: position),
            fontLineHeight: font?.lineHeight,
            verticalOffset: NativeTextEditorLayout.uiCaretVerticalOffset
        )
    }

    func installHorizontalSwipeRecognizersIfNeeded() {
        guard !didInstallHorizontalSwipeRecognizers else {
            return
        }
        didInstallHorizontalSwipeRecognizers = true

        let horizontalPan = UIPanGestureRecognizer(target: self, action: #selector(handleHorizontalPan(_:)))
        horizontalPan.cancelsTouchesInView = false
        horizontalPan.delegate = self
        addGestureRecognizer(horizontalPan)
    }

    func installInlineLinkTapRecognizerIfNeeded() {
        guard !didInstallInlineLinkTapRecognizer else {
            return
        }
        didInstallInlineLinkTapRecognizer = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleInlineLinkTap(_:)))
        tap.numberOfTapsRequired = 1
        tap.cancelsTouchesInView = false
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    func installBlockDragInteractionIfNeeded(delegate: UIDragInteractionDelegate) {
        guard blockDragInteraction == nil else {
            blockDragInteraction?.isEnabled = true
            return
        }

        let interaction = UIDragInteraction(delegate: delegate)
        interaction.isEnabled = true
        interaction.allowsSimultaneousRecognitionDuringLift = false
        addInteraction(interaction)
        blockDragInteraction = interaction
    }

    func disableSystemTextDropInteractionIfNeeded() {
        guard let textDropInteraction else {
            return
        }

        removeInteraction(textDropInteraction)
    }

    override var keyCommands: [UIKeyCommand]? {
        var commands = [
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
            ),
            UIKeyCommand(
                input: "v",
                modifierFlags: [.command],
                action: #selector(pasteFromKeyboard)
            ),
            UIKeyCommand(
                input: "]",
                modifierFlags: [.command],
                action: #selector(promoteBlockToPage)
            ),
            UIKeyCommand(
                input: "a",
                modifierFlags: [.command],
                action: #selector(selectAllByKeyboard)
            ),
            UIKeyCommand(
                input: UIKeyCommand.inputEscape,
                modifierFlags: [],
                action: #selector(cancelSelectionByKeyboard)
            )
        ]
        if BlockKeyboardShortcutResolver.insertsBlockAfter(
            keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
            modifiers: [],
            blockType: blockType
        ) {
            commands.insert(
                UIKeyCommand(
                    input: "\r",
                    modifierFlags: [],
                    action: #selector(insertBlockAfter)
                ),
                at: 2
            )
        }
        return commands
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        switch direction {
        case .left:
            return onHorizontalSwipe?(-72) ?? false
        case .right:
            return onHorizontalSwipe?(72) ?? false
        default:
            return super.accessibilityScroll(direction)
        }
    }

    @objc private func handleHorizontalPan(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .ended else {
            return
        }

        let translation = recognizer.translation(in: self)
        guard abs(translation.x) >= 44,
              abs(translation.x) > abs(translation.y) * 1.35 else {
            return
        }

        _ = onHorizontalSwipe?(translation.x)
    }

    @objc private func handleInlineLinkTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended,
              let onInlineLinkActivation else {
            return
        }

        let point = recognizer.location(in: self)
        guard let position = closestPosition(to: point) else {
            return
        }
        let characterIndex = offset(from: beginningOfDocument, to: position)
        guard let activation = NativeInlineLinkActivationResolver.activation(
            text: text ?? "",
            characterIndex: characterIndex
        ) else {
            return
        }
        guard NativeInlineLinkPointHitGuard.contains(
            point: point,
            fragmentBounds: renderedFragmentBounds(for: activation.range)
        ) else {
            return
        }

        _ = onInlineLinkActivation(activation, selectedRange)
    }

    private func renderedFragmentBounds(for characterRange: NSRange) -> [CGRect] {
        guard characterRange.length > 0,
              characterRange.location < textStorage.length else {
            return []
        }
        let clampedRange = NSRange(
            location: characterRange.location,
            length: min(characterRange.length, textStorage.length - characterRange.location)
        )
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: clampedRange,
            actualCharacterRange: nil
        )
        guard glyphRange.length > 0 else {
            return []
        }

        var fragments: [CGRect] = []
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, fragmentGlyphRange, _ in
            let intersection = NSIntersectionRange(fragmentGlyphRange, glyphRange)
            guard intersection.length > 0 else {
                return
            }
            let glyphBounds = self.layoutManager.boundingRect(forGlyphRange: intersection, in: self.textContainer)
            guard !glyphBounds.isNull,
                  !glyphBounds.isEmpty else {
                return
            }
            fragments.append(glyphBounds.intersection(usedRect).offsetBy(
                dx: self.textContainerInset.left,
                dy: self.textContainerInset.top
            ))
        }
        return fragments
    }

    @objc private func moveBlockUp() {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: markedTextRange != nil) else {
            return
        }
        _ = onKeyboardMove?(.up)
    }

    @objc private func moveBlockDown() {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: markedTextRange != nil) else {
            return
        }
        _ = onKeyboardMove?(.down)
    }

    @objc private func insertBlockAfter() {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: markedTextRange != nil) else {
            return
        }
        guard BlockKeyboardShortcutResolver.insertsBlockAfter(
            keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
            modifiers: [],
            blockType: blockType
        ) else {
            insertText("\n")
            return
        }
        if SlashCommandKeyboardResolver.requestsSelection(
            keyCode: BlockKeyboardShortcutResolver.returnKeyCode,
            modifiers: [],
            text: text,
            selectedRange: selectedRange
        ), onSlashCommandSelectionByKeyboard?() == true {
            return
        }
        _ = onInsertBlockAfter?(selectedRange)
    }

    override func deleteBackward() {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: markedTextRange != nil) else {
            super.deleteBackward()
            return
        }

        if onMergeBlockWithPrevious?(selectedRange) == true {
            return
        }

        super.deleteBackward()
    }

    override func paste(_ sender: Any?) {
        if pasteAttachmentsFromGeneralPasteboard() {
            return
        }
        if let pasteText = UIPasteboard.general.string,
           NativeTextPasteSplitPolicy.shouldRouteToBlockPaste(text: pasteText, blockType: blockType),
           onPasteTextAtSelection?(selectedRange, pasteText) == true {
            return
        }
        super.paste(sender)
    }

    private func isUnmodifiedForwardDeletePress(_ press: UIPress) -> Bool {
        guard let key = press.key else {
            return false
        }

        return key.keyCode == .keyboardDeleteForward && key.modifierFlags.isEmpty
    }

    private func deleteForwardInBlock() {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: markedTextRange != nil) else {
            deleteForwardWithinText()
            return
        }

        if onMergeBlockWithNext?(selectedRange) == true {
            return
        }

        deleteForwardWithinText()
    }

    private func deleteForwardWithinText() {
        let currentRange = selectedRange
        let textLength = (text as NSString).length
        guard currentRange.location < textLength || currentRange.length > 0 else {
            return
        }

        let deleteLength = currentRange.length > 0 ? currentRange.length : 1
        guard currentRange.location + deleteLength <= textLength,
              let start = position(from: beginningOfDocument, offset: currentRange.location),
              let end = position(from: start, offset: deleteLength),
              let textRange = textRange(from: start, to: end) else {
            return
        }

        replace(textRange, withText: "")
    }

    @objc private func indentBlock() {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: markedTextRange != nil) else {
            return
        }
        _ = onKeyboardIndentation?(.indent)
    }

    @objc private func outdentBlock() {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: markedTextRange != nil) else {
            return
        }
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
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: markedTextRange != nil) else {
            return
        }
        _ = onKeyboardInlineFormat?(format, selectedRange)
    }

    @objc private func insertLink() {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: markedTextRange != nil) else {
            return
        }
        _ = onKeyboardLinkInsertion?(selectedRange)
    }

    @objc private func promoteBlockToPage() {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: markedTextRange != nil) else {
            return
        }
        _ = onPromoteBlockToPageByKeyboard?()
    }

    @objc private func pasteFromKeyboard() {
        if pasteAttachmentsFromGeneralPasteboard() {
            return
        }
        paste(nil)
    }

    private func pasteAttachmentsFromGeneralPasteboard() -> Bool {
        let attachmentURLs = IOSPasteboardAttachmentResolver.attachmentURLs(from: .general)
        guard !attachmentURLs.isEmpty else {
            return false
        }
        return onPasteAttachmentURLs?(attachmentURLs) == true
    }

    @objc private func selectAllByKeyboard() {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: markedTextRange != nil) else {
            return
        }

        switch BlockSelectAllKeyboardResolver.stage(blockType: blockType, selectedRange: selectedRange, text: text) {
        case .currentText:
            super.selectAll(nil)
            if onSelectCurrentTextByKeyboard?() == true {
                return
            }
        case .currentBlock:
            if onSelectCurrentBlockByKeyboard?() == true {
                return
            }
        case .allBlocks:
            if onSelectAllBlocksByKeyboard?() == true {
                return
            }
        }

        selectAll(nil)
    }

    @objc private func cancelSelectionByKeyboard() {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: markedTextRange != nil) else {
            return
        }
        _ = handleCancelSelectionByKeyboard()
    }

    private func handleCancelSelectionByKeyboard() -> Bool {
        var handled = false
        let currentRange = selectedRange
        if currentRange.length > 0 {
            selectedRange = NSRange(location: currentRange.location + currentRange.length, length: 0)
            handled = true
        }
        if onCancelSelectionByKeyboard?() == true {
            handled = true
        }
        return handled
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard NativeTextCompositionPolicy.shouldHandleBlockCommand(isComposing: markedTextRange != nil) else {
            super.pressesBegan(presses, with: event)
            return
        }

        if presses.contains(where: isUnmodifiedEscapePress), handleCancelSelectionByKeyboard() {
            return
        }

        if presses.contains(where: isUnmodifiedForwardDeletePress) {
            deleteForwardInBlock()
            return
        }

        guard let press = presses.first,
              let keyCode = press.key?.blockKeyboardArrowKeyCode else {
            super.pressesBegan(presses, with: event)
            return
        }

        if let direction = SlashCommandKeyboardResolver.navigationDirection(
            keyCode: keyCode,
            modifiers: press.key?.modifierFlags.blockKeyboardShortcutModifiers ?? [],
            text: text,
            selectedRange: selectedRange
        ), onSlashCommandNavigationByKeyboard?(direction) == true {
            return
        }

        if let direction = BlockKeyboardSelectionExtensionResolver.direction(
            keyCode: keyCode,
            modifiers: press.key?.modifierFlags.blockKeyboardShortcutModifiers ?? [],
            selectedRange: selectedRange,
            text: text
        ), onExtendBlockSelectionByKeyboard?(direction) == true {
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

    private func isUnmodifiedEscapePress(_ press: UIPress) -> Bool {
        guard let key = press.key else {
            return false
        }

        return key.keyCode == .keyboardEscape && key.modifierFlags.isEmpty
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
