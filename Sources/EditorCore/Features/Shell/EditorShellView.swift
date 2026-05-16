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

extension FocusedValues {
    var insertMarkdownLinkAction: (() -> Void)? {
        get { self[EditorInsertMarkdownLinkActionKey.self] }
        set { self[EditorInsertMarkdownLinkActionKey.self] = newValue }
    }

    var promoteDiarySelectionAction: (() -> Void)? {
        get { self[EditorPromoteDiarySelectionActionKey.self] }
        set { self[EditorPromoteDiarySelectionActionKey.self] = newValue }
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
            if viewModel.selectedPage == nil {
                if viewModel.activeDiaryEntry == nil {
                    Color.white
                        .navigationTitle("Diary")
                } else {
                    DiaryEditorView(
                        entry: viewModel.activeDiaryEntry,
                        onTextChange: { text in
                            do {
                                try viewModel.updateDiaryText(text)
                            } catch {
                                EditorLog.input.error(
                                    "diary_text_update_failed error=\(String(describing: error), privacy: .public)"
                                )
                            }
                        },
                        onPromoteSelection: { selectedText in
                            do {
                                try viewModel.promoteSelectedDiaryTextToPage(selectedText)
                                return true
                            } catch {
                                EditorLog.input.error(
                                    "diary_text_promote_failed error=\(String(describing: error), privacy: .public)"
                                )
                                return false
                            }
                        }
                    )
                }
            } else {
                EditorCanvasView(
                    page: viewModel.selectedPage,
                    pages: viewModel.snapshot.pages,
                    blocks: viewModel.editorVisibleBlocks,
                    allBlocks: viewModel.snapshot.blocks,
                    attachments: viewModel.snapshot.attachments,
                    backlinks: viewModel.selectedPageBacklinks,
                    externalLinks: viewModel.selectedPageExternalLinks,
                    conflicts: viewModel.selectedPageConflicts,
                    outlineItems: viewModel.selectedPageOutline,
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
                    onSelectBacklink: { backlink in
                        viewModel.selectBacklink(backlink)
                    },
                    onSelectOutlineItem: { item in
                        viewModel.selectOutlineItem(item)
                    },
                    onOpenPageReference: { targetPageID in
                        viewModel.openPageReference(targetPageID: targetPageID)
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
                    onBlockTextChange: { blockID, text in
                        viewModel.editBlockText(blockID: blockID, text: text)
                    },
                    onBlockTypeChange: { blockID, type in
                        viewModel.changeBlockTypeForUI(blockID: blockID, type: type)
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
                    onPendingBlockFocusHandled: {
                        _ = viewModel.consumePendingFocusBlockID()
                    }
                )
            }
        }
    }
}

private struct CompactEditorShell: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @State private var path: [CompactRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Spaces") {
                    ForEach(viewModel.snapshot.workspaces) { workspace in
                        NavigationLink(value: CompactRoute.pages) {
                            Label(workspace.name, systemImage: "tray.full")
                        }
                        .accessibilityIdentifier("editor.workspace.\(workspace.id)")
                    }
                }

                CloudKitAccountStatusSection(viewModel: viewModel)
            }
            .navigationTitle("Editor")
            .background(Color.white)
            .navigationDestination(for: CompactRoute.self) { route in
                switch route {
                case .pages:
                    CompactPageListView(viewModel: viewModel)
                case .page(let pageID):
                    CompactPageDestination(
                        viewModel: viewModel,
                        pageID: pageID
                    )
                }
            }
            .onChange(of: viewModel.pendingCompactPageNavigationID) { _, pageID in
                guard let pageID = viewModel.consumePendingCompactPageNavigationID() ?? pageID else {
                    return
                }
                pushPageIfNeeded(pageID)
            }
        }
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
        visibleBlockIndexesByID[blockID] = index
        lastEventNanoseconds = nowNanoseconds
        blockAppearanceCount += 1
        peakVisibleBlockCount = max(peakVisibleBlockCount, visibleBlockIndexesByID.count)
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

private enum CompactRoute: Hashable {
    case pages
    case page(String)
}

private struct CompactPageDestination: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    let pageID: String

    var body: some View {
        if let page = viewModel.snapshot.pages.first(where: { $0.id == pageID }) {
            EditorCanvasView(
                page: page,
                pages: viewModel.snapshot.pages,
                blocks: viewModel.editorVisibleBlocks(for: page.id),
                allBlocks: viewModel.snapshot.blocks,
                attachments: viewModel.snapshot.attachments,
                backlinks: viewModel.selectedPageBacklinks,
                externalLinks: viewModel.selectedPageExternalLinks,
                conflicts: viewModel.selectedPageConflicts,
                outlineItems: viewModel.selectedPageOutline,
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
                onSelectBacklink: { backlink in
                    viewModel.selectBacklink(backlink)
                },
                onSelectOutlineItem: { item in
                    viewModel.selectOutlineItem(item)
                },
                onOpenPageReference: { targetPageID in
                    viewModel.openPageReference(targetPageID: targetPageID)
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
                onBlockTextChange: { blockID, text in
                    viewModel.editBlockText(blockID: blockID, text: text)
                },
                onBlockTypeChange: { blockID, type in
                    viewModel.changeBlockTypeForUI(blockID: blockID, type: type)
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
                onPendingBlockFocusHandled: {
                    _ = viewModel.consumePendingFocusBlockID()
                }
            )
            .onAppear {
                viewModel.selectPage(id: page.id)
            }
        } else {
            Color.white
                .navigationTitle("Editor")
        }
    }
}

private struct WorkspaceSidebar: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        List {
            Section("Write") {
                CollectionRailButton(
                    title: "Diary",
                    systemImage: "square.and.pencil",
                    isSelected: viewModel.selectedCollection == .diary,
                    identifier: "editor.collection.diary"
                ) {
                    viewModel.selectCollection(.diary)
                }
            }

            Section("Browse") {
                CollectionRailButton(
                    title: "All Documents",
                    systemImage: "doc.text",
                    isSelected: viewModel.selectedCollection == .allDocuments,
                    identifier: "editor.collection.all-documents"
                ) {
                    viewModel.selectCollection(.allDocuments)
                }

                CollectionRailButton(
                    title: "Favorites",
                    systemImage: "star",
                    isSelected: viewModel.selectedCollection == .favorites,
                    identifier: "editor.collection.favorites"
                ) {
                    viewModel.selectCollection(.favorites)
                }

                ForEach(viewModel.snapshot.favoritePages) { page in
                    Button {
                        viewModel.selectPage(id: page.id)
                    } label: {
                        Label(page.title, systemImage: "star.fill")
                            .font(.callout)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.primary)
                    .padding(.leading, 18)
                    .accessibilityIdentifier("editor.favorite-page.\(page.id)")
                }

                CollectionRailButton(
                    title: "Tags",
                    systemImage: "tag",
                    isSelected: isTagsSelected,
                    identifier: "editor.collection.tags"
                ) {
                    viewModel.selectCollection(.tag(""))
                }

                ForEach(viewModel.snapshot.tags) { tag in
                    CollectionRailButton(
                        title: tag.path,
                        systemImage: "tag",
                        isSelected: viewModel.selectedCollection == .tag(tag.id),
                        identifier: "editor.collection.tag.\(tag.id)"
                    ) {
                        viewModel.selectCollection(.tag(tag.id))
                    }
                    .padding(.leading, 18)
                }

                CollectionRailButton(
                    title: "Search",
                    systemImage: "magnifyingglass",
                    isSelected: viewModel.selectedCollection == .search,
                    identifier: "editor.collection.search"
                ) {
                    viewModel.selectCollection(.search)
                }

                CollectionRailButton(
                    title: "Archive",
                    systemImage: "archivebox",
                    isSelected: viewModel.selectedCollection == .archive,
                    identifier: "editor.collection.archive"
                ) {
                    viewModel.selectCollection(.archive)
                }
            }

            CloudKitAccountStatusSection(viewModel: viewModel)
        }
        .navigationTitle("Editor")
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.98, green: 0.98, blue: 0.96))
    }

    private var isTagsSelected: Bool {
        if case .tag = viewModel.selectedCollection {
            return true
        }
        return false
    }
}

private struct CollectionRailButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(isSelected ? .body.weight(.semibold) : .body)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private struct CloudKitAccountStatusSection: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        Section("Sync") {
            HStack(spacing: 8) {
                Image(systemName: statusIconName)
                    .foregroundStyle(statusColor)
                    .frame(width: 18)

                Text(viewModel.cloudKitAccountStatusText)
                    .font(.callout)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button {
                    viewModel.syncNow()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.icloud")
                }
                .buttonStyle(.borderless)
                .help("Sync now")
                .accessibilityIdentifier("editor.sync-now")

                Button {
                    viewModel.refreshCloudKitAccountStatusForUI()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh iCloud status")
                .accessibilityIdentifier("editor.refresh-icloud-status")

                Button {
                    viewModel.purgeUnreferencedAttachmentsForUI()
                } label: {
                    Image(systemName: "trash.slash")
                }
                .buttonStyle(.borderless)
                .help("Clean unreferenced attachments")
                .accessibilityIdentifier("editor.clean-attachments")
            }
            .accessibilityIdentifier("editor.icloud-status")

            Text(viewModel.syncStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
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
        List(selection: selectedPageBinding) {
            switch viewModel.selectedCollection {
            case .diary, .allDocuments:
                pageRowsSection(title: "All Documents", pages: viewModel.visibleDocumentPages)
            case .favorites:
                pageRowsSection(title: "Favorites", pages: viewModel.visibleDocumentPages)
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
        .navigationTitle(navigationTitle)
        .scrollContentBackground(.hidden)
        .background(Color.white)
    }

    @ViewBuilder
    private func pageRowsSection(title: String, pages: [PageSummary]) -> some View {
        Section(title) {
            ForEach(pages) { page in
                pageRow(page)
            }
        }
    }

    @ViewBuilder
    private func tagSection(tagID: String) -> some View {
        if tagID.isEmpty {
            Section("Tags") {
                ForEach(viewModel.snapshot.tags) { tag in
                    Button {
                        viewModel.selectCollection(.tag(tag.id))
                    } label: {
                        Label(tag.path, systemImage: "tag")
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("editor.tag-row.\(tag.id)")
                }
            }
        } else {
            pageRowsSection(title: tagName(for: tagID), pages: viewModel.visibleDocumentPages)
        }
    }

    private var archiveSection: some View {
        Group {
            if viewModel.canUndoPageArchive {
                undoArchiveSection
            }

            Section("Archive") {
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

    private var undoArchiveSection: some View {
        Section {
            Button {
                viewModel.undoLastPageArchiveForUI()
            } label: {
                Label("Undo Archive", systemImage: "arrow.uturn.backward")
            }
            .accessibilityIdentifier("editor.undo-page-archive")
        }
    }

    private func pageRow(_ page: PageSummary) -> some View {
        PageRow(
            page: page,
            isSelected: viewModel.selectedPageID == page.id,
            tagNames: tagNames(for: page),
            onFavoriteToggle: {
                viewModel.updatePageFavoriteForUI(
                    id: page.id,
                    isFavorite: !page.isFavorite
                )
            }
        )
        .tag(Optional(page.id))
        .contextMenu {
            Button {
                viewModel.updatePageFavoriteForUI(
                    id: page.id,
                    isFavorite: !page.isFavorite
                )
            } label: {
                Label(
                    page.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: page.isFavorite ? "star.slash" : "star"
                )
            }

            Button {
                viewModel.archivePageForUI(id: page.id)
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
        }
    }

    private var navigationTitle: String {
        switch viewModel.selectedCollection {
        case .diary, .allDocuments:
            return "All Documents"
        case .favorites:
            return "Favorites"
        case .tag(let tagID):
            return tagID.isEmpty ? "Tags" : tagName(for: tagID)
        case .search:
            return "Search"
        case .archive:
            return "Archive"
        }
    }

    private func tagName(for tagID: String) -> String {
        viewModel.snapshot.tags.first { $0.id == tagID }?.path ?? "Tags"
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
            if let newValue {
                viewModel.selectPage(id: newValue)
            }
        }
    }
}

private struct DiaryEditorView: View {
    let entry: DiaryEntrySnapshot?
    let onTextChange: (String) -> Void
    let onPromoteSelection: (String) -> Bool

    @State private var text = ""
    @State private var selectedText = ""
    @State private var syncedEntryID: String?

    var body: some View {
        PlatformDiaryTextEditor(
            text: textBinding,
            onSelectedTextChange: { selectedText in
                self.selectedText = selectedText
            },
            onPromoteSelection: promoteSelectedText
        )
            .padding(.horizontal, 40)
            .padding(.vertical, 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white)
            .accessibilityLabel("Diary")
            .accessibilityIdentifier("editor.diary.text")
            .focusedValue(\.promoteDiarySelectionAction, promoteDiarySelectionAction)
            .onAppear {
                syncTextFromEntry(force: true)
            }
            .onChange(of: entry) { _, _ in
                syncTextFromEntry(force: false)
            }
            .navigationTitle("Diary")
    }

    private var promoteDiarySelectionAction: (() -> Void)? {
        guard !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return {
            _ = promoteSelectedText(selectedText)
        }
    }

    private var textBinding: Binding<String> {
        Binding {
            text
        } set: { newText in
            text = newText
            onTextChange(newText)
        }
    }

    private func syncTextFromEntry(force: Bool) {
        let entryID = entry?.id
        guard force || syncedEntryID != entryID else {
            return
        }
        syncedEntryID = entryID
        text = entry?.textPlain ?? ""
    }

    private func promoteSelectedText(_ selectedText: String) -> Bool {
        guard !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        return onPromoteSelection(selectedText)
    }
}

#if os(macOS)
private struct PlatformDiaryTextEditor: NSViewRepresentable {
    @Binding var text: String
    let onSelectedTextChange: (String) -> Void
    let onPromoteSelection: (String) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = DiaryNSTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.setAccessibilityIdentifier("editor.diary.text")
        textView.onPromoteSelection = { [weak coordinator = context.coordinator, weak textView] in
            guard let coordinator, let textView else {
                return false
            }
            return coordinator.promoteSelection(in: textView)
        }

        context.coordinator.applyModelText(text, to: textView)
        scrollView.documentView = textView
        scrollView.setAccessibilityIdentifier("editor.diary.container")
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? DiaryNSTextView else {
            return
        }

        textView.onPromoteSelection = { [weak coordinator = context.coordinator, weak textView] in
            guard let coordinator, let textView else {
                return false
            }
            return coordinator.promoteSelection(in: textView)
        }
        if textView.string != text {
            context.coordinator.applyModelText(text, to: textView)
        }
        context.coordinator.publishSelectedText(in: textView)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlatformDiaryTextEditor
        private var isApplyingModelText = false

        init(parent: PlatformDiaryTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingModelText,
                  let textView = notification.object as? NSTextView else {
                return
            }

            parent.text = textView.string
            publishSelectedText(in: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            publishSelectedText(in: textView)
        }

        func applyModelText(_ text: String, to textView: NSTextView) {
            isApplyingModelText = true
            let currentRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(Self.clamped(range: currentRange, text: text))
            isApplyingModelText = false
            publishSelectedText(in: textView)
        }

        func promoteSelection(in textView: NSTextView) -> Bool {
            let selectedText = Self.selectedText(in: textView)
            guard parent.onPromoteSelection(selectedText) else {
                return false
            }
            parent.onSelectedTextChange("")
            return true
        }

        func publishSelectedText(in textView: NSTextView) {
            parent.onSelectedTextChange(Self.selectedText(in: textView))
        }

        private static func selectedText(in textView: NSTextView) -> String {
            let range = textView.selectedRange()
            guard range.length > 0,
                  let textRange = Range(range, in: textView.string) else {
                return ""
            }

            return String(textView.string[textRange])
        }

        private static func clamped(range: NSRange, text: String) -> NSRange {
            let length = (text as NSString).length
            let location = min(range.location, length)
            let selectedLength = min(range.length, length - location)
            return NSRange(location: location, length: selectedLength)
        }
    }
}

private final class DiaryNSTextView: NSTextView {
    var onPromoteSelection: (() -> Bool)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        NativeTextBlockEditor.acceptsInactiveWindowFirstMouse
    }

    override func keyDown(with event: NSEvent) {
        if DiaryPromotionKeyboardResolver.requestsPromotion(
            input: event.charactersIgnoringModifiers,
            modifiers: event.blockKeyboardShortcutModifiers
        ), onPromoteSelection?() == true {
            return
        }

        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if DiaryPromotionKeyboardResolver.requestsPromotion(
            input: event.charactersIgnoringModifiers,
            modifiers: event.blockKeyboardShortcutModifiers
        ), onPromoteSelection?() == true {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}
#else
private struct PlatformDiaryTextEditor: View {
    @Binding var text: String
    let onSelectedTextChange: (String) -> Void
    let onPromoteSelection: (String) -> Bool

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .scrollContentBackground(.hidden)
            .onChange(of: text) { _, _ in
                onSelectedTextChange("")
            }
    }
}
#endif

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
                                    page.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                    systemImage: page.isFavorite ? "star.slash" : "star"
                                )
                            }

                            Button {
                                viewModel.archivePageForUI(id: page.id)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
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
                    Label("New Notebook", systemImage: "folder.badge.plus")
                }
            }

            if viewModel.canUndoPageArchive {
                Section {
                    Button {
                        viewModel.undoLastPageArchiveForUI()
                    } label: {
                        Label("Undo Archive", systemImage: "arrow.uturn.backward")
                    }
                    .accessibilityIdentifier("editor.undo-page-archive")
                }
            }

            if !viewModel.snapshot.archivedPages.isEmpty {
                Section("Archive") {
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
        .navigationTitle("Pages")
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
            TextField("Notebook", text: nameBinding)
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
            .help("Move up")
            .accessibilityLabel("Move notebook up")
            .accessibilityValue(controlAvailabilityValue(canMoveUp))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).move-up")

            Button {
                onMoveDown()
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveDown)
            .help("Move down")
            .accessibilityLabel("Move notebook down")
            .accessibilityValue(controlAvailabilityValue(canMoveDown))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).move-down")

            Button {
                onOutdent()
            } label: {
                Image(systemName: "decrease.indent")
            }
            .buttonStyle(.borderless)
            .disabled(!canOutdent)
            .help("Outdent notebook")
            .accessibilityLabel("Outdent notebook")
            .accessibilityValue(controlAvailabilityValue(canOutdent))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).outdent")

            Button {
                onIndent()
            } label: {
                Image(systemName: "increase.indent")
            }
            .buttonStyle(.borderless)
            .disabled(!canIndent)
            .help("Indent notebook")
            .accessibilityLabel("Indent notebook")
            .accessibilityValue(controlAvailabilityValue(canIndent))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).indent")

            Button {
                onAddChildNotebook()
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.borderless)
            .help("New child notebook")
            .accessibilityLabel("Add child notebook")
            .accessibilityValue(controlAvailabilityValue(true))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).add-child-notebook")

            Button {
                onAddPage()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("New page")
            .accessibilityLabel("Add page to notebook")
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
        isAvailable ? "Available" : "Unavailable"
    }
}

private struct SearchSectionView: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        Section("Search") {
            TextField("Search", text: searchBinding)
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
    var onFavoriteToggle: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "doc.text.fill" : "doc.text")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)

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
                Button {
                    onFavoriteToggle()
                } label: {
                    Image(systemName: page.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(page.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.borderless)
                .help(page.isFavorite ? "Remove from Favorites" : "Add to Favorites")
                .accessibilityLabel(page.isFavorite ? "Remove page from favorites" : "Add page to favorites")
                .accessibilityValue(page.isFavorite ? "Favorite" : "Not favorite")
                .accessibilityIdentifier("editor.page.\(page.id).favorite")
            } else if page.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 5)
    }

    private var pageRowAccessibilityValue: String {
        let selection = isSelected ? "Selected" : "Not selected"
        let favorite = page.isFavorite ? "Favorite" : "Not favorite"
        let tags = tagNames.isEmpty ? "No tags" : "Tags: \(tagNames.joined(separator: ", "))"
        return "\(selection), \(favorite), \(tags)"
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
            .help("Restore")
            .accessibilityIdentifier("editor.restore-page.\(page.id)")

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete permanently")
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
    let backlinks: [Backlink]
    let externalLinks: [ExternalLink]
    let conflicts: [ConflictSnapshot]
    let outlineItems: [PageOutlineItem]
    let pendingFocusBlockID: String?
    let canUndoTextEdit: Bool
    let onAddParagraphBlock: () -> String?
    let onAddPageReference: (String) -> Void
    let onAddBlockReference: (String) -> Void
    let onInsertMarkdownLink: (String, String, String) -> Bool
    let onInsertMarkdownLinkAtSelection: (String, String, String, EditorTextSelection) -> EditorTextSelection?
    let onApplyMarkdownInlineFormat: (String, MarkdownInlineFormat, EditorTextSelection) -> EditorTextSelection?
    let onUndoTextEdit: () -> Void
    let onFocusCanvas: () -> String?
    let onMoveBlock: (String, Int) -> Void
    let onMoveBlockByKeyboard: (String, BlockKeyboardMoveDirection) -> Bool
    let onInsertBlockAfter: (String) -> Bool
    let onSplitTextBlockAtSelection: (String, EditorTextSelection) -> EditorTextSelection?
    let onMergeTextBlockWithPrevious: (String, EditorTextSelection) -> EditorTextSelection?
    let onMergeTextBlockWithNext: (String, EditorTextSelection) -> EditorTextSelection?
    let onIndentBlock: (String) -> Bool
    let onOutdentBlock: (String) -> Bool
    let onDeleteBlock: (String) -> Void
    let onSelectBacklink: (Backlink) -> Void
    let onSelectOutlineItem: (PageOutlineItem) -> Void
    let onOpenPageReference: (String) -> Void
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
    let onBlockTextChange: (String, String) -> Void
    let onBlockTypeChange: (String, BlockType) -> Void
    let onTaskItemCompletionChange: (String, Bool) -> Void
    let onCodeBlockLineWrappingChange: (String, Bool) -> Void
    let onToggleBlockExpansion: (String) -> Void
    let isToggleBlockExpanded: (String) -> Bool
    let onImportAttachment: (URL) -> Void
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
    @State private var scrollMetricsTracker = EditorCanvasScrollMetricsTracker(pageID: nil, blockCount: 0)

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    TextField("Untitled", text: pageTitleBinding)
                        .textFieldStyle(.plain)
                        .font(.largeTitle.weight(.semibold))
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
                    .help("New block")
                    .accessibilityIdentifier("editor.add-block")
                    .disabled(page == nil)

                    Menu {
                        ForEach(pageReferenceTargets) { targetPage in
                            Button {
                                onAddPageReference(targetPage.id)
                            } label: {
                                Label(targetPage.title, systemImage: "doc.text")
                            }
                        }
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                    .menuStyle(.borderlessButton)
                    .help("Insert page reference")
                    .accessibilityIdentifier("editor.insert-page-reference")
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
                        Image(systemName: "text.badge.plus")
                    }
                    .menuStyle(.borderlessButton)
                    .help("Insert block reference")
                    .accessibilityIdentifier("editor.insert-block-reference")
                    .disabled(blockReferenceTargets.isEmpty)

                    Button {
                        activeInlineLinkTarget = inlineLinkTarget
                        isInlineLinkPopoverPresented = activeInlineLinkTarget != nil
                    } label: {
                        Image(systemName: "link.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .help("Insert link")
                    .accessibilityIdentifier("editor.insert-markdown-link")
                    .disabled(inlineLinkToolbarTargetBlockID == nil)

                    Button {
                        applyMarkdownInlineFormat(.bold)
                    } label: {
                        Image(systemName: "bold")
                    }
                    .buttonStyle(.borderless)
                    .help("Bold")
                    .accessibilityIdentifier("editor.inline-format.bold")
                    .disabled(inlineFormatTarget == nil)

                    Button {
                        applyMarkdownInlineFormat(.italic)
                    } label: {
                        Image(systemName: "italic")
                    }
                    .buttonStyle(.borderless)
                    .help("Italic")
                    .accessibilityIdentifier("editor.inline-format.italic")
                    .disabled(inlineFormatTarget == nil)

                    Button {
                        applyMarkdownInlineFormat(.strikethrough)
                    } label: {
                        Image(systemName: "strikethrough")
                    }
                    .buttonStyle(.borderless)
                    .help("Strikethrough")
                    .accessibilityIdentifier("editor.inline-format.strikethrough")
                    .disabled(inlineFormatTarget == nil)

                    Button {
                        applyMarkdownInlineFormat(.code)
                    } label: {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                    }
                    .buttonStyle(.borderless)
                    .help("Code")
                    .accessibilityIdentifier("editor.inline-format.code")
                    .disabled(inlineFormatTarget == nil)

                    Button {
                        onUndoTextEdit()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderless)
                    .help("Undo text edit")
                    .accessibilityIdentifier("editor.undo-text-edit")
                    .disabled(!canUndoTextEdit)

                    Button {
                        handleMarkdownImportButton()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderless)
                    .help("Import Markdown")
                    .accessibilityIdentifier("editor.import-markdown")
                    .disabled(page == nil)

                    Button {
                        handleMarkdownExportButton()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .help("Export Markdown")
                    .accessibilityIdentifier("editor.export-markdown")
                    .disabled(page == nil)

                    Button {
                        handleAttachmentImportButton()
                    } label: {
                        Image(systemName: "paperclip")
                    }
                    .buttonStyle(.borderless)
                    .help("Insert attachment")
                    .accessibilityIdentifier("editor.insert-attachment")
                }

                if isInlineLinkPopoverPresented {
                    inlineLinkPopover
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
                    BlockRowView(
                        block: block,
                        attachment: attachment(for: block),
                        editorSession: editorSession,
                        nestingLevel: nestingLevel(for: block),
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
                        onTaskItemCompletionChange: { isCompleted in
                            onTaskItemCompletionChange(block.id, isCompleted)
                        },
                        onCodeBlockLineWrappingChange: { isWrapped in
                            onCodeBlockLineWrappingChange(block.id, isWrapped)
                        },
                        onToggleBlockExpansion: {
                            onToggleBlockExpansion(block.id)
                        },
                        isToggleBlockExpanded: isToggleBlockExpanded(block.id),
                        focusRequestID: pendingFocusRequest?.blockID == block.id ? pendingFocusRequest?.id : nil,
                        focusSelection: pendingFocusRequest?.blockID == block.id ? pendingFocusRequest?.selection : nil,
                        onFocusRequestHandled: {
                            if pendingFocusRequest?.blockID == block.id {
                                pendingFocusRequest = nil
                            }
                            if pendingFocusBlockID == block.id {
                                onPendingBlockFocusHandled()
                            }
                        }
                    ) { text in
                        onBlockTextChange(block.id, text)
                    }
                    .onAppear {
                        recordVisibleBlockAppeared(block.id, index: index)
                    }
                    .onDisappear {
                        recordVisibleBlockDisappeared(block.id)
                    }
                    .dropDestination(for: String.self) { draggedBlockIDs, _ in
                        moveDroppedBlocks(draggedBlockIDs, destinationBlockID: block.id)
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
                        moveDroppedBlocksToEnd(draggedBlockIDs)
                    }
                    .accessibilityIdentifier("editor.canvas-edit-region")
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.vertical, 36)
        }
        .accessibilityIdentifier("editor.canvas-scroll")
#if DEBUG
        .overlay(alignment: .topLeading) {
            scrollMetricsDebugProbe
        }
#endif
        .background(Color.white)
#if os(macOS)
        .background(
            MacEditorKeyboardShortcutBridge {
                presentInlineLinkInsertionFromKeyboardShortcut()
            }
        )
#endif
        .navigationTitle(page?.title ?? "Editor")
        .focusedValue(\.insertMarkdownLinkAction, insertMarkdownLinkAction)
        .onAppear {
            resetScrollMetrics()
            schedulePendingFocusIfNeeded(pendingFocusBlockID)
            logRenderMetrics(reason: "appear")
        }
        .onChange(of: pendingFocusBlockID) { _, blockID in
            schedulePendingFocusIfNeeded(blockID)
        }
        .onChange(of: renderMetrics) { _, _ in
            resetScrollMetrics()
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
            defaultFilename: "\(page?.title ?? "Page").md"
        ) { result in
            if case .failure(let error) = result {
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
        let markdown = MarkdownTransformer.export(blocks: blocks)
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
            TextField("Label", text: $inlineLinkLabel)
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
                .help("Cancel")
                .accessibilityIdentifier("editor.insert-markdown-link.cancel")

                Spacer()
                Button {
                    insertInlineLink()
                } label: {
                    Label(isEditingInlineLink ? "Update Link" : "Insert Link", systemImage: "link")
                }
                .disabled(MarkdownInlineLinkComposer.markdown(label: inlineLinkLabel, url: inlineLinkURL) == nil)
                .accessibilityIdentifier("editor.insert-markdown-link.confirm")
            }
        }
        .padding(12)
    }

    private func blockReferenceTitle(for block: BlockSnapshot) -> String {
        let pageTitle = pages.first { $0.id == block.pageID }?.title ?? "Page"
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

    private func focusAdjacentBlock(
        from blockID: String,
        direction: BlockKeyboardFocusDirection
    ) -> Bool {
        guard let target = BlockKeyboardFocusResolver.target(
            currentBlockID: blockID,
            direction: direction,
            blocks: blocks
        ) else {
            return false
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

    private func moveDroppedBlocks(_ draggedBlockIDs: [String], destinationBlockID: String) -> Bool {
        guard let draggedBlockID = draggedBlockIDs.first,
              let targetIndex = BlockDragReorderResolver.targetIndex(
                draggedBlockID: draggedBlockID,
                destinationBlockID: destinationBlockID,
                visibleBlockIDs: blocks.map(\.id)
              ) else {
            return false
        }

        onMoveBlock(draggedBlockID, targetIndex)
        return true
    }

    private func moveDroppedBlocksToEnd(_ draggedBlockIDs: [String]) -> Bool {
        guard let draggedBlockID = draggedBlockIDs.first,
              let targetIndex = BlockDragReorderResolver.endTargetIndex(
                draggedBlockID: draggedBlockID,
                visibleBlockIDs: blocks.map(\.id)
              ) else {
            return false
        }

        onMoveBlock(draggedBlockID, targetIndex)
        return true
    }

    private func attachment(for block: BlockSnapshot) -> AttachmentSnapshot? {
        attachments.first { $0.matches(block: block) }
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

    private func recordVisibleBlockAppeared(_ blockID: String, index: Int) {
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
private struct MacEditorKeyboardShortcutBridge: NSViewRepresentable {
    let onInsertLink: () -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.onInsertLink = onInsertLink
        context.coordinator.install()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onInsertLink = onInsertLink
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        var onInsertLink: (() -> Bool)?
        private var eventMonitor: Any?

        func install() {
            guard eventMonitor == nil else {
                return
            }

            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else {
                    return event
                }

                if MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(
                    input: event.charactersIgnoringModifiers,
                    modifiers: event.blockKeyboardShortcutModifiers
                ), self.onInsertLink?() == true {
                    return nil
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
#endif

private struct BacklinksPanel: View {
    let backlinks: [Backlink]
    let onSelectBacklink: (Backlink) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backlinks")
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
            Text("External Links")
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
            Text("Outline")
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
                .accessibilityLabel("Outline heading \(item.title)")
                .accessibilityValue("Level \(item.level)")
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
        Text("Sync Conflicts")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var headerButtons: some View {
        Button {
            mergeDrafts.useLocalText(for: conflicts)
        } label: {
            Label("Draft All Local", systemImage: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .disabled(conflicts.isEmpty)
        .accessibilityIdentifier("editor.conflict.draft-all-local")

        Button {
            mergeDrafts.useRemoteText(for: conflicts)
        } label: {
            Label("Draft All Remote", systemImage: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .disabled(conflicts.isEmpty)
        .accessibilityIdentifier("editor.conflict.draft-all-remote")

        Button {
            onResolveAllManually(currentMergedTexts())
        } label: {
            Label("Apply All Merged", systemImage: "checkmark.circle")
        }
        .buttonStyle(.borderless)
        .disabled(conflicts.isEmpty)
        .accessibilityIdentifier("editor.conflict.apply-all-merged")

        Button {
            onAcceptAllLocalConflicts()
        } label: {
            Label("Use All Local", systemImage: "arrow.up.doc")
        }
        .buttonStyle(.borderless)
        .disabled(conflicts.isEmpty)
        .accessibilityIdentifier("editor.conflict.accept-all-local")

        Button {
            onAcceptAllConflicts()
        } label: {
            Label("Use All Remote", systemImage: "arrow.down.doc")
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
                        conflictTextColumn(title: "Local", text: conflict.localTextPlain)
                        conflictTextColumn(
                            title: "Remote r\(conflict.remoteRevision)",
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
            Label("Edit Local", systemImage: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("editor.conflict.\(conflict.id).draft-local")

        Button {
            onUseRemoteDraft(conflict)
        } label: {
            Label("Edit Remote", systemImage: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("editor.conflict.\(conflict.id).draft-remote")
    }

    @ViewBuilder
    private var resolutionButtons: some View {
        Button {
            onResolveManually(conflict, mergedText)
        } label: {
            Label("Apply Merge", systemImage: "checkmark.circle")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("editor.conflict.\(conflict.id).apply-merge")

        Button {
            onAcceptLocalConflict(conflict)
        } label: {
            Label("Use Local", systemImage: "arrow.up.doc")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("editor.conflict.\(conflict.id).accept-local")

        Button {
            onAcceptConflict(conflict)
        } label: {
            Label("Use Remote", systemImage: "arrow.down.doc")
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

private struct BlockRowView: View {
    let block: BlockSnapshot
    let attachment: AttachmentSnapshot?
    @ObservedObject var editorSession: EditorSession
    let nestingLevel: Int
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
    let onDelete: () -> Void
    let onOpenPageReference: (String) -> Void
    let onOpenBlockReference: (String, String) -> Void
    let onChangeType: (BlockType) -> Void
    let onTaskItemCompletionChange: (Bool) -> Void
    let onCodeBlockLineWrappingChange: (Bool) -> Void
    let onToggleBlockExpansion: () -> Void
    let isToggleBlockExpanded: Bool
    let focusRequestID: UUID?
    let focusSelection: EditorTextSelection?
    let onFocusRequestHandled: () -> Void
    let onTextChange: (String) -> Void
    @State private var rowFocusRequest: BlockFocusRequest?

    init(
        block: BlockSnapshot,
        attachment: AttachmentSnapshot? = nil,
        editorSession: EditorSession,
        nestingLevel: Int = 0,
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
        onDelete: @escaping () -> Void = {},
        onOpenPageReference: @escaping (String) -> Void = { _ in },
        onOpenBlockReference: @escaping (String, String) -> Void = { _, _ in },
        onChangeType: @escaping (BlockType) -> Void = { _ in },
        onTaskItemCompletionChange: @escaping (Bool) -> Void = { _ in },
        onCodeBlockLineWrappingChange: @escaping (Bool) -> Void = { _ in },
        onToggleBlockExpansion: @escaping () -> Void = {},
        isToggleBlockExpanded: Bool = true,
        focusRequestID: UUID? = nil,
        focusSelection: EditorTextSelection? = nil,
        onFocusRequestHandled: @escaping () -> Void = {},
        onTextChange: @escaping (String) -> Void
    ) {
        self.block = block
        self.attachment = attachment
        self.editorSession = editorSession
        self.nestingLevel = nestingLevel
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
        self.onDelete = onDelete
        self.onOpenPageReference = onOpenPageReference
        self.onOpenBlockReference = onOpenBlockReference
        self.onChangeType = onChangeType
        self.onTaskItemCompletionChange = onTaskItemCompletionChange
        self.onCodeBlockLineWrappingChange = onCodeBlockLineWrappingChange
        self.onToggleBlockExpansion = onToggleBlockExpansion
        self.isToggleBlockExpanded = isToggleBlockExpanded
        self.focusRequestID = focusRequestID
        self.focusSelection = focusSelection
        self.onFocusRequestHandled = onFocusRequestHandled
        self.onTextChange = onTextChange
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 2) {
                Image(systemName: "circle.grid.2x2")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .draggable(block.id)
                    .accessibilityLabel("Block drag handle")
                    .accessibilityValue(block.type.editorMenuTitle)
                    .accessibilityIdentifier("editor.block.\(block.id).drag-handle")

                if block.type.isTextEditable {
                    Menu {
                        ForEach(Self.textBlockMenuTypes, id: \.self) { type in
                            Button {
                                onChangeType(type)
                            } label: {
                                Label(type.editorMenuTitle, systemImage: type.editorMenuSystemImage)
                            }
                        }
                    } label: {
                        Image(systemName: "textformat")
                    }
                    .menuStyle(.borderlessButton)
                    .help("Block type")
                    .accessibilityLabel("Change block type")
                    .accessibilityValue(block.type.editorMenuTitle)
                    .accessibilityIdentifier("editor.block.\(block.id).type-menu")
                }

                Button {
                    onMoveUp()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(!canMoveUp)
                .help("Move up")
                .accessibilityLabel("Move block up")
                .accessibilityValue(controlAvailabilityValue(canMoveUp))
                .accessibilityIdentifier("editor.block.\(block.id).move-up")

                Button {
                    onMoveDown()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(!canMoveDown)
                .help("Move down")
                .accessibilityLabel("Move block down")
                .accessibilityValue(controlAvailabilityValue(canMoveDown))
                .accessibilityIdentifier("editor.block.\(block.id).move-down")

                Button {
                    _ = onOutdent()
                } label: {
                    Image(systemName: "decrease.indent")
                }
                .buttonStyle(.borderless)
                .disabled(nestingLevel == 0)
                .help("Outdent")
                .accessibilityLabel("Outdent block")
                .accessibilityValue(controlAvailabilityValue(nestingLevel > 0))
                .accessibilityIdentifier("editor.block.\(block.id).outdent")

                Button {
                    _ = onIndent()
                } label: {
                    Image(systemName: "increase.indent")
                }
                .buttonStyle(.borderless)
                .disabled(!canMoveUp)
                .help("Indent")
                .accessibilityLabel("Indent block")
                .accessibilityValue(controlAvailabilityValue(canMoveUp))
                .accessibilityIdentifier("editor.block.\(block.id).indent")

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete")
                .accessibilityLabel("Delete block")
                .accessibilityValue(controlAvailabilityValue(true))
                .accessibilityIdentifier("editor.block.\(block.id).delete")
            }
            .frame(width: 24)
            .padding(.top, 1)

            if block.type == .table {
                StructuredTableBlockEditor(
                    blockID: block.id,
                    text: block.textPlain,
                    onTextChange: onTextChange
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if block.type.isTextEditable {
                textEditableBlockContent
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if block.type == .pageReference {
                PageReferenceBlockRow(block: block, onOpenPageReference: onOpenPageReference)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if block.type == .blockReference {
                BlockReferenceBlockRow(block: block, onOpenBlockReference: onOpenBlockReference)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if block.type == .divider {
                Divider()
                    .padding(.vertical, 10)
                    .accessibilityIdentifier("editor.divider.\(block.id)")
            } else {
                AttachmentBlockRow(block: block, attachment: attachment)
            }
        }
        .padding(.vertical, 7)
        .padding(.leading, CGFloat(nestingLevel) * 24)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(rowAccessibilityIdentifier)
        .simultaneousGesture(
            TapGesture().onEnded {
                requestRowFocus()
            }
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

    @ViewBuilder
    private var textEditableBlockContent: some View {
        if block.type == .taskItem {
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
            .accessibilityValue(block.taskItemIsCompleted ? "Completed" : "Incomplete")
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
            .background(Color(red: 0.98, green: 0.98, blue: 0.96))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(codeBlockAccessibilityLabel)
            .accessibilityValue(block.codeBlockLineWrapping ? "Line wrap enabled" : "Line wrap disabled")
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
            .accessibilityValue(isToggleBlockExpanded ? "Expanded" : "Collapsed")
            .accessibilityIdentifier("editor.toggle.\(block.id)")
        } else if block.type == .callout {
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.35))
                    .frame(width: 3)
                    .padding(.vertical, 3)
                    .accessibilityHidden(true)

                Image(systemName: "exclamationmark.bubble")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                    .accessibilityHidden(true)

                nativeTextBlockEditor
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Callout block")
            .accessibilityValue(block.textPlain.isEmpty ? "Empty" : block.textPlain)
            .accessibilityIdentifier("editor.callout.\(block.id)")
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
        .help(block.taskItemIsCompleted ? "Mark incomplete" : "Mark complete")
        .accessibilityLabel(block.taskItemIsCompleted ? "Mark task incomplete" : "Mark task complete")
        .accessibilityValue(block.taskItemIsCompleted ? "Completed" : "Incomplete")
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
        .help(isToggleBlockExpanded ? "Collapse" : "Expand")
        .accessibilityLabel(isToggleBlockExpanded ? "Collapse toggle block" : "Expand toggle block")
        .accessibilityValue(isToggleBlockExpanded ? "Expanded" : "Collapsed")
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
        .help(block.codeBlockLineWrapping ? "Disable line wrap" : "Enable line wrap")
        .accessibilityLabel(block.codeBlockLineWrapping ? "Disable code line wrap" : "Enable code line wrap")
        .accessibilityValue(block.codeBlockLineWrapping ? "Line wrap enabled" : "Line wrap disabled")
        .accessibilityIdentifier("editor.block.\(block.id).code-wrap")
    }

    private var codeBlockAccessibilityLabel: String {
        block.codeBlockLineWrapping ? "Code block, Line wrap enabled" : "Code block, Line wrap disabled"
    }

    private var toggleBlockAccessibilityLabel: String {
        isToggleBlockExpanded ? "Toggle block, Expanded" : "Toggle block, Collapsed"
    }

    private var taskBlockAccessibilityLabel: String {
        block.taskItemIsCompleted ? "Task block, Completed" : "Task block, Incomplete"
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
            onTextChange: onTextChange
        )
        .accessibilityIdentifier("editor.text.\(block.id)")
    }

    private func controlAvailabilityValue(_ isAvailable: Bool) -> String {
        isAvailable ? "Available" : "Unavailable"
    }

    private func handleKeyboardIndentation(_ direction: BlockKeyboardIndentationDirection) -> Bool {
        switch direction {
        case .indent:
            return onIndent()
        case .outdent:
            return onOutdent()
        }
    }

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

    private func requestRowFocus() {
        guard block.type.isTextEditable else {
            return
        }

        rowFocusRequest = BlockFocusRequest(blockID: block.id)
        EditorLog.focus.debug(
            "editor_focus_request_scheduled block_id=\(block.id, privacy: .public) source=row_tap"
        )
    }

    private func handleFocusRequestHandled() {
        if rowFocusRequest?.blockID == block.id {
            rowFocusRequest = nil
        }
        onFocusRequestHandled()
    }
}

private struct StructuredTableBlockEditor: View {
    let blockID: String
    let text: String
    let onTextChange: (String) -> Void

    private var table: MarkdownTableDocument {
        MarkdownTableDocument(markdown: text)
    }

    var body: some View {
        let rows = editableRows
        let tableDimensions = tableDimensionAccessibilityValue(rows: rows)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Table", systemImage: "tablecells")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Spacer(minLength: 8)

                Button {
                    appendRow()
                } label: {
                    Image(systemName: "plus.square")
                }
                .buttonStyle(.borderless)
                .help("Add row")
                .accessibilityLabel("Add table row")
                .accessibilityValue(tableDimensions)
                .accessibilityIdentifier("editor.table.\(blockID).add-row")

                Button {
                    appendColumn()
                } label: {
                    Image(systemName: "plus.rectangle.portrait")
                }
                .buttonStyle(.borderless)
                .help("Add column")
                .accessibilityLabel("Add table column")
                .accessibilityValue(tableDimensions)
                .accessibilityIdentifier("editor.table.\(blockID).add-column")

                Button {
                    removeLastRow()
                } label: {
                    Image(systemName: "minus.square")
                }
                .buttonStyle(.borderless)
                .help("Remove last row")
                .accessibilityLabel("Remove last table row")
                .accessibilityValue(tableDimensions)
                .accessibilityIdentifier("editor.table.\(blockID).remove-row")

                Button {
                    removeLastColumn()
                } label: {
                    Image(systemName: "minus.rectangle.portrait")
                }
                .buttonStyle(.borderless)
                .help("Remove last column")
                .accessibilityLabel("Remove last table column")
                .accessibilityValue(tableDimensions)
                .accessibilityIdentifier("editor.table.\(blockID).remove-column")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(rows.indices, id: \.self) { rowIndex in
                        GridRow {
                            ForEach(rows[rowIndex].indices, id: \.self) { columnIndex in
                                TextField(
                                    "",
                                    text: cellBinding(row: rowIndex, column: columnIndex)
                                )
                                .textFieldStyle(.plain)
                                .font(rowIndex == 0 ? .callout.weight(.semibold) : .callout)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .frame(minWidth: 96, alignment: .leading)
                                .background(rowIndex == 0 ? Color.secondary.opacity(0.08) : Color.white)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.secondary.opacity(0.22), lineWidth: 0.5)
                                )
                                .accessibilityIdentifier("editor.table.\(blockID).cell.\(rowIndex).\(columnIndex)")
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Table block, \(tableDimensions)")
        .accessibilityValue(tableDimensions)
        .accessibilityIdentifier("editor.table.\(blockID)")
    }

    private var editableRows: [[String]] {
        if !table.rows.isEmpty {
            return table.rows
        }

        return [[text]]
    }

    private func tableDimensionAccessibilityValue(rows: [[String]]) -> String {
        let rowCount = rows.count
        let columnCount = rows.map(\.count).max() ?? 0
        let rowLabel = rowCount == 1 ? "row" : "rows"
        let columnLabel = columnCount == 1 ? "column" : "columns"
        return "\(rowCount) \(rowLabel), \(columnCount) \(columnLabel)"
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
            if updatedTable.rows.isEmpty {
                updatedTable = MarkdownTableDocument(markdown: "| \(text) |\n| --- |")
            }
            updatedTable.updateCell(row: rowIndex, column: columnIndex, text: value)
            onTextChange(updatedTable.markdown)
        }
    }

    private func appendRow() {
        var updatedTable = normalizedTable()
        updatedTable.appendRow()
        onTextChange(updatedTable.markdown)
    }

    private func appendColumn() {
        var updatedTable = normalizedTable()
        updatedTable.appendColumn()
        onTextChange(updatedTable.markdown)
    }

    private func removeLastRow() {
        var updatedTable = normalizedTable()
        updatedTable.removeLastRow()
        onTextChange(updatedTable.markdown)
    }

    private func removeLastColumn() {
        var updatedTable = normalizedTable()
        updatedTable.removeLastColumn()
        onTextChange(updatedTable.markdown)
    }

    private func normalizedTable() -> MarkdownTableDocument {
        if !table.rows.isEmpty {
            return table
        }

        return MarkdownTableDocument(markdown: "| \(text) |\n| --- |")
    }
}

private struct PageReferenceBlockRow: View {
    let block: BlockSnapshot
    let onOpenPageReference: (String) -> Void

    private var titleText: String {
        block.textPlain.isEmpty ? "Untitled" : block.textPlain
    }

    var body: some View {
        Button {
            if let targetPageID = block.pageReferenceTargetPageID {
                onOpenPageReference(targetPageID)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Page")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(titleText)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .background(Color.accentColor.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(block.pageReferenceTargetPageID == nil)
        .accessibilityLabel("Page reference: \(titleText)")
        .accessibilityValue(block.pageReferenceTargetPageID == nil ? "Unavailable" : "Open page")
        .accessibilityIdentifier("editor.page-reference.\(block.id)")
    }
}

private struct BlockReferenceBlockRow: View {
    let block: BlockSnapshot
    let onOpenBlockReference: (String, String) -> Void

    private var titleText: String {
        block.textPlain.isEmpty ? "Referenced block" : block.textPlain
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
                    Text("Block")
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
        .accessibilityLabel("Block reference: \(titleText)")
        .accessibilityValue(
            block.pageReferenceTargetPageID == nil || block.blockReferenceTargetBlockID == nil
                ? "Unavailable"
                : "Open referenced block"
        )
        .accessibilityIdentifier("editor.block-reference.\(block.id)")
    }
}

private extension BlockType {
    var editorMenuTitle: String {
        switch self {
        case .paragraph:
            return "Paragraph"
        case .heading1:
            return "Heading 1"
        case .heading2:
            return "Heading 2"
        case .heading3:
            return "Heading 3"
        case .unorderedListItem:
            return "Bulleted List"
        case .orderedListItem:
            return "Numbered List"
        case .taskItem:
            return "Task"
        case .quote:
            return "Quote"
        case .codeBlock:
            return "Code"
        case .callout:
            return "Callout"
        case .toggle:
            return "Toggle"
        case .table:
            return "Table"
        case .divider:
            return "Divider"
        case .pageReference:
            return "Page Reference"
        case .blockReference:
            return "Block Reference"
        case .attachmentImage:
            return "Image"
        case .attachmentVideo:
            return "Video"
        case .attachmentFile:
            return "File"
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

    var body: some View {
        HStack(spacing: 10) {
            if let thumbnailImage {
                thumbnailImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
            } else if isPreviewPending {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 52, height: 40)
                    .background(Color.white.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityLabel("Generating attachment preview")
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(red: 0.97, green: 0.97, blue: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityIdentifier("editor.attachment.\(block.id)")
        .accessibilityLabel(block.textPlain)
        .accessibilityValue(kindLabel)
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
        previewState == .pending
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
        switch block.type {
        case .attachmentImage:
            return isPreviewPending ? "Image, generating preview" : "Image"
        case .attachmentVideo:
            return isPreviewPending ? "Video, generating preview" : "Video"
        case .attachmentFile:
            return "File"
        default:
            return "Text"
        }
    }
}

#Preview {
    EditorShellView(
        viewModel: WorkspaceViewModel(
            snapshot: WorkspaceSnapshot(
                workspaces: [WorkspaceSummary(id: "workspace-local", name: "Local")],
                pages: [PageSummary(id: "page-welcome", workspaceID: "workspace-local", title: "Welcome")],
                blocks: [
                    BlockSnapshot(
                        id: "block-welcome-001",
                        pageID: "page-welcome",
                        parentBlockID: nil,
                        orderKey: "000001",
                        type: .paragraph,
                        textPlain: "Start writing in blocks."
                    )
                ],
                attachments: [],
                selectedWorkspaceID: "workspace-local",
                selectedPageID: "page-welcome"
            )
        )
    )
}
