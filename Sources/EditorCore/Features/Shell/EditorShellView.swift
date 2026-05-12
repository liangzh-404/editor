import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct EditorShellView: View {
    @StateObject private var viewModel: WorkspaceViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: WorkspaceViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        AdaptiveEditorShell(viewModel: viewModel)
            .task {
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
            EditorCanvasView(
                page: viewModel.selectedPage,
                blocks: viewModel.visibleBlocks,
                attachments: viewModel.snapshot.attachments,
                backlinks: viewModel.selectedPageBacklinks,
                conflicts: viewModel.selectedPageConflicts,
                pendingFocusBlockID: viewModel.pendingFocusBlockID,
                onAddParagraphBlock: {
                    viewModel.addParagraphBlockToCurrentPage()
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
                onAcceptConflict: { conflict in
                    viewModel.acceptRemoteConflictForUI(id: conflict.id)
                },
                onResolveConflictManually: { conflict, text in
                    viewModel.resolveConflictManuallyForUI(id: conflict.id, text: text)
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
                blocks: viewModel.snapshot.blocks.filter { $0.pageID == page.id },
                attachments: viewModel.snapshot.attachments,
                backlinks: viewModel.selectedPageBacklinks,
                conflicts: viewModel.selectedPageConflicts,
                pendingFocusBlockID: viewModel.pendingFocusBlockID,
                onAddParagraphBlock: {
                    viewModel.addParagraphBlockToCurrentPage()
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
                onAcceptConflict: { conflict in
                    viewModel.acceptRemoteConflictForUI(id: conflict.id)
                },
                onResolveConflictManually: { conflict, text in
                    viewModel.resolveConflictManuallyForUI(id: conflict.id, text: text)
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
            Section("Spaces") {
                ForEach(viewModel.snapshot.workspaces) { workspace in
                    Label(workspace.name, systemImage: "tray.full")
                }
            }

            CloudKitAccountStatusSection(viewModel: viewModel)

            Section("Library") {
                Label("Favorites", systemImage: "star")
                Label("Archive", systemImage: "archivebox")
            }
        }
        .navigationTitle("Editor")
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.98, green: 0.98, blue: 0.96))
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
            SearchSectionView(viewModel: viewModel)

            ForEach(Array(viewModel.snapshot.notebooks.enumerated()), id: \.element.id) { index, notebook in
                Section {
                    ForEach(pages(in: notebook)) { page in
                        PageRow(page: page)
                            .tag(Optional(page.id))
                            .contextMenu {
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
                        canMoveUp: index > 0,
                        canMoveDown: index < viewModel.snapshot.notebooks.count - 1,
                        onRename: { name in
                            viewModel.renameNotebookForUI(id: notebook.id, name: name)
                        },
                        onMoveUp: {
                            viewModel.moveNotebookForUI(id: notebook.id, toIndex: index - 1)
                        },
                        onMoveDown: {
                            viewModel.moveNotebookForUI(id: notebook.id, toIndex: index + 1)
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

private struct CompactPageListView: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        List {
            SearchSectionView(viewModel: viewModel)

            ForEach(Array(viewModel.snapshot.notebooks.enumerated()), id: \.element.id) { index, notebook in
                Section {
                    ForEach(pages(in: notebook)) { page in
                        NavigationLink(value: CompactRoute.page(page.id)) {
                            PageRow(page: page)
                        }
                        .contextMenu {
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
                        canMoveUp: index > 0,
                        canMoveDown: index < viewModel.snapshot.notebooks.count - 1,
                        onRename: { name in
                            viewModel.renameNotebookForUI(id: notebook.id, name: name)
                        },
                        onMoveUp: {
                            viewModel.moveNotebookForUI(id: notebook.id, toIndex: index - 1)
                        },
                        onMoveDown: {
                            viewModel.moveNotebookForUI(id: notebook.id, toIndex: index + 1)
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
}

private struct NotebookSectionHeader: View {
    let notebook: NotebookSummary
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onRename: (String) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onAddPage: () -> Void
    @State private var draftName: String

    init(
        notebook: NotebookSummary,
        canMoveUp: Bool,
        canMoveDown: Bool,
        onRename: @escaping (String) -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onAddPage: @escaping () -> Void
    ) {
        self.notebook = notebook
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onRename = onRename
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
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
            .accessibilityIdentifier("editor.notebook.\(notebook.id).move-up")

            Button {
                onMoveDown()
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveDown)
            .help("Move down")
            .accessibilityIdentifier("editor.notebook.\(notebook.id).move-down")

            Button {
                onAddPage()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("New page")
            .accessibilityIdentifier("editor.notebook.\(notebook.id).add-page")
        }
        .onChange(of: notebook.name) { _, name in
            if draftName != name {
                draftName = name
            }
        }
    }

    private var nameBinding: Binding<String> {
        Binding {
            draftName
        } set: { name in
            draftName = name
            onRename(name)
        }
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

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
            Text(page.title)
                .font(.body)
                .lineLimit(1)
        }
        .padding(.vertical, 5)
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
    let blocks: [BlockSnapshot]
    let attachments: [AttachmentSnapshot]
    let backlinks: [Backlink]
    let conflicts: [ConflictSnapshot]
    let pendingFocusBlockID: String?
    let onAddParagraphBlock: () -> String?
    let onFocusCanvas: () -> String?
    let onMoveBlock: (String, Int) -> Void
    let onMoveBlockByKeyboard: (String, BlockKeyboardMoveDirection) -> Bool
    let onIndentBlock: (String) -> Bool
    let onOutdentBlock: (String) -> Bool
    let onDeleteBlock: (String) -> Void
    let onSelectBacklink: (Backlink) -> Void
    let onAcceptConflict: (ConflictSnapshot) -> Void
    let onResolveConflictManually: (ConflictSnapshot, String) -> Void
    let onPageTitleChange: (String) -> Void
    let onImportMarkdown: (URL) -> Void
    let onExportMarkdown: () -> String
    let onBlockTextChange: (String, String) -> Void
    let onBlockTypeChange: (String, BlockType) -> Void
    let onImportAttachment: (URL) -> Void
    let onPendingBlockFocusHandled: () -> Void
    @State private var isAttachmentImporterPresented = false
    @State private var isMarkdownImporterPresented = false
    @State private var isMarkdownExporterPresented = false
    @State private var markdownExportDocument = MarkdownFileDocument(text: "")
    @StateObject private var editorSession = EditorSession()
    @State private var pendingFocusRequest: BlockFocusRequest?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
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

                    Button {
                        isMarkdownImporterPresented = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderless)
                    .help("Import Markdown")
                    .accessibilityIdentifier("editor.import-markdown")
                    .disabled(page == nil)

                    Button {
                        markdownExportDocument = MarkdownFileDocument(text: onExportMarkdown())
                        isMarkdownExporterPresented = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .help("Export Markdown")
                    .accessibilityIdentifier("editor.export-markdown")
                    .disabled(page == nil)

                    Button {
                        isAttachmentImporterPresented = true
                    } label: {
                        Image(systemName: "paperclip")
                    }
                    .buttonStyle(.borderless)
                    .help("Insert attachment")
                    .accessibilityIdentifier("editor.insert-attachment")
                }

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
                        onIndent: {
                            onIndentBlock(block.id)
                        },
                        onOutdent: {
                            onOutdentBlock(block.id)
                        },
                        onDelete: {
                            onDeleteBlock(block.id)
                        },
                        onChangeType: { type in
                            onBlockTypeChange(block.id, type)
                        },
                        focusRequestID: pendingFocusRequest?.blockID == block.id ? pendingFocusRequest?.id : nil,
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
                    .dropDestination(for: String.self) { draggedBlockIDs, _ in
                        moveDroppedBlocks(draggedBlockIDs, destinationBlockID: block.id)
                    }
                }

                if !backlinks.isEmpty {
                    BacklinksPanel(backlinks: backlinks, onSelectBacklink: onSelectBacklink)
                }

                if !conflicts.isEmpty {
                    ConflictPanel(
                        conflicts: conflicts,
                        onAcceptConflict: onAcceptConflict,
                        onResolveManually: onResolveConflictManually
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
        .background(Color.white)
        .navigationTitle(page?.title ?? "Editor")
        .onAppear {
            schedulePendingFocusIfNeeded(pendingFocusBlockID)
        }
        .onChange(of: pendingFocusBlockID) { _, blockID in
            schedulePendingFocusIfNeeded(blockID)
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

    private func schedulePendingFocusIfNeeded(_ blockID: String?) {
        guard let blockID else {
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

private struct ConflictPanel: View {
    let conflicts: [ConflictSnapshot]
    let onAcceptConflict: (ConflictSnapshot) -> Void
    let onResolveManually: (ConflictSnapshot, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sync Conflicts")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(conflicts) { conflict in
                ConflictResolutionRow(
                    conflict: conflict,
                    onAcceptConflict: onAcceptConflict,
                    onResolveManually: onResolveManually
                )
            }
        }
        .padding(.top, 10)
    }
}

private struct ConflictResolutionRow: View {
    let conflict: ConflictSnapshot
    let onAcceptConflict: (ConflictSnapshot) -> Void
    let onResolveManually: (ConflictSnapshot, String) -> Void
    @State private var mergedText: String

    init(
        conflict: ConflictSnapshot,
        onAcceptConflict: @escaping (ConflictSnapshot) -> Void,
        onResolveManually: @escaping (ConflictSnapshot, String) -> Void
    ) {
        self.conflict = conflict
        self.onAcceptConflict = onAcceptConflict
        self.onResolveManually = onResolveManually
        _mergedText = State(initialValue: conflict.localTextPlain)
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

                    TextEditor(text: $mergedText)
                        .font(.callout)
                        .frame(minHeight: 72)
                        .accessibilityIdentifier("editor.conflict.\(conflict.id).merge-text")

                    HStack(spacing: 8) {
                        Button {
                            onResolveManually(conflict, mergedText)
                        } label: {
                            Label("Apply Merge", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("editor.conflict.\(conflict.id).apply-merge")

                        Button {
                            onAcceptConflict(conflict)
                        } label: {
                            Label("Use Remote", systemImage: "arrow.down.doc")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("editor.conflict.\(conflict.id).accept-remote")
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityIdentifier("editor.conflict.\(conflict.id)")
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
    let onIndent: () -> Bool
    let onOutdent: () -> Bool
    let onDelete: () -> Void
    let onChangeType: (BlockType) -> Void
    let focusRequestID: UUID?
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
        onIndent: @escaping () -> Bool = { false },
        onOutdent: @escaping () -> Bool = { false },
        onDelete: @escaping () -> Void = {},
        onChangeType: @escaping (BlockType) -> Void = { _ in },
        focusRequestID: UUID? = nil,
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
        self.onIndent = onIndent
        self.onOutdent = onOutdent
        self.onDelete = onDelete
        self.onChangeType = onChangeType
        self.focusRequestID = focusRequestID
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
                .accessibilityIdentifier("editor.block.\(block.id).move-up")

                Button {
                    onMoveDown()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(!canMoveDown)
                .help("Move down")
                .accessibilityIdentifier("editor.block.\(block.id).move-down")

                Button {
                    _ = onOutdent()
                } label: {
                    Image(systemName: "decrease.indent")
                }
                .buttonStyle(.borderless)
                .disabled(nestingLevel == 0)
                .help("Outdent")
                .accessibilityIdentifier("editor.block.\(block.id).outdent")

                Button {
                    _ = onIndent()
                } label: {
                    Image(systemName: "increase.indent")
                }
                .buttonStyle(.borderless)
                .disabled(!canMoveUp)
                .help("Indent")
                .accessibilityIdentifier("editor.block.\(block.id).indent")

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete")
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
                .accessibilityIdentifier("editor.block.\(block.id)")
            } else if block.type.isTextEditable {
                NativeTextBlockEditor(
                    blockID: block.id,
                    text: block.textPlain,
                    blockType: block.type,
                    session: editorSession,
                    focusRequestID: effectiveFocusRequestID,
                    onFocusRequestHandled: handleFocusRequestHandled,
                    onMoveByKeyboard: onMoveByKeyboard,
                    onTextChange: onTextChange
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("editor.block.\(block.id)")
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
        .simultaneousGesture(
            TapGesture().onEnded {
                requestRowFocus()
            }
        )
    }

    private var effectiveFocusRequestID: UUID? {
        rowFocusRequest?.id ?? focusRequestID
    }

    private static let textBlockMenuTypes: [BlockType] = [
        .paragraph,
        .heading1,
        .unorderedListItem,
        .orderedListItem,
        .taskItem,
        .quote,
        .codeBlock,
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

    private var editableRows: [[String]] {
        if !table.rows.isEmpty {
            return table.rows
        }

        return [[text]]
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
}

private extension BlockType {
    var editorMenuTitle: String {
        switch self {
        case .paragraph:
            return "Paragraph"
        case .heading1:
            return "Heading"
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
    }

    private var thumbnailImage: Image? {
        guard let path = attachment?.previewPath(for: block) else {
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
            return "Image"
        case .attachmentVideo:
            return "Video"
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
