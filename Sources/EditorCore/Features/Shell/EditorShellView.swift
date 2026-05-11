import SwiftUI
import UniformTypeIdentifiers

struct EditorShellView: View {
    @StateObject private var viewModel: WorkspaceViewModel

    init(viewModel: WorkspaceViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        AdaptiveEditorShell(viewModel: viewModel)
            .task {
                try? viewModel.load()
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
            WorkspaceSidebar(snapshot: viewModel.snapshot)
        } content: {
            PageListView(viewModel: viewModel)
        } detail: {
            EditorCanvasView(
                page: viewModel.selectedPage,
                blocks: viewModel.visibleBlocks,
                onBlockTextChange: { blockID, text in
                    viewModel.editBlockText(blockID: blockID, text: text)
                },
                onImportAttachment: { sourceURL in
                    viewModel.importAttachmentForCurrentPage(sourceURL: sourceURL)
                }
            )
        }
    }
}

private struct CompactEditorShell: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Spaces") {
                    ForEach(viewModel.snapshot.workspaces) { workspace in
                        NavigationLink {
                            CompactPageListView(viewModel: viewModel)
                        } label: {
                            Label(workspace.name, systemImage: "tray.full")
                        }
                    }
                }
            }
            .navigationTitle("Editor")
            .background(Color.white)
        }
    }
}

private struct WorkspaceSidebar: View {
    let snapshot: WorkspaceSnapshot

    var body: some View {
        List {
            Section("Spaces") {
                ForEach(snapshot.workspaces) { workspace in
                    Label(workspace.name, systemImage: "tray.full")
                }
            }

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

private struct PageListView: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    var body: some View {
        List(selection: selectedPageBinding) {
            ForEach(viewModel.snapshot.pages) { page in
                PageRow(page: page)
                    .tag(Optional(page.id))
            }
        }
        .navigationTitle("Pages")
        .scrollContentBackground(.hidden)
        .background(Color.white)
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
            ForEach(viewModel.snapshot.pages) { page in
                NavigationLink {
                    EditorCanvasView(
                        page: page,
                        blocks: viewModel.snapshot.blocks.filter { $0.pageID == page.id },
                        onBlockTextChange: { blockID, text in
                            viewModel.editBlockText(blockID: blockID, text: text)
                        },
                        onImportAttachment: { sourceURL in
                            viewModel.importAttachmentForCurrentPage(sourceURL: sourceURL)
                        }
                    )
                    .onAppear {
                        viewModel.selectPage(id: page.id)
                    }
                } label: {
                    PageRow(page: page)
                }
            }
        }
        .navigationTitle("Pages")
        .scrollContentBackground(.hidden)
        .background(Color.white)
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

private struct EditorCanvasView: View {
    let page: PageSummary?
    let blocks: [BlockSnapshot]
    let onBlockTextChange: (String, String) -> Void
    let onImportAttachment: (URL) -> Void
    @State private var isAttachmentImporterPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    Text(page?.title ?? "No Page")
                        .font(.largeTitle.weight(.semibold))

                    Spacer(minLength: 12)

                    Button {
                        isAttachmentImporterPresented = true
                    } label: {
                        Image(systemName: "paperclip")
                    }
                    .buttonStyle(.borderless)
                    .help("Insert attachment")
                    .accessibilityIdentifier("editor.insert-attachment")
                }

                ForEach(blocks) { block in
                    BlockRowView(block: block) { text in
                        onBlockTextChange(block.id, text)
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.vertical, 36)
        }
        .background(Color.white)
        .navigationTitle(page?.title ?? "Editor")
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
}

private struct BlockRowView: View {
    let block: BlockSnapshot
    let onTextChange: (String) -> Void
    @State private var draftText: String

    init(block: BlockSnapshot, onTextChange: @escaping (String) -> Void) {
        self.block = block
        self.onTextChange = onTextChange
        _draftText = State(initialValue: block.textPlain)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle.grid.2x2")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)

            switch block.type {
            case .paragraph:
                TextField(
                    "Start writing",
                    text: Binding(
                        get: { draftText },
                        set: { newValue in
                            draftText = newValue
                            onTextChange(newValue)
                        }
                    ),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1...8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("editor.block.\(block.id)")
                .onChange(of: block.textPlain) { _, newValue in
                    if newValue != draftText {
                        draftText = newValue
                    }
                }
            case .attachmentImage, .attachmentVideo, .attachmentFile:
                AttachmentBlockRow(block: block)
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}

private struct AttachmentBlockRow: View {
    let block: BlockSnapshot

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

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

    private var iconName: String {
        switch block.type {
        case .attachmentImage:
            return "photo"
        case .attachmentVideo:
            return "film"
        case .attachmentFile:
            return "doc"
        case .paragraph:
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
        case .paragraph:
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
