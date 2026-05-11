import SwiftUI

struct EditorShellView: View {
    var body: some View {
        AdaptiveEditorShell()
    }
}

private struct AdaptiveEditorShell: View {
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    var body: some View {
#if os(iOS)
        if horizontalSizeClass == .compact {
            CompactEditorShell()
        } else {
            ThreeColumnEditorShell()
        }
#else
        ThreeColumnEditorShell()
#endif
    }
}

private struct ThreeColumnEditorShell: View {
    var body: some View {
        NavigationSplitView {
            List {
                Section("Spaces") {
                    Label("Local", systemImage: "tray.full")
                    Label("Favorites", systemImage: "star")
                    Label("Archive", systemImage: "archivebox")
                }
            }
            .navigationTitle("Editor")
        } content: {
            List {
                Text("Welcome")
            }
            .navigationTitle("Pages")
        } detail: {
            PlaceholderEditorCanvas()
        }
    }
}

private struct CompactEditorShell: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Local") {
                    List {
                        NavigationLink("Welcome") {
                            PlaceholderEditorCanvas()
                        }
                    }
                    .navigationTitle("Pages")
                }
            }
            .navigationTitle("Editor")
        }
    }
}

private struct PlaceholderEditorCanvas: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Welcome")
                    .font(.largeTitle.weight(.semibold))

                Text("Start writing in blocks.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.vertical, 36)
        }
        .background(Color.white)
        .navigationTitle("Welcome")
    }
}

#Preview {
    EditorShellView()
}

