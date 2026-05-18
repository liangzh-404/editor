import Foundation
import Dispatch
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct EditorColorToken: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

#if os(macOS)
    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: 1)
    }
#elseif os(iOS)
    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
#endif

    static func hex(_ red: Int, _ green: Int, _ blue: Int) -> EditorColorToken {
        EditorColorToken(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255
        )
    }
}

struct EditorShadowToken: Equatable, Sendable {
    let color: EditorColorToken
    let opacity: Double
    let radius: Double
    let x: Double
    let y: Double

    var swiftUIColor: Color {
        color.color.opacity(opacity)
    }
}

enum EditorDesignTokens {
    enum Colors {
        static let appBackground = EditorColorToken.hex(0xF3, 0xF1, 0xED)
        static let sidebarBackground = EditorColorToken.hex(0xF7, 0xF4, 0xEF)
        static let editorBackground = EditorColorToken.hex(0xFF, 0xFF, 0xFF)
        static let primaryText = EditorColorToken.hex(0x24, 0x24, 0x24)
        static let secondaryText = EditorColorToken.hex(0x5A, 0x58, 0x55)
        static let tertiaryText = EditorColorToken.hex(0x76, 0x73, 0x6E)
        static let border = EditorColorToken.hex(0xE8, 0xE4, 0xDE)
        static let accent = EditorColorToken.hex(0x2F, 0x7D, 0xFA)
        static let shadow = EditorColorToken.hex(0x1E, 0x19, 0x12)
    }

    enum Typography {
        static let documentTitleSize: Double = 28
        static let bodySize: Double = 14
        static let bodyLineHeightMultiple: Double = 1.34
    }

    enum Layout {
        static let editorMaxWidth: Double = 740
        static let documentListMinWidth: Double = 280
        static let documentListIdealWidth: Double = 300
        static let documentListMaxWidth: Double = 320
        static let documentListRowMinHeight: Double = 72
        static let documentListSelectedAccentWidth: Double = 3
        static let rowCornerRadius: Double = 8
        static let specialBlockCornerRadius: Double = 12
        static let pageLinkCornerRadius: Double = 13
        static let slashMenuWidth: Double = 380
        static let slashMenuRowHeight: Double = 48
        static let slashMenuCornerRadius: Double = 14
        static let auxiliaryRailWidth: Double = 180
        static let popoverCornerRadius: Double = 16
    }

    enum Shadows {
        static let popoverLarge = EditorShadowToken(
            color: Colors.shadow,
            opacity: 0.10,
            radius: 48,
            x: 0,
            y: 16
        )
        static let popoverSmall = EditorShadowToken(
            color: Colors.shadow,
            opacity: 0.06,
            radius: 8,
            x: 0,
            y: 2
        )
    }
}

enum EditorDisplayMode: Equatable, Sendable {
    case standard
    case writing
    case focus

    var showsSidebar: Bool {
        self != .focus
    }

    var showsDocumentList: Bool {
        self == .standard
    }

    var showsAuxiliaryRail: Bool {
        self == .standard
    }

    var splitVisibility: NavigationSplitViewVisibility {
        switch self {
        case .standard:
            return .all
        case .writing:
            return .all
        case .focus:
            return .detailOnly
        }
    }
}

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
    @State private var displayMode: EditorDisplayMode = .standard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            if displayMode.showsSidebar {
                WorkspaceSidebar(viewModel: viewModel)
            } else {
                Color.clear
                    .frame(width: 0)
                    .navigationSplitViewColumnWidth(min: 0, ideal: 0, max: 0)
            }
        } content: {
            if displayMode.showsDocumentList {
                PageListView(viewModel: viewModel)
            } else {
                Color.clear
                    .frame(width: 0)
                    .navigationSplitViewColumnWidth(min: 0, ideal: 0, max: 0)
            }
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
                    canRedoTextEdit: viewModel.canRedoTextEdit,
                    displayMode: displayMode,
                    onDisplayModeChange: { mode in
                        displayMode = mode
                    },
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
                    onRedoTextEdit: {
                        viewModel.redoLastTextEditForUI()
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
                    onUpdateBlockParent: { blockID, parentBlockID in
                        viewModel.updateBlockParentForUI(blockID: blockID, parentBlockID: parentBlockID)
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
                EditorDesignTokens.Colors.editorBackground.color
                    .navigationTitle("编辑器")
            }
        }
        .onAppear {
            columnVisibility = displayMode.splitVisibility
        }
        .onChange(of: displayMode) { _, mode in
            columnVisibility = mode.splitVisibility
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
            .onChange(of: viewModel.selectedPageID) { _, _ in
                pushInitialPageIfNeeded()
            }
            .onChange(of: viewModel.snapshot.pages.map(\.id)) { _, _ in
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

        guard let pageID = CompactInitialNavigationResolver.initialPageID(
            selectedPageID: viewModel.selectedPageID,
            availablePageIDs: viewModel.snapshot.pages.map(\.id)
        ) else {
            return
        }
        didPushInitialPage = true
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
        ScrollView(.vertical, showsIndicators: false) {
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
        .background(CompactChrome.backgroundColor)
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
    static let listMarkerTopPadding: Double = 3
    static let listMarkerLineHeight: Double = 20
    static let listNestingIndentWidth: Double = 48
    static let actionColumnWidth: Double = 18
    static let actionColumnSpacing: Double = 5
    static let dragHandleWidth: Double = 18
    static let inactiveHandleOpacity: Double = 0
    static let specialBlockCornerRadius: Double = 5
    static let dropTargetHeight: Double = 32
    static let dropSlotHeight: Double = 4
    static let dropIndicatorAfterOffset: Double = 0
    static let trailingInsertHitHeight: Double = 64
}

enum ListMarkerHorizontalAlignment: Equatable, Sendable {
    case leading

    var frameAlignment: Alignment {
        switch self {
        case .leading:
            return .leading
        }
    }
}

struct ListMarkerGlyphFrameDescriptor: Equatable, Sendable {
    let width: Double
    let height: Double
    let horizontalAlignment: ListMarkerHorizontalAlignment

    init(
        width: Double = EditorBlockChrome.listMarkerWidth,
        height: Double = EditorBlockChrome.listMarkerLineHeight,
        horizontalAlignment: ListMarkerHorizontalAlignment = .leading
    ) {
        self.width = width
        self.height = height
        self.horizontalAlignment = horizontalAlignment
    }
}

struct ListMarkerBulletGlyphDescriptor: Equatable, Sendable {
    let diameter: Double
    let strokeLineWidth: Double
    let visibleLeadingOffset: Double
    let visibleTopOffset: Double

    init(
        diameter: Double = 6,
        strokeLineWidth: Double = 1.4,
        visibleLeadingOffset: Double = 0,
        visibleTopOffset: Double = 0
    ) {
        self.diameter = diameter
        self.strokeLineWidth = strokeLineWidth
        self.visibleLeadingOffset = visibleLeadingOffset
        self.visibleTopOffset = visibleTopOffset
    }
}

struct InlineLeadingControlFrameDescriptor: Equatable, Sendable {
    let width: Double
    let height: Double
    let topPadding: Double
    let textSpacing: Double
    let textVerticalOffset: Double

    init(
        width: Double = EditorBlockChrome.listMarkerWidth,
        height: Double = EditorBlockChrome.listMarkerLineHeight,
        topPadding: Double = EditorBlockChrome.listMarkerTopPadding,
        textSpacing: Double = EditorBlockChrome.listTextSpacing,
        textVerticalOffset: Double = -2
    ) {
        self.width = width
        self.height = height
        self.topPadding = topPadding
        self.textSpacing = textSpacing
        self.textVerticalOffset = textVerticalOffset
    }
}

enum ListMarkerBulletStyleResolver {
    static func isHollow(nestingLevel: Int) -> Bool {
        max(0, nestingLevel).isMultiple(of: 2) == false
    }
}

enum BlockRowNestingIndentResolver {
    static func leadingPadding(nestingLevel: Int, blockType: BlockType) -> Double {
        let level = max(0, nestingLevel)
        let width: Double
        switch blockType {
        case .unorderedListItem, .orderedListItem, .taskItem:
            width = EditorBlockChrome.listNestingIndentWidth
        default:
            width = BlockDropPlacementResolver.levelIndentWidth
        }
        return Double(level) * width
    }
}

enum BlockRowBackgroundPolicy {
    static func opacity(
        blockType: BlockType,
        isSelected: Bool,
        isFocused: Bool,
        isSlashCommandMenuVisible: Bool
    ) -> Double {
        if blockType == .table || blockType == .divider || isSlashCommandMenuVisible {
            return 0
        }
        if isSelected {
            return 0.08
        }
        if isFocused {
            return 0.32
        }
        return 0
    }
}

enum BlockRowSelectionBorderPolicy {
    static func opacity(blockType: BlockType, isSelected: Bool) -> Double {
        guard isSelected, blockType != .divider else {
            return 0
        }
        return 0.28
    }
}

enum NonEditableBlockSelectionPolicy {
    static func selectsBlockOnFocusRequest(blockType: BlockType) -> Bool {
        blockType != .divider
    }
}

enum TextEditableBlockChromePolicy {
    static func backgroundOpacity(blockType: BlockType) -> Double {
        switch blockType {
        case .taskItem, .toggle:
            return 0
        default:
            return EditorBlockChrome.listBackgroundOpacity
        }
    }
}

enum ListMarkerColumnAlignmentResolver {
    static func leadingOffset(markerWidth: Double, columnWidth: Double) -> Double {
        0
    }
}

struct DragPreviewLayoutDescriptor: Equatable, Sendable {
    let pointerHorizontalOffset: Double
    let pointerVerticalOffset: Double
    let visibleCardWidth: Double
    let visibleCardMaxHeight: Double
    let trailingInset: Double
    let bottomInset: Double
    let invisibleSpacerOpacity: Double

    init(
        pointerHorizontalOffset: Double = 380,
        pointerVerticalOffset: Double = 140,
        visibleCardWidth: Double = 284,
        visibleCardMaxHeight: Double = 64,
        trailingInset: Double = 8,
        bottomInset: Double = 8,
        invisibleSpacerOpacity: Double = 0.001
    ) {
        self.pointerHorizontalOffset = pointerHorizontalOffset
        self.pointerVerticalOffset = pointerVerticalOffset
        self.visibleCardWidth = visibleCardWidth
        self.visibleCardMaxHeight = visibleCardMaxHeight
        self.trailingInset = trailingInset
        self.bottomInset = bottomInset
        self.invisibleSpacerOpacity = invisibleSpacerOpacity
    }

    var previewWidth: Double {
        pointerHorizontalOffset + visibleCardWidth + trailingInset
    }

    var previewHeight: Double {
        pointerVerticalOffset + visibleCardMaxHeight + bottomInset
    }

    var visibleCardLeadingFromCenteredPointer: Double {
        pointerHorizontalOffset - previewWidth / 2
    }

    var visibleCardTopFromCenteredPointer: Double {
        pointerVerticalOffset - previewHeight / 2
    }
}

enum CompactChrome {
    static let backgroundRed: Double = EditorDesignTokens.Colors.appBackground.red
    static let backgroundGreen: Double = EditorDesignTokens.Colors.appBackground.green
    static let backgroundBlue: Double = EditorDesignTokens.Colors.appBackground.blue

    static var backgroundYellowBias: Double {
        max(0, ((backgroundRed + backgroundGreen) / 2) - backgroundBlue)
    }

    static var backgroundColor: Color {
        Color(red: backgroundRed, green: backgroundGreen, blue: backgroundBlue)
    }
}

enum TableBlockChrome {
    static let cellWidth: Double = 112
    static let cellHeight: Double = 28
    static let maxViewportWidth: Double = 520
    static let cornerRadius: Double = 8
    static let gridLineOpacity: Double = 0.038
    static let outerBorderOpacity: Double = 0.080
    static let primaryControlDiameter: Double = 18
    static let insertControlVisibleDiameter: Double = 4
    static let insertControlExpandedDiameter: Double = 10
    static let insertControlIconFontSize: Double = 6
    static let insertControlEdgeOffset: Double = 0
    static let insertControlIdleOpacity: Double = 0.28
    static let insertControlHoverOpacity: Double = 0.9
    static let selectorWidth: Double = 8
    static let selectorHeight: Double = 8
    static let selectorIndicatorOpacity: Double = 0
    static let selectorHitOpacity: Double = 0.0001
    static let selectorSelectedIndicatorOpacity: Double = 0.38
    static let selectorSelectedIndicatorThickness: Double = 1.5
    static let selectorSelectedIndicatorInset: Double = 10
}

enum TableBlockDefaultGridResolver {
    static let emptyGridRows = MarkdownTableDocument.defaultEmptyGridRows

    static func editableRows(text: String, rows: [[String]]) -> [[String]] {
        if !rows.isEmpty {
            return rows
        }

        let markdownRows = MarkdownTableDocument(markdown: text).rows
        if !markdownRows.isEmpty {
            return markdownRows
        }

        return MarkdownTableDocument.defaultGridRows(firstCellText: text)
    }
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

enum IOSTableBlockKeyboardActionResolver {
    static let deleteBackwardInput = "\u{8}"
    static let deleteForwardInput = "\u{7F}"
    static let escapeInput = "\u{1B}"

    static func action(
        input: String?,
        modifiers: Set<BlockKeyboardShortcutModifier>,
        hasSelection: Bool
    ) -> TableBlockKeyboardAction? {
        guard hasSelection, modifiers.isEmpty else {
            return nil
        }

        switch input {
        case deleteBackwardInput, deleteForwardInput:
            return .deleteSelection
        case escapeInput:
            return .cancelSelection
        case IOSEditorKeyboardShortcutActionResolver.upArrowInput:
            return .moveFocus(.previous)
        case IOSEditorKeyboardShortcutActionResolver.downArrowInput:
            return .moveFocus(.next)
        default:
            return nil
        }
    }
}

enum IOSEditorKeyboardShortcutBridgeActivationResolver {
    static func capturesPaste(
        hasFocusedTextBlock: Bool,
        hasCurrentPage: Bool
    ) -> Bool {
        !hasFocusedTextBlock && hasCurrentPage
    }

    static func capturesFocusMove(hasBlockSelection: Bool) -> Bool {
        hasBlockSelection
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

enum BlockSelectionRangeResolver {
    static func selection(
        anchorBlockID: String,
        targetBlockID: String,
        visibleBlockIDs: [String]
    ) -> [String] {
        guard let anchorIndex = visibleBlockIDs.firstIndex(of: anchorBlockID),
              let targetIndex = visibleBlockIDs.firstIndex(of: targetBlockID) else {
            return []
        }

        let lowerBound = min(anchorIndex, targetIndex)
        let upperBound = max(anchorIndex, targetIndex)
        return Array(visibleBlockIDs[lowerBound...upperBound])
    }

    static func selectionAfterExtending(
        from blockID: String,
        direction: BlockKeyboardFocusDirection,
        currentSelection: Set<String>,
        visibleBlockIDs: [String]
    ) -> [String] {
        let orderedSelection = visibleBlockIDs.filter { currentSelection.contains($0) }
        guard !orderedSelection.isEmpty else {
            guard let currentIndex = visibleBlockIDs.firstIndex(of: blockID) else {
                return []
            }

            let targetIndex: Int
            switch direction {
            case .previous:
                targetIndex = currentIndex - 1
            case .next:
                targetIndex = currentIndex + 1
            }
            guard visibleBlockIDs.indices.contains(targetIndex) else {
                return []
            }
            return selection(
                anchorBlockID: blockID,
                targetBlockID: visibleBlockIDs[targetIndex],
                visibleBlockIDs: visibleBlockIDs
            )
        }

        guard let lowerIndex = visibleBlockIDs.firstIndex(of: orderedSelection[0]),
              let upperIndex = visibleBlockIDs.firstIndex(of: orderedSelection[orderedSelection.count - 1]) else {
            return orderedSelection
        }

        switch direction {
        case .previous:
            let nextLowerIndex = lowerIndex - 1
            guard visibleBlockIDs.indices.contains(nextLowerIndex) else {
                return orderedSelection
            }
            return Array(visibleBlockIDs[nextLowerIndex...upperIndex])
        case .next:
            let nextUpperIndex = upperIndex + 1
            guard visibleBlockIDs.indices.contains(nextUpperIndex) else {
                return orderedSelection
            }
            return Array(visibleBlockIDs[lowerIndex...nextUpperIndex])
        }
    }
}

enum BlockSelectionMarqueeChrome {
    static let fillOpacity: Double = 0.10
    static let strokeOpacity: Double = 0.42
    static let strokeWidth: Double = 1
    static let cornerRadius: Double = 4
    static let minimumVisibleDimension: Double = 2
}

enum BlockSelectionMarqueeRectResolver {
    static func rect(start: CGPoint, current: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    static func isVisible(_ rect: CGRect) -> Bool {
        rect.width >= BlockSelectionMarqueeChrome.minimumVisibleDimension
            && rect.height >= BlockSelectionMarqueeChrome.minimumVisibleDimension
    }
}

enum BlockSelectionMarqueeSelectionResolver {
    static func selectedBlockIDs(
        selectionRect: CGRect,
        blockFrames: [String: CGRect],
        visibleBlockIDs: [String]
    ) -> [String] {
        guard BlockSelectionMarqueeRectResolver.isVisible(selectionRect) else {
            return []
        }

        return visibleBlockIDs.filter { blockID in
            guard let frame = blockFrames[blockID] else {
                return false
            }
            return selectionRect.intersects(frame)
        }
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

enum MobileBlockRowSwipeGestureAttachment: Equatable, Sendable {
    case nativeTextEditorOnly
    case rowHighPriority
}

enum MobileBlockRowSwipeGestureAttachmentResolver {
    static func attachment(usesNativeTextEditor: Bool) -> MobileBlockRowSwipeGestureAttachment {
        usesNativeTextEditor ? .nativeTextEditorOnly : .rowHighPriority
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

enum MobileBlockSelectionBatchResolver {
    static func orderedBlockIDs(
        selectedBlockIDs: Set<String>,
        visibleBlockIDs: [String]
    ) -> [String] {
        visibleBlockIDs.filter { selectedBlockIDs.contains($0) }
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
    let onOutdent: () -> Void
    let onIndent: () -> Void
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

            Button(action: onOutdent) {
                Image(systemName: "decrease.indent")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("减少缩进")
            .accessibilityIdentifier("editor.mobile-selection-outdent")

            Button(action: onIndent) {
                Image(systemName: "increase.indent")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("增加缩进")
            .accessibilityIdentifier("editor.mobile-selection-indent")

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
    static func selectionAfterExternalInteraction(_ selection: TableSelection) -> TableSelection {
        selection.isEmpty ? selection : .empty
    }

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
    case outdentAfter
}

struct BlockDropTarget: Equatable, Sendable {
    let blockID: String
    let placement: BlockDropPlacement
    let targetLevel: Int?

    init(blockID: String, placement: BlockDropPlacement, targetLevel: Int? = nil) {
        self.blockID = blockID
        self.placement = placement
        self.targetLevel = targetLevel
    }
}

enum BlockDropTargetLifecycleReducer {
    static func targetAfterEditorInteraction(current: BlockDropTarget?) -> BlockDropTarget? {
        nil
    }

    static func targetAfterDragEnded(current: BlockDropTarget?) -> BlockDropTarget? {
        nil
    }
}

struct TransientSelectionResetRequest: Equatable, Sendable {
    let id: UUID
    let excludingBlockID: String?

    static let none = TransientSelectionResetRequest(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, excludingBlockID: nil)

    init(id: UUID = UUID(), excludingBlockID: String? = nil) {
        self.id = id
        self.excludingBlockID = excludingBlockID
    }
}

enum BlockDropPlacementResolver {
    static let rootLevelAnchorX: CGFloat = 48
    static let levelIndentWidth: CGFloat = 24
    static let childActivationOffset: CGFloat = 36
    static let beforeBandHeight: CGFloat = 10

    static func resolution(
        location: CGPoint,
        rowSize: CGSize,
        destinationLevel: Int = 0
    ) -> BlockDropPlacementResolution {
        let clampedDestinationLevel = max(0, destinationLevel)
        let topBandHeight = min(beforeBandHeight, max(rowSize.height * 0.35, 8))
        if location.y <= topBandHeight {
            return BlockDropPlacementResolution(placement: .before, targetLevel: clampedDestinationLevel)
        }

        return afterResolution(locationX: location.x, destinationLevel: clampedDestinationLevel)
    }

    static func placement(
        location: CGPoint,
        rowSize: CGSize,
        destinationLevel: Int = 0
    ) -> BlockDropPlacement {
        resolution(location: location, rowSize: rowSize, destinationLevel: destinationLevel).placement
    }

    static func afterResolution(
        locationX: CGFloat,
        destinationLevel: Int
    ) -> BlockDropPlacementResolution {
        let clampedDestinationLevel = max(0, destinationLevel)
        let sameLevelAnchor = rootLevelAnchorX + CGFloat(clampedDestinationLevel) * levelIndentWidth

        let targetLevel: Int
        if locationX >= sameLevelAnchor + childActivationOffset {
            targetLevel = clampedDestinationLevel + 1
        } else {
            let rawLevel = Int(round((locationX - rootLevelAnchorX) / levelIndentWidth))
            targetLevel = min(max(rawLevel, 0), clampedDestinationLevel)
        }

        let placement: BlockDropPlacement
        if targetLevel > clampedDestinationLevel {
            placement = .childAfter
        } else if targetLevel < clampedDestinationLevel {
            placement = .outdentAfter
        } else {
            placement = .after
        }
        return BlockDropPlacementResolution(placement: placement, targetLevel: targetLevel)
    }
}

struct BlockDropPlacementResolution: Equatable, Sendable {
    let placement: BlockDropPlacement
    let targetLevel: Int?
}

enum BlockDropParentResolver {
    static func parentBlockIDForEndDrop() -> String? {
        nil
    }

    static func parentBlockID(
        destinationBlockID: String,
        targetLevel: Int,
        blocks: [BlockSnapshot]
    ) -> String? {
        guard targetLevel > 0 else {
            return nil
        }

        let destinationChain = ancestorChainIncludingDestination(
            destinationBlockID: destinationBlockID,
            blocks: blocks
        )
        guard destinationChain.indices.contains(targetLevel - 1) else {
            return destinationBlockID
        }
        return destinationChain[targetLevel - 1].id
    }

    private static func ancestorChainIncludingDestination(
        destinationBlockID: String,
        blocks: [BlockSnapshot]
    ) -> [BlockSnapshot] {
        let blocksByID = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })
        guard var block = blocksByID[destinationBlockID] else {
            return []
        }

        var chain: [BlockSnapshot] = [block]
        var visitedBlockIDs: Set<String> = [block.id]
        while let parentBlockID = block.parentBlockID,
              !visitedBlockIDs.contains(parentBlockID),
              let parent = blocksByID[parentBlockID] {
            chain.insert(parent, at: 0)
            visitedBlockIDs.insert(parentBlockID)
            block = parent
        }
        return chain
    }
}

enum SlashCommandSelectionSource: Equatable, Sendable {
    case keyboard
    case hover
}

enum SlashCommandMenuScrollPolicy {
    static func shouldScrollSelectionIntoView(source: SlashCommandSelectionSource) -> Bool {
        source == .keyboard
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
        CompactPageNavigationResolver.initialPageID(
            selectedPageID: selectedPageID,
            availablePageIDs: availablePageIDs
        )
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
                canRedoTextEdit: viewModel.canRedoTextEdit,
                showsAuxiliaryRail: false,
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
                onRedoTextEdit: {
                    viewModel.redoLastTextEditForUI()
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
                onUpdateBlockParent: { blockID, parentBlockID in
                    viewModel.updateBlockParentForUI(blockID: blockID, parentBlockID: parentBlockID)
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
    static let sectionSpacing: Double = 6
    static let rowSpacing: Double = 1
    static let rowCornerRadius: Double = 12
    static let rowVerticalPadding: Double = 6
    static let nestedItemIndent: Double = 12
    static let dividerOpacity: Double = 0.07
    static let selectedFillOpacity: Double = 0.70
    static let selectedStrokeOpacity: Double = 0.025
    static let headerBadgeSize: Double = 30
    static let headerBadgeCornerRadius: Double = 8
    static let backgroundRed: Double = EditorDesignTokens.Colors.sidebarBackground.red
    static let backgroundGreen: Double = EditorDesignTokens.Colors.sidebarBackground.green
    static let backgroundBlue: Double = EditorDesignTokens.Colors.sidebarBackground.blue
    static let selectedFillRed: Double = EditorDesignTokens.Colors.border.red
    static let selectedFillGreen: Double = EditorDesignTokens.Colors.border.green
    static let selectedFillBlue: Double = EditorDesignTokens.Colors.border.blue

    static var backgroundYellowBias: Double {
        max(0, ((backgroundRed + backgroundGreen) / 2) - backgroundBlue)
    }

    static var selectedFillYellowBias: Double {
        max(0, ((selectedFillRed + selectedFillGreen) / 2) - selectedFillBlue)
    }

    static var backgroundColor: Color {
        Color(red: backgroundRed, green: backgroundGreen, blue: backgroundBlue)
    }

    static var selectedFillColor: Color {
        Color(red: selectedFillRed, green: selectedFillGreen, blue: selectedFillBlue)
    }

    static var selectedForegroundColor: Color {
        EditorDesignTokens.Colors.primaryText.color
    }

    static var foregroundColor: Color {
        EditorDesignTokens.Colors.secondaryText.color
    }

    static var mutedForegroundColor: Color {
        EditorDesignTokens.Colors.tertiaryText.color
    }
}

private struct WorkspaceSidebar: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @AppStorage("editor.sidebar.favorites.expanded") private var isFavoritesExpanded = true
    @AppStorage("editor.sidebar.tags.expanded") private var isTagsExpanded = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: CGFloat(SidebarChrome.sectionSpacing)) {
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
                SidebarDisclosureHeader(
                    title: "收藏",
                    count: viewModel.snapshot.favoritePages.count,
                    isExpanded: isFavoritesExpanded
                ) {
                    isFavoritesExpanded.toggle()
                }

                if isFavoritesExpanded {
                    ForEach(viewModel.snapshot.favoritePages) { page in
                        Button {
                            viewModel.selectPage(id: page.id)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.caption.weight(.semibold))
                                    .frame(width: 16)
                                    .foregroundStyle(Color(red: 0.74, green: 0.62, blue: 0.30))
                                Text(page.title)
                                    .font(.callout)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.leading, 18)
                            .padding(.trailing, 10)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(SidebarChrome.foregroundColor)
                        .accessibilityIdentifier("editor.favorite-page.\(page.id)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tagGroup: some View {
        if !sidebarModel.tagItems.isEmpty {
            VStack(alignment: .leading, spacing: CGFloat(SidebarChrome.rowSpacing)) {
                SidebarDisclosureHeader(
                    title: "标签",
                    count: sidebarModel.tagItems.count,
                    isExpanded: isTagsExpanded
                ) {
                    isTagsExpanded.toggle()
                }

                if isTagsExpanded {
                    ForEach(sidebarModel.tagItems) { item in
                        CollectionRailButton(item: item) {
                            viewModel.selectCollection(item.collection)
                        }
                        .padding(.leading, CGFloat(SidebarChrome.nestedItemIndent))
                    }
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

private struct SidebarDisclosureHeader: View {
    let title: String
    let count: Int
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .frame(width: 12)
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 4)
                Text("\(count)")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
            }
            .foregroundStyle(SidebarChrome.mutedForegroundColor.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)，\(isExpanded ? "已展开" : "已收起")")
    }
}

private struct CollectionRailButton: View {
    let item: SidebarNavigationItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: item.systemImage)
                    .font(.callout.weight(.medium))
                    .frame(width: 20)
                    .foregroundStyle(item.isSelected ? SidebarChrome.selectedForegroundColor : SidebarChrome.mutedForegroundColor)
                Text(item.title)
                    .font(item.isSelected ? .callout.weight(.semibold) : .callout.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 6)
                if item.showsCount {
                    Text("\(item.count)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(item.isSelected ? SidebarChrome.selectedForegroundColor.opacity(0.80) : SidebarChrome.mutedForegroundColor)
                        .monospacedDigit()
                }
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, CGFloat(SidebarChrome.rowVerticalPadding))
                .background(
                    RoundedRectangle(cornerRadius: CGFloat(SidebarChrome.rowCornerRadius), style: .continuous)
                        .fill(item.isSelected ? SidebarChrome.selectedFillColor.opacity(SidebarChrome.selectedFillOpacity) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CGFloat(SidebarChrome.rowCornerRadius), style: .continuous)
                        .stroke(
                            item.isSelected
                                ? EditorDesignTokens.Colors.border.color.opacity(SidebarChrome.selectedStrokeOpacity)
                                : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(item.isSelected ? SidebarChrome.selectedForegroundColor : SidebarChrome.foregroundColor)
        .accessibilityIdentifier(item.identifier)
        .accessibilityValue(item.isSelected ? "已选中，\(item.count)" : "未选中，\(item.count)")
    }
}

private struct PageListView: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
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
        .navigationSplitViewColumnWidth(
            min: CGFloat(EditorDesignTokens.Layout.documentListMinWidth),
            ideal: CGFloat(EditorDesignTokens.Layout.documentListIdealWidth),
            max: CGFloat(EditorDesignTokens.Layout.documentListMaxWidth)
        )
        .background(EditorDesignTokens.Colors.appBackground.color)
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
        .background(EditorDesignTokens.Colors.editorBackground.color)
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
        ScrollView(.vertical, showsIndicators: false) {
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
        .background(CompactChrome.backgroundColor)
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
                .fill(isSelected ? EditorDesignTokens.Colors.accent.color.opacity(0.72) : Color.clear)
                .frame(width: CGFloat(EditorDesignTokens.Layout.documentListSelectedAccentWidth))
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
            .padding(.vertical, 10)
        }
        .frame(minHeight: CGFloat(EditorDesignTokens.Layout.documentListRowMinHeight), alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? EditorDesignTokens.Colors.border.color.opacity(0.52) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? EditorDesignTokens.Colors.border.color.opacity(0.36) : Color.clear, lineWidth: 1)
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
                    .foregroundStyle(EditorDesignTokens.Colors.secondaryText.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(EditorDesignTokens.Colors.border.color.opacity(0.42))
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

private enum EditorCanvasCoordinateSpace {
    static let blockSelection = "editor.canvas.block-selection"
}

private struct BlockRowFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private struct BlockSelectionMarqueeOverlay: View {
    let rect: CGRect

    var body: some View {
        RoundedRectangle(
            cornerRadius: CGFloat(BlockSelectionMarqueeChrome.cornerRadius),
            style: .continuous
        )
        .fill(EditorDesignTokens.Colors.accent.color.opacity(BlockSelectionMarqueeChrome.fillOpacity))
        .overlay(
            RoundedRectangle(
                cornerRadius: CGFloat(BlockSelectionMarqueeChrome.cornerRadius),
                style: .continuous
            )
            .stroke(
                EditorDesignTokens.Colors.accent.color.opacity(BlockSelectionMarqueeChrome.strokeOpacity),
                lineWidth: CGFloat(BlockSelectionMarqueeChrome.strokeWidth)
            )
        )
        .frame(width: max(1, rect.width), height: max(1, rect.height))
        .offset(x: rect.minX, y: rect.minY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
    let canRedoTextEdit: Bool
    var displayMode: EditorDisplayMode = .standard
    var showsAuxiliaryRail = true
    var onDisplayModeChange: (EditorDisplayMode) -> Void = { _ in }
    let onAddParagraphBlock: () -> String?
    let onAddPageReference: (String) -> Void
    let onAddBlockReference: (String) -> Void
    let onInsertMarkdownLink: (String, String, String) -> Bool
    let onInsertMarkdownLinkAtSelection: (String, String, String, EditorTextSelection) -> EditorTextSelection?
    let onRemoveMarkdownLinkAtSelection: (String, EditorTextSelection) -> EditorTextSelection?
    let onApplyMarkdownInlineFormat: (String, MarkdownInlineFormat, EditorTextSelection) -> EditorTextSelection?
    let onUndoTextEdit: () -> Void
    let onRedoTextEdit: () -> Void
    let onFocusCanvas: () -> String?
    let onMoveBlock: (String, Int) -> Void
    let onMoveBlocks: ([String], Int) -> Void
    let onUpdateBlockParent: (String, String?) -> Bool
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
    @State private var transientSelectionResetRequest = TransientSelectionResetRequest.none
    @State private var scrollMetricsTracker = EditorCanvasScrollMetricsTracker(pageID: nil, blockCount: 0)
    @State private var isAuxiliaryRailCollapsed = true
    @State private var blockRowFrames: [String: CGRect] = [:]
    @State private var blockSelectionMarqueeStart: CGPoint?
    @State private var blockSelectionMarqueeCurrent: CGPoint?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: CGFloat(EditorBlockChrome.blockSpacing)) {
                HStack(alignment: .center, spacing: 12) {
                    TextField("未命名", text: pageTitleBinding)
                        .textFieldStyle(.plain)
                        .font(.system(size: EditorDesignTokens.Typography.documentTitleSize, weight: .semibold))
                        .foregroundStyle(EditorDesignTokens.Colors.primaryText.color)
                        .padding(.leading, CGFloat(EditorBlockChrome.actionColumnWidth + EditorBlockChrome.actionColumnSpacing + 4))
                        .disabled(page == nil)
                        .accessibilityIdentifier("editor.page-title")
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                clearTransientSelections()
                            }
                        )

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
                                .foregroundStyle(EditorDesignTokens.Colors.secondaryText.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(EditorDesignTokens.Colors.border.color.opacity(0.42))
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
                            destinationLevel: nestingLevel(for: block),
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
                        onExtendBlockSelectionByKeyboard: { direction in
                            extendBlockSelection(from: block.id, direction: direction)
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
                            applyBlockIndentation(.indent, fallbackBlockID: block.id)
                        },
                        onOutdent: {
                            applyBlockIndentation(.outdent, fallbackBlockID: block.id)
                        },
                        onPasteAttachmentURLs: { urls in
                            guard !urls.isEmpty else {
                                return false
                            }
                            return onImportAttachmentsAfterBlock(urls, block.id)
                        },
                        onDelete: {
                            deleteBlockForCommand(fallbackBlockID: block.id)
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
                        selectionResetRequest: transientSelectionResetRequest,
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
                        onClearTransientSelections: { excludingBlockID in
                            clearTransientSelections(excludingBlockID: excludingBlockID)
                        },
                        onTableRowsChange: { rows in
                            onTableRowsChange(block.id, rows)
                        }
                    ) { text in
                        onBlockTextChange(block.id, text)
                    }
                    .background(blockSelectionFrameReporter(block.id))
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
                        destinationLevel: nestingLevel(for: block),
                        moveDroppedBlocks: moveDroppedBlocks
                    )
                }

                if !blocks.isEmpty {
                    CanvasTrailingInsertRegion {
                        focusCanvas()
                    }
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
                        activeBlockDropTarget = BlockDropTargetLifecycleReducer
                            .targetAfterDragEnded(current: activeBlockDropTarget)
                        return moveDroppedBlocksToEnd(draggedBlockIDs)
                    }
                    .accessibilityIdentifier("editor.canvas-edit-region")
            }
            .frame(maxWidth: CGFloat(EditorDesignTokens.Layout.editorMaxWidth), alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.vertical, 36)
            }
            .accessibilityIdentifier("editor.canvas-scroll")
            .coordinateSpace(name: EditorCanvasCoordinateSpace.blockSelection)
            .onPreferenceChange(BlockRowFramePreferenceKey.self) { frames in
                blockRowFrames = frames
            }
            .overlay(alignment: .topLeading) {
                if let blockSelectionMarqueeRect {
                    BlockSelectionMarqueeOverlay(rect: blockSelectionMarqueeRect)
                }
            }
            .simultaneousGesture(blockSelectionMarqueeGesture())
            .onChange(of: editorSession.focusedBlockID) { _, _ in
                activeBlockDropTarget = BlockDropTargetLifecycleReducer
                    .targetAfterEditorInteraction(current: activeBlockDropTarget)
            }
#if DEBUG
            .overlay(alignment: .topLeading) {
                scrollMetricsDebugProbe
            }
#endif

            if shouldOfferAuxiliaryRail {
                if isAuxiliaryRailCollapsed {
                    auxiliaryRailExpandButton
                        .padding(.top, 18)
                        .padding(.trailing, 10)
                } else {
                    EditorAuxiliaryRail(
                        outlineItems: outlineItems,
                        backlinks: backlinks,
                        externalLinks: externalLinks,
                        onSelectOutlineItem: onSelectOutlineItem,
                        onSelectBacklink: onSelectBacklink,
                        onCollapse: {
                            isAuxiliaryRailCollapsed = true
                        }
                    )
                    .frame(width: CGFloat(EditorDesignTokens.Layout.auxiliaryRailWidth), alignment: .topLeading)
                    .padding(.top, 18)
                    .padding(.trailing, 10)
                    .accessibilityIdentifier("editor.auxiliary-rail")
                }
            }
        }
        .background(EditorDesignTokens.Colors.editorBackground.color)
#if os(iOS)
        .safeAreaInset(edge: .bottom) {
            if !editorSession.selectedBlockIDs.isEmpty {
                MobileBlockSelectionToolbar(
                    selectedCount: editorSession.selectedBlockIDs.count,
                    onClear: {
                        editorSession.clearBlockSelection()
                    },
                    onOutdent: {
                        applySelectedBlocksIndentation(.outdent)
                    },
                    onIndent: {
                        applySelectedBlocksIndentation(.indent)
                    },
                    onDelete: {
                        deleteSelectedBlocks()
                    }
                )
            }
        }
#endif
#if os(macOS)
        .background(
            DropTargetCleanupEventBridge(isEnabled: activeBlockDropTarget != nil) {
                activeBlockDropTarget = BlockDropTargetLifecycleReducer
                    .targetAfterDragEnded(current: activeBlockDropTarget)
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
                },
                onExtendBlockSelection: { direction in
                    guard let blockID = BlockSelectionKeyboardAnchorResolver.anchorBlockID(
                        selectedBlockIDs: editorSession.selectedBlockIDs,
                        visibleBlockIDs: blocks.map(\.id)
                    ) else {
                        return false
                    }

                    return extendBlockSelection(from: blockID, direction: direction)
                },
                onIndentSelection: { direction in
                    applySelectedBlocksIndentation(direction)
                },
                onDeleteSelection: {
                    deleteSelectedBlocks()
                },
                onUndoEdit: {
                    guard canUndoTextEdit else {
                        return false
                    }
                    onUndoTextEdit()
                    return true
                },
                onRedoEdit: {
                    guard canRedoTextEdit else {
                        return false
                    }
                    onRedoTextEdit()
                    return true
                },
                onSelectFocusedCodeText: { textView in
                    let identifier = textView.accessibilityIdentifier()
                    guard identifier.hasPrefix("editor.text.") else {
                        return false
                    }

                    let blockID = String(identifier.dropFirst("editor.text.".count))
                    guard let block = blocks.first(where: { $0.id == blockID }),
                          block.type == .codeBlock else {
                        return false
                    }

                    let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
                    textView.setSelectedRange(fullRange)
                    editorSession.updateSelection(
                        blockID: blockID,
                        location: fullRange.location,
                        length: fullRange.length
                    )
                    editorSession.clearBlockSelection()
                    return true
                },
                onPromoteBlockToPage: {
                    promoteCurrentBlockToPageFromKeyboard()
                }
            )
        )
#elseif os(iOS)
        .background(
            IOSEditorKeyboardShortcutBridge(
                isPasteEnabled: IOSEditorKeyboardShortcutBridgeActivationResolver.capturesPaste(
                    hasFocusedTextBlock: editorSession.focusedBlockID != nil,
                    hasCurrentPage: page != nil
                ),
                isFocusMoveEnabled: IOSEditorKeyboardShortcutBridgeActivationResolver.capturesFocusMove(
                    hasBlockSelection: !editorSession.selectedBlockIDs.isEmpty
                ),
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

    private var shouldShowAuxiliaryRail: Bool {
        showsAuxiliaryRail
            && displayMode.showsAuxiliaryRail
            && (!outlineItems.isEmpty || !backlinks.isEmpty || !externalLinks.isEmpty)
    }

    private var shouldOfferAuxiliaryRail: Bool {
        shouldShowAuxiliaryRail
    }

    private var auxiliaryRailExpandButton: some View {
        Button {
            isAuxiliaryRailCollapsed = false
        } label: {
            Image(systemName: "sidebar.right")
                .font(.callout)
                .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("展开右侧栏")
        .accessibilityLabel("展开右侧栏")
        .accessibilityIdentifier("editor.auxiliary-rail.expand")
    }

    private var pageActionsMenu: some View {
        Menu {
            Section("视图") {
                Button {
                    onDisplayModeChange(displayMode == .writing ? .standard : .writing)
                } label: {
                    Label(displayMode == .writing ? "退出写作模式" : "写作模式", systemImage: "sidebar.trailing")
                }

                Button {
                    onDisplayModeChange(displayMode == .focus ? .standard : .focus)
                } label: {
                    Label(displayMode == .focus ? "退出专注模式" : "专注模式", systemImage: "rectangle.center.inset.filled")
                }
            }

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
                    onRedoTextEdit()
                } label: {
                    Label("重做编辑", systemImage: "arrow.uturn.forward")
                }
                .disabled(!canRedoTextEdit)

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

    private func promoteCurrentBlockToPageFromKeyboard() -> Bool {
        guard let promoteCurrentBlockToPageAction else {
            return false
        }

        promoteCurrentBlockToPageAction()
        return true
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
        clearTransientSelections()
        guard let blockID = onFocusCanvas() else {
            return
        }

        pendingFocusRequest = BlockFocusRequest(blockID: blockID)
    }

    private func clearTransientSelections(excludingBlockID: String? = nil) {
        editorSession.clearBlockSelection()
        activeBlockDropTarget = BlockDropTargetLifecycleReducer
            .targetAfterEditorInteraction(current: activeBlockDropTarget)
        transientSelectionResetRequest = TransientSelectionResetRequest(excludingBlockID: excludingBlockID)
    }

    @discardableResult
    private func extendBlockSelection(
        from blockID: String,
        direction: BlockKeyboardFocusDirection
    ) -> Bool {
        let blockIDs = BlockSelectionRangeResolver.selectionAfterExtending(
            from: blockID,
            direction: direction,
            currentSelection: editorSession.selectedBlockIDs,
            visibleBlockIDs: blocks.map(\.id)
        )
        guard !blockIDs.isEmpty else {
            return false
        }

        editorSession.selectBlocks(Set(blockIDs))
        return true
    }

    @discardableResult
    private func applySelectedBlocksIndentation(_ direction: BlockKeyboardIndentationDirection) -> Bool {
        let blockIDs = MobileBlockSelectionBatchResolver.orderedBlockIDs(
            selectedBlockIDs: editorSession.selectedBlockIDs,
            visibleBlockIDs: blocks.map(\.id)
        )
        guard !blockIDs.isEmpty else {
            return false
        }

        var didChange = false
        for blockID in blockIDs {
            switch direction {
            case .indent:
                didChange = onIndentBlock(blockID) || didChange
            case .outdent:
                didChange = onOutdentBlock(blockID) || didChange
            }
        }

        if didChange {
            editorSession.selectBlocks(Set(blockIDs))
        }
        return didChange
    }

    @discardableResult
    private func applyBlockIndentation(
        _ direction: BlockKeyboardIndentationDirection,
        fallbackBlockID: String
    ) -> Bool {
        if editorSession.selectedBlockIDs.contains(fallbackBlockID),
           applySelectedBlocksIndentation(direction) {
            return true
        }

        switch direction {
        case .indent:
            return onIndentBlock(fallbackBlockID)
        case .outdent:
            return onOutdentBlock(fallbackBlockID)
        }
    }

    @discardableResult
    private func deleteSelectedBlocks() -> Bool {
        let blockIDs = MobileBlockSelectionBatchResolver.orderedBlockIDs(
            selectedBlockIDs: editorSession.selectedBlockIDs,
            visibleBlockIDs: blocks.map(\.id)
        )
        guard !blockIDs.isEmpty else {
            return false
        }

        if onDeleteBlocks(blockIDs) {
            editorSession.clearBlockSelection()
            return true
        }
        return false
    }

    private func deleteBlockForCommand(fallbackBlockID: String) {
        if editorSession.selectedBlockIDs.contains(fallbackBlockID),
           deleteSelectedBlocks() {
            return
        }

        onDeleteBlock(fallbackBlockID)
    }

    private func blockSelectionFrameReporter(_ blockID: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: BlockRowFramePreferenceKey.self,
                value: [blockID: proxy.frame(in: .named(EditorCanvasCoordinateSpace.blockSelection))]
            )
        }
    }

    private var blockSelectionMarqueeRect: CGRect? {
        guard let blockSelectionMarqueeStart,
              let blockSelectionMarqueeCurrent else {
            return nil
        }

        let rect = BlockSelectionMarqueeRectResolver.rect(
            start: blockSelectionMarqueeStart,
            current: blockSelectionMarqueeCurrent
        )
        guard BlockSelectionMarqueeRectResolver.isVisible(rect) else {
            return nil
        }
        return rect
    }

    private func blockSelectionMarqueeGesture() -> some Gesture {
        DragGesture(
            minimumDistance: 2,
            coordinateSpace: .named(EditorCanvasCoordinateSpace.blockSelection)
        )
        .onChanged { value in
            guard isBlockSelectionMarqueeDragStart(value.startLocation) else {
                return
            }

            if blockSelectionMarqueeStart == nil {
                blockSelectionMarqueeStart = value.startLocation
            }
            blockSelectionMarqueeCurrent = value.location

            let selectionRect = BlockSelectionMarqueeRectResolver.rect(
                start: value.startLocation,
                current: value.location
            )
            let blockIDs = BlockSelectionMarqueeSelectionResolver.selectedBlockIDs(
                selectionRect: selectionRect,
                blockFrames: blockRowFrames,
                visibleBlockIDs: blocks.map(\.id)
            )

            editorSession.selectBlocks(Set(blockIDs))
        }
        .onEnded { _ in
            blockSelectionMarqueeStart = nil
            blockSelectionMarqueeCurrent = nil
        }
    }

    private func isBlockSelectionMarqueeDragStart(_ location: CGPoint) -> Bool {
        !blockRowFrames.contains { _, frame in
            let handleFrame = CGRect(
                x: frame.minX,
                y: frame.minY,
                width: CGFloat(EditorBlockChrome.actionColumnWidth),
                height: frame.height
            )
            return handleFrame.contains(location)
        }
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
        placement: BlockDropPlacement,
        targetLevel: Int?
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

        let parentBlockID: String?
        if let targetLevel {
            parentBlockID = BlockDropParentResolver.parentBlockID(
                destinationBlockID: destinationBlockID,
                targetLevel: targetLevel,
                blocks: blocks
            )
        } else {
            parentBlockID = nil
        }

        onMoveBlocks(movedBlockIDs, targetIndex)
        if targetLevel != nil {
            _ = onUpdateBlockParent(draggedBlockID, parentBlockID)
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
        _ = onUpdateBlockParent(draggedBlockID, BlockDropParentResolver.parentBlockIDForEndDrop())
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
    case deleteSelection
    case indentSelection(BlockKeyboardIndentationDirection)
    case extendBlockSelection(BlockKeyboardFocusDirection)
    case undoEdit
    case redoEdit
    case selectFocusedCodeText
    case insertLink
    case pasteAttachments
    case moveFocus(BlockKeyboardFocusDirection)
    case promoteBlockToPage
}

enum MacEditorKeyboardShortcutActionResolver {
    private static let deleteKeyCodes: Set<UInt16> = [51, 117]

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

        if hasBlockSelection,
           deleteKeyCodes.contains(keyCode),
           modifiers.isEmpty {
            return .deleteSelection
        }

        if hasBlockSelection,
           let direction = BlockKeyboardShortcutResolver.indentationDirection(
            keyCode: keyCode,
            modifiers: modifiers
           ) {
            return .indentSelection(direction)
        }

        if hasBlockSelection,
           let direction = BlockKeyboardSelectionExtensionResolver.direction(
            keyCode: keyCode,
            modifiers: modifiers
           ) {
            return .extendBlockSelection(direction)
        }

        if hasBlockSelection,
           let direction = NonEditableBlockKeyboardFocusResolver.focusDirection(
            keyCode: keyCode,
            modifiers: modifiers
           ) {
            return .moveFocus(direction)
        }

        if input?.lowercased() == "z",
           modifiers == [.command] {
            return .undoEdit
        }

        if input?.lowercased() == "z",
           modifiers == [.command, .shift] {
            return .redoEdit
        }

        if BlockSelectAllKeyboardResolver.requestsSelectAll(
            input: input,
            modifiers: modifiers
        ) {
            return .selectFocusedCodeText
        }

        if MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(
            input: input,
            modifiers: modifiers
        ) {
            return .insertLink
        }

        if DiaryPromotionKeyboardResolver.requestsPromotion(
            input: input,
            modifiers: modifiers
        ) {
            return .promoteBlockToPage
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
    let onMoveFocus: (BlockKeyboardFocusDirection) -> Bool
    let onExtendBlockSelection: (BlockKeyboardFocusDirection) -> Bool
    let onIndentSelection: (BlockKeyboardIndentationDirection) -> Bool
    let onDeleteSelection: () -> Bool
    let onUndoEdit: () -> Bool
    let onRedoEdit: () -> Bool
    let onSelectFocusedCodeText: (NSTextView) -> Bool
    let onPromoteBlockToPage: () -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.onInsertLink = onInsertLink
        context.coordinator.onPasteAttachments = onPasteAttachments
        context.coordinator.hasBlockSelection = hasBlockSelection
        context.coordinator.onCancelSelection = onCancelSelection
        context.coordinator.onMoveFocus = onMoveFocus
        context.coordinator.onExtendBlockSelection = onExtendBlockSelection
        context.coordinator.onIndentSelection = onIndentSelection
        context.coordinator.onDeleteSelection = onDeleteSelection
        context.coordinator.onUndoEdit = onUndoEdit
        context.coordinator.onRedoEdit = onRedoEdit
        context.coordinator.onSelectFocusedCodeText = onSelectFocusedCodeText
        context.coordinator.onPromoteBlockToPage = onPromoteBlockToPage
        context.coordinator.install()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onInsertLink = onInsertLink
        context.coordinator.onPasteAttachments = onPasteAttachments
        context.coordinator.hasBlockSelection = hasBlockSelection
        context.coordinator.onCancelSelection = onCancelSelection
        context.coordinator.onMoveFocus = onMoveFocus
        context.coordinator.onExtendBlockSelection = onExtendBlockSelection
        context.coordinator.onIndentSelection = onIndentSelection
        context.coordinator.onDeleteSelection = onDeleteSelection
        context.coordinator.onUndoEdit = onUndoEdit
        context.coordinator.onRedoEdit = onRedoEdit
        context.coordinator.onSelectFocusedCodeText = onSelectFocusedCodeText
        context.coordinator.onPromoteBlockToPage = onPromoteBlockToPage
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        var onInsertLink: (() -> Bool)?
        var onPasteAttachments: (() -> Bool)?
        var hasBlockSelection: (() -> Bool)?
        var onCancelSelection: (() -> Bool)?
        var onMoveFocus: ((BlockKeyboardFocusDirection) -> Bool)?
        var onExtendBlockSelection: ((BlockKeyboardFocusDirection) -> Bool)?
        var onIndentSelection: ((BlockKeyboardIndentationDirection) -> Bool)?
        var onDeleteSelection: (() -> Bool)?
        var onUndoEdit: (() -> Bool)?
        var onRedoEdit: (() -> Bool)?
        var onSelectFocusedCodeText: ((NSTextView) -> Bool)?
        var onPromoteBlockToPage: (() -> Bool)?
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
                case .deleteSelection:
                    if self.onDeleteSelection?() == true {
                        return nil
                    }
                case .indentSelection(let direction):
                    if self.onIndentSelection?(direction) == true {
                        return nil
                    }
                case .extendBlockSelection(let direction):
                    if self.onExtendBlockSelection?(direction) == true {
                        return nil
                    }
                case .undoEdit:
                    if self.onUndoEdit?() == true {
                        return nil
                    }
                case .redoEdit:
                    if self.onRedoEdit?() == true {
                        return nil
                    }
                case .selectFocusedCodeText:
                    let focusedTextView = MainActor.assumeIsolated {
                        NSApp.keyWindow?.firstResponder as? NSTextView
                    }
                    if let textView = focusedTextView,
                       self.onSelectFocusedCodeText?(textView) == true {
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
                case .moveFocus(let direction):
                    if self.onMoveFocus?(direction) == true {
                        return nil
                    }
                case .promoteBlockToPage:
                    if self.onPromoteBlockToPage?() == true {
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
    let isPasteEnabled: Bool
    let isFocusMoveEnabled: Bool
    let onPasteAttachments: () -> Bool
    let onMoveFocus: (BlockKeyboardFocusDirection) -> Bool

    func makeUIView(context: Context) -> ShortcutCaptureView {
        let view = ShortcutCaptureView(frame: .zero)
        view.isPasteEnabled = isPasteEnabled
        view.isFocusMoveEnabled = isFocusMoveEnabled
        view.onPasteAttachments = onPasteAttachments
        view.onMoveFocus = onMoveFocus
        return view
    }

    func updateUIView(_ uiView: ShortcutCaptureView, context: Context) {
        uiView.isPasteEnabled = isPasteEnabled
        uiView.isFocusMoveEnabled = isFocusMoveEnabled
        uiView.onPasteAttachments = onPasteAttachments
        uiView.onMoveFocus = onMoveFocus
        uiView.updateFirstResponderIfNeeded()
    }

    final class ShortcutCaptureView: UIView {
        var isPasteEnabled = false
        var isFocusMoveEnabled = false
        var onPasteAttachments: () -> Bool = { false }
        var onMoveFocus: (BlockKeyboardFocusDirection) -> Bool = { _ in false }
        private var isCapturingKeyboard = false

        override var canBecomeFirstResponder: Bool {
            isPasteEnabled || isFocusMoveEnabled
        }

        override var keyCommands: [UIKeyCommand]? {
            guard canBecomeFirstResponder else {
                return []
            }

            var commands: [UIKeyCommand] = []
            if isPasteEnabled {
                commands.append(UIKeyCommand(
                    input: "v",
                    modifierFlags: [.command],
                    action: #selector(pasteAttachments)
                ))
            }
            if isFocusMoveEnabled {
                commands.append(UIKeyCommand(
                    input: IOSEditorKeyboardShortcutActionResolver.upArrowInput,
                    modifierFlags: [],
                    action: #selector(moveFocusUp)
                ))
                commands.append(UIKeyCommand(
                    input: IOSEditorKeyboardShortcutActionResolver.downArrowInput,
                    modifierFlags: [],
                    action: #selector(moveFocusDown)
                ))
            }
            return commands
        }

        func updateFirstResponderIfNeeded() {
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                if self.canBecomeFirstResponder {
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

private struct EditorAuxiliaryRail: View {
    let outlineItems: [PageOutlineItem]
    let backlinks: [Backlink]
    let externalLinks: [ExternalLink]
    let onSelectOutlineItem: (PageOutlineItem) -> Void
    let onSelectBacklink: (Backlink) -> Void
    let onCollapse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Spacer()
                Button(action: onCollapse) {
                    Image(systemName: "sidebar.right")
                        .font(.callout)
                        .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("收起右侧栏")
                .accessibilityLabel("收起右侧栏")
                .accessibilityIdentifier("editor.auxiliary-rail.collapse")
            }
            .padding(.bottom, -4)

            if !outlineItems.isEmpty {
                OutlinePanel(outlineItems: outlineItems, onSelectOutlineItem: onSelectOutlineItem)
            }

            if !backlinks.isEmpty {
                BacklinksPanel(backlinks: backlinks, onSelectBacklink: onSelectBacklink)
            }

            if !externalLinks.isEmpty {
                ExternalLinksPanel(externalLinks: externalLinks)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)
        .opacity(0.76)
    }
}

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
    let nestingLevel: Int
    private let frameDescriptor = ListMarkerGlyphFrameDescriptor()

    var body: some View {
        Group {
            if descriptor.marker.hasSuffix(".") {
                Text(descriptor.marker)
                    .font(.system(size: EditorDesignTokens.Typography.bodySize, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary)
            } else {
                ListMarkerBulletGlyph(
                    isHollow: ListMarkerBulletStyleResolver.isHollow(nestingLevel: nestingLevel)
                )
            }
        }
        .frame(
            width: CGFloat(frameDescriptor.width),
            height: CGFloat(frameDescriptor.height),
            alignment: frameDescriptor.horizontalAlignment.frameAlignment
        )
        .accessibilityHidden(true)
    }
}

private struct ListMarkerBulletGlyph: View {
    let isHollow: Bool
    private let descriptor = ListMarkerBulletGlyphDescriptor()

    var body: some View {
        Group {
            if isHollow {
                Circle()
                    .stroke(Color.primary, lineWidth: CGFloat(descriptor.strokeLineWidth))
            } else {
                Circle()
                    .fill(Color.primary)
            }
        }
        .frame(width: CGFloat(descriptor.diameter), height: CGFloat(descriptor.diameter))
        .offset(
            x: CGFloat(descriptor.visibleLeadingOffset),
            y: CGFloat(descriptor.visibleTopOffset)
        )
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

enum DividerBlockAxis: Equatable, Sendable {
    case horizontal
}

struct DividerBlockChromeDescriptor: Equatable, Sendable {
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String
    let axis: DividerBlockAxis
    let height: Double
    let waveAmplitude: Double
    let loopCount: Int
    let strokeOpacity: Double
    let strokeWidth: Double
    let casualVariance: Double

    init(block: BlockSnapshot) {
        accessibilityLabel = "分割线块"
        accessibilityValue = "分割线"
        accessibilityIdentifier = "editor.divider.\(block.id)"
        axis = .horizontal
        height = 56
        waveAmplitude = 12
        loopCount = 5
        strokeOpacity = 0.58
        strokeWidth = 1.6
        casualVariance = 0.16
    }
}

private struct CraftDividerBlockRow: View {
    let descriptor: DividerBlockChromeDescriptor

    var body: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else {
                return
            }

            var path = Path()
            let midY = size.height * 0.5
            let left = size.width * 0.04
            let right = size.width * 0.96
            let loopWidth = min(38, max(28, size.width / 22))
            let loopTotalWidth = loopWidth * CGFloat(descriptor.loopCount)
            let loopStart = max(left + 20, (size.width - loopTotalWidth) / 2)
            let loopEnd = min(right - 20, loopStart + loopTotalWidth)
            let amplitude = CGFloat(descriptor.waveAmplitude)
            let variance = CGFloat(descriptor.casualVariance)

            path.move(to: CGPoint(x: left, y: midY))
            path.addCurve(
                to: CGPoint(x: loopStart, y: midY),
                control1: CGPoint(x: left + (loopStart - left) * 0.16, y: midY + amplitude * (0.86 + variance)),
                control2: CGPoint(x: loopStart - (loopStart - left) * 0.24, y: midY + amplitude * (0.42 + variance * 0.4))
            )

            for index in 0..<descriptor.loopCount {
                let startX = loopStart + CGFloat(index) * loopWidth
                let sway = CGFloat(index % 2 == 0 ? 1 : -1) * variance
                let middleX = startX + loopWidth * (0.50 + sway * 0.10)
                let endX = startX + loopWidth
                let topScale = 1.22 - CGFloat(index % 3) * variance * 0.18
                let bottomScale = 1.06 + CGFloat(index % 2) * variance * 0.5
                path.addCurve(
                    to: CGPoint(x: middleX, y: midY),
                    control1: CGPoint(x: startX + loopWidth * (0.13 + sway * 0.04), y: midY - amplitude * topScale),
                    control2: CGPoint(x: middleX - loopWidth * (0.24 - sway * 0.05), y: midY - amplitude * (topScale + variance * 0.25))
                )
                path.addCurve(
                    to: CGPoint(x: endX, y: midY),
                    control1: CGPoint(x: middleX + loopWidth * (0.22 + sway * 0.03), y: midY + amplitude * bottomScale),
                    control2: CGPoint(x: endX - loopWidth * (0.16 - sway * 0.04), y: midY + amplitude * (bottomScale + variance * 0.22))
                )
            }

            path.addCurve(
                to: CGPoint(x: right, y: midY),
                control1: CGPoint(x: loopEnd + (right - loopEnd) * 0.22, y: midY - amplitude * 0.5),
                control2: CGPoint(x: right - (right - loopEnd) * 0.18, y: midY - amplitude * 0.9)
            )

            context.stroke(
                path,
                with: .color(Color.primary.opacity(descriptor.strokeOpacity)),
                style: StrokeStyle(
                    lineWidth: CGFloat(descriptor.strokeWidth),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: CGFloat(descriptor.height))
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

#if os(iOS)
private struct MobileBlockRowSwipeGestureModifier: ViewModifier {
    let attachment: MobileBlockRowSwipeGestureAttachment
    let onSwipe: (CGSize) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        switch attachment {
        case .nativeTextEditorOnly:
            content
        case .rowHighPriority:
            content.highPriorityGesture(
                DragGesture(minimumDistance: 24, coordinateSpace: .local)
                    .onEnded { value in
                        onSwipe(value.translation)
                    }
            )
        }
    }
}
#endif

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
    let onExtendBlockSelectionByKeyboard: (BlockKeyboardFocusDirection) -> Bool
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
    let selectionResetRequest: TransientSelectionResetRequest
    let dropPlacement: BlockDropPlacement?
    let focusRequestID: UUID?
    let focusSelection: EditorTextSelection?
    let onFocusRequestHandled: () -> Void
    let onSelectCurrentBlock: () -> Void
    let onToggleBlockSelection: () -> Void
    let onSelectAllBlocksByKeyboard: () -> Bool
    let onClearDropTarget: () -> Void
    let onClearTransientSelections: (String?) -> Void
    let onTableRowsChange: ([[String]]) -> Void
    let onTextChange: (String) -> Void
    @State private var isRowHovered = false
    @State private var rowFocusRequest: BlockFocusRequest?
    @State private var slashCommandSelectionIndex = 0
    @State private var slashCommandSelectionSource: SlashCommandSelectionSource = .keyboard

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
        onExtendBlockSelectionByKeyboard: @escaping (BlockKeyboardFocusDirection) -> Bool = { _ in false },
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
        selectionResetRequest: TransientSelectionResetRequest = .none,
        dropPlacement: BlockDropPlacement? = nil,
        focusRequestID: UUID? = nil,
        focusSelection: EditorTextSelection? = nil,
        onFocusRequestHandled: @escaping () -> Void = {},
        onSelectCurrentBlock: @escaping () -> Void = {},
        onToggleBlockSelection: @escaping () -> Void = {},
        onSelectAllBlocksByKeyboard: @escaping () -> Bool = { false },
        onClearDropTarget: @escaping () -> Void = {},
        onClearTransientSelections: @escaping (String?) -> Void = { _ in },
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
        self.onExtendBlockSelectionByKeyboard = onExtendBlockSelectionByKeyboard
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
        self.selectionResetRequest = selectionResetRequest
        self.dropPlacement = dropPlacement
        self.focusRequestID = focusRequestID
        self.focusSelection = focusSelection
        self.onFocusRequestHandled = onFocusRequestHandled
        self.onSelectCurrentBlock = onSelectCurrentBlock
        self.onToggleBlockSelection = onToggleBlockSelection
        self.onSelectAllBlocksByKeyboard = onSelectAllBlocksByKeyboard
        self.onClearDropTarget = onClearDropTarget
        self.onClearTransientSelections = onClearTransientSelections
        self.onTableRowsChange = onTableRowsChange
        self.onTextChange = onTextChange
    }

    var body: some View {
        HStack(alignment: .top, spacing: CGFloat(EditorBlockChrome.actionColumnSpacing)) {
            blockActionColumn
            blockContent
        }
        .padding(.vertical, CGFloat(EditorBlockChrome.rowVerticalPadding))
        .padding(.leading, CGFloat(BlockRowNestingIndentResolver.leadingPadding(
            nestingLevel: nestingLevel,
            blockType: block.type
        )))
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
        .modifier(
            MobileBlockRowSwipeGestureModifier(
                attachment: MobileBlockRowSwipeGestureAttachmentResolver.attachment(
                    usesNativeTextEditor: usesNativeTextEditor
                ),
                onSwipe: { translation in
                    handleMobileHorizontalSwipe(translation: translation)
                }
            )
        )
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
            NonEditableBlockKeyboardFocusBridge(
                isEnabled: NonEditableBlockKeyboardBridgeActivationResolver.isEnabled(
                    blockType: block.type,
                    isBlockSelected: isBlockSelected
                )
            ) { direction in
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
                focusedBlockID: editorSession.focusedBlockID,
                selectionResetRequest: selectionResetRequest,
                onClearExternalSelections: {
                    onClearTransientSelections(block.id)
                },
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
            CraftDividerBlockRow(descriptor: descriptor)
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
        let borderOpacity = BlockRowSelectionBorderPolicy.opacity(
            blockType: block.type,
            isSelected: isBlockSelected
        )
        return RoundedRectangle(cornerRadius: CGFloat(EditorDesignTokens.Layout.rowCornerRadius), style: .continuous)
            .fill(rowBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat(EditorDesignTokens.Layout.rowCornerRadius), style: .continuous)
                    .stroke(EditorDesignTokens.Colors.accent.color.opacity(borderOpacity), lineWidth: 1)
            )
    }

    private var rowBackgroundColor: Color {
        let opacity = BlockRowBackgroundPolicy.opacity(
            blockType: block.type,
            isSelected: isBlockSelected,
            isFocused: editorSession.focusedBlockID == block.id,
            isSlashCommandMenuVisible: isSlashCommandMenuVisible
        )
        guard opacity > 0 else {
            return Color.clear
        }
        if isBlockSelected {
            return EditorDesignTokens.Colors.accent.color.opacity(opacity)
        }
        return EditorDesignTokens.Colors.border.color.opacity(opacity)
    }

    private var isRowActive: Bool {
        isRowHovered || isBlockSelected || editorSession.focusedBlockID == block.id
    }

    private var isSlashCommandMenuVisible: Bool {
        editorSession.focusedBlockID == block.id
            && block.textPlain.hasPrefix("/")
            && !SlashCommandResolver.matchingCommands(for: block.textPlain).isEmpty
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
        case .after, .childAfter, .outdentAfter, nil:
            return .bottomLeading
        }
    }

    private func dropIndicatorLeadingPadding(for placement: BlockDropPlacement) -> CGFloat {
        placement == .childAfter ? 28 : 0
    }

    private func dropIndicatorVerticalOffset(for placement: BlockDropPlacement) -> CGFloat {
        switch placement {
        case .before:
            return -CGFloat(EditorBlockChrome.dropIndicatorAfterOffset)
        case .after, .childAfter, .outdentAfter:
            return CGFloat(EditorBlockChrome.dropIndicatorAfterOffset)
        }
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
                scrollsSelectionIntoView: SlashCommandMenuScrollPolicy.shouldScrollSelectionIntoView(
                    source: slashCommandSelectionSource
                ),
                onHover: { index in
                    guard slashCommandSelectionIndex != index || slashCommandSelectionSource != .hover else {
                        return
                    }
                    slashCommandSelectionSource = .hover
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
            let controlFrame = InlineLeadingControlFrameDescriptor()
            HStack(alignment: .top, spacing: CGFloat(controlFrame.textSpacing)) {
                ListMarkerGlyph(descriptor: descriptor, nestingLevel: nestingLevel)
                    .padding(.top, CGFloat(controlFrame.topPadding))

                inlineBodyTextEditor(descriptor: controlFrame)
            }
            .padding(.vertical, CGFloat(EditorBlockChrome.listVerticalPadding))
            .padding(.horizontal, CGFloat(EditorBlockChrome.listHorizontalPadding))
            .background(Color.secondary.opacity(EditorBlockChrome.listBackgroundOpacity))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(descriptor.accessibilityLabel)
            .accessibilityValue(descriptor.accessibilityValue)
            .accessibilityIdentifier(descriptor.accessibilityIdentifier)
        } else if block.type == .taskItem {
            let controlFrame = InlineLeadingControlFrameDescriptor()
            HStack(alignment: .top, spacing: CGFloat(controlFrame.textSpacing)) {
                inlineLeadingControl(taskItemCompletionButton, descriptor: controlFrame)

                inlineBodyTextEditor(descriptor: controlFrame)
            }
            .padding(.vertical, CGFloat(EditorBlockChrome.listVerticalPadding))
            .padding(.horizontal, CGFloat(EditorBlockChrome.listHorizontalPadding))
            .background(Color.secondary.opacity(TextEditableBlockChromePolicy.backgroundOpacity(blockType: block.type)))
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
            let controlFrame = InlineLeadingControlFrameDescriptor()
            HStack(alignment: .top, spacing: CGFloat(controlFrame.textSpacing)) {
                inlineLeadingControl(toggleBlockExpansionButton, descriptor: controlFrame)

                inlineBodyTextEditor(descriptor: controlFrame)
            }
            .padding(.vertical, CGFloat(EditorBlockChrome.listVerticalPadding))
            .padding(.horizontal, CGFloat(EditorBlockChrome.listHorizontalPadding))
            .background(Color.secondary.opacity(TextEditableBlockChromePolicy.backgroundOpacity(blockType: block.type)))
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

    private func inlineLeadingControl<Control: View>(
        _ control: Control,
        descriptor: InlineLeadingControlFrameDescriptor
    ) -> some View {
        control
            .frame(
                width: CGFloat(descriptor.width),
                height: CGFloat(descriptor.height),
                alignment: .leading
            )
            .padding(.top, CGFloat(descriptor.topPadding))
    }

    private func inlineBodyTextEditor(descriptor: InlineLeadingControlFrameDescriptor) -> some View {
        nativeTextBlockEditor
            .offset(y: CGFloat(descriptor.textVerticalOffset))
    }

    private var taskItemCompletionButton: some View {
        Button {
            onTaskItemCompletionChange(!block.taskItemIsCompleted)
        } label: {
            Image(systemName: block.taskItemIsCompleted ? "checkmark.circle.fill" : "circle")
        }
        .buttonStyle(.plain)
        .font(.system(size: 16, weight: .regular))
        .foregroundStyle(block.taskItemIsCompleted ? .green : .secondary)
        .contentShape(Rectangle())
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
        .buttonStyle(.plain)
        .font(.system(size: 16, weight: .regular))
        .foregroundStyle(.secondary)
        .contentShape(Rectangle())
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
            onExtendBlockSelectionByKeyboard: onExtendBlockSelectionByKeyboard,
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
            onPromoteBlockToPageByKeyboard: {
                onConvertToPage()
                return true
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
        slashCommandSelectionSource = .keyboard
        switch command.type {
        case .pageReference:
            onTextChange("")
            onConvertToPage()
        case .attachmentFile, .attachmentImage, .attachmentVideo:
            break
        default:
            onClearTransientSelections(nil)
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
        slashCommandSelectionSource = .keyboard
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
        guard block.type != .table else {
            return
        }
        onClearTransientSelections(nil)
        guard usesNativeTextEditor else {
            if NonEditableBlockSelectionPolicy.selectsBlockOnFocusRequest(blockType: block.type) {
                onSelectCurrentBlock()
            }
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

        if NonEditableBlockSelectionPolicy.selectsBlockOnFocusRequest(blockType: block.type) {
            onSelectCurrentBlock()
        }
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
    let destinationLevel: Int
    let moveDroppedBlocks: ([String], String, BlockDropPlacement, Int?) -> Bool

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: CGFloat(EditorBlockChrome.dropSlotHeight))
            .contentShape(Rectangle())
            .overlay(alignment: .center) {
                if let activeTarget {
                    BlockDropIndicator(
                        placement: activeTarget.placement,
                        targetLevel: activeTarget.targetLevel
                    )
                    .padding(.leading, dropIndicatorLeadingPadding(for: activeTarget.targetLevel))
                }
            }
            .onDrop(
                of: [UTType.plainText.identifier, UTType.text.identifier],
                delegate: EditorBlockDropDelegate(
                    destinationBlockID: destinationBlockID,
                    slotKind: slotKind,
                    activeDropTarget: $activeDropTarget,
                    destinationLevel: destinationLevel,
                    moveDroppedBlocks: moveDroppedBlocks
                )
            )
            .accessibilityHidden(true)
    }

    private var activeTarget: BlockDropTarget? {
        guard let activeDropTarget,
              activeDropTarget.blockID == destinationBlockID else {
            return nil
        }

        switch (slotKind, activeDropTarget.placement) {
        case (.before, .before):
            return activeDropTarget
        case (.after, .after):
            return activeDropTarget
        case (.after, .childAfter):
            return activeDropTarget
        case (.after, .outdentAfter):
            return activeDropTarget
        default:
            return nil
        }
    }

    private func dropIndicatorLeadingPadding(for targetLevel: Int?) -> CGFloat {
        CGFloat(max(0, targetLevel ?? destinationLevel)) * BlockDropPlacementResolver.levelIndentWidth
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
    let destinationLevel: Int
    let moveDroppedBlocks: ([String], String, BlockDropPlacement, Int?) -> Bool

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
        let resolution = updateTarget(for: info)
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
                _ = moveDroppedBlocks(
                    blockIDs,
                    destinationBlockID,
                    resolution.placement,
                    resolution.targetLevel
                )
            }
        }
        return true
    }

    @discardableResult
    private func updateTarget(for info: DropInfo) -> BlockDropPlacementResolution {
        let resolution = placementResolution(for: info)
        let target = BlockDropTarget(
            blockID: destinationBlockID,
            placement: resolution.placement,
            targetLevel: resolution.targetLevel
        )
        if activeDropTarget != target {
            activeDropTarget = target
        }
        return resolution
    }

    private func placementResolution(for info: DropInfo) -> BlockDropPlacementResolution {
        switch slotKind {
        case .before:
            return BlockDropPlacementResolution(placement: .before, targetLevel: nil)
        case .after:
            return BlockDropPlacementResolver.afterResolution(
                locationX: info.location.x,
                destinationLevel: destinationLevel
            )
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
    let targetLevel: Int?

    private var descriptor: BlockDropIndicatorDescriptor {
        BlockDropIndicatorDescriptor(placement: placement, targetLevel: targetLevel)
    }

    var body: some View {
        HStack(spacing: 7) {
            BlockDropLevelRail(
                dotCount: descriptor.levelDotCount,
                color: indicatorColor
            )

            Capsule()
                .fill(indicatorColor)
                .frame(maxWidth: 340)
                .frame(height: 1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("editor.block-drop-indicator")
    }

    private var indicatorColor: Color {
        (placement == .childAfter || placement == .outdentAfter)
            ? EditorDesignTokens.Colors.accent.color.opacity(0.62)
            : EditorDesignTokens.Colors.accent.color.opacity(0.34)
    }

    private var accessibilityLabel: String {
        switch placement {
        case .before:
            return "拖拽到块上方"
        case .after:
            return "拖拽到块下方"
        case .childAfter:
            return "拖拽为下级块"
        case .outdentAfter:
            return "拖拽为上级块"
        }
    }
}

struct BlockDropIndicatorDescriptor: Equatable, Sendable {
    let placement: BlockDropPlacement
    let targetLevel: Int?

    var levelDotCount: Int {
        guard placement != .before else {
            return 1
        }
        return max(1, (targetLevel ?? 0) + 1)
    }

    var visibleText: String? {
        nil
    }
}

private struct BlockDropLevelRail: View {
    let dotCount: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<min(max(dotCount, 1), 7), id: \.self) { index in
                Circle()
                    .fill(color.opacity(index == dotCount - 1 ? 1 : 0.42))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(width: 48, alignment: .leading)
    }
}

private struct DragPreviewBlock: View {
    let block: BlockSnapshot
    private let layout = DragPreviewLayoutDescriptor()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            invisibleSpacer
                .frame(height: CGFloat(layout.pointerVerticalOffset))

            HStack(spacing: 0) {
                invisibleSpacer
                    .frame(width: CGFloat(layout.pointerHorizontalOffset))

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
                .shadow(
                    color: EditorDesignTokens.Shadows.popoverSmall.swiftUIColor,
                    radius: CGFloat(EditorDesignTokens.Shadows.popoverSmall.radius),
                    x: CGFloat(EditorDesignTokens.Shadows.popoverSmall.x),
                    y: CGFloat(EditorDesignTokens.Shadows.popoverSmall.y)
                )

                invisibleSpacer
                    .frame(width: CGFloat(layout.trailingInset))
            }

            invisibleSpacer
                .frame(height: CGFloat(layout.bottomInset))
        }
        .frame(
            width: CGFloat(layout.previewWidth),
            height: CGFloat(layout.previewHeight),
            alignment: .topLeading
        )
    }

    private var invisibleSpacer: some View {
        Color.white.opacity(layout.invisibleSpacerOpacity)
    }

    private var previewText: String {
        let trimmed = block.textPlain.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? block.type.editorMenuTitle : trimmed
    }
}

private struct SlashCommandMenu: View {
    let commands: [SlashCommandDescriptor]
    let selectedIndex: Int
    let scrollsSelectionIntoView: Bool
    let onHover: (Int) -> Void
    let onSelect: (SlashCommandDescriptor) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                        Button {
                            onSelect(command)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: command.type.editorMenuSystemImage)
                                    .font(.callout)
                                    .foregroundStyle(index == selectedIndex ? EditorDesignTokens.Colors.accent.color : .secondary)
                                    .frame(width: 22)

                                VStack(alignment: .leading, spacing: 2) {
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
                            .frame(minHeight: CGFloat(EditorDesignTokens.Layout.slashMenuRowHeight), alignment: .leading)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(index == selectedIndex ? EditorDesignTokens.Colors.accent.color.opacity(0.08) : Color.clear)
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
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
            }
            .frame(maxHeight: 342)
            .onChange(of: selectedIndex) { _, index in
                guard scrollsSelectionIntoView else {
                    return
                }
                guard commands.indices.contains(index) else {
                    return
                }
                withAnimation(.easeOut(duration: 0.06)) {
                    proxy.scrollTo(commands[index].id, anchor: .center)
                }
            }
        }
        .frame(width: CGFloat(EditorDesignTokens.Layout.slashMenuWidth), alignment: .leading)
        .background(EditorDesignTokens.Colors.editorBackground.color)
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(EditorDesignTokens.Layout.slashMenuCornerRadius), style: .continuous)
                .stroke(EditorDesignTokens.Colors.border.color, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(EditorDesignTokens.Layout.slashMenuCornerRadius), style: .continuous))
        .shadow(
            color: EditorDesignTokens.Shadows.popoverLarge.swiftUIColor,
            radius: CGFloat(EditorDesignTokens.Shadows.popoverLarge.radius),
            x: CGFloat(EditorDesignTokens.Shadows.popoverLarge.x),
            y: CGFloat(EditorDesignTokens.Shadows.popoverLarge.y)
        )
        .shadow(
            color: EditorDesignTokens.Shadows.popoverSmall.swiftUIColor,
            radius: CGFloat(EditorDesignTokens.Shadows.popoverSmall.radius),
            x: CGFloat(EditorDesignTokens.Shadows.popoverSmall.x),
            y: CGFloat(EditorDesignTokens.Shadows.popoverSmall.y)
        )
        .accessibilityValue("可滚动，\(commands.count) 项")
        .accessibilityIdentifier("editor.slash-command-menu")
    }
}

private struct StructuredTableBlockEditor: View {
    let blockID: String
    let text: String
    let rows: [[String]]
    let focusedBlockID: String?
    let selectionResetRequest: TransientSelectionResetRequest
    let onClearExternalSelections: () -> Void
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
            } onCancelSelection: {
                selection = .empty
            } onMoveFocus: { direction in
                onMoveFocusByKeyboard(direction)
            }
            .frame(width: 0, height: 0)
        )
#elseif os(iOS)
        .background(
            IOSTableKeyboardShortcutBridge(isEnabled: !selection.isEmpty) {
                deleteSelection()
            } onCancelSelection: {
                selection = .empty
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
        .onChange(of: selectionResetRequest) { _, request in
            guard request.excludingBlockID != blockID else {
                return
            }
            selection = TableSelectionReducer.selectionAfterExternalInteraction(selection)
        }
        .onChange(of: focusedBlockID) { _, focusedBlockID in
            if focusedBlockID != blockID {
                selection = .empty
            }
        }
    }

    private var editableRows: [[String]] {
        TableBlockDefaultGridResolver.editableRows(text: text, rows: rows)
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
        .font(.system(size: 13, weight: rowIndex == 0 ? .semibold : .regular))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(
            width: CGFloat(TableBlockChrome.cellWidth),
            height: CGFloat(TableBlockChrome.cellHeight),
            alignment: .topLeading
        )
        .background(cellBackgroundColor(row: rowIndex, column: columnIndex))
        .overlay {
            if selection.rows.contains(rowIndex) || selection.columns.contains(columnIndex) {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.accentColor.opacity(0.14), lineWidth: 1)
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
            onClearExternalSelections()
            selection = .empty
        }
        .accessibilityIdentifier("editor.table.\(blockID).cell.\(rowIndex).\(columnIndex)")
    }

    private func cellBackgroundColor(row rowIndex: Int, column columnIndex: Int) -> Color {
        if selection.rows.contains(rowIndex) || selection.columns.contains(columnIndex) {
            return Color.accentColor.opacity(0.045)
        }
        return rowIndex == 0 ? Color.secondary.opacity(0.012) : Color.white
    }

    private func rowSelector(_ rowIndex: Int, columnCount: Int) -> some View {
        Button {
            onClearExternalSelections()
            selection = TableSelectionReducer.selectionAfterSelectingRow(
                rowIndex,
                current: selection,
                extend: isShiftPressed
            )
        } label: {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.accentColor.opacity(TableBlockChrome.selectorHitOpacity))
                    .frame(
                        width: CGFloat(TableBlockChrome.selectorWidth),
                        height: CGFloat(TableBlockChrome.cellHeight)
                    )

                if selection.rows.contains(rowIndex) {
                    Capsule()
                        .fill(Color.accentColor.opacity(TableBlockChrome.selectorSelectedIndicatorOpacity))
                        .frame(
                            width: CGFloat(TableBlockChrome.selectorSelectedIndicatorThickness),
                            height: CGFloat(TableBlockChrome.cellHeight - TableBlockChrome.selectorSelectedIndicatorInset * 2)
                        )
                        .padding(.vertical, CGFloat(TableBlockChrome.selectorSelectedIndicatorInset))
                }
            }
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
            onClearExternalSelections()
            selection = TableSelectionReducer.selectionAfterSelectingColumn(
                columnIndex,
                current: selection,
                extend: isShiftPressed
            )
        } label: {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color.accentColor.opacity(TableBlockChrome.selectorHitOpacity))
                    .frame(
                        width: CGFloat(TableBlockChrome.cellWidth),
                        height: CGFloat(TableBlockChrome.selectorHeight)
                    )

                if selection.columns.contains(columnIndex) {
                    Capsule()
                        .fill(Color.accentColor.opacity(TableBlockChrome.selectorSelectedIndicatorOpacity))
                        .frame(
                            width: CGFloat(TableBlockChrome.cellWidth - TableBlockChrome.selectorSelectedIndicatorInset * 2),
                            height: CGFloat(TableBlockChrome.selectorSelectedIndicatorThickness)
                        )
                        .padding(.horizontal, CGFloat(TableBlockChrome.selectorSelectedIndicatorInset))
                }
            }
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
                    .fill(insertControlColor)
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
            .background(Color.white.opacity(0.01))
            .contentShape(Rectangle())
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

    private var insertControlColor: Color {
        if isHovered {
            return Color.accentColor.opacity(TableBlockChrome.insertControlHoverOpacity)
        }
        return Color.secondary.opacity(TableBlockChrome.insertControlIdleOpacity)
    }
}

#if os(iOS)
private struct IOSTableKeyboardShortcutBridge: UIViewRepresentable {
    let isEnabled: Bool
    let onDelete: () -> Void
    let onCancelSelection: () -> Void
    let onMoveFocus: (BlockKeyboardFocusDirection) -> Bool

    func makeUIView(context: Context) -> TableKeyCaptureView {
        let view = TableKeyCaptureView(frame: .zero)
        view.isEnabled = isEnabled
        view.onDelete = onDelete
        view.onCancelSelection = onCancelSelection
        view.onMoveFocus = onMoveFocus
        return view
    }

    func updateUIView(_ uiView: TableKeyCaptureView, context: Context) {
        uiView.isEnabled = isEnabled
        uiView.onDelete = onDelete
        uiView.onCancelSelection = onCancelSelection
        uiView.onMoveFocus = onMoveFocus
        uiView.updateFirstResponderIfNeeded()
    }

    final class TableKeyCaptureView: UIView {
        var isEnabled = false
        var onDelete: () -> Void = {}
        var onCancelSelection: () -> Void = {}
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
                    input: UIKeyCommand.inputUpArrow,
                    modifierFlags: [],
                    action: #selector(moveFocusUp)
                ),
                UIKeyCommand(
                    input: UIKeyCommand.inputDownArrow,
                    modifierFlags: [],
                    action: #selector(moveFocusDown)
                ),
                UIKeyCommand(
                    input: IOSTableBlockKeyboardActionResolver.deleteBackwardInput,
                    modifierFlags: [],
                    action: #selector(deleteSelectionCommand)
                ),
                UIKeyCommand(
                    input: IOSTableBlockKeyboardActionResolver.deleteForwardInput,
                    modifierFlags: [],
                    action: #selector(deleteSelectionCommand)
                ),
                UIKeyCommand(
                    input: IOSTableBlockKeyboardActionResolver.escapeInput,
                    modifierFlags: [],
                    action: #selector(cancelSelectionCommand)
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

        @objc private func moveFocusUp(_ sender: Any?) {
            performShortcut(input: IOSEditorKeyboardShortcutActionResolver.upArrowInput)
        }

        @objc private func moveFocusDown(_ sender: Any?) {
            performShortcut(input: IOSEditorKeyboardShortcutActionResolver.downArrowInput)
        }

        @objc private func deleteSelectionCommand(_ sender: Any?) {
            performShortcut(input: IOSTableBlockKeyboardActionResolver.deleteBackwardInput)
        }

        @objc private func cancelSelectionCommand(_ sender: Any?) {
            performShortcut(input: IOSTableBlockKeyboardActionResolver.escapeInput)
        }

        private func performShortcut(input: String?) {
            switch IOSTableBlockKeyboardActionResolver.action(
                input: input,
                modifiers: [],
                hasSelection: isEnabled
            ) {
            case .deleteSelection:
                onDelete()
            case .cancelSelection:
                onCancelSelection()
            case .moveFocus(let direction):
                _ = onMoveFocus(direction)
            case nil:
                break
            }
        }
    }
}
#endif

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
    let onCancelSelection: () -> Void
    let onMoveFocus: (BlockKeyboardFocusDirection) -> Bool

    func makeNSView(context: Context) -> TableDeleteKeyCaptureView {
        let view = TableDeleteKeyCaptureView(frame: .zero)
        view.isEnabled = isEnabled
        view.onDelete = onDelete
        view.onCancelSelection = onCancelSelection
        view.onMoveFocus = onMoveFocus
        return view
    }

    func updateNSView(_ nsView: TableDeleteKeyCaptureView, context: Context) {
        nsView.isEnabled = isEnabled
        nsView.onDelete = onDelete
        nsView.onCancelSelection = onCancelSelection
        nsView.onMoveFocus = onMoveFocus

        guard isEnabled else {
            DispatchQueue.main.async {
                if nsView.window?.firstResponder === nsView {
                    nsView.window?.makeFirstResponder(nil)
                }
            }
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
        var onCancelSelection: () -> Void
        var onMoveFocus: (BlockKeyboardFocusDirection) -> Bool

        override init(frame frameRect: NSRect) {
            self.onDelete = {}
            self.onCancelSelection = {}
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
                if isEnabled,
                   event.blockKeyboardShortcutModifiers.isEmpty,
                   !(event.charactersIgnoringModifiers ?? "").isEmpty {
                    onCancelSelection()
                }
                nextResponder?.keyDown(with: event)
                return
            }

            switch action {
            case .deleteSelection:
                onDelete()
            case .cancelSelection:
                onCancelSelection()
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
        private var globalMouseUpMonitor: Any?
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
            if globalMouseUpMonitor == nil {
                globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
                    Task { @MainActor in
                        self?.clearIfNeeded()
                    }
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
            if let globalMouseUpMonitor {
                NSEvent.removeMonitor(globalMouseUpMonitor)
            }
            if let resignObserver {
                NotificationCenter.default.removeObserver(resignObserver)
            }
            eventMonitor = nil
            globalMouseUpMonitor = nil
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
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(
                    cornerRadius: CGFloat(EditorDesignTokens.Layout.pageLinkCornerRadius),
                    style: .continuous
                )
                .fill(EditorDesignTokens.Colors.appBackground.color.opacity(0.52))
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: CGFloat(EditorDesignTokens.Layout.pageLinkCornerRadius),
                    style: .continuous
                )
                .stroke(EditorDesignTokens.Colors.border.color.opacity(0.82), lineWidth: 1)
            )
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
