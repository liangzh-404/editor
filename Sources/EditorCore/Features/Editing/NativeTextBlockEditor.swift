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
             .attachmentFile:
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
#elseif os(iOS)
    static var uiColor: UIColor {
        EditorDesignTokens.Colors.accent.uiColor
    }
#endif
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

struct NativeTextBlockEditor: View {
    static let acceptsInactiveWindowFirstMouse = true

    let blockID: String
    let text: String
    let blockType: BlockType
    let contentFont: EditorContentFont
    @ObservedObject var session: EditorSession
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
    let onInsertBlockAfter: (EditorTextSelection) -> EditorTextSelection?
    let onReplaceTextAtSelection: (EditorTextSelection, String) -> EditorTextSelection?
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
        onInsertBlockAfter: @escaping (EditorTextSelection) -> EditorTextSelection? = { _ in nil },
        onReplaceTextAtSelection: @escaping (EditorTextSelection, String) -> EditorTextSelection? = { _, _ in nil },
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
        onTextChange: @escaping (String) -> Void
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
        self.onInsertBlockAfter = onInsertBlockAfter
        self.onReplaceTextAtSelection = onReplaceTextAtSelection
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
                onInsertBlockAfter: onInsertBlockAfter,
                onReplaceTextAtSelection: onReplaceTextAtSelection,
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
                onTextChange: onTextChange
            )

            if showsPlaceholder {
                Text("按 \"/\" 快速操作")
                    .font(placeholderFont)
                    .foregroundStyle(.secondary.opacity(0.72))
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
    @ObservedObject var session: EditorSession
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
    let onInsertBlockAfter: (EditorTextSelection) -> EditorTextSelection?
    let onReplaceTextAtSelection: (EditorTextSelection, String) -> EditorTextSelection?
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
        textView.onInsertBlockAfter = { selectedRange in
            onInsertBlockAfter(
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                )
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
        context.coordinator.applyModelText(text, to: textView)
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
            textView.onInsertBlockAfter = { selectedRange in
                onInsertBlockAfter(
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    )
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
        if NativeTextCompositionPolicy.shouldApplyModelText(isComposing: textView.hasMarkedText()),
           textView.string != text {
            context.coordinator.applyModelText(text, to: textView)
        }
        textView.font = nsFont
        textView.textColor = EditorDesignTokens.Colors.primaryText.nsColor
        textView.insertionPointColor = NativeTextCursorChrome.nsColor
        textView.defaultParagraphStyle = paragraphStyle
        configureLineWrapping(textView: textView)
        if NativeTextCompositionPolicy.shouldApplyInlineMarkdownStyles(isComposing: textView.hasMarkedText()) {
            context.coordinator.applyTextStyles(to: textView)
        }
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
        private let codeSyntaxHighlighter = Highlight()
        private var codeSyntaxHighlightTask: Task<Void, Never>?

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

        func applyTextStyles(to textView: NSTextView) {
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
            codeSyntaxHighlightTask = Task { [weak self, weak textView, codeSyntaxHighlighter] in
                do {
                    let highlighted = try await codeSyntaxHighlighter.attributedText(
                        code,
                        colors: .light(.xcode)
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
            parent.session.clearBlockSelection()
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
            updateSessionSelection(textView: textView)
            updateSessionComposition(textView: textView)
            guard !textView.hasMarkedText() else {
                scheduleHeightMeasurement(for: textView)
                return
            }
            parent.session.updateDraft(blockID: parent.blockID, text: textView.string)
            parent.onTextChange(textView.string)
            applyTextStyles(to: textView)
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

        func syncCurrentTextSelection(in textView: NSTextView) {
            updateSessionSelection(textView: textView)
            parent.session.clearBlockSelection()
        }

        func selectCurrentBlock(in textView: NSTextView) {
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            textView.setSelectedRange(fullRange)
            updateSessionSelection(textView: textView)
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
            guard !isHeightMeasurementScheduled else {
                return
            }
            isHeightMeasurementScheduled = true
            DispatchQueue.main.async { [weak textView, weak self] in
                guard let textView, let self else {
                    return
                }
                self.isHeightMeasurementScheduled = false
                self.parent.onContentHeightChange(self.measuredHeight(for: textView))
            }
        }

        private func measuredHeight(for textView: NSTextView) -> CGFloat {
            guard !textView.string.isEmpty else {
                return parent.minimumHeight
            }
            let width = parent.lineWrapping ? max(textView.bounds.width, 320) : 10_000
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
    var onInsertBlockAfter: ((NSRange) -> Bool)?
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
        super.mouseDown(with: event)
        onMouseFocusResult?(window?.firstResponder === self)
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
    @ObservedObject var session: EditorSession
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
    let onInsertBlockAfter: (EditorTextSelection) -> EditorTextSelection?
    let onReplaceTextAtSelection: (EditorTextSelection, String) -> EditorTextSelection?
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

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = EditorUITextView(usingTextLayoutManager: true)
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
        textView.onInsertBlockAfter = { selectedRange in
            onInsertBlockAfter(
                EditorTextSelection(
                    blockID: blockID,
                    location: selectedRange.location,
                    length: selectedRange.length
                )
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
        context.coordinator.applyModelText(text, to: textView)
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
            textView.onInsertBlockAfter = { selectedRange in
                onInsertBlockAfter(
                    EditorTextSelection(
                        blockID: blockID,
                        location: selectedRange.location,
                        length: selectedRange.length
                    )
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
        if NativeTextCompositionPolicy.shouldApplyModelText(isComposing: textView.markedTextRange != nil),
           textView.text != text {
            context.coordinator.applyModelText(text, to: textView)
        }
        textView.font = uiFont
        textView.textColor = EditorDesignTokens.Colors.primaryText.uiColor
        textView.tintColor = NativeTextCursorChrome.uiColor
        textView.typingAttributes = baseTextAttributes
        configureLineWrapping(textView: textView)
        context.coordinator.configureKeyboardAccessory(
            keyboardAccessory,
            height: keyboardAccessoryHeight,
            replacesKeyboard: keyboardAccessoryReplacesKeyboard,
            for: textView
        )
        if NativeTextCompositionPolicy.shouldApplyInlineMarkdownStyles(isComposing: textView.markedTextRange != nil) {
            context.coordinator.applyTextStyles(to: textView)
        }
        context.coordinator.scheduleHeightMeasurement(for: textView)
        context.coordinator.handleFocusRequestIfNeeded(textView: textView)
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
        private let codeSyntaxHighlighter = Highlight()
        private var codeSyntaxHighlightTask: Task<Void, Never>?
        private var keyboardAccessoryHostingController: UIHostingController<AnyView>?
        private var keyboardAccessoryContainer: EditorKeyboardAccessoryContainerView?
        private var configuredKeyboardAccessoryHeight: CGFloat?
        private var configuredKeyboardReplacesKeyboard = false
        private var pendingPostSplitTextSelection: EditorTextSelection?

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
            let shouldRestoreSystemKeyboard = wasReplacingKeyboard && !replacesKeyboard
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
                    guard textView.isFirstResponder else {
                        textView.becomeFirstResponder()
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
            textView.text = text
            applyTextStyles(to: textView)
            scheduleHeightMeasurement(for: textView)
        }

        func applyTextStyles(to textView: UITextView) {
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
            codeSyntaxHighlightTask = Task { [weak self, weak textView, codeSyntaxHighlighter] in
                do {
                    let highlighted = try await codeSyntaxHighlighter.attributedText(
                        code,
                        colors: .light(.xcode)
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
            parent.session.clearBlockSelection()
            updateSessionSelection(textView: textView)
            updateSessionComposition(textView: textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            guard modelUpdateGuard.shouldForwardTextChange else {
                return
            }
            updateSessionSelection(textView: textView)
            updateSessionComposition(textView: textView)
            guard textView.markedTextRange == nil else {
                scheduleHeightMeasurement(for: textView)
                return
            }
            parent.session.updateDraft(blockID: parent.blockID, text: textView.text)
            parent.onTextChange(textView.text)
            applyTextStyles(to: textView)
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
               let replacement = NativeTextNewlineReplacementResolver.replacement(
                   currentText: textView.text,
                   range: range,
                   replacementText: text
            ) {
                parent.session.updateDraft(blockID: parent.blockID, text: replacement.updatedText)
                parent.onTextChange(replacement.updatedText)
                guard let nextSelection = parent.onInsertBlockAfter(
                    EditorTextSelection(
                        blockID: parent.blockID,
                        location: replacement.newlineRange.location,
                        length: replacement.newlineRange.length
                    )
                ) else {
                    return false
                }
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

        func textViewDidEndEditing(_ textView: UITextView) {
            pendingPostSplitTextSelection = nil
            _ = parent.session.commitDraft(blockID: parent.blockID)
            parent.session.endEditing(blockID: parent.blockID)
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
            updateSessionSelection(textView: textView)
            parent.session.clearBlockSelection()
        }

        func selectCurrentBlock(in textView: UITextView) {
            let fullRange = NSRange(location: 0, length: (textView.text as NSString).length)
            textView.selectedRange = fullRange
            updateSessionSelection(textView: textView)
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
            guard !isHeightMeasurementScheduled else {
                return
            }
            isHeightMeasurementScheduled = true
            DispatchQueue.main.async { [weak textView, weak self] in
                guard let textView, let self else {
                    return
                }
                self.isHeightMeasurementScheduled = false
                self.parent.onContentHeightChange(self.measuredHeight(for: textView))
            }
        }

        private func measuredHeight(for textView: UITextView) -> CGFloat {
            guard !textView.text.isEmpty else {
                return parent.minimumHeight
            }
            let width = NativeTextMeasurementWidthPolicy.width(
                boundsWidth: textView.bounds.width,
                viewportWidth: UIScreen.main.bounds.width,
                horizontalMargin: CGFloat(EditorCanvasChromeLayout.compactHorizontalPadding * 2),
                lineWrapping: parent.lineWrapping
            )
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
    var blockType: BlockType = .paragraph
    var onKeyboardMove: ((BlockKeyboardMoveDirection) -> Bool)?
    var onKeyboardIndentation: ((BlockKeyboardIndentationDirection) -> Bool)?
    var onKeyboardFocusMove: ((BlockKeyboardFocusDirection) -> Bool)?
    var onExtendBlockSelectionByKeyboard: ((BlockKeyboardFocusDirection) -> Bool)?
    var onSlashCommandNavigationByKeyboard: ((BlockKeyboardMoveDirection) -> Bool)?
    var onSlashCommandSelectionByKeyboard: (() -> Bool)?
    var onKeyboardInlineFormat: ((MarkdownInlineFormat, NSRange) -> Bool)?
    var onKeyboardLinkInsertion: ((NSRange) -> Bool)?
    var onInsertBlockAfter: ((NSRange) -> Bool)?
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
