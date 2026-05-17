import Foundation
import Dispatch
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct EditorInsertMarkdownLinkActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorPromoteDiarySelectionActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorOpenParentPageActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorCreateNewDocumentActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorOpenTodayActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorNavigateBackActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorNavigateForwardActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorShowAllDocumentsActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorShowFavoritesActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorQuickOpenActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var insertMarkdownLinkAction: (() -> Void)? {
        get { self[EditorInsertMarkdownLinkActionKey.self] }
        set { self[EditorInsertMarkdownLinkActionKey.self] = newValue }
    }

    var promoteDiarySelectionAction: (() -> Void)? {
        get { self[EditorPromoteDiarySelectionActionKey.self] }
        set { self[EditorPromoteDiarySelectionActionKey.self] = newValue }
    }

    var openParentPageAction: (() -> Void)? {
        get { self[EditorOpenParentPageActionKey.self] }
        set { self[EditorOpenParentPageActionKey.self] = newValue }
    }

    var createNewDocumentAction: (() -> Void)? {
        get { self[EditorCreateNewDocumentActionKey.self] }
        set { self[EditorCreateNewDocumentActionKey.self] = newValue }
    }

    var openTodayAction: (() -> Void)? {
        get { self[EditorOpenTodayActionKey.self] }
        set { self[EditorOpenTodayActionKey.self] = newValue }
    }

    var navigateBackAction: (() -> Void)? {
        get { self[EditorNavigateBackActionKey.self] }
        set { self[EditorNavigateBackActionKey.self] = newValue }
    }

    var navigateForwardAction: (() -> Void)? {
        get { self[EditorNavigateForwardActionKey.self] }
        set { self[EditorNavigateForwardActionKey.self] = newValue }
    }

    var showAllDocumentsAction: (() -> Void)? {
        get { self[EditorShowAllDocumentsActionKey.self] }
        set { self[EditorShowAllDocumentsActionKey.self] = newValue }
    }

    var showFavoritesAction: (() -> Void)? {
        get { self[EditorShowFavoritesActionKey.self] }
        set { self[EditorShowFavoritesActionKey.self] = newValue }
    }

    var quickOpenAction: (() -> Void)? {
        get { self[EditorQuickOpenActionKey.self] }
        set { self[EditorQuickOpenActionKey.self] = newValue }
    }
}

struct EditorShellView: View {
    @StateObject private var viewModel: WorkspaceViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: WorkspaceViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        AdaptiveEditorShell(viewModel: viewModel)
            .task {
                await Task.yield()
                try? viewModel.load()
                viewModel.syncAfterActivation()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    viewModel.syncAfterActivation()
                }
            }
    }
}

private struct AdaptiveEditorShell: View {
    @ObservedObject var viewModel: WorkspaceViewModel

#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    var body: some View {
#if os(iOS)
        if horizontalSizeClass == .compact {
            CompactEditorShell(viewModel: viewModel)
        } else {
            ThreeColumnEditorShell(viewModel: viewModel)
        }
#else
        ThreeColumnEditorShell(viewModel: viewModel)
#endif
    }
}

private struct ThreeColumnEditorShell: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        NavigationSplitView {
            WorkspaceSidebar(viewModel: viewModel)
        } content: {
            PageListView(viewModel: viewModel)
        } detail: {
            if viewModel.selectedPage != nil {
                EditorCanvasView(
                    page: viewModel.selectedPage,
                    pages: viewModel.snapshot.pages,
                    blocks: viewModel.editorVisibleBlocks,
                    allBlocks: viewModel.snapshot.blocks,
                    attachments: viewModel.snapshot.attachments,
                    attachmentPreviewGenerationStatuses: viewModel.attachmentPreviewGenerationStatuses,
                    markdownImportStatusText: viewModel.markdownImportStatusText,
                    backlinks: viewModel.selectedPageBacklinks,
                    externalLinks: viewModel.selectedPageExternalLinks,
                    conflicts: viewModel.selectedPageConflicts,
                    outlineItems: viewModel.selectedPageOutline,
                    parentPageLink: viewModel.selectedPageParentLink,
                    pageTagNames: viewModel.selectedPageTagNames,
                    pendingFocusBlockID: viewModel.pendingFocusBlockID,
                    canUndoTextEdit: viewModel.canUndoTextEdit,
                    onAddParagraphBlock: {
                        viewModel.addParagraphBlockToCurrentPage()
                    },
                    onAddPageReference: { targetPageID in
                        viewModel.appendPageReferenceToCurrentPageForUI(targetPageID: targetPageID)
                    },
                    onAddBlockReference: { targetBlockID in
                        viewModel.appendBlockReferenceToCurrentPageForUI(targetBlockID: targetBlockID)
                    },
                    onInsertMarkdownLink: { blockID, label, url in
                        viewModel.insertMarkdownLinkForUI(blockID: blockID, label: label, url: url)
                    },
                    onInsertMarkdownLinkAtSelection: { blockID, label, url, selection in
                        viewModel.insertMarkdownLinkForUI(
                            blockID: blockID,
                            label: label,
                            url: url,
                            selection: selection
                        )
                    },
                    onRemoveMarkdownLinkAtSelection: { blockID, selection in
                        viewModel.removeMarkdownLinkForUI(blockID: blockID, selection: selection)
                    },
                    onApplyMarkdownInlineFormat: { blockID, format, selection in
                        viewModel.applyMarkdownInlineFormatForUI(
                            blockID: blockID,
                            format: format,
                            selection: selection
                        )
                    },
                    onUndoTextEdit: {
                        viewModel.undoLastTextEditForUI()
                    },
                    onFocusCanvas: {
                        viewModel.focusEditorCanvasForUI()
                    },
                    onMoveBlock: { blockID, targetIndex in
                        viewModel.moveBlockInCurrentPage(blockID: blockID, toIndex: targetIndex)
                    },
                    onMoveBlocks: { blockIDs, targetIndex in
                        viewModel.moveBlocksInCurrentPage(blockIDs: blockIDs, toIndex: targetIndex)
                    },
                    onMoveBlockByKeyboard: { blockID, direction in
                        viewModel.moveBlockByKeyboardForUI(blockID: blockID, direction: direction)
                    },
                    onInsertBlockAfter: { blockID in
                        viewModel.insertParagraphBlockAfterForUI(blockID: blockID)
                    },
                    onSplitTextBlockAtSelection: { blockID, selection in
                        viewModel.splitTextBlockAtSelectionForUI(blockID: blockID, selection: selection)
                    },
                    onMergeTextBlockWithPrevious: { blockID, selection in
                        viewModel.mergeTextBlockWithPreviousAtSelectionForUI(blockID: blockID, selection: selection)
                    },
                    onMergeTextBlockWithNext: { blockID, selection in
                        viewModel.mergeTextBlockWithNextAtSelectionForUI(blockID: blockID, selection: selection)
                    },
                    onIndentBlock: { blockID in
                        viewModel.indentBlockForUI(blockID: blockID)
                    },
                    onOutdentBlock: { blockID in
                        viewModel.outdentBlockForUI(blockID: blockID)
                    },
                    onDeleteBlock: { blockID in
                        viewModel.deleteBlockFromCurrentPage(blockID: blockID)
                    },
                    onDeleteBlocks: { blockIDs in
                        viewModel.deleteBlocksFromCurrentPage(blockIDs: blockIDs)
                    },
                    onSelectBacklink: { backlink in
                        viewModel.selectBacklink(backlink)
                    },
                    onSelectOutlineItem: { item in
                        viewModel.selectOutlineItem(item)
                    },
                    onOpenPageReference: { targetPageID in
                        viewModel.openPageReference(targetPageID: targetPageID)
                    },
                    onOpenParentPage: {
                        viewModel.openParentPageForCurrentPageForUI()
                    },
                    onOpenBlockReference: { targetPageID, targetBlockID in
                        viewModel.openBlockReference(targetPageID: targetPageID, targetBlockID: targetBlockID)
                    },
                    onAcceptConflict: { conflict in
                        viewModel.acceptRemoteConflictForUI(id: conflict.id)
                    },
                    onAcceptAllConflicts: {
                        viewModel.acceptAllRemoteConflictsForSelectedPageForUI()
                    },
                    onAcceptLocalConflict: { conflict in
                        viewModel.acceptLocalConflictForUI(id: conflict.id)
                    },
                    onAcceptAllLocalConflicts: {
                        viewModel.acceptAllLocalConflictsForSelectedPageForUI()
                    },
                    onResolveConflictManually: { conflict, text in
                        viewModel.resolveConflictManuallyForUI(id: conflict.id, text: text)
                    },
                    onResolveAllConflictsManually: { mergedTextsByConflictID in
                        viewModel.resolveAllManualConflictsForSelectedPageForUI(
                            mergedTextsByConflictID: mergedTextsByConflictID
                        )
                    },
                    onPageTitleChange: { title in
                        viewModel.editSelectedPageTitle(title)
                    },
                    onImportMarkdown: { sourceURL in
                        viewModel.importMarkdownFileForCurrentPage(sourceURL: sourceURL)
                    },
                    onExportMarkdown: {
                        viewModel.exportCurrentPageMarkdown()
                    },
                    onExportMarkdownPackage: { destinationURL in
                        viewModel.exportCurrentPageMarkdownPackageForUI(to: destinationURL)
                    },
                    onBlockTextChange: { blockID, text in
                        viewModel.editBlockText(blockID: blockID, text: text)
                    },
                    onTableRowsChange: { blockID, rows in
                        viewModel.updateTableRowsForUI(blockID: blockID, rows: rows)
                    },
                    onBlockTypeChange: { blockID, type in
                        viewModel.changeBlockTypeForUI(blockID: blockID, type: type)
                    },
                    onConvertBlockToPage: { blockID in
                        viewModel.convertTextBlockToPageForUI(blockID: blockID)
                    },
                    onTaskItemCompletionChange: { blockID, isCompleted in
                        viewModel.updateTaskItemCompletionForUI(
                            blockID: blockID,
                            isCompleted: isCompleted
                        )
                    },
                    onCodeBlockLineWrappingChange: { blockID, isWrapped in
                        viewModel.updateCodeBlockLineWrapping(blockID: blockID, isWrapped: isWrapped)
                    },
                    onToggleBlockExpansion: { blockID in
                        viewModel.toggleBlockExpansion(blockID: blockID)
                    },
                    isToggleBlockExpanded: { blockID in
                        viewModel.isToggleBlockExpanded(blockID: blockID)
                    },
                    onImportAttachment: { sourceURL in
                        viewModel.importAttachmentForCurrentPage(sourceURL: sourceURL)
                    },
                    onImportAttachmentsAfterBlock: { sourceURLs, blockID in
                        viewModel.importAttachmentsForCurrentPage(
                            sourceURLs: sourceURLs,
                            afterBlockID: blockID
                        )
                    },
                    onRetryAttachmentPreview: { attachmentID in
                        viewModel.retryAttachmentPreviewGeneration(attachmentID: attachmentID)
                    },
                    onPendingBlockFocusHandled: {
                        _ = viewModel.consumePendingFocusBlockID()
                    }
                )
            } else {
                Color.white
                    .navigationTitle("编辑器")
            }
        }
        .focusedValue(\.createNewDocumentAction, {
            _ = viewModel.createNewDocumentForUI()
        })
        .focusedValue(\.openTodayAction, {
            _ = viewModel.openTodayForUI()
        })
        .focusedValue(\.navigateBackAction, {
            _ = viewModel.navigateBackForUI()
        })
        .focusedValue(\.navigateForwardAction, {
            _ = viewModel.navigateForwardForUI()
        })
        .focusedValue(\.showAllDocumentsAction, {
            viewModel.selectCollection(.allDocuments)
        })
        .focusedValue(\.showFavoritesAction, {
            viewModel.selectCollection(.favorites)
        })
        .focusedValue(\.quickOpenAction, {
            viewModel.selectCollection(.search)
        })
    }
}

private struct CompactEditorShell: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @State private var path: [CompactRoute]
    @State private var didPushInitialPage: Bool

    init(viewModel: WorkspaceViewModel) {
        self.viewModel = viewModel
        let initialPageID = CompactInitialNavigationResolver.initialPageID(
            selectedPageID: viewModel.selectedPageID,
            availablePageIDs: viewModel.snapshot.pages.map(\.id)
        )
        _path = State(initialValue: initialPageID.map { [.page($0)] } ?? [])
        _didPushInitialPage = State(initialValue: initialPageID != nil)
    }

    var body: some View {
        NavigationStack(path: $path) {
            CompactHomeView(viewModel: viewModel)
            .navigationDestination(for: CompactRoute.self) { route in
                switch route {
                case .pages:
                    CompactPageListView(viewModel: viewModel)
                case .collection(let collection):
                    CompactCollectionDestination(
                        viewModel: viewModel,
                        collection: collection
                    )
                case .page(let pageID):
                    CompactPageDestination(
                        viewModel: viewModel,
                        pageID: pageID
                    )
                }
            }
            .onAppear {
                pushInitialPageIfNeeded()
            }
            .onChange(of: viewModel.pendingCompactPageNavigationID) { _, pageID in
                guard let pageID = viewModel.consumePendingCompactPageNavigationID() ?? pageID else {
                    return
                }
                pushPageIfNeeded(pageID)
            }
        }
    }

    private func pushInitialPageIfNeeded() {
        guard !didPushInitialPage else {
            return
        }
        didPushInitialPage = true

        guard let pageID = viewModel.selectedPageID else {
            return
        }
        pushPageIfNeeded(pageID)
    }

    private func pushPageIfNeeded(_ pageID: String) {
        guard viewModel.snapshot.pages.contains(where: { $0.id == pageID }) else {
            return
        }

        if path.last != .page(pageID) {
            path.append(.page(pageID))
        }
    }
}

private struct CompactHomeView: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                recentSection
                librarySection
                tagSection
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .navigationTitle("近期打开")
        .background(Color(red: 0.965, green: 0.958, blue: 0.948))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(red: 0.45, green: 0.43, blue: 0.58))

            Text("近期打开")
                .font(.title2.weight(.bold))

            Spacer()

            Button {
                _ = viewModel.createNewDocumentForCompactUI()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("新建文档")
            .accessibilityIdentifier("editor.compact.new-document")
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(recentPages) { page in
                NavigationLink(value: CompactRoute.page(page.id)) {
                    CompactRecentPageCard(
                        page: page,
                        tagNames: tagNames(for: page),
                        preview: PageListPreviewResolver.preview(
                            pageID: page.id,
                            blocks: viewModel.snapshot.blocks,
                            attachments: viewModel.snapshot.attachments
                        )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("editor.page.\(page.id)")
            }
        }
    }

    private var librarySection: some View {
        VStack(spacing: 6) {
            ForEach(CompactLibraryNavigationModel.items(snapshot: viewModel.snapshot)) { item in
                compactNavigationRow(item: item)
            }
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("标签")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.primary.opacity(0.82))
                .padding(.horizontal, 4)

            ForEach(viewModel.snapshot.tags.prefix(8)) { tag in
                HStack(spacing: 10) {
                    Image(systemName: "tag")
                        .foregroundStyle(Color(red: 0.49, green: 0.47, blue: 0.62))
                        .frame(width: 22)
                    Text(tag.path)
                        .lineLimit(1)
                    Spacer()
                    Text("\(tagCount(tag.id))")
                        .foregroundStyle(.secondary)
                }
                .font(.body.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.5))
                )
            }
        }
    }

    private func compactNavigationRow(item: CompactLibraryNavigationItem) -> some View {
        NavigationLink(value: item.route) {
            HStack(spacing: 10) {
                Image(systemName: item.systemImage)
                    .frame(width: 22)
                    .foregroundStyle(Color(red: 0.49, green: 0.47, blue: 0.62))
                Text(item.title)
                    .font(.body.weight(.semibold))
                Spacer()
                Text("\(item.count)")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.62))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(item.identifier)
    }

    private var recentPages: [PageSummary] {
        var pages: [PageSummary] = []
        if let selectedPage = viewModel.selectedPage {
            pages.append(selectedPage)
        }
        for page in viewModel.visibleDocumentPages where !pages.contains(where: { $0.id == page.id }) {
            pages.append(page)
            if pages.count >= 4 {
                break
            }
        }
        return pages
    }

    private func tagNames(for page: PageSummary) -> [String] {
        let tagIDs = Set(viewModel.snapshot.pageTags.filter { $0.pageID == page.id }.map(\.tagID))
        return viewModel.snapshot.tags.filter { tagIDs.contains($0.id) }.map(\.name)
    }

    private func tagCount(_ tagID: String) -> Int {
        viewModel.snapshot.pageTags.filter { $0.tagID == tagID }.count
    }
}

private struct CompactRecentPageCard: View {
    let page: PageSummary
    let tagNames: [String]
    let preview: PageListPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: page.isFavorite ? "star.fill" : "doc.text")
                    .foregroundStyle(page.isFavorite ? Color.yellow : Color.secondary)
                Text(page.title)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                Spacer()
            }

            Text(preview.excerpt?.isEmpty == false ? preview.excerpt ?? "" : "空白文档")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if !tagNames.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tagNames.prefix(3), id: \.self) { tagName in
                        Text("#\(tagName)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.32, green: 0.43, blue: 0.74))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.89, green: 0.92, blue: 0.98))
                            )
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }
}

enum EditorBlockChrome {
    static let blockSpacing: Double = 0
    static let rowVerticalPadding: Double = 0
    static let listVerticalPadding: Double = 0
    static let listHorizontalPadding: Double = 0
    static let listBackgroundOpacity: Double = 0
    static let listMarkerWidth: Double = 18
    static let listTextSpacing: Double = 6
    static let actionColumnWidth: Double = 18
    static let actionColumnSpacing: Double = 5
    static let dragHandleWidth: Double = 18
    static let inactiveHandleOpacity: Double = 0
    static let specialBlockCornerRadius: Double = 5
    static let dropTargetHeight: Double = 32
    static let dropSlotHeight: Double = 8
    static let trailingInsertHitHeight: Double = 28
}

enum TableBlockChrome {
    static let cellWidth: Double = 136
    static let cellHeight: Double = 42
    static let maxViewportWidth: Double = 620
    static let cornerRadius: Double = 8
    static let gridLineOpacity: Double = 0.045
    static let outerBorderOpacity: Double = 0.09
    static let primaryControlDiameter: Double = 18
    static let insertControlVisibleDiameter: Double = 3
    static let insertControlExpandedDiameter: Double = 10
    static let insertControlIconFontSize: Double = 6
    static let insertControlEdgeOffset: Double = 4
    static let selectorWidth: Double = 12
    static let selectorHeight: Double = 12
    static let selectorIndicatorOpacity: Double = 0
    static let selectorHitOpacity: Double = 0.0001
}

enum PastedAttachmentAnchorResolver {
    static func anchorBlockID(
        textSelection: EditorTextSelection?,
        focusedBlockID: String?,
        selectedBlockIDs: Set<String>,
        visibleBlockIDs: [String]
    ) -> String? {
        if let blockID = textSelection?.blockID,
           visibleBlockIDs.contains(blockID) {
            return blockID
        }

        if let focusedBlockID,
           visibleBlockIDs.contains(focusedBlockID) {
            return focusedBlockID
        }

        return visibleBlockIDs.last { selectedBlockIDs.contains($0) }
    }
}

enum IOSEditorKeyboardShortcutAction: Equatable, Sendable {
    case pasteAttachments
    case moveFocus(BlockKeyboardFocusDirection)
}

enum IOSEditorKeyboardShortcutActionResolver {
    static let upArrowInput = "\u{F700}"
    static let downArrowInput = "\u{F701}"

    static func action(
        input: String?,
        modifiers: Set<BlockKeyboardShortcutModifier>
    ) -> IOSEditorKeyboardShortcutAction? {
        if CommandVPasteShortcutResolver.requestsAttachmentPaste(
            input: input,
            modifiers: modifiers
        ) {
            return .pasteAttachments
        }

        guard modifiers.isEmpty else {
            return nil
        }

        switch input {
        case upArrowInput:
            return .moveFocus(.previous)
        case downArrowInput:
            return .moveFocus(.next)
        default:
            return nil
        }
    }
}

enum BlockSelectionKeyboardAnchorResolver {
    static func anchorBlockID(
        selectedBlockIDs: Set<String>,
        visibleBlockIDs: [String]
    ) -> String? {
        visibleBlockIDs.last { selectedBlockIDs.contains($0) }
    }
}

enum MobileBlockSwipeAction: Equatable, Sendable {
    case select
    case indent
    case outdent
}

enum MobileBlockSwipeActionResolver {
    static let horizontalThreshold: CGFloat = 56
    static let horizontalDominanceRatio: CGFloat = 1.25

    static func action(
        translation: CGSize,
        isEditingBlock: Bool,
        nestingLevel: Int
    ) -> MobileBlockSwipeAction? {
        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)
        guard horizontalDistance >= horizontalThreshold,
              horizontalDistance > verticalDistance * horizontalDominanceRatio else {
            return nil
        }

        if translation.width > 0 {
            return .indent
        }

        if isEditingBlock, nestingLevel > 0 {
            return .outdent
        }

        return .select
    }
}

enum MobileBlockSelectionReducer {
    static func selectionAfterSelecting(
        blockID: String,
        current: Set<String>
    ) -> Set<String> {
        var nextSelection = current
        if nextSelection.contains(blockID) {
            nextSelection.remove(blockID)
        } else {
            nextSelection.insert(blockID)
        }
        return nextSelection
    }
}

enum MobileBlockSelectionChromeResolver {
    static func isSelectionControlVisible(isSelectionModeActive: Bool) -> Bool {
        isSelectionModeActive
    }

    static func symbolName(isSelected: Bool) -> String {
        isSelected ? "checkmark.circle.fill" : "circle"
    }
}

#if os(iOS)
private struct MobileBlockSelectionToolbar: View {
    let selectedCount: Int
    let onClear: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("已选择 \(selectedCount) 个")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Button("取消", action: onClear)
                .font(.subheadline.weight(.medium))
                .buttonStyle(.borderless)
                .accessibilityIdentifier("editor.mobile-selection-clear")

            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("editor.mobile-selection-delete")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 0.5)
        }
        .accessibilityIdentifier("editor.mobile-selection-toolbar")
    }
}
#endif

struct TableSelection: Equatable, Sendable {
    var rows: Set<Int>
    var columns: Set<Int>

    init(rows: Set<Int> = [], columns: Set<Int> = []) {
        self.rows = rows
        self.columns = columns
    }

    static let empty = TableSelection()

    var isEmpty: Bool {
        rows.isEmpty && columns.isEmpty
    }
}

enum TableSelectionReducer {
    static func selectionAfterSelectingRow(
        _ row: Int,
        current: TableSelection,
        extend: Bool
    ) -> TableSelection {
        var selectedRows = extend ? current.rows : []
        if extend, selectedRows.contains(row) {
            selectedRows.remove(row)
        } else {
            selectedRows.insert(row)
        }
        return TableSelection(rows: selectedRows, columns: [])
    }

    static func selectionAfterSelectingColumn(
        _ column: Int,
        current: TableSelection,
        extend: Bool
    ) -> TableSelection {
        var selectedColumns = extend ? current.columns : []
        if extend, selectedColumns.contains(column) {
            selectedColumns.remove(column)
        } else {
            selectedColumns.insert(column)
        }
        return TableSelection(rows: [], columns: selectedColumns)
    }

    static func rowsAfterDeletingSelection(
        _ selection: TableSelection,
        from rows: [[String]]
    ) -> [[String]] {
        let normalizedRows = normalized(rows)
        let rowsAfterRowDeletion: [[String]]
        if selection.rows.isEmpty {
            rowsAfterRowDeletion = normalizedRows
        } else {
            rowsAfterRowDeletion = normalizedRows.enumerated()
                .filter { index, _ in !selection.rows.contains(index) }
                .map(\.element)
        }

        let survivingRows = rowsAfterRowDeletion.isEmpty ? [[""]] : rowsAfterRowDeletion

        guard !selection.columns.isEmpty else {
            return survivingRows
        }

        let deletedColumns = selection.columns
        let rowsAfterColumnDeletion = survivingRows.map { row in
            let keptCells = row.enumerated()
                .filter { index, _ in !deletedColumns.contains(index) }
                .map(\.element)
            return keptCells.isEmpty ? [""] : keptCells
        }

        return rowsAfterColumnDeletion.isEmpty ? [[""]] : rowsAfterColumnDeletion
    }

    private static func normalized(_ rows: [[String]]) -> [[String]] {
        let sourceRows = rows.isEmpty ? [[""]] : rows
        let columnCount = max(sourceRows.map(\.count).max() ?? 1, 1)
        return sourceRows.map { row in
            if row.count >= columnCount {
                return row
            }
            return row + Array(repeating: "", count: columnCount - row.count)
        }
    }
}

enum BlockDropPlacement: Equatable, Sendable {
    case before
    case after
    case childAfter
}

struct BlockDropTarget: Equatable, Sendable {
    let blockID: String
    let placement: BlockDropPlacement
}

enum BlockDropTargetLifecycleReducer {
    static func targetAfterEditorInteraction(current: BlockDropTarget?) -> BlockDropTarget? {
        nil
    }
}

enum BlockDropPlacementResolver {
    static let indentationThreshold: CGFloat = 180
    static let beforeBandHeight: CGFloat = 10

    static func placement(location: CGPoint, rowSize: CGSize) -> BlockDropPlacement {
        let topBandHeight = min(beforeBandHeight, max(rowSize.height * 0.35, 8))
        if location.y <= topBandHeight {
            return .before
        }
        if location.x >= indentationThreshold {
            return .childAfter
        }
        return .after
    }
}

struct PageListPreview: Equatable, Sendable {
    let excerpt: String?
    let imageAttachment: AttachmentSnapshot?
    let fileAttachment: AttachmentSnapshot?
}

enum PageListPreviewResolver {
    static func preview(
        pageID: String,
        blocks: [BlockSnapshot],
        attachments: [AttachmentSnapshot]
    ) -> PageListPreview {
        let pageBlocks = blocks.filter { $0.pageID == pageID }
        let excerpt = pageBlocks.first { block in
            block.type == .paragraph
                && !block.textPlain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }?.textPlain.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageAttachment = attachment(
            in: attachments,
            matching: pageBlocks.first { $0.type == .attachmentImage }
        )
        let fileAttachment = attachment(
            in: attachments,
            matching: pageBlocks.first { $0.type == .attachmentFile }
        )

        return PageListPreview(
            excerpt: excerpt,
            imageAttachment: imageAttachment,
            fileAttachment: fileAttachment
        )
    }

    private static func attachment(
        in attachments: [AttachmentSnapshot],
        matching block: BlockSnapshot?
    ) -> AttachmentSnapshot? {
        guard let block else {
            return nil
        }
        return attachments.first { $0.matches(block: block) }
    }
}

enum PageReferencePreviewResolver {
    static func previewText(targetPageID: String?, blocks: [BlockSnapshot]) -> String? {
        guard let targetPageID else {
            return nil
        }

        return blocks.first { block in
            block.pageID == targetPageID
                && block.type.isTextEditable
                && !block.textPlain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }?.textPlain.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct EditorCanvasRenderMetrics: Equatable, Sendable {
    let pageID: String?
    let blockCount: Int
    let attachmentCount: Int
    let backlinkCount: Int
    let conflictCount: Int

    var isLargePage: Bool {
        blockCount >= EditorCanvasRenderPolicy.largePageBlockThreshold
    }
}

enum EditorCanvasRenderPolicy {
    static let usesLazyBlockStack = true
    static let largePageBlockThreshold = 750
}

struct EditorCanvasScrollMetrics: Equatable, Sendable {
    let pageID: String?
    let blockCount: Int
    let visibleBlockCount: Int
    let peakVisibleBlockCount: Int
    let firstVisibleBlockIndex: Int?
    let lastVisibleBlockIndex: Int?
    let peakLastVisibleBlockIndex: Int?
    let peakVisibleBlockIndexSpan: Int
    let scrollLifetimeMilliseconds: Double
    let blockAppearanceCount: Int
    let blockDisappearanceCount: Int

    init(
        pageID: String?,
        blockCount: Int,
        visibleBlockCount: Int,
        peakVisibleBlockCount: Int,
        firstVisibleBlockIndex: Int?,
        lastVisibleBlockIndex: Int?,
        peakLastVisibleBlockIndex: Int? = nil,
        peakVisibleBlockIndexSpan: Int,
        scrollLifetimeMilliseconds: Double = 0,
        blockAppearanceCount: Int = 0,
        blockDisappearanceCount: Int = 0
    ) {
        self.pageID = pageID
        self.blockCount = blockCount
        self.visibleBlockCount = visibleBlockCount
        self.peakVisibleBlockCount = peakVisibleBlockCount
        self.firstVisibleBlockIndex = firstVisibleBlockIndex
        self.lastVisibleBlockIndex = lastVisibleBlockIndex
        self.peakLastVisibleBlockIndex = peakLastVisibleBlockIndex
        self.peakVisibleBlockIndexSpan = peakVisibleBlockIndexSpan
        self.scrollLifetimeMilliseconds = scrollLifetimeMilliseconds
        self.blockAppearanceCount = blockAppearanceCount
        self.blockDisappearanceCount = blockDisappearanceCount
    }

    var isLargePage: Bool {
        blockCount >= EditorCanvasRenderPolicy.largePageBlockThreshold
    }

    var visibleBlockChurnCount: Int {
        blockAppearanceCount + blockDisappearanceCount
    }

    var visibleBlockIndexSpan: Int {
        guard let firstVisibleBlockIndex,
              let lastVisibleBlockIndex else {
            return 0
        }
        return lastVisibleBlockIndex - firstVisibleBlockIndex + 1
    }

    var runtimeSummary: String {
        [
            "page_id=\(pageID ?? "none")",
            "block_count=\(blockCount)",
            "visible_block_count=\(visibleBlockCount)",
            "peak_visible_block_count=\(peakVisibleBlockCount)",
            "first_visible_block_index=\(Self.optionalIndexDescription(firstVisibleBlockIndex))",
            "last_visible_block_index=\(Self.optionalIndexDescription(lastVisibleBlockIndex))",
            "peak_last_visible_block_index=\(Self.optionalIndexDescription(peakLastVisibleBlockIndex))",
            "visible_block_index_span=\(visibleBlockIndexSpan)",
            "peak_visible_block_index_span=\(peakVisibleBlockIndexSpan)",
            "scroll_lifetime_ms=\(Self.millisecondsDescription(scrollLifetimeMilliseconds))",
            "block_appearance_count=\(blockAppearanceCount)",
            "block_disappearance_count=\(blockDisappearanceCount)",
            "visible_block_churn_count=\(visibleBlockChurnCount)",
            "large_page=\(isLargePage)"
        ].joined(separator: " ")
    }

    private static func optionalIndexDescription(_ index: Int?) -> String {
        index.map(String.init) ?? "none"
    }

    private static func millisecondsDescription(_ milliseconds: Double) -> String {
        String(format: "%.3f", milliseconds)
    }
}

struct EditorCanvasScrollMetricsTracker: Equatable, Sendable {
    private var pageID: String?
    private var blockCount: Int
    private var visibleBlockIndexesByID: [String: Int] = [:]
    private var peakVisibleBlockCount = 0
    private var peakLastVisibleBlockIndex: Int?
    private var peakVisibleBlockIndexSpan = 0
    private var startedAtNanoseconds: UInt64
    private var lastEventNanoseconds: UInt64
    private var blockAppearanceCount = 0
    private var blockDisappearanceCount = 0

    init(
        pageID: String?,
        blockCount: Int,
        nowNanoseconds: UInt64 = Self.currentNanoseconds()
    ) {
        self.pageID = pageID
        self.blockCount = blockCount
        self.startedAtNanoseconds = nowNanoseconds
        self.lastEventNanoseconds = nowNanoseconds
    }

    var metrics: EditorCanvasScrollMetrics {
        let firstVisibleBlockIndex = visibleBlockIndexesByID.values.min()
        let lastVisibleBlockIndex = visibleBlockIndexesByID.values.max()
        return EditorCanvasScrollMetrics(
            pageID: pageID,
            blockCount: blockCount,
            visibleBlockCount: visibleBlockIndexesByID.count,
            peakVisibleBlockCount: peakVisibleBlockCount,
            firstVisibleBlockIndex: firstVisibleBlockIndex,
            lastVisibleBlockIndex: lastVisibleBlockIndex,
            peakLastVisibleBlockIndex: peakLastVisibleBlockIndex,
            peakVisibleBlockIndexSpan: peakVisibleBlockIndexSpan,
            scrollLifetimeMilliseconds: Self.durationMilliseconds(
                from: startedAtNanoseconds,
                to: lastEventNanoseconds
            ),
            blockAppearanceCount: blockAppearanceCount,
            blockDisappearanceCount: blockDisappearanceCount
        )
    }

    mutating func reset(
        pageID: String?,
        blockCount: Int,
        nowNanoseconds: UInt64 = Self.currentNanoseconds()
    ) {
        self.pageID = pageID
        self.blockCount = blockCount
        visibleBlockIndexesByID.removeAll()
        peakVisibleBlockCount = 0
        peakLastVisibleBlockIndex = nil
        peakVisibleBlockIndexSpan = 0
        startedAtNanoseconds = nowNanoseconds
        lastEventNanoseconds = nowNanoseconds
        blockAppearanceCount = 0
        blockDisappearanceCount = 0
    }

    mutating func blockAppeared(
        _ blockID: String,
        index: Int,
        nowNanoseconds: UInt64 = Self.currentNanoseconds()
    ) {
        if visibleBlockIndexesByID[blockID] == index {
            return
        }

        let wasVisible = visibleBlockIndexesByID[blockID] != nil
        visibleBlockIndexesByID[blockID] = index
        lastEventNanoseconds = nowNanoseconds
        if !wasVisible {
            blockAppearanceCount += 1
        }
        peakVisibleBlockCount = max(peakVisibleBlockCount, visibleBlockIndexesByID.count)
        peakLastVisibleBlockIndex = max(peakLastVisibleBlockIndex ?? index, index)
        peakVisibleBlockIndexSpan = max(peakVisibleBlockIndexSpan, metrics.visibleBlockIndexSpan)
    }

    mutating func blockDisappeared(
        _ blockID: String,
        nowNanoseconds: UInt64 = Self.currentNanoseconds()
    ) {
        guard visibleBlockIndexesByID.removeValue(forKey: blockID) != nil else {
            return
        }
        lastEventNanoseconds = nowNanoseconds
        blockDisappearanceCount += 1
    }

    private static func currentNanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    private static func durationMilliseconds(from start: UInt64, to end: UInt64) -> Double {
        Double(end - start) / 1_000_000
    }
}

struct CompactLibraryNavigationItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let systemImage: String
    let count: Int
    let collection: WorkspaceCollection
    let route: CompactRoute
    let identifier: String
}

enum CompactLibraryNavigationModel {
    static func items(snapshot: WorkspaceSnapshot) -> [CompactLibraryNavigationItem] {
        let diaryPageIDs = Set(snapshot.diaryPages.map(\.pageID))
        let allDocumentCount = snapshot.pages.filter { !diaryPageIDs.contains($0.id) }.count

        return [
            CompactLibraryNavigationItem(
                id: "all-documents",
                title: "全部文档",
                systemImage: "doc.text",
                count: allDocumentCount,
                collection: .allDocuments,
                route: .collection(.allDocuments),
                identifier: "editor.compact.all-documents"
            ),
            CompactLibraryNavigationItem(
                id: "diary",
                title: "日记",
                systemImage: "square.and.pencil",
                count: diaryPageIDs.count,
                collection: .diary,
                route: .collection(.diary),
                identifier: "editor.compact.diary"
            ),
            CompactLibraryNavigationItem(
                id: "favorites",
                title: "收藏",
                systemImage: "star",
                count: snapshot.favoritePages.count,
                collection: .favorites,
                route: .collection(.favorites),
                identifier: "editor.compact.favorites"
            )
        ]
    }
}

struct CompactCollectionPageListItem: Identifiable, Equatable, Sendable {
    let id: String
    let page: PageSummary
    let tagNames: [String]
    let preview: PageListPreview
}

enum CompactCollectionPageListModel {
    static func pages(snapshot: WorkspaceSnapshot, collection: WorkspaceCollection) -> [PageSummary] {
        let diaryPageIDs = Set(snapshot.diaryPages.map(\.pageID))

        switch collection {
        case .recent:
            return snapshot.pages
        case .diary:
            return snapshot.pages.filter { diaryPageIDs.contains($0.id) }
        case .allDocuments:
            return snapshot.pages.filter { !diaryPageIDs.contains($0.id) }
        case .favorites:
            return snapshot.favoritePages
        case .tag(let tagID):
            guard !tagID.isEmpty else {
                return []
            }
            let pageIDs = Set(
                snapshot.pageTags
                    .filter { $0.tagID == tagID }
                    .map(\.pageID)
            )
            return snapshot.pages.filter { pageIDs.contains($0.id) }
        case .search:
            return []
        case .archive:
            return snapshot.archivedPages
        }
    }

    static func items(snapshot: WorkspaceSnapshot, collection: WorkspaceCollection) -> [CompactCollectionPageListItem] {
        pages(snapshot: snapshot, collection: collection).map { page in
            CompactCollectionPageListItem(
                id: page.id,
                page: page,
                tagNames: tagNames(for: page, snapshot: snapshot),
                preview: PageListPreviewResolver.preview(
                    pageID: page.id,
                    blocks: snapshot.blocks,
                    attachments: snapshot.attachments
                )
            )
        }
    }

    private static func tagNames(for page: PageSummary, snapshot: WorkspaceSnapshot) -> [String] {
        let tagIDs = Set(
            snapshot.pageTags
                .filter { $0.pageID == page.id }
                .map(\.tagID)
        )

        return snapshot.tags
            .filter { tagIDs.contains($0.id) }
            .map(\.name)
    }
}

enum CompactRoute: Hashable {
    case pages
    case collection(WorkspaceCollection)
    case page(String)
}

enum CompactInitialNavigationResolver {
    static func initialPageID(
        selectedPageID: String?,
        availablePageIDs: [String]
    ) -> String? {
        guard let selectedPageID,
              availablePageIDs.contains(selectedPageID) else {
            return nil
        }
        return selectedPageID
    }
}

private struct CompactPageDestination: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    let pageID: String
    @State private var didRequestInitialFocus = false

    var body: some View {
        if let page = viewModel.snapshot.pages.first(where: { $0.id == pageID }) {
            EditorCanvasView(
                page: page,
                pages: viewModel.snapshot.pages,
                blocks: viewModel.editorVisibleBlocks(for: page.id),
                allBlocks: viewModel.snapshot.blocks,
                attachments: viewModel.snapshot.attachments,
                attachmentPreviewGenerationStatuses: viewModel.attachmentPreviewGenerationStatuses,
                markdownImportStatusText: viewModel.markdownImportStatusText,
                backlinks: viewModel.selectedPageBacklinks,
                externalLinks: viewModel.selectedPageExternalLinks,
                conflicts: viewModel.selectedPageConflicts,
                outlineItems: viewModel.selectedPageOutline,
                parentPageLink: viewModel.selectedPageParentLink,
                pageTagNames: viewModel.selectedPageTagNames,
                pendingFocusBlockID: viewModel.pendingFocusBlockID,
                canUndoTextEdit: viewModel.canUndoTextEdit,
                onAddParagraphBlock: {
                    viewModel.addParagraphBlockToCurrentPage()
                },
                onAddPageReference: { targetPageID in
                    viewModel.appendPageReferenceToCurrentPageForUI(targetPageID: targetPageID)
                },
                onAddBlockReference: { targetBlockID in
                    viewModel.appendBlockReferenceToCurrentPageForUI(targetBlockID: targetBlockID)
                },
                onInsertMarkdownLink: { blockID, label, url in
                    viewModel.insertMarkdownLinkForUI(blockID: blockID, label: label, url: url)
                },
                onInsertMarkdownLinkAtSelection: { blockID, label, url, selection in
                    viewModel.insertMarkdownLinkForUI(
                        blockID: blockID,
                        label: label,
                        url: url,
                        selection: selection
                    )
                },
                onRemoveMarkdownLinkAtSelection: { blockID, selection in
                    viewModel.removeMarkdownLinkForUI(blockID: blockID, selection: selection)
                },
                onApplyMarkdownInlineFormat: { blockID, format, selection in
                    viewModel.applyMarkdownInlineFormatForUI(
                        blockID: blockID,
                        format: format,
                        selection: selection
                    )
                },
                onUndoTextEdit: {
                    viewModel.undoLastTextEditForUI()
                },
                onFocusCanvas: {
                    viewModel.focusEditorCanvasForUI()
                },
                onMoveBlock: { blockID, targetIndex in
                    viewModel.moveBlockInCurrentPage(blockID: blockID, toIndex: targetIndex)
                },
                onMoveBlocks: { blockIDs, targetIndex in
                    viewModel.moveBlocksInCurrentPage(blockIDs: blockIDs, toIndex: targetIndex)
                },
                onMoveBlockByKeyboard: { blockID, direction in
                    viewModel.moveBlockByKeyboardForUI(blockID: blockID, direction: direction)
                },
                onInsertBlockAfter: { blockID in
                    viewModel.insertParagraphBlockAfterForUI(blockID: blockID)
                },
                onSplitTextBlockAtSelection: { blockID, selection in
                    viewModel.splitTextBlockAtSelectionForUI(blockID: blockID, selection: selection)
                },
                onMergeTextBlockWithPrevious: { blockID, selection in
                    viewModel.mergeTextBlockWithPreviousAtSelectionForUI(blockID: blockID, selection: selection)
                },
                onMergeTextBlockWithNext: { blockID, selection in
                    viewModel.mergeTextBlockWithNextAtSelectionForUI(blockID: blockID, selection: selection)
                },
                onIndentBlock: { blockID in
                    viewModel.indentBlockForUI(blockID: blockID)
                },
                onOutdentBlock: { blockID in
                    viewModel.outdentBlockForUI(blockID: blockID)
                },
                onDeleteBlock: { blockID in
                    viewModel.deleteBlockFromCurrentPage(blockID: blockID)
                },
                onDeleteBlocks: { blockIDs in
                    viewModel.deleteBlocksFromCurrentPage(blockIDs: blockIDs)
                },
                onSelectBacklink: { backlink in
                    viewModel.selectBacklink(backlink)
                },
                onSelectOutlineItem: { item in
                    viewModel.selectOutlineItem(item)
                },
                onOpenPageReference: { targetPageID in
                    viewModel.openPageReference(targetPageID: targetPageID)
                },
                onOpenParentPage: {
                    viewModel.openParentPageForCurrentPageForUI()
                },
                onOpenBlockReference: { targetPageID, targetBlockID in
                    viewModel.openBlockReference(targetPageID: targetPageID, targetBlockID: targetBlockID)
                },
                onAcceptConflict: { conflict in
                    viewModel.acceptRemoteConflictForUI(id: conflict.id)
                },
                onAcceptAllConflicts: {
                    viewModel.acceptAllRemoteConflictsForSelectedPageForUI()
                },
                onAcceptLocalConflict: { conflict in
                    viewModel.acceptLocalConflictForUI(id: conflict.id)
                },
                onAcceptAllLocalConflicts: {
                    viewModel.acceptAllLocalConflictsForSelectedPageForUI()
                },
                onResolveConflictManually: { conflict, text in
                    viewModel.resolveConflictManuallyForUI(id: conflict.id, text: text)
                },
                onResolveAllConflictsManually: { mergedTextsByConflictID in
                    viewModel.resolveAllManualConflictsForSelectedPageForUI(
                        mergedTextsByConflictID: mergedTextsByConflictID
                    )
                },
                onPageTitleChange: { title in
                    viewModel.editSelectedPageTitle(title)
                },
                onImportMarkdown: { sourceURL in
                    viewModel.importMarkdownFileForCurrentPage(sourceURL: sourceURL)
                },
                onExportMarkdown: {
                    viewModel.exportCurrentPageMarkdown()
                },
                onExportMarkdownPackage: { destinationURL in
                    viewModel.exportCurrentPageMarkdownPackageForUI(to: destinationURL)
                },
                onBlockTextChange: { blockID, text in
                    viewModel.editBlockText(blockID: blockID, text: text)
                },
                onTableRowsChange: { blockID, rows in
                    viewModel.updateTableRowsForUI(blockID: blockID, rows: rows)
                },
                onBlockTypeChange: { blockID, type in
                    viewModel.changeBlockTypeForUI(blockID: blockID, type: type)
                },
                onConvertBlockToPage: { blockID in
                    viewModel.convertTextBlockToPageForUI(blockID: blockID)
                },
                onTaskItemCompletionChange: { blockID, isCompleted in
                    viewModel.updateTaskItemCompletionForUI(
                        blockID: blockID,
                        isCompleted: isCompleted
                    )
                },
                onCodeBlockLineWrappingChange: { blockID, isWrapped in
                    viewModel.updateCodeBlockLineWrapping(blockID: blockID, isWrapped: isWrapped)
                },
                onToggleBlockExpansion: { blockID in
                    viewModel.toggleBlockExpansion(blockID: blockID)
                },
                isToggleBlockExpanded: { blockID in
                    viewModel.isToggleBlockExpanded(blockID: blockID)
                },
                onImportAttachment: { sourceURL in
                    viewModel.importAttachmentForCurrentPage(sourceURL: sourceURL)
                },
                onImportAttachmentsAfterBlock: { sourceURLs, blockID in
                    viewModel.importAttachmentsForCurrentPage(
                        sourceURLs: sourceURLs,
                        afterBlockID: blockID
                    )
                },
                onRetryAttachmentPreview: { attachmentID in
                    viewModel.retryAttachmentPreviewGeneration(attachmentID: attachmentID)
                },
                onPendingBlockFocusHandled: {
                    _ = viewModel.consumePendingFocusBlockID()
                }
            )
            .onAppear {
                viewModel.selectPage(id: page.id)
                requestInitialFocusIfNeeded()
            }
        } else {
            Color.white
                .navigationTitle("编辑器")
        }
    }

    private func requestInitialFocusIfNeeded() {
        guard !didRequestInitialFocus else {
            return
        }
        didRequestInitialFocus = true
        _ = viewModel.focusEditorCanvasForUI()
    }
}

struct SidebarNavigationItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let systemImage: String
    let count: Int
    let showsCount: Bool
    let collection: WorkspaceCollection
    let identifier: String
    let isSelected: Bool

    init(
        id: String,
        title: String,
        systemImage: String,
        count: Int,
        showsCount: Bool = true,
        collection: WorkspaceCollection,
        identifier: String,
        isSelected: Bool
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.count = count
        self.showsCount = showsCount
        self.collection = collection
        self.identifier = identifier
        self.isSelected = isSelected
    }
}

struct SidebarNavigationModel: Equatable, Sendable {
    let primaryItems: [SidebarNavigationItem]
    let tagItems: [SidebarNavigationItem]
    let utilityItems: [SidebarNavigationItem]

    init(snapshot: WorkspaceSnapshot, selectedCollection: WorkspaceCollection) {
        let diaryPageIDs = Set(snapshot.diaryPages.map(\.pageID))
        let allDocumentCount = snapshot.pages.filter { !diaryPageIDs.contains($0.id) }.count
        let tagCounts = Dictionary(
            grouping: snapshot.pageTags,
            by: \.tagID
        )
        .mapValues(\.count)

        primaryItems = [
            SidebarNavigationItem(
                id: "recent",
                title: "近期文件",
                systemImage: "clock.arrow.circlepath",
                count: snapshot.pages.count,
                collection: .recent,
                identifier: "editor.collection.recent",
                isSelected: selectedCollection == .recent
            ),
            SidebarNavigationItem(
                id: "all-documents",
                title: "全部文档",
                systemImage: "doc.text",
                count: allDocumentCount,
                collection: .allDocuments,
                identifier: "editor.collection.all-documents",
                isSelected: selectedCollection == .allDocuments
            ),
            SidebarNavigationItem(
                id: "diary",
                title: "日记",
                systemImage: "square.and.pencil",
                count: diaryPageIDs.count,
                collection: .diary,
                identifier: "editor.collection.diary",
                isSelected: selectedCollection == .diary
            ),
            SidebarNavigationItem(
                id: "favorites",
                title: "收藏",
                systemImage: "star",
                count: snapshot.favoritePages.count,
                collection: .favorites,
                identifier: "editor.collection.favorites",
                isSelected: selectedCollection == .favorites
            )
        ]

        tagItems = snapshot.tags.map { tag in
            SidebarNavigationItem(
                id: "tag-\(tag.id)",
                title: tag.path,
                systemImage: "tag",
                count: tagCounts[tag.id] ?? 0,
                collection: .tag(tag.id),
                identifier: "editor.collection.tag.\(tag.id)",
                isSelected: selectedCollection == .tag(tag.id)
            )
        }

        utilityItems = [
            SidebarNavigationItem(
                id: "search",
                title: "搜索",
                systemImage: "magnifyingglass",
                count: 0,
                showsCount: false,
                collection: .search,
                identifier: "editor.collection.search",
                isSelected: selectedCollection == .search
            ),
            SidebarNavigationItem(
                id: "archive",
                title: "归档",
                systemImage: "archivebox",
                count: snapshot.archivedPages.count,
                showsCount: snapshot.archivedPages.count > 0,
                collection: .archive,
                identifier: "editor.collection.archive",
                isSelected: selectedCollection == .archive
            )
        ]
    }
}

enum SidebarChrome {
    static let horizontalPadding: Double = 8
    static let verticalPadding: Double = 10
    static let sectionSpacing: Double = 8
    static let rowSpacing: Double = 2
    static let rowCornerRadius: Double = 13
    static let rowVerticalPadding: Double = 8
    static let nestedItemIndent: Double = 16
    static let dividerOpacity: Double = 0.10

    static var backgroundColor: Color {
        Color(red: 0.968, green: 0.962, blue: 0.952)
    }

    static var selectedFillColor: Color {
        Color(red: 0.78, green: 0.75, blue: 0.70)
    }

    static var selectedForegroundColor: Color {
        Color(red: 0.25, green: 0.23, blue: 0.34)
    }

    static var foregroundColor: Color {
        Color(red: 0.35, green: 0.34, blue: 0.43)
    }

    static var mutedForegroundColor: Color {
        Color(red: 0.54, green: 0.52, blue: 0.61)
    }
}

private struct WorkspaceSidebar: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat(SidebarChrome.sectionSpacing)) {
                sidebarHeader
                newDocumentButton
                sidebarDivider
                sidebarGroup(items: sidebarModel.primaryItems)
                favoritePageShortcuts
                tagGroup
                sidebarDivider
                sidebarGroup(items: sidebarModel.utilityItems)
            }
            .padding(.horizontal, CGFloat(SidebarChrome.horizontalPadding))
            .padding(.vertical, CGFloat(SidebarChrome.verticalPadding))
        }
        .navigationTitle("编辑器")
        .background(SidebarChrome.backgroundColor)
    }

    private var sidebarModel: SidebarNavigationModel {
        SidebarNavigationModel(
            snapshot: viewModel.snapshot,
            selectedCollection: viewModel.selectedCollection
        )
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(red: 0.78, green: 0.72, blue: 0.64))
                .frame(width: 28, height: 28)
                .overlay {
                    Text("文")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text("Editor")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(SidebarChrome.selectedForegroundColor)
                Text("本地文档")
                    .font(.caption2)
                    .foregroundStyle(SidebarChrome.mutedForegroundColor)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Editor 本地文档")
    }

    private var newDocumentButton: some View {
        Button {
            _ = viewModel.createNewDocumentForUI()
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "doc.badge.plus")
                    .font(.body.weight(.medium))
                    .frame(width: 22)
                    .foregroundStyle(SidebarChrome.mutedForegroundColor)
                Text("新建文档")
                    .font(.body.weight(.medium))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, CGFloat(SidebarChrome.rowVerticalPadding))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(SidebarChrome.foregroundColor)
        .accessibilityIdentifier("editor.sidebar.new-document")
    }

    private func sidebarGroup(items: [SidebarNavigationItem]) -> some View {
        VStack(spacing: CGFloat(SidebarChrome.rowSpacing)) {
            ForEach(items) { item in
                CollectionRailButton(item: item) {
                    viewModel.selectCollection(item.collection)
                }
            }
        }
    }

    private var sidebarDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(SidebarChrome.dividerOpacity))
            .frame(height: 1)
            .padding(.horizontal, 8)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var favoritePageShortcuts: some View {
        if !viewModel.snapshot.favoritePages.isEmpty {
            VStack(alignment: .leading, spacing: CGFloat(SidebarChrome.rowSpacing)) {
                SidebarSectionLabel("收藏")
                ForEach(viewModel.snapshot.favoritePages) { page in
                    Button {
                        viewModel.selectPage(id: page.id)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "star.fill")
                                .font(.caption.weight(.semibold))
                                .frame(width: 18)
                                .foregroundStyle(Color(red: 0.74, green: 0.62, blue: 0.30))
                            Text(page.title)
                                .font(.callout)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, 24)
                        .padding(.trailing, 12)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(SidebarChrome.foregroundColor)
                    .accessibilityIdentifier("editor.favorite-page.\(page.id)")
                }
            }
        }
    }

    @ViewBuilder
    private var tagGroup: some View {
        if !sidebarModel.tagItems.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                CollectionRailButton(
                    item: SidebarNavigationItem(
                        id: "tags",
                        title: "标签",
                        systemImage: "tag",
                        count: sidebarModel.tagItems.count,
                        collection: .tag(""),
                        identifier: "editor.collection.tags",
                        isSelected: isTagsSelected
                    )
                ) {
                    viewModel.selectCollection(.tag(""))
                }

                ForEach(sidebarModel.tagItems) { item in
                    CollectionRailButton(item: item) {
                        viewModel.selectCollection(item.collection)
                    }
                    .padding(.leading, CGFloat(SidebarChrome.nestedItemIndent))
                }
            }
        }
    }

    private var isTagsSelected: Bool {
        if case .tag = viewModel.selectedCollection {
            return true
        }
        return false
    }
}

private struct SidebarSectionLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(SidebarChrome.mutedForegroundColor.opacity(0.78))
            .padding(.horizontal, 12)
            .padding(.top, 2)
    }
}

private struct CollectionRailButton: View {
    let item: SidebarNavigationItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: item.systemImage)
                    .font(.body.weight(.medium))
                    .frame(width: 22)
                    .foregroundStyle(item.isSelected ? SidebarChrome.selectedForegroundColor : SidebarChrome.mutedForegroundColor)
                Text(item.title)
                    .font(item.isSelected ? .body.weight(.semibold) : .body.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 6)
                if item.showsCount {
                    Text("\(item.count)")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(item.isSelected ? SidebarChrome.selectedForegroundColor.opacity(0.80) : SidebarChrome.mutedForegroundColor)
                        .monospacedDigit()
                }
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, CGFloat(SidebarChrome.rowVerticalPadding))
                .background(
                    RoundedRectangle(cornerRadius: CGFloat(SidebarChrome.rowCornerRadius), style: .continuous)
                        .fill(item.isSelected ? SidebarChrome.selectedFillColor.opacity(0.78) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CGFloat(SidebarChrome.rowCornerRadius), style: .continuous)
                        .stroke(item.isSelected ? Color.black.opacity(0.035) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(item.isSelected ? SidebarChrome.selectedForegroundColor : SidebarChrome.foregroundColor)
        .accessibilityIdentifier(item.identifier)
        .accessibilityValue(item.isSelected ? "已选中，\(item.count)" : "未选中，\(item.count)")
    }
}

private struct CloudKitAccountStatusSection: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SidebarSectionLabel("同步")
            HStack(spacing: 8) {
                Image(systemName: statusIconName)
                    .foregroundStyle(statusColor)
                    .frame(width: 18)

                Text(viewModel.cloudKitAccountStatusText)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .accessibilityIdentifier("editor.icloud-status")

            HStack(spacing: 12) {
                Button {
                    viewModel.syncNow()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.icloud")
                }
                .buttonStyle(.borderless)
                .help("立即同步")
                .accessibilityIdentifier("editor.sync-now")

                Button {
                    viewModel.refreshCloudKitAccountStatusForUI()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("刷新 iCloud 状态")
                .accessibilityIdentifier("editor.refresh-icloud-status")

                Button {
                    viewModel.purgeUnreferencedAttachmentsForUI()
                } label: {
                    Image(systemName: "trash.slash")
                }
                .buttonStyle(.borderless)
                .help("清理未引用附件")
                .accessibilityIdentifier("editor.clean-attachments")
            }
            .padding(.horizontal, 10)

            Text(viewModel.syncStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .accessibilityIdentifier("editor.sync-status")
        }
    }

    private var statusIconName: String {
        switch viewModel.cloudKitAccountStatus {
        case .available:
            return "checkmark.icloud"
        case .noAccount, .restricted, .temporarilyUnavailable:
            return "xmark.icloud"
        case .couldNotDetermine, nil:
            return "icloud"
        }
    }

    private var statusColor: Color {
        switch viewModel.cloudKitAccountStatus {
        case .available:
            return .green
        case .noAccount, .restricted, .temporarilyUnavailable:
            return .red
        case .couldNotDetermine, nil:
            return .secondary
        }
    }
}

private struct PageListView: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                switch viewModel.selectedCollection {
                case .recent:
                    pageRowsSection(title: "近期文件", pages: viewModel.visibleDocumentPages)
                case .diary:
                    pageRowsSection(title: "日记", pages: viewModel.visibleDocumentPages)
                case .allDocuments:
                    pageRowsSection(title: "全部文档", pages: viewModel.visibleDocumentPages)
                case .favorites:
                    pageRowsSection(title: "收藏", pages: viewModel.visibleDocumentPages)
                case .tag(let tagID):
                    tagSection(tagID: tagID)
                case .search:
                    SearchSectionView(viewModel: viewModel)
                case .archive:
                    archiveSection
                }

                if viewModel.canUndoPageArchive && viewModel.selectedCollection != .archive {
                    undoArchiveSection
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
        }
        .navigationTitle(navigationTitle)
        .background(Color(red: 0.986, green: 0.987, blue: 0.989))
    }

    @ViewBuilder
    private func pageRowsSection(title: String, pages: [PageSummary]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)

            ForEach(pages) { page in
                pageRow(page)
            }
        }
    }

    @ViewBuilder
    private func tagSection(tagID: String) -> some View {
        if tagID.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("标签")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 2)

                ForEach(viewModel.snapshot.tags) { tag in
                    Button {
                        viewModel.selectCollection(.tag(tag.id))
                    } label: {
                        Label(tag.path, systemImage: "tag")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("editor.tag-row.\(tag.id)")
                }
            }
        } else {
            pageRowsSection(title: tagName(for: tagID), pages: viewModel.visibleDocumentPages)
        }
    }

    private var archiveSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if viewModel.canUndoPageArchive {
                undoArchiveSection
            }

            Text("归档")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)

            ForEach(viewModel.snapshot.archivedPages) { page in
                ArchivedPageRow(
                    page: page,
                    onRestore: {
                        viewModel.restoreArchivedPageForUI(id: page.id)
                    },
                    onDelete: {
                        viewModel.permanentlyDeleteArchivedPageForUI(id: page.id)
                    }
                )
            }
        }
    }

    private var undoArchiveSection: some View {
        Button {
            viewModel.undoLastPageArchiveForUI()
        } label: {
            Label("撤销归档", systemImage: "arrow.uturn.backward")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("editor.undo-page-archive")
    }

    private func pageRow(_ page: PageSummary) -> some View {
        PageRow(
            page: page,
            isSelected: viewModel.selectedPageID == page.id,
            tagNames: tagNames(for: page),
            preview: PageListPreviewResolver.preview(
                pageID: page.id,
                blocks: viewModel.snapshot.blocks,
                attachments: viewModel.snapshot.attachments
            ),
            usesRichPreview: true,
            onFavoriteToggle: {
                viewModel.updatePageFavoriteForUI(
                    id: page.id,
                    isFavorite: !page.isFavorite
                )
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectPage(id: page.id)
        }
        .contextMenu {
            Button {
                viewModel.updatePageFavoriteForUI(
                    id: page.id,
                    isFavorite: !page.isFavorite
                )
            } label: {
                Label(
                    page.isFavorite ? "取消收藏" : "加入收藏",
                    systemImage: page.isFavorite ? "star.slash" : "star"
                )
            }

            Button {
                viewModel.archivePageForUI(id: page.id)
            } label: {
                Label("归档", systemImage: "archivebox")
            }
        }
    }

    private var navigationTitle: String {
        switch viewModel.selectedCollection {
        case .recent:
            return "近期文件"
        case .diary:
            return "日记"
        case .allDocuments:
            return "全部文档"
        case .favorites:
            return "收藏"
        case .tag(let tagID):
            return tagID.isEmpty ? "标签" : tagName(for: tagID)
        case .search:
            return "搜索"
        case .archive:
            return "归档"
        }
    }

    private func tagName(for tagID: String) -> String {
        viewModel.snapshot.tags.first { $0.id == tagID }?.path ?? "标签"
    }

    private func tagNames(for page: PageSummary) -> [String] {
        let tagIDs = Set(
            viewModel.snapshot.pageTags
                .filter { $0.pageID == page.id }
                .map(\.tagID)
        )
        return viewModel.snapshot.tags
            .filter { tagIDs.contains($0.id) }
            .map(\.name)
    }

    private var selectedPageBinding: Binding<String?> {
        Binding {
            viewModel.selectedPageID
        } set: { newValue in
            guard let newValue,
                  newValue != viewModel.selectedPageID else {
                return
            }
            DispatchQueue.main.async {
                viewModel.selectPage(id: newValue)
            }
        }
    }
}

private struct CompactPageListView: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        List {
            SearchSectionView(viewModel: viewModel)

            ForEach(Array(viewModel.snapshot.notebooks.enumerated()), id: \.element.id) { index, notebook in
                Section {
                    ForEach(pages(in: notebook)) { page in
                        NavigationLink(value: CompactRoute.page(page.id)) {
                            PageRow(page: page, isSelected: viewModel.selectedPageID == page.id)
                        }
                        .accessibilityIdentifier("editor.page.\(page.id)")
                        .contextMenu {
                            Button {
                                viewModel.updatePageFavoriteForUI(
                                    id: page.id,
                                    isFavorite: !page.isFavorite
                                )
                            } label: {
                                Label(
                                    page.isFavorite ? "取消收藏" : "加入收藏",
                                    systemImage: page.isFavorite ? "star.slash" : "star"
                                )
                            }

                            Button {
                                viewModel.archivePageForUI(id: page.id)
                            } label: {
                                Label("归档", systemImage: "archivebox")
                            }
                        }
                    }
                } header: {
                    NotebookSectionHeader(
                        notebook: notebook,
                        nestingLevel: nestingLevel(for: notebook),
                        canMoveUp: NotebookHierarchy.canMoveUp(
                            notebook: notebook,
                            in: viewModel.snapshot.notebooks
                        ),
                        canMoveDown: NotebookHierarchy.canMoveDown(
                            notebook: notebook,
                            in: viewModel.snapshot.notebooks
                        ),
                        canIndent: index > 0,
                        canOutdent: notebook.parentNotebookID != nil,
                        onRename: { name in
                            viewModel.renameNotebookForUI(id: notebook.id, name: name)
                        },
                        onMoveUp: {
                            if let targetIndex = NotebookHierarchy.siblingTargetIndex(
                                for: notebook,
                                direction: .up,
                                in: viewModel.snapshot.notebooks
                            ) {
                                viewModel.moveNotebookForUI(id: notebook.id, toIndex: targetIndex)
                            }
                        },
                        onMoveDown: {
                            if let targetIndex = NotebookHierarchy.siblingTargetIndex(
                                for: notebook,
                                direction: .down,
                                in: viewModel.snapshot.notebooks
                            ) {
                                viewModel.moveNotebookForUI(id: notebook.id, toIndex: targetIndex)
                            }
                        },
                        onIndent: {
                            _ = viewModel.indentNotebookForUI(id: notebook.id)
                        },
                        onOutdent: {
                            _ = viewModel.outdentNotebookForUI(id: notebook.id)
                        },
                        onAddChildNotebook: {
                            _ = viewModel.addNotebookToSelectedWorkspace(parentNotebookID: notebook.id)
                        },
                        onAddPage: {
                            _ = viewModel.addPageToSelectedWorkspace(notebookID: notebook.id)
                        }
                    )
                }
            }

            Section {
                Button {
                    _ = viewModel.addNotebookToSelectedWorkspace()
                } label: {
                    Label("新建笔记本", systemImage: "folder.badge.plus")
                }
            }

            if viewModel.canUndoPageArchive {
                Section {
                    Button {
                        viewModel.undoLastPageArchiveForUI()
                    } label: {
                        Label("撤销归档", systemImage: "arrow.uturn.backward")
                    }
                    .accessibilityIdentifier("editor.undo-page-archive")
                }
            }

            if !viewModel.snapshot.archivedPages.isEmpty {
                Section("归档") {
                    ForEach(viewModel.snapshot.archivedPages) { page in
                        ArchivedPageRow(
                            page: page,
                            onRestore: {
                                viewModel.restoreArchivedPageForUI(id: page.id)
                            },
                            onDelete: {
                                viewModel.permanentlyDeleteArchivedPageForUI(id: page.id)
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("页面")
        .scrollContentBackground(.hidden)
        .background(Color.white)
    }

    private func pages(in notebook: NotebookSummary) -> [PageSummary] {
        viewModel.snapshot.pages.filter { $0.notebookID == notebook.id }
    }

    private func nestingLevel(for notebook: NotebookSummary) -> Int {
        NotebookHierarchy.nestingLevel(for: notebook, in: viewModel.snapshot.notebooks)
    }
}

private struct CompactCollectionDestination: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    let collection: WorkspaceCollection
    @State private var didSelectCollection = false

    var body: some View {
        Group {
            if collection == .diary {
                if viewModel.selectedCollection == .diary,
                   let pageID = viewModel.selectedPageID {
                    CompactPageDestination(viewModel: viewModel, pageID: pageID)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle("日记")
                }
            } else {
                CompactCollectionPageListView(viewModel: viewModel, collection: collection)
            }
        }
        .onAppear {
            guard !didSelectCollection else {
                return
            }
            didSelectCollection = true
            viewModel.selectCollection(collection)
        }
    }
}

private struct CompactCollectionPageListView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    let collection: WorkspaceCollection

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(items) { item in
                    NavigationLink(value: CompactRoute.page(item.page.id)) {
                        CompactRecentPageCard(
                            page: item.page,
                            tagNames: item.tagNames,
                            preview: item.preview
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("editor.page.\(item.page.id)")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .navigationTitle(navigationTitle)
        .background(Color(red: 0.965, green: 0.958, blue: 0.948))
    }

    private var items: [CompactCollectionPageListItem] {
        CompactCollectionPageListModel.items(
            snapshot: viewModel.snapshot,
            collection: collection
        )
    }

    private var navigationTitle: String {
        switch collection {
        case .allDocuments:
            return "全部文档"
        case .favorites:
            return "收藏"
        case .recent:
            return "近期文件"
        case .diary:
            return "日记"
        case .tag:
            return "标签"
        case .search:
            return "搜索"
        case .archive:
            return "归档"
        }
    }
}

enum NotebookHierarchyMoveDirection {
    case up
    case down
}

enum NotebookHierarchy {
    static func nestingLevel(for notebook: NotebookSummary, in notebooks: [NotebookSummary]) -> Int {
        var level = 0
        var visitedNotebookIDs: Set<String> = [notebook.id]
        var parentNotebookID = notebook.parentNotebookID

        while let currentParentID = parentNotebookID,
              !visitedNotebookIDs.contains(currentParentID),
              let parentNotebook = notebooks.first(where: { $0.id == currentParentID }) {
            level += 1
            visitedNotebookIDs.insert(currentParentID)
            parentNotebookID = parentNotebook.parentNotebookID
        }

        return min(level, 6)
    }

    static func canMoveUp(notebook: NotebookSummary, in notebooks: [NotebookSummary]) -> Bool {
        siblingIndex(for: notebook, in: notebooks).map { $0 > 0 } ?? false
    }

    static func canMoveDown(notebook: NotebookSummary, in notebooks: [NotebookSummary]) -> Bool {
        guard let siblingIndex = siblingIndex(for: notebook, in: notebooks) else {
            return false
        }
        return siblingIndex < siblings(of: notebook, in: notebooks).count - 1
    }

    static func siblingTargetIndex(
        for notebook: NotebookSummary,
        direction: NotebookHierarchyMoveDirection,
        in notebooks: [NotebookSummary]
    ) -> Int? {
        guard let siblingIndex = siblingIndex(for: notebook, in: notebooks) else {
            return nil
        }

        switch direction {
        case .up:
            return siblingIndex > 0 ? siblingIndex - 1 : nil
        case .down:
            let siblingCount = siblings(of: notebook, in: notebooks).count
            return siblingIndex < siblingCount - 1 ? siblingIndex + 1 : nil
        }
    }

    private static func siblingIndex(
        for notebook: NotebookSummary,
        in notebooks: [NotebookSummary]
    ) -> Int? {
        siblings(of: notebook, in: notebooks).firstIndex { $0.id == notebook.id }
    }

    private static func siblings(
        of notebook: NotebookSummary,
        in notebooks: [NotebookSummary]
    ) -> [NotebookSummary] {
        notebooks.filter { $0.parentNotebookID == notebook.parentNotebookID }
    }
}

private struct NotebookSectionHeader: View {
    let notebook: NotebookSummary
    let nestingLevel: Int
    let canMoveUp: Bool
    let canMoveDown: Bool
    let canIndent: Bool
    let canOutdent: Bool
    let onRename: (String) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onIndent: () -> Void
    let onOutdent: () -> Void
    let onAddChildNotebook: () -> Void
    let onAddPage: () -> Void
    @State private var draftName: String

    init(
        notebook: NotebookSummary,
        nestingLevel: Int = 0,
        canMoveUp: Bool,
        canMoveDown: Bool,
        canIndent: Bool = false,
        canOutdent: Bool = false,
        onRename: @escaping (String) -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onIndent: @escaping () -> Void = {},
        onOutdent: @escaping () -> Void = {},
        onAddChildNotebook: @escaping () -> Void = {},
        onAddPage: @escaping () -> Void
    ) {
        self.notebook = notebook
        self.nestingLevel = nestingLevel
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.canIndent = canIndent
        self.canOutdent = canOutdent
        self.onRename = onRename
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onIndent = onIndent
        self.onOutdent = onOutdent
        self.onAddChildNotebook = onAddChildNotebook
        self.onAddPage = onAddPage
        _draftName = State(initialValue: notebook.name)
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("笔记本", text: nameBinding)
                .textFieldStyle(.plain)
                .font(.caption.weight(.semibold))
                .accessibilityIdentifier("editor.notebook.\(notebook.id).name")
            Spacer(minLength: 8)

            Button {
                onMoveUp()
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveUp)
            .help("上移")
            .accessibilityLabel("上移笔记本")
            .accessibilityValue(controlAvailabilityValue(canMoveUp))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).move-up")

            Button {
                onMoveDown()
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveDown)
            .help("下移")
            .accessibilityLabel("下移笔记本")
            .accessibilityValue(controlAvailabilityValue(canMoveDown))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).move-down")

            Button {
                onOutdent()
            } label: {
                Image(systemName: "decrease.indent")
            }
            .buttonStyle(.borderless)
            .disabled(!canOutdent)
            .help("减少缩进")
            .accessibilityLabel("减少笔记本缩进")
            .accessibilityValue(controlAvailabilityValue(canOutdent))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).outdent")

            Button {
                onIndent()
            } label: {
                Image(systemName: "increase.indent")
            }
            .buttonStyle(.borderless)
            .disabled(!canIndent)
            .help("增加缩进")
            .accessibilityLabel("增加笔记本缩进")
            .accessibilityValue(controlAvailabilityValue(canIndent))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).indent")

            Button {
                onAddChildNotebook()
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.borderless)
            .help("新建子笔记本")
            .accessibilityLabel("新建子笔记本")
            .accessibilityValue(controlAvailabilityValue(true))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).add-child-notebook")

            Button {
                onAddPage()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("新建页面")
            .accessibilityLabel("在笔记本中新建页面")
            .accessibilityValue(controlAvailabilityValue(true))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).add-page")
        }
        .onChange(of: notebook.name) { _, name in
            if draftName != name {
                draftName = name
            }
        }
        .padding(.leading, CGFloat(nestingLevel) * 14)
    }

    private var nameBinding: Binding<String> {
        Binding {
            draftName
        } set: { name in
            draftName = name
            onRename(name)
        }
    }

    private func controlAvailabilityValue(_ isAvailable: Bool) -> String {
        isAvailable ? "可用" : "不可用"
    }
}

private struct SearchSectionView: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("搜索")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            TextField("搜索", text: searchBinding)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("editor.search-field")

            ForEach(viewModel.searchResults) { result in
                Button {
                    viewModel.selectSearchResult(result)
                } label: {
                    SearchResultRow(result: result)
                }
                .buttonStyle(.plain)
                .disabled(result.destinationPageID == nil)
            }
        }
    }

    private var searchBinding: Binding<String> {
        Binding {
            viewModel.searchQuery
        } set: { query in
            viewModel.updateSearchQuery(query)
        }
    }
}

private struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(result.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("editor.search-result.\(result.id)")
    }

    private var iconName: String {
        switch result.entityType {
        case "page":
            return "doc.text"
        case "attachment":
            return "paperclip"
        default:
            return "text.alignleft"
        }
    }
}

private struct PageRow: View {
    let page: PageSummary
    var isSelected = false
    var tagNames: [String] = []
    var preview: PageListPreview?
    var usesRichPreview = false
    var onFavoriteToggle: (() -> Void)? = nil

    var body: some View {
        if usesRichPreview {
            richPreviewBody
        } else {
            compactBody
        }
    }

    private var compactBody: some View {
        HStack(spacing: 8) {
            pageIcon

            VStack(alignment: .leading, spacing: 3) {
                Text(page.title)
                    .font(isSelected ? .body.weight(.semibold) : .body)
                    .lineLimit(1)
                    .accessibilityLabel(page.title)
                    .accessibilityValue(pageRowAccessibilityValue)
                    .accessibilityIdentifier("editor.page-row.\(page.id)")

                if !tagNames.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tagNames, id: \.self) { tagName in
                            Text(tagName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                    .accessibilityHidden(true)
                }
            }

            Spacer(minLength: 8)

            if let onFavoriteToggle {
                favoriteButton(onFavoriteToggle)
            } else if page.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.09) : Color.clear)
        )
    }

    private var richPreviewBody: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? Color.red.opacity(0.72) : Color.clear)
                .frame(width: 4)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    pageIcon

                    Text(page.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                        .accessibilityLabel(page.title)
                        .accessibilityValue(pageRowAccessibilityValue)
                        .accessibilityIdentifier("editor.page-row.\(page.id)")

                    Spacer(minLength: 8)

                    if let onFavoriteToggle {
                        favoriteButton(onFavoriteToggle)
                    } else if page.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)
                    }
                }

                if let excerpt = preview?.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if preview?.imageAttachment != nil || preview?.fileAttachment != nil {
                    HStack(alignment: .top, spacing: 10) {
                        if let imageAttachment = preview?.imageAttachment {
                            PageRowImageAttachmentThumbnail(attachment: imageAttachment)
                        }

                        if let fileAttachment = preview?.fileAttachment {
                            PageRowFileAttachmentPill(attachment: fileAttachment)
                        }
                    }
                }

                if !tagNames.isEmpty {
                    tagChips
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.secondary.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.secondary.opacity(0.06) : Color.clear, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var pageIcon: some View {
        Image(systemName: "doc.text")
            .font(.callout)
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .accessibilityHidden(true)
    }

    private var tagChips: some View {
        HStack(spacing: 5) {
            ForEach(tagNames, id: \.self) { tagName in
                Text(tagName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color(red: 0.45, green: 0.28, blue: 0.70))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.45, green: 0.28, blue: 0.70).opacity(0.10))
                    .clipShape(Capsule())
            }
        }
        .accessibilityHidden(true)
    }

    private func favoriteButton(_ onFavoriteToggle: @escaping () -> Void) -> some View {
        Button {
            onFavoriteToggle()
        } label: {
            Image(systemName: page.isFavorite ? "star.fill" : "star")
                .foregroundStyle(page.isFavorite ? .yellow : .secondary)
        }
        .buttonStyle(.borderless)
        .help(page.isFavorite ? "取消收藏" : "加入收藏")
        .accessibilityLabel(page.isFavorite ? "取消收藏页面" : "收藏页面")
        .accessibilityValue(page.isFavorite ? "已收藏" : "未收藏")
        .accessibilityIdentifier("editor.page.\(page.id).favorite")
    }

    private var pageRowAccessibilityValue: String {
        let selection = isSelected ? "已选中" : "未选中"
        let favorite = page.isFavorite ? "已收藏" : "未收藏"
        let tags = tagNames.isEmpty ? "无标签" : "标签：\(tagNames.joined(separator: ", "))"
        return "\(selection), \(favorite), \(tags)"
    }
}

private struct PageRowImageAttachmentThumbnail: View {
    let attachment: AttachmentSnapshot

    var body: some View {
        Group {
            if let image = thumbnailImage {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.08))
            }
        }
        .frame(width: 112, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityLabel("图片附件")
        .accessibilityValue(attachment.originalFilename)
    }

    private var thumbnailImage: Image? {
        let path = attachment.thumbnailPath ?? attachment.localPath
#if os(macOS)
        guard let image = NSImage(contentsOfFile: path) else {
            return nil
        }
        return Image(nsImage: image)
#elseif os(iOS)
        guard let image = UIImage(contentsOfFile: path) else {
            return nil
        }
        return Image(uiImage: image)
#else
        return nil
#endif
    }
}

private struct PageRowFileAttachmentPill: View {
    let attachment: AttachmentSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(attachment.originalFilename)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(fileExtension)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
        }
        .frame(width: 108, height: 72, alignment: .leading)
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityLabel("文件附件")
        .accessibilityValue(attachment.originalFilename)
    }

    private var fileExtension: String {
        let ext = (attachment.originalFilename as NSString).pathExtension
        return ext.isEmpty ? "文件" : ext.uppercased()
    }
}

private struct ArchivedPageRow: View {
    let page: PageSummary
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "archivebox")
                .foregroundStyle(.secondary)

            Text(page.title)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button {
                onRestore()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)
            .help("恢复")
            .accessibilityIdentifier("editor.restore-page.\(page.id)")

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("永久删除")
            .accessibilityIdentifier("editor.delete-archived-page.\(page.id)")
        }
        .padding(.vertical, 5)
        .accessibilityIdentifier("editor.archived-page.\(page.id)")
    }
}

private struct EditorCanvasView: View {
    let page: PageSummary?
    let pages: [PageSummary]
    let blocks: [BlockSnapshot]
    let allBlocks: [BlockSnapshot]
    let attachments: [AttachmentSnapshot]
    let attachmentPreviewGenerationStatuses: [String: AttachmentPreviewGenerationStatus]
    let markdownImportStatusText: String?
    let backlinks: [Backlink]
    let externalLinks: [ExternalLink]
    let conflicts: [ConflictSnapshot]
    let outlineItems: [PageOutlineItem]
    let parentPageLink: PageParentLink?
    let pageTagNames: [String]
    let pendingFocusBlockID: String?
    let canUndoTextEdit: Bool
    let onAddParagraphBlock: () -> String?
    let onAddPageReference: (String) -> Void
    let onAddBlockReference: (String) -> Void
    let onInsertMarkdownLink: (String, String, String) -> Bool
    let onInsertMarkdownLinkAtSelection: (String, String, String, EditorTextSelection) -> EditorTextSelection?
    let onRemoveMarkdownLinkAtSelection: (String, EditorTextSelection) -> EditorTextSelection?
    let onApplyMarkdownInlineFormat: (String, MarkdownInlineFormat, EditorTextSelection) -> EditorTextSelection?
    let onUndoTextEdit: () -> Void
    let onFocusCanvas: () -> String?
    let onMoveBlock: (String, Int) -> Void
    let onMoveBlocks: ([String], Int) -> Void
    let onMoveBlockByKeyboard: (String, BlockKeyboardMoveDirection) -> Bool
    let onInsertBlockAfter: (String) -> Bool
    let onSplitTextBlockAtSelection: (String, EditorTextSelection) -> EditorTextSelection?
    let onMergeTextBlockWithPrevious: (String, EditorTextSelection) -> EditorTextSelection?
    let onMergeTextBlockWithNext: (String, EditorTextSelection) -> EditorTextSelection?
    let onIndentBlock: (String) -> Bool
    let onOutdentBlock: (String) -> Bool
    let onDeleteBlock: (String) -> Void
    let onDeleteBlocks: ([String]) -> Bool
    let onSelectBacklink: (Backlink) -> Void
    let onSelectOutlineItem: (PageOutlineItem) -> Void
    let onOpenPageReference: (String) -> Void
    let onOpenParentPage: () -> Bool
    let onOpenBlockReference: (String, String) -> Void
    let onAcceptConflict: (ConflictSnapshot) -> Void
    let onAcceptAllConflicts: () -> Void
    let onAcceptLocalConflict: (ConflictSnapshot) -> Void
    let onAcceptAllLocalConflicts: () -> Void
    let onResolveConflictManually: (ConflictSnapshot, String) -> Void
    let onResolveAllConflictsManually: ([String: String]) -> Void
    let onPageTitleChange: (String) -> Void
    let onImportMarkdown: (URL) -> Void
    let onExportMarkdown: () -> String
    let onExportMarkdownPackage: (URL) -> Void
    let onBlockTextChange: (String, String) -> Void
    let onTableRowsChange: (String, [[String]]) -> Void
    let onBlockTypeChange: (String, BlockType) -> Void
    let onConvertBlockToPage: (String) -> Void
    let onTaskItemCompletionChange: (String, Bool) -> Void
    let onCodeBlockLineWrappingChange: (String, Bool) -> Void
    let onToggleBlockExpansion: (String) -> Void
    let isToggleBlockExpanded: (String) -> Bool
    let onImportAttachment: (URL) -> Void
    let onImportAttachmentsAfterBlock: ([URL], String) -> Bool
    let onRetryAttachmentPreview: (String) -> Void
    let onPendingBlockFocusHandled: () -> Void
    @State private var isAttachmentImporterPresented = false
    @State private var isMarkdownImporterPresented = false
    @State private var isMarkdownExporterPresented = false
    @State private var isInlineLinkPopoverPresented = false
    @State private var activeInlineLinkTarget: (blockID: String, selection: EditorTextSelection?)?
    @State private var inlineLinkLabel = ""
    @State private var inlineLinkURL = ""
    @State private var isEditingInlineLink = false
    @State private var markdownExportDocument = MarkdownFileDocument(text: "")
#if DEBUG
    @State private var uiTestMarkdownExportOutput: String?
#endif
    @StateObject private var editorSession = EditorSession()
    @State private var pendingFocusRequest: BlockFocusRequest?
    @State private var activeBlockDropTarget: BlockDropTarget?
    @State private var scrollMetricsTracker = EditorCanvasScrollMetricsTracker(pageID: nil, blockCount: 0)

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CGFloat(EditorBlockChrome.blockSpacing)) {
                HStack(alignment: .center, spacing: 12) {
                    TextField("未命名", text: pageTitleBinding)
                        .textFieldStyle(.plain)
                        .font(.largeTitle.weight(.semibold))
                        .padding(.leading, CGFloat(EditorBlockChrome.actionColumnWidth + EditorBlockChrome.actionColumnSpacing + 4))
                        .disabled(page == nil)
                        .accessibilityIdentifier("editor.page-title")

                    Spacer(minLength: 12)

                    Button {
                        if let blockID = onAddParagraphBlock() {
                            pendingFocusRequest = BlockFocusRequest(blockID: blockID)
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("新增块")
                    .accessibilityIdentifier("editor.add-block")
                    .disabled(page == nil)

                    Button {
                        handleAttachmentImportButton()
                    } label: {
                        Image(systemName: "paperclip")
                    }
                    .buttonStyle(.borderless)
                    .help("插入附件")
                    .accessibilityIdentifier("editor.insert-attachment")
                    .disabled(page == nil)

                    pageActionsMenu
                }

                if !pageTagNames.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(pageTagNames, id: \.self) { tagName in
                            Text(tagName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color(red: 0.45, green: 0.28, blue: 0.70))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(red: 0.45, green: 0.28, blue: 0.70).opacity(0.10))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.leading, CGFloat(EditorBlockChrome.actionColumnWidth + EditorBlockChrome.actionColumnSpacing + 4))
                    .accessibilityLabel("页面标签")
                    .accessibilityValue(pageTagNames.joined(separator: ", "))
                }

                if isInlineLinkPopoverPresented {
                    inlineLinkPopover
                }

                if let markdownImportStatusText {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)

                        Text(markdownImportStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.orange.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.orange.opacity(0.18), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityIdentifier("editor.markdown-import-status")
                }

#if DEBUG
                if let uiTestMarkdownExportOutput {
                    Text(uiTestMarkdownExportOutput)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("editor.markdown-export-test-output")
                        .accessibilityLabel(uiTestMarkdownExportOutput)
                        .accessibilityValue(uiTestMarkdownExportOutput)
                }
#endif

                ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                    let dragPayloadBlockIDs = BlockDragPayloadResolver.payloadBlockIDs(
                        rootBlockID: block.id,
                        blocks: blocks
                    )

                    if index == 0 {
                        BlockDropSlot(
                            destinationBlockID: block.id,
                            slotKind: .before,
                            activeDropTarget: $activeBlockDropTarget,
                            moveDroppedBlocks: moveDroppedBlocks
                        )
                    }

                    BlockRowView(
                        block: block,
                        attachment: attachment(for: block),
                        attachmentPreviewGenerationStatus: attachmentPreviewGenerationStatus(for: block),
                        pageReferencePreviewText: PageReferencePreviewResolver.previewText(
                            targetPageID: block.pageReferenceTargetPageID,
                            blocks: allBlocks
                        ),
                        editorSession: editorSession,
                        nestingLevel: nestingLevel(for: block),
                        listOrdinal: ListBlockOrdinalResolver.ordinal(for: block, at: index, in: blocks),
                        dragPayloadBlockIDs: dragPayloadBlockIDs,
                        canMoveUp: index > 0,
                        canMoveDown: index < blocks.count - 1,
                        onMoveUp: {
                            onMoveBlock(block.id, index - 1)
                        },
                        onMoveDown: {
                            onMoveBlock(block.id, index + 1)
                        },
                        onMoveByKeyboard: { direction in
                            onMoveBlockByKeyboard(block.id, direction)
                        },
                        onMoveFocusByKeyboard: { direction in
                            focusAdjacentBlock(from: block.id, direction: direction)
                        },
                        onApplyInlineFormatByKeyboard: { format, selection in
                            applyMarkdownInlineFormat(format, selection: selection)
                        },
                        onInsertLinkByKeyboard: { selection in
                            presentInlineLinkInsertion(selection: selection)
                        },
                        onInsertBlockAfter: { selection in
                            guard let nextSelection = onSplitTextBlockAtSelection(block.id, selection) else {
                                return false
                            }
                            pendingFocusRequest = BlockFocusRequest(
                                blockID: nextSelection.blockID,
                                selection: nextSelection
                            )
                            return true
                        },
                        onMergeBlockWithPrevious: { selection in
                            guard let nextSelection = onMergeTextBlockWithPrevious(block.id, selection) else {
                                return false
                            }
                            pendingFocusRequest = BlockFocusRequest(
                                blockID: nextSelection.blockID,
                                selection: nextSelection
                            )
                            return true
                        },
                        onMergeBlockWithNext: { selection in
                            guard let nextSelection = onMergeTextBlockWithNext(block.id, selection) else {
                                return false
                            }
                            pendingFocusRequest = BlockFocusRequest(
                                blockID: nextSelection.blockID,
                                selection: nextSelection
                            )
                            return true
                        },
                        onIndent: {
                            onIndentBlock(block.id)
                        },
                        onOutdent: {
                            onOutdentBlock(block.id)
                        },
                        onPasteAttachmentURLs: { urls in
                            guard !urls.isEmpty else {
                                return false
                            }
                            return onImportAttachmentsAfterBlock(urls, block.id)
                        },
                        onDelete: {
                            onDeleteBlock(block.id)
                        },
                        onOpenPageReference: { targetPageID in
                            onOpenPageReference(targetPageID)
                        },
                        onOpenBlockReference: { targetPageID, targetBlockID in
                            onOpenBlockReference(targetPageID, targetBlockID)
                        },
                        onChangeType: { type in
                            onBlockTypeChange(block.id, type)
                        },
                        onConvertToPage: {
                            onConvertBlockToPage(block.id)
                        },
                        onTaskItemCompletionChange: { isCompleted in
                            onTaskItemCompletionChange(block.id, isCompleted)
                        },
                        onCodeBlockLineWrappingChange: { isWrapped in
                            onCodeBlockLineWrappingChange(block.id, isWrapped)
                        },
                        onToggleBlockExpansion: {
                            onToggleBlockExpansion(block.id)
                        },
                        onRetryAttachmentPreview: { attachmentID in
                            onRetryAttachmentPreview(attachmentID)
                        },
                        isToggleBlockExpanded: isToggleBlockExpanded(block.id),
                        isMobileSelectionModeActive: !editorSession.selectedBlockIDs.isEmpty,
                        isBlockSelected: editorSession.selectedBlockIDs.contains(block.id),
                        dropPlacement: activeBlockDropTarget?.blockID == block.id ? activeBlockDropTarget?.placement : nil,
                        focusRequestID: pendingFocusRequest?.blockID == block.id ? pendingFocusRequest?.id : nil,
                        focusSelection: pendingFocusRequest?.blockID == block.id ? pendingFocusRequest?.selection : nil,
                        onFocusRequestHandled: {
                            if pendingFocusRequest?.blockID == block.id {
                                pendingFocusRequest = nil
                            }
                            if pendingFocusBlockID == block.id {
                                onPendingBlockFocusHandled()
                            }
                        },
                        onSelectCurrentBlock: {
                            editorSession.selectBlocks([block.id])
                        },
                        onToggleBlockSelection: {
                            editorSession.selectBlocks(
                                MobileBlockSelectionReducer.selectionAfterSelecting(
                                    blockID: block.id,
                                    current: editorSession.selectedBlockIDs
                                )
                            )
                        },
                        onSelectAllBlocksByKeyboard: {
                            let blockIDs = Set(blocks.map(\.id))
                            guard !blockIDs.isEmpty else {
                                return false
                            }
                            editorSession.selectBlocks(blockIDs)
                            return true
                        },
                        onClearDropTarget: {
                            activeBlockDropTarget = BlockDropTargetLifecycleReducer
                                .targetAfterEditorInteraction(current: activeBlockDropTarget)
                        },
                        onTableRowsChange: { rows in
                            onTableRowsChange(block.id, rows)
                        }
                    ) { text in
                        onBlockTextChange(block.id, text)
                    }
                    .onAppear {
                        scheduleVisibleBlockAppeared(block.id, index: index)
                    }
                    .onDisappear {
                        scheduleVisibleBlockDisappeared(block.id)
                    }

                    BlockDropSlot(
                        destinationBlockID: block.id,
                        slotKind: .after,
                        activeDropTarget: $activeBlockDropTarget,
                        moveDroppedBlocks: moveDroppedBlocks
                    )
                }

                if !blocks.isEmpty {
                    CanvasTrailingInsertRegion {
                        focusCanvas()
                    }
                }

                if !outlineItems.isEmpty {
                    OutlinePanel(outlineItems: outlineItems, onSelectOutlineItem: onSelectOutlineItem)
                }

                if !backlinks.isEmpty {
                    BacklinksPanel(backlinks: backlinks, onSelectBacklink: onSelectBacklink)
                }

                if !externalLinks.isEmpty {
                    ExternalLinksPanel(externalLinks: externalLinks)
                }

                if !conflicts.isEmpty {
                    ConflictPanel(
                        conflicts: conflicts,
                        onAcceptConflict: onAcceptConflict,
                        onAcceptAllConflicts: onAcceptAllConflicts,
                        onAcceptLocalConflict: onAcceptLocalConflict,
                        onAcceptAllLocalConflicts: onAcceptAllLocalConflicts,
                        onResolveManually: onResolveConflictManually,
                        onResolveAllManually: onResolveAllConflictsManually
                    )
                }

                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusCanvas()
                    }
                    .dropDestination(for: String.self) { draggedBlockIDs, _ in
                        activeBlockDropTarget = nil
                        return moveDroppedBlocksToEnd(draggedBlockIDs)
                    }
                    .accessibilityIdentifier("editor.canvas-edit-region")
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.vertical, 36)
        }
        .accessibilityIdentifier("editor.canvas-scroll")
        .onChange(of: editorSession.focusedBlockID) { _, _ in
            activeBlockDropTarget = BlockDropTargetLifecycleReducer
                .targetAfterEditorInteraction(current: activeBlockDropTarget)
        }
#if DEBUG
        .overlay(alignment: .topLeading) {
            scrollMetricsDebugProbe
        }
#endif
        .background(Color.white)
#if os(iOS)
        .safeAreaInset(edge: .bottom) {
            if !editorSession.selectedBlockIDs.isEmpty {
                MobileBlockSelectionToolbar(
                    selectedCount: editorSession.selectedBlockIDs.count,
                    onClear: {
                        editorSession.clearBlockSelection()
                    },
                    onDelete: {
                        let blockIDs = Array(editorSession.selectedBlockIDs)
                        if onDeleteBlocks(blockIDs) {
                            editorSession.clearBlockSelection()
                        }
                    }
                )
            }
        }
#endif
#if os(macOS)
        .background(
            DropTargetCleanupEventBridge(isEnabled: activeBlockDropTarget != nil) {
                activeBlockDropTarget = nil
            }
            .frame(width: 0, height: 0)
        )
        .onPasteCommand(of: [.fileURL, .png, .jpeg, .tiff]) { _ in
            let attachmentURLs = MacPasteboardAttachmentResolver.attachmentURLs(from: .general)
            _ = importPastedAttachments(attachmentURLs)
        }
#endif
#if os(macOS)
        .background(
            MacEditorKeyboardShortcutBridge(
                onInsertLink: {
                    presentInlineLinkInsertionFromKeyboardShortcut()
                },
                onPasteAttachments: {
                    let attachmentURLs = MacPasteboardAttachmentResolver.attachmentURLs(from: .general)
                    return importPastedAttachments(attachmentURLs)
                },
                hasBlockSelection: {
                    !editorSession.selectedBlockIDs.isEmpty
                },
                onCancelSelection: {
                    let hadBlockSelection = !editorSession.selectedBlockIDs.isEmpty
                    editorSession.clearBlockSelection()
                    return hadBlockSelection
                }
            )
        )
#elseif os(iOS)
        .background(
            IOSEditorKeyboardShortcutBridge(
                isEnabled: !editorSession.selectedBlockIDs.isEmpty,
                onPasteAttachments: {
                    let attachmentURLs = IOSPasteboardAttachmentResolver.attachmentURLs(from: .general)
                    return importPastedAttachments(attachmentURLs)
                },
                onMoveFocus: { direction in
                    guard let blockID = BlockSelectionKeyboardAnchorResolver.anchorBlockID(
                        selectedBlockIDs: editorSession.selectedBlockIDs,
                        visibleBlockIDs: blocks.map(\.id)
                    ) else {
                        return false
                    }

                    return focusAdjacentBlock(
                        from: blockID,
                        direction: direction,
                        clearsBlockSelection: true
                    )
                }
            )
            .frame(width: 0, height: 0)
        )
#endif
        .navigationTitle(page?.title ?? "编辑器")
        .focusedValue(\.insertMarkdownLinkAction, insertMarkdownLinkAction)
        .focusedValue(\.promoteDiarySelectionAction, promoteCurrentBlockToPageAction)
        .focusedValue(\.openParentPageAction, openParentPageAction)
        .onAppear {
            scheduleScrollMetricsReset()
            schedulePendingFocusIfNeeded(pendingFocusBlockID)
            logRenderMetrics(reason: "appear")
        }
        .onChange(of: pendingFocusBlockID) { _, blockID in
            schedulePendingFocusIfNeeded(blockID)
        }
        .onChange(of: renderMetrics) { _, _ in
            scheduleScrollMetricsReset()
            logRenderMetrics(reason: "change")
        }
        .fileImporter(
            isPresented: $isMarkdownImporterPresented,
            allowedContentTypes: MarkdownFileDocument.readableContentTypes,
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let sourceURL = urls.first {
                let isScoped = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if isScoped {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }
                onImportMarkdown(sourceURL)
            }
        }
        .fileExporter(
            isPresented: $isMarkdownExporterPresented,
            document: markdownExportDocument,
            contentType: MarkdownFileDocument.markdownContentType,
            defaultFilename: "\(page?.title ?? "页面").md"
        ) { result in
            switch result {
            case .success(let destinationURL):
                onExportMarkdownPackage(destinationURL)
            case .failure(let error):
                EditorLog.markdown.error(
                    "markdown_file_export_failed error=\(String(describing: error), privacy: .public)"
                )
            }
        }
        .fileImporter(
            isPresented: $isAttachmentImporterPresented,
            allowedContentTypes: [.image, .movie, .data, .item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let sourceURL = urls.first {
                let isScoped = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if isScoped {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }
                onImportAttachment(sourceURL)
            }
        }
    }

    private var pageTitleBinding: Binding<String> {
        Binding {
            page?.title ?? ""
        } set: { title in
            onPageTitleChange(title)
        }
    }

    private var pageReferenceTargets: [PageSummary] {
        pages.filter { targetPage in
            targetPage.id != page?.id
        }
    }

    private var pageActionsMenu: some View {
        Menu {
            Section("块") {
                Button {
                    if let blockID = onAddParagraphBlock() {
                        pendingFocusRequest = BlockFocusRequest(blockID: blockID)
                    }
                } label: {
                    Label("新增文本块", systemImage: "plus")
                }

                Menu {
                    ForEach(pageReferenceTargets) { targetPage in
                        Button {
                            onAddPageReference(targetPage.id)
                        } label: {
                            Label(targetPage.title, systemImage: "doc.text")
                        }
                    }
                } label: {
                    Label("页面引用", systemImage: "doc.badge.plus")
                }
                .disabled(pageReferenceTargets.isEmpty)

                Menu {
                    ForEach(blockReferenceTargets) { targetBlock in
                        Button {
                            onAddBlockReference(targetBlock.id)
                        } label: {
                            Label(blockReferenceTitle(for: targetBlock), systemImage: "text.quote")
                        }
                    }
                } label: {
                    Label("块引用", systemImage: "text.badge.plus")
                }
                .disabled(blockReferenceTargets.isEmpty)

                Button {
                    handleAttachmentImportButton()
                } label: {
                    Label("附件", systemImage: "paperclip")
                }
                .disabled(page == nil)
            }

            Section("文本") {
                Button {
                    _ = presentInlineLinkInsertionFromCurrentTarget()
                } label: {
                    Label("链接", systemImage: "link")
                }
                .disabled(inlineLinkToolbarTargetBlockID == nil)

                Button {
                    applyMarkdownInlineFormat(.bold)
                } label: {
                    Label("加粗", systemImage: "bold")
                }
                .disabled(inlineFormatTarget == nil)

                Button {
                    applyMarkdownInlineFormat(.italic)
                } label: {
                    Label("斜体", systemImage: "italic")
                }
                .disabled(inlineFormatTarget == nil)

                Button {
                    applyMarkdownInlineFormat(.strikethrough)
                } label: {
                    Label("删除线", systemImage: "strikethrough")
                }
                .disabled(inlineFormatTarget == nil)

                Button {
                    applyMarkdownInlineFormat(.code)
                } label: {
                    Label("代码", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .disabled(inlineFormatTarget == nil)
            }

            Section("页面") {
                Button {
                    onUndoTextEdit()
                } label: {
                    Label("撤销编辑", systemImage: "arrow.uturn.backward")
                }
                .disabled(!canUndoTextEdit)

                Button {
                    handleMarkdownImportButton()
                } label: {
                    Label("导入 Markdown", systemImage: "square.and.arrow.down")
                }
                .disabled(page == nil)

                Button {
                    handleMarkdownExportButton()
                } label: {
                    Label("导出 Markdown", systemImage: "square.and.arrow.up")
                }
                .disabled(page == nil)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .help("更多")
        .accessibilityIdentifier("editor.page-actions")
    }

    private var blockReferenceTargets: [BlockSnapshot] {
        allBlocks.filter { block in
            block.type.isTextEditable && !block.textPlain.isEmpty
        }
    }

    private var inlineFormatTarget: (blockID: String, selection: EditorTextSelection)? {
        if let selection = editorSession.textSelection,
           let block = blocks.first(where: { $0.id == selection.blockID && $0.type.isTextEditable }),
           isValid(selection: selection, for: block) {
            return (block.id, selection)
        }

        if let focusedBlockID = editorSession.focusedBlockID,
           let block = blocks.first(where: { $0.id == focusedBlockID && $0.type.isTextEditable }) {
            return (block.id, endSelection(for: block))
        }

        if let block = blocks.last(where: { $0.type.isTextEditable }) {
            return (block.id, endSelection(for: block))
        }

        return nil
    }

    private var inlineLinkTarget: (blockID: String, selection: EditorTextSelection?)? {
        if let selection = editorSession.textSelection,
           let block = blocks.first(where: { $0.id == selection.blockID && $0.type.isTextEditable }),
           isValid(selection: selection, for: block) {
            return (block.id, selection)
        }

        if let focusedBlockID = editorSession.focusedBlockID,
           blocks.contains(where: { $0.id == focusedBlockID && $0.type.isTextEditable }) {
            return (focusedBlockID, nil)
        }

        if let block = blocks.last(where: { $0.type.isTextEditable }) {
            return (block.id, nil)
        }

        return nil
    }

    private var inlineLinkTargetBlockID: String? {
        inlineLinkTarget?.blockID
    }

    private var inlineLinkKeyboardTarget: (blockID: String, selection: EditorTextSelection?)? {
        guard let selection = editorSession.textSelection,
              let block = blocks.first(where: { $0.id == selection.blockID && $0.type.isTextEditable }),
              isValid(selection: selection, for: block) else {
            return nil
        }

        return (block.id, selection)
    }

    private var inlineLinkToolbarTargetBlockID: String? {
        inlineLinkTargetBlockID ?? activeInlineLinkTarget?.blockID
    }

    private var insertMarkdownLinkAction: (() -> Void)? {
        guard inlineLinkToolbarTargetBlockID != nil else {
            return nil
        }

        return {
            _ = presentInlineLinkInsertionFromCurrentTarget()
        }
    }

    private var promoteCurrentBlockToPageAction: (() -> Void)? {
        guard let blockID = BlockPromotionCommandResolver.promotableBlockID(
            selection: editorSession.textSelection,
            focusedBlockID: editorSession.focusedBlockID,
            blocks: blocks
        ) else {
            return nil
        }

        return {
            onConvertBlockToPage(blockID)
        }
    }

    private var openParentPageAction: (() -> Void)? {
        guard parentPageLink != nil else {
            return nil
        }

        return {
            _ = onOpenParentPage()
        }
    }

    private func handleMarkdownImportButton() {
#if DEBUG
        if let sourceURL = makeUITestMarkdownImportSourceURL() {
            onImportMarkdown(sourceURL)
            return
        }
#endif
        isMarkdownImporterPresented = true
    }

    private func handleMarkdownExportButton() {
        let markdown = onExportMarkdown()
#if DEBUG
        if ProcessInfo.processInfo.environment["EDITOR_UI_TEST_MARKDOWN_EXPORT_CAPTURE"] == "1" {
            uiTestMarkdownExportOutput = markdown
            return
        }
#endif
        markdownExportDocument = MarkdownFileDocument(text: markdown)
        isMarkdownExporterPresented = true
    }

    private func handleAttachmentImportButton() {
#if DEBUG
        if let sourceURL = makeUITestAttachmentImportSourceURL() {
            onImportAttachment(sourceURL)
            return
        }
#endif
        isAttachmentImporterPresented = true
    }

#if DEBUG
    private func makeUITestMarkdownImportSourceURL() -> URL? {
        guard let markdown = ProcessInfo.processInfo.environment["EDITOR_UI_TEST_MARKDOWN_IMPORT_TEXT"] else {
            return nil
        }

        do {
            let fixtureDirectory = try makeUITestFixtureDirectory()
            let sourceURL = fixtureDirectory.appendingPathComponent("toolbar-import.md")
            try markdown.write(to: sourceURL, atomically: true, encoding: .utf8)
            return sourceURL
        } catch {
            EditorLog.markdown.error(
                "markdown_ui_test_fixture_failed error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    private func makeUITestAttachmentImportSourceURL() -> URL? {
        guard let filename = ProcessInfo.processInfo.environment["EDITOR_UI_TEST_ATTACHMENT_IMPORT_FILENAME"],
              !filename.isEmpty else {
            return nil
        }

        do {
            let fixtureDirectory = try makeUITestFixtureDirectory()
            let safeFilename = URL(fileURLWithPath: filename).lastPathComponent
            let sourceURL = fixtureDirectory.appendingPathComponent(safeFilename)
            let contents = ProcessInfo.processInfo.environment["EDITOR_UI_TEST_ATTACHMENT_IMPORT_CONTENTS"]
                ?? "Attachment fixture from macOS toolbar UI automation"
            try contents.write(to: sourceURL, atomically: true, encoding: .utf8)
            return sourceURL
        } catch {
            EditorLog.attachment.error(
                "attachment_ui_test_fixture_failed error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    private func makeUITestFixtureDirectory() throws -> URL {
        let fixtureDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorUITestFixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
        return fixtureDirectory
    }
#endif

    private var inlineLinkPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("文本", text: $inlineLinkLabel)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .accessibilityIdentifier("editor.insert-markdown-link.label")

            TextField("URL", text: $inlineLinkURL)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .accessibilityIdentifier("editor.insert-markdown-link.url")

            HStack {
                Button {
                    cancelInlineLinkInsertion()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("取消")
                .accessibilityIdentifier("editor.insert-markdown-link.cancel")

                if isEditingInlineLink {
                    Button(role: .destructive) {
                        removeInlineLink()
                    } label: {
                        Label("移除链接", systemImage: "link.badge.minus")
                    }
                    .buttonStyle(.borderless)
                    .help("移除链接")
                    .accessibilityIdentifier("editor.insert-markdown-link.remove")
                }

                Spacer()
                Button {
                    insertInlineLink()
                } label: {
                    Label(isEditingInlineLink ? "更新链接" : "插入链接", systemImage: "link")
                }
                .disabled(MarkdownInlineLinkComposer.markdown(label: inlineLinkLabel, url: inlineLinkURL) == nil)
                .accessibilityIdentifier("editor.insert-markdown-link.confirm")
            }
        }
        .padding(12)
    }

    private func blockReferenceTitle(for block: BlockSnapshot) -> String {
        let pageTitle = pages.first { $0.id == block.pageID }?.title ?? "页面"
        return "\(pageTitle): \(block.textPlain)"
    }

    private func insertInlineLink() {
        guard let target = activeInlineLinkTarget ?? inlineLinkTarget else {
            return
        }

        if let selection = target.selection {
            guard let nextSelection = onInsertMarkdownLinkAtSelection(
                target.blockID,
                inlineLinkLabel,
                inlineLinkURL,
                selection
            ) else {
                return
            }
            pendingFocusRequest = BlockFocusRequest(blockID: target.blockID, selection: nextSelection)
        } else {
            guard onInsertMarkdownLink(target.blockID, inlineLinkLabel, inlineLinkURL) else {
                return
            }
            pendingFocusRequest = BlockFocusRequest(blockID: target.blockID)
        }

        inlineLinkLabel = ""
        inlineLinkURL = ""
        isEditingInlineLink = false
        isInlineLinkPopoverPresented = false
        activeInlineLinkTarget = nil
    }

    private func removeInlineLink() {
        guard let target = activeInlineLinkTarget,
              let selection = target.selection,
              let nextSelection = onRemoveMarkdownLinkAtSelection(target.blockID, selection) else {
            return
        }

        pendingFocusRequest = BlockFocusRequest(blockID: target.blockID, selection: nextSelection)
        inlineLinkLabel = ""
        inlineLinkURL = ""
        isEditingInlineLink = false
        isInlineLinkPopoverPresented = false
        activeInlineLinkTarget = nil
    }

    private func cancelInlineLinkInsertion() {
        inlineLinkLabel = ""
        inlineLinkURL = ""
        isEditingInlineLink = false
        isInlineLinkPopoverPresented = false
        activeInlineLinkTarget = nil
    }

    private func applyMarkdownInlineFormat(_ format: MarkdownInlineFormat) {
        guard let target = inlineFormatTarget,
              let nextSelection = onApplyMarkdownInlineFormat(target.blockID, format, target.selection) else {
            return
        }

        pendingFocusRequest = BlockFocusRequest(blockID: target.blockID, selection: nextSelection)
    }

    private func applyMarkdownInlineFormat(
        _ format: MarkdownInlineFormat,
        selection: EditorTextSelection
    ) -> Bool {
        guard let nextSelection = onApplyMarkdownInlineFormat(selection.blockID, format, selection) else {
            return false
        }

        pendingFocusRequest = BlockFocusRequest(blockID: selection.blockID, selection: nextSelection)
        EditorLog.focus.debug(
            "editor_focus_request_scheduled block_id=\(selection.blockID, privacy: .public) source=keyboard_inline_format"
        )
        return true
    }

    private func presentInlineLinkInsertion(selection: EditorTextSelection) -> Bool {
        guard let block = blocks.first(where: { $0.id == selection.blockID && $0.type.isTextEditable }),
              isValid(selection: selection, for: block) else {
            return false
        }

        activeInlineLinkTarget = preparedInlineLinkTarget(for: (selection.blockID, selection))
        isInlineLinkPopoverPresented = true
        EditorLog.focus.debug(
            "editor_inline_link_panel_presented block_id=\(selection.blockID, privacy: .public) source=keyboard_link"
        )
        return true
    }

    private func presentInlineLinkInsertionFromCurrentTarget() -> Bool {
        guard let target = inlineLinkTarget else {
            return false
        }

        activeInlineLinkTarget = preparedInlineLinkTarget(for: target)
        isInlineLinkPopoverPresented = true
        return true
    }

#if os(macOS)
    private func presentInlineLinkInsertionFromKeyboardShortcut() -> Bool {
        guard let target = inlineLinkKeyboardTarget else {
            return false
        }

        activeInlineLinkTarget = preparedInlineLinkTarget(for: target)
        isInlineLinkPopoverPresented = true
        return true
    }
#endif

    private func preparedInlineLinkTarget(
        for target: (blockID: String, selection: EditorTextSelection?)
    ) -> (blockID: String, selection: EditorTextSelection?) {
        inlineLinkLabel = ""
        inlineLinkURL = ""
        isEditingInlineLink = false

        guard let selection = target.selection,
              let block = blocks.first(where: { $0.id == selection.blockID && $0.type.isTextEditable }),
              let editTarget = MarkdownInlineLinkEditTarget.target(in: block.textPlain, selection: selection) else {
            return target
        }

        inlineLinkLabel = editTarget.label
        inlineLinkURL = editTarget.url
        isEditingInlineLink = true
        return (blockID: target.blockID, selection: editTarget.replacementSelection)
    }

    private func isValid(selection: EditorTextSelection, for block: BlockSnapshot) -> Bool {
        let textLength = (block.textPlain as NSString).length
        return selection.location >= 0 &&
            selection.length >= 0 &&
            selection.location <= textLength &&
            selection.length <= textLength - selection.location
    }

    private func endSelection(for block: BlockSnapshot) -> EditorTextSelection {
        EditorTextSelection(
            blockID: block.id,
            location: (block.textPlain as NSString).length,
            length: 0
        )
    }

    private func schedulePendingFocusIfNeeded(_ blockID: String?) {
        guard let blockID else {
            return
        }

        guard pendingFocusRequest?.blockID != blockID else {
            return
        }

        pendingFocusRequest = BlockFocusRequest(blockID: blockID)
        EditorLog.focus.debug(
            "editor_focus_request_scheduled block_id=\(blockID, privacy: .public) source=view_model"
        )
    }

    private func focusCanvas() {
        guard let blockID = onFocusCanvas() else {
            return
        }

        pendingFocusRequest = BlockFocusRequest(blockID: blockID)
    }

    private func importPastedAttachments(_ attachmentURLs: [URL]) -> Bool {
        guard !attachmentURLs.isEmpty else {
            return false
        }

        if let anchorBlockID = PastedAttachmentAnchorResolver.anchorBlockID(
            textSelection: editorSession.textSelection,
            focusedBlockID: editorSession.focusedBlockID,
            selectedBlockIDs: editorSession.selectedBlockIDs,
            visibleBlockIDs: blocks.map(\.id)
        ) {
            return onImportAttachmentsAfterBlock(attachmentURLs, anchorBlockID)
        }

        attachmentURLs.forEach(onImportAttachment)
        return true
    }

    private func focusAdjacentBlock(
        from blockID: String,
        direction: BlockKeyboardFocusDirection,
        clearsBlockSelection: Bool = false
    ) -> Bool {
        guard let target = BlockKeyboardFocusResolver.target(
            currentBlockID: blockID,
            direction: direction,
            blocks: blocks
        ) else {
            return false
        }

        if clearsBlockSelection {
            editorSession.clearBlockSelection()
        }

        pendingFocusRequest = BlockFocusRequest(
            blockID: target.blockID,
            selection: target.selection
        )
        EditorLog.focus.debug(
            "editor_focus_request_scheduled block_id=\(target.blockID, privacy: .public) source=keyboard_navigation direction=\(direction.debugName, privacy: .public)"
        )
        return true
    }

    private func moveDroppedBlocks(
        _ draggedBlockIDs: [String],
        destinationBlockID: String,
        placement: BlockDropPlacement
    ) -> Bool {
        let movedBlockIDs = visibleDraggedBlockIDs(from: draggedBlockIDs)
        guard let draggedBlockID = movedBlockIDs.first,
              let targetIndex = BlockDragReorderResolver.targetIndex(
                draggedBlockIDs: movedBlockIDs,
                destinationBlockID: destinationBlockID,
                visibleBlockIDs: blocks.map(\.id),
                placement: placement
              ) else {
            return false
        }

        onMoveBlocks(movedBlockIDs, targetIndex)
        if placement == .childAfter {
            _ = onIndentBlock(draggedBlockID)
        }
        pendingFocusRequest = BlockFocusRequest(blockID: draggedBlockID)
        return true
    }

    private func moveDroppedBlocksToEnd(_ draggedBlockIDs: [String]) -> Bool {
        let movedBlockIDs = visibleDraggedBlockIDs(from: draggedBlockIDs)
        guard let draggedBlockID = movedBlockIDs.first,
              let targetIndex = BlockDragReorderResolver.endTargetIndex(
                draggedBlockIDs: movedBlockIDs,
                visibleBlockIDs: blocks.map(\.id)
              ) else {
            return false
        }

        onMoveBlocks(movedBlockIDs, targetIndex)
        pendingFocusRequest = BlockFocusRequest(blockID: draggedBlockID)
        return true
    }

    private func visibleDraggedBlockIDs(from draggedBlockIDs: [String]) -> [String] {
        let draggedBlockIDSet = Set(draggedBlockIDs)
        return blocks.map(\.id).filter { draggedBlockIDSet.contains($0) }
    }

    private func attachment(for block: BlockSnapshot) -> AttachmentSnapshot? {
        attachments.first { $0.matches(block: block) }
    }

    private func attachmentPreviewGenerationStatus(for block: BlockSnapshot) -> AttachmentPreviewGenerationStatus {
        guard let attachment = attachment(for: block) else {
            return .idle
        }

        return attachmentPreviewGenerationStatuses[attachment.id] ?? .idle
    }

    private var renderMetrics: EditorCanvasRenderMetrics {
        EditorCanvasRenderMetrics(
            pageID: page?.id,
            blockCount: blocks.count,
            attachmentCount: attachments.count,
            backlinkCount: backlinks.count,
            conflictCount: conflicts.count
        )
    }

    private func logRenderMetrics(reason: String) {
        let metrics = renderMetrics
        EditorLog.render.debug(
            "editor_canvas_rendered reason=\(reason, privacy: .public) page_id=\(metrics.pageID ?? "none", privacy: .public) block_count=\(metrics.blockCount, privacy: .public) attachment_count=\(metrics.attachmentCount, privacy: .public) backlink_count=\(metrics.backlinkCount, privacy: .public) conflict_count=\(metrics.conflictCount, privacy: .public) large_page=\(metrics.isLargePage, privacy: .public)"
        )
    }

    private func resetScrollMetrics() {
        scrollMetricsTracker.reset(pageID: page?.id, blockCount: blocks.count)
        logScrollMetrics(reason: "reset")
    }

    private func scheduleScrollMetricsReset() {
        DispatchQueue.main.async {
            resetScrollMetrics()
        }
    }

    private func scheduleVisibleBlockAppeared(_ blockID: String, index: Int) {
        DispatchQueue.main.async {
            recordVisibleBlockAppeared(blockID, index: index)
        }
    }

    private func scheduleVisibleBlockDisappeared(_ blockID: String) {
        DispatchQueue.main.async {
            recordVisibleBlockDisappeared(blockID)
        }
    }

    private func recordVisibleBlockAppeared(_ blockID: String, index: Int) {
        guard blocks.indices.contains(index),
              blocks[index].id == blockID else {
            return
        }
        scrollMetricsTracker.blockAppeared(blockID, index: index)
        logScrollMetrics(reason: "appear")
    }

    private func recordVisibleBlockDisappeared(_ blockID: String) {
        scrollMetricsTracker.blockDisappeared(blockID)
        logScrollMetrics(reason: "disappear")
    }

    private func logScrollMetrics(reason: String) {
        let metrics = scrollMetricsTracker.metrics
        EditorLog.scroll.debug(
            "editor_canvas_scroll_visible reason=\(reason, privacy: .public) \(metrics.runtimeSummary, privacy: .public)"
        )
    }

#if DEBUG
    private var scrollMetricsDebugProbe: some View {
        let summary = scrollMetricsTracker.metrics.runtimeSummary
        return Text(summary)
            .font(.system(size: 1))
            .opacity(0.01)
            .frame(width: 1, height: 1)
            .id(summary)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("editor.scroll-metrics-test-output")
            .accessibilityLabel(summary)
            .accessibilityValue(summary)
    }
#endif

    private func nestingLevel(for block: BlockSnapshot) -> Int {
        var level = 0
        var visitedBlockIDs: Set<String> = [block.id]
        var parentBlockID = block.parentBlockID

        while let currentParentID = parentBlockID,
              !visitedBlockIDs.contains(currentParentID),
              let parentBlock = blocks.first(where: { $0.id == currentParentID }) {
            level += 1
            visitedBlockIDs.insert(currentParentID)
            parentBlockID = parentBlock.parentBlockID
        }

        return min(level, 6)
    }
}

#if os(macOS)
enum MacEditorKeyboardShortcutAction: Equatable, Sendable {
    case cancelSelection
    case insertLink
    case pasteAttachments
}

enum MacEditorKeyboardShortcutActionResolver {
    static func action(
        keyCode: UInt16,
        input: String?,
        modifiers: Set<BlockKeyboardShortcutModifier>,
        hasBlockSelection: Bool,
        hasPasteableAttachments: Bool
    ) -> MacEditorKeyboardShortcutAction? {
        if hasBlockSelection,
           BlockSelectionCancelKeyboardResolver.requestsCancel(
            keyCode: keyCode,
            input: input,
            modifiers: modifiers
           ) {
            return .cancelSelection
        }

        if MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(
            input: input,
            modifiers: modifiers
        ) {
            return .insertLink
        }

        if hasPasteableAttachments,
           MacPasteKeyboardShortcutResolver.requestsAttachmentPaste(
            keyCode: keyCode,
            input: input,
            modifiers: modifiers
           ) {
            return .pasteAttachments
        }

        return nil
    }
}

private struct MacEditorKeyboardShortcutBridge: NSViewRepresentable {
    let onInsertLink: () -> Bool
    let onPasteAttachments: () -> Bool
    let hasBlockSelection: () -> Bool
    let onCancelSelection: () -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.onInsertLink = onInsertLink
        context.coordinator.onPasteAttachments = onPasteAttachments
        context.coordinator.hasBlockSelection = hasBlockSelection
        context.coordinator.onCancelSelection = onCancelSelection
        context.coordinator.install()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onInsertLink = onInsertLink
        context.coordinator.onPasteAttachments = onPasteAttachments
        context.coordinator.hasBlockSelection = hasBlockSelection
        context.coordinator.onCancelSelection = onCancelSelection
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        var onInsertLink: (() -> Bool)?
        var onPasteAttachments: (() -> Bool)?
        var hasBlockSelection: (() -> Bool)?
        var onCancelSelection: (() -> Bool)?
        private var eventMonitor: Any?

        func install() {
            guard eventMonitor == nil else {
                return
            }

            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else {
                    return event
                }

                let action = MacEditorKeyboardShortcutActionResolver.action(
                    keyCode: event.keyCode,
                    input: event.charactersIgnoringModifiers,
                    modifiers: event.blockKeyboardShortcutModifiers,
                    hasBlockSelection: self.hasBlockSelection?() == true,
                    hasPasteableAttachments: true
                )

                switch action {
                case .cancelSelection:
                    if self.onCancelSelection?() == true {
                        return nil
                    }
                case .insertLink:
                    if self.onInsertLink?() == true {
                        return nil
                    }
                case .pasteAttachments:
                    if self.onPasteAttachments?() == true {
                        return nil
                    }
                case nil:
                    break
                }

                return event
            }
        }

        func uninstall() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
                self.eventMonitor = nil
            }
        }

        deinit {
            uninstall()
        }
    }
}
#elseif os(iOS)
private struct IOSEditorKeyboardShortcutBridge: UIViewRepresentable {
    let isEnabled: Bool
    let onPasteAttachments: () -> Bool
    let onMoveFocus: (BlockKeyboardFocusDirection) -> Bool

    func makeUIView(context: Context) -> ShortcutCaptureView {
        let view = ShortcutCaptureView(frame: .zero)
        view.isEnabled = isEnabled
        view.onPasteAttachments = onPasteAttachments
        view.onMoveFocus = onMoveFocus
        return view
    }

    func updateUIView(_ uiView: ShortcutCaptureView, context: Context) {
        uiView.isEnabled = isEnabled
        uiView.onPasteAttachments = onPasteAttachments
        uiView.onMoveFocus = onMoveFocus
        uiView.updateFirstResponderIfNeeded()
    }

    final class ShortcutCaptureView: UIView {
        var isEnabled = false
        var onPasteAttachments: () -> Bool = { false }
        var onMoveFocus: (BlockKeyboardFocusDirection) -> Bool = { _ in false }
        private var isCapturingKeyboard = false

        override var canBecomeFirstResponder: Bool {
            isEnabled
        }

        override var keyCommands: [UIKeyCommand]? {
            guard isEnabled else {
                return []
            }

            return [
                UIKeyCommand(
                    input: "v",
                    modifierFlags: [.command],
                    action: #selector(pasteAttachments)
                ),
                UIKeyCommand(
                    input: IOSEditorKeyboardShortcutActionResolver.upArrowInput,
                    modifierFlags: [],
                    action: #selector(moveFocusUp)
                ),
                UIKeyCommand(
                    input: IOSEditorKeyboardShortcutActionResolver.downArrowInput,
                    modifierFlags: [],
                    action: #selector(moveFocusDown)
                )
            ]
        }

        func updateFirstResponderIfNeeded() {
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                if self.isEnabled {
                    self.becomeFirstResponder()
                    self.isCapturingKeyboard = self.isFirstResponder
                } else if self.isCapturingKeyboard {
                    self.resignFirstResponder()
                    self.isCapturingKeyboard = false
                }
            }
        }

        @objc private func pasteAttachments(_ sender: Any?) {
            performShortcut(input: "v", modifiers: [.command])
        }

        @objc private func moveFocusUp(_ sender: Any?) {
            performShortcut(
                input: IOSEditorKeyboardShortcutActionResolver.upArrowInput,
                modifiers: []
            )
        }

        @objc private func moveFocusDown(_ sender: Any?) {
            performShortcut(
                input: IOSEditorKeyboardShortcutActionResolver.downArrowInput,
                modifiers: []
            )
        }

        private func performShortcut(
            input: String?,
            modifiers: Set<BlockKeyboardShortcutModifier>
        ) {
            switch IOSEditorKeyboardShortcutActionResolver.action(
                input: input,
                modifiers: modifiers
            ) {
            case .pasteAttachments:
                _ = onPasteAttachments()
            case let .moveFocus(direction):
                _ = onMoveFocus(direction)
            case nil:
                break
            }
        }
    }
}
#endif

private struct BacklinksPanel: View {
    let backlinks: [Backlink]
    let onSelectBacklink: (Backlink) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("反向链接")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(backlinks) { backlink in
                Button {
                    onSelectBacklink(backlink)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(backlink.sourcePageTitle)
                                .font(.callout)
                            Text("[[\(backlink.linkText)]]")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 3)
                .accessibilityIdentifier("editor.backlink.\(backlink.id)")
            }
        }
        .padding(.top, 10)
    }
}

private struct ExternalLinksPanel: View {
    @Environment(\.openURL) private var openURL

    let externalLinks: [ExternalLink]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("外部链接")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(externalLinks) { externalLink in
                Button {
                    guard let destinationURL = externalLink.destinationURL else {
                        return
                    }
                    openURL(destinationURL)
                } label: {
                    externalLinkRow(externalLink)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 3)
                .disabled(externalLink.destinationURL == nil)
                .accessibilityIdentifier("editor.external-link.\(externalLink.id)")
            }
        }
        .padding(.top, 10)
        .accessibilityIdentifier("editor.external-links")
    }

    private func externalLinkRow(_ externalLink: ExternalLink) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "safari")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(externalLink.linkText)
                    .font(.callout)
                Text(externalLink.targetURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

private struct OutlinePanel: View {
    let outlineItems: [PageOutlineItem]
    let onSelectOutlineItem: (PageOutlineItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("大纲")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(outlineItems) { item in
                Button {
                    onSelectOutlineItem(item)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "list.bullet.indent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)

                        Text(item.title)
                            .font(.callout)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.leading, CGFloat(max(item.level - 1, 0)) * 12)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 3)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("大纲标题 \(item.title)")
                .accessibilityValue("\(item.level) 级")
                .accessibilityIdentifier("editor.outline.\(item.blockID)")
            }
        }
        .padding(.top, 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.outline")
    }
}

private struct ConflictPanel: View {
    let conflicts: [ConflictSnapshot]
    let onAcceptConflict: (ConflictSnapshot) -> Void
    let onAcceptAllConflicts: () -> Void
    let onAcceptLocalConflict: (ConflictSnapshot) -> Void
    let onAcceptAllLocalConflicts: () -> Void
    let onResolveManually: (ConflictSnapshot, String) -> Void
    let onResolveAllManually: ([String: String]) -> Void
    @State private var mergeDrafts = ConflictMergeDrafts()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            ForEach(conflicts) { conflict in
                ConflictResolutionRow(
                    conflict: conflict,
                    mergedText: binding(for: conflict),
                    onUseLocalDraft: { conflict in
                        mergeDrafts.useLocalText(for: conflict)
                    },
                    onUseRemoteDraft: { conflict in
                        mergeDrafts.useRemoteText(for: conflict)
                    },
                    onAcceptConflict: onAcceptConflict,
                    onAcceptLocalConflict: onAcceptLocalConflict,
                    onResolveManually: onResolveManually
                )
            }
        }
        .padding(.top, 10)
        .onChange(of: conflicts.map(\.id)) { _, conflictIDs in
            mergeDrafts.prune(keeping: conflictIDs)
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                headerTitle
                Spacer(minLength: 8)
                headerButtons
            }

            VStack(alignment: .leading, spacing: 6) {
                headerTitle
                HStack(spacing: 8) {
                    headerButtons
                }
            }
        }
    }

    private var headerTitle: some View {
        Text("同步冲突")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var headerButtons: some View {
        Button {
            mergeDrafts.useLocalText(for: conflicts)
        } label: {
            Label("全部使用本地草稿", systemImage: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .disabled(conflicts.isEmpty)
        .accessibilityIdentifier("editor.conflict.draft-all-local")

        Button {
            mergeDrafts.useRemoteText(for: conflicts)
        } label: {
            Label("全部使用远端草稿", systemImage: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .disabled(conflicts.isEmpty)
        .accessibilityIdentifier("editor.conflict.draft-all-remote")

        Button {
            onResolveAllManually(currentMergedTexts())
        } label: {
            Label("应用全部合并", systemImage: "checkmark.circle")
        }
        .buttonStyle(.borderless)
        .disabled(conflicts.isEmpty)
        .accessibilityIdentifier("editor.conflict.apply-all-merged")

        Button {
            onAcceptAllLocalConflicts()
        } label: {
            Label("全部保留本地", systemImage: "arrow.up.doc")
        }
        .buttonStyle(.borderless)
        .disabled(conflicts.isEmpty)
        .accessibilityIdentifier("editor.conflict.accept-all-local")

        Button {
            onAcceptAllConflicts()
        } label: {
            Label("全部采用远端", systemImage: "arrow.down.doc")
        }
        .buttonStyle(.borderless)
        .disabled(conflicts.isEmpty)
        .accessibilityIdentifier("editor.conflict.accept-all-remote")
    }

    private func binding(for conflict: ConflictSnapshot) -> Binding<String> {
        Binding(
            get: {
                mergeDrafts.text(for: conflict)
            },
            set: { newValue in
                mergeDrafts.setText(newValue, for: conflict)
            }
        )
    }

    private func currentMergedTexts() -> [String: String] {
        mergeDrafts.mergedTexts(for: conflicts)
    }
}

private struct ConflictResolutionRow: View {
    let conflict: ConflictSnapshot
    @Binding var mergedText: String
    let onUseLocalDraft: (ConflictSnapshot) -> Void
    let onUseRemoteDraft: (ConflictSnapshot) -> Void
    let onAcceptConflict: (ConflictSnapshot) -> Void
    let onAcceptLocalConflict: (ConflictSnapshot) -> Void
    let onResolveManually: (ConflictSnapshot, String) -> Void

    init(
        conflict: ConflictSnapshot,
        mergedText: Binding<String>,
        onUseLocalDraft: @escaping (ConflictSnapshot) -> Void,
        onUseRemoteDraft: @escaping (ConflictSnapshot) -> Void,
        onAcceptConflict: @escaping (ConflictSnapshot) -> Void,
        onAcceptLocalConflict: @escaping (ConflictSnapshot) -> Void,
        onResolveManually: @escaping (ConflictSnapshot, String) -> Void
    ) {
        self.conflict = conflict
        _mergedText = mergedText
        self.onUseLocalDraft = onUseLocalDraft
        self.onUseRemoteDraft = onUseRemoteDraft
        self.onAcceptConflict = onAcceptConflict
        self.onAcceptLocalConflict = onAcceptLocalConflict
        self.onResolveManually = onResolveManually
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        conflictTextColumn(title: "本地", text: conflict.localTextPlain)
                        conflictTextColumn(
                            title: "远端 r\(conflict.remoteRevision)",
                            text: conflict.remoteTextPlain
                        )
                    }

                    ConflictDiffView(
                        segments: ConflictTextDiff.segments(
                            local: conflict.localTextPlain,
                            remote: conflict.remoteTextPlain
                        )
                    )
                    .accessibilityIdentifier("editor.conflict.\(conflict.id).diff")

                    TextEditor(text: $mergedText)
                        .font(.callout)
                        .frame(minHeight: 72)
                        .accessibilityIdentifier("editor.conflict.\(conflict.id).merge-text")

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            draftButtons
                            resolutionButtons
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                draftButtons
                            }
                            HStack(spacing: 8) {
                                resolutionButtons
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.conflict.\(conflict.id)")
    }

    @ViewBuilder
    private var draftButtons: some View {
        Button {
            onUseLocalDraft(conflict)
        } label: {
            Label("编辑本地", systemImage: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("editor.conflict.\(conflict.id).draft-local")

        Button {
            onUseRemoteDraft(conflict)
        } label: {
            Label("编辑远端", systemImage: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("editor.conflict.\(conflict.id).draft-remote")
    }

    @ViewBuilder
    private var resolutionButtons: some View {
        Button {
            onResolveManually(conflict, mergedText)
        } label: {
            Label("应用合并", systemImage: "checkmark.circle")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("editor.conflict.\(conflict.id).apply-merge")

        Button {
            onAcceptLocalConflict(conflict)
        } label: {
            Label("保留本地", systemImage: "arrow.up.doc")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("editor.conflict.\(conflict.id).accept-local")

        Button {
            onAcceptConflict(conflict)
        } label: {
            Label("采用远端", systemImage: "arrow.down.doc")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("editor.conflict.\(conflict.id).accept-remote")
    }

    private func conflictTextColumn(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text.isEmpty ? " " : text)
                .font(.caption)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private struct ConflictDiffView: View {
    let segments: [ConflictTextDiffSegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(prefix(for: segment.kind))
                        .font(.caption.monospaced())
                        .foregroundStyle(foregroundColor(for: segment.kind))
                        .frame(width: 14, alignment: .center)

                    Text(segment.text.isEmpty ? " " : segment.text)
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(backgroundColor(for: segment.kind))
            }
        }
    }

    private func prefix(for kind: ConflictTextDiffSegmentKind) -> String {
        switch kind {
        case .unchanged:
            return " "
        case .removed:
            return "-"
        case .added:
            return "+"
        }
    }

    private func foregroundColor(for kind: ConflictTextDiffSegmentKind) -> Color {
        switch kind {
        case .unchanged:
            return .secondary
        case .removed:
            return .red
        case .added:
            return .green
        }
    }

    private func backgroundColor(for kind: ConflictTextDiffSegmentKind) -> Color {
        switch kind {
        case .unchanged:
            return Color.secondary.opacity(0.05)
        case .removed:
            return Color.red.opacity(0.10)
        case .added:
            return Color.green.opacity(0.12)
        }
    }
}

private struct MarkdownFileDocument: FileDocument {
    static var markdownContentType: UTType {
        UTType(filenameExtension: "md") ?? .plainText
    }

    static var readableContentTypes: [UTType] {
        [markdownContentType, .plainText]
    }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private struct BlockFocusRequest: Equatable {
    let id = UUID()
    let blockID: String
    let selection: EditorTextSelection?

    init(blockID: String, selection: EditorTextSelection? = nil) {
        self.blockID = blockID
        self.selection = selection
    }
}

struct QuoteBlockChromeDescriptor: Equatable, Sendable {
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String

    init(block: BlockSnapshot) {
        accessibilityLabel = "Quote block"
        accessibilityValue = block.textPlain.isEmpty ? "Empty" : block.textPlain
        accessibilityIdentifier = "editor.quote.\(block.id)"
    }
}

struct ListBlockChromeDescriptor: Equatable, Sendable {
    let marker: String
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String

    init(block: BlockSnapshot, ordinal: Int?) {
        accessibilityValue = block.textPlain.isEmpty ? "Empty" : block.textPlain

        if block.type == .orderedListItem {
            marker = "\(max(ordinal ?? 1, 1))."
            accessibilityLabel = "Numbered list block"
            accessibilityIdentifier = "editor.ordered-list.\(block.id)"
        } else {
            marker = "\u{2022}"
            accessibilityLabel = "Bulleted list block"
            accessibilityIdentifier = "editor.unordered-list.\(block.id)"
        }
    }
}

private struct ListMarkerGlyph: View {
    let descriptor: ListBlockChromeDescriptor
    let isNested: Bool

    var body: some View {
        Group {
            if descriptor.marker.hasSuffix(".") {
                Text(descriptor.marker)
                    .font(.system(size: 15, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary)
            } else if isNested {
                Circle()
                    .stroke(Color.primary, lineWidth: 1.7)
                    .frame(width: 5.6, height: 5.6)
            } else {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 5.6, height: 5.6)
            }
        }
        .frame(width: CGFloat(EditorBlockChrome.listMarkerWidth), height: 21, alignment: .leading)
        .accessibilityHidden(true)
    }
}

struct ListBlockOrdinalResolver: Equatable, Sendable {
    static func ordinal(for block: BlockSnapshot, at index: Int, in blocks: [BlockSnapshot]) -> Int? {
        guard block.type == .orderedListItem,
              blocks.indices.contains(index),
              blocks[index].id == block.id else {
            return nil
        }

        var ordinal = 1
        var candidateIndex = index - 1
        while candidateIndex >= 0 {
            let candidate = blocks[candidateIndex]
            if candidate.parentBlockID == block.parentBlockID {
                guard candidate.type == .orderedListItem else {
                    break
                }
                ordinal += 1
            }
            candidateIndex -= 1
        }
        return ordinal
    }
}

struct HeadingBlockChromeDescriptor: Equatable, Sendable {
    let level: Int
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String

    init(block: BlockSnapshot) {
        switch block.type {
        case .heading1:
            level = 1
            accessibilityLabel = "一级标题块"
            accessibilityIdentifier = "editor.heading1.\(block.id)"
        case .heading2:
            level = 2
            accessibilityLabel = "二级标题块"
            accessibilityIdentifier = "editor.heading2.\(block.id)"
        case .heading3:
            level = 3
            accessibilityLabel = "三级标题块"
            accessibilityIdentifier = "editor.heading3.\(block.id)"
        default:
            level = 0
            accessibilityLabel = "文本块"
            accessibilityIdentifier = "editor.block.\(block.id)"
        }
        accessibilityValue = block.textPlain.isEmpty ? "空" : block.textPlain
    }
}

struct DividerBlockChromeDescriptor: Equatable, Sendable {
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String

    init(block: BlockSnapshot) {
        accessibilityLabel = "分割线块"
        accessibilityValue = "分割线"
        accessibilityIdentifier = "editor.divider.\(block.id)"
    }
}

struct AttachmentBlockChromeDescriptor: Equatable, Sendable {
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String

    init(
        block: BlockSnapshot,
        attachment: AttachmentSnapshot?,
        generationStatus: AttachmentPreviewGenerationStatus
    ) {
        let kindTitle = Self.kindTitle(for: block)
        let filename = block.textPlain.isEmpty
            ? attachment?.originalFilename ?? "未命名附件"
            : block.textPlain
        let previewState = attachment?.previewState(for: block) ?? .unavailable

        accessibilityLabel = "\(kindTitle)附件：\(filename)"
        accessibilityIdentifier = "editor.attachment.\(block.id)"
        let statusLabel = Self.statusLabel(
            attachment: attachment,
            generationStatus: generationStatus,
            previewState: previewState
        )
        accessibilityValue = "\(kindTitle), \(statusLabel)"
    }

    private static func statusLabel(
        attachment: AttachmentSnapshot?,
        generationStatus: AttachmentPreviewGenerationStatus,
        previewState: AttachmentPreviewState
    ) -> String {
        guard attachment != nil else {
            return "附件不可用"
        }

        if case .failed = generationStatus {
            return "预览失败"
        }

        if generationStatus == .generating || previewState == .pending {
            return "正在生成预览"
        }

        if case .thumbnail = previewState {
            return "预览就绪"
        }

        return "就绪"
    }

    private static func kindTitle(for block: BlockSnapshot) -> String {
        switch block.type {
        case .attachmentImage:
            return "图片"
        case .attachmentVideo:
            return "视频"
        case .attachmentFile:
            return "文件"
        default:
            return "附件"
        }
    }
}

private struct BlockRowView: View {
    let block: BlockSnapshot
    let attachment: AttachmentSnapshot?
    let attachmentPreviewGenerationStatus: AttachmentPreviewGenerationStatus
    let pageReferencePreviewText: String?
    @ObservedObject var editorSession: EditorSession
    let nestingLevel: Int
    let listOrdinal: Int?
    let dragPayloadBlockIDs: [String]
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onMoveByKeyboard: (BlockKeyboardMoveDirection) -> Bool
    let onMoveFocusByKeyboard: (BlockKeyboardFocusDirection) -> Bool
    let onApplyInlineFormatByKeyboard: (MarkdownInlineFormat, EditorTextSelection) -> Bool
    let onInsertLinkByKeyboard: (EditorTextSelection) -> Bool
    let onInsertBlockAfter: (EditorTextSelection) -> Bool
    let onMergeBlockWithPrevious: (EditorTextSelection) -> Bool
    let onMergeBlockWithNext: (EditorTextSelection) -> Bool
    let onIndent: () -> Bool
    let onOutdent: () -> Bool
    let onPasteAttachmentURLs: ([URL]) -> Bool
    let onDelete: () -> Void
    let onOpenPageReference: (String) -> Void
    let onOpenBlockReference: (String, String) -> Void
    let onChangeType: (BlockType) -> Void
    let onConvertToPage: () -> Void
    let onTaskItemCompletionChange: (Bool) -> Void
    let onCodeBlockLineWrappingChange: (Bool) -> Void
    let onToggleBlockExpansion: () -> Void
    let onRetryAttachmentPreview: (String) -> Void
    let isToggleBlockExpanded: Bool
    let isMobileSelectionModeActive: Bool
    let isBlockSelected: Bool
    let dropPlacement: BlockDropPlacement?
    let focusRequestID: UUID?
    let focusSelection: EditorTextSelection?
    let onFocusRequestHandled: () -> Void
    let onSelectCurrentBlock: () -> Void
    let onToggleBlockSelection: () -> Void
    let onSelectAllBlocksByKeyboard: () -> Bool
    let onClearDropTarget: () -> Void
    let onTableRowsChange: ([[String]]) -> Void
    let onTextChange: (String) -> Void
    @State private var isRowHovered = false
    @State private var rowFocusRequest: BlockFocusRequest?
    @State private var slashCommandSelectionIndex = 0

    init(
        block: BlockSnapshot,
        attachment: AttachmentSnapshot? = nil,
        attachmentPreviewGenerationStatus: AttachmentPreviewGenerationStatus = .idle,
        pageReferencePreviewText: String? = nil,
        editorSession: EditorSession,
        nestingLevel: Int = 0,
        listOrdinal: Int? = nil,
        dragPayloadBlockIDs: [String] = [],
        canMoveUp: Bool = false,
        canMoveDown: Bool = false,
        onMoveUp: @escaping () -> Void = {},
        onMoveDown: @escaping () -> Void = {},
        onMoveByKeyboard: @escaping (BlockKeyboardMoveDirection) -> Bool = { _ in false },
        onMoveFocusByKeyboard: @escaping (BlockKeyboardFocusDirection) -> Bool = { _ in false },
        onApplyInlineFormatByKeyboard: @escaping (MarkdownInlineFormat, EditorTextSelection) -> Bool = { _, _ in false },
        onInsertLinkByKeyboard: @escaping (EditorTextSelection) -> Bool = { _ in false },
        onInsertBlockAfter: @escaping (EditorTextSelection) -> Bool = { _ in false },
        onMergeBlockWithPrevious: @escaping (EditorTextSelection) -> Bool = { _ in false },
        onMergeBlockWithNext: @escaping (EditorTextSelection) -> Bool = { _ in false },
        onIndent: @escaping () -> Bool = { false },
        onOutdent: @escaping () -> Bool = { false },
        onPasteAttachmentURLs: @escaping ([URL]) -> Bool = { _ in false },
        onDelete: @escaping () -> Void = {},
        onOpenPageReference: @escaping (String) -> Void = { _ in },
        onOpenBlockReference: @escaping (String, String) -> Void = { _, _ in },
        onChangeType: @escaping (BlockType) -> Void = { _ in },
        onConvertToPage: @escaping () -> Void = {},
        onTaskItemCompletionChange: @escaping (Bool) -> Void = { _ in },
        onCodeBlockLineWrappingChange: @escaping (Bool) -> Void = { _ in },
        onToggleBlockExpansion: @escaping () -> Void = {},
        onRetryAttachmentPreview: @escaping (String) -> Void = { _ in },
        isToggleBlockExpanded: Bool = true,
        isMobileSelectionModeActive: Bool = false,
        isBlockSelected: Bool = false,
        dropPlacement: BlockDropPlacement? = nil,
        focusRequestID: UUID? = nil,
        focusSelection: EditorTextSelection? = nil,
        onFocusRequestHandled: @escaping () -> Void = {},
        onSelectCurrentBlock: @escaping () -> Void = {},
        onToggleBlockSelection: @escaping () -> Void = {},
        onSelectAllBlocksByKeyboard: @escaping () -> Bool = { false },
        onClearDropTarget: @escaping () -> Void = {},
        onTableRowsChange: @escaping ([[String]]) -> Void = { _ in },
        onTextChange: @escaping (String) -> Void
    ) {
        self.block = block
        self.attachment = attachment
        self.attachmentPreviewGenerationStatus = attachmentPreviewGenerationStatus
        self.pageReferencePreviewText = pageReferencePreviewText
        self.editorSession = editorSession
        self.nestingLevel = nestingLevel
        self.listOrdinal = listOrdinal
        self.dragPayloadBlockIDs = dragPayloadBlockIDs
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onMoveByKeyboard = onMoveByKeyboard
        self.onMoveFocusByKeyboard = onMoveFocusByKeyboard
        self.onApplyInlineFormatByKeyboard = onApplyInlineFormatByKeyboard
        self.onInsertLinkByKeyboard = onInsertLinkByKeyboard
        self.onInsertBlockAfter = onInsertBlockAfter
        self.onMergeBlockWithPrevious = onMergeBlockWithPrevious
        self.onMergeBlockWithNext = onMergeBlockWithNext
        self.onIndent = onIndent
        self.onOutdent = onOutdent
        self.onPasteAttachmentURLs = onPasteAttachmentURLs
        self.onDelete = onDelete
        self.onOpenPageReference = onOpenPageReference
        self.onOpenBlockReference = onOpenBlockReference
        self.onChangeType = onChangeType
        self.onConvertToPage = onConvertToPage
        self.onTaskItemCompletionChange = onTaskItemCompletionChange
        self.onCodeBlockLineWrappingChange = onCodeBlockLineWrappingChange
        self.onToggleBlockExpansion = onToggleBlockExpansion
        self.onRetryAttachmentPreview = onRetryAttachmentPreview
        self.isToggleBlockExpanded = isToggleBlockExpanded
        self.isMobileSelectionModeActive = isMobileSelectionModeActive
        self.isBlockSelected = isBlockSelected
        self.dropPlacement = dropPlacement
        self.focusRequestID = focusRequestID
        self.focusSelection = focusSelection
        self.onFocusRequestHandled = onFocusRequestHandled
        self.onSelectCurrentBlock = onSelectCurrentBlock
        self.onToggleBlockSelection = onToggleBlockSelection
        self.onSelectAllBlocksByKeyboard = onSelectAllBlocksByKeyboard
        self.onClearDropTarget = onClearDropTarget
        self.onTableRowsChange = onTableRowsChange
        self.onTextChange = onTextChange
    }

    var body: some View {
        HStack(alignment: .top, spacing: CGFloat(EditorBlockChrome.actionColumnSpacing)) {
            blockActionColumn
            blockContent
        }
        .overlay(alignment: dropIndicatorAlignment) {
            if let dropPlacement {
                BlockDropIndicator(placement: dropPlacement)
                    .padding(.leading, dropIndicatorLeadingPadding(for: dropPlacement))
            }
        }
        .padding(.vertical, CGFloat(EditorBlockChrome.rowVerticalPadding))
        .padding(.leading, CGFloat(nestingLevel) * 24)
        .padding(.horizontal, 4)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .contextMenu {
            blockContextCommands
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(rowAccessibilityIdentifier)
        .accessibilityLabel(rowAccessibilityValue)
        .accessibilityValue(rowAccessibilityValue)
        .simultaneousGesture(
            TapGesture().onEnded {
                requestRowFocus()
            }
        )
#if os(iOS)
        .simultaneousGesture(mobileHorizontalSwipeGesture)
#endif
#if os(macOS)
        .onHover { hovering in
            isRowHovered = hovering
        }
#endif
        .animation(.easeInOut(duration: 0.12), value: isRowActive)
        .animation(.easeInOut(duration: 0.12), value: isBlockSelected)
        .onAppear {
            handleNonEditableFocusRequestIfNeeded(effectiveFocusRequestID)
        }
        .onChange(of: effectiveFocusRequestID) { _, requestID in
            handleNonEditableFocusRequestIfNeeded(requestID)
        }
#if os(macOS)
        .background(
            NonEditableBlockKeyboardFocusBridge(isEnabled: isBlockSelected && !usesNativeTextEditor) { direction in
                onMoveFocusByKeyboard(direction)
            }
            .frame(width: 0, height: 0)
        )
#endif
    }

    @ViewBuilder
    private var blockContent: some View {
        if block.type == .table {
            StructuredTableBlockEditor(
                blockID: block.id,
                text: block.textPlain,
                rows: block.tableRows,
                onRowsChange: onTableRowsChange,
                onMoveFocusByKeyboard: onMoveFocusByKeyboard
            )
            .onTapGesture {
                onClearDropTarget()
            }
        } else if block.type.isTextEditable {
            VStack(alignment: .leading, spacing: 4) {
                textEditableBlockContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                slashCommandMenu
            }
        } else if block.type == .pageReference {
            PageReferenceBlockRow(
                block: block,
                previewText: pageReferencePreviewText,
                onOpenPageReference: onOpenPageReference
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if block.type == .blockReference {
            BlockReferenceBlockRow(block: block, onOpenBlockReference: onOpenBlockReference)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if block.type == .divider {
            let descriptor = DividerBlockChromeDescriptor(block: block)
            Divider()
                .padding(.vertical, 10)
                .accessibilityLabel(descriptor.accessibilityLabel)
                .accessibilityValue(descriptor.accessibilityValue)
                .accessibilityIdentifier(descriptor.accessibilityIdentifier)
        } else {
            AttachmentBlockRow(
                block: block,
                attachment: attachment,
                generationStatus: attachmentPreviewGenerationStatus,
                onRetryPreview: onRetryAttachmentPreview
            )
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(rowBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isBlockSelected ? Color.accentColor.opacity(0.28) : Color.clear, lineWidth: 1)
            )
    }

    private var rowBackgroundColor: Color {
        if isBlockSelected {
            return Color.accentColor.opacity(0.08)
        }
        if isRowActive {
            return Color.secondary.opacity(0.045)
        }
        return Color.clear
    }

    private var isRowActive: Bool {
        isRowHovered || isBlockSelected || editorSession.focusedBlockID == block.id
    }

    private var usesNativeTextEditor: Bool {
        block.type.isTextEditable && block.type != .table
    }

    private var blockActionOpacity: Double {
        isRowActive ? 1 : EditorBlockChrome.inactiveHandleOpacity
    }

    @ViewBuilder
    private var blockActionColumn: some View {
#if os(iOS)
        if MobileBlockSelectionChromeResolver.isSelectionControlVisible(
            isSelectionModeActive: isMobileSelectionModeActive
        ) {
            Button {
                onToggleBlockSelection()
            } label: {
                Image(systemName: MobileBlockSelectionChromeResolver.symbolName(isSelected: isBlockSelected))
                    .font(.callout.weight(isBlockSelected ? .semibold : .regular))
                    .foregroundStyle(isBlockSelected ? Color.accentColor : Color.secondary.opacity(0.72))
            }
            .buttonStyle(.plain)
            .frame(width: CGFloat(EditorBlockChrome.dragHandleWidth), height: 24)
            .contentShape(Rectangle())
            .padding(.top, 0)
            .accessibilityLabel(isBlockSelected ? "取消选择块" : "选择块")
            .accessibilityValue(block.type.editorMenuTitle)
            .accessibilityIdentifier("editor.block.\(block.id).selection-toggle")
        } else {
            dragHandleColumn
        }
#else
        dragHandleColumn
#endif
    }

    private var dragHandleColumn: some View {
        Image(systemName: "circle.grid.2x2")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .draggable(dragPayloadText) {
                DragPreviewBlock(block: block)
            }
            .accessibilityLabel("块拖拽手柄")
            .accessibilityValue(block.type.editorMenuTitle)
            .accessibilityIdentifier("editor.block.\(block.id).drag-handle")
            .frame(width: CGFloat(EditorBlockChrome.dragHandleWidth), height: 20)
            .contentShape(Rectangle())
            .padding(.top, 2)
            .opacity(blockActionOpacity)
    }

    private var dragPayloadText: String {
        let payloadBlockIDs = dragPayloadBlockIDs.isEmpty ? [block.id] : dragPayloadBlockIDs
        return payloadBlockIDs.joined(separator: "\n")
    }

    private var dropIndicatorAlignment: Alignment {
        switch dropPlacement {
        case .before:
            return .topLeading
        case .after, .childAfter, nil:
            return .bottomLeading
        }
    }

    private func dropIndicatorLeadingPadding(for placement: BlockDropPlacement) -> CGFloat {
        placement == .childAfter ? 28 : 0
    }

    @ViewBuilder
    private var slashCommandMenu: some View {
        let commands = SlashCommandResolver.matchingCommands(for: block.textPlain)
        if editorSession.focusedBlockID == block.id,
           block.textPlain.hasPrefix("/"),
           !commands.isEmpty {
            SlashCommandMenu(
                commands: commands,
                selectedIndex: clampedSlashCommandSelectionIndex(for: commands),
                onHover: { index in
                    slashCommandSelectionIndex = index
                },
                onSelect: applySlashCommand
            )
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var blockContextCommands: some View {
        Button {
            _ = onInsertBlockAfter(blockEndSelection)
        } label: {
            Label("下方新增", systemImage: "plus")
        }

        if block.type.isTextEditable {
            Divider()

            Button {
                onConvertToPage()
            } label: {
                Label("页面", systemImage: "doc.text")
            }

            ForEach(Self.textBlockMenuTypes, id: \.self) { type in
                Button {
                    onChangeType(type)
                } label: {
                    Label(type.editorMenuTitle, systemImage: type.editorMenuSystemImage)
                }
            }
        }

        Divider()

        Button {
            onMoveUp()
        } label: {
            Label("上移", systemImage: "chevron.up")
        }
        .disabled(!canMoveUp)

        Button {
            onMoveDown()
        } label: {
            Label("下移", systemImage: "chevron.down")
        }
        .disabled(!canMoveDown)

        Button {
            _ = onOutdent()
        } label: {
            Label("减少缩进", systemImage: "decrease.indent")
        }
        .disabled(nestingLevel == 0)

        Button {
            _ = onIndent()
        } label: {
            Label("增加缩进", systemImage: "increase.indent")
        }
        .disabled(!canMoveUp)

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    private var blockEndSelection: EditorTextSelection {
        EditorTextSelection(
            blockID: block.id,
            location: (block.textPlain as NSString).length,
            length: 0
        )
    }

    private var effectiveFocusRequestID: UUID? {
        rowFocusRequest?.id ?? focusRequestID
    }

    private var effectiveFocusSelection: EditorTextSelection? {
        rowFocusRequest?.selection ?? focusSelection
    }

    private var rowAccessibilityIdentifier: String {
        switch block.type {
        case .pageReference:
            return "editor.page-reference.\(block.id)"
        case .blockReference:
            return "editor.block-reference.\(block.id)"
        default:
            return "editor.block.\(block.id)"
        }
    }

    private var rowAccessibilityValue: String {
        let selectionState = isBlockSelected ? "当前块已选中" : "当前块未选中"
        let content = block.textPlain.isEmpty ? "空" : block.textPlain
        return "\(content), \(selectionState)"
    }

    @ViewBuilder
    private var textEditableBlockContent: some View {
        if block.type == .heading1 || block.type == .heading2 || block.type == .heading3 {
            let descriptor = HeadingBlockChromeDescriptor(block: block)
            nativeTextBlockEditor
                .padding(.vertical, descriptor.level == 1 ? 2 : 1)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(descriptor.accessibilityLabel)
                .accessibilityValue(descriptor.accessibilityValue)
                .accessibilityIdentifier(descriptor.accessibilityIdentifier)
                .accessibilityAddTraits(.isHeader)
        } else if block.type == .unorderedListItem || block.type == .orderedListItem {
            let descriptor = ListBlockChromeDescriptor(block: block, ordinal: listOrdinal)
            HStack(alignment: .top, spacing: CGFloat(EditorBlockChrome.listTextSpacing)) {
                ListMarkerGlyph(descriptor: descriptor, isNested: block.parentBlockID != nil)
                    .padding(.top, 2)

                nativeTextBlockEditor
            }
            .padding(.vertical, CGFloat(EditorBlockChrome.listVerticalPadding))
            .padding(.horizontal, CGFloat(EditorBlockChrome.listHorizontalPadding))
            .background(Color.secondary.opacity(EditorBlockChrome.listBackgroundOpacity))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(descriptor.accessibilityLabel)
            .accessibilityValue(descriptor.accessibilityValue)
            .accessibilityIdentifier(descriptor.accessibilityIdentifier)
        } else if block.type == .taskItem {
            HStack(alignment: .top, spacing: 8) {
                taskItemCompletionButton
                    .padding(.top, 1)

                nativeTextBlockEditor
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color.green.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.green.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(taskBlockAccessibilityLabel)
            .accessibilityValue(block.taskItemIsCompleted ? "已完成" : "未完成")
            .accessibilityIdentifier("editor.task.\(block.id)")
        } else if block.type == .codeBlock {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: block.type.editorMenuSystemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Spacer(minLength: 8)

                    codeBlockWrapButton
                }

                nativeTextBlockEditor
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color(red: 0.965, green: 0.968, blue: 0.972))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(codeBlockAccessibilityLabel)
            .accessibilityValue(block.codeBlockLineWrapping ? "已开启自动换行" : "已关闭自动换行")
            .accessibilityIdentifier("editor.code.\(block.id)")
        } else if block.type == .toggle {
            HStack(alignment: .top, spacing: 8) {
                toggleBlockExpansionButton
                    .padding(.top, 1)

                nativeTextBlockEditor
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color.secondary.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(toggleBlockAccessibilityLabel)
            .accessibilityValue(isToggleBlockExpanded ? "已展开" : "已折叠")
            .accessibilityIdentifier("editor.toggle.\(block.id)")
        } else if block.type == .callout {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                    .accessibilityHidden(true)

                nativeTextBlockEditor
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color(red: 0.964, green: 0.968, blue: 0.974))
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat(EditorBlockChrome.specialBlockCornerRadius))
                    .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CGFloat(EditorBlockChrome.specialBlockCornerRadius)))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("提示块")
            .accessibilityValue(block.textPlain.isEmpty ? "空" : block.textPlain)
            .accessibilityIdentifier("editor.callout.\(block.id)")
        } else if block.type == .quote {
            let descriptor = QuoteBlockChromeDescriptor(block: block)
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.38))
                    .frame(width: 3)
                    .padding(.vertical, 3)
                    .accessibilityHidden(true)

                Image(systemName: "quote.opening")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                    .accessibilityHidden(true)

                nativeTextBlockEditor
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color(red: 0.966, green: 0.969, blue: 0.974))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(descriptor.accessibilityLabel)
            .accessibilityValue(descriptor.accessibilityValue)
            .accessibilityIdentifier(descriptor.accessibilityIdentifier)
        } else {
            HStack(alignment: .top, spacing: 8) {
                textBlockLeadingControls
                nativeTextBlockEditor
            }
        }
    }

    @ViewBuilder
    private var textBlockLeadingControls: some View {
        if block.type == .taskItem {
            taskItemCompletionButton
        }

        if block.type == .toggle {
            toggleBlockExpansionButton
        }

        if block.type == .codeBlock {
            codeBlockWrapButton
        }
    }

    private var taskItemCompletionButton: some View {
        Button {
            onTaskItemCompletionChange(!block.taskItemIsCompleted)
        } label: {
            Image(systemName: block.taskItemIsCompleted ? "checkmark.circle.fill" : "circle")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(block.taskItemIsCompleted ? .green : .secondary)
        .help(block.taskItemIsCompleted ? "标记未完成" : "标记完成")
        .accessibilityLabel(block.taskItemIsCompleted ? "标记任务未完成" : "标记任务完成")
        .accessibilityValue(block.taskItemIsCompleted ? "已完成" : "未完成")
        .accessibilityIdentifier("editor.block.\(block.id).task-toggle")
    }

    private var toggleBlockExpansionButton: some View {
        Button {
            onToggleBlockExpansion()
        } label: {
            Image(systemName: isToggleBlockExpanded ? "chevron.down" : "chevron.right")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(isToggleBlockExpanded ? "折叠" : "展开")
        .accessibilityLabel(isToggleBlockExpanded ? "折叠块" : "展开块")
        .accessibilityValue(isToggleBlockExpanded ? "已展开" : "已折叠")
        .accessibilityIdentifier("editor.block.\(block.id).toggle-expansion")
    }

    private var codeBlockWrapButton: some View {
        Button {
            onCodeBlockLineWrappingChange(!block.codeBlockLineWrapping)
        } label: {
            Image(systemName: "text.alignleft")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(block.codeBlockLineWrapping ? .primary : .secondary)
        .help(block.codeBlockLineWrapping ? "关闭自动换行" : "开启自动换行")
        .accessibilityLabel(block.codeBlockLineWrapping ? "关闭代码自动换行" : "开启代码自动换行")
        .accessibilityValue(block.codeBlockLineWrapping ? "已开启自动换行" : "已关闭自动换行")
        .accessibilityIdentifier("editor.block.\(block.id).code-wrap")
    }

    private var codeBlockAccessibilityLabel: String {
        block.codeBlockLineWrapping ? "代码块，已开启自动换行" : "代码块，已关闭自动换行"
    }

    private var toggleBlockAccessibilityLabel: String {
        isToggleBlockExpanded ? "折叠块，已展开" : "折叠块，已折叠"
    }

    private var taskBlockAccessibilityLabel: String {
        block.taskItemIsCompleted ? "任务块，已完成" : "任务块，未完成"
    }

    private var nativeTextBlockEditor: some View {
        NativeTextBlockEditor(
            blockID: block.id,
            text: block.textPlain,
            blockType: block.type,
            session: editorSession,
            lineWrapping: block.type == .codeBlock ? block.codeBlockLineWrapping : true,
            focusRequestID: effectiveFocusRequestID,
            focusSelection: effectiveFocusSelection,
            onFocusRequestHandled: handleFocusRequestHandled,
            onMoveByKeyboard: onMoveByKeyboard,
            onIndentationByKeyboard: handleKeyboardIndentation,
            onMoveFocusByKeyboard: onMoveFocusByKeyboard,
            onApplyInlineFormatByKeyboard: onApplyInlineFormatByKeyboard,
            onInsertLinkByKeyboard: onInsertLinkByKeyboard,
            onInsertBlockAfter: onInsertBlockAfter,
            onMergeBlockWithPrevious: onMergeBlockWithPrevious,
            onMergeBlockWithNext: onMergeBlockWithNext,
            onSlashCommandNavigationByKeyboard: handleSlashCommandNavigation,
            onSlashCommandSelectionByKeyboard: selectCurrentSlashCommand,
            onPasteAttachmentURLs: onPasteAttachmentURLs,
            onSelectAllBlocksByKeyboard: onSelectAllBlocksByKeyboard,
            onCancelSelectionByKeyboard: {
                let hadBlockSelection = !editorSession.selectedBlockIDs.isEmpty
                editorSession.clearBlockSelection()
                return hadBlockSelection
            },
            onHorizontalSwipe: { translationWidth in
#if os(iOS)
                handleMobileHorizontalSwipe(translation: CGSize(width: translationWidth, height: 0))
                return true
#else
                return false
#endif
            },
            onTextChange: { text in
                onClearDropTarget()
                onTextChange(text)
            }
        )
        .accessibilityIdentifier("editor.text.\(block.id)")
#if os(iOS)
        .highPriorityGesture(mobileHorizontalSwipeGesture)
#endif
    }

    private func controlAvailabilityValue(_ isAvailable: Bool) -> String {
        isAvailable ? "可用" : "不可用"
    }

    private func handleKeyboardIndentation(_ direction: BlockKeyboardIndentationDirection) -> Bool {
        switch direction {
        case .indent:
            return onIndent()
        case .outdent:
            return onOutdent()
        }
    }

#if os(iOS)
    private var mobileHorizontalSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                handleMobileHorizontalSwipe(translation: value.translation)
            }
    }

    private func handleMobileHorizontalSwipe(translation: CGSize) {
        guard let action = MobileBlockSwipeActionResolver.action(
            translation: translation,
            isEditingBlock: editorSession.focusedBlockID == block.id,
            nestingLevel: nestingLevel
        ) else {
            return
        }

        switch action {
        case .select:
            onToggleBlockSelection()
        case .indent:
            if onIndent() {
                rowFocusRequest = BlockFocusRequest(blockID: block.id)
            }
        case .outdent:
            if onOutdent() {
                rowFocusRequest = BlockFocusRequest(blockID: block.id)
            }
        }
    }
#endif

    private static let textBlockMenuTypes: [BlockType] = [
        .paragraph,
        .heading1,
        .heading2,
        .heading3,
        .unorderedListItem,
        .orderedListItem,
        .taskItem,
        .quote,
        .codeBlock,
        .divider,
        .table,
        .callout,
        .toggle
    ]

    private func applySlashCommand(_ command: SlashCommandDescriptor) {
        slashCommandSelectionIndex = 0
        switch command.type {
        case .pageReference:
            onTextChange("")
            onConvertToPage()
        case .attachmentFile, .attachmentImage, .attachmentVideo:
            break
        default:
            onTextChange("")
            onChangeType(command.type)
            rowFocusRequest = BlockFocusRequest(blockID: block.id)
        }
    }

    private func handleSlashCommandNavigation(_ direction: BlockKeyboardMoveDirection) -> Bool {
        let commands = SlashCommandResolver.matchingCommands(for: block.textPlain)
        guard editorSession.focusedBlockID == block.id,
              block.textPlain.hasPrefix("/"),
              !commands.isEmpty else {
            return false
        }

        let currentIndex = clampedSlashCommandSelectionIndex(for: commands)
        switch direction {
        case .up:
            slashCommandSelectionIndex = max(0, currentIndex - 1)
        case .down:
            slashCommandSelectionIndex = min(commands.count - 1, currentIndex + 1)
        }
        return true
    }

    private func selectCurrentSlashCommand() -> Bool {
        let commands = SlashCommandResolver.matchingCommands(for: block.textPlain)
        guard editorSession.focusedBlockID == block.id,
              block.textPlain.hasPrefix("/"),
              !commands.isEmpty else {
            return false
        }

        applySlashCommand(commands[clampedSlashCommandSelectionIndex(for: commands)])
        return true
    }

    private func clampedSlashCommandSelectionIndex(for commands: [SlashCommandDescriptor]) -> Int {
        guard !commands.isEmpty else {
            return 0
        }
        return min(max(slashCommandSelectionIndex, 0), commands.count - 1)
    }

    private func requestRowFocus() {
        onClearDropTarget()
        guard usesNativeTextEditor else {
            onSelectCurrentBlock()
            return
        }

        DispatchQueue.main.async {
            let selection = editorSession.textSelection?.blockID == block.id ? editorSession.textSelection : nil
            rowFocusRequest = BlockFocusRequest(blockID: block.id, selection: selection)
            EditorLog.focus.debug(
                "editor_focus_request_scheduled block_id=\(block.id, privacy: .public) source=row_tap"
            )
        }
    }

    private func handleFocusRequestHandled() {
        onClearDropTarget()
        if rowFocusRequest?.blockID == block.id {
            rowFocusRequest = nil
        }
        onFocusRequestHandled()
    }

    private func handleNonEditableFocusRequestIfNeeded(_ requestID: UUID?) {
        guard requestID != nil,
              !usesNativeTextEditor else {
            return
        }

        onSelectCurrentBlock()
        handleFocusRequestHandled()
    }
}

private enum BlockDropSlotKind: Equatable {
    case before
    case after
}

private struct BlockDropSlot: View {
    let destinationBlockID: String
    let slotKind: BlockDropSlotKind
    @Binding var activeDropTarget: BlockDropTarget?
    let moveDroppedBlocks: ([String], String, BlockDropPlacement) -> Bool

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: CGFloat(EditorBlockChrome.dropSlotHeight))
            .contentShape(Rectangle())
            .onDrop(
                of: [UTType.plainText.identifier, UTType.text.identifier],
                delegate: EditorBlockDropDelegate(
                    destinationBlockID: destinationBlockID,
                    slotKind: slotKind,
                    activeDropTarget: $activeDropTarget,
                    moveDroppedBlocks: moveDroppedBlocks
                )
            )
            .accessibilityHidden(true)
    }
}

private struct CanvasTrailingInsertRegion: View {
    let onInsert: () -> Void

    var body: some View {
        Button(action: onInsert) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: CGFloat(EditorBlockChrome.trailingInsertHitHeight))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("在末尾继续编辑")
        .accessibilityValue("点击后创建或聚焦末尾文本块")
        .accessibilityIdentifier("editor.canvas-trailing-insert-region")
    }
}

private struct EditorBlockDropDelegate: DropDelegate {
    let destinationBlockID: String
    let slotKind: BlockDropSlotKind
    @Binding var activeDropTarget: BlockDropTarget?
    let moveDroppedBlocks: ([String], String, BlockDropPlacement) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        !info.itemProviders(for: [UTType.plainText.identifier, UTType.text.identifier]).isEmpty
    }

    func dropEntered(info: DropInfo) {
        updateTarget(for: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateTarget(for: info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        clearTargetIfNeeded()
    }

    func performDrop(info: DropInfo) -> Bool {
        let placement = updateTarget(for: info)
        guard let provider = info.itemProviders(for: [UTType.plainText.identifier, UTType.text.identifier]).first,
              let typeIdentifier = provider.registeredTypeIdentifiers.first(where: { identifier in
                  UTType(identifier)?.conforms(to: .text) == true
              }) else {
            clearTargetIfNeeded()
            return false
        }

        activeDropTarget = nil
        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
            let blockIDs = Self.blockIDs(from: item)
            DispatchQueue.main.async {
                guard !blockIDs.isEmpty else {
                    return
                }
                _ = moveDroppedBlocks(blockIDs, destinationBlockID, placement)
            }
        }
        return true
    }

    @discardableResult
    private func updateTarget(for info: DropInfo) -> BlockDropPlacement {
        let placement = placement(for: info)
        let target = BlockDropTarget(blockID: destinationBlockID, placement: placement)
        if activeDropTarget != target {
            activeDropTarget = target
        }
        return placement
    }

    private func placement(for info: DropInfo) -> BlockDropPlacement {
        switch slotKind {
        case .before:
            return .before
        case .after:
            return info.location.x >= BlockDropPlacementResolver.indentationThreshold ? .childAfter : .after
        }
    }

    private func clearTargetIfNeeded() {
        guard activeDropTarget?.blockID == destinationBlockID else {
            return
        }
        activeDropTarget = nil
    }

    nonisolated private static func blockIDs(from item: NSSecureCoding?) -> [String] {
        let text: String?
        if let string = item as? String {
            text = string
        } else if let string = item as? NSString {
            text = string as String
        } else if let data = item as? Data {
            text = String(data: data, encoding: .utf8)
        } else {
            text = nil
        }

        return text?
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map(String.init)
            .filter { !$0.isEmpty } ?? []
    }
}

private struct BlockDropIndicator: View {
    let placement: BlockDropPlacement

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 5, height: 5)

            Capsule()
                .fill(indicatorColor)
                .frame(maxWidth: 520)
                .frame(height: 2)

            if placement == .childAfter {
                Text("缩进一级")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(indicatorColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(indicatorColor.opacity(0.08))
                    .clipShape(Capsule())
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("editor.block-drop-indicator")
    }

    private var indicatorColor: Color {
        placement == .childAfter ? Color.accentColor.opacity(0.78) : Color.accentColor.opacity(0.58)
    }

    private var accessibilityLabel: String {
        switch placement {
        case .before:
            return "拖拽到块上方"
        case .after:
            return "拖拽到块下方"
        case .childAfter:
            return "拖拽为下级块"
        }
    }
}

private struct DragPreviewBlock: View {
    let block: BlockSnapshot

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 34)

            HStack(spacing: 9) {
                Image(systemName: block.type.editorMenuSystemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(previewText)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 260, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .shadow(color: Color.black.opacity(0.13), radius: 12, x: 0, y: 7)
        }
        .frame(width: 330, alignment: .leading)
        .offset(x: 12, y: 8)
    }

    private var previewText: String {
        let trimmed = block.textPlain.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? block.type.editorMenuTitle : trimmed
    }
}

private struct SlashCommandMenu: View {
    let commands: [SlashCommandDescriptor]
    let selectedIndex: Int
    let onHover: (Int) -> Void
    let onSelect: (SlashCommandDescriptor) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                        Button {
                            onSelect(command)
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: command.type.editorMenuSystemImage)
                                    .font(.callout)
                                    .foregroundStyle(index == selectedIndex ? Color.accentColor : .secondary)
                                    .frame(width: 18)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(command.title)
                                        .font(.callout.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(command.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 12)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(index == selectedIndex ? Color.accentColor.opacity(0.08) : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .id(command.id)
                        .buttonStyle(.plain)
                        .disabled(command.type == .attachmentFile)
                        .onHover { hovering in
                            if hovering {
                                onHover(index)
                            }
                        }
                        .accessibilityIdentifier("editor.slash-command.\(command.id)")
                    }
                }
                .padding(.vertical, 5)
            }
            .frame(maxHeight: 278)
            .onChange(of: selectedIndex) { _, index in
                guard commands.indices.contains(index) else {
                    return
                }
                withAnimation(.easeOut(duration: 0.08)) {
                    proxy.scrollTo(commands[index].id, anchor: .center)
                }
            }
        }
        .frame(width: 260, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        .accessibilityValue("可滚动，\(commands.count) 项")
        .accessibilityIdentifier("editor.slash-command-menu")
    }
}

private struct StructuredTableBlockEditor: View {
    let blockID: String
    let text: String
    let rows: [[String]]
    let onRowsChange: ([[String]]) -> Void
    let onMoveFocusByKeyboard: (BlockKeyboardFocusDirection) -> Bool
    @State private var isTableHovered = false
    @State private var selection = TableSelection.empty

    private var table: MarkdownTableDocument {
        MarkdownTableDocument(rows: editableRows)
    }

    var body: some View {
        let rows = editableRows
        let tableDimensions = tableDimensionAccessibilityValue(rows: rows)
        let viewportWidth = tableViewportWidth(rows: rows)
        let contentHeight = tableContentHeight(rows: rows)
        let columnCount = tableColumnCount(rows: rows)

        ZStack(alignment: .topLeading) {
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    tableGrid(rows: rows, columnCount: columnCount)
                    tableSelectionHitLayer(rows: rows, columnCount: columnCount)
                }
                .fixedSize()
            }
            .frame(
                width: viewportWidth,
                height: contentHeight
            )
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat(TableBlockChrome.cornerRadius), style: .continuous)
                    .stroke(Color.secondary.opacity(TableBlockChrome.outerBorderOpacity), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CGFloat(TableBlockChrome.cornerRadius), style: .continuous))
        }
        .overlay(alignment: .bottom) {
            tablePrimaryControl(
                systemImage: "plus",
                help: "新增行",
                accessibilityLabel: "新增表格行",
                accessibilityValue: tableDimensions,
                accessibilityIdentifier: "editor.table.\(blockID).add-row",
                action: appendRow
            )
            .offset(y: CGFloat(TableBlockChrome.insertControlEdgeOffset))
        }
        .overlay(alignment: .trailing) {
            tablePrimaryControl(
                systemImage: "plus",
                help: "新增列",
                accessibilityLabel: "新增表格列",
                accessibilityValue: tableDimensions,
                accessibilityIdentifier: "editor.table.\(blockID).add-column",
                action: appendColumn
            )
            .offset(x: CGFloat(TableBlockChrome.insertControlEdgeOffset))
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            isTableHovered = hovering
        }
#if os(macOS)
        .onDeleteCommand {
            deleteSelection()
        }
        .background(
            TableDeleteKeyBridge(isEnabled: !selection.isEmpty) {
                deleteSelection()
            } onMoveFocus: { direction in
                onMoveFocusByKeyboard(direction)
            }
            .frame(width: 0, height: 0)
        )
#endif
        .accessibilityElement(children: .contain)
        .accessibilityLabel("表格块，\(tableDimensions)")
        .accessibilityValue(tableDimensions)
        .accessibilityIdentifier("editor.table.\(blockID)")
    }

    private var editableRows: [[String]] {
        if !rows.isEmpty {
            return rows
        }

        let markdownRows = MarkdownTableDocument(markdown: text).rows
        if !markdownRows.isEmpty {
            return markdownRows
        }

        return [[text]]
    }

    private func tableDimensionAccessibilityValue(rows: [[String]]) -> String {
        let rowCount = rows.count
        let columnCount = rows.map(\.count).max() ?? 0
        return "\(rowCount) 行，\(columnCount) 列"
    }

    private func tableViewportWidth(rows: [[String]]) -> CGFloat {
        let columnCount = tableColumnCount(rows: rows)
        let contentWidth = CGFloat(columnCount) * CGFloat(TableBlockChrome.cellWidth)
        return min(contentWidth, CGFloat(TableBlockChrome.maxViewportWidth))
    }

    private func tableContentHeight(rows: [[String]]) -> CGFloat {
        CGFloat(max(rows.count, 1)) * CGFloat(TableBlockChrome.cellHeight)
    }

    private func tableColumnCount(rows: [[String]]) -> Int {
        max(rows.map(\.count).max() ?? 1, 1)
    }

    private func tableContentWidth(columnCount: Int) -> CGFloat {
        CGFloat(columnCount) * CGFloat(TableBlockChrome.cellWidth)
    }

    private func tableGrid(rows: [[String]], columnCount: Int) -> some View {
        Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                GridRow(alignment: .top) {
                    ForEach(0..<columnCount, id: \.self) { columnIndex in
                        tableCell(
                            row: rowIndex,
                            column: columnIndex,
                            rowCount: rows.count,
                            columnCount: columnCount
                        )
                    }
                }
            }
        }
    }

    private func tableSelectionHitLayer(rows: [[String]], columnCount: Int) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                rowSelector(rowIndex, columnCount: columnCount)
            }

            ForEach(0..<columnCount, id: \.self) { columnIndex in
                columnSelector(columnIndex)
            }
        }
        .frame(
            width: tableContentWidth(columnCount: columnCount),
            height: tableContentHeight(rows: rows),
            alignment: .topLeading
        )
        .zIndex(2)
    }

    private func cellBinding(row rowIndex: Int, column columnIndex: Int) -> Binding<String> {
        Binding {
            let rows = editableRows
            guard rows.indices.contains(rowIndex),
                  rows[rowIndex].indices.contains(columnIndex) else {
                return ""
            }
            return rows[rowIndex][columnIndex]
        } set: { value in
            var updatedTable = table
            updatedTable.updateCell(row: rowIndex, column: columnIndex, text: value)
            onRowsChange(updatedTable.rows)
        }
    }

    private func tableCell(
        row rowIndex: Int,
        column columnIndex: Int,
        rowCount: Int,
        columnCount: Int
    ) -> some View {
        TextField(
            "",
            text: cellBinding(row: rowIndex, column: columnIndex)
        )
        .textFieldStyle(.plain)
        .font(.system(size: 14, weight: rowIndex == 0 ? .semibold : .regular))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(
            width: CGFloat(TableBlockChrome.cellWidth),
            height: CGFloat(TableBlockChrome.cellHeight),
            alignment: .topLeading
        )
        .background(cellBackgroundColor(row: rowIndex, column: columnIndex))
        .overlay {
            if selection.rows.contains(rowIndex) || selection.columns.contains(columnIndex) {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
            }
        }
        .overlay(alignment: .trailing) {
            if columnIndex < columnCount - 1 {
                Rectangle()
                    .fill(Color.secondary.opacity(TableBlockChrome.gridLineOpacity))
                    .frame(width: 1)
            }
        }
        .overlay(alignment: .bottom) {
            if rowIndex < rowCount - 1 {
                Rectangle()
                    .fill(Color.secondary.opacity(TableBlockChrome.gridLineOpacity))
                    .frame(height: 1)
            }
        }
        .onTapGesture {
            selection = .empty
        }
        .accessibilityIdentifier("editor.table.\(blockID).cell.\(rowIndex).\(columnIndex)")
    }

    private func cellBackgroundColor(row rowIndex: Int, column columnIndex: Int) -> Color {
        if selection.rows.contains(rowIndex) || selection.columns.contains(columnIndex) {
            return Color.accentColor.opacity(0.08)
        }
        return rowIndex == 0 ? Color.secondary.opacity(0.012) : Color.white
    }

    private func rowSelector(_ rowIndex: Int, columnCount: Int) -> some View {
        Button {
            selection = TableSelectionReducer.selectionAfterSelectingRow(
                rowIndex,
                current: selection,
                extend: isShiftPressed
            )
        } label: {
            Rectangle()
                .fill(Color.accentColor.opacity(TableBlockChrome.selectorHitOpacity))
                .frame(
                    width: CGFloat(TableBlockChrome.selectorWidth),
                    height: CGFloat(TableBlockChrome.cellHeight)
                )
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .offset(
            x: 0,
            y: CGFloat(rowIndex) * CGFloat(TableBlockChrome.cellHeight)
        )
        .help("选择第 \(rowIndex + 1) 行")
        .accessibilityLabel("选择第 \(rowIndex + 1) 行")
        .accessibilityValue(selection.rows.contains(rowIndex) ? "已选择" : "未选择")
        .accessibilityIdentifier("editor.table.\(blockID).row-selector.\(rowIndex)")
    }

    private func columnSelector(_ columnIndex: Int) -> some View {
        Button {
            selection = TableSelectionReducer.selectionAfterSelectingColumn(
                columnIndex,
                current: selection,
                extend: isShiftPressed
            )
        } label: {
            Rectangle()
                .fill(Color.accentColor.opacity(TableBlockChrome.selectorHitOpacity))
                .frame(
                    width: CGFloat(TableBlockChrome.cellWidth),
                    height: CGFloat(TableBlockChrome.selectorHeight)
                )
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .offset(
            x: CGFloat(columnIndex) * CGFloat(TableBlockChrome.cellWidth),
            y: 0
        )
        .help("选择第 \(columnIndex + 1) 列")
        .accessibilityLabel("选择第 \(columnIndex + 1) 列")
        .accessibilityValue(selection.columns.contains(columnIndex) ? "已选择" : "未选择")
        .accessibilityIdentifier("editor.table.\(blockID).column-selector.\(columnIndex)")
    }

    private func tablePrimaryControl(
        systemImage: String,
        help: String,
        accessibilityLabel: String,
        accessibilityValue: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        TableInsertControl(
            systemImage: systemImage,
            help: help,
            accessibilityLabel: accessibilityLabel,
            accessibilityValue: accessibilityValue,
            accessibilityIdentifier: accessibilityIdentifier,
            action: action
        )
    }

    private func appendRow() {
        var updatedTable = normalizedTable()
        updatedTable.appendRow()
        onRowsChange(updatedTable.rows)
    }

    private func appendColumn() {
        var updatedTable = normalizedTable()
        updatedTable.appendColumn()
        onRowsChange(updatedTable.rows)
    }

    private func removeLastRow() {
        var updatedTable = normalizedTable()
        updatedTable.removeLastRow()
        onRowsChange(updatedTable.rows)
    }

    private func removeLastColumn() {
        var updatedTable = normalizedTable()
        updatedTable.removeLastColumn()
        onRowsChange(updatedTable.rows)
    }

    private func deleteSelection() {
        guard !selection.isEmpty else {
            return
        }
        let updatedRows = TableSelectionReducer.rowsAfterDeletingSelection(selection, from: editableRows)
        selection = .empty
        onRowsChange(updatedRows)
    }

    private var isShiftPressed: Bool {
#if os(macOS)
        NSEvent.modifierFlags.contains(.shift)
#else
        false
#endif
    }

    private func normalizedTable() -> MarkdownTableDocument {
        table
    }
}

private struct TableInsertControl: View {
    let systemImage: String
    let help: String
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(
                        width: isHovered
                            ? CGFloat(TableBlockChrome.insertControlExpandedDiameter)
                            : CGFloat(TableBlockChrome.insertControlVisibleDiameter),
                        height: isHovered
                            ? CGFloat(TableBlockChrome.insertControlExpandedDiameter)
                            : CGFloat(TableBlockChrome.insertControlVisibleDiameter)
                    )

                if isHovered {
                    Image(systemName: systemImage)
                        .font(.system(size: CGFloat(TableBlockChrome.insertControlIconFontSize), weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
            .frame(
                width: CGFloat(TableBlockChrome.primaryControlDiameter),
                height: CGFloat(TableBlockChrome.primaryControlDiameter)
            )
            .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(accessibilityIdentifier)
#if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
#endif
    }
}

#if os(macOS)
private struct NonEditableBlockKeyboardFocusBridge: NSViewRepresentable {
    let isEnabled: Bool
    let onMoveFocus: (BlockKeyboardFocusDirection) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onMoveFocus: onMoveFocus)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.install()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onMoveFocus = onMoveFocus
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    @MainActor
    final class Coordinator {
        var isEnabled = false
        var onMoveFocus: (BlockKeyboardFocusDirection) -> Bool
        private var monitor: Any?

        init(onMoveFocus: @escaping (BlockKeyboardFocusDirection) -> Bool) {
            self.onMoveFocus = onMoveFocus
        }

        func install() {
            guard monitor == nil else {
                return
            }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else {
                    return event
                }
                guard isEnabled,
                      let direction = NonEditableBlockKeyboardFocusResolver.focusDirection(
                        keyCode: event.keyCode,
                        modifiers: event.blockKeyboardShortcutModifiers
                      ) else {
                    return event
                }

                return onMoveFocus(direction) ? nil : event
            }
        }

        func uninstall() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }
    }
}

private struct TableDeleteKeyBridge: NSViewRepresentable {
    let isEnabled: Bool
    let onDelete: () -> Void
    let onMoveFocus: (BlockKeyboardFocusDirection) -> Bool

    func makeNSView(context: Context) -> TableDeleteKeyCaptureView {
        let view = TableDeleteKeyCaptureView(frame: .zero)
        view.isEnabled = isEnabled
        view.onDelete = onDelete
        view.onMoveFocus = onMoveFocus
        return view
    }

    func updateNSView(_ nsView: TableDeleteKeyCaptureView, context: Context) {
        nsView.isEnabled = isEnabled
        nsView.onDelete = onDelete
        nsView.onMoveFocus = onMoveFocus

        guard isEnabled else {
            return
        }

        DispatchQueue.main.async {
            guard nsView.window?.firstResponder !== nsView else {
                return
            }
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class TableDeleteKeyCaptureView: NSView {
        var isEnabled = false
        var onDelete: () -> Void
        var onMoveFocus: (BlockKeyboardFocusDirection) -> Bool

        override init(frame frameRect: NSRect) {
            self.onDelete = {}
            self.onMoveFocus = { _ in false }
            super.init(frame: frameRect)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var acceptsFirstResponder: Bool {
            true
        }

        override func keyDown(with event: NSEvent) {
            guard let action = TableBlockKeyboardActionResolver.action(
                keyCode: event.keyCode,
                modifiers: event.blockKeyboardShortcutModifiers,
                hasSelection: isEnabled
            ) else {
                nextResponder?.keyDown(with: event)
                return
            }

            switch action {
            case .deleteSelection:
                onDelete()
            case .moveFocus(let direction):
                if !onMoveFocus(direction) {
                    nextResponder?.keyDown(with: event)
                }
            }
        }

        override func deleteBackward(_ sender: Any?) {
            if isEnabled {
                onDelete()
            } else {
                nextResponder?.tryToPerform(#selector(deleteBackward(_:)), with: sender)
            }
        }

        override func deleteForward(_ sender: Any?) {
            if isEnabled {
                onDelete()
            } else {
                nextResponder?.tryToPerform(#selector(deleteForward(_:)), with: sender)
            }
        }
    }
}

private struct DropTargetCleanupEventBridge: NSViewRepresentable {
    let isEnabled: Bool
    let onClear: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onClear: onClear)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.install()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onClear = onClear
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    @MainActor
    final class Coordinator {
        var isEnabled = false
        var onClear: () -> Void
        private var eventMonitor: Any?
        private var resignObserver: NSObjectProtocol?

        init(onClear: @escaping () -> Void) {
            self.onClear = onClear
        }

        func install() {
            if eventMonitor == nil {
                eventMonitor = NSEvent.addLocalMonitorForEvents(
                    matching: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .keyDown]
                ) { [weak self] event in
                    self?.clearIfNeeded()
                    return event
                }
            }
            if resignObserver == nil {
                resignObserver = NotificationCenter.default.addObserver(
                    forName: NSApplication.didResignActiveNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        self?.clearIfNeeded()
                    }
                }
            }
        }

        func uninstall() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
            if let resignObserver {
                NotificationCenter.default.removeObserver(resignObserver)
            }
            eventMonitor = nil
            resignObserver = nil
        }

        private func clearIfNeeded() {
            guard isEnabled else {
                return
            }
            onClear()
        }
    }
}
#endif

private struct PageReferenceBlockRow: View {
    let block: BlockSnapshot
    let previewText: String?
    let onOpenPageReference: (String) -> Void

    private var titleText: String {
        block.textPlain.isEmpty ? "未命名" : block.textPlain
    }

    private var normalizedPreviewText: String? {
        let trimmed = previewText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        Button {
            if let targetPageID = block.pageReferenceTargetPageID {
                onOpenPageReference(targetPageID)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let normalizedPreviewText {
                        Text(normalizedPreviewText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
        .disabled(block.pageReferenceTargetPageID == nil)
        .accessibilityLabel("页面引用：\(titleText)")
        .accessibilityValue(block.pageReferenceTargetPageID == nil ? "不可用" : "打开页面")
        .accessibilityIdentifier("editor.page-reference.\(block.id)")
    }
}

private struct BlockReferenceBlockRow: View {
    let block: BlockSnapshot
    let onOpenBlockReference: (String, String) -> Void

    private var titleText: String {
        block.textPlain.isEmpty ? "引用块" : block.textPlain
    }

    var body: some View {
        Button {
            if let targetPageID = block.pageReferenceTargetPageID,
               let targetBlockID = block.blockReferenceTargetBlockID {
                onOpenBlockReference(targetPageID, targetBlockID)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text("块")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(titleText)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .background(Color.secondary.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(block.pageReferenceTargetPageID == nil || block.blockReferenceTargetBlockID == nil)
        .accessibilityLabel("块引用：\(titleText)")
        .accessibilityValue(
            block.pageReferenceTargetPageID == nil || block.blockReferenceTargetBlockID == nil
                ? "不可用"
                : "打开引用块"
        )
        .accessibilityIdentifier("editor.block-reference.\(block.id)")
    }
}

private extension BlockType {
    var editorMenuTitle: String {
        switch self {
        case .paragraph:
            return "正文"
        case .heading1:
            return "一级标题"
        case .heading2:
            return "二级标题"
        case .heading3:
            return "三级标题"
        case .unorderedListItem:
            return "无序列表"
        case .orderedListItem:
            return "有序列表"
        case .taskItem:
            return "任务"
        case .quote:
            return "引用"
        case .codeBlock:
            return "代码"
        case .callout:
            return "提示"
        case .toggle:
            return "折叠"
        case .table:
            return "表格"
        case .divider:
            return "分割线"
        case .pageReference:
            return "页面引用"
        case .blockReference:
            return "块引用"
        case .attachmentImage:
            return "图片"
        case .attachmentVideo:
            return "视频"
        case .attachmentFile:
            return "文件"
        }
    }

    var editorMenuSystemImage: String {
        switch self {
        case .paragraph:
            return "text.alignleft"
        case .heading1:
            return "textformat.size"
        case .heading2:
            return "textformat.size"
        case .heading3:
            return "textformat.size"
        case .unorderedListItem:
            return "list.bullet"
        case .orderedListItem:
            return "list.number"
        case .taskItem:
            return "checklist"
        case .quote:
            return "quote.opening"
        case .codeBlock:
            return "chevron.left.forwardslash.chevron.right"
        case .callout:
            return "exclamationmark.bubble"
        case .toggle:
            return "chevron.right.square"
        case .table:
            return "tablecells"
        case .divider:
            return "minus"
        case .pageReference:
            return "doc.text"
        case .blockReference:
            return "text.quote"
        case .attachmentImage:
            return "photo"
        case .attachmentVideo:
            return "film"
        case .attachmentFile:
            return "doc"
        }
    }
}

private struct AttachmentBlockRow: View {
    let block: BlockSnapshot
    let attachment: AttachmentSnapshot?
    let generationStatus: AttachmentPreviewGenerationStatus
    let onRetryPreview: (String) -> Void

    var body: some View {
        let descriptor = AttachmentBlockChromeDescriptor(
            block: block,
            attachment: attachment,
            generationStatus: generationStatus
        )
        if block.type == .attachmentImage, let thumbnailImage {
            imageAttachmentBody(thumbnailImage: thumbnailImage, descriptor: descriptor)
        } else {
            compactAttachmentBody(descriptor: descriptor)
        }
    }

    private func imageAttachmentBody(
        thumbnailImage: Image,
        descriptor: AttachmentBlockChromeDescriptor
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnailImage
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 460, maxHeight: 280, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .accessibilityHidden(true)

            Text(block.textPlain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(descriptor.accessibilityIdentifier)
        .accessibilityLabel(descriptor.accessibilityLabel)
        .accessibilityValue(descriptor.accessibilityValue)
    }

    private func compactAttachmentBody(descriptor: AttachmentBlockChromeDescriptor) -> some View {
        HStack(spacing: 10) {
            if let thumbnailImage {
                thumbnailImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
            } else if isPreviewFailed {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .frame(width: 52, height: 40)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
            } else if isPreviewPending {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 52, height: 40)
                    .background(Color.white.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityLabel("正在生成附件预览")
                    .accessibilityIdentifier("editor.attachment.\(block.id).preview-pending")
            } else {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(block.textPlain)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(kindLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if isPreviewFailed, let attachment {
                Button {
                    onRetryPreview(attachment.id)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("重试预览")
                .accessibilityLabel("重试附件预览")
                .accessibilityIdentifier("editor.attachment.\(block.id).preview-retry")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(red: 0.965, green: 0.968, blue: 0.972))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityIdentifier(descriptor.accessibilityIdentifier)
        .accessibilityLabel(descriptor.accessibilityLabel)
        .accessibilityValue(descriptor.accessibilityValue)
    }

    private var thumbnailImage: Image? {
        guard case .thumbnail(let path) = previewState else {
            return nil
        }

#if os(macOS)
        guard let image = NSImage(contentsOfFile: path) else {
            return nil
        }
        return Image(nsImage: image)
#elseif os(iOS)
        guard let image = UIImage(contentsOfFile: path) else {
            return nil
        }
        return Image(uiImage: image)
#else
        return nil
#endif
    }

    private var previewState: AttachmentPreviewState {
        attachment?.previewState(for: block) ?? .unavailable
    }

    private var isPreviewPending: Bool {
        generationStatus == .generating || previewState == .pending
    }

    private var isPreviewFailed: Bool {
        if case .failed = generationStatus {
            return true
        }
        return false
    }

    private var iconName: String {
        switch block.type {
        case .attachmentImage:
            return "photo"
        case .attachmentVideo:
            return "film"
        case .attachmentFile:
            return "doc"
        default:
            return "doc.text"
        }
    }

    private var kindLabel: String {
        if isPreviewFailed {
            return "预览失败"
        }

        switch block.type {
        case .attachmentImage:
            return isPreviewPending ? "图片，正在生成预览" : "图片"
        case .attachmentVideo:
            return isPreviewPending ? "视频，正在生成预览" : "视频"
        case .attachmentFile:
            return "文件"
        default:
            return "文本"
        }
    }
}

#Preview {
    EditorShellView(
        viewModel: WorkspaceViewModel(
            snapshot: WorkspaceSnapshot(
                workspaces: [WorkspaceSummary(id: "workspace-local", name: "本地")],
                pages: [PageSummary(id: "page-welcome", workspaceID: "workspace-local", title: "欢迎")],
                blocks: [
                    BlockSnapshot(
                        id: "block-welcome-001",
                        pageID: "page-welcome",
                        parentBlockID: nil,
                        orderKey: "000001",
                        type: .paragraph,
                        textPlain: "开始用块写作。"
                    )
                ],
                attachments: [],
                selectedWorkspaceID: "workspace-local",
                selectedPageID: "page-welcome"
            )
        )
    )
}
